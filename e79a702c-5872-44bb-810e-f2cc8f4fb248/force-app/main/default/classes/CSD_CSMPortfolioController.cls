/**
 * @description Apex controller for CSM Portfolio Dashboard Lightning Web Component.
 * Provides efficient aggregate queries for portfolio KPIs, paginated account retrieval
 * with filtering/sorting, and bulk operations optimized for large portfolios.
 * Security: Uses 'with sharing' to enforce record-level security and sharing rules.
 * All queries filter by Primary_CSM__c = current user to ensure users only see their assigned accounts.
 * @author Tribal AI Platform
 * @date 2024
 */
public with sharing class CSD_CSMPortfolioController {

    /**
     * @description Wrapper class for portfolio summary KPIs
     */
    public class PortfolioSummary {
        @AuraEnabled public Integer totalAccounts { get; set; }
        @AuraEnabled public Integer atRiskAccounts { get; set; }
        @AuraEnabled public Integer needsAttentionAccounts { get; set; }
        @AuraEnabled public Integer healthyAccounts { get; set; }
        @AuraEnabled public Integer totalOpenCases { get; set; }
        @AuraEnabled public Integer totalOverdueTasks { get; set; }
        @AuraEnabled public Integer inactiveAccounts { get; set; }
        @AuraEnabled public Decimal totalOpenPipeline { get; set; }
    }

    /**
     * @description Wrapper class for account row data in portfolio table
     */
    public class AccountRow {
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String healthScore { get; set; }
        @AuraEnabled public String healthScoreColor { get; set; }
        @AuraEnabled public Integer daysSinceLastActivity { get; set; }
        @AuraEnabled public Integer openCasesCount { get; set; }
        @AuraEnabled public Integer highPriorityCasesCount { get; set; }
        @AuraEnabled public Integer overdueTasksCount { get; set; }
        @AuraEnabled public String nextActivityDate { get; set; }
        @AuraEnabled public Integer daysUntilNextActivity { get; set; }
        @AuraEnabled public Decimal openPipelineAmount { get; set; }
        @AuraEnabled public Boolean hasNoActivity { get; set; }
        @AuraEnabled public Boolean hasOverdueTasks { get; set; }
        @AuraEnabled public Boolean hasHighPriorityCases { get; set; }
    }

    /**
     * @description Retrieves portfolio summary KPIs for the current user
     * @return PortfolioSummary object with aggregated metrics
     */
    @AuraEnabled(cacheable=false)
    public static PortfolioSummary getPortfolioSummary() {
        try {
            Id currentUserId = UserInfo.getUserId();
            PortfolioSummary summary = new PortfolioSummary();

            // Total accounts assigned to current user
            summary.totalAccounts = [
                SELECT COUNT()
                FROM Account
                WHERE CSD_Primary_CSM__c = :currentUserId
            ];

            // At-risk accounts (Health Score = Red)
            summary.atRiskAccounts = [
                SELECT COUNT()
                FROM Account
                WHERE CSD_Primary_CSM__c = :currentUserId
                AND CSD_Account_Health_Score__c = 'Red'
            ];

            // Needs attention accounts (Health Score = Yellow)
            summary.needsAttentionAccounts = [
                SELECT COUNT()
                FROM Account
                WHERE CSD_Primary_CSM__c = :currentUserId
                AND CSD_Account_Health_Score__c = 'Yellow'
            ];

            // Healthy accounts (Health Score = Green)
            summary.healthyAccounts = [
                SELECT COUNT()
                FROM Account
                WHERE CSD_Primary_CSM__c = :currentUserId
                AND CSD_Account_Health_Score__c = 'Green'
            ];

            // Get all account IDs for current user
            Set<Id> accountIds = new Set<Id>();
            for (Account acc : [
                SELECT Id
                FROM Account
                WHERE CSD_Primary_CSM__c = :currentUserId
            ]) {
                accountIds.add(acc.Id);
            }

            // Total open cases across all accounts
            summary.totalOpenCases = 0;
            if (!accountIds.isEmpty()) {
                summary.totalOpenCases = [
                    SELECT COUNT()
                    FROM Case
                    WHERE AccountId IN :accountIds
                    AND IsClosed = false
                ];
            }

            // Total overdue tasks across all accounts
            summary.totalOverdueTasks = 0;
            if (!accountIds.isEmpty()) {
                summary.totalOverdueTasks = [
                    SELECT COUNT()
                    FROM Task
                    WHERE WhatId IN :accountIds
                    AND IsClosed = false
                    AND ActivityDate < TODAY
                ];
            }

            // Inactive accounts (no activity in 30+ days) - calculated in getPortfolioAccounts
            summary.inactiveAccounts = 0;

            // Total open pipeline across all accounts
            summary.totalOpenPipeline = 0;
            if (!accountIds.isEmpty()) {
                for (AggregateResult ar : [
                    SELECT SUM(Amount) totalAmount
                    FROM Opportunity
                    WHERE AccountId IN :accountIds
                    AND IsClosed = false
                ]) {
                    Decimal amt = (Decimal) ar.get('totalAmount');
                    summary.totalOpenPipeline = amt != null ? amt : 0;
                }
            }

            return summary;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving portfolio summary: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves paginated list of accounts for the current user's portfolio
     * @param filterType Filter type: 'all', 'at-risk', 'needs-attention', 'healthy', 'inactive'
     * @param sortField Field to sort by: 'accountName', 'healthScore', 'daysSinceLastActivity', etc.
     * @param sortDirection Sort direction: 'asc' or 'desc'
     * @param pageSize Number of records per page
     * @param pageNumber Current page number (1-indexed)
     * @return List of AccountRow objects
     */
    @AuraEnabled(cacheable=false)
    public static List<AccountRow> getPortfolioAccounts(
        String filterType,
        String sortField,
        String sortDirection,
        Integer pageSize,
        Integer pageNumber
    ) {
        try {
            Id currentUserId = UserInfo.getUserId();

            // Whitelist allowed values for input validation (prevents SOQL injection)
            Set<String> allowedFilters = new Set<String>{'all', 'at-risk', 'needs-attention', 'healthy', 'inactive'};
            Set<String> allowedSortFields = new Set<String>{'accountName', 'healthScore'};
            Set<String> allowedSortDirections = new Set<String>{'asc', 'desc'};

            // Default and validate parameters
            if (String.isBlank(filterType) || !allowedFilters.contains(filterType.toLowerCase())) {
                filterType = 'all';
            } else {
                filterType = filterType.toLowerCase();
            }

            if (String.isBlank(sortField) || !allowedSortFields.contains(sortField.toLowerCase())) {
                sortField = 'accountName';
            } else {
                sortField = sortField.toLowerCase();
            }

            if (String.isBlank(sortDirection) || !allowedSortDirections.contains(sortDirection.toLowerCase())) {
                sortDirection = 'asc';
            } else {
                sortDirection = sortDirection.toLowerCase();
            }

            if (pageSize == null || pageSize <= 0) {
                pageSize = 25;
            }
            if (pageNumber == null || pageNumber <= 0) {
                pageNumber = 1;
            }

            // Build base query for accounts
            String queryString = 'SELECT Id, Name, CSD_Account_Health_Score__c ' +
                                'FROM Account ' +
                                'WHERE CSD_Primary_CSM__c = :currentUserId';

            // Apply filter (values are validated against whitelist)
            if (filterType == 'at-risk') {
                queryString += ' AND CSD_Account_Health_Score__c = \'Red\'';
            } else if (filterType == 'needs-attention') {
                queryString += ' AND CSD_Account_Health_Score__c = \'Yellow\'';
            } else if (filterType == 'healthy') {
                queryString += ' AND CSD_Account_Health_Score__c = \'Green\'';
            }

            // Apply sorting (values are validated against whitelist)
            if (sortField == 'accountName') {
                queryString += (sortDirection == 'desc') ? ' ORDER BY Name DESC' : ' ORDER BY Name ASC';
            } else if (sortField == 'healthScore') {
                queryString += (sortDirection == 'desc') ? ' ORDER BY CSD_Account_Health_Score__c DESC' : ' ORDER BY CSD_Account_Health_Score__c ASC';
            } else {
                queryString += ' ORDER BY Name ASC';
            }

            // Apply pagination
            Integer offset = (pageNumber - 1) * pageSize;
            queryString += ' LIMIT :pageSize OFFSET :offset';

            // Execute query (all inputs are validated against whitelists)
            List<Account> accounts = Database.query(queryString);

            // Build account rows with additional metrics
            List<AccountRow> accountRows = new List<AccountRow>();
            Set<Id> accountIds = new Set<Id>();
            for (Account acc : accounts) {
                accountIds.add(acc.Id);
            }

            // Get activity metrics for all accounts in batch
            Map<Id, Date> lastActivityByAccount = getLastActivityDates(accountIds);
            Map<Id, Date> nextActivityByAccount = getNextActivityDates(accountIds);
            Map<Id, Integer> openCasesByAccount = getOpenCasesCounts(accountIds);
            Map<Id, Integer> highPriCasesByAccount = getHighPriorityCasesCounts(accountIds);
            Map<Id, Integer> overdueTasksByAccount = getOverdueTasksCounts(accountIds);
            Map<Id, Decimal> openPipelineByAccount = getOpenPipelineAmounts(accountIds);

            // Build account rows
            for (Account acc : accounts) {
                AccountRow row = new AccountRow();
                row.accountId = acc.Id;
                row.accountName = acc.Name;
                row.healthScore = acc.CSD_Account_Health_Score__c != null
                    ? acc.CSD_Account_Health_Score__c
                    : 'Not Assessed';
                row.healthScoreColor = getHealthScoreColor(row.healthScore);

                // Calculate days since last activity
                Date lastActivity = lastActivityByAccount.get(acc.Id);
                if (lastActivity != null) {
                    row.daysSinceLastActivity = lastActivity.daysBetween(Date.today());
                } else {
                    row.daysSinceLastActivity = null;
                }

                // Calculate days until next activity
                Date nextActivity = nextActivityByAccount.get(acc.Id);
                if (nextActivity != null) {
                    row.nextActivityDate = nextActivity.format();
                    row.daysUntilNextActivity = Date.today().daysBetween(nextActivity);
                } else {
                    row.nextActivityDate = null;
                    row.daysUntilNextActivity = null;
                }

                // Set case and task counts
                row.openCasesCount = openCasesByAccount.get(acc.Id) != null
                    ? openCasesByAccount.get(acc.Id)
                    : 0;
                row.highPriorityCasesCount = highPriCasesByAccount.get(acc.Id) != null
                    ? highPriCasesByAccount.get(acc.Id)
                    : 0;
                row.overdueTasksCount = overdueTasksByAccount.get(acc.Id) != null
                    ? overdueTasksByAccount.get(acc.Id)
                    : 0;

                // Set open pipeline amount
                row.openPipelineAmount = openPipelineByAccount.get(acc.Id) != null
                    ? openPipelineByAccount.get(acc.Id)
                    : 0;

                // Set risk indicators
                row.hasNoActivity = row.daysSinceLastActivity != null && row.daysSinceLastActivity > 30;
                row.hasOverdueTasks = row.overdueTasksCount > 0;
                row.hasHighPriorityCases = row.highPriorityCasesCount > 0;

                accountRows.add(row);
            }

            // Apply post-query filtering for inactive accounts
            if (filterType == 'inactive') {
                List<AccountRow> filteredRows = new List<AccountRow>();
                for (AccountRow row : accountRows) {
                    if (row.hasNoActivity) {
                        filteredRows.add(row);
                    }
                }
                return filteredRows;
            }

            return accountRows;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving portfolio accounts: ' + e.getMessage());
        }
    }

    /**
     * @description Gets last activity date for each account
     * @param accountIds Set of account IDs
     * @return Map of account ID to last activity date
     */
    private static Map<Id, Date> getLastActivityDates(Set<Id> accountIds) {
        Map<Id, Date> lastActivityByAccount = new Map<Id, Date>();

        if (accountIds.isEmpty()) {
            return lastActivityByAccount;
        }

        // Get last completed tasks
        for (Task t : [
            SELECT WhatId, ActivityDate
            FROM Task
            WHERE WhatId IN :accountIds
            AND IsClosed = true
            AND ActivityDate != null
            ORDER BY ActivityDate DESC
        ]) {
            if (!lastActivityByAccount.containsKey(t.WhatId)) {
                lastActivityByAccount.put(t.WhatId, t.ActivityDate);
            }
        }

        // Get last events
        for (Event e : [
            SELECT WhatId, ActivityDate
            FROM Event
            WHERE WhatId IN :accountIds
            AND ActivityDate != null
            ORDER BY ActivityDate DESC
        ]) {
            Date existingDate = lastActivityByAccount.get(e.WhatId);
            if (existingDate == null || e.ActivityDate > existingDate) {
                lastActivityByAccount.put(e.WhatId, e.ActivityDate);
            }
        }

        return lastActivityByAccount;
    }

    /**
     * @description Gets next activity date for each account
     * @param accountIds Set of account IDs
     * @return Map of account ID to next activity date
     */
    private static Map<Id, Date> getNextActivityDates(Set<Id> accountIds) {
        Map<Id, Date> nextActivityByAccount = new Map<Id, Date>();

        if (accountIds.isEmpty()) {
            return nextActivityByAccount;
        }

        // Get next tasks
        for (Task t : [
            SELECT WhatId, ActivityDate
            FROM Task
            WHERE WhatId IN :accountIds
            AND IsClosed = false
            AND ActivityDate >= TODAY
            ORDER BY ActivityDate ASC
        ]) {
            if (!nextActivityByAccount.containsKey(t.WhatId)) {
                nextActivityByAccount.put(t.WhatId, t.ActivityDate);
            }
        }

        // Get next events
        for (Event e : [
            SELECT WhatId, ActivityDate
            FROM Event
            WHERE WhatId IN :accountIds
            AND ActivityDate >= TODAY
            ORDER BY ActivityDate ASC
        ]) {
            Date existingDate = nextActivityByAccount.get(e.WhatId);
            if (existingDate == null || e.ActivityDate < existingDate) {
                nextActivityByAccount.put(e.WhatId, e.ActivityDate);
            }
        }

        return nextActivityByAccount;
    }

    /**
     * @description Gets open cases count for each account
     * @param accountIds Set of account IDs
     * @return Map of account ID to open cases count
     */
    private static Map<Id, Integer> getOpenCasesCounts(Set<Id> accountIds) {
        Map<Id, Integer> casesByAccount = new Map<Id, Integer>();

        if (accountIds.isEmpty()) {
            return casesByAccount;
        }

        for (AggregateResult ar : [
            SELECT AccountId, COUNT(Id) caseCount
            FROM Case
            WHERE AccountId IN :accountIds
            AND IsClosed = false
            GROUP BY AccountId
        ]) {
            Id accountId = (Id) ar.get('AccountId');
            Integer count = (Integer) ar.get('caseCount');
            casesByAccount.put(accountId, count);
        }

        return casesByAccount;
    }

    /**
     * @description Gets high priority cases count for each account
     * @param accountIds Set of account IDs
     * @return Map of account ID to high priority cases count
     */
    private static Map<Id, Integer> getHighPriorityCasesCounts(Set<Id> accountIds) {
        Map<Id, Integer> casesByAccount = new Map<Id, Integer>();

        if (accountIds.isEmpty()) {
            return casesByAccount;
        }

        for (AggregateResult ar : [
            SELECT AccountId, COUNT(Id) caseCount
            FROM Case
            WHERE AccountId IN :accountIds
            AND IsClosed = false
            AND (Priority = 'High' OR IsEscalated = true)
            GROUP BY AccountId
        ]) {
            Id accountId = (Id) ar.get('AccountId');
            Integer count = (Integer) ar.get('caseCount');
            casesByAccount.put(accountId, count);
        }

        return casesByAccount;
    }

    /**
     * @description Gets overdue tasks count for each account
     * @param accountIds Set of account IDs
     * @return Map of account ID to overdue tasks count
     */
    private static Map<Id, Integer> getOverdueTasksCounts(Set<Id> accountIds) {
        Map<Id, Integer> tasksByAccount = new Map<Id, Integer>();

        if (accountIds.isEmpty()) {
            return tasksByAccount;
        }

        for (AggregateResult ar : [
            SELECT WhatId, COUNT(Id) taskCount
            FROM Task
            WHERE WhatId IN :accountIds
            AND IsClosed = false
            AND ActivityDate < TODAY
            GROUP BY WhatId
        ]) {
            Id accountId = (Id) ar.get('WhatId');
            Integer count = (Integer) ar.get('taskCount');
            tasksByAccount.put(accountId, count);
        }

        return tasksByAccount;
    }

    /**
     * @description Gets open pipeline amount for each account
     * @param accountIds Set of account IDs
     * @return Map of account ID to open pipeline amount
     */
    private static Map<Id, Decimal> getOpenPipelineAmounts(Set<Id> accountIds) {
        Map<Id, Decimal> pipelineByAccount = new Map<Id, Decimal>();

        if (accountIds.isEmpty()) {
            return pipelineByAccount;
        }

        for (AggregateResult ar : [
            SELECT AccountId, SUM(Amount) totalAmount
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND IsClosed = false
            GROUP BY AccountId
        ]) {
            Id accountId = (Id) ar.get('AccountId');
            Decimal amount = (Decimal) ar.get('totalAmount');
            pipelineByAccount.put(accountId, amount != null ? amount : 0);
        }

        return pipelineByAccount;
    }

    /**
     * @description Helper method to determine color code for health score
     * @param healthScore The health score value
     * @return String color code (green, yellow, red, gray)
     */
    private static String getHealthScoreColor(String healthScore) {
        if (healthScore == 'Green') {
            return 'green';
        } else if (healthScore == 'Yellow') {
            return 'yellow';
        } else if (healthScore == 'Red') {
            return 'red';
        } else {
            return 'gray';
        }
    }
}
