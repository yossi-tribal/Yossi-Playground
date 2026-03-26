/**
 * @description Test class for CSD_EventHealthScoreHandler and CSD_EventHealthScoreTrigger.
 * Tests automated health score calculation when Events are created, updated, or deleted.
 * @author Tribal AI Platform
 * @date 2024
 */
@isTest
private class CSD_EventHealthScoreHandlerTest {

    /**
     * @description Test setup method to create common test data
     */
    @testSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Account for Event Health Score'
        );
        insert testAccount;
    }

    /**
     * @description Test that creating a recent event improves health score
     */
    @isTest
    static void testEventInsert_RecentEvent_HealthyHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Event Health Score' LIMIT 1];

        // Create old activity to establish 30+ days no activity
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

        // Verify At Risk status
        Account redAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        System.assertEquals('At Risk', redAccount.CSD_Account_Health_Score__c,
            'Account should have At Risk health score with no activity in 30+ days');

        Test.startTest();
        // Create a recent event
        Event recentEvent = new Event(
            Subject = 'Recent Meeting',
            WhatId = testAccount.Id,
            ActivityDate = Date.today().addDays(-5),
            StartDateTime = DateTime.now().addDays(-5),
            EndDateTime = DateTime.now().addDays(-5).addHours(1)
        );
        insert recentEvent;
        Test.stopTest();

        // Query the account to verify health score improved
        Account greenAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Healthy', greenAccount.CSD_Account_Health_Score__c,
            'Account should have Healthy health score after recent event');
    }

    /**
     * @description Test that creating an event 15-29 days ago triggers Needs Attention health score
     */
    @isTest
    static void testEventInsert_15To29DaysAgo_NeedsAttentionHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Event Health Score' LIMIT 1];

        Test.startTest();
        // Create an event 20 days ago
        Event event = new Event(
            Subject = 'Meeting 20 days ago',
            WhatId = testAccount.Id,
            ActivityDate = Date.today().addDays(-20),
            StartDateTime = DateTime.now().addDays(-20),
            EndDateTime = DateTime.now().addDays(-20).addHours(1)
        );
        insert event;
        Test.stopTest();

        // Query the account to verify health score
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Needs Attention', result.CSD_Account_Health_Score__c,
            'Account should have Needs Attention health score with event 15-29 days ago');
    }

    /**
     * @description Test that updating an event triggers health score recalculation
     */
    @isTest
    static void testEventUpdate_RecalculatesHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Event Health Score' LIMIT 1];

        // Create an old event
        Event oldEvent = new Event(
            Subject = 'Old Meeting',
            WhatId = testAccount.Id,
            ActivityDate = Date.today().addDays(-31),
            StartDateTime = DateTime.now().addDays(-31),
            EndDateTime = DateTime.now().addDays(-31).addHours(1)
        );
        insert oldEvent;

        // Verify At Risk status
        Account redAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        System.assertEquals('At Risk', redAccount.CSD_Account_Health_Score__c,
            'Account should have At Risk health score with event 30+ days ago');

        Test.startTest();
        // Update event to be more recent
        oldEvent.ActivityDate = Date.today().addDays(-5);
        oldEvent.StartDateTime = DateTime.now().addDays(-5);
        oldEvent.EndDateTime = DateTime.now().addDays(-5).addHours(1);
        update oldEvent;
        Test.stopTest();

        // Query the account to verify health score improved
        Account greenAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Healthy', greenAccount.CSD_Account_Health_Score__c,
            'Account should have Healthy health score after updating event to recent date');
    }

    /**
     * @description Test that deleting events triggers health score recalculation
     */
    @isTest
    static void testEventDelete_RecalculatesHealthScore() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Event Health Score' LIMIT 1];

        // Create a recent event
        Event recentEvent = new Event(
            Subject = 'Recent Meeting',
            WhatId = testAccount.Id,
            ActivityDate = Date.today().addDays(-5),
            StartDateTime = DateTime.now().addDays(-5),
            EndDateTime = DateTime.now().addDays(-5).addHours(1)
        );
        insert recentEvent;

        // Also create an old event
        Event oldEvent = new Event(
            Subject = 'Old Meeting',
            WhatId = testAccount.Id,
            ActivityDate = Date.today().addDays(-31),
            StartDateTime = DateTime.now().addDays(-31),
            EndDateTime = DateTime.now().addDays(-31).addHours(1)
        );
        insert oldEvent;

        // Verify Healthy status due to recent event
        Account greenAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        System.assertEquals('Healthy', greenAccount.CSD_Account_Health_Score__c,
            'Account should have Healthy health score with recent event');

        Test.startTest();
        // Delete the recent event
        delete recentEvent;
        Test.stopTest();

        // Query the account to verify health score changed
        Account redAccount = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('At Risk', redAccount.CSD_Account_Health_Score__c,
            'Account should have At Risk health score after deleting recent event');
    }

    /**
     * @description Test bulk event operations
     */
    @isTest
    static void testBulkEventInsert() {
        // Create multiple accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(Name = 'Bulk Test Account ' + i));
        }
        insert accounts;

        Test.startTest();
        // Create a recent event for each account
        List<Event> events = new List<Event>();
        for (Account acc : accounts) {
            events.add(new Event(
                Subject = 'Recent Meeting',
                WhatId = acc.Id,
                ActivityDate = Date.today().addDays(-5),
                StartDateTime = DateTime.now().addDays(-5),
                EndDateTime = DateTime.now().addDays(-5).addHours(1)
            ));
        }
        insert events;
        Test.stopTest();

        // Query all accounts to verify health scores
        List<Account> results = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id IN :accounts
        ];

        // All should be Healthy with recent activity
        for (Account acc : results) {
            System.assertEquals('Healthy', acc.CSD_Account_Health_Score__c,
                'Bulk accounts should have Healthy health score with recent events');
        }
    }

    /**
     * @description Test that handler gracefully handles events not related to Account
     */
    @isTest
    static void testEventWithoutAccount() {
        // Create a Contact to relate event to (not an Account)
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account for Event Health Score' LIMIT 1];
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id
        );
        insert testContact;

        Test.startTest();
        // Create an event related to Contact, not Account
        Event contactEvent = new Event(
            Subject = 'Meeting with Contact',
            WhoId = testContact.Id,
            ActivityDate = Date.today().addDays(1),
            StartDateTime = DateTime.now().addDays(1),
            EndDateTime = DateTime.now().addDays(1).addHours(1)
        );
        insert contactEvent;
        Test.stopTest();

        // If we reach here without exceptions, the test passes
        System.assert(true, 'Handler should gracefully handle events not related to Account');
    }

    /**
     * @description Test combined Task and Event activity tracking
     */
    @isTest
    static void testCombinedTaskAndEventActivity() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Event Health Score' LIMIT 1];

        // Create old completed task
        Task oldTask = new Task(
            Subject = 'Old Task',
            WhatId = testAccount.Id,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-25)
        );
        insert oldTask;

        Test.startTest();
        // Create recent event
        Event recentEvent = new Event(
            Subject = 'Recent Meeting',
            WhatId = testAccount.Id,
            ActivityDate = Date.today().addDays(-5),
            StartDateTime = DateTime.now().addDays(-5),
            EndDateTime = DateTime.now().addDays(-5).addHours(1)
        );
        insert recentEvent;
        Test.stopTest();

        // Query the account to verify health score uses most recent activity
        Account result = [
            SELECT Id, CSD_Account_Health_Score__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];

        System.assertEquals('Healthy', result.CSD_Account_Health_Score__c,
            'Account should have Healthy health score based on most recent activity (event)');
    }
}
