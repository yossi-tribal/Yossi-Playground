/**
 * @description Controller for Opportunity Health Thermostat LWC. Queries opportunity data with tasks
 * and OpportunityHistory, calculates health scores based on four criteria, and updates health score fields.
 */
public with sharing class OHT_OpportunityHealthController {

    /**
     * @description Pre-queried task and stage history data so bulk health updates stay within SOQL limits
     */
    private class HealthCalculationContext {
        private final Map<Id, Integer> overdueTaskCountByOppId;
        private final Map<String, DateTime> firstStageHistoryCreatedByKey;

        private HealthCalculationContext(
            Map<Id, Integer> overdueTaskCountByOppId,
            Map<String, DateTime> firstStageHistoryCreatedByKey
        ) {
            this.overdueTaskCountByOppId = overdueTaskCountByOppId == null
                ? new Map<Id, Integer>()
                : overdueTaskCountByOppId;
            this.firstStageHistoryCreatedByKey = firstStageHistoryCreatedByKey == null
                ? new Map<String, DateTime>()
                : firstStageHistoryCreatedByKey;
        }
    }

    /**
     * @description Wrapper class for health score data returned to LWC
     */
    public class HealthScoreData {
        @AuraEnabled public Decimal healthScore { get; set; }
        @AuraEnabled public String riskLevel { get; set; }
        @AuraEnabled public DateTime lastUpdated { get; set; }
        @AuraEnabled public CriteriaBreakdown breakdown { get; set; }
        @AuraEnabled public Boolean isClosed { get; set; }
        @AuraEnabled public Boolean isWon { get; set; }
    }

    /**
     * @description Wrapper class for breakdown of individual health criteria
     */
    public class CriteriaBreakdown {
        @AuraEnabled public Decimal overdueTasksScore { get; set; }
        @AuraEnabled public Decimal lastActivityScore { get; set; }
        @AuraEnabled public Decimal closeDateScore { get; set; }
        @AuraEnabled public Decimal stageAgingScore { get; set; }
        @AuraEnabled public Integer overdueTaskCount { get; set; }
        @AuraEnabled public Integer daysSinceLastActivity { get; set; }
        @AuraEnabled public Integer daysUntilClose { get; set; }
        @AuraEnabled public Integer daysInCurrentStage { get; set; }
    }

    /**
     * @description Retrieves and calculates health score data for a given opportunity
     * @param opportunityId The ID of the opportunity to calculate health score for
     * @return HealthScoreData containing calculated health score and breakdown
     */
    @AuraEnabled(cacheable=false)
    public static HealthScoreData getOpportunityHealthScore(Id opportunityId) {
        try {
            // Query opportunity with necessary fields
            List<Opportunity> opps = [
                SELECT Id, Name, StageName, CloseDate, LastActivityDate,
                       IsClosed, IsWon, CreatedDate,
                       OHT_Health_Score__c, OHT_Risk_Level__c, OHT_Health_Score_Last_Updated__c
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];

            if (opps.isEmpty()) {
                throw new AuraHandledException('Opportunity not found');
            }

            Opportunity opp = opps[0];

            HealthCalculationContext ctx = buildHealthCalculationContext(opps);

            // Calculate health score
            HealthScoreData healthData = calculateHealthScore(opp, ctx);

            // Update opportunity fields
            updateOpportunityHealthFields(opp, healthData);

            return healthData;

        } catch (Exception e) {
            if (e instanceof AuraHandledException) {
                throw (AuraHandledException) e;
            }
            throw new AuraHandledException('Error calculating health score: ' + e.getMessage());
        }
    }

    /**
     * @description Bulk-loads overdue open tasks and earliest stage history rows for the given opportunities
     */
    private static HealthCalculationContext buildHealthCalculationContext(List<Opportunity> opps) {
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity o : opps) {
            if (o.Id != null) {
                oppIds.add(o.Id);
            }
        }

        Map<Id, Integer> overdueCountByOppId = new Map<Id, Integer>();
        if (!oppIds.isEmpty()) {
            for (Task t : [
                SELECT WhatId
                FROM Task
                WHERE WhatId IN :oppIds
                AND IsClosed = false
                AND ActivityDate < TODAY
            ]) {
                Id wid = t.WhatId;
                overdueCountByOppId.put(
                    wid,
                    overdueCountByOppId.containsKey(wid) ? overdueCountByOppId.get(wid) + 1 : 1
                );
            }
        }

        Map<String, DateTime> firstHistByOppAndStage = new Map<String, DateTime>();
        if (!oppIds.isEmpty()) {
            Set<String> seenKeys = new Set<String>();
            for (OpportunityHistory oh : [
                SELECT OpportunityId, StageName, CreatedDate
                FROM OpportunityHistory
                WHERE OpportunityId IN :oppIds
                ORDER BY CreatedDate ASC
            ]) {
                String key = String.valueOf(oh.OpportunityId) + '|' + oh.StageName;
                if (!seenKeys.contains(key)) {
                    seenKeys.add(key);
                    firstHistByOppAndStage.put(key, oh.CreatedDate);
                }
            }
        }

        return new HealthCalculationContext(overdueCountByOppId, firstHistByOppAndStage);
    }

    /**
     * @description Calculates health score for an opportunity
     * @param opp The opportunity record to calculate health score for
     * @return HealthScoreData containing calculated health score and breakdown
     */
    public static HealthScoreData calculateHealthScore(Opportunity opp) {
        List<Opportunity> ctxSource = new List<Opportunity>();
        if (opp != null && opp.Id != null) {
            ctxSource.add(opp);
        }
        HealthCalculationContext ctx = buildHealthCalculationContext(ctxSource);
        return calculateHealthScore(opp, ctx);
    }

    private static HealthScoreData calculateHealthScore(Opportunity opp, HealthCalculationContext ctx) {
        HealthScoreData healthData = new HealthScoreData();
        healthData.breakdown = new CriteriaBreakdown();
        healthData.isClosed = opp.IsClosed;
        healthData.isWon = opp.IsWon;

        // Handle closed opportunities
        if (opp.IsClosed) {
            if (opp.IsWon) {
                // Closed Won = Perfect health
                healthData.healthScore = 100;
                healthData.riskLevel = 'On Track';
                healthData.breakdown.overdueTasksScore = 100;
                healthData.breakdown.lastActivityScore = 100;
                healthData.breakdown.closeDateScore = 100;
                healthData.breakdown.stageAgingScore = 100;
            } else {
                // Closed Lost = Zero health
                healthData.healthScore = 0;
                healthData.riskLevel = 'At-Risk';
                healthData.breakdown.overdueTasksScore = 0;
                healthData.breakdown.lastActivityScore = 0;
                healthData.breakdown.closeDateScore = 0;
                healthData.breakdown.stageAgingScore = 0;
            }
            healthData.lastUpdated = DateTime.now();
            return healthData;
        }

        // Calculate individual criteria scores for open opportunities
        Decimal overdueTasksScore = calculateOverdueTasksScore(opp.Id, healthData.breakdown, ctx);
        Decimal lastActivityScore = calculateLastActivityScore(opp.LastActivityDate, healthData.breakdown);
        Decimal closeDateScore = calculateCloseDateScore(opp.CloseDate, healthData.breakdown);
        Decimal stageAgingScore = calculateStageAgingScore(opp, healthData.breakdown, ctx);

        // Calculate weighted health score
        Decimal totalScore =
            (overdueTasksScore * 0.30) +  // 30% weight
            (lastActivityScore * 0.20) +   // 20% weight
            (closeDateScore * 0.25) +      // 25% weight
            (stageAgingScore * 0.25);      // 25% weight

        healthData.healthScore = totalScore.setScale(0);
        healthData.riskLevel = determineRiskLevel(healthData.healthScore);
        healthData.lastUpdated = DateTime.now();

        return healthData;
    }

    /**
     * @description Calculates overdue tasks score (30% weight)
     * @param oppId The opportunity ID
     * @param breakdown The breakdown object to populate with details
     * @return Score from 0-100
     */
    private static Decimal calculateOverdueTasksScore(
        Id oppId,
        CriteriaBreakdown breakdown,
        HealthCalculationContext ctx
    ) {
        Integer overdueCount = ctx.overdueTaskCountByOppId.containsKey(oppId)
            ? ctx.overdueTaskCountByOppId.get(oppId)
            : 0;

        breakdown.overdueTaskCount = overdueCount;
        breakdown.overdueTasksScore = overdueCount == 0 ? 100 : 0;

        return breakdown.overdueTasksScore;
    }

    /**
     * @description Calculates last activity score (20% weight)
     * @param lastActivityDate The last activity date from opportunity
     * @param breakdown The breakdown object to populate with details
     * @return Score from 0-100
     */
    private static Decimal calculateLastActivityScore(Date lastActivityDate, CriteriaBreakdown breakdown) {
        if (lastActivityDate == null) {
            breakdown.daysSinceLastActivity = null;
            breakdown.lastActivityScore = 0;
            return 0;
        }

        Integer daysSince = Date.today().daysBetween(lastActivityDate) * -1;
        breakdown.daysSinceLastActivity = daysSince;

        if (daysSince <= 7) {
            breakdown.lastActivityScore = 100;
        } else if (daysSince <= 14) {
            breakdown.lastActivityScore = 50;
        } else {
            breakdown.lastActivityScore = 0;
        }

        return breakdown.lastActivityScore;
    }

    /**
     * @description Calculates close date proximity score (25% weight)
     * @param closeDate The close date from opportunity
     * @param breakdown The breakdown object to populate with details
     * @return Score from 0-100
     */
    private static Decimal calculateCloseDateScore(Date closeDate, CriteriaBreakdown breakdown) {
        if (closeDate == null) {
            breakdown.daysUntilClose = null;
            breakdown.closeDateScore = 50;
            return 50;
        }

        Integer daysUntil = Date.today().daysBetween(closeDate);
        breakdown.daysUntilClose = daysUntil;

        if (daysUntil > 30) {
            breakdown.closeDateScore = 100;
        } else if (daysUntil >= 15) {
            breakdown.closeDateScore = 50;
        } else {
            breakdown.closeDateScore = 0;
        }

        return breakdown.closeDateScore;
    }

    /**
     * @description Calculates stage aging score (25% weight)
     * @param oppId The opportunity ID
     * @param currentStage The current stage name
     * @param breakdown The breakdown object to populate with details
     * @return Score from 0-100
     */
    private static Decimal calculateStageAgingScore(
        Opportunity opp,
        CriteriaBreakdown breakdown,
        HealthCalculationContext ctx
    ) {
        String key = String.valueOf(opp.Id) + '|' + opp.StageName;
        Date stageEntryDate;
        if (ctx.firstStageHistoryCreatedByKey.containsKey(key)) {
            stageEntryDate = ctx.firstStageHistoryCreatedByKey.get(key).date();
        } else {
            stageEntryDate = opp.CreatedDate != null ? opp.CreatedDate.date() : Date.today();
        }

        Integer daysInStage = stageEntryDate.daysBetween(Date.today());
        breakdown.daysInCurrentStage = daysInStage;

        if (daysInStage <= 30) {
            breakdown.stageAgingScore = 100;
        } else if (daysInStage <= 60) {
            breakdown.stageAgingScore = 50;
        } else {
            breakdown.stageAgingScore = 0;
        }

        return breakdown.stageAgingScore;
    }

    /**
     * @description Determines risk level based on health score
     * @param healthScore The calculated health score (0-100)
     * @return Risk level string (On Track, Needs Attention, At-Risk)
     */
    private static String determineRiskLevel(Decimal healthScore) {
        if (healthScore >= 75) {
            return 'On Track';
        } else if (healthScore >= 50) {
            return 'Needs Attention';
        } else {
            return 'At-Risk';
        }
    }

    /**
     * @description Updates opportunity health fields with calculated values
     * @param opp The opportunity record to update
     * @param healthData The calculated health score data
     */
    private static void updateOpportunityHealthFields(Opportunity opp, HealthScoreData healthData) {
        try {
            opp.OHT_Health_Score__c = healthData.healthScore;
            opp.OHT_Risk_Level__c = healthData.riskLevel;
            opp.OHT_Health_Score_Last_Updated__c = healthData.lastUpdated;

            update opp;
        } catch (Exception e) {
            // Log error but don't fail the entire operation
            System.debug('Error updating opportunity health fields: ' + e.getMessage());
        }
    }

    /**
     * @description Batch-friendly method to calculate and update health scores for multiple opportunities
     * @param opportunities List of opportunities to update
     */
    public static void updateHealthScoresForOpportunities(List<Opportunity> opportunities) {
        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        HealthCalculationContext ctx = buildHealthCalculationContext(opportunities);

        for (Opportunity opp : opportunities) {
            try {
                HealthScoreData healthData = calculateHealthScore(opp, ctx);
                opp.OHT_Health_Score__c = healthData.healthScore;
                opp.OHT_Risk_Level__c = healthData.riskLevel;
                opp.OHT_Health_Score_Last_Updated__c = healthData.lastUpdated;
                oppsToUpdate.add(opp);
            } catch (Exception e) {
                System.debug('Error calculating health score for opportunity ' + opp.Id + ': ' + e.getMessage());
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            try {
                update oppsToUpdate;
            } catch (Exception e) {
                System.debug('Error updating opportunity health scores: ' + e.getMessage());
            }
        }
    }
}
