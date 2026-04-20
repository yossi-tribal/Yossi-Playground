/**
 * @description Handler class for Account Health Score calculation trigger.
 * Automatically evaluates account health based on activity metrics, open cases, and overdue tasks.
 * Health score logic:
 * - Red (At Risk): No activity in 30+ days OR 3+ overdue tasks OR 2+ high priority/escalated cases OR 5+ open cases
 * - Yellow (Caution): No activity in 15-29 days OR 1-2 overdue tasks OR 1 high priority/escalated case OR 3-4 open cases
 * - Green (Healthy): None of the above conditions are met
 * @author Tribal AI Platform
 * @date 2024
 */
public with sharing class CSD_AccountHealthScoreHandler {

    /**
     * When true, Account health trigger skips recalculation (for tests that set scores manually).
     */
    @TestVisible
    private static Boolean skipRecalculationInTests = false;

    /**
     * Prevents re-entrancy: the Account trigger fires `after update` and the handler itself
     * issues an Account update, which would otherwise re-fire the trigger on the same records
     * within the same transaction. That second pass is wasteful and can produce extra history
     * rows that confuse downstream consumers of AccountHistory.
     */
    @TestVisible
    private static Boolean inProgress = false;

    // Health score risk thresholds
    private static final Integer RED_DAYS_NO_ACTIVITY = 30;
    private static final Integer YELLOW_DAYS_NO_ACTIVITY = 15;
    private static final Integer RED_OVERDUE_TASKS = 3;
    private static final Integer YELLOW_OVERDUE_TASKS = 1;
    private static final Integer RED_HIGH_PRIORITY_CASES = 2;
    private static final Integer YELLOW_HIGH_PRIORITY_CASES = 1;
    private static final Integer RED_TOTAL_CASES = 5;
    private static final Integer YELLOW_TOTAL_CASES = 3;

    /**
     * @description Main entry point for calculating health scores for a collection of accounts
     * @param accountIds Set of Account IDs to calculate health scores for
     */
    public static void calculateHealthScores(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }
        if (Test.isRunningTest() && skipRecalculationInTests) {
            return;
        }
        if (inProgress) {
            // Second pass of the same transaction – the first pass already computed the
            // correct score, so there is nothing more to do.
            return;
        }

        // Query accounts that need health score calculation. CSD_Previous_Health_Score__c
        // is read so we can preserve it when the score stays the same, and overwrite it
        // with the prior current value when the score changes.
        List<Account> accountsToUpdate = [
            SELECT Id, CSD_Account_Health_Score__c, CSD_Previous_Health_Score__c
            FROM Account
            WHERE Id IN :accountIds
        ];

        if (accountsToUpdate.isEmpty()) {
            return;
        }

        Map<Id, Date> lastClosedTaskDateByAccount = new Map<Id, Date>();
        for (Task t : [
            SELECT WhatId, ActivityDate
            FROM Task
            WHERE WhatId IN :accountIds
            AND IsClosed = true
            AND ActivityDate != null
        ]) {
            Date existing = lastClosedTaskDateByAccount.get(t.WhatId);
            if (existing == null || t.ActivityDate > existing) {
                lastClosedTaskDateByAccount.put(t.WhatId, t.ActivityDate);
            }
        }

        Map<Id, Date> lastEventDateByAccount = new Map<Id, Date>();
        for (Event ev : [
            SELECT WhatId, ActivityDate
            FROM Event
            WHERE WhatId IN :accountIds
            AND ActivityDate != null
        ]) {
            Date existing = lastEventDateByAccount.get(ev.WhatId);
            if (existing == null || ev.ActivityDate > existing) {
                lastEventDateByAccount.put(ev.WhatId, ev.ActivityDate);
            }
        }

        Map<Id, Integer> overdueTaskCountByAccount = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT WhatId wid, COUNT(Id) cnt
            FROM Task
            WHERE WhatId IN :accountIds
            AND IsClosed = false
            AND ActivityDate < TODAY
            GROUP BY WhatId
        ]) {
            overdueTaskCountByAccount.put((Id) ar.get('wid'), (Integer) ar.get('cnt'));
        }

        Map<Id, Integer> highPriorityCaseCountByAccount = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT AccountId aid, COUNT(Id) cnt
            FROM Case
            WHERE AccountId IN :accountIds
            AND IsClosed = false
            AND (Priority = 'High' OR IsEscalated = true)
            GROUP BY AccountId
        ]) {
            highPriorityCaseCountByAccount.put((Id) ar.get('aid'), (Integer) ar.get('cnt'));
        }

        Map<Id, Integer> openCaseCountByAccount = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT AccountId aid, COUNT(Id) cnt
            FROM Case
            WHERE AccountId IN :accountIds
            AND IsClosed = false
            GROUP BY AccountId
        ]) {
            openCaseCountByAccount.put((Id) ar.get('aid'), (Integer) ar.get('cnt'));
        }

        Map<Id, String> accountHealthScores = new Map<Id, String>();
        for (Account acc : accountsToUpdate) {
            Date lastTaskDate = lastClosedTaskDateByAccount.get(acc.Id);
            Date lastEventDate = lastEventDateByAccount.get(acc.Id);
            Date lastActivityDate = null;
            if (lastTaskDate != null && lastEventDate != null) {
                lastActivityDate = lastTaskDate > lastEventDate ? lastTaskDate : lastEventDate;
            } else if (lastTaskDate != null) {
                lastActivityDate = lastTaskDate;
            } else if (lastEventDate != null) {
                lastActivityDate = lastEventDate;
            }

            Integer daysSinceLastActivity = null;
            if (lastActivityDate != null) {
                daysSinceLastActivity = lastActivityDate.daysBetween(Date.today());
            }

            Integer overdueTasksCount = overdueTaskCountByAccount.containsKey(acc.Id)
                ? overdueTaskCountByAccount.get(acc.Id)
                : 0;
            Integer highPriorityCasesCount = highPriorityCaseCountByAccount.containsKey(acc.Id)
                ? highPriorityCaseCountByAccount.get(acc.Id)
                : 0;
            Integer totalOpenCasesCount = openCaseCountByAccount.containsKey(acc.Id)
                ? openCaseCountByAccount.get(acc.Id)
                : 0;

            accountHealthScores.put(
                acc.Id,
                calculateHealthScoreFromMetrics(
                    daysSinceLastActivity,
                    overdueTasksCount,
                    highPriorityCasesCount,
                    totalOpenCasesCount
                )
            );
        }

        List<Account> accountsWithNewScores = new List<Account>();
        for (Account acc : accountsToUpdate) {
            String newScore = accountHealthScores.get(acc.Id);
            if (newScore != null && newScore != acc.CSD_Account_Health_Score__c) {
                // Capture the old current value as the previous score in the same DML so
                // downstream trend calculations are always consistent with the displayed score.
                // If there was no prior value (brand-new assessment) we leave previous null.
                acc.CSD_Previous_Health_Score__c = acc.CSD_Account_Health_Score__c;
                acc.CSD_Account_Health_Score__c = newScore;
                accountsWithNewScores.add(acc);
            }
        }

        if (!accountsWithNewScores.isEmpty()) {
            inProgress = true;
            try {
                update accountsWithNewScores;
            } finally {
                inProgress = false;
            }
        }
    }

    /**
     * @description Calculates health score from pre-loaded metrics (bulk-safe).
     */
    private static String calculateHealthScoreFromMetrics(
        Integer daysSinceLastActivity,
        Integer overdueTasksCount,
        Integer highPriorityCasesCount,
        Integer totalOpenCasesCount
    ) {
        if (isRedRisk(daysSinceLastActivity, overdueTasksCount, highPriorityCasesCount, totalOpenCasesCount)) {
            return 'At Risk';
        }
        if (isYellowRisk(daysSinceLastActivity, overdueTasksCount, highPriorityCasesCount, totalOpenCasesCount)) {
            return 'Needs Attention';
        }
        return 'Healthy';
    }

    /**
     * @description Evaluates if account meets Red (At Risk) criteria
     * @param daysSinceLastActivity Number of days since last completed activity
     * @param overdueTasksCount Number of overdue tasks
     * @param highPriorityCasesCount Number of high priority or escalated cases
     * @param totalOpenCasesCount Total number of open cases
     * @return Boolean true if account meets Red risk criteria
     */
    private static Boolean isRedRisk(Integer daysSinceLastActivity, Integer overdueTasksCount,
                                      Integer highPriorityCasesCount, Integer totalOpenCasesCount) {
        // Red if: 30+ days no activity OR 3+ overdue tasks OR 2+ high priority cases OR 5+ total cases
        return (daysSinceLastActivity != null && daysSinceLastActivity >= RED_DAYS_NO_ACTIVITY) ||
               (overdueTasksCount >= RED_OVERDUE_TASKS) ||
               (highPriorityCasesCount >= RED_HIGH_PRIORITY_CASES) ||
               (totalOpenCasesCount >= RED_TOTAL_CASES);
    }

    /**
     * @description Evaluates if account meets Yellow (Caution) criteria
     * @param daysSinceLastActivity Number of days since last completed activity
     * @param overdueTasksCount Number of overdue tasks
     * @param highPriorityCasesCount Number of high priority or escalated cases
     * @param totalOpenCasesCount Total number of open cases
     * @return Boolean true if account meets Yellow risk criteria
     */
    private static Boolean isYellowRisk(Integer daysSinceLastActivity, Integer overdueTasksCount,
                                         Integer highPriorityCasesCount, Integer totalOpenCasesCount) {
        // Yellow if: 15-29 days no activity OR 1-2 overdue tasks OR 1 high priority case OR 3-4 total cases
        return (daysSinceLastActivity != null && daysSinceLastActivity >= YELLOW_DAYS_NO_ACTIVITY) ||
               (overdueTasksCount >= YELLOW_OVERDUE_TASKS) ||
               (highPriorityCasesCount >= YELLOW_HIGH_PRIORITY_CASES) ||
               (totalOpenCasesCount >= YELLOW_TOTAL_CASES);
    }
}
