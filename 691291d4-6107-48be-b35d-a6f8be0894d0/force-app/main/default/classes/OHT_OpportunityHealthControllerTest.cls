/**
 * @description Test class for OHT_OpportunityHealthController
 */
@isTest
private with sharing class OHT_OpportunityHealthControllerTest {

    /**
     * @description Setup test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        // Create test opportunities with different scenarios
        List<Opportunity> testOpps = new List<Opportunity>();

        // Opportunity 1: Healthy - recent activity, future close date, no overdue tasks
        testOpps.add(new Opportunity(
            Name = 'Healthy Opp',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(45),
            Amount = 100000
        ));

        // Opportunity 2: Needs Attention - moderate issues
        testOpps.add(new Opportunity(
            Name = 'Medium Risk Opp',
            AccountId = testAccount.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(20),
            Amount = 50000
        ));

        // Opportunity 3: At-Risk - multiple issues
        testOpps.add(new Opportunity(
            Name = 'At-Risk Opp',
            AccountId = testAccount.Id,
            StageName = 'Negotiation',
            CloseDate = Date.today().addDays(10),
            Amount = 75000
        ));

        // Opportunity 4: Closed Won
        testOpps.add(new Opportunity(
            Name = 'Closed Won Opp',
            AccountId = testAccount.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(-10),
            Amount = 200000
        ));

        // Opportunity 5: Closed Lost
        testOpps.add(new Opportunity(
            Name = 'Closed Lost Opp',
            AccountId = testAccount.Id,
            StageName = 'Closed Lost',
            CloseDate = Date.today().addDays(-5),
            Amount = 30000
        ));

        // Opportunity 6: No activity date
        testOpps.add(new Opportunity(
            Name = 'No Activity Opp',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(25),
            Amount = 40000
        ));

        insert testOpps;

        // Create overdue task for at-risk opportunity
        Task overdueTask = new Task(
            Subject = 'Overdue Task',
            WhatId = testOpps[2].Id,
            ActivityDate = Date.today().addDays(-5),
            Status = 'Not Started'
        );
        insert overdueTask;
    }

    /**
     * @description Test healthy opportunity scoring
     */
    @isTest
    static void testHealthyOpportunity() {
        Opportunity healthyOpp = [SELECT Id FROM Opportunity WHERE Name = 'Healthy Opp' LIMIT 1];

        Test.startTest();
        OHT_OpportunityHealthController.HealthScoreData result =
            OHT_OpportunityHealthController.getOpportunityHealthScore(healthyOpp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('On Track', result.riskLevel, 'Risk level should be On Track');
        System.assert(result.healthScore >= 75, 'Health score should be 75 or higher');
        System.assertEquals(false, result.isClosed, 'Opportunity should be open');
        System.assertNotEquals(null, result.breakdown, 'Breakdown should not be null');
        System.assertEquals(100, result.breakdown.overdueTasksScore, 'No overdue tasks should score 100');
    }

    /**
     * @description Test medium risk opportunity scoring
     */
    @isTest
    static void testMediumRiskOpportunity() {
        Opportunity mediumOpp = [SELECT Id FROM Opportunity WHERE Name = 'Medium Risk Opp' LIMIT 1];

        Test.startTest();
        OHT_OpportunityHealthController.HealthScoreData result =
            OHT_OpportunityHealthController.getOpportunityHealthScore(mediumOpp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.healthScore >= 50 && result.healthScore < 75,
            'Health score should be between 50-74');
        System.assertEquals('Needs Attention', result.riskLevel, 'Risk level should be Needs Attention');
    }

    /**
     * @description Test at-risk opportunity with overdue tasks
     */
    @isTest
    static void testAtRiskOpportunity() {
        Opportunity atRiskOpp = [SELECT Id FROM Opportunity WHERE Name = 'At-Risk Opp' LIMIT 1];

        Test.startTest();
        OHT_OpportunityHealthController.HealthScoreData result =
            OHT_OpportunityHealthController.getOpportunityHealthScore(atRiskOpp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.healthScore < 50, 'Health score should be below 50');
        System.assertEquals('At-Risk', result.riskLevel, 'Risk level should be At-Risk');
        System.assertEquals(0, result.breakdown.overdueTasksScore, 'Overdue tasks should score 0');
        System.assert(result.breakdown.overdueTaskCount > 0, 'Should have overdue tasks');
    }

    /**
     * @description Test closed won opportunity
     */
    @isTest
    static void testClosedWonOpportunity() {
        Opportunity closedWonOpp = [SELECT Id FROM Opportunity WHERE Name = 'Closed Won Opp' LIMIT 1];

        Test.startTest();
        OHT_OpportunityHealthController.HealthScoreData result =
            OHT_OpportunityHealthController.getOpportunityHealthScore(closedWonOpp.Id);
        Test.stopTest();

        System.assertEquals(100, result.healthScore, 'Closed Won should have 100 health score');
        System.assertEquals('On Track', result.riskLevel, 'Risk level should be On Track');
        System.assertEquals(true, result.isClosed, 'Opportunity should be closed');
        System.assertEquals(true, result.isWon, 'Opportunity should be won');
        System.assertEquals(100, result.breakdown.overdueTasksScore, 'All criteria should be 100');
    }

    /**
     * @description Test closed lost opportunity
     */
    @isTest
    static void testClosedLostOpportunity() {
        Opportunity closedLostOpp = [SELECT Id FROM Opportunity WHERE Name = 'Closed Lost Opp' LIMIT 1];

        Test.startTest();
        OHT_OpportunityHealthController.HealthScoreData result =
            OHT_OpportunityHealthController.getOpportunityHealthScore(closedLostOpp.Id);
        Test.stopTest();

        System.assertEquals(0, result.healthScore, 'Closed Lost should have 0 health score');
        System.assertEquals('At-Risk', result.riskLevel, 'Risk level should be At-Risk');
        System.assertEquals(true, result.isClosed, 'Opportunity should be closed');
        System.assertEquals(false, result.isWon, 'Opportunity should not be won');
        System.assertEquals(0, result.breakdown.overdueTasksScore, 'All criteria should be 0');
    }

    /**
     * @description Test opportunity with no activity date
     */
    @isTest
    static void testOpportunityWithNoActivity() {
        Opportunity noActivityOpp = [SELECT Id FROM Opportunity WHERE Name = 'No Activity Opp' LIMIT 1];

        Test.startTest();
        OHT_OpportunityHealthController.HealthScoreData result =
            OHT_OpportunityHealthController.getOpportunityHealthScore(noActivityOpp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.breakdown.lastActivityScore, 'No activity should score 0');
        System.assertEquals(null, result.breakdown.daysSinceLastActivity, 'Days should be null');
    }

    /**
     * @description Test bulk update method for multiple opportunities
     */
    @isTest
    static void testBulkUpdateOpportunities() {
        List<Opportunity> opps = [
            SELECT Id, Name, StageName, CloseDate, LastActivityDate,
                   IsClosed, IsWon, CreatedDate,
                   OHT_Health_Score__c, OHT_Risk_Level__c, OHT_Health_Score_Last_Updated__c
            FROM Opportunity
            WHERE IsClosed = false
        ];

        Test.startTest();
        OHT_OpportunityHealthController.updateHealthScoresForOpportunities(opps);
        Test.stopTest();

        // Verify updates were applied
        List<Opportunity> updatedOpps = [
            SELECT Id, OHT_Health_Score__c, OHT_Risk_Level__c, OHT_Health_Score_Last_Updated__c
            FROM Opportunity
            WHERE IsClosed = false
        ];

        for (Opportunity opp : updatedOpps) {
            System.assertNotEquals(null, opp.OHT_Health_Score__c, 'Health score should be set');
            System.assertNotEquals(null, opp.OHT_Risk_Level__c, 'Risk level should be set');
            System.assertNotEquals(null, opp.OHT_Health_Score_Last_Updated__c, 'Last updated should be set');
        }
    }

    /**
     * @description Test error handling when no opportunity row is returned (deleted Id is not visible to default SOQL)
     */
    @isTest
    static void testInvalidOpportunityId() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Opportunity phantom = new Opportunity(
            Name = 'Phantom Opp',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 1
        );
        insert phantom;
        Id removedId = phantom.Id;
        delete phantom;

        Test.startTest();
        try {
            OHT_OpportunityHealthController.getOpportunityHealthScore(removedId);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            // Apex tests often surface AuraHandledException as "Script-thrown exception" instead of the constructor text
            System.assert(
                e.getMessage().contains('Opportunity not found')
                || e.getMessage() == 'Script-thrown exception',
                'Unexpected message: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description Test close date scoring logic
     */
    @isTest
    static void testCloseDateScoring() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        // Test various close date scenarios
        List<Opportunity> testOpps = new List<Opportunity>();

        testOpps.add(new Opportunity(
            Name = 'Far Future Close',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(60),
            Amount = 10000
        ));

        testOpps.add(new Opportunity(
            Name = 'Near Future Close',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(5),
            Amount = 10000
        ));

        insert testOpps;

        Test.startTest();
        OHT_OpportunityHealthController.HealthScoreData farFutureResult =
            OHT_OpportunityHealthController.getOpportunityHealthScore(testOpps[0].Id);
        OHT_OpportunityHealthController.HealthScoreData nearFutureResult =
            OHT_OpportunityHealthController.getOpportunityHealthScore(testOpps[1].Id);
        Test.stopTest();

        System.assertEquals(100, farFutureResult.breakdown.closeDateScore,
            'Far future close should score 100');
        System.assertEquals(0, nearFutureResult.breakdown.closeDateScore,
            'Near future close should score 0');
    }

    /**
     * @description Test last activity date scoring logic
     */
    @isTest
    static void testLastActivityScoring() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        List<Opportunity> testOpps = new List<Opportunity>();

        testOpps.add(new Opportunity(
            Name = 'Recent Activity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 10000
        ));

        testOpps.add(new Opportunity(
            Name = 'Old Activity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 10000
        ));

        insert testOpps;

        // LastActivityDate is derived from completed activities; insert tasks so scoring can distinguish recency
        insert new List<Task>{
            new Task(
                Subject = 'Recent Activity Task',
                WhatId = testOpps[0].Id,
                Status = 'Completed',
                ActivityDate = Date.today().addDays(-3)
            ),
            new Task(
                Subject = 'Old Activity Task',
                WhatId = testOpps[1].Id,
                Status = 'Completed',
                ActivityDate = Date.today().addDays(-20)
            )
        };

        Test.startTest();
        OHT_OpportunityHealthController.HealthScoreData recentResult =
            OHT_OpportunityHealthController.getOpportunityHealthScore(testOpps[0].Id);
        OHT_OpportunityHealthController.HealthScoreData oldResult =
            OHT_OpportunityHealthController.getOpportunityHealthScore(testOpps[1].Id);
        Test.stopTest();

        System.assertEquals(100, recentResult.breakdown.lastActivityScore,
            'Recent activity should score 100');
        System.assertEquals(0, oldResult.breakdown.lastActivityScore,
            'Old activity should score 0');
    }
}
