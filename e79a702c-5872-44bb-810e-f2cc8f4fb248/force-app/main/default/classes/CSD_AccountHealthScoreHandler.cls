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

        // Query accounts that need health score calculation
        List<Account> accountsToUpdate = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id IN :accountIds
        ];

        if (accountsToUpdate.isEmpty()) {
            return;
        }

        // Calculate health metrics for each account
        Map<Id, String> accountHealthScores = new Map<Id, String>();

        for (Account acc : accountsToUpdate) {
            String calculatedScore = calculateHealthScore(acc.Id);
            accountHealthScores.put(acc.Id, calculatedScore);
        }

        // Update accounts with new health scores
        List<Account> accountsWithNewScores = new List<Account>();
        for (Account acc : accountsToUpdate) {
            String newScore = accountHealthScores.get(acc.Id);
            // Only update if score has changed to avoid unnecessary updates
            if (newScore != null && newScore != acc.CSD_Account_Health_Score__c) {
                acc.CSD_Account_Health_Score__c = newScore;
                accountsWithNewScores.add(acc);
            }
        }

        // Perform DML update if there are changes
        if (!accountsWithNewScores.isEmpty()) {
            update accountsWithNewScores;
        }
    }

    /**
     * @description Calculates health score for a single account based on risk factors
     * @param accountId The Account ID to evaluate
     * @return String health score value (At Risk, Needs Attention, or Healthy)
     */
    private static String calculateHealthScore(Id accountId) {
        // Gather all risk metrics
        Integer daysSinceLastActivity = getDaysSinceLastActivity(accountId);
        Integer overdueTasksCount = getOverdueTasksCount(accountId);
        Integer highPriorityCasesCount = getHighPriorityCasesCount(accountId);
        Integer totalOpenCasesCount = getTotalOpenCasesCount(accountId);

        // Evaluate Red (At Risk) conditions - highest priority
        if (isRedRisk(daysSinceLastActivity, overdueTasksCount, highPriorityCasesCount, totalOpenCasesCount)) {
            return 'At Risk';
        }

        // Evaluate Yellow (Caution) conditions - medium priority
        if (isYellowRisk(daysSinceLastActivity, overdueTasksCount, highPriorityCasesCount, totalOpenCasesCount)) {
            return 'Needs Attention';
        }

        // Default to Green (Healthy) if no risk conditions are met
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

    /**
     * @description Calculates days since last completed activity (Task or Event)
     * @param accountId The Account ID
     * @return Integer number of days since last activity, or null if no activity found
     */
    private static Integer getDaysSinceLastActivity(Id accountId) {
        // Query most recent completed Task
        List<Task> lastTasks = [
            SELECT Id, ActivityDate
            FROM Task
            WHERE WhatId = :accountId
            AND IsClosed = true
            ORDER BY ActivityDate DESC
            LIMIT 1
        ];

        // Query most recent Event
        List<Event> lastEvents = [
            SELECT Id, ActivityDate
            FROM Event
            WHERE WhatId = :accountId
            ORDER BY ActivityDate DESC
            LIMIT 1
        ];

        // Determine the most recent activity date
        Date lastActivityDate = null;
        if (!lastTasks.isEmpty() && !lastEvents.isEmpty()) {
            lastActivityDate = lastTasks[0].ActivityDate > lastEvents[0].ActivityDate
                ? lastTasks[0].ActivityDate
                : lastEvents[0].ActivityDate;
        } else if (!lastTasks.isEmpty()) {
            lastActivityDate = lastTasks[0].ActivityDate;
        } else if (!lastEvents.isEmpty()) {
            lastActivityDate = lastEvents[0].ActivityDate;
        }

        // Calculate days since last activity
        if (lastActivityDate != null) {
            return lastActivityDate.daysBetween(Date.today());
        }

        // Return null if no activity found (will be treated as highest risk)
        return null;
    }

    /**
     * @description Counts overdue tasks for the account
     * @param accountId The Account ID
     * @return Integer number of overdue tasks
     */
    private static Integer getOverdueTasksCount(Id accountId) {
        return [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :accountId
            AND IsClosed = false
            AND ActivityDate < TODAY
        ];
    }

    /**
     * @description Counts high priority or escalated open cases for the account
     * @param accountId The Account ID
     * @return Integer number of high priority or escalated cases
     */
    private static Integer getHighPriorityCasesCount(Id accountId) {
        return [
            SELECT COUNT()
            FROM Case
            WHERE AccountId = :accountId
            AND IsClosed = false
            AND (Priority = 'High' OR IsEscalated = true)
        ];
    }

    /**
     * @description Counts total open cases for the account
     * @param accountId The Account ID
     * @return Integer number of open cases
     */
    private static Integer getTotalOpenCasesCount(Id accountId) {
        return [
            SELECT COUNT()
            FROM Case
            WHERE AccountId = :accountId
            AND IsClosed = false
        ];
    }
}
