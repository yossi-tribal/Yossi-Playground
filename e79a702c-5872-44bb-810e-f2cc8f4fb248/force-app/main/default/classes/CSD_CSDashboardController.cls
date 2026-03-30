/**
 * @description Apex controller for the Customer Success Dashboard Lightning Web Component.
 * Provides data access and business logic for displaying account health, cases, activities,
 * and engagement metrics. All activity metrics are computed dynamically from related records.
 * @author Tribal AI Platform
 * @date 2024
 */
public with sharing class CSD_CSDashboardController {

    /**
     * @description Wrapper class for dashboard summary metrics
     */
    public class DashboardSummary {
        @AuraEnabled public Integer openCasesCount { get; set; }
        @AuraEnabled public Integer highPriorityCasesCount { get; set; }
        @AuraEnabled public Integer overdueTasks { get; set; }
        @AuraEnabled public Integer openTasksCount { get; set; }
        @AuraEnabled public String lastActivityDate { get; set; }
        @AuraEnabled public String nextPlannedActivity { get; set; }
        @AuraEnabled public Integer opportunityCount { get; set; }
        @AuraEnabled public String accountHealthScore { get; set; }
        @AuraEnabled public String accountHealthColor { get; set; }
        @AuraEnabled public Integer daysSinceLastActivity { get; set; }
        @AuraEnabled public Integer daysUntilNextActivity { get; set; }
        @AuraEnabled public String csmName { get; set; }
        @AuraEnabled public String csmInitials { get; set; }
        @AuraEnabled public String nextOpportunityCloseDate { get; set; }
        @AuraEnabled public String healthTrend { get; set; }
        @AuraEnabled public Integer contactCount { get; set; }
        @AuraEnabled public String relationshipDepth { get; set; }
        @AuraEnabled public Integer relationshipDepthStars { get; set; }
        @AuraEnabled public String nextTouchpointSubject { get; set; }
        @AuraEnabled public String nextTouchpointType { get; set; }
        @AuraEnabled public String nextTouchpointTime { get; set; }
        /** Sum of Amount on closed-won opportunities (booked revenue) */
        @AuraEnabled public Decimal totalWonRevenue { get; set; }
        /** Won revenue with CloseDate in the current calendar year */
        @AuraEnabled public Decimal ytdWonRevenue { get; set; }
        /** Won revenue with CloseDate in the prior calendar year (full year) */
        @AuraEnabled public Decimal priorYearWonRevenue { get; set; }
        /** Sum of Amount on open opportunities */
        @AuraEnabled public Decimal openPipelineAmount { get; set; }
        /** Sum of Amount * Probability/100 on open opportunities */
        @AuraEnabled public Decimal weightedPipelineAmount { get; set; }
        /** Cases created in the last 90 days */
        @AuraEnabled public Integer casesOpenedLast90Days { get; set; }
        /** ISO currency code for formatting (account or org default) */
        @AuraEnabled public String currencyCode { get; set; }
        /** Won revenue for the 4 most recent calendar quarters (oldest first) for mini-bar chart */
        @AuraEnabled public Decimal wonQuarter1 { get; set; }
        @AuraEnabled public Decimal wonQuarter2 { get; set; }
        @AuraEnabled public Decimal wonQuarter3 { get; set; }
        @AuraEnabled public Decimal wonQuarter4 { get; set; }
        /** Labels for the four quarters (e.g. Q1 2024) matching wonQuarter1..4 */
        @AuraEnabled public String wonQuarter1Label { get; set; }
        @AuraEnabled public String wonQuarter2Label { get; set; }
        @AuraEnabled public String wonQuarter3Label { get; set; }
        @AuraEnabled public String wonQuarter4Label { get; set; }

        /** Case resolution metrics (closed cases, last 90 days) */
        @AuraEnabled public Decimal medianCaseCloseTimeDays { get; set; }
        @AuraEnabled public Decimal minCaseCloseTimeDays { get; set; }
        @AuraEnabled public Decimal maxCaseCloseTimeDays { get; set; }
        @AuraEnabled public Integer closedCasesLast90Days { get; set; }
        @AuraEnabled public String caseResolutionTrend { get; set; }

        /** Monthly case volume (last 6 months, oldest first) */
        @AuraEnabled public Integer caseMonth1 { get; set; }
        @AuraEnabled public Integer caseMonth2 { get; set; }
        @AuraEnabled public Integer caseMonth3 { get; set; }
        @AuraEnabled public Integer caseMonth4 { get; set; }
        @AuraEnabled public Integer caseMonth5 { get; set; }
        @AuraEnabled public Integer caseMonth6 { get; set; }
        @AuraEnabled public String caseMonth1Label { get; set; }
        @AuraEnabled public String caseMonth2Label { get; set; }
        @AuraEnabled public String caseMonth3Label { get; set; }
        @AuraEnabled public String caseMonth4Label { get; set; }
        @AuraEnabled public String caseMonth5Label { get; set; }
        @AuraEnabled public String caseMonth6Label { get; set; }
        /** Same 6 months, prior year (for paired bar chart) */
        @AuraEnabled public Integer caseMonth1Prev { get; set; }
        @AuraEnabled public Integer caseMonth2Prev { get; set; }
        @AuraEnabled public Integer caseMonth3Prev { get; set; }
        @AuraEnabled public Integer caseMonth4Prev { get; set; }
        @AuraEnabled public Integer caseMonth5Prev { get; set; }
        @AuraEnabled public Integer caseMonth6Prev { get; set; }
        /** YTD case count and prior year case count */
        @AuraEnabled public Integer ytdCaseCount { get; set; }
        @AuraEnabled public Integer priorYearCaseCount { get; set; }
        /** Escalated cases in the last 90 days */
        @AuraEnabled public Integer escalatedCasesLast90Days { get; set; }

        /** Monthly closed-won revenue (last 6 months, current year, oldest first) */
        @AuraEnabled public Decimal wonMonth1 { get; set; }
        @AuraEnabled public Decimal wonMonth2 { get; set; }
        @AuraEnabled public Decimal wonMonth3 { get; set; }
        @AuraEnabled public Decimal wonMonth4 { get; set; }
        @AuraEnabled public Decimal wonMonth5 { get; set; }
        @AuraEnabled public Decimal wonMonth6 { get; set; }
        /** Same months, prior year */
        @AuraEnabled public Decimal wonMonth1Prev { get; set; }
        @AuraEnabled public Decimal wonMonth2Prev { get; set; }
        @AuraEnabled public Decimal wonMonth3Prev { get; set; }
        @AuraEnabled public Decimal wonMonth4Prev { get; set; }
        @AuraEnabled public Decimal wonMonth5Prev { get; set; }
        @AuraEnabled public Decimal wonMonth6Prev { get; set; }
        @AuraEnabled public String wonMonth1Label { get; set; }
        @AuraEnabled public String wonMonth2Label { get; set; }
        @AuraEnabled public String wonMonth3Label { get; set; }
        @AuraEnabled public String wonMonth4Label { get; set; }
        @AuraEnabled public String wonMonth5Label { get; set; }
        @AuraEnabled public String wonMonth6Label { get; set; }

        /** Nearest renewal (from open Opportunity with Type='Renewal') */
        @AuraEnabled public Integer nearestRenewalDays { get; set; }
        @AuraEnabled public Decimal nearestRenewalAmount { get; set; }
        @AuraEnabled public Boolean hasUpcomingRenewal { get; set; }
        @AuraEnabled public Id nearestRenewalId { get; set; }
    }

    /**
     * @description Wrapper class for Case data
     */
    public class CaseData {
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public Integer age { get; set; }
        @AuraEnabled public Boolean isEscalated { get; set; }
    }

    /**
     * @description Wrapper class for Activity data (Tasks and Events)
     */
    public class ActivityData implements Comparable {
        @AuraEnabled public Id activityId { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String activityType { get; set; }
        @AuraEnabled public String activityDate { get; set; }
        @AuraEnabled public Date activityDateValue { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public Integer daysOverdue { get; set; }
        @AuraEnabled public Boolean isOverdue { get; set; }
        @AuraEnabled public Boolean isDueToday { get; set; }
        @AuraEnabled public String status { get; set; }

        /**
         * @description Compare ActivityData objects by date for sorting
         */
        public Integer compareTo(Object compareTo) {
            ActivityData compareToActivity = (ActivityData)compareTo;

            // Handle null dates
            if (this.activityDateValue == null && compareToActivity.activityDateValue == null) {
                return 0;
            }
            if (this.activityDateValue == null) {
                return 1; // Put nulls at the end
            }
            if (compareToActivity.activityDateValue == null) {
                return -1; // Put nulls at the end
            }

            // Compare dates - ascending order
            if (this.activityDateValue < compareToActivity.activityDateValue) {
                return -1;
            } else if (this.activityDateValue > compareToActivity.activityDateValue) {
                return 1;
            }
            return 0;
        }
    }

    /**
     * @description Wrapper class for Opportunity data
     */
    public class OpportunityData {
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String stageName { get; set; }
        @AuraEnabled public String closeDate { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public Integer probability { get; set; }
    }

    /**
     * @description Wrapper class for Contact data
     */
    public class ContactData {
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String lastActivityDate { get; set; }
    }

    /**
     * @description Retrieves comprehensive dashboard summary for the specified Account
     * @param accountId The Id of the Account record
     * @return DashboardSummary object containing all KPIs
     */
    @AuraEnabled(cacheable=false)
    public static DashboardSummary getDashboardSummary(Id accountId) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }

            DashboardSummary summary = new DashboardSummary();

            // Get Account details
            List<Account> accounts = [
                SELECT Id, CSD_Account_Health_Score__c, CSD_Primary_CSM__c, CSD_Primary_CSM__r.Name
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            if (accounts.isEmpty()) {
                throw new AuraHandledException('Account not found');
            }

            Account acc = accounts[0];

            summary.currencyCode = UserInfo.getDefaultCurrency();

            // Set health score
            summary.accountHealthScore = acc.CSD_Account_Health_Score__c != null
                ? acc.CSD_Account_Health_Score__c
                : 'Not Assessed';
            summary.accountHealthColor = getHealthScoreColor(summary.accountHealthScore);
            summary.healthTrend = calculateHealthTrend(accountId);

            // Set CSM information
            if (acc.CSD_Primary_CSM__c != null && acc.CSD_Primary_CSM__r != null) {
                summary.csmName = acc.CSD_Primary_CSM__r.Name;
                summary.csmInitials = getInitials(acc.CSD_Primary_CSM__r.Name);
            } else {
                summary.csmName = 'Not Assigned';
                summary.csmInitials = 'NA';
            }

            // Count open cases
            Integer openCases = [
                SELECT COUNT()
                FROM Case
                WHERE AccountId = :accountId
                AND IsClosed = false
            ];
            summary.openCasesCount = openCases;

            // Count high priority cases
            Integer highPriCases = [
                SELECT COUNT()
                FROM Case
                WHERE AccountId = :accountId
                AND IsClosed = false
                AND (Priority = 'High' OR IsEscalated = true)
            ];
            summary.highPriorityCasesCount = highPriCases;

            // Count overdue tasks
            Integer overdue = [
                SELECT COUNT()
                FROM Task
                WHERE WhatId = :accountId
                AND IsClosed = false
                AND ActivityDate < TODAY
            ];
            summary.overdueTasks = overdue;

            // Count all open tasks
            Integer openTasks = [
                SELECT COUNT()
                FROM Task
                WHERE WhatId = :accountId
                AND IsClosed = false
            ];
            summary.openTasksCount = openTasks;

            // Get last completed activity (Task or Event)
            List<Task> lastTasks = [
                SELECT Id, ActivityDate
                FROM Task
                WHERE WhatId = :accountId
                AND IsClosed = true
                ORDER BY ActivityDate DESC
                LIMIT 1
            ];

            List<Event> lastEvents = [
                SELECT Id, ActivityDate
                FROM Event
                WHERE WhatId = :accountId
                ORDER BY ActivityDate DESC
                LIMIT 1
            ];

            Date lastActivityDateVal = null;
            if (!lastTasks.isEmpty() && !lastEvents.isEmpty()) {
                lastActivityDateVal = lastTasks[0].ActivityDate > lastEvents[0].ActivityDate
                    ? lastTasks[0].ActivityDate
                    : lastEvents[0].ActivityDate;
            } else if (!lastTasks.isEmpty()) {
                lastActivityDateVal = lastTasks[0].ActivityDate;
            } else if (!lastEvents.isEmpty()) {
                lastActivityDateVal = lastEvents[0].ActivityDate;
            }

            if (lastActivityDateVal != null) {
                summary.lastActivityDate = lastActivityDateVal.format();
                summary.daysSinceLastActivity = Date.today().daysBetween(lastActivityDateVal) * -1;
            } else {
                summary.lastActivityDate = 'No recent activity';
                summary.daysSinceLastActivity = null;
            }

            // Get next planned activity (Task or Event)
            List<Task> nextTasks = [
                SELECT Id, ActivityDate, Subject
                FROM Task
                WHERE WhatId = :accountId
                AND IsClosed = false
                AND ActivityDate >= TODAY
                ORDER BY ActivityDate ASC
                LIMIT 1
            ];

            List<Event> nextEvents = [
                SELECT Id, ActivityDate, Subject
                FROM Event
                WHERE WhatId = :accountId
                AND ActivityDate >= TODAY
                ORDER BY ActivityDate ASC
                LIMIT 1
            ];

            Date nextActivityDateVal = null;
            if (!nextTasks.isEmpty() && !nextEvents.isEmpty()) {
                nextActivityDateVal = nextTasks[0].ActivityDate < nextEvents[0].ActivityDate
                    ? nextTasks[0].ActivityDate
                    : nextEvents[0].ActivityDate;
            } else if (!nextTasks.isEmpty()) {
                nextActivityDateVal = nextTasks[0].ActivityDate;
            } else if (!nextEvents.isEmpty()) {
                nextActivityDateVal = nextEvents[0].ActivityDate;
            }

            if (nextActivityDateVal != null) {
                summary.nextPlannedActivity = nextActivityDateVal.format();
                summary.daysUntilNextActivity = Date.today().daysBetween(nextActivityDateVal);
            } else {
                summary.nextPlannedActivity = 'No upcoming activity';
                summary.daysUntilNextActivity = null;
            }

            // Count all open opportunities
            Integer opportunityCount = [
                SELECT COUNT()
                FROM Opportunity
                WHERE AccountId = :accountId
                AND IsClosed = false
            ];
            summary.opportunityCount = opportunityCount;

            // Get next opportunity close date
            List<Opportunity> nextOpps = [
                SELECT Id, CloseDate
                FROM Opportunity
                WHERE AccountId = :accountId
                AND IsClosed = false
                ORDER BY CloseDate ASC
                LIMIT 1
            ];

            if (!nextOpps.isEmpty() && nextOpps[0].CloseDate != null) {
                summary.nextOpportunityCloseDate = nextOpps[0].CloseDate.format();
            } else {
                summary.nextOpportunityCloseDate = 'None closing soon';
            }

            // Count contacts for relationship depth
            Integer contactsCount = [
                SELECT COUNT()
                FROM Contact
                WHERE AccountId = :accountId
            ];
            summary.contactCount = contactsCount;

            // Calculate relationship depth based on contact count
            if (contactsCount >= 10) {
                summary.relationshipDepth = 'Strong';
                summary.relationshipDepthStars = 4;
            } else if (contactsCount >= 5) {
                summary.relationshipDepth = 'Moderate';
                summary.relationshipDepthStars = 3;
            } else if (contactsCount >= 1) {
                summary.relationshipDepth = 'Weak';
                summary.relationshipDepthStars = 2;
            } else {
                summary.relationshipDepth = 'None';
                summary.relationshipDepthStars = 0;
            }

            // Get next touchpoint details (more detailed than nextPlannedActivity)
            if (nextActivityDateVal != null) {
                // Try to get the subject and type of the next activity
                String nextSubject = '';
                String nextType = '';
                String nextTime = '';

                if (!nextTasks.isEmpty() && (nextEvents.isEmpty() || nextTasks[0].ActivityDate <= nextEvents[0].ActivityDate)) {
                    nextSubject = nextTasks[0].Subject != null ? nextTasks[0].Subject : 'Untitled Task';
                    nextType = 'Task';
                } else if (!nextEvents.isEmpty()) {
                    // Query event with more details including time
                    List<Event> eventDetails = [
                        SELECT Id, Subject, ActivityDateTime
                        FROM Event
                        WHERE Id = :nextEvents[0].Id
                        LIMIT 1
                    ];
                    if (!eventDetails.isEmpty()) {
                        nextSubject = eventDetails[0].Subject != null ? eventDetails[0].Subject : 'Untitled Event';
                        nextType = 'Event';
                        if (eventDetails[0].ActivityDateTime != null) {
                            nextTime = eventDetails[0].ActivityDateTime.format('h:mm a');
                        }
                    }
                }

                summary.nextTouchpointSubject = nextSubject;
                summary.nextTouchpointType = nextType;
                summary.nextTouchpointTime = nextTime;
            } else {
                summary.nextTouchpointSubject = 'No upcoming touchpoint';
                summary.nextTouchpointType = '';
                summary.nextTouchpointTime = '';
            }

            populateCommercialKpis(accountId, summary);

            return summary;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving dashboard summary: ' + e.getMessage());
        }
    }

    /**
     * @description Commercial KPIs: won revenue, pipeline, support volume, quarterly won
     */
    private static void populateCommercialKpis(Id accountId, DashboardSummary summary) {
        summary.totalWonRevenue = 0;
        summary.ytdWonRevenue = 0;
        summary.priorYearWonRevenue = 0;
        summary.openPipelineAmount = 0;
        summary.weightedPipelineAmount = 0;
        summary.casesOpenedLast90Days = 0;
        summary.wonQuarter1 = 0;
        summary.wonQuarter2 = 0;
        summary.wonQuarter3 = 0;
        summary.wonQuarter4 = 0;
        summary.wonQuarter1Label = '';
        summary.wonQuarter2Label = '';
        summary.wonQuarter3Label = '';
        summary.wonQuarter4Label = '';

        summary.medianCaseCloseTimeDays = 0;
        summary.minCaseCloseTimeDays = 0;
        summary.maxCaseCloseTimeDays = 0;
        summary.closedCasesLast90Days = 0;
        summary.caseResolutionTrend = 'stable';

        summary.caseMonth1 = 0;
        summary.caseMonth2 = 0;
        summary.caseMonth3 = 0;
        summary.caseMonth4 = 0;
        summary.caseMonth5 = 0;
        summary.caseMonth6 = 0;
        summary.caseMonth1Label = '';
        summary.caseMonth2Label = '';
        summary.caseMonth3Label = '';
        summary.caseMonth4Label = '';
        summary.caseMonth5Label = '';
        summary.caseMonth6Label = '';
        summary.caseMonth1Prev = 0;
        summary.caseMonth2Prev = 0;
        summary.caseMonth3Prev = 0;
        summary.caseMonth4Prev = 0;
        summary.caseMonth5Prev = 0;
        summary.caseMonth6Prev = 0;
        summary.ytdCaseCount = 0;
        summary.priorYearCaseCount = 0;
        summary.escalatedCasesLast90Days = 0;

        summary.wonMonth1 = 0;
        summary.wonMonth2 = 0;
        summary.wonMonth3 = 0;
        summary.wonMonth4 = 0;
        summary.wonMonth5 = 0;
        summary.wonMonth6 = 0;
        summary.wonMonth1Prev = 0;
        summary.wonMonth2Prev = 0;
        summary.wonMonth3Prev = 0;
        summary.wonMonth4Prev = 0;
        summary.wonMonth5Prev = 0;
        summary.wonMonth6Prev = 0;
        summary.wonMonth1Label = '';
        summary.wonMonth2Label = '';
        summary.wonMonth3Label = '';
        summary.wonMonth4Label = '';
        summary.wonMonth5Label = '';
        summary.wonMonth6Label = '';

        summary.nearestRenewalDays = 0;
        summary.nearestRenewalAmount = 0;
        summary.hasUpcomingRenewal = false;
        summary.nearestRenewalId = null;

        Integer y = Date.today().year();
        Date ytdStart = Date.newInstance(y, 1, 1);
        Date ytdEnd = Date.newInstance(y, 12, 31);
        Integer py = y - 1;
        Date priorYearStart = Date.newInstance(py, 1, 1);
        Date priorYearEnd = Date.newInstance(py, 12, 31);

        for (AggregateResult ar : [
            SELECT SUM(Amount) amt
            FROM Opportunity
            WHERE AccountId = :accountId
            AND IsClosed = true
            AND IsWon = true
        ]) {
            summary.totalWonRevenue = (Decimal) ar.get('amt');
        }
        if (summary.totalWonRevenue == null) {
            summary.totalWonRevenue = 0;
        }

        for (AggregateResult ar : [
            SELECT SUM(Amount) amt
            FROM Opportunity
            WHERE AccountId = :accountId
            AND IsClosed = true
            AND IsWon = true
            AND CloseDate >= :ytdStart
            AND CloseDate <= :ytdEnd
        ]) {
            summary.ytdWonRevenue = (Decimal) ar.get('amt');
        }
        if (summary.ytdWonRevenue == null) {
            summary.ytdWonRevenue = 0;
        }

        for (AggregateResult ar : [
            SELECT SUM(Amount) amt
            FROM Opportunity
            WHERE AccountId = :accountId
            AND IsClosed = true
            AND IsWon = true
            AND CloseDate >= :priorYearStart
            AND CloseDate <= :priorYearEnd
        ]) {
            summary.priorYearWonRevenue = (Decimal) ar.get('amt');
        }
        if (summary.priorYearWonRevenue == null) {
            summary.priorYearWonRevenue = 0;
        }

        for (AggregateResult ar : [
            SELECT SUM(Amount) amt
            FROM Opportunity
            WHERE AccountId = :accountId
            AND IsClosed = false
        ]) {
            summary.openPipelineAmount = (Decimal) ar.get('amt');
        }
        if (summary.openPipelineAmount == null) {
            summary.openPipelineAmount = 0;
        }

        for (Opportunity o : [
            SELECT Amount, Probability
            FROM Opportunity
            WHERE AccountId = :accountId
            AND IsClosed = false
        ]) {
            if (o.Amount != null && o.Probability != null) {
                summary.weightedPipelineAmount += o.Amount * o.Probability / 100;
            }
        }

        summary.casesOpenedLast90Days = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId = :accountId
            AND CreatedDate >= LAST_N_DAYS:90
        ];

        summary.escalatedCasesLast90Days = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId = :accountId
            AND CreatedDate >= LAST_N_DAYS:90
            AND IsEscalated = true
        ];

        populateLastFourQuartersWon(accountId, summary);
        populateCaseResolutionMetrics(accountId, summary);
        populateMonthlyCaseVolume(accountId, summary);
        populateMonthlyWonRevenue(accountId, summary);
        populateNearestRenewal(accountId, summary);
        populateYtdCaseCount(accountId, summary);
    }

    /**
     * @description Fill wonQuarter1..4 (oldest to newest) and labels for last 4 calendar quarters
     */
    private static void populateLastFourQuartersWon(Id accountId, DashboardSummary summary) {
        Date today = Date.today();
        Integer cq = getCalendarQuarter(today);
        Integer cy = today.year();

        // Oldest of the rolling 4 quarters ending at current quarter: step back 3 quarters
        Integer q = cq;
        Integer year = cy;
        for (Integer i = 0; i < 3; i++) {
            q--;
            if (q < 1) {
                q = 4;
                year--;
            }
        }

        List<QuarterWindow> windows = new List<QuarterWindow>();
        for (Integer i = 0; i < 4; i++) {
            windows.add(getQuarterDateRange(year, q));
            q++;
            if (q > 4) {
                q = 1;
                year++;
            }
        }

        List<Decimal> amounts = new List<Decimal>();
        for (QuarterWindow w : windows) {
            Decimal amt = 0;
            for (AggregateResult ar : [
                SELECT SUM(Amount) a
                FROM Opportunity
                WHERE AccountId = :accountId
                AND IsClosed = true
                AND IsWon = true
                AND CloseDate >= :w.startDate
                AND CloseDate <= :w.endDate
            ]) {
                amt = (Decimal) ar.get('a');
            }
            amounts.add(amt != null ? amt : 0);
        }

        summary.wonQuarter1 = amounts.size() > 0 ? amounts[0] : 0;
        summary.wonQuarter2 = amounts.size() > 1 ? amounts[1] : 0;
        summary.wonQuarter3 = amounts.size() > 2 ? amounts[2] : 0;
        summary.wonQuarter4 = amounts.size() > 3 ? amounts[3] : 0;

        summary.wonQuarter1Label = windows.size() > 0 ? windows[0].label : '';
        summary.wonQuarter2Label = windows.size() > 1 ? windows[1].label : '';
        summary.wonQuarter3Label = windows.size() > 2 ? windows[2].label : '';
        summary.wonQuarter4Label = windows.size() > 3 ? windows[3].label : '';
    }

    private class QuarterWindow {
        Date startDate;
        Date endDate;
        String label;
    }

    private static Integer getCalendarQuarter(Date d) {
        Integer m = d.month();
        if (m <= 3) {
            return 1;
        }
        if (m <= 6) {
            return 2;
        }
        if (m <= 9) {
            return 3;
        }
        return 4;
    }

    private static QuarterWindow getQuarterDateRange(Integer year, Integer quarter) {
        QuarterWindow w = new QuarterWindow();
        Integer startMonth = (quarter - 1) * 3 + 1;
        w.startDate = Date.newInstance(year, startMonth, 1);
        Integer endMonth = startMonth + 2;
        Integer lastDay = Date.daysInMonth(year, endMonth);
        w.endDate = Date.newInstance(year, endMonth, lastDay);
        w.label = 'Q' + String.valueOf(quarter) + ' ' + String.valueOf(year);
        return w;
    }

    private static List<Integer> computeDurations(List<Case> cases) {
        List<Integer> durations = new List<Integer>();
        for (Case c : cases) {
            if (c.CreatedDate != null && c.ClosedDate != null) {
                Integer days = c.CreatedDate.date().daysBetween(c.ClosedDate.date());
                durations.add(Math.max(days, 0));
            }
        }
        durations.sort();
        return durations;
    }

    private static Decimal computeMedian(List<Integer> sorted) {
        if (sorted.isEmpty()) return 0;
        Integer n = sorted.size();
        if (Math.mod(n, 2) == 1) {
            return sorted[n / 2];
        }
        return ((Decimal) sorted[n / 2 - 1] + sorted[n / 2]) / 2;
    }

    private static void populateCaseResolutionMetrics(Id accountId, DashboardSummary summary) {
        List<Case> currentCases = [
            SELECT CreatedDate, ClosedDate
            FROM Case
            WHERE AccountId = :accountId
            AND IsClosed = true
            AND ClosedDate >= LAST_N_DAYS:90
        ];

        List<Integer> durations = computeDurations(currentCases);
        summary.closedCasesLast90Days = durations.size();

        if (!durations.isEmpty()) {
            summary.medianCaseCloseTimeDays = computeMedian(durations).setScale(1, System.RoundingMode.HALF_UP);
            summary.minCaseCloseTimeDays = durations[0];
            summary.maxCaseCloseTimeDays = durations[durations.size() - 1];
        }

        DateTime priorStart = DateTime.now().addDays(-180);
        DateTime priorEnd = DateTime.now().addDays(-90);
        List<Case> priorCases = [
            SELECT CreatedDate, ClosedDate
            FROM Case
            WHERE AccountId = :accountId
            AND IsClosed = true
            AND ClosedDate >= :priorStart
            AND ClosedDate < :priorEnd
        ];

        List<Integer> priorDurations = computeDurations(priorCases);
        if (!durations.isEmpty() && !priorDurations.isEmpty()) {
            Decimal currentMedian = computeMedian(durations);
            Decimal priorMedian = computeMedian(priorDurations);
            if (priorMedian > 0) {
                Decimal pctChange = ((currentMedian - priorMedian) / priorMedian) * 100;
                if (pctChange <= -10) {
                    summary.caseResolutionTrend = 'improving';
                } else if (pctChange >= 10) {
                    summary.caseResolutionTrend = 'declining';
                }
            }
        }
    }

    private static final String[] MONTH_ABBREVS = new String[]{
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    };

    private static void populateMonthlyCaseVolume(Id accountId, DashboardSummary summary) {
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

        Integer m = startMonth;
        Integer yr = startYear;
        for (Integer i = 0; i < 6; i++) {
            String key = yr + '-' + String.valueOf(m).leftPad(2, '0');
            monthCounts.put(key, 0);
            orderedKeys.add(key);
            String prevKey = (yr - 1) + '-' + String.valueOf(m).leftPad(2, '0');
            prevMonthCounts.put(prevKey, 0);
            m++;
            if (m > 12) {
                m = 1;
                yr++;
            }
        }

        for (AggregateResult ar : [
            SELECT CALENDAR_MONTH(CreatedDate) mo, CALENDAR_YEAR(CreatedDate) yr, COUNT(Id) cnt
            FROM Case
            WHERE AccountId = :accountId
            AND CreatedDate >= :sixMonthsAgo
            GROUP BY CALENDAR_MONTH(CreatedDate), CALENDAR_YEAR(CreatedDate)
            ORDER BY CALENDAR_YEAR(CreatedDate), CALENDAR_MONTH(CreatedDate)
        ]) {
            Integer arMonth = (Integer) ar.get('mo');
            Integer arYear = (Integer) ar.get('yr');
            String key = arYear + '-' + String.valueOf(arMonth).leftPad(2, '0');
            if (monthCounts.containsKey(key)) {
                monthCounts.put(key, (Integer) ar.get('cnt'));
            }
        }

        for (AggregateResult ar : [
            SELECT CALENDAR_MONTH(CreatedDate) mo, CALENDAR_YEAR(CreatedDate) yr, COUNT(Id) cnt
            FROM Case
            WHERE AccountId = :accountId
            AND CreatedDate >= :priorSixMonthsAgo
            AND CreatedDate < :sixMonthsAgo
            GROUP BY CALENDAR_MONTH(CreatedDate), CALENDAR_YEAR(CreatedDate)
            ORDER BY CALENDAR_YEAR(CreatedDate), CALENDAR_MONTH(CreatedDate)
        ]) {
            Integer arMonth = (Integer) ar.get('mo');
            Integer arYear = (Integer) ar.get('yr');
            String key = arYear + '-' + String.valueOf(arMonth).leftPad(2, '0');
            if (prevMonthCounts.containsKey(key)) {
                prevMonthCounts.put(key, (Integer) ar.get('cnt'));
            }
        }

        List<Integer> counts = new List<Integer>();
        List<Integer> prevCounts = new List<Integer>();
        List<String> labels = new List<String>();
        for (String key : orderedKeys) {
            counts.add(monthCounts.get(key));
            Integer mo = Integer.valueOf(key.substring(5));
            Integer y = Integer.valueOf(key.substring(0, 4));
            String prevKey = (y - 1) + '-' + String.valueOf(mo).leftPad(2, '0');
            prevCounts.add(prevMonthCounts.containsKey(prevKey) ? prevMonthCounts.get(prevKey) : 0);
            labels.add(MONTH_ABBREVS[mo - 1]);
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

    private static void populateYtdCaseCount(Id accountId, DashboardSummary summary) {
        Integer y = Date.today().year();
        Date ytdStart = Date.newInstance(y, 1, 1);
        Integer py = y - 1;
        Date priorYearStart = Date.newInstance(py, 1, 1);
        Date priorYearEnd = Date.newInstance(py, 12, 31);

        summary.ytdCaseCount = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId = :accountId
            AND CreatedDate >= :ytdStart
        ];

        summary.priorYearCaseCount = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId = :accountId
            AND CreatedDate >= :priorYearStart
            AND CreatedDate <= :priorYearEnd
        ];
    }

    private static void populateNearestRenewal(Id accountId, DashboardSummary summary) {
        List<Opportunity> renewals = [
            SELECT Id, CloseDate, Amount
            FROM Opportunity
            WHERE AccountId = :accountId
            AND IsClosed = false
            AND Type = 'Renewal'
            ORDER BY CloseDate ASC
            LIMIT 1
        ];

        if (!renewals.isEmpty()) {
            Opportunity r = renewals[0];
            summary.hasUpcomingRenewal = true;
            summary.nearestRenewalDays = Date.today().daysBetween(r.CloseDate);
            summary.nearestRenewalAmount = r.Amount != null ? r.Amount : 0;
            summary.nearestRenewalId = r.Id;
        }
    }

    private static void populateMonthlyWonRevenue(Id accountId, DashboardSummary summary) {
        Date today = Date.today();
        Integer currentMonth = today.month();
        Integer currentYear = today.year();
        Integer priorYear = currentYear - 1;

        Integer startMonth = currentMonth - 5;
        Integer startYear = currentYear;
        if (startMonth < 1) {
            startMonth += 12;
            startYear--;
        }
        Date windowStart = Date.newInstance(startYear, startMonth, 1);
        Date priorWindowStart = Date.newInstance(startYear - 1, startMonth, 1);

        List<String> orderedKeys = new List<String>();
        Integer m = startMonth;
        Integer yr = startYear;
        for (Integer i = 0; i < 6; i++) {
            orderedKeys.add(yr + '-' + String.valueOf(m).leftPad(2, '0'));
            m++;
            if (m > 12) { m = 1; yr++; }
        }

        Map<String, Decimal> currentAmounts = new Map<String, Decimal>();
        Map<String, Decimal> prevAmounts = new Map<String, Decimal>();
        for (String k : orderedKeys) {
            currentAmounts.put(k, 0);
            Integer mo = Integer.valueOf(k.substring(5));
            Integer y = Integer.valueOf(k.substring(0, 4));
            String prevKey = (y - 1) + '-' + String.valueOf(mo).leftPad(2, '0');
            prevAmounts.put(prevKey, 0);
        }

        for (AggregateResult ar : [
            SELECT CALENDAR_MONTH(CloseDate) mo, CALENDAR_YEAR(CloseDate) yr, SUM(Amount) amt
            FROM Opportunity
            WHERE AccountId = :accountId
            AND IsClosed = true
            AND IsWon = true
            AND CloseDate >= :windowStart
            GROUP BY CALENDAR_MONTH(CloseDate), CALENDAR_YEAR(CloseDate)
            ORDER BY CALENDAR_YEAR(CloseDate), CALENDAR_MONTH(CloseDate)
        ]) {
            Integer arMonth = (Integer) ar.get('mo');
            Integer arYear = (Integer) ar.get('yr');
            String key = arYear + '-' + String.valueOf(arMonth).leftPad(2, '0');
            if (currentAmounts.containsKey(key)) {
                Decimal amt = (Decimal) ar.get('amt');
                currentAmounts.put(key, amt != null ? amt : 0);
            }
        }

        for (AggregateResult ar : [
            SELECT CALENDAR_MONTH(CloseDate) mo, CALENDAR_YEAR(CloseDate) yr, SUM(Amount) amt
            FROM Opportunity
            WHERE AccountId = :accountId
            AND IsClosed = true
            AND IsWon = true
            AND CloseDate >= :priorWindowStart
            AND CloseDate < :windowStart
            GROUP BY CALENDAR_MONTH(CloseDate), CALENDAR_YEAR(CloseDate)
            ORDER BY CALENDAR_YEAR(CloseDate), CALENDAR_MONTH(CloseDate)
        ]) {
            Integer arMonth = (Integer) ar.get('mo');
            Integer arYear = (Integer) ar.get('yr');
            String key = arYear + '-' + String.valueOf(arMonth).leftPad(2, '0');
            if (prevAmounts.containsKey(key)) {
                Decimal amt = (Decimal) ar.get('amt');
                prevAmounts.put(key, amt != null ? amt : 0);
            }
        }

        List<Decimal> curr = new List<Decimal>();
        List<Decimal> prev = new List<Decimal>();
        List<String> labels = new List<String>();
        for (String key : orderedKeys) {
            curr.add(currentAmounts.get(key));
            Integer mo = Integer.valueOf(key.substring(5));
            Integer y = Integer.valueOf(key.substring(0, 4));
            String prevKey = (y - 1) + '-' + String.valueOf(mo).leftPad(2, '0');
            prev.add(prevAmounts.containsKey(prevKey) ? prevAmounts.get(prevKey) : 0);
            labels.add(MONTH_ABBREVS[mo - 1]);
        }

        summary.wonMonth1 = curr[0]; summary.wonMonth2 = curr[1]; summary.wonMonth3 = curr[2];
        summary.wonMonth4 = curr[3]; summary.wonMonth5 = curr[4]; summary.wonMonth6 = curr[5];
        summary.wonMonth1Prev = prev[0]; summary.wonMonth2Prev = prev[1]; summary.wonMonth3Prev = prev[2];
        summary.wonMonth4Prev = prev[3]; summary.wonMonth5Prev = prev[4]; summary.wonMonth6Prev = prev[5];
        summary.wonMonth1Label = labels[0]; summary.wonMonth2Label = labels[1]; summary.wonMonth3Label = labels[2];
        summary.wonMonth4Label = labels[3]; summary.wonMonth5Label = labels[4]; summary.wonMonth6Label = labels[5];
    }

    /**
     * @description Retrieves open cases for the specified Account
     * @param accountId The Id of the Account record
     * @param recordLimit Maximum number of records to return (default 10)
     * @return List of CaseData wrapper objects
     */
    @AuraEnabled(cacheable=false)
    public static List<CaseData> getOpenCases(Id accountId, Integer recordLimit) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }

            if (recordLimit == null || recordLimit <= 0) {
                recordLimit = 10;
            }

            List<CaseData> caseList = new List<CaseData>();

            // Query cases with custom sorting: Escalated first, then by Priority, then by Age
            List<Case> cases = [
                SELECT Id, CaseNumber, Subject, Status, Priority, Owner.Name,
                       CreatedDate, IsEscalated
                FROM Case
                WHERE AccountId = :accountId
                AND IsClosed = false
                ORDER BY IsEscalated DESC, Priority DESC, CreatedDate ASC
                LIMIT :recordLimit
            ];

            for (Case c : cases) {
                CaseData caseData = new CaseData();
                caseData.caseId = c.Id;
                caseData.caseNumber = c.CaseNumber;
                caseData.subject = c.Subject;
                caseData.status = c.Status;
                caseData.priority = c.Priority;
                caseData.ownerName = c.Owner.Name;
                caseData.isEscalated = c.IsEscalated;

                // Calculate age in days
                DateTime createdDT = c.CreatedDate;
                caseData.age = createdDT.date().daysBetween(Date.today());

                caseList.add(caseData);
            }

            return caseList;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving cases: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves open tasks for the specified Account, sorted with overdue and due-today tasks first
     * @param accountId The Id of the Account record
     * @param recordLimit Maximum number of records to return (default 10)
     * @return List of ActivityData wrapper objects
     */
    @AuraEnabled(cacheable=false)
    public static List<ActivityData> getOpenTasks(Id accountId, Integer recordLimit) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }

            if (recordLimit == null || recordLimit <= 0) {
                recordLimit = 10;
            }

            List<ActivityData> activityList = new List<ActivityData>();

            List<Task> tasks = [
                SELECT Id, Subject, ActivityDate, Owner.Name, Status
                FROM Task
                WHERE WhatId = :accountId
                AND IsClosed = false
                ORDER BY ActivityDate ASC NULLS LAST
                LIMIT :recordLimit
            ];

            Date today = Date.today();
            for (Task t : tasks) {
                ActivityData activity = new ActivityData();
                activity.activityId = t.Id;
                activity.subject = t.Subject;
                activity.activityType = 'Task';
                activity.activityDate = t.ActivityDate != null ? t.ActivityDate.format() : '';
                activity.activityDateValue = t.ActivityDate;
                activity.ownerName = t.Owner.Name;
                activity.status = t.Status;
                activity.isOverdue = t.ActivityDate != null && t.ActivityDate < today;
                activity.isDueToday = t.ActivityDate != null && t.ActivityDate == today;

                if (activity.isOverdue) {
                    activity.daysOverdue = t.ActivityDate.daysBetween(today);
                }

                activityList.add(activity);
            }

            return activityList;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving open tasks: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves upcoming activities (Tasks and Events) for the specified Account
     * @param accountId The Id of the Account record
     * @param recordLimit Maximum number of records to return (default 5)
     * @return List of ActivityData wrapper objects
     */
    @AuraEnabled(cacheable=false)
    public static List<ActivityData> getUpcomingActivities(Id accountId, Integer recordLimit) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }

            if (recordLimit == null || recordLimit <= 0) {
                recordLimit = 5;
            }

            List<ActivityData> activityList = new List<ActivityData>();

            // Get upcoming tasks
            List<Task> tasks = [
                SELECT Id, Subject, ActivityDate, Owner.Name, Status
                FROM Task
                WHERE WhatId = :accountId
                AND IsClosed = false
                AND ActivityDate >= TODAY
                ORDER BY ActivityDate ASC
                LIMIT :recordLimit
            ];

            for (Task t : tasks) {
                ActivityData activity = new ActivityData();
                activity.activityId = t.Id;
                activity.subject = t.Subject;
                activity.activityType = 'Task';
                activity.activityDate = t.ActivityDate != null ? t.ActivityDate.format() : '';
                activity.activityDateValue = t.ActivityDate;
                activity.ownerName = t.Owner.Name;
                activity.status = t.Status;
                activityList.add(activity);
            }

            // Get upcoming events
            List<Event> events = [
                SELECT Id, Subject, ActivityDate, Owner.Name
                FROM Event
                WHERE WhatId = :accountId
                AND ActivityDate >= TODAY
                ORDER BY ActivityDate ASC
                LIMIT :recordLimit
            ];

            for (Event e : events) {
                ActivityData activity = new ActivityData();
                activity.activityId = e.Id;
                activity.subject = e.Subject;
                activity.activityType = 'Event';
                activity.activityDate = e.ActivityDate != null ? e.ActivityDate.format() : '';
                activity.activityDateValue = e.ActivityDate;
                activity.ownerName = e.Owner.Name;
                activityList.add(activity);
            }

            // Sort combined list by date and limit
            activityList.sort();

            // Apply record limit if needed
            List<ActivityData> limitedList = new List<ActivityData>();
            for (Integer i = 0; i < activityList.size() && i < recordLimit; i++) {
                limitedList.add(activityList[i]);
            }

            return limitedList;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving upcoming activities: ' + e.getMessage());
        }
    }

    /**
     * @description Calculates health trend based on AccountHistory field tracking
     * @param accountId The Id of the Account record
     * @return String trend indicator (improving, declining, stable)
     */
    private static String calculateHealthTrend(Id accountId) {
        try {
            // Query the last 2 health score changes from AccountHistory
            List<AccountHistory> historyRecords = [
                SELECT OldValue, NewValue, CreatedDate
                FROM AccountHistory
                WHERE AccountId = :accountId
                AND Field = 'CSD_Account_Health_Score__c'
                ORDER BY CreatedDate DESC
                LIMIT 2
            ];

            // If no history, trend is stable (no changes)
            if (historyRecords.isEmpty()) {
                return 'stable';
            }

            // Get the most recent change
            String previousValue = String.valueOf(historyRecords[0].OldValue);
            String currentValue = String.valueOf(historyRecords[0].NewValue);

            // Compare health scores to determine trend
            // Health score values: Healthy (best), Needs Attention (middle), At Risk (worst)
            return determineTrendDirection(previousValue, currentValue);

        } catch (Exception e) {
            // If history tracking is not enabled or any error occurs, default to stable
            return 'stable';
        }
    }

    /**
     * @description Determines trend direction based on old and new health score values
     * @param oldValue Previous health score value
     * @param newValue Current health score value
     * @return String trend indicator (improving, declining, stable)
     */
    private static String determineTrendDirection(String oldValue, String newValue) {
        // Handle null or blank values
        if (String.isBlank(oldValue) || String.isBlank(newValue)) {
            return 'stable';
        }

        // If values are the same, trend is stable
        if (oldValue.equals(newValue)) {
            return 'stable';
        }

        // Map health scores to numeric values for comparison
        // Higher number = better health
        Map<String, Integer> healthScoreMap = new Map<String, Integer>{
            'At Risk' => 1,
            'Needs Attention' => 2,
            'Healthy' => 3,
            'Not Assessed' => 0
        };

        Integer oldScore = healthScoreMap.containsKey(oldValue) ? healthScoreMap.get(oldValue) : 0;
        Integer newScore = healthScoreMap.containsKey(newValue) ? healthScoreMap.get(newValue) : 0;

        // Compare scores to determine trend
        if (newScore > oldScore) {
            return 'improving'; // Health improved
        } else if (newScore < oldScore) {
            return 'declining'; // Health declined
        } else {
            return 'stable';
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
     * @description Helper method to get initials from a full name
     * @param fullName The full name to convert to initials
     * @return String initials (e.g., "John Doe" -> "JD")
     */
    private static String getInitials(String fullName) {
        if (String.isBlank(fullName)) {
            return 'NA';
        }

        List<String> nameParts = fullName.trim().split('\\s+');
        String initials = '';

        for (String part : nameParts) {
            if (String.isNotBlank(part)) {
                initials += part.substring(0, 1).toUpperCase();
            }
        }

        return String.isNotBlank(initials) ? initials : 'NA';
    }

    /**
     * @description Retrieves all open cases for modal display
     * @param accountId The Id of the Account record
     * @return List of CaseData wrapper objects
     */
    @AuraEnabled(cacheable=false)
    public static List<CaseData> getAllOpenCases(Id accountId) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }

            List<CaseData> caseList = new List<CaseData>();

            List<Case> cases = [
                SELECT Id, CaseNumber, Subject, Status, Priority, Owner.Name,
                       CreatedDate, IsEscalated
                FROM Case
                WHERE AccountId = :accountId
                AND IsClosed = false
                ORDER BY IsEscalated DESC, Priority DESC, CreatedDate ASC
                LIMIT 100
            ];

            for (Case c : cases) {
                CaseData caseData = new CaseData();
                caseData.caseId = c.Id;
                caseData.caseNumber = c.CaseNumber;
                caseData.subject = c.Subject;
                caseData.status = c.Status;
                caseData.priority = c.Priority;
                caseData.ownerName = c.Owner.Name;
                caseData.isEscalated = c.IsEscalated;
                caseData.age = c.CreatedDate.date().daysBetween(Date.today());
                caseList.add(caseData);
            }

            return caseList;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving all cases: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves all open tasks for modal display, overdue and due-today first
     * @param accountId The Id of the Account record
     * @return List of ActivityData wrapper objects
     */
    @AuraEnabled(cacheable=false)
    public static List<ActivityData> getAllOpenTasks(Id accountId) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }

            List<ActivityData> activityList = new List<ActivityData>();

            List<Task> tasks = [
                SELECT Id, Subject, ActivityDate, Owner.Name, Status
                FROM Task
                WHERE WhatId = :accountId
                AND IsClosed = false
                ORDER BY ActivityDate ASC NULLS LAST
                LIMIT 100
            ];

            Date today = Date.today();
            for (Task t : tasks) {
                ActivityData activity = new ActivityData();
                activity.activityId = t.Id;
                activity.subject = t.Subject;
                activity.activityType = 'Task';
                activity.activityDate = t.ActivityDate != null ? t.ActivityDate.format() : '';
                activity.activityDateValue = t.ActivityDate;
                activity.ownerName = t.Owner.Name;
                activity.status = t.Status;
                activity.isOverdue = t.ActivityDate != null && t.ActivityDate < today;
                activity.isDueToday = t.ActivityDate != null && t.ActivityDate == today;

                if (activity.isOverdue) {
                    activity.daysOverdue = t.ActivityDate.daysBetween(today);
                }

                activityList.add(activity);
            }

            return activityList;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving open tasks: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves all opportunities for modal display
     * @param accountId The Id of the Account record
     * @return List of OpportunityData wrapper objects
     */
    @AuraEnabled(cacheable=false)
    public static List<OpportunityData> getAllOpportunities(Id accountId) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }

            List<OpportunityData> oppList = new List<OpportunityData>();

            List<Opportunity> opportunities = [
                SELECT Id, Name, StageName, CloseDate, Amount, Owner.Name, Probability
                FROM Opportunity
                WHERE AccountId = :accountId
                AND IsClosed = false
                ORDER BY CloseDate ASC
                LIMIT 100
            ];

            for (Opportunity opp : opportunities) {
                OpportunityData oppData = new OpportunityData();
                oppData.opportunityId = opp.Id;
                oppData.name = opp.Name;
                oppData.stageName = opp.StageName;
                oppData.closeDate = opp.CloseDate != null ? opp.CloseDate.format() : '';
                oppData.amount = opp.Amount;
                oppData.ownerName = opp.Owner.Name;
                oppData.probability = opp.Probability != null ? Integer.valueOf(opp.Probability) : null;
                oppList.add(oppData);
            }

            return oppList;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving opportunities: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves contacts for list view
     * @param accountId The Id of the Account record
     * @param recordLimit Maximum number of records to return (default 10)
     * @return List of ContactData wrapper objects
     */
    @AuraEnabled(cacheable=false)
    public static List<ContactData> getContacts(Id accountId, Integer recordLimit) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }

            if (recordLimit == null || recordLimit <= 0) {
                recordLimit = 10;
            }

            List<ContactData> contactList = new List<ContactData>();

            List<Contact> contacts = [
                SELECT Id, Name, Title, Email, Phone, Owner.Name
                FROM Contact
                WHERE AccountId = :accountId
                ORDER BY Name ASC
                LIMIT :recordLimit
            ];

            Set<Id> contactIds = new Set<Id>();
            for (Contact c : contacts) {
                contactIds.add(c.Id);
            }

            Map<Id, Date> lastActivityByContact = new Map<Id, Date>();

            for (Task t : [
                SELECT WhoId, ActivityDate
                FROM Task
                WHERE WhoId IN :contactIds
                AND IsClosed = true
                AND ActivityDate != null
                ORDER BY ActivityDate DESC
            ]) {
                if (!lastActivityByContact.containsKey(t.WhoId)) {
                    lastActivityByContact.put(t.WhoId, t.ActivityDate);
                }
            }

            for (Event ev : [
                SELECT WhoId, ActivityDate
                FROM Event
                WHERE WhoId IN :contactIds
                AND ActivityDate != null
                ORDER BY ActivityDate DESC
            ]) {
                if (!lastActivityByContact.containsKey(ev.WhoId) ||
                    ev.ActivityDate > lastActivityByContact.get(ev.WhoId)) {
                    lastActivityByContact.put(ev.WhoId, ev.ActivityDate);
                }
            }

            for (Contact c : contacts) {
                ContactData contactData = new ContactData();
                contactData.contactId = c.Id;
                contactData.name = c.Name;
                contactData.title = c.Title;
                contactData.email = c.Email;
                contactData.phone = c.Phone;
                contactData.ownerName = c.Owner.Name;

                Date lastDate = lastActivityByContact.get(c.Id);
                contactData.lastActivityDate = lastDate != null ? lastDate.format() : null;

                contactList.add(contactData);
            }

            return contactList;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving contacts: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves open opportunities for list view
     * @param accountId The Id of the Account record
     * @param recordLimit Maximum number of records to return (default 10)
     * @return List of OpportunityData wrapper objects
     */
    @AuraEnabled(cacheable=false)
    public static List<OpportunityData> getOpenOpportunities(Id accountId, Integer recordLimit) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }

            if (recordLimit == null || recordLimit <= 0) {
                recordLimit = 10;
            }

            List<OpportunityData> oppList = new List<OpportunityData>();

            List<Opportunity> opportunities = [
                SELECT Id, Name, StageName, CloseDate, Amount, Owner.Name, Probability
                FROM Opportunity
                WHERE AccountId = :accountId
                AND IsClosed = false
                ORDER BY CloseDate ASC
                LIMIT :recordLimit
            ];

            for (Opportunity opp : opportunities) {
                OpportunityData oppData = new OpportunityData();
                oppData.opportunityId = opp.Id;
                oppData.name = opp.Name;
                oppData.stageName = opp.StageName;
                oppData.closeDate = opp.CloseDate != null ? opp.CloseDate.format() : '';
                oppData.amount = opp.Amount;
                oppData.ownerName = opp.Owner.Name;
                oppData.probability = opp.Probability != null ? Integer.valueOf(opp.Probability) : null;
                oppList.add(oppData);
            }

            return oppList;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving open opportunities: ' + e.getMessage());
        }
    }

    /**
     * @description Closed-won opportunities for commercial drilldown (all-time, calendar YTD, or prior calendar year)
     * @param scopeFilter ALL_TIME, YTD, or PRIOR_YEAR
     */
    @AuraEnabled(cacheable=false)
    public static List<OpportunityData> getClosedWonOpportunities(Id accountId, String scopeFilter) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }

            String scope = String.isBlank(scopeFilter) ? 'ALL_TIME' : scopeFilter.trim().toUpperCase();

            Integer y = Date.today().year();
            Date ytdStart = Date.newInstance(y, 1, 1);
            Date ytdEnd = Date.newInstance(y, 12, 31);
            Integer py = y - 1;
            Date priorYearStart = Date.newInstance(py, 1, 1);
            Date priorYearEnd = Date.newInstance(py, 12, 31);

            List<Opportunity> opportunities;

            if (scope == 'YTD') {
                opportunities = [
                    SELECT Id, Name, StageName, CloseDate, Amount, Owner.Name, Probability
                    FROM Opportunity
                    WHERE AccountId = :accountId
                    AND IsClosed = true
                    AND IsWon = true
                    AND CloseDate >= :ytdStart
                    AND CloseDate <= :ytdEnd
                    ORDER BY CloseDate DESC
                    LIMIT 100
                ];
            } else if (scope == 'PRIOR_YEAR') {
                opportunities = [
                    SELECT Id, Name, StageName, CloseDate, Amount, Owner.Name, Probability
                    FROM Opportunity
                    WHERE AccountId = :accountId
                    AND IsClosed = true
                    AND IsWon = true
                    AND CloseDate >= :priorYearStart
                    AND CloseDate <= :priorYearEnd
                    ORDER BY CloseDate DESC
                    LIMIT 100
                ];
            } else {
                opportunities = [
                    SELECT Id, Name, StageName, CloseDate, Amount, Owner.Name, Probability
                    FROM Opportunity
                    WHERE AccountId = :accountId
                    AND IsClosed = true
                    AND IsWon = true
                    ORDER BY CloseDate DESC
                    LIMIT 100
                ];
            }

            List<OpportunityData> oppList = new List<OpportunityData>();
            for (Opportunity opp : opportunities) {
                OpportunityData oppData = new OpportunityData();
                oppData.opportunityId = opp.Id;
                oppData.name = opp.Name;
                oppData.stageName = opp.StageName;
                oppData.closeDate = opp.CloseDate != null ? opp.CloseDate.format() : '';
                oppData.amount = opp.Amount;
                oppData.ownerName = opp.Owner.Name;
                oppData.probability = opp.Probability != null ? Integer.valueOf(opp.Probability) : null;
                oppList.add(oppData);
            }

            return oppList;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving closed-won opportunities: ' + e.getMessage());
        }
    }

    /**
     * @description Cases created in the last N days (default 90) for support-volume drilldown
     */
    @AuraEnabled(cacheable=false)
    public static List<CaseData> getCasesOpenedInLastDays(Id accountId, Integer days) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }

            if (days == null || days <= 0) {
                days = 90;
            }

            DateTime cutoff = DateTime.now().addDays(-days);
            List<CaseData> caseList = new List<CaseData>();

            List<Case> cases = [
                SELECT Id, CaseNumber, Subject, Status, Priority, Owner.Name, CreatedDate, IsEscalated
                FROM Case
                WHERE AccountId = :accountId
                AND CreatedDate >= :cutoff
                ORDER BY CreatedDate DESC
                LIMIT 100
            ];

            for (Case c : cases) {
                CaseData caseData = new CaseData();
                caseData.caseId = c.Id;
                caseData.caseNumber = c.CaseNumber;
                caseData.subject = c.Subject;
                caseData.status = c.Status;
                caseData.priority = c.Priority;
                caseData.ownerName = c.Owner.Name;
                caseData.isEscalated = c.IsEscalated;
                caseData.age = c.CreatedDate.date().daysBetween(Date.today());
                caseList.add(caseData);
            }

            return caseList;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving recent cases: ' + e.getMessage());
        }
    }

    public class TaskPicklistValues {
        @AuraEnabled public List<PicklistOption> statusValues { get; set; }
        @AuraEnabled public List<PicklistOption> priorityValues { get; set; }
        @AuraEnabled public List<PicklistOption> typeValues { get; set; }
    }

    public class PicklistOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=true)
    public static TaskPicklistValues getTaskPicklistValues() {
        TaskPicklistValues result = new TaskPicklistValues();
        result.statusValues = new List<PicklistOption>();
        result.priorityValues = new List<PicklistOption>();
        result.typeValues = new List<PicklistOption>();

        Map<String, Schema.SObjectField> taskFields = Schema.SObjectType.Task.fields.getMap();
        for (Schema.PicklistEntry pe : taskFields.get('Status').getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                result.statusValues.add(new PicklistOption(pe.getLabel(), pe.getValue()));
            }
        }
        for (Schema.PicklistEntry pe : taskFields.get('Priority').getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                result.priorityValues.add(new PicklistOption(pe.getLabel(), pe.getValue()));
            }
        }
        for (Schema.PicklistEntry pe : taskFields.get('Type').getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                result.typeValues.add(new PicklistOption(pe.getLabel(), pe.getValue()));
            }
        }
        return result;
    }

    @AuraEnabled
    public static Id createTask(String fieldsJson) {
        try {
            Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(fieldsJson);
            Task t = new Task();
            if (fields.containsKey('Subject'))      t.Subject      = (String) fields.get('Subject');
            if (fields.containsKey('WhoId'))         t.WhoId        = (Id) fields.get('WhoId');
            if (fields.containsKey('WhatId'))        t.WhatId       = (Id) fields.get('WhatId');
            if (fields.containsKey('Status'))        t.Status       = (String) fields.get('Status');
            if (fields.containsKey('Priority'))      t.Priority     = (String) fields.get('Priority');
            if (fields.containsKey('Type'))          t.put('Type', (String) fields.get('Type'));
            if (fields.containsKey('OwnerId'))       t.OwnerId      = (Id) fields.get('OwnerId');
            if (fields.containsKey('Description'))   t.Description  = (String) fields.get('Description');
            if (fields.containsKey('ActivityDate') && fields.get('ActivityDate') != null) {
                t.ActivityDate = Date.valueOf((String) fields.get('ActivityDate'));
            }
            insert t;
            return t.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating task: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Id createEvent(String fieldsJson) {
        try {
            Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(fieldsJson);
            Event ev = new Event();
            if (fields.containsKey('Subject'))       ev.Subject      = (String) fields.get('Subject');
            if (fields.containsKey('WhoId'))          ev.WhoId       = (Id) fields.get('WhoId');
            if (fields.containsKey('WhatId'))         ev.WhatId      = (Id) fields.get('WhatId');
            if (fields.containsKey('Location'))       ev.Location    = (String) fields.get('Location');
            if (fields.containsKey('OwnerId'))        ev.OwnerId     = (Id) fields.get('OwnerId');
            if (fields.containsKey('Description'))    ev.Description = (String) fields.get('Description');
            if (fields.containsKey('IsAllDayEvent'))  ev.IsAllDayEvent = (Boolean) fields.get('IsAllDayEvent');

            if (ev.IsAllDayEvent == true) {
                if (fields.containsKey('ActivityDate') && fields.get('ActivityDate') != null) {
                    ev.ActivityDate = Date.valueOf((String) fields.get('ActivityDate'));
                }
            } else {
                if (fields.containsKey('StartDateTime') && fields.get('StartDateTime') != null) {
                    ev.StartDateTime = Datetime.valueOf(((String) fields.get('StartDateTime')).replace('T', ' '));
                }
                if (fields.containsKey('EndDateTime') && fields.get('EndDateTime') != null) {
                    ev.EndDateTime = Datetime.valueOf(((String) fields.get('EndDateTime')).replace('T', ' '));
                }
            }
            insert ev;
            return ev.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating event: ' + e.getMessage());
        }
    }
}
