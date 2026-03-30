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
        @AuraEnabled public Integer accountsWithOverdueTasks { get; set; }
        @AuraEnabled public Integer accountsWithHighPriCases { get; set; }
        @AuraEnabled public Decimal totalClosedWonAmount { get; set; }
        @AuraEnabled public Decimal totalWeightedPipeline { get; set; }
        @AuraEnabled public Decimal totalYtdClosedWon { get; set; }
        @AuraEnabled public Integer upcomingRenewalsCount { get; set; }
        @AuraEnabled public Integer ytdCaseCount { get; set; }
        @AuraEnabled public Integer priorYearCaseCount { get; set; }
        @AuraEnabled public Integer caseMonth1 { get; set; }
        @AuraEnabled public Integer caseMonth2 { get; set; }
        @AuraEnabled public Integer caseMonth3 { get; set; }
        @AuraEnabled public Integer caseMonth4 { get; set; }
        @AuraEnabled public Integer caseMonth5 { get; set; }
        @AuraEnabled public Integer caseMonth6 { get; set; }
        @AuraEnabled public Integer caseMonth1Prev { get; set; }
        @AuraEnabled public Integer caseMonth2Prev { get; set; }
        @AuraEnabled public Integer caseMonth3Prev { get; set; }
        @AuraEnabled public Integer caseMonth4Prev { get; set; }
        @AuraEnabled public Integer caseMonth5Prev { get; set; }
        @AuraEnabled public Integer caseMonth6Prev { get; set; }
        @AuraEnabled public String caseMonth1Label { get; set; }
        @AuraEnabled public String caseMonth2Label { get; set; }
        @AuraEnabled public String caseMonth3Label { get; set; }
        @AuraEnabled public String caseMonth4Label { get; set; }
        @AuraEnabled public String caseMonth5Label { get; set; }
        @AuraEnabled public String caseMonth6Label { get; set; }
        @AuraEnabled public Decimal priorYearWonRevenue { get; set; }
        @AuraEnabled public Decimal wonMonth1 { get; set; }
        @AuraEnabled public Decimal wonMonth2 { get; set; }
        @AuraEnabled public Decimal wonMonth3 { get; set; }
        @AuraEnabled public Decimal wonMonth4 { get; set; }
        @AuraEnabled public Decimal wonMonth5 { get; set; }
        @AuraEnabled public Decimal wonMonth6 { get; set; }
        @AuraEnabled public Decimal prevWonMonth1 { get; set; }
        @AuraEnabled public Decimal prevWonMonth2 { get; set; }
        @AuraEnabled public Decimal prevWonMonth3 { get; set; }
        @AuraEnabled public Decimal prevWonMonth4 { get; set; }
        @AuraEnabled public Decimal prevWonMonth5 { get; set; }
        @AuraEnabled public Decimal prevWonMonth6 { get; set; }
        @AuraEnabled public String wonMonth1Label { get; set; }
        @AuraEnabled public String wonMonth2Label { get; set; }
        @AuraEnabled public String wonMonth3Label { get; set; }
        @AuraEnabled public String wonMonth4Label { get; set; }
        @AuraEnabled public String wonMonth5Label { get; set; }
        @AuraEnabled public String wonMonth6Label { get; set; }
        @AuraEnabled public Integer casesOpenedLast90Days { get; set; }
        @AuraEnabled public Integer escalatedCasesLast90Days { get; set; }
        @AuraEnabled public Decimal caseResolutionMedianDays { get; set; }
        @AuraEnabled public String caseResolutionTrend { get; set; }
        @AuraEnabled public Integer openTasksCount { get; set; }
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
        @AuraEnabled public String nearestRenewalDate { get; set; }
        @AuraEnabled public Integer daysUntilRenewal { get; set; }
        @AuraEnabled public Integer totalOpenCasesForHealth { get; set; }
        @AuraEnabled public Integer highPriorityCasesForHealth { get; set; }
        @AuraEnabled public Integer overdueTasksForHealth { get; set; }
        @AuraEnabled public Integer daysSinceActivityForHealth { get; set; }
        @AuraEnabled public List<RecentActivity> recentActivities { get; set; }
        @AuraEnabled public String primaryContactName { get; set; }
    }

    /**
     * @description Wrapper for a recent activity (Task or Event) shown in expansion rows
     */
    public class RecentActivity {
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String activityDate { get; set; }
        @AuraEnabled public String activityType { get; set; }
    }

    /**
     * @description Wrapper for portfolio-level health factor breakdown
     */
    public class PortfolioHealthBreakdown {
        @AuraEnabled public Integer accountsInactiveRed { get; set; }
        @AuraEnabled public Integer accountsInactiveYellow { get; set; }
        @AuraEnabled public Integer accountsInactiveGreen { get; set; }
        @AuraEnabled public Integer accountsOverdueRed { get; set; }
        @AuraEnabled public Integer accountsOverdueYellow { get; set; }
        @AuraEnabled public Integer accountsOverdueGreen { get; set; }
        @AuraEnabled public Integer accountsHighPriRed { get; set; }
        @AuraEnabled public Integer accountsHighPriYellow { get; set; }
        @AuraEnabled public Integer accountsHighPriGreen { get; set; }
        @AuraEnabled public Integer accountsCasesRed { get; set; }
        @AuraEnabled public Integer accountsCasesYellow { get; set; }
        @AuraEnabled public Integer accountsCasesGreen { get; set; }
    }

    /**
     * @description Wrapper for an overdue task item shown in suggested action modal
     */
    public class OverdueTaskRow {
        @AuraEnabled public Id taskId { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String dueDate { get; set; }
        @AuraEnabled public Integer daysOverdue { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public Id accountId { get; set; }
    }

    /**
     * @description Wrapper for a high-priority case shown in suggested action modal
     */
    public class HighPriorityCaseRow {
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public Id accountId { get; set; }
    }

    /**
     * @description Wrapper for a portfolio-wide open case shown in the KPI modal.
     */
    public class PortfolioCaseRow {
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public Integer age { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public Boolean isEscalated { get; set; }
    }

    /**
     * @description Wrapper for a portfolio-wide open task shown in the detail accordion and KPI modal.
     */
    public class PortfolioTaskRow {
        @AuraEnabled public Id taskId { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String dueDate { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public Boolean isOverdue { get; set; }
        @AuraEnabled public Integer daysOverdue { get; set; }
    }

    /**
     * @description Wrapper for a portfolio-wide open opportunity shown in the KPI modal.
     */
    public class PortfolioOpportunityRow {
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String stageName { get; set; }
        @AuraEnabled public String closeDate { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Decimal probability { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public Id accountId { get; set; }
    }

    /**
     * @description Wrapper class for upcoming renewal opportunities
     */
    public class RenewalRow {
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public String opportunityName { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String closeDate { get; set; }
        @AuraEnabled public Integer daysUntilClose { get; set; }
        @AuraEnabled public String stageName { get; set; }
    }

    /**
     * @description Wrapper class for upcoming events across the portfolio
     */
    public class PortfolioEventRow {
        @AuraEnabled public Id eventId { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String activityDate { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public Id accountId { get; set; }
    }

    private static final String[] MONTH_ABBREVS = new String[]{
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    };

    private static Set<Id> getPortfolioAccountIds(Id currentUserId) {
        Set<Id> accountIds = new Set<Id>();
        for (Account a : [
            SELECT Id
            FROM Account
            WHERE CSD_Primary_CSM__c = :currentUserId
        ]) {
            accountIds.add(a.Id);
        }
        return accountIds;
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
            summary.ytdCaseCount = 0;
            summary.priorYearCaseCount = 0;
            summary.caseMonth1 = 0;
            summary.caseMonth2 = 0;
            summary.caseMonth3 = 0;
            summary.caseMonth4 = 0;
            summary.caseMonth5 = 0;
            summary.caseMonth6 = 0;
            summary.caseMonth1Prev = 0;
            summary.caseMonth2Prev = 0;
            summary.caseMonth3Prev = 0;
            summary.caseMonth4Prev = 0;
            summary.caseMonth5Prev = 0;
            summary.caseMonth6Prev = 0;
            summary.caseMonth1Label = '';
            summary.caseMonth2Label = '';
            summary.caseMonth3Label = '';
            summary.caseMonth4Label = '';
            summary.caseMonth5Label = '';
            summary.caseMonth6Label = '';
            summary.priorYearWonRevenue = 0;
            summary.wonMonth1 = 0;
            summary.wonMonth2 = 0;
            summary.wonMonth3 = 0;
            summary.wonMonth4 = 0;
            summary.wonMonth5 = 0;
            summary.wonMonth6 = 0;
            summary.prevWonMonth1 = 0;
            summary.prevWonMonth2 = 0;
            summary.prevWonMonth3 = 0;
            summary.prevWonMonth4 = 0;
            summary.prevWonMonth5 = 0;
            summary.prevWonMonth6 = 0;
            summary.wonMonth1Label = '';
            summary.wonMonth2Label = '';
            summary.wonMonth3Label = '';
            summary.wonMonth4Label = '';
            summary.wonMonth5Label = '';
            summary.wonMonth6Label = '';
            summary.casesOpenedLast90Days = 0;
            summary.escalatedCasesLast90Days = 0;
            summary.caseResolutionMedianDays = null;
            summary.caseResolutionTrend = 'stable';
            summary.openTasksCount = 0;

            // Total accounts assigned to current user
            summary.totalAccounts = [
                SELECT COUNT()
                FROM Account
                WHERE CSD_Primary_CSM__c = :currentUserId
            ];

            // At-risk accounts (Health Score = At Risk)
            summary.atRiskAccounts = [
                SELECT COUNT()
                FROM Account
                WHERE CSD_Primary_CSM__c = :currentUserId
                AND CSD_Account_Health_Score__c = 'At Risk'
            ];

            // Needs attention accounts (Health Score = Needs Attention)
            summary.needsAttentionAccounts = [
                SELECT COUNT()
                FROM Account
                WHERE CSD_Primary_CSM__c = :currentUserId
                AND CSD_Account_Health_Score__c = 'Needs Attention'
            ];

            // Healthy accounts (Health Score = Healthy)
            summary.healthyAccounts = [
                SELECT COUNT()
                FROM Account
                WHERE CSD_Primary_CSM__c = :currentUserId
                AND CSD_Account_Health_Score__c = 'Healthy'
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

            // Inactive accounts (no activity in 30+ days)
            summary.inactiveAccounts = 0;
            if (!accountIds.isEmpty()) {
                Set<Id> activeAccountIds = new Set<Id>();
                for (Task t : [
                    SELECT WhatId FROM Task
                    WHERE WhatId IN :accountIds
                    AND ActivityDate >= LAST_N_DAYS:30
                    AND ActivityDate != null
                ]) {
                    activeAccountIds.add(t.WhatId);
                }
                for (Event e : [
                    SELECT WhatId FROM Event
                    WHERE WhatId IN :accountIds
                    AND ActivityDate >= LAST_N_DAYS:30
                    AND ActivityDate != null
                ]) {
                    activeAccountIds.add(e.WhatId);
                }
                summary.inactiveAccounts = accountIds.size() - activeAccountIds.size();
            }

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

            // Accounts with overdue tasks (count of distinct accounts)
            summary.accountsWithOverdueTasks = 0;
            if (!accountIds.isEmpty()) {
                List<AggregateResult> overdueAccounts = [
                    SELECT WhatId FROM Task
                    WHERE WhatId IN :accountIds
                    AND IsClosed = false
                    AND ActivityDate < TODAY
                    GROUP BY WhatId
                ];
                summary.accountsWithOverdueTasks = overdueAccounts.size();
            }

            // Accounts with high-priority cases
            summary.accountsWithHighPriCases = 0;
            if (!accountIds.isEmpty()) {
                List<AggregateResult> highPriAccounts = [
                    SELECT AccountId FROM Case
                    WHERE AccountId IN :accountIds
                    AND IsClosed = false
                    AND (Priority = 'High' OR IsEscalated = true)
                    GROUP BY AccountId
                ];
                summary.accountsWithHighPriCases = highPriAccounts.size();
            }

            // Total closed-won amount (lifetime value)
            summary.totalClosedWonAmount = 0;
            if (!accountIds.isEmpty()) {
                for (AggregateResult ar : [
                    SELECT SUM(Amount) totalAmount
                    FROM Opportunity
                    WHERE AccountId IN :accountIds
                    AND IsWon = true
                ]) {
                    Decimal amt = (Decimal) ar.get('totalAmount');
                    summary.totalClosedWonAmount = amt != null ? amt : 0;
                }
            }

            // Total weighted pipeline
            summary.totalWeightedPipeline = 0;
            if (!accountIds.isEmpty()) {
                for (Opportunity opp : [
                    SELECT Amount, Probability
                    FROM Opportunity
                    WHERE AccountId IN :accountIds
                    AND IsClosed = false
                    AND Amount != null
                ]) {
                    Decimal prob = opp.Probability != null ? opp.Probability : 0;
                    summary.totalWeightedPipeline += opp.Amount * (prob / 100);
                }
            }

            // Total YTD closed-won
            summary.totalYtdClosedWon = 0;
            if (!accountIds.isEmpty()) {
                Date ytdStart = Date.newInstance(Date.today().year(), 1, 1);
                for (AggregateResult ar : [
                    SELECT SUM(Amount) totalAmount
                    FROM Opportunity
                    WHERE AccountId IN :accountIds
                    AND IsWon = true
                    AND CloseDate >= :ytdStart
                ]) {
                    Decimal amt = (Decimal) ar.get('totalAmount');
                    summary.totalYtdClosedWon = amt != null ? amt : 0;
                }
            }

            // Upcoming renewals count (next 90 days)
            summary.upcomingRenewalsCount = 0;
            if (!accountIds.isEmpty()) {
                Date futureDate = Date.today().addDays(90);
                summary.upcomingRenewalsCount = [
                    SELECT COUNT()
                    FROM Opportunity
                    WHERE AccountId IN :accountIds
                    AND IsClosed = false
                    AND CloseDate >= TODAY
                    AND CloseDate <= :futureDate
                ];
            }

            populatePortfolioYtdCaseCount(accountIds, summary);
            populatePortfolioMonthlyCaseVolume(accountIds, summary);
            populatePortfolioMonthlyRevenueVolume(accountIds, summary);
            populatePortfolio90DayCaseMetrics(accountIds, summary);
            populatePortfolioPriorYearRevenue(accountIds, summary);
            populatePortfolioOpenTasksCount(accountIds, summary);

            return summary;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving portfolio summary: ' + e.getMessage());
        }
    }

    private static void populatePortfolioYtdCaseCount(Set<Id> accountIds, PortfolioSummary summary) {
        if (accountIds.isEmpty()) {
            return;
        }

        Integer currentYear = Date.today().year();
        Date ytdStart = Date.newInstance(currentYear, 1, 1);
        Integer priorYear = currentYear - 1;
        Date priorYearStart = Date.newInstance(priorYear, 1, 1);
        Date priorYearEnd = Date.newInstance(priorYear, 12, 31);

        summary.ytdCaseCount = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId IN :accountIds
            AND CreatedDate >= :ytdStart
        ];

        summary.priorYearCaseCount = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId IN :accountIds
            AND CreatedDate >= :priorYearStart
            AND CreatedDate <= :priorYearEnd
        ];
    }

    private static void populatePortfolioMonthlyCaseVolume(Set<Id> accountIds, PortfolioSummary summary) {
        if (accountIds.isEmpty()) {
            return;
        }

        Date today = Date.today();
        Integer currentMonth = today.month();
        Integer currentYear = today.year();
        Integer startMonth = currentMonth - 5;
        Integer startYear = currentYear;
        if (startMonth < 1) {
            startMonth += 12;
            startYear--;
        }

        Date sixMonthsAgo = Date.newInstance(startYear, startMonth, 1);
        Date priorSixMonthsAgo = Date.newInstance(startYear - 1, startMonth, 1);

        Map<String, Integer> monthCounts = new Map<String, Integer>();
        Map<String, Integer> prevMonthCounts = new Map<String, Integer>();
        List<String> orderedKeys = new List<String>();

        Integer monthCursor = startMonth;
        Integer yearCursor = startYear;
        for (Integer i = 0; i < 6; i++) {
            String key = yearCursor + '-' + String.valueOf(monthCursor).leftPad(2, '0');
            monthCounts.put(key, 0);
            orderedKeys.add(key);

            String prevKey = (yearCursor - 1) + '-' + String.valueOf(monthCursor).leftPad(2, '0');
            prevMonthCounts.put(prevKey, 0);

            monthCursor++;
            if (monthCursor > 12) {
                monthCursor = 1;
                yearCursor++;
            }
        }

        for (AggregateResult ar : [
            SELECT CALENDAR_MONTH(CreatedDate) mo, CALENDAR_YEAR(CreatedDate) yr, COUNT(Id) cnt
            FROM Case
            WHERE AccountId IN :accountIds
            AND CreatedDate >= :sixMonthsAgo
            GROUP BY CALENDAR_MONTH(CreatedDate), CALENDAR_YEAR(CreatedDate)
            ORDER BY CALENDAR_YEAR(CreatedDate), CALENDAR_MONTH(CreatedDate)
        ]) {
            Integer resultMonth = (Integer) ar.get('mo');
            Integer resultYear = (Integer) ar.get('yr');
            String key = resultYear + '-' + String.valueOf(resultMonth).leftPad(2, '0');
            if (monthCounts.containsKey(key)) {
                monthCounts.put(key, (Integer) ar.get('cnt'));
            }
        }

        for (AggregateResult ar : [
            SELECT CALENDAR_MONTH(CreatedDate) mo, CALENDAR_YEAR(CreatedDate) yr, COUNT(Id) cnt
            FROM Case
            WHERE AccountId IN :accountIds
            AND CreatedDate >= :priorSixMonthsAgo
            AND CreatedDate < :sixMonthsAgo
            GROUP BY CALENDAR_MONTH(CreatedDate), CALENDAR_YEAR(CreatedDate)
            ORDER BY CALENDAR_YEAR(CreatedDate), CALENDAR_MONTH(CreatedDate)
        ]) {
            Integer resultMonth = (Integer) ar.get('mo');
            Integer resultYear = (Integer) ar.get('yr');
            String key = resultYear + '-' + String.valueOf(resultMonth).leftPad(2, '0');
            if (prevMonthCounts.containsKey(key)) {
                prevMonthCounts.put(key, (Integer) ar.get('cnt'));
            }
        }

        List<Integer> counts = new List<Integer>();
        List<Integer> prevCounts = new List<Integer>();
        List<String> labels = new List<String>();
        for (String key : orderedKeys) {
            counts.add(monthCounts.get(key));

            Integer monthValue = Integer.valueOf(key.substring(5));
            Integer yearValue = Integer.valueOf(key.substring(0, 4));
            String prevKey = (yearValue - 1) + '-' + String.valueOf(monthValue).leftPad(2, '0');
            prevCounts.add(prevMonthCounts.containsKey(prevKey) ? prevMonthCounts.get(prevKey) : 0);
            labels.add(MONTH_ABBREVS[monthValue - 1]);
        }

        summary.caseMonth1 = counts[0];
        summary.caseMonth2 = counts[1];
        summary.caseMonth3 = counts[2];
        summary.caseMonth4 = counts[3];
        summary.caseMonth5 = counts[4];
        summary.caseMonth6 = counts[5];
        summary.caseMonth1Prev = prevCounts[0];
        summary.caseMonth2Prev = prevCounts[1];
        summary.caseMonth3Prev = prevCounts[2];
        summary.caseMonth4Prev = prevCounts[3];
        summary.caseMonth5Prev = prevCounts[4];
        summary.caseMonth6Prev = prevCounts[5];
        summary.caseMonth1Label = labels[0];
        summary.caseMonth2Label = labels[1];
        summary.caseMonth3Label = labels[2];
        summary.caseMonth4Label = labels[3];
        summary.caseMonth5Label = labels[4];
        summary.caseMonth6Label = labels[5];
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
                queryString += ' AND CSD_Account_Health_Score__c = \'At Risk\'';
            } else if (filterType == 'needs-attention') {
                queryString += ' AND CSD_Account_Health_Score__c = \'Needs Attention\'';
            } else if (filterType == 'healthy') {
                queryString += ' AND CSD_Account_Health_Score__c = \'Healthy\'';
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
            Map<Id, Date> nearestRenewalByAccount = getNearestRenewalDates(accountIds);
            Map<Id, List<RecentActivity>> recentActivitiesByAccount = getRecentActivities(accountIds);
            Map<Id, String> primaryContactByAccount = getPrimaryContactNames(accountIds);

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

                // Set nearest renewal date
                Date renewalDate = nearestRenewalByAccount.get(acc.Id);
                if (renewalDate != null) {
                    row.nearestRenewalDate = renewalDate.format();
                    row.daysUntilRenewal = Date.today().daysBetween(renewalDate);
                }

                // Health factor breakdown fields (mirror the values used above)
                row.totalOpenCasesForHealth = row.openCasesCount;
                row.highPriorityCasesForHealth = row.highPriorityCasesCount;
                row.overdueTasksForHealth = row.overdueTasksCount;
                row.daysSinceActivityForHealth = row.daysSinceLastActivity;

                // Recent activities and primary contact
                row.recentActivities = recentActivitiesByAccount.containsKey(acc.Id)
                    ? recentActivitiesByAccount.get(acc.Id)
                    : new List<RecentActivity>();
                row.primaryContactName = primaryContactByAccount.get(acc.Id);

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
     * @description Gets nearest renewal/close date for open opportunities per account
     * @param accountIds Set of account IDs
     * @return Map of account ID to nearest renewal date
     */
    private static Map<Id, Date> getNearestRenewalDates(Set<Id> accountIds) {
        Map<Id, Date> renewalByAccount = new Map<Id, Date>();

        if (accountIds.isEmpty()) {
            return renewalByAccount;
        }

        for (Opportunity opp : [
            SELECT AccountId, CloseDate
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND IsClosed = false
            AND CloseDate >= TODAY
            ORDER BY CloseDate ASC
        ]) {
            if (!renewalByAccount.containsKey(opp.AccountId)) {
                renewalByAccount.put(opp.AccountId, opp.CloseDate);
            }
        }

        return renewalByAccount;
    }

    /**
     * @description Retrieves upcoming renewal/closing opportunities across the portfolio
     * @param daysAhead Number of days to look ahead (default 90)
     * @return List of RenewalRow objects sorted by close date
     */
    @AuraEnabled(cacheable=false)
    public static List<RenewalRow> getUpcomingRenewals(Integer daysAhead) {
        try {
            Id currentUserId = UserInfo.getUserId();
            if (daysAhead == null || daysAhead <= 0) {
                daysAhead = 90;
            }
            Date futureDate = Date.today().addDays(daysAhead);

            List<RenewalRow> renewals = new List<RenewalRow>();

            for (Opportunity opp : [
                SELECT Id, Name, Amount, CloseDate, StageName,
                       AccountId, Account.Name
                FROM Opportunity
                WHERE Account.CSD_Primary_CSM__c = :currentUserId
                AND IsClosed = false
                AND CloseDate >= TODAY
                AND CloseDate <= :futureDate
                ORDER BY CloseDate ASC
                LIMIT 20
            ]) {
                RenewalRow row = new RenewalRow();
                row.accountId = opp.AccountId;
                row.accountName = opp.Account.Name;
                row.opportunityId = opp.Id;
                row.opportunityName = opp.Name;
                row.amount = opp.Amount != null ? opp.Amount : 0;
                row.closeDate = opp.CloseDate.format();
                row.daysUntilClose = Date.today().daysBetween(opp.CloseDate);
                row.stageName = opp.StageName;
                renewals.add(row);
            }

            return renewals;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving upcoming renewals: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves upcoming events across the portfolio (next 90 days)
     * @return List of PortfolioEventRow objects sorted by ActivityDate ASC
     */
    @AuraEnabled(cacheable=false)
    public static List<PortfolioEventRow> getUpcomingEventsForPortfolio() {
        try {
            Id currentUserId = UserInfo.getUserId();

            Set<Id> accountIds = new Set<Id>();
            for (Account a : [
                SELECT Id FROM Account
                WHERE CSD_Primary_CSM__c = :currentUserId
            ]) {
                accountIds.add(a.Id);
            }

            if (accountIds.isEmpty()) {
                return new List<PortfolioEventRow>();
            }

            List<PortfolioEventRow> rows = new List<PortfolioEventRow>();

            for (Event ev : [
                SELECT Id, Subject, ActivityDate, Owner.Name,
                       WhatId, What.Name
                FROM Event
                WHERE WhatId IN :accountIds
                AND ActivityDate >= TODAY
                ORDER BY ActivityDate ASC
                LIMIT 10
            ]) {
                PortfolioEventRow row = new PortfolioEventRow();
                row.eventId = ev.Id;
                row.subject = ev.Subject != null ? ev.Subject : 'Untitled Event';
                row.activityDate = ev.ActivityDate != null ? ev.ActivityDate.format() : '';
                row.ownerName = ev.Owner.Name;
                row.accountName = ev.What != null ? ev.What.Name : '';
                row.accountId = ev.WhatId;
                rows.add(row);
            }

            return rows;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving upcoming events: ' + e.getMessage());
        }
    }

    /**
     * @description Helper method to determine color code for health score
     * @param healthScore The health score value
     * @return String color code (green, yellow, red, gray)
     */
    private static String getHealthScoreColor(String healthScore) {
        if (healthScore == 'Healthy') {
            return 'green';
        } else if (healthScore == 'Needs Attention') {
            return 'yellow';
        } else if (healthScore == 'At Risk') {
            return 'red';
        } else {
            return 'gray';
        }
    }

    /**
     * @description Gets the 2-3 most recent activities per account for expansion row display
     * @param accountIds Set of account IDs
     * @return Map of account ID to list of RecentActivity wrappers
     */
    private static Map<Id, List<RecentActivity>> getRecentActivities(Set<Id> accountIds) {
        Map<Id, List<RecentActivity>> result = new Map<Id, List<RecentActivity>>();
        if (accountIds.isEmpty()) {
            return result;
        }

        Map<Id, List<RecentActivity>> tempMap = new Map<Id, List<RecentActivity>>();

        for (Task t : [
            SELECT WhatId, Subject, ActivityDate, Type
            FROM Task
            WHERE WhatId IN :accountIds
            AND IsClosed = true
            AND ActivityDate != null
            ORDER BY ActivityDate DESC
        ]) {
            if (!tempMap.containsKey(t.WhatId)) {
                tempMap.put(t.WhatId, new List<RecentActivity>());
            }
            List<RecentActivity> activities = tempMap.get(t.WhatId);
            if (activities.size() < 3) {
                RecentActivity ra = new RecentActivity();
                ra.subject = t.Subject;
                ra.activityDate = t.ActivityDate.format();
                ra.activityType = (t.Type != null && t.Type.toLowerCase().contains('call')) ? 'Call' : 'Task';
                activities.add(ra);
            }
        }

        for (Event e : [
            SELECT WhatId, Subject, ActivityDate
            FROM Event
            WHERE WhatId IN :accountIds
            AND ActivityDate != null
            AND ActivityDate <= TODAY
            ORDER BY ActivityDate DESC
        ]) {
            if (!tempMap.containsKey(e.WhatId)) {
                tempMap.put(e.WhatId, new List<RecentActivity>());
            }
            List<RecentActivity> activities = tempMap.get(e.WhatId);
            if (activities.size() < 3) {
                RecentActivity ra = new RecentActivity();
                ra.subject = e.Subject;
                ra.activityDate = e.ActivityDate.format();
                ra.activityType = 'Event';
                activities.add(ra);
            }
        }

        // Sort by date descending and take top 3 per account
        for (Id accId : tempMap.keySet()) {
            List<RecentActivity> all = tempMap.get(accId);
            // Already limited to 3 per source; just take as-is (max 6, but typically 3)
            List<RecentActivity> top3 = new List<RecentActivity>();
            for (Integer i = 0; i < Math.min(3, all.size()); i++) {
                top3.add(all[i]);
            }
            result.put(accId, top3);
        }

        return result;
    }

    /**
     * @description Gets primary contact name for each account
     * @param accountIds Set of account IDs
     * @return Map of account ID to primary contact full name
     */
    private static Map<Id, String> getPrimaryContactNames(Set<Id> accountIds) {
        Map<Id, String> contactByAccount = new Map<Id, String>();
        if (accountIds.isEmpty()) {
            return contactByAccount;
        }

        for (Contact c : [
            SELECT AccountId, Name
            FROM Contact
            WHERE AccountId IN :accountIds
            ORDER BY CreatedDate ASC
        ]) {
            if (!contactByAccount.containsKey(c.AccountId)) {
                contactByAccount.put(c.AccountId, c.Name);
            }
        }

        return contactByAccount;
    }

    /**
     * @description Retrieves portfolio-wide health factor breakdown for the health breakdown modal.
     * Counts how many accounts fall into red/yellow/green for each of the 4 health factors.
     * @return PortfolioHealthBreakdown with per-factor counts
     */
    @AuraEnabled(cacheable=false)
    public static PortfolioHealthBreakdown getPortfolioHealthBreakdown() {
        try {
            Id currentUserId = UserInfo.getUserId();
            PortfolioHealthBreakdown breakdown = new PortfolioHealthBreakdown();

            // Initialize all counters
            breakdown.accountsInactiveRed = 0;
            breakdown.accountsInactiveYellow = 0;
            breakdown.accountsInactiveGreen = 0;
            breakdown.accountsOverdueRed = 0;
            breakdown.accountsOverdueYellow = 0;
            breakdown.accountsOverdueGreen = 0;
            breakdown.accountsHighPriRed = 0;
            breakdown.accountsHighPriYellow = 0;
            breakdown.accountsHighPriGreen = 0;
            breakdown.accountsCasesRed = 0;
            breakdown.accountsCasesYellow = 0;
            breakdown.accountsCasesGreen = 0;

            List<Account> portfolioAccounts = [
                SELECT Id FROM Account WHERE CSD_Primary_CSM__c = :currentUserId
            ];
            if (portfolioAccounts.isEmpty()) {
                return breakdown;
            }

            Set<Id> accountIds = new Set<Id>();
            for (Account a : portfolioAccounts) {
                accountIds.add(a.Id);
            }

            Map<Id, Date> lastActivityDates = getLastActivityDates(accountIds);
            Map<Id, Integer> overdueCounts = getOverdueTasksCounts(accountIds);
            Map<Id, Integer> highPriCounts = getHighPriorityCasesCounts(accountIds);
            Map<Id, Integer> totalCaseCounts = getOpenCasesCounts(accountIds);

            // Thresholds from CSD_AccountHealthScoreHandler
            for (Id accId : accountIds) {
                // Activity recency factor
                Date lastActivity = lastActivityDates.get(accId);
                Integer daysSince = lastActivity != null ? lastActivity.daysBetween(Date.today()) : 999;
                if (daysSince >= 30) {
                    breakdown.accountsInactiveRed++;
                } else if (daysSince >= 15) {
                    breakdown.accountsInactiveYellow++;
                } else {
                    breakdown.accountsInactiveGreen++;
                }

                // Overdue tasks factor
                Integer overdue = overdueCounts.containsKey(accId) ? overdueCounts.get(accId) : 0;
                if (overdue >= 3) {
                    breakdown.accountsOverdueRed++;
                } else if (overdue >= 1) {
                    breakdown.accountsOverdueYellow++;
                } else {
                    breakdown.accountsOverdueGreen++;
                }

                // High-priority cases factor
                Integer highPri = highPriCounts.containsKey(accId) ? highPriCounts.get(accId) : 0;
                if (highPri >= 2) {
                    breakdown.accountsHighPriRed++;
                } else if (highPri >= 1) {
                    breakdown.accountsHighPriYellow++;
                } else {
                    breakdown.accountsHighPriGreen++;
                }

                // Total open cases factor
                Integer totalCases = totalCaseCounts.containsKey(accId) ? totalCaseCounts.get(accId) : 0;
                if (totalCases >= 5) {
                    breakdown.accountsCasesRed++;
                } else if (totalCases >= 3) {
                    breakdown.accountsCasesYellow++;
                } else {
                    breakdown.accountsCasesGreen++;
                }
            }

            return breakdown;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving health breakdown: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves overdue tasks across all portfolio accounts for the suggested action modal.
     * @return List of OverdueTaskRow sorted by due date ascending (most overdue first)
     */
    @AuraEnabled(cacheable=false)
    public static List<OverdueTaskRow> getOverdueTasksForPortfolio() {
        try {
            Id currentUserId = UserInfo.getUserId();

            Set<Id> accountIds = getPortfolioAccountIds(currentUserId);

            List<OverdueTaskRow> rows = new List<OverdueTaskRow>();
            if (accountIds.isEmpty()) {
                return rows;
            }

            for (Task t : [
                SELECT Id, Subject, ActivityDate, Owner.Name, Status, What.Name, WhatId
                FROM Task
                WHERE WhatId IN :accountIds
                AND IsClosed = false
                AND ActivityDate < TODAY
                ORDER BY ActivityDate ASC
                LIMIT 50
            ]) {
                OverdueTaskRow row = new OverdueTaskRow();
                row.taskId = t.Id;
                row.subject = t.Subject;
                row.dueDate = t.ActivityDate != null ? t.ActivityDate.format() : '';
                row.daysOverdue = t.ActivityDate != null ? t.ActivityDate.daysBetween(Date.today()) : 0;
                row.ownerName = t.Owner.Name;
                row.status = t.Status;
                row.accountName = t.What.Name;
                row.accountId = t.WhatId;
                rows.add(row);
            }

            return rows;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving overdue tasks: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves high-priority/escalated cases across all portfolio accounts for the suggested action modal.
     * @return List of HighPriorityCaseRow sorted by priority then created date
     */
    @AuraEnabled(cacheable=false)
    public static List<HighPriorityCaseRow> getHighPriorityCasesForPortfolio() {
        try {
            Id currentUserId = UserInfo.getUserId();

            Set<Id> accountIds = getPortfolioAccountIds(currentUserId);

            List<HighPriorityCaseRow> rows = new List<HighPriorityCaseRow>();
            if (accountIds.isEmpty()) {
                return rows;
            }

            for (Case c : [
                SELECT Id, CaseNumber, Subject, Priority, Status, Owner.Name, Account.Name, AccountId
                FROM Case
                WHERE AccountId IN :accountIds
                AND IsClosed = false
                AND (Priority = 'High' OR IsEscalated = true)
                ORDER BY Priority DESC, CreatedDate ASC
                LIMIT 50
            ]) {
                HighPriorityCaseRow row = new HighPriorityCaseRow();
                row.caseId = c.Id;
                row.caseNumber = c.CaseNumber;
                row.subject = c.Subject;
                row.priority = c.Priority;
                row.status = c.Status;
                row.ownerName = c.Owner.Name;
                row.accountName = c.Account.Name;
                row.accountId = c.AccountId;
                rows.add(row);
            }

            return rows;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving high-priority cases: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves all open cases across all portfolio accounts for the KPI modal.
     * @return List of PortfolioCaseRow objects
     */
    @AuraEnabled(cacheable=false)
    public static List<PortfolioCaseRow> getAllOpenCasesForPortfolio() {
        try {
            Set<Id> accountIds = getPortfolioAccountIds(UserInfo.getUserId());
            List<PortfolioCaseRow> rows = new List<PortfolioCaseRow>();
            if (accountIds.isEmpty()) {
                return rows;
            }

            for (Case c : [
                SELECT Id, CaseNumber, Subject, Status, Priority, Owner.Name, Account.Name, AccountId, IsEscalated, CreatedDate
                FROM Case
                WHERE AccountId IN :accountIds
                AND IsClosed = false
                ORDER BY Account.Name ASC, CreatedDate ASC, CaseNumber ASC
            ]) {
                PortfolioCaseRow row = new PortfolioCaseRow();
                row.caseId = c.Id;
                row.caseNumber = c.CaseNumber;
                row.subject = c.Subject;
                row.status = c.Status;
                row.priority = c.Priority;
                row.ownerName = c.Owner.Name;
                row.age = c.CreatedDate != null ? c.CreatedDate.date().daysBetween(Date.today()) : 0;
                row.accountName = c.Account != null ? c.Account.Name : '';
                row.accountId = c.AccountId;
                row.isEscalated = c.IsEscalated;
                rows.add(row);
            }

            return rows;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving open cases: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves all open opportunities across all portfolio accounts for the KPI modal.
     * @return List of PortfolioOpportunityRow objects
     */
    @AuraEnabled(cacheable=false)
    public static List<PortfolioOpportunityRow> getAllOpenOpportunitiesForPortfolio() {
        try {
            Set<Id> accountIds = getPortfolioAccountIds(UserInfo.getUserId());
            List<PortfolioOpportunityRow> rows = new List<PortfolioOpportunityRow>();
            if (accountIds.isEmpty()) {
                return rows;
            }

            for (Opportunity opp : [
                SELECT Id, Name, StageName, CloseDate, Amount, Probability, Owner.Name, Account.Name, AccountId
                FROM Opportunity
                WHERE AccountId IN :accountIds
                AND IsClosed = false
                ORDER BY Account.Name ASC, Amount DESC, CloseDate ASC
            ]) {
                PortfolioOpportunityRow row = new PortfolioOpportunityRow();
                row.opportunityId = opp.Id;
                row.name = opp.Name;
                row.stageName = opp.StageName;
                row.closeDate = opp.CloseDate != null ? opp.CloseDate.format() : '';
                row.amount = opp.Amount != null ? opp.Amount : 0;
                row.probability = opp.Probability != null ? opp.Probability : 0;
                row.ownerName = opp.Owner.Name;
                row.accountName = opp.Account != null ? opp.Account.Name : '';
                row.accountId = opp.AccountId;
                rows.add(row);
            }

            return rows;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving open opportunities: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<PortfolioTaskRow> getAllOpenTasksForPortfolio() {
        try {
            Set<Id> accountIds = getPortfolioAccountIds(UserInfo.getUserId());
            List<PortfolioTaskRow> rows = new List<PortfolioTaskRow>();
            if (accountIds.isEmpty()) {
                return rows;
            }

            for (Task t : [
                SELECT Id, Subject, ActivityDate, Owner.Name, Status, Priority, What.Name, WhatId
                FROM Task
                WHERE WhatId IN :accountIds
                AND IsClosed = false
                ORDER BY ActivityDate ASC NULLS LAST
                LIMIT 100
            ]) {
                PortfolioTaskRow row = new PortfolioTaskRow();
                row.taskId = t.Id;
                row.subject = t.Subject;
                row.dueDate = t.ActivityDate != null ? t.ActivityDate.format() : '';
                row.ownerName = t.Owner.Name;
                row.status = t.Status;
                row.priority = t.Priority;
                row.accountName = t.What.Name;
                row.accountId = t.WhatId;
                row.isOverdue = t.ActivityDate != null && t.ActivityDate < Date.today();
                row.daysOverdue = (t.ActivityDate != null && t.ActivityDate < Date.today())
                    ? t.ActivityDate.daysBetween(Date.today()) : 0;
                rows.add(row);
            }

            return rows;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving open tasks: ' + e.getMessage());
        }
    }

    private static void populatePortfolioMonthlyRevenueVolume(Set<Id> accountIds, PortfolioSummary summary) {
        if (accountIds.isEmpty()) {
            return;
        }

        Date today = Date.today();
        Integer currentMonth = today.month();
        Integer currentYear = today.year();
        Integer startMonth = currentMonth - 5;
        Integer startYear = currentYear;
        if (startMonth < 1) {
            startMonth += 12;
            startYear--;
        }

        Date sixMonthsAgo = Date.newInstance(startYear, startMonth, 1);
        Date priorSixMonthsAgo = Date.newInstance(startYear - 1, startMonth, 1);

        Map<String, Decimal> monthAmounts = new Map<String, Decimal>();
        Map<String, Decimal> prevMonthAmounts = new Map<String, Decimal>();
        List<String> orderedKeys = new List<String>();

        Integer monthCursor = startMonth;
        Integer yearCursor = startYear;
        for (Integer i = 0; i < 6; i++) {
            String key = yearCursor + '-' + String.valueOf(monthCursor).leftPad(2, '0');
            monthAmounts.put(key, 0);
            orderedKeys.add(key);

            String prevKey = (yearCursor - 1) + '-' + String.valueOf(monthCursor).leftPad(2, '0');
            prevMonthAmounts.put(prevKey, 0);

            monthCursor++;
            if (monthCursor > 12) {
                monthCursor = 1;
                yearCursor++;
            }
        }

        for (AggregateResult ar : [
            SELECT CALENDAR_MONTH(CloseDate) mo, CALENDAR_YEAR(CloseDate) yr, SUM(Amount) totalAmount
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND IsWon = true
            AND CloseDate >= :sixMonthsAgo
            GROUP BY CALENDAR_MONTH(CloseDate), CALENDAR_YEAR(CloseDate)
            ORDER BY CALENDAR_YEAR(CloseDate), CALENDAR_MONTH(CloseDate)
        ]) {
            Integer resultMonth = (Integer) ar.get('mo');
            Integer resultYear = (Integer) ar.get('yr');
            String key = resultYear + '-' + String.valueOf(resultMonth).leftPad(2, '0');
            if (monthAmounts.containsKey(key)) {
                Decimal amt = (Decimal) ar.get('totalAmount');
                monthAmounts.put(key, amt != null ? amt : 0);
            }
        }

        for (AggregateResult ar : [
            SELECT CALENDAR_MONTH(CloseDate) mo, CALENDAR_YEAR(CloseDate) yr, SUM(Amount) totalAmount
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND IsWon = true
            AND CloseDate >= :priorSixMonthsAgo
            AND CloseDate < :sixMonthsAgo
            GROUP BY CALENDAR_MONTH(CloseDate), CALENDAR_YEAR(CloseDate)
            ORDER BY CALENDAR_YEAR(CloseDate), CALENDAR_MONTH(CloseDate)
        ]) {
            Integer resultMonth = (Integer) ar.get('mo');
            Integer resultYear = (Integer) ar.get('yr');
            String key = resultYear + '-' + String.valueOf(resultMonth).leftPad(2, '0');
            if (prevMonthAmounts.containsKey(key)) {
                Decimal amt = (Decimal) ar.get('totalAmount');
                prevMonthAmounts.put(key, amt != null ? amt : 0);
            }
        }

        List<Decimal> amounts = new List<Decimal>();
        List<Decimal> prevAmounts = new List<Decimal>();
        List<String> labels = new List<String>();
        for (String key : orderedKeys) {
            amounts.add(monthAmounts.get(key));

            Integer monthValue = Integer.valueOf(key.substring(5));
            Integer yearValue = Integer.valueOf(key.substring(0, 4));
            String prevKey = (yearValue - 1) + '-' + String.valueOf(monthValue).leftPad(2, '0');
            prevAmounts.add(prevMonthAmounts.containsKey(prevKey) ? prevMonthAmounts.get(prevKey) : 0);
            labels.add(MONTH_ABBREVS[monthValue - 1]);
        }

        summary.wonMonth1 = amounts[0];
        summary.wonMonth2 = amounts[1];
        summary.wonMonth3 = amounts[2];
        summary.wonMonth4 = amounts[3];
        summary.wonMonth5 = amounts[4];
        summary.wonMonth6 = amounts[5];
        summary.prevWonMonth1 = prevAmounts[0];
        summary.prevWonMonth2 = prevAmounts[1];
        summary.prevWonMonth3 = prevAmounts[2];
        summary.prevWonMonth4 = prevAmounts[3];
        summary.prevWonMonth5 = prevAmounts[4];
        summary.prevWonMonth6 = prevAmounts[5];
        summary.wonMonth1Label = labels[0];
        summary.wonMonth2Label = labels[1];
        summary.wonMonth3Label = labels[2];
        summary.wonMonth4Label = labels[3];
        summary.wonMonth5Label = labels[4];
        summary.wonMonth6Label = labels[5];
    }

    private static void populatePortfolio90DayCaseMetrics(Set<Id> accountIds, PortfolioSummary summary) {
        if (accountIds.isEmpty()) {
            return;
        }

        Date ninetyDaysAgo = Date.today().addDays(-90);
        Date oneEightyDaysAgo = Date.today().addDays(-180);

        summary.casesOpenedLast90Days = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId IN :accountIds
            AND CreatedDate >= :ninetyDaysAgo
        ];

        summary.escalatedCasesLast90Days = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId IN :accountIds
            AND CreatedDate >= :ninetyDaysAgo
            AND IsEscalated = true
        ];

        List<Decimal> resolutionDays = new List<Decimal>();
        for (Case c : [
            SELECT CreatedDate, ClosedDate
            FROM Case
            WHERE AccountId IN :accountIds
            AND IsClosed = true
            AND ClosedDate >= :ninetyDaysAgo
            AND CreatedDate != null
            AND ClosedDate != null
        ]) {
            Integer days = c.CreatedDate.date().daysBetween(c.ClosedDate.date());
            resolutionDays.add(days);
        }

        if (!resolutionDays.isEmpty()) {
            resolutionDays.sort();
            Integer mid = resolutionDays.size() / 2;
            if (Math.mod(resolutionDays.size(), 2) == 0) {
                summary.caseResolutionMedianDays = (resolutionDays[mid - 1] + resolutionDays[mid]) / 2;
            } else {
                summary.caseResolutionMedianDays = resolutionDays[mid];
            }
        }

        List<Decimal> priorResolutionDays = new List<Decimal>();
        for (Case c : [
            SELECT CreatedDate, ClosedDate
            FROM Case
            WHERE AccountId IN :accountIds
            AND IsClosed = true
            AND ClosedDate >= :oneEightyDaysAgo
            AND ClosedDate < :ninetyDaysAgo
            AND CreatedDate != null
            AND ClosedDate != null
        ]) {
            Integer days = c.CreatedDate.date().daysBetween(c.ClosedDate.date());
            priorResolutionDays.add(days);
        }

        if (!resolutionDays.isEmpty() && !priorResolutionDays.isEmpty()) {
            priorResolutionDays.sort();
            Integer priorMid = priorResolutionDays.size() / 2;
            Decimal priorMedian;
            if (Math.mod(priorResolutionDays.size(), 2) == 0) {
                priorMedian = (priorResolutionDays[priorMid - 1] + priorResolutionDays[priorMid]) / 2;
            } else {
                priorMedian = priorResolutionDays[priorMid];
            }
            if (summary.caseResolutionMedianDays < priorMedian) {
                summary.caseResolutionTrend = 'improving';
            } else if (summary.caseResolutionMedianDays > priorMedian) {
                summary.caseResolutionTrend = 'worsening';
            } else {
                summary.caseResolutionTrend = 'stable';
            }
        }
    }

    private static void populatePortfolioPriorYearRevenue(Set<Id> accountIds, PortfolioSummary summary) {
        if (accountIds.isEmpty()) {
            return;
        }

        Integer priorYear = Date.today().year() - 1;
        Date priorYearStart = Date.newInstance(priorYear, 1, 1);
        Date priorYearEnd = Date.newInstance(priorYear, 12, 31);

        for (AggregateResult ar : [
            SELECT SUM(Amount) totalAmount
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND IsWon = true
            AND CloseDate >= :priorYearStart
            AND CloseDate <= :priorYearEnd
        ]) {
            Decimal amt = (Decimal) ar.get('totalAmount');
            summary.priorYearWonRevenue = amt != null ? amt : 0;
        }
    }

    private static void populatePortfolioOpenTasksCount(Set<Id> accountIds, PortfolioSummary summary) {
        if (accountIds.isEmpty()) {
            return;
        }
        summary.openTasksCount = [
            SELECT COUNT()
            FROM Task
            WHERE WhatId IN :accountIds
            AND IsClosed = false
        ];
    }
}
