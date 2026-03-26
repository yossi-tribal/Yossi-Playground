/**
 * @description Test class for CSD_AccountHealthScoreHandler and CSD_AccountHealthScoreTrigger.
 * Tests automated health score calculation based on activity metrics, cases, and tasks.
 * @author Tribal AI Platform
 * @date 2024
 */
@isTest
private class CSD_AccountHealthScoreHandlerTest {

    /**
     * @description Test setup method to create common test data
     */
    @testSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            testAccounts.add(new Account(
                Name = 'Test Account ' + i
            ));
        }
        insert testAccounts;
    }

    /**
     * @description Test that new accounts get Healthy health score when no risk factors exist
     */
    @isTest
    static void testNewAccount_HealthyHealthScore() {
        Test.startTest();
        Account newAccount = new Account(Name = 'Healthy Account');
        insert newAccount;
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :newAccount.Id
        ];

        // Should be Healthy since no cases, tasks, or activities exist
        System.assertEquals('Healthy', result.CSD_Account_Health_Score__c,
            'New account with no risk factors should have Healthy health score');
    }

    /**
     * @description Test At Risk health score when account has 30+ days without activity
     */
    @isTest
    static void testAtRiskHealthScore_NoActivityIn30Days() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 0' LIMIT 1];

        // Create a completed task 31 days ago
        Task oldTask = new Task(
            Subject = 'Old Completed Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-31)
        );
        insert oldTask;

        Test.startTest();
        // Trigger health score recalculation by updating account
        testAccount.Description = 'Trigger update';
        update testAccount;
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('At Risk', result.CSD_Account_Health_Score__c,
            'Account with 30+ days without activity should have At Risk health score');
    }

    /**
     * @description Test Needs Attention health score when account has 15-29 days without activity
     */
    @isTest
    static void testNeedsAttentionHealthScore_NoActivityIn15To29Days() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 1' LIMIT 1];

        // Create a completed task 20 days ago
        Task recentTask = new Task(
            Subject = 'Recent Completed Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-20)
        );
        insert recentTask;

        Test.startTest();
        // Trigger health score recalculation
        testAccount.Description = 'Trigger update';
        update testAccount;
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Needs Attention', result.CSD_Account_Health_Score__c,
            'Account with 15-29 days without activity should have Needs Attention health score');
    }

    /**
     * @description Test At Risk health score when account has 3+ overdue tasks
     */
    @isTest
    static void testAtRiskHealthScore_3PlusOverdueTasks() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 2' LIMIT 1];

        // Create recent activity to avoid activity-based risk
        Event recentEvent = new Event(
            Subject = 'Recent Meeting',
            WhatId = testAccount.Id,
            ActivityDate = Date.today().addDays(-5),
            StartDateTime = DateTime.now().addDays(-5),
            EndDateTime = DateTime.now().addDays(-5).addHours(1)
        );
        insert recentEvent;

        // Create 3 overdue tasks
        List<Task> overdueTasks = new List<Task>();
        for (Integer i = 0; i < 3; i++) {
            overdueTasks.add(new Task(
                Subject = 'Overdue Task ' + i,
                WhatId = testAccount.Id,
                Status = 'Not Started',
                ActivityDate = Date.today().addDays(-10 - i)
            ));
        }
        insert overdueTasks;

        Test.startTest();
        // Trigger health score recalculation
        testAccount.Description = 'Trigger update';
        update testAccount;
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('At Risk', result.CSD_Account_Health_Score__c,
            'Account with 3+ overdue tasks should have At Risk health score');
    }

    /**
     * @description Test Needs Attention health score when account has 1-2 overdue tasks
     */
    @isTest
    static void testNeedsAttentionHealthScore_1To2OverdueTasks() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 3' LIMIT 1];

        // Create recent activity
        Task recentTask = new Task(
            Subject = 'Recent Completed Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-2)
        );
        insert recentTask;

        // Create 2 overdue tasks
        List<Task> overdueTasks = new List<Task>();
        for (Integer i = 0; i < 2; i++) {
            overdueTasks.add(new Task(
                Subject = 'Overdue Task ' + i,
                WhatId = testAccount.Id,
                Status = 'Not Started',
                ActivityDate = Date.today().addDays(-5 - i)
            ));
        }
        insert overdueTasks;

        Test.startTest();
        // Trigger health score recalculation
        testAccount.Description = 'Trigger update';
        update testAccount;
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Needs Attention', result.CSD_Account_Health_Score__c,
            'Account with 1-2 overdue tasks should have Needs Attention health score');
    }

    /**
     * @description Test At Risk health score when account has 2+ high priority or escalated cases
     */
    @isTest
    static void testAtRiskHealthScore_2PlusHighPriorityCases() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 4' LIMIT 1];

        // Create recent activity
        Task recentTask = new Task(
            Subject = 'Recent Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );
        insert recentTask;

        // Create 2 high priority cases
        List<Case> cases = new List<Case>();
        cases.add(new Case(
            Subject = 'High Priority Case 1',
            AccountId = testAccount.Id,
            Status = 'New',
            Priority = 'High'
        ));
        cases.add(new Case(
            Subject = 'Escalated Case',
            AccountId = testAccount.Id,
            Status = 'Working',
            Priority = 'Medium',
            IsEscalated = true
        ));
        insert cases;

        Test.startTest();
        // Trigger health score recalculation
        testAccount.Description = 'Trigger update';
        update testAccount;
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('At Risk', result.CSD_Account_Health_Score__c,
            'Account with 2+ high priority or escalated cases should have At Risk health score');
    }

    /**
     * @description Test Needs Attention health score when account has 1 high priority case
     */
    @isTest
    static void testNeedsAttentionHealthScore_1HighPriorityCase() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 0' LIMIT 1];

        // Create recent activity
        Task recentTask = new Task(
            Subject = 'Recent Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );
        insert recentTask;

        // Create 1 high priority case
        Case highPriCase = new Case(
            Subject = 'High Priority Case',
            AccountId = testAccount.Id,
            Status = 'New',
            Priority = 'High'
        );
        insert highPriCase;

        Test.startTest();
        // Trigger health score recalculation
        testAccount.Description = 'Trigger update';
        update testAccount;
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Needs Attention', result.CSD_Account_Health_Score__c,
            'Account with 1 high priority case should have Needs Attention health score');
    }

    /**
     * @description Test At Risk health score when account has 5+ total open cases
     */
    @isTest
    static void testAtRiskHealthScore_5PlusOpenCases() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 1' LIMIT 1];

        // Create recent activity
        Task recentTask = new Task(
            Subject = 'Recent Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );
        insert recentTask;

        // Create 5 open cases (low priority)
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 5; i++) {
            cases.add(new Case(
                Subject = 'Case ' + i,
                AccountId = testAccount.Id,
                Status = 'New',
                Priority = 'Low'
            ));
        }
        insert cases;

        Test.startTest();
        // Trigger health score recalculation
        testAccount.Description = 'Trigger update';
        update testAccount;
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('At Risk', result.CSD_Account_Health_Score__c,
            'Account with 5+ open cases should have At Risk health score');
    }

    /**
     * @description Test Needs Attention health score when account has 3-4 total open cases
     */
    @isTest
    static void testNeedsAttentionHealthScore_3To4OpenCases() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 2' LIMIT 1];

        // Create recent activity
        Task recentTask = new Task(
            Subject = 'Recent Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );
        insert recentTask;

        // Create 4 open cases (low priority)
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 4; i++) {
            cases.add(new Case(
                Subject = 'Case ' + i,
                AccountId = testAccount.Id,
                Status = 'New',
                Priority = 'Low'
            ));
        }
        insert cases;

        Test.startTest();
        // Trigger health score recalculation
        testAccount.Description = 'Trigger update';
        update testAccount;
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Needs Attention', result.CSD_Account_Health_Score__c,
            'Account with 3-4 open cases should have Needs Attention health score');
    }

    /**
     * @description Test that health score improves from At Risk to Healthy when risk factors are resolved
     */
    @isTest
    static void testHealthScoreImprovement_AtRiskToHealthy() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 3' LIMIT 1];

        // Create overdue tasks to trigger At Risk status
        List<Task> overdueTasks = new List<Task>();
        for (Integer i = 0; i < 3; i++) {
            overdueTasks.add(new Task(
                Subject = 'Overdue Task ' + i,
                WhatId = testAccount.Id,
                Status = 'Not Started',
                ActivityDate = Date.today().addDays(-10 - i)
            ));
        }
        insert overdueTasks;

        // Update account to trigger health score calculation
        testAccount.Description = 'Trigger update 1';
        update testAccount;

        // Verify At Risk status
        Account redAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        System.assertEquals('At Risk', redAccount.CSD_Account_Health_Score__c,
            'Account should initially have At Risk health score');

        Test.startTest();
        // Complete all overdue tasks
        for (Task t : overdueTasks) {
            t.Status = 'Completed';
        }
        update overdueTasks;

        // Trigger health score recalculation
        testAccount.Description = 'Trigger update 2';
        update testAccount;
        Test.stopTest();

        // Verify Healthy status
        Account greenAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        System.assertEquals('Healthy', greenAccount.CSD_Account_Health_Score__c,
            'Account should now have Healthy health score after resolving risk factors');
    }

    /**
     * @description Test bulk trigger handling with multiple accounts
     */
    @isTest
    static void testBulkAccountUpdate() {
        List<Account> accounts = [SELECT Id FROM Account];

        // Create recent activities for all accounts
        List<Task> tasks = new List<Task>();
        for (Account acc : accounts) {
            tasks.add(new Task(
                Subject = 'Recent Task',
                WhatId = acc.Id,
                Status = 'Completed',
                ActivityDate = Date.today().addDays(-1)
            ));
        }
        insert tasks;

        Test.startTest();
        // Update all accounts at once to test bulk trigger
        for (Account acc : accounts) {
            acc.Description = 'Bulk update';
        }
        update accounts;
        Test.stopTest();

        // Query all accounts to verify health scores
        List<Account> results = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id IN :accounts
        ];

        // All should be Healthy since they have recent activity and no risk factors
        for (Account acc : results) {
            System.assertEquals('Healthy', acc.CSD_Account_Health_Score__c,
                'Bulk updated accounts should have Healthy health score');
        }
    }

    /**
     * @description Test that handler gracefully handles null or empty account ID sets
     */
    @isTest
    static void testNullAndEmptyAccountIds() {
        Test.startTest();
        // Test null set
        CSD_AccountHealthScoreHandler.calculateHealthScores(null);

        // Test empty set
        CSD_AccountHealthScoreHandler.calculateHealthScores(new Set<Id>());
        Test.stopTest();

        // If we reach here without exceptions, the test passes
        System.assert(true, 'Handler should gracefully handle null and empty input');
    }
}
