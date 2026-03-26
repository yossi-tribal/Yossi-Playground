/**
 * @description Test class for CSD_CaseHealthScoreHandler and CSD_CaseHealthScoreTrigger.
 * Tests automated health score calculation when Cases are created, updated, or deleted.
 * @author Tribal AI Platform
 * @date 2024
 */
@isTest
private class CSD_CaseHealthScoreHandlerTest {

    /**
     * @description Test setup method to create common test data
     */
    @testSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Account for Case Health Score'
        );
        insert testAccount;
    }

    /**
     * @description Test that creating a high priority case triggers At Risk health score
     */
    @isTest
    static void testCaseInsert_HighPriority_AtRiskHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Case Health Score' LIMIT 1];

        // Create recent activity to avoid activity-based risk
        Task recentTask = new Task(
            Subject = 'Recent Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );
        insert recentTask;

        Test.startTest();
        // Create 2 high priority cases
        List<Case> cases = new List<Case>();
        cases.add(new Case(
            Subject = 'High Priority Case 1',
            AccountId = testAccount.Id,
            Status = 'New',
            Priority = 'High'
        ));
        cases.add(new Case(
            Subject = 'High Priority Case 2',
            AccountId = testAccount.Id,
            Status = 'Working',
            Priority = 'High'
        ));
        insert cases;
        Test.stopTest();

        // Query the account to verify health score was updated
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('At Risk', result.CSD_Account_Health_Score__c,
            'Account should have At Risk health score after inserting 2 high priority cases');
    }

    /**
     * @description Test that creating multiple open cases triggers At Risk health score
     */
    @isTest
    static void testCaseInsert_5PlusOpenCases_AtRiskHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Case Health Score' LIMIT 1];

        // Create recent activity
        Task recentTask = new Task(
            Subject = 'Recent Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );
        insert recentTask;

        Test.startTest();
        // Create 5 open cases
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
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('At Risk', result.CSD_Account_Health_Score__c,
            'Account should have At Risk health score with 5+ open cases');
    }

    /**
     * @description Test that updating a case to escalated triggers appropriate health score
     */
    @isTest
    static void testCaseUpdate_Escalated_AtRiskHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Case Health Score' LIMIT 1];

        // Create recent activity
        Task recentTask = new Task(
            Subject = 'Recent Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );
        insert recentTask;

        // Create 2 low priority cases
        List<Case> cases = new List<Case>();
        cases.add(new Case(
            Subject = 'Case 1',
            AccountId = testAccount.Id,
            Status = 'New',
            Priority = 'Low',
            IsEscalated = false
        ));
        cases.add(new Case(
            Subject = 'Case 2',
            AccountId = testAccount.Id,
            Status = 'New',
            Priority = 'Low',
            IsEscalated = false
        ));
        insert cases;

        Test.startTest();
        // Escalate both cases
        for (Case c : cases) {
            c.IsEscalated = true;
        }
        update cases;
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('At Risk', result.CSD_Account_Health_Score__c,
            'Account should have At Risk health score after escalating 2 cases');
    }

    /**
     * @description Test that closing cases improves health score
     */
    @isTest
    static void testCaseUpdate_CloseCases_ImprovesHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Case Health Score' LIMIT 1];

        // Create recent activity
        Task recentTask = new Task(
            Subject = 'Recent Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-1)
        );
        insert recentTask;

        // Create 5 open cases
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

        // Verify At Risk status
        Account redAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        System.assertEquals('At Risk', redAccount.CSD_Account_Health_Score__c,
            'Account should initially have At Risk health score with 5 open cases');

        Test.startTest();
        // Close 3 cases to bring total below threshold
        for (Integer i = 0; i < 3; i++) {
            cases[i].Status = 'Closed';
        }
        update cases;
        Test.stopTest();

        // Query the account to verify improved health score
        Account greenAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Healthy', greenAccount.CSD_Account_Health_Score__c,
            'Account should have Healthy health score after closing cases');
    }

    /**
     * @description Test that deleting cases triggers health score recalculation
     */
    @isTest
    static void testCaseDelete_RecalculatesHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Case Health Score' LIMIT 1];

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
            Subject = 'High Priority Case 2',
            AccountId = testAccount.Id,
            Status = 'Working',
            Priority = 'High'
        ));
        insert cases;

        // Verify At Risk status
        Account redAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        System.assertEquals('At Risk', redAccount.CSD_Account_Health_Score__c,
            'Account should have At Risk health score with 2 high priority cases');

        Test.startTest();
        // Delete both cases
        delete cases;
        Test.stopTest();

        // Query the account to verify health score improved
        Account greenAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Healthy', greenAccount.CSD_Account_Health_Score__c,
            'Account should have Healthy health score after deleting high priority cases');
    }

    /**
     * @description Test bulk case operations
     */
    @isTest
    static void testBulkCaseInsert() {
        // Create multiple accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(Name = 'Bulk Test Account ' + i));
        }
        insert accounts;

        // Create recent activity for all accounts
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
        // Create 1 high priority case for each account
        List<Case> cases = new List<Case>();
        for (Account acc : accounts) {
            cases.add(new Case(
                Subject = 'High Priority Case',
                AccountId = acc.Id,
                Status = 'New',
                Priority = 'High'
            ));
        }
        insert cases;
        Test.stopTest();

        // Query all accounts to verify health scores
        List<Account> results = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id IN :accounts
        ];

        // All should be Needs Attention with 1 high priority case
        for (Account acc : results) {
            System.assertEquals('Needs Attention', acc.CSD_Account_Health_Score__c,
                'Bulk accounts should have Needs Attention health score with 1 high priority case');
        }
    }

    /**
     * @description Test that handler gracefully handles cases without AccountId
     */
    @isTest
    static void testCaseWithoutAccount() {
        Test.startTest();
        // Create a case without an Account (should not cause errors)
        Case orphanCase = new Case(
            Subject = 'Case without Account',
            Status = 'New',
            Priority = 'Low'
        );
        insert orphanCase;
        Test.stopTest();

        // If we reach here without exceptions, the test passes
        System.assert(true, 'Handler should gracefully handle cases without AccountId');
    }
}
