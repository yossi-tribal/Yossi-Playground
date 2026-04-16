/**
 * @description Controller for Opportunity Health Thermostat LWC. Queries opportunity data with tasks
 * and OpportunityHistory, calculates health scores based on four criteria, and updates health score fields.
 */
public with sharing class OHT_OpportunityHealthController {

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

            // Calculate health score
            HealthScoreData healthData = calculateHealthScore(opp);

            // Update opportunity fields
            updateOpportunityHealthFields(opp, healthData);

            return healthData;

        } catch (Exception e) {
            throw new AuraHandledException('Error calculating health score: ' + e.getMessage());
        }
    }

    /**
     * @description Calculates health score for an opportunity
     * @param opp The opportunity record to calculate health score for
     * @return HealthScoreData containing calculated health score and breakdown
     */
    public static HealthScoreData calculateHealthScore(Opportunity opp) {
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
        Decimal overdueTasksScore = calculateOverdueTasksScore(opp.Id, healthData.breakdown);
        Decimal lastActivityScore = calculateLastActivityScore(opp.LastActivityDate, healthData.breakdown);
        Decimal closeDateScore = calculateCloseDateScore(opp.CloseDate, healthData.breakdown);
        Decimal stageAgingScore = calculateStageAgingScore(opp.Id, opp.StageName, healthData.breakdown);

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
    private static Decimal calculateOverdueTasksScore(Id oppId, CriteriaBreakdown breakdown) {
        // Query open tasks related to opportunity
        List<Task> overdueTasks = [
            SELECT Id, ActivityDate
            FROM Task
            WHERE WhatId = :oppId
            AND IsClosed = false
            AND ActivityDate < TODAY
        ];

        breakdown.overdueTaskCount = overdueTasks.size();
        breakdown.overdueTasksScore = overdueTasks.isEmpty() ? 100 : 0;

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
    private static Decimal calculateStageAgingScore(Id oppId, String currentStage, CriteriaBreakdown breakdown) {
        // Query OpportunityHistory to find when opportunity entered current stage
        List<OpportunityHistory> histories = [
            SELECT Id, CreatedDate, StageName
            FROM OpportunityHistory
            WHERE OpportunityId = :oppId
            AND StageName = :currentStage
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        Date stageEntryDate;
        if (!histories.isEmpty()) {
            stageEntryDate = histories[0].CreatedDate.date();
        } else {
            // If no history found, use opportunity creation date
            List<Opportunity> opps = [
                SELECT CreatedDate
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];
            stageEntryDate = opps.isEmpty() ? Date.today() : opps[0].CreatedDate.date();
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

        for (Opportunity opp : opportunities) {
            try {
                HealthScoreData healthData = calculateHealthScore(opp);
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
