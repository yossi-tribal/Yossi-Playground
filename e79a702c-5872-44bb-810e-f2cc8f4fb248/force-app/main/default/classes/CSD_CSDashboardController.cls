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

            return summary;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving dashboard summary: ' + e.getMessage());
        }
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
     * @description Retrieves overdue tasks for the specified Account
     * @param accountId The Id of the Account record
     * @param recordLimit Maximum number of records to return (default 5)
     * @return List of ActivityData wrapper objects
     */
    @AuraEnabled(cacheable=false)
    public static List<ActivityData> getOverdueTasks(Id accountId, Integer recordLimit) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }

            if (recordLimit == null || recordLimit <= 0) {
                recordLimit = 5;
            }

            List<ActivityData> activityList = new List<ActivityData>();

            List<Task> tasks = [
                SELECT Id, Subject, ActivityDate, Owner.Name, Status
                FROM Task
                WHERE WhatId = :accountId
                AND IsClosed = false
                AND ActivityDate < TODAY
                ORDER BY ActivityDate ASC
                LIMIT :recordLimit
            ];

            for (Task t : tasks) {
                ActivityData activity = new ActivityData();
                activity.activityId = t.Id;
                activity.subject = t.Subject;
                activity.activityType = 'Task';
                activity.activityDate = t.ActivityDate != null ? t.ActivityDate.format() : '';
                activity.ownerName = t.Owner.Name;
                activity.status = t.Status;

                // Calculate days overdue
                if (t.ActivityDate != null) {
                    activity.daysOverdue = t.ActivityDate.daysBetween(Date.today());
                }

                activityList.add(activity);
            }

            return activityList;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving overdue tasks: ' + e.getMessage());
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
     * @description Retrieves all overdue tasks for modal display
     * @param accountId The Id of the Account record
     * @return List of ActivityData wrapper objects
     */
    @AuraEnabled(cacheable=false)
    public static List<ActivityData> getAllOverdueTasks(Id accountId) {
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
                AND ActivityDate < TODAY
                ORDER BY ActivityDate ASC
                LIMIT 100
            ];

            for (Task t : tasks) {
                ActivityData activity = new ActivityData();
                activity.activityId = t.Id;
                activity.subject = t.Subject;
                activity.activityType = 'Task';
                activity.activityDate = t.ActivityDate != null ? t.ActivityDate.format() : '';
                activity.ownerName = t.Owner.Name;
                activity.status = t.Status;

                if (t.ActivityDate != null) {
                    activity.daysOverdue = t.ActivityDate.daysBetween(Date.today());
                }

                activityList.add(activity);
            }

            return activityList;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving all overdue tasks: ' + e.getMessage());
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
}
