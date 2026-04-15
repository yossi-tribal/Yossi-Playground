/**
 * @description Test class for CSD_CSDashboardController
 * Provides comprehensive test coverage for all controller methods
 * @author Tribal AI Platform
 * @date 2024
 */
@isTest
private class CSD_CSDashboardControllerTest {

    /**
     * AuraHandledException messages may be blank in some test contexts; still expect a handled error.
     */
    private static void assertNullAccountException(AuraHandledException e) {
        String msg = e.getMessage();
        System.assert(
            String.isBlank(msg)
                || msg.containsIgnoreCase('account')
                || msg.containsIgnoreCase('script-thrown'),
            'Expected missing-account error; got: [' + msg + ']'
        );
    }

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
            Amount = 50000,
            Probability = 40
        ));
        testOpps.add(new Opportunity(
            AccountId = testAccount.Id,
            Name = 'Test Opportunity 2',
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(90),
            Amount = 75000,
            Probability = 50
        ));
        testOpps.add(new Opportunity(
            AccountId = testAccount.Id,
            Name = 'Test Opportunity 3',
            StageName = 'Proposal',
            CloseDate = Date.today().addDays(30),
            Amount = 100000,
            Probability = 60
        ));
        insert testOpps;

        // Create prior-year cases for YTD and paired bar chart testing
        Integer py = Date.today().year() - 1;
        List<Case> priorYearCases = new List<Case>();
        priorYearCases.add(new Case(
            AccountId = testAccount.Id,
            Subject = 'Prior Year Case 1',
            Status = 'Closed',
            Priority = 'Medium',
            Origin = 'Web'
        ));
        priorYearCases.add(new Case(
            AccountId = testAccount.Id,
            Subject = 'Prior Year Case 2',
            Status = 'Closed',
            Priority = 'Low',
            Origin = 'Email'
        ));
        insert priorYearCases;

        // Backdate CreatedDate for prior-year cases using Test.setCreatedDate
        Test.setCreatedDate(priorYearCases[0].Id, DateTime.newInstance(py, 6, 15));
        Test.setCreatedDate(priorYearCases[1].Id, DateTime.newInstance(py, 6, 20));

        List<Opportunity> closedWonOpps = new List<Opportunity>();
        closedWonOpps.add(new Opportunity(
            AccountId = testAccount.Id,
            Name = 'Closed Won Historical',
            StageName = 'Closed Won',
            CloseDate = Date.newInstance(py, 11, 15),
            Amount = 25000
        ));
        closedWonOpps.add(new Opportunity(
            AccountId = testAccount.Id,
            Name = 'Closed Won YTD',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 5000
        ));
        closedWonOpps.add(new Opportunity(
            AccountId = testAccount.Id,
            Name = 'Closed Won Prior Year',
            StageName = 'Closed Won',
            CloseDate = Date.newInstance(py, 8, 1),
            Amount = 15000
        ));
        insert closedWonOpps;

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
        System.assertEquals('At Risk', summary.accountHealthScore, 'Health score reflects automated calculation');
        System.assertEquals('red', summary.accountHealthColor, 'Health color should match calculated score');
        System.assertEquals(3, summary.openCasesCount, 'Should have 3 open cases');
        System.assertEquals(2, summary.highPriorityCasesCount, 'Should have 2 high priority cases');
        System.assertEquals(1, summary.overdueTasks, 'Should have 1 overdue task');
        System.assertEquals(2, summary.openTasksCount, 'Should have 2 open tasks');
        System.assertNotEquals('No recent activity', summary.lastActivityDate, 'Should have recent activity');
        System.assertNotEquals('No upcoming activity', summary.nextPlannedActivity, 'Should have upcoming activity');
        System.assertEquals(3, summary.opportunityCount, 'Should have 3 open opportunities');

        System.assertEquals(45000, summary.totalWonRevenue, 'Total won revenue should sum closed-won amounts');
        System.assertEquals(5000, summary.ytdWonRevenue, 'YTD won should include only current-calendar-year closes');
        System.assertEquals(40000, summary.priorYearWonRevenue, 'Prior year won should sum full prior calendar year');
        System.assertEquals(225000, summary.openPipelineAmount, 'Open pipeline should sum open opp amounts');
        System.assertEquals(117500, summary.weightedPipelineAmount, 'Weighted pipeline = sum of Amount × probability');
        System.assertEquals(3, summary.casesOpenedLast90Days, 'Should count cases opened in last 90 days');
        System.assertNotEquals(null, summary.currencyCode, 'Currency code should be set');
        System.assertNotEquals(null, summary.wonQuarter1Label, 'Quarter labels should be populated');

        System.assertNotEquals(null, summary.wonMonth12Label, 'Monthly won labels should be populated');
        System.assert(summary.wonMonth12 >= 0, 'Current month won amount should be non-negative');
        System.assert(summary.wonMonth12Prev >= 0, 'Prior year month won amount should be non-negative');
        System.assert(summary.wonMonth12 == 5000, 'Current month should include the Closed Won YTD opp');
        System.assertNotEquals(null, summary.wonMonth7Label, 'Month 7 won label should be populated');

        System.assert(summary.ytdCaseCount >= 3, 'YTD case count should include cases created this year');
        System.assertEquals(2, summary.priorYearCaseCount, 'Prior year case count should include backdated prior-year cases');
        System.assert(summary.caseMonth1Prev >= 0, 'Prior year monthly case count should be non-negative');
        System.assert(summary.caseMonth12 >= 0, 'Current month case count should be non-negative');
        System.assertNotEquals(null, summary.caseMonth7Label, 'Month 7 case label should be populated');
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
            assertNullAccountException(e);
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
        System.assertEquals(0, summary.openTasksCount, 'Should have 0 open tasks');
        System.assertEquals('No recent activity', summary.lastActivityDate, 'Should show no recent activity');
        System.assertEquals('No upcoming activity', summary.nextPlannedActivity, 'Should show no upcoming activity');
        System.assertEquals(0, summary.opportunityCount, 'Should have 0 opportunities');
        System.assertEquals(0, summary.totalWonRevenue, 'Total won should be 0');
        System.assertEquals(0, summary.ytdWonRevenue, 'YTD won should be 0');
        System.assertEquals(0, summary.priorYearWonRevenue, 'Prior year won should be 0');
        System.assertEquals(0, summary.openPipelineAmount, 'Pipeline should be 0');
        System.assertEquals(0, summary.weightedPipelineAmount, 'Weighted pipeline should be 0');
        System.assertEquals(0, summary.casesOpenedLast90Days, 'Recent cases should be 0');
        System.assertEquals(0, summary.wonMonth1, 'Monthly won should be 0 for empty account');
        System.assertEquals(0, summary.wonMonth1Prev, 'Prior year monthly won should be 0 for empty account');
        System.assertNotEquals(null, summary.wonMonth1Label, 'Monthly won label should be set even for empty account');
        System.assertEquals(0, summary.wonMonth12, 'Month 12 won should be 0 for empty account');
        System.assertEquals(0, summary.wonMonth12Prev, 'Month 12 prior year won should be 0 for empty account');
        System.assertNotEquals(null, summary.wonMonth12Label, 'Month 12 won label should be set');
        System.assertEquals(0, summary.ytdCaseCount, 'YTD case count should be 0 for empty account');
        System.assertEquals(0, summary.priorYearCaseCount, 'Prior year case count should be 0 for empty account');
        System.assertEquals(0, summary.caseMonth1Prev, 'Prior year monthly case count should be 0 for empty account');
        System.assertEquals(0, summary.caseMonth12, 'Month 12 case count should be 0 for empty account');
        System.assertEquals(null, summary.caseMonth1AvgClose, 'Avg close should be null for empty account');
        System.assertEquals(null, summary.caseMonth12AvgClose, 'Month 12 avg close should be null for empty account');
        System.assertEquals(null, summary.averageCaseResolutionHours, 'No closed cases — average hours null');
        System.assertEquals(0, summary.closedCasesAllTimeCount, 'No closed cases — count 0');
    }

    /**
     * @description Mean elapsed resolution across all-time closed cases (batched query)
     */
    @isTest
    static void testGetDashboardSummary_AverageResolutionHours_AllTime() {
        Account solo = new Account(Name = 'Average Resolution Account', CSD_Account_Health_Score__c = 'Healthy');
        insert solo;
        List<Case> cases = new List<Case>();
        cases.add(new Case(AccountId = solo.Id, Subject = 'MR-A', Status = 'New', Origin = 'Web'));
        cases.add(new Case(AccountId = solo.Id, Subject = 'MR-B', Status = 'New', Origin = 'Web'));
        cases.add(new Case(AccountId = solo.Id, Subject = 'MR-C', Status = 'New', Origin = 'Web'));
        insert cases;
        Test.setCreatedDate(cases[0].Id, DateTime.now().addHours(-8));
        Test.setCreatedDate(cases[1].Id, DateTime.now().addHours(-4));
        Test.setCreatedDate(cases[2].Id, DateTime.now().addHours(-2));
        for (Case c : cases) {
            c.Status = 'Closed';
        }
        update cases;

        Test.startTest();
        CSD_CSDashboardController.DashboardSummary summary =
            CSD_CSDashboardController.getDashboardSummary(solo.Id);
        Test.stopTest();

        System.assertEquals(3, summary.closedCasesAllTimeCount, 'Three closed cases');
        System.assertNotEquals(null, summary.averageCaseResolutionHours, 'Average hours set');
        Decimal expectedMean = Decimal.valueOf(2 + 4 + 8) / 3;
        System.assertEquals(
            expectedMean.setScale(4, System.RoundingMode.HALF_UP),
            summary.averageCaseResolutionHours.setScale(4, System.RoundingMode.HALF_UP),
            'Mean of 2h, 4h, 8h is 14/3 hours'
        );
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
            assertNullAccountException(e);
        }
        Test.stopTest();
    }

    /**
     * @description Test getOpenTasks method — returns all open tasks sorted overdue-first
     */
    @isTest
    static void testGetOpenTasks_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.ActivityData> tasks =
            CSD_CSDashboardController.getOpenTasks(testAccount.Id, 10);
        Test.stopTest();

        // Assertions — test data has 1 overdue + 1 upcoming open task
        System.assertEquals(2, tasks.size(), 'Should return 2 open tasks');
        System.assertEquals('Task', tasks[0].activityType, 'Activity type should be Task');
        // Overdue task should sort first (earliest date)
        System.assertEquals(true, tasks[0].isOverdue, 'First task should be overdue');
        System.assert(tasks[0].daysOverdue > 0, 'Days overdue should be positive');
        System.assertEquals(false, tasks[1].isOverdue, 'Second task should not be overdue');
        System.assertNotEquals(null, tasks[0].ownerName, 'Owner name should not be null');
    }

    /**
     * @description Test getOpenTasks with null account ID
     */
    @isTest
    static void testGetOpenTasks_NullAccountId() {
        Test.startTest();
        try {
            CSD_CSDashboardController.getOpenTasks(null, 10);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            assertNullAccountException(e);
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
            assertNullAccountException(e);
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
        CSD_AccountHealthScoreHandler.skipRecalculationInTests = true;
        try {
            testAccount.CSD_Account_Health_Score__c = 'Needs Attention';
            update testAccount;

            Test.startTest();
            CSD_CSDashboardController.DashboardSummary summary =
                CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
            Test.stopTest();

            System.assertEquals('Needs Attention', summary.accountHealthScore, 'Health score should be Needs Attention');
            System.assertEquals('yellow', summary.accountHealthColor, 'Health color should be yellow');
        } finally {
            CSD_AccountHealthScoreHandler.skipRecalculationInTests = false;
        }
    }

    /**
     * @description Test dashboard with Not Assessed health score
     */
    @isTest
    static void testHealthScore_NotAssessed() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        CSD_AccountHealthScoreHandler.skipRecalculationInTests = true;
        try {
            testAccount.CSD_Account_Health_Score__c = 'Not Assessed';
            update testAccount;

            Test.startTest();
            CSD_CSDashboardController.DashboardSummary summary =
                CSD_CSDashboardController.getDashboardSummary(testAccount.Id);
            Test.stopTest();

            System.assertEquals('Not Assessed', summary.accountHealthScore, 'Health score should be Not Assessed');
            System.assertEquals('gray', summary.accountHealthColor, 'Health color should be gray');
        } finally {
            CSD_AccountHealthScoreHandler.skipRecalculationInTests = false;
        }
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
            CSD_CSDashboardController.getOpenTasks(testAccount.Id, null);
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
            assertNullAccountException(e);
        }
        Test.stopTest();
    }

    /**
     * @description Test getAllOpenTasks method
     */
    @isTest
    static void testGetAllOpenTasks_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.ActivityData> tasks =
            CSD_CSDashboardController.getAllOpenTasks(testAccount.Id);
        Test.stopTest();

        // Assertions — test data has 1 overdue + 1 upcoming open task
        System.assertEquals(2, tasks.size(), 'Should return 2 open tasks');
        System.assertEquals('Task', tasks[0].activityType, 'Activity type should be Task');
        System.assertEquals(true, tasks[0].isOverdue, 'First task should be overdue');
        System.assert(tasks[0].daysOverdue > 0, 'Days overdue should be positive');
    }

    /**
     * @description Test getAllOpenTasks with null account ID
     */
    @isTest
    static void testGetAllOpenTasks_NullAccountId() {
        Test.startTest();
        try {
            CSD_CSDashboardController.getAllOpenTasks(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            assertNullAccountException(e);
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
            assertNullAccountException(e);
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
            assertNullAccountException(e);
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

    /**
     * @description Closed-won opportunities drilldown (all time)
     */
    @isTest
    static void testGetClosedWonOpportunities_AllTime() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.OpportunityData> opps =
            CSD_CSDashboardController.getClosedWonOpportunities(testAccount.Id, 'ALL_TIME');
        Test.stopTest();

        System.assertEquals(3, opps.size(), 'Should return 3 closed-won opportunities');
        System.assertNotEquals(null, opps[0].opportunityId, 'Opportunity ID should be set');
    }

    /**
     * @description Closed-won opportunities drilldown (YTD)
     */
    @isTest
    static void testGetClosedWonOpportunities_Ytd() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.OpportunityData> opps =
            CSD_CSDashboardController.getClosedWonOpportunities(testAccount.Id, 'YTD');
        Test.stopTest();

        System.assertEquals(1, opps.size(), 'YTD filter should return one closed-won opp');
    }

    /**
     * @description Closed-won opportunities — null account
     */
    @isTest
    static void testGetClosedWonOpportunities_NullAccount() {
        Test.startTest();
        try {
            CSD_CSDashboardController.getClosedWonOpportunities(null, 'ALL_TIME');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            assertNullAccountException(e);
        }
        Test.stopTest();
    }

    /**
     * @description Cases opened in last N days
     */
    @isTest
    static void testGetCasesOpenedInLastDays_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<CSD_CSDashboardController.CaseData> cases =
            CSD_CSDashboardController.getCasesOpenedInLastDays(testAccount.Id, 90);
        Test.stopTest();

        System.assertEquals(3, cases.size(), 'Should return 3 cases created in setup');
        System.assertNotEquals(null, cases[0].caseId, 'Case ID should be set');
    }

    /**
     * @description Cases opened — null account
     */
    @isTest
    static void testGetCasesOpenedInLastDays_NullAccount() {
        Test.startTest();
        try {
            CSD_CSDashboardController.getCasesOpenedInLastDays(null, 90);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            assertNullAccountException(e);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetTaskPicklistValues() {
        Test.startTest();
        CSD_CSDashboardController.TaskPicklistValues vals =
            CSD_CSDashboardController.getTaskPicklistValues();
        Test.stopTest();

        System.assertNotEquals(null, vals, 'Picklist values wrapper should not be null');
        System.assert(!vals.statusValues.isEmpty(), 'Task Status picklist should have values');
        System.assert(!vals.priorityValues.isEmpty(), 'Task Priority picklist should have values');
        System.assertNotEquals(null, vals.statusValues[0].label, 'Label should be populated');
        System.assertNotEquals(null, vals.statusValues[0].value, 'Value should be populated');
    }

    @isTest
    static void testCreateTask_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Map<String, Object> fields = new Map<String, Object>{
            'Subject' => 'Test Created Task',
            'WhatId' => testAccount.Id,
            'Status' => 'Not Started',
            'Priority' => 'Normal',
            'ActivityDate' => String.valueOf(Date.today().addDays(7))
        };

        Test.startTest();
        Id taskId = CSD_CSDashboardController.createTask(JSON.serialize(fields));
        Test.stopTest();

        System.assertNotEquals(null, taskId, 'Returned Task Id should not be null');
        Task created = [SELECT Subject, WhatId, Status, Priority, ActivityDate FROM Task WHERE Id = :taskId];
        System.assertEquals('Test Created Task', created.Subject);
        System.assertEquals(testAccount.Id, created.WhatId);
        System.assertEquals('Not Started', created.Status);
    }

    @isTest
    static void testCreateTask_InvalidJson() {
        Test.startTest();
        try {
            CSD_CSDashboardController.createTask('not valid json');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            String msg = e.getMessage();
            System.assert(
                (String.isNotBlank(msg) && msg.containsIgnoreCase('error'))
                    || msg.containsIgnoreCase('script-thrown'),
                'Should surface task creation error; got: [' + msg + ']'
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateEvent_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Datetime startDt = Datetime.now().addDays(3);
        Datetime endDt = startDt.addHours(1);

        Map<String, Object> fields = new Map<String, Object>{
            'Subject' => 'Test Created Event',
            'WhatId' => testAccount.Id,
            'IsAllDayEvent' => false,
            'StartDateTime' => startDt.format('yyyy-MM-dd\'T\'HH:mm:ss'),
            'EndDateTime' => endDt.format('yyyy-MM-dd\'T\'HH:mm:ss'),
            'Location' => 'Conference Room'
        };

        Test.startTest();
        Id eventId = CSD_CSDashboardController.createEvent(JSON.serialize(fields));
        Test.stopTest();

        System.assertNotEquals(null, eventId, 'Returned Event Id should not be null');
        Event created = [SELECT Subject, WhatId, Location, IsAllDayEvent FROM Event WHERE Id = :eventId];
        System.assertEquals('Test Created Event', created.Subject);
        System.assertEquals(testAccount.Id, created.WhatId);
        System.assertEquals('Conference Room', created.Location);
        System.assertEquals(false, created.IsAllDayEvent);
    }

    @isTest
    static void testCreateEvent_AllDay() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Map<String, Object> fields = new Map<String, Object>{
            'Subject' => 'All Day Event',
            'WhatId' => testAccount.Id,
            'IsAllDayEvent' => true,
            'ActivityDate' => String.valueOf(Date.today().addDays(5))
        };

        Test.startTest();
        Id eventId = CSD_CSDashboardController.createEvent(JSON.serialize(fields));
        Test.stopTest();

        System.assertNotEquals(null, eventId, 'Returned Event Id should not be null');
        Event created = [SELECT Subject, IsAllDayEvent, ActivityDate FROM Event WHERE Id = :eventId];
        System.assertEquals(true, created.IsAllDayEvent);
    }
}
