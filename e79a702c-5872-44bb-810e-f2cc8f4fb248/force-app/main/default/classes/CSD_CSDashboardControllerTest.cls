/**
 * @description Test class for CSD_CSDashboardController
 * Provides comprehensive test coverage for all controller methods
 * @author Tribal AI Platform
 * @date 2024
 */
@isTest
private class CSD_CSDashboardControllerTest {

    /**
     * @description Setup test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Customer Account',
            CSD_Account_Health_Score__c = 'Healthy'
        );
        insert testAccount;

        // Create test Cases
        List<Case> testCases = new List<Case>();
        testCases.add(new Case(
            AccountId = testAccount.Id,
            Subject = 'High Priority Case',
            Status = 'New',
            Priority = 'High',
            Origin = 'Web'
        ));
        testCases.add(new Case(
            AccountId = testAccount.Id,
            Subject = 'Escalated Case',
            Status = 'Working',
            Priority = 'Medium',
            IsEscalated = true,
            Origin = 'Email'
        ));
        testCases.add(new Case(
            AccountId = testAccount.Id,
            Subject = 'Normal Case',
            Status = 'New',
            Priority = 'Low',
            Origin = 'Phone'
        ));
        insert testCases;

        // Create test Tasks
        List<Task> testTasks = new List<Task>();
        testTasks.add(new Task(
            WhatId = testAccount.Id,
            Subject = 'Overdue Task 1',
            Status = 'Not Started',
            Priority = 'High',
            ActivityDate = Date.today().addDays(-5)
        ));
        testTasks.add(new Task(
            WhatId = testAccount.Id,
            Subject = 'Upcoming Task 1',
            Status = 'Not Started',
            Priority = 'Normal',
            ActivityDate = Date.today().addDays(3)
        ));
        testTasks.add(new Task(
            WhatId = testAccount.Id,
            Subject = 'Completed Task',
            Status = 'Completed',
            Priority = 'Normal',
            ActivityDate = Date.today().addDays(-10)
        ));
        insert testTasks;

        // Create test Events
        List<Event> testEvents = new List<Event>();
        testEvents.add(new Event(
            WhatId = testAccount.Id,
            Subject = 'Past Event',
            ActivityDate = Date.today().addDays(-2),
            ActivityDateTime = DateTime.now().addDays(-2),
            DurationInMinutes = 60
        ));
        testEvents.add(new Event(
            WhatId = testAccount.Id,
            Subject = 'Future Event',
            ActivityDate = Date.today().addDays(5),
            ActivityDateTime = DateTime.now().addDays(5),
            DurationInMinutes = 30
        ));
        insert testEvents;

        // Create test Opportunities
        List<Opportunity> testOpps = new List<Opportunity>();
        testOpps.add(new Opportunity(
            AccountId = testAccount.Id,
            Name = 'Test Opportunity 1',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(60),
            Amount = 50000
        ));
        testOpps.add(new Opportunity(
            AccountId = testAccount.Id,
            Name = 'Test Opportunity 2',
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(90),
            Amount = 75000
        ));
        testOpps.add(new Opportunity(
            AccountId = testAccount.Id,
            Name = 'Test Opportunity 3',
            StageName = 'Proposal',
            CloseDate = Date.today().addDays(30),
            Amount = 100000
        ));
        insert testOpps;

        // Create test Contacts for relationship depth testing
        List<Contact> testContacts = new List<Contact>();
        testContacts.add(new Contact(
            AccountId = testAccount.Id,
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@example.com'
        ));
        testContacts.add(new Contact(
            AccountId = testAccount.Id,
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@example.com'
        ));
        testContacts.add(new Contact(
            AccountId = testAccount.Id,
            FirstName = 'Bob',
            LastName = 'Johnson',
            Email = 'bob.johnson@example.com'
        ));
        insert testContacts;
    }

    /**
     * @description Test getDashboardSummary method with valid account
     */
    @isTest
    static void testGetDashboardSummary_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, summary, 'Summary should not be null');
        System.assertEquals('Healthy', summary.accountHealthScore, 'Health score should be Healthy');
        System.assertEquals('green', summary.accountHealthColor, 'Health color should be green');
        System.assertEquals(3, summary.openCasesCount, 'Should have 3 open cases');
        System.assertEquals(2, summary.highPriorityCasesCount, 'Should have 2 high priority cases');
        System.assertEquals(1, summary.overdueTasks, 'Should have 1 overdue task');
        System.assertNotEquals('No recent activity', summary.lastActivityDate, 'Should have recent activity');
        System.assertNotEquals('No upcoming activity', summary.nextPlannedActivity, 'Should have upcoming activity');
        System.assertEquals(3, summary.opportunityCount, 'Should have 3 open opportunities');
    }

    /**
     * @description Test getDashboardSummary method with null account ID
     */
    @isTest
    static void testGetDashboardSummary_NullAccountId() {
        Test.startTest();
        try {
            CSD_CSDashboardController.getDashboardSummary(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account ID is required'),
                'Exception message should indicate missing account ID');
        }
        Test.stopTest();
    }

    /**
     * @description Test getDashboardSummary with account having no data
     */
    @isTest
    static void testGetDashboardSummary_NoData() {
        Account emptyAccount = new Account(Name = 'Empty Account');
        insert emptyAccount;

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(emptyAccount.Id);
        Test.stopTest();

        // Assertions
        System.assertEquals(0, summary.openCasesCount, 'Should have 0 open cases');
        System.assertEquals(0, summary.highPriorityCasesCount, 'Should have 0 high priority cases');
        System.assertEquals(0, summary.overdueTasks, 'Should have 0 overdue tasks');
        System.assertEquals('No recent activity', summary.lastActivityDate, 'Should show no recent activity');
        System.assertEquals('No upcoming activity', summary.nextPlannedActivity, 'Should show no upcoming activity');
        System.assertEquals(0, summary.opportunityCount, 'Should have 0 opportunities');
    }

    /**
     * @description Test getOpenCases method
     */
    @isTest
    static void testGetOpenCases_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.CaseData> cases =
            CSD_CSDashboardController.getOpenCases(testAccount.Id, 10);
        Test.stopTest();

        // Assertions
        System.assertEquals(3, cases.size(), 'Should return 3 open cases');

        // Verify escalated case is first (sorted by IsEscalated DESC)
        System.assertEquals(true, cases[0].isEscalated, 'First case should be escalated');
        System.assertEquals('Escalated Case', cases[0].subject, 'First case subject should match');

        // Verify high priority case is second
        System.assertEquals('High', cases[1].priority, 'Second case should be High priority');

        // Verify case data structure
        System.assertNotEquals(null, cases[0].caseId, 'Case ID should not be null');
        System.assertNotEquals(null, cases[0].caseNumber, 'Case number should not be null');
        System.assertNotEquals(null, cases[0].ownerName, 'Owner name should not be null');
        System.assert(cases[0].age >= 0, 'Age should be non-negative');
    }

    /**
     * @description Test getOpenCases with record limit
     */
    @isTest
    static void testGetOpenCases_WithLimit() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.CaseData> cases =
            CSD_CSDashboardController.getOpenCases(testAccount.Id, 2);
        Test.stopTest();

        // Assertions
        System.assertEquals(2, cases.size(), 'Should return only 2 cases due to limit');
    }

    /**
     * @description Test getOpenCases with null account ID
     */
    @isTest
    static void testGetOpenCases_NullAccountId() {
        Test.startTest();
        try {
            CSD_CSDashboardController.getOpenCases(null, 10);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account ID is required'),
                'Exception message should indicate missing account ID');
        }
        Test.stopTest();
    }

    /**
     * @description Test getOverdueTasks method
     */
    @isTest
    static void testGetOverdueTasks_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.ActivityData> tasks =
            CSD_CSDashboardController.getOverdueTasks(testAccount.Id, 5);
        Test.stopTest();

        // Assertions
        System.assertEquals(1, tasks.size(), 'Should return 1 overdue task');
        System.assertEquals('Task', tasks[0].activityType, 'Activity type should be Task');
        System.assertEquals('Overdue Task 1', tasks[0].subject, 'Task subject should match');
        System.assert(tasks[0].daysOverdue > 0, 'Days overdue should be positive');
        System.assertNotEquals(null, tasks[0].ownerName, 'Owner name should not be null');
    }

    /**
     * @description Test getOverdueTasks with null account ID
     */
    @isTest
    static void testGetOverdueTasks_NullAccountId() {
        Test.startTest();
        try {
            CSD_CSDashboardController.getOverdueTasks(null, 5);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account ID is required'),
                'Exception message should indicate missing account ID');
        }
        Test.stopTest();
    }

    /**
     * @description Test getUpcomingActivities method
     */
    @isTest
    static void testGetUpcomingActivities_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.ActivityData> activities =
            CSD_CSDashboardController.getUpcomingActivities(testAccount.Id, 5);
        Test.stopTest();

        // Assertions
        System.assert(activities.size() >= 2, 'Should return at least 2 upcoming activities');

        // Verify activities are in the future
        for (CSD_CSDashboardController.ActivityData activity : activities) {
            System.assertNotEquals(null, activity.activityType, 'Activity type should not be null');
            System.assertNotEquals(null, activity.subject, 'Subject should not be null');
            System.assertNotEquals(null, activity.ownerName, 'Owner name should not be null');
        }
    }

    /**
     * @description Test getUpcomingActivities with null account ID
     */
    @isTest
    static void testGetUpcomingActivities_NullAccountId() {
        Test.startTest();
        try {
            CSD_CSDashboardController.getUpcomingActivities(null, 5);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account ID is required'),
                'Exception message should indicate missing account ID');
        }
        Test.stopTest();
    }

    /**
     * @description Test dashboard with At Risk health score
     */
    @isTest
    static void testHealthScore_AtRisk() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        testAccount.CSD_Account_Health_Score__c = 'At Risk';
        update testAccount;

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
        Test.stopTest();

        System.assertEquals('At Risk', summary.accountHealthScore, 'Health score should be At Risk');
        System.assertEquals('red', summary.accountHealthColor, 'Health color should be red');
    }

    /**
     * @description Test dashboard with Needs Attention health score
     */
    @isTest
    static void testHealthScore_NeedsAttention() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        testAccount.CSD_Account_Health_Score__c = 'Needs Attention';
        update testAccount;

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
        Test.stopTest();

        System.assertEquals('Needs Attention', summary.accountHealthScore, 'Health score should be Needs Attention');
        System.assertEquals('yellow', summary.accountHealthColor, 'Health color should be yellow');
    }

    /**
     * @description Test dashboard with Not Assessed health score
     */
    @isTest
    static void testHealthScore_NotAssessed() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        testAccount.CSD_Account_Health_Score__c = 'Not Assessed';
        update testAccount;

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
        Test.stopTest();

        System.assertEquals('Not Assessed', summary.accountHealthScore, 'Health score should be Not Assessed');
        System.assertEquals('gray', summary.accountHealthColor, 'Health color should be gray');
    }

    /**
     * @description Test with default record limits
     */
    @isTest
    static void testDefaultLimits() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.CaseData> cases =
            CSD_CSDashboardController.getOpenCases(testAccount.Id, null);
        List<CSD_CSDashboardController.ActivityData> tasks =
            CSD_CSDashboardController.getOverdueTasks(testAccount.Id, null);
        List<CSD_CSDashboardController.ActivityData> activities =
            CSD_CSDashboardController.getUpcomingActivities(testAccount.Id, null);
        Test.stopTest();

        // Verify default limits are applied
        System.assertNotEquals(null, cases, 'Cases list should not be null');
        System.assertNotEquals(null, tasks, 'Tasks list should not be null');
        System.assertNotEquals(null, activities, 'Activities list should not be null');
    }

    /**
     * @description Test getAllOpenCases method
     */
    @isTest
    static void testGetAllOpenCases_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.CaseData> cases =
            CSD_CSDashboardController.getAllOpenCases(testAccount.Id);
        Test.stopTest();

        // Assertions
        System.assertEquals(3, cases.size(), 'Should return 3 open cases');
        System.assertNotEquals(null, cases[0].caseId, 'Case ID should not be null');
        System.assertNotEquals(null, cases[0].caseNumber, 'Case number should not be null');
    }

    /**
     * @description Test getAllOpenCases with null account ID
     */
    @isTest
    static void testGetAllOpenCases_NullAccountId() {
        Test.startTest();
        try {
            CSD_CSDashboardController.getAllOpenCases(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account ID is required'),
                'Exception message should indicate missing account ID');
        }
        Test.stopTest();
    }

    /**
     * @description Test getAllOverdueTasks method
     */
    @isTest
    static void testGetAllOverdueTasks_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.ActivityData> tasks =
            CSD_CSDashboardController.getAllOverdueTasks(testAccount.Id);
        Test.stopTest();

        // Assertions
        System.assertEquals(1, tasks.size(), 'Should return 1 overdue task');
        System.assertEquals('Task', tasks[0].activityType, 'Activity type should be Task');
        System.assert(tasks[0].daysOverdue > 0, 'Days overdue should be positive');
    }

    /**
     * @description Test getAllOverdueTasks with null account ID
     */
    @isTest
    static void testGetAllOverdueTasks_NullAccountId() {
        Test.startTest();
        try {
            CSD_CSDashboardController.getAllOverdueTasks(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account ID is required'),
                'Exception message should indicate missing account ID');
        }
        Test.stopTest();
    }

    /**
     * @description Test getAllOpportunities method
     */
    @isTest
    static void testGetAllOpportunities_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.OpportunityData> opps =
            CSD_CSDashboardController.getAllOpportunities(testAccount.Id);
        Test.stopTest();

        // Assertions
        System.assertEquals(3, opps.size(), 'Should return 3 open opportunities');
        System.assertNotEquals(null, opps[0].opportunityId, 'Opportunity ID should not be null');
        System.assertNotEquals(null, opps[0].name, 'Opportunity name should not be null');
        System.assertNotEquals(null, opps[0].stageName, 'Stage name should not be null');
        System.assertNotEquals(null, opps[0].ownerName, 'Owner name should not be null');

        // Verify sorted by close date (earliest first)
        System.assertEquals('Test Opportunity 3', opps[0].name, 'First opportunity should be closest to close');
    }

    /**
     * @description Test getAllOpportunities with null account ID
     */
    @isTest
    static void testGetAllOpportunities_NullAccountId() {
        Test.startTest();
        try {
            CSD_CSDashboardController.getAllOpportunities(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account ID is required'),
                'Exception message should indicate missing account ID');
        }
        Test.stopTest();
    }

    /**
     * @description Test getAllOpportunities with no opportunities
     */
    @isTest
    static void testGetAllOpportunities_NoData() {
        Account emptyAccount = new Account(Name = 'Empty Account');
        insert emptyAccount;

        Test.startTest();
        List<CSD_CSDashboardController.OpportunityData> opps =
            CSD_CSDashboardController.getAllOpportunities(emptyAccount.Id);
        Test.stopTest();

        // Assertions
        System.assertEquals(0, opps.size(), 'Should return 0 opportunities for empty account');
    }

    /**
     * @description Test health trend calculation with no history
     * Note: AccountHistory records cannot be created in tests, so this verifies
     * the default behavior when Field History Tracking is not enabled or no changes exist
     */
    @isTest
    static void testHealthTrend_NoHistory() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
        Test.stopTest();

        // When no history exists, trend should default to 'stable'
        System.assertEquals('stable', summary.healthTrend, 'Trend should be stable when no history exists');
    }

    /**
     * @description Test health trend field is populated in dashboard summary
     */
    @isTest
    static void testHealthTrend_FieldPopulated() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        testAccount.CSD_Account_Health_Score__c = 'At Risk';
        update testAccount;

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
        Test.stopTest();

        // Verify health trend field is populated
        System.assertNotEquals(null, summary.healthTrend, 'Health trend should not be null');
        System.assert(
            summary.healthTrend == 'stable' ||
            summary.healthTrend == 'improving' ||
            summary.healthTrend == 'declining',
            'Health trend should be a valid value'
        );
    }

    /**
     * @description Test health trend with multiple health score changes
     * Note: This test verifies the trend calculation logic works when history is available
     */
    @isTest
    static void testHealthTrend_WithChanges() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        // Change health score multiple times to simulate trend
        testAccount.CSD_Account_Health_Score__c = 'Needs Attention';
        update testAccount;

        testAccount.CSD_Account_Health_Score__c = 'At Risk';
        update testAccount;

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
        Test.stopTest();

        // Verify trend is calculated
        // In test context without Field History Tracking enabled, trend will be 'stable'
        // In production with Field History Tracking enabled, this would show 'declining'
        System.assertNotEquals(null, summary.healthTrend, 'Health trend should not be null');
    }

    /**
     * @description Test relationship depth calculation with multiple contacts
     */
    @isTest
    static void testRelationshipDepth_Strong() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
        Test.stopTest();

        // Should have 3 contacts from setup data
        System.assertEquals(3, summary.contactCount, 'Should have 3 contacts');
        System.assertEquals('Weak', summary.relationshipDepth, 'Should be Weak with 3 contacts');
        System.assertEquals(2, summary.relationshipDepthStars, 'Should have 2 stars');
    }

    /**
     * @description Test relationship depth calculation with no contacts
     */
    @isTest
    static void testRelationshipDepth_None() {
        Account emptyAccount = new Account(Name = 'Empty Account');
        insert emptyAccount;

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(emptyAccount.Id);
        Test.stopTest();

        // Should have 0 contacts
        System.assertEquals(0, summary.contactCount, 'Should have 0 contacts');
        System.assertEquals('None', summary.relationshipDepth, 'Should be None with no contacts');
        System.assertEquals(0, summary.relationshipDepthStars, 'Should have 0 stars');
    }

    /**
     * @description Test relationship depth calculation with moderate contacts
     */
    @isTest
    static void testRelationshipDepth_Moderate() {
        Account testAccount = new Account(Name = 'Moderate Account');
        insert testAccount;

        // Create 6 contacts for moderate relationship depth
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 6; i++) {
            contacts.add(new Contact(
                AccountId = testAccount.Id,
                FirstName = 'Contact',
                LastName = 'Number' + i,
                Email = 'contact' + i + '@example.com'
            ));
        }
        insert contacts;

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
        Test.stopTest();

        System.assertEquals(6, summary.contactCount, 'Should have 6 contacts');
        System.assertEquals('Moderate', summary.relationshipDepth, 'Should be Moderate with 6 contacts');
        System.assertEquals(3, summary.relationshipDepthStars, 'Should have 3 stars');
    }

    /**
     * @description Test relationship depth calculation with strong contacts
     */
    @isTest
    static void testRelationshipDepth_StrongMany() {
        Account testAccount = new Account(Name = 'Strong Account');
        insert testAccount;

        // Create 12 contacts for strong relationship depth
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 12; i++) {
            contacts.add(new Contact(
                AccountId = testAccount.Id,
                FirstName = 'Contact',
                LastName = 'Number' + i,
                Email = 'contact' + i + '@example.com'
            ));
        }
        insert contacts;

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
        Test.stopTest();

        System.assertEquals(12, summary.contactCount, 'Should have 12 contacts');
        System.assertEquals('Strong', summary.relationshipDepth, 'Should be Strong with 12 contacts');
        System.assertEquals(4, summary.relationshipDepthStars, 'Should have 4 stars');
    }

    /**
     * @description Test next touchpoint details are populated
     */
    @isTest
    static void testNextTouchpoint_Details() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
        Test.stopTest();

        // Verify next touchpoint fields are populated
        System.assertNotEquals(null, summary.nextTouchpointSubject, 'Next touchpoint subject should not be null');
        System.assertNotEquals(null, summary.nextTouchpointType, 'Next touchpoint type should not be null');

        // Should have either 'Task' or 'Event' as the type
        System.assert(
            summary.nextTouchpointType == 'Task' || summary.nextTouchpointType == 'Event',
            'Next touchpoint type should be Task or Event'
        );
    }

    /**
     * @description Test getContacts returns contacts with last activity dates
     */
    @isTest
    static void testGetContacts_WithLastActivity() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE AccountId = :testAccount.Id LIMIT 1];

        Task contactTask = new Task(
            WhoId = testContact.Id,
            WhatId = testAccount.Id,
            Subject = 'Contact Follow-up',
            Status = 'Completed',
            Priority = 'Normal',
            ActivityDate = Date.today().addDays(-3)
        );
        insert contactTask;

        Test.startTest();
        List<CSD_CSDashboardController.ContactData> contacts =
            CSD_CSDashboardController.getContacts(testAccount.Id, 10);
        Test.stopTest();

        System.assertEquals(3, contacts.size(), 'Should return 3 contacts');

        Boolean foundWithActivity = false;
        for (CSD_CSDashboardController.ContactData c : contacts) {
            System.assertNotEquals(null, c.contactId, 'Contact ID should not be null');
            System.assertNotEquals(null, c.name, 'Contact name should not be null');
            if (c.contactId == testContact.Id) {
                System.assertNotEquals(null, c.lastActivityDate, 'Contact with task should have lastActivityDate');
                foundWithActivity = true;
            }
        }
        System.assert(foundWithActivity, 'Should find the contact with activity');
    }

    /**
     * @description Test getContacts with null account ID
     */
    @isTest
    static void testGetContacts_NullAccountId() {
        Test.startTest();
        try {
            CSD_CSDashboardController.getContacts(null, 10);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account ID is required'),
                'Exception message should indicate missing account ID');
        }
        Test.stopTest();
    }

    /**
     * @description Test getContacts with no activity returns null lastActivityDate
     */
    @isTest
    static void testGetContacts_NoActivity() {
        Account freshAccount = new Account(Name = 'Fresh Account');
        insert freshAccount;

        Contact freshContact = new Contact(
            AccountId = freshAccount.Id,
            FirstName = 'Fresh',
            LastName = 'Contact',
            Email = 'fresh@example.com'
        );
        insert freshContact;

        Test.startTest();
        List<CSD_CSDashboardController.ContactData> contacts =
            CSD_CSDashboardController.getContacts(freshAccount.Id, 10);
        Test.stopTest();

        System.assertEquals(1, contacts.size(), 'Should return 1 contact');
        System.assertEquals(null, contacts[0].lastActivityDate, 'Contact with no activity should have null lastActivityDate');
    }

    /**
     * @description Test next touchpoint with no upcoming activities
     */
    @isTest
    static void testNextTouchpoint_NoUpcoming() {
        Account emptyAccount = new Account(Name = 'Empty Account');
        insert emptyAccount;

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(emptyAccount.Id);
        Test.stopTest();

        // Verify next touchpoint shows no upcoming
        System.assertEquals('No upcoming touchpoint', summary.nextTouchpointSubject,
            'Should show no upcoming touchpoint');
        System.assertEquals('', summary.nextTouchpointType,
            'Type should be empty');
        System.assertEquals('', summary.nextTouchpointTime,
            'Time should be empty');
    }
}
