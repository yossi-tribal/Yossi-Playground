/**
 * @description Test class for CSD_TaskHealthScoreHandler and CSD_TaskHealthScoreTrigger.
 * Tests automated health score calculation when Tasks are created, updated, or deleted.
 * @author Tribal AI Platform
 * @date 2024
 */
@isTest
private class CSD_TaskHealthScoreHandlerTest {

    /**
     * @description Test setup method to create common test data
     */
    @testSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Account for Task Health Score'
        );
        insert testAccount;
    }

    /**
     * @description Test that creating overdue tasks triggers At Risk health score
     */
    @isTest
    static void testTaskInsert_3PlusOverdue_AtRiskHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Task Health Score' LIMIT 1];

        // Create recent event to avoid activity-based risk
        Event recentEvent = new Event(
            Subject = 'Recent Meeting',
            WhatId = testAccount.Id,
            ActivityDate = Date.today().addDays(-5),
            StartDateTime = DateTime.now().addDays(-5),
            EndDateTime = DateTime.now().addDays(-5).addHours(1)
        );
        insert recentEvent;

        Test.startTest();
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
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('At Risk', result.CSD_Account_Health_Score__c,
            'Account should have At Risk health score with 3+ overdue tasks');
    }

    /**
     * @description Test that creating 1-2 overdue tasks triggers Needs Attention health score
     */
    @isTest
    static void testTaskInsert_1To2Overdue_NeedsAttentionHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Task Health Score' LIMIT 1];

        // Create recent activity
        Task recentTask = new Task(
            Subject = 'Recent Completed Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-2)
        );
        insert recentTask;

        Test.startTest();
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
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Needs Attention', result.CSD_Account_Health_Score__c,
            'Account should have Needs Attention health score with 1-2 overdue tasks');
    }

    /**
     * @description Test that completing overdue tasks improves health score
     */
    @isTest
    static void testTaskUpdate_CompleteOverdue_ImprovesHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Task Health Score' LIMIT 1];

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

        // Verify At Risk status
        Account redAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        System.assertEquals('At Risk', redAccount.CSD_Account_Health_Score__c,
            'Account should initially have At Risk health score with 3 overdue tasks');

        Test.startTest();
        // Complete all overdue tasks
        for (Task t : overdueTasks) {
            t.Status = 'Completed';
        }
        update overdueTasks;
        Test.stopTest();

        // Query the account to verify improved health score
        Account greenAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Healthy', greenAccount.CSD_Account_Health_Score__c,
            'Account should have Healthy health score after completing overdue tasks');
    }

    /**
     * @description Test that deleting tasks triggers health score recalculation
     */
    @isTest
    static void testTaskDelete_RecalculatesHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Task Health Score' LIMIT 1];

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

        // Verify At Risk status
        Account redAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        System.assertEquals('At Risk', redAccount.CSD_Account_Health_Score__c,
            'Account should have At Risk health score with 3 overdue tasks');

        Test.startTest();
        // Delete all overdue tasks
        delete overdueTasks;
        Test.stopTest();

        // Query the account to verify health score improved
        Account greenAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Healthy', greenAccount.CSD_Account_Health_Score__c,
            'Account should have Healthy health score after deleting overdue tasks');
    }

    /**
     * @description Test that creating a completed task updates last activity date
     */
    @isTest
    static void testTaskInsert_CompletedTask_UpdatesHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Task Health Score' LIMIT 1];

        // Create an old completed task to establish 30+ days no activity
        Task oldTask = new Task(
            Subject = 'Old Completed Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-31)
        );
        insert oldTask;

        // Trigger initial health score calculation
        testAccount.Description = 'Trigger update';
        update testAccount;

        // Verify At Risk status due to no recent activity
        Account redAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        System.assertEquals('At Risk', redAccount.CSD_Account_Health_Score__c,
            'Account should have At Risk health score with no activity in 30+ days');

        Test.startTest();
        // Create a new completed task today
        Task newTask = new Task(
            Subject = 'New Completed Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today()
        );
        insert newTask;
        Test.stopTest();

        // Query the account to verify health score improved
        Account greenAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Healthy', greenAccount.CSD_Account_Health_Score__c,
            'Account should have Healthy health score after recent completed task');
    }

    /**
     * @description Test bulk task operations
     */
    @isTest
    static void testBulkTaskInsert() {
        // Create multiple accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(Name = 'Bulk Test Account ' + i));
        }
        insert accounts;

        Test.startTest();
        // Create 2 overdue tasks for each account
        List<Task> tasks = new List<Task>();
        for (Account acc : accounts) {
            for (Integer i = 0; i < 2; i++) {
                tasks.add(new Task(
                    Subject = 'Overdue Task ' + i,
                    WhatId = acc.Id,
                    Status = 'Not Started',
                    ActivityDate = Date.today().addDays(-5 - i)
                ));
            }
        }
        insert tasks;
        Test.stopTest();

        // Query all accounts to verify health scores
        List<Account> results = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id IN :accounts
        ];

        // All should be Needs Attention with 1-2 overdue tasks
        for (Account acc : results) {
            System.assertEquals('Needs Attention', acc.CSD_Account_Health_Score__c,
                'Bulk accounts should have Needs Attention health score with 2 overdue tasks');
        }
    }

    /**
     * @description Test that handler gracefully handles tasks not related to Account
     */
    @isTest
    static void testTaskWithoutAccount() {
        // Create a Contact to relate task to (not an Account)
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account for Task Health Score' LIMIT 1];
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id
        );
        insert testContact;

        Test.startTest();
        // Create a task related to Contact, not Account
        Task contactTask = new Task(
            Subject = 'Task for Contact',
            WhoId = testContact.Id,
            Status = 'Not Started',
            ActivityDate = Date.today().addDays(1)
        );
        insert contactTask;
        Test.stopTest();

        // If we reach here without exceptions, the test passes
        System.assert(true, 'Handler should gracefully handle tasks not related to Account');
    }
}
