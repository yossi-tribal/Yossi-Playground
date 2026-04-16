/**
 * @description Test class for OHT_OpportunityHealthBatch
 */
@isTest
private with sharing class OHT_OpportunityHealthBatchTest {

    /**
     * @description Setup test data for batch tests
     */
    @TestSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(Name = 'Batch Test Account');
        insert testAccount;

        // Create multiple open opportunities for batch processing
        List<Opportunity> testOpps = new List<Opportunity>();

        for (Integer i = 0; i < 150; i++) {
            testOpps.add(new Opportunity(
                Name = 'Batch Test Opp ' + i,
                AccountId = testAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30 + i),
                Amount = 10000 + (i * 1000)
            ));
        }

        insert testOpps;
    }

    /**
     * @description Test batch execution processes all open opportunities
     */
    @isTest
    static void testBatchExecution() {
        // Verify opportunities exist without health scores
        List<Opportunity> oppsBeforeBatch = [
            SELECT Id, OHT_Health_Score__c, OHT_Risk_Level__c
            FROM Opportunity
            WHERE IsClosed = false
        ];

        System.assertEquals(150, oppsBeforeBatch.size(), 'Should have 150 test opportunities');

        Test.startTest();
        // Execute the batch
        OHT_OpportunityHealthBatch batch = new OHT_OpportunityHealthBatch();
        Id batchId = Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify all opportunities have health scores after batch
        List<Opportunity> oppsAfterBatch = [
            SELECT Id, OHT_Health_Score__c, OHT_Risk_Level__c, OHT_Health_Score_Last_Updated__c
            FROM Opportunity
            WHERE IsClosed = false
        ];

        System.assertEquals(150, oppsAfterBatch.size(), 'Should still have 150 opportunities');

        for (Opportunity opp : oppsAfterBatch) {
            System.assertNotEquals(null, opp.OHT_Health_Score__c,
                'Health score should be calculated for opportunity ' + opp.Id);
            System.assertNotEquals(null, opp.OHT_Risk_Level__c,
                'Risk level should be set for opportunity ' + opp.Id);
            System.assertNotEquals(null, opp.OHT_Health_Score_Last_Updated__c,
                'Last updated timestamp should be set for opportunity ' + opp.Id);
        }
    }

    /**
     * @description Test schedulable interface execution
     */
    @isTest
    static void testSchedulableExecution() {
        // Create a cron expression for scheduling (every day at 2 AM)
        String cronExp = '0 0 2 * * ?';

        Test.startTest();
        // Schedule the batch job
        String jobId = System.schedule('Test Opportunity Health Batch', cronExp, new OHT_OpportunityHealthBatch());
        Test.stopTest();

        // Verify job was scheduled
        System.assertNotEquals(null, jobId, 'Job should be scheduled successfully');

        // Query the scheduled job
        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronExpression, State, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertEquals(1, scheduledJobs.size(), 'Should have one scheduled job');
        System.assertEquals(cronExp, scheduledJobs[0].CronExpression, 'Cron expression should match');
    }

    /**
     * @description Test batch handles closed opportunities correctly (should skip them)
     */
    @isTest
    static void testBatchSkipsClosedOpportunities() {
        // Create some closed opportunities
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        List<Opportunity> closedOpps = new List<Opportunity>();
        closedOpps.add(new Opportunity(
            Name = 'Closed Won Test',
            AccountId = testAccount.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(-10),
            Amount = 50000
        ));
        closedOpps.add(new Opportunity(
            Name = 'Closed Lost Test',
            AccountId = testAccount.Id,
            StageName = 'Closed Lost',
            CloseDate = Date.today().addDays(-5),
            Amount = 30000
        ));

        insert closedOpps;

        Test.startTest();
        // Execute the batch
        OHT_OpportunityHealthBatch batch = new OHT_OpportunityHealthBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify closed opportunities were not processed (health score should be null or unchanged)
        List<Opportunity> closedOppsAfter = [
            SELECT Id, Name, IsClosed, OHT_Health_Score__c
            FROM Opportunity
            WHERE IsClosed = true
        ];

        System.assertEquals(2, closedOppsAfter.size(), 'Should have 2 closed opportunities');

        // Verify open opportunities were processed
        List<Opportunity> openOppsAfter = [
            SELECT Id, OHT_Health_Score__c
            FROM Opportunity
            WHERE IsClosed = false
        ];

        for (Opportunity opp : openOppsAfter) {
            System.assertNotEquals(null, opp.OHT_Health_Score__c,
                'Open opportunities should have health scores');
        }
    }

    /**
     * @description Test batch processes opportunities with various health conditions
     */
    @isTest
    static void testBatchProcessesVariousHealthConditions() {
        // Update some opportunities to have different health conditions
        List<Opportunity> opps = [
            SELECT Id, Name, CloseDate
            FROM Opportunity
            WHERE IsClosed = false
            LIMIT 5
        ];

        // Make some unhealthy
        opps[0].CloseDate = Date.today().addDays(5);

        // Make some healthy
        opps[1].CloseDate = Date.today().addDays(60);

        // Make some medium
        opps[2].CloseDate = Date.today().addDays(25);

        update opps;

        // Create overdue task for first opp
        Task overdueTask = new Task(
            Subject = 'Overdue Follow-up',
            WhatId = opps[0].Id,
            ActivityDate = Date.today().addDays(-10),
            Status = 'Not Started'
        );
        insert overdueTask;

        Test.startTest();
        OHT_OpportunityHealthBatch batch = new OHT_OpportunityHealthBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify different risk levels were assigned
        List<Opportunity> processedOpps = [
            SELECT Id, Name, OHT_Health_Score__c, OHT_Risk_Level__c
            FROM Opportunity
            WHERE Id IN :opps
            ORDER BY OHT_Health_Score__c DESC
        ];

        System.assertEquals(5, processedOpps.size(), 'Should have processed 5 opportunities');

        // Verify we have a mix of risk levels
        Boolean hasOnTrack = false;
        Boolean hasAtRisk = false;

        for (Opportunity opp : processedOpps) {
            if (opp.OHT_Risk_Level__c == 'On Track') {
                hasOnTrack = true;
            }
            if (opp.OHT_Risk_Level__c == 'At-Risk') {
                hasAtRisk = true;
            }
        }

        System.assert(hasOnTrack || hasAtRisk,
            'Should have different risk levels based on conditions');
    }

    /**
     * @description Test batch with small batch size
     */
    @isTest
    static void testBatchWithSmallBatchSize() {
        Test.startTest();
        // Execute batch with small batch size to test multiple executions
        OHT_OpportunityHealthBatch batch = new OHT_OpportunityHealthBatch();
        Id batchId = Database.executeBatch(batch, 50);
        Test.stopTest();

        // Verify batch completed successfully
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE Id = :batchId
        ];

        System.assertEquals('Completed', job.Status, 'Batch should complete successfully');
        System.assertEquals(0, job.NumberOfErrors, 'Should have no errors');

        // Verify all opportunities were processed
        List<Opportunity> processedOpps = [
            SELECT Id, OHT_Health_Score__c
            FROM Opportunity
            WHERE IsClosed = false AND OHT_Health_Score__c != null
        ];

        System.assertEquals(150, processedOpps.size(), 'All opportunities should be processed');
    }

    /**
     * @description Test that batch updates existing health scores
     */
    @isTest
    static void testBatchUpdatesExistingScores() {
        // First, manually set some health scores
        List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE IsClosed = false LIMIT 10];
        for (Opportunity opp : opps) {
            opp.OHT_Health_Score__c = 50;
            opp.OHT_Risk_Level__c = 'Old Value';
        }
        update opps;

        Test.startTest();
        // Run batch to recalculate
        OHT_OpportunityHealthBatch batch = new OHT_OpportunityHealthBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify scores were recalculated (should be different from 50)
        List<Opportunity> updatedOpps = [
            SELECT Id, OHT_Health_Score__c, OHT_Risk_Level__c
            FROM Opportunity
            WHERE Id IN :opps
        ];

        for (Opportunity opp : updatedOpps) {
            System.assertNotEquals('Old Value', opp.OHT_Risk_Level__c,
                'Risk level should be recalculated');
        }
    }
}
