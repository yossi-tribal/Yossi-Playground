/**
 * @description Test class for CSD_CSMPortfolioController
 * @author Tribal AI Platform
 * @date 2024
 */
@isTest
private class CSD_CSMPortfolioControllerTest {

    /**
     * @description Setup test data
     */
    @testSetup
    static void setupTestData() {
        // Create test user for CSM
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'CSM',
            Email = 'testcsm@example.com',
            Username = 'testcsm' + System.currentTimeMillis() + '@example.com',
            Alias = 'tcsm',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        System.runAs(testUser) {
            // Create test accounts with different health scores
            List<Account> accounts = new List<Account>();

            // At-risk account
            Account acc1 = new Account(
                Name = 'Test Account 1 - At Risk',
                CSD_Account_Health_Score__c = 'At Risk',
                CSD_Primary_CSM__c = testUser.Id
            );
            accounts.add(acc1);

            // Needs attention account
            Account acc2 = new Account(
                Name = 'Test Account 2 - Needs Attention',
                CSD_Account_Health_Score__c = 'Needs Attention',
                CSD_Primary_CSM__c = testUser.Id
            );
            accounts.add(acc2);

            // Healthy account
            Account acc3 = new Account(
                Name = 'Test Account 3 - Healthy',
                CSD_Account_Health_Score__c = 'Healthy',
                CSD_Primary_CSM__c = testUser.Id
            );
            accounts.add(acc3);

            // Account without CSM (should not appear in portfolio)
            Account acc4 = new Account(
                Name = 'Test Account 4 - No CSM',
                CSD_Account_Health_Score__c = 'Healthy'
            );
            accounts.add(acc4);

            insert accounts;

            // Create test cases for Account 1
            List<Case> cases = new List<Case>();
            cases.add(new Case(
                AccountId = acc1.Id,
                Subject = 'Test Case 1 - High Priority',
                Priority = 'High',
                Status = 'New'
            ));
            cases.add(new Case(
                AccountId = acc1.Id,
                Subject = 'Test Case 2 - Normal Priority',
                Priority = 'Medium',
                Status = 'Working'
            ));
            insert cases;

            // Create test tasks for Account 2
            List<Task> tasks = new List<Task>();
            tasks.add(new Task(
                WhatId = acc2.Id,
                Subject = 'Overdue Task',
                Status = 'Not Started',
                ActivityDate = Date.today().addDays(-5)
            ));
            tasks.add(new Task(
                WhatId = acc2.Id,
                Subject = 'Future Task',
                Status = 'Not Started',
                ActivityDate = Date.today().addDays(5)
            ));
            tasks.add(new Task(
                WhatId = acc2.Id,
                Subject = 'Completed Task',
                Status = 'Completed',
                ActivityDate = Date.today().addDays(-10)
            ));
            insert tasks;

            // Create test events for Account 3
            List<Event> events = new List<Event>();
            events.add(new Event(
                WhatId = acc3.Id,
                Subject = 'Past Event',
                StartDateTime = DateTime.now().addDays(-3),
                EndDateTime = DateTime.now().addDays(-3).addHours(1),
                ActivityDate = Date.today().addDays(-3)
            ));
            events.add(new Event(
                WhatId = acc3.Id,
                Subject = 'Future Event',
                StartDateTime = DateTime.now().addDays(2),
                EndDateTime = DateTime.now().addDays(2).addHours(1),
                ActivityDate = Date.today().addDays(2)
            ));
            insert events;

            // Create test opportunities
            List<Opportunity> opportunities = new List<Opportunity>();
            opportunities.add(new Opportunity(
                AccountId = acc1.Id,
                Name = 'Test Opportunity 1',
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Amount = 50000
            ));
            opportunities.add(new Opportunity(
                AccountId = acc2.Id,
                Name = 'Test Opportunity 2',
                StageName = 'Negotiation',
                CloseDate = Date.today().addDays(60),
                Amount = 75000
            ));
            insert opportunities;
        }
    }

    /**
     * @description Test getPortfolioSummary method
     */
    @isTest
    static void testGetPortfolioSummary() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            CSD_CSMPortfolioController.PortfolioSummary summary = CSD_CSMPortfolioController.getPortfolioSummary();

            // Assert summary values
            System.assertEquals(3, summary.totalAccounts, 'Should have 3 accounts assigned to CSM');
            System.assertEquals(1, summary.atRiskAccounts, 'Should have 1 at-risk account');
            System.assertEquals(1, summary.needsAttentionAccounts, 'Should have 1 needs attention account');
            System.assertEquals(1, summary.healthyAccounts, 'Should have 1 healthy account');
            System.assertEquals(2, summary.totalOpenCases, 'Should have 2 open cases');
            System.assertEquals(1, summary.totalOverdueTasks, 'Should have 1 overdue task');
            System.assertEquals(125000, summary.totalOpenPipeline, 'Should have total pipeline of 125000');
        }
        Test.stopTest();
    }

    /**
     * @description Test getPortfolioAccounts with all filter
     */
    @isTest
    static void testGetPortfolioAccountsAll() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<CSD_CSMPortfolioController.AccountRow> accounts =
                CSD_CSMPortfolioController.getPortfolioAccounts('all', 'accountName', 'asc', 25, 1);

            // Assert accounts returned
            System.assertEquals(3, accounts.size(), 'Should return 3 accounts for all filter');

            // Verify first account (alphabetically)
            System.assert(accounts[0].accountName.startsWith('Test Account'), 'Account name should start with Test Account');
            System.assertNotEquals(null, accounts[0].accountId, 'Account ID should not be null');
            System.assertNotEquals(null, accounts[0].healthScore, 'Health score should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Test getPortfolioAccounts with at-risk filter
     */
    @isTest
    static void testGetPortfolioAccountsAtRisk() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<CSD_CSMPortfolioController.AccountRow> accounts =
                CSD_CSMPortfolioController.getPortfolioAccounts('at-risk', 'accountName', 'asc', 25, 1);

            // Assert only at-risk accounts returned
            System.assertEquals(1, accounts.size(), 'Should return 1 at-risk account');
            System.assertEquals('At Risk', accounts[0].healthScore, 'Health score should be At Risk');
            System.assertEquals('red', accounts[0].healthScoreColor, 'Health score color should be red');
            System.assertEquals(2, accounts[0].openCasesCount, 'Should have 2 open cases');
            System.assertEquals(1, accounts[0].highPriorityCasesCount, 'Should have 1 high priority case');
        }
        Test.stopTest();
    }

    /**
     * @description Test getPortfolioAccounts with needs-attention filter
     */
    @isTest
    static void testGetPortfolioAccountsNeedsAttention() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<CSD_CSMPortfolioController.AccountRow> accounts =
                CSD_CSMPortfolioController.getPortfolioAccounts('needs-attention', 'accountName', 'asc', 25, 1);

            // Assert only needs-attention accounts returned
            System.assertEquals(1, accounts.size(), 'Should return 1 needs-attention account');
            System.assertEquals('Needs Attention', accounts[0].healthScore, 'Health score should be Needs Attention');
            System.assertEquals('yellow', accounts[0].healthScoreColor, 'Health score color should be yellow');
            System.assertEquals(1, accounts[0].overdueTasksCount, 'Should have 1 overdue task');
            System.assertEquals(true, accounts[0].hasOverdueTasks, 'Should have overdue tasks flag set');
        }
        Test.stopTest();
    }

    /**
     * @description Test getPortfolioAccounts with healthy filter
     */
    @isTest
    static void testGetPortfolioAccountsHealthy() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<CSD_CSMPortfolioController.AccountRow> accounts =
                CSD_CSMPortfolioController.getPortfolioAccounts('healthy', 'accountName', 'asc', 25, 1);

            // Assert only healthy accounts returned
            System.assertEquals(1, accounts.size(), 'Should return 1 healthy account');
            System.assertEquals('Healthy', accounts[0].healthScore, 'Health score should be Healthy');
            System.assertEquals('green', accounts[0].healthScoreColor, 'Health score color should be green');
        }
        Test.stopTest();
    }

    /**
     * @description Test getPortfolioAccounts with pagination
     */
    @isTest
    static void testGetPortfolioAccountsPagination() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            // Page 1 - 2 records
            List<CSD_CSMPortfolioController.AccountRow> page1 =
                CSD_CSMPortfolioController.getPortfolioAccounts('all', 'accountName', 'asc', 2, 1);
            System.assertEquals(2, page1.size(), 'Page 1 should return 2 accounts');

            // Page 2 - remaining records
            List<CSD_CSMPortfolioController.AccountRow> page2 =
                CSD_CSMPortfolioController.getPortfolioAccounts('all', 'accountName', 'asc', 2, 2);
            System.assertEquals(1, page2.size(), 'Page 2 should return 1 account');

            // Verify no duplicates
            System.assertNotEquals(page1[0].accountId, page2[0].accountId, 'Pages should not contain duplicate accounts');
        }
        Test.stopTest();
    }

    /**
     * @description Test getPortfolioAccounts with sorting
     */
    @isTest
    static void testGetPortfolioAccountsSorting() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            // Sort ascending
            List<CSD_CSMPortfolioController.AccountRow> accountsAsc =
                CSD_CSMPortfolioController.getPortfolioAccounts('all', 'accountName', 'asc', 25, 1);

            // Sort descending
            List<CSD_CSMPortfolioController.AccountRow> accountsDesc =
                CSD_CSMPortfolioController.getPortfolioAccounts('all', 'accountName', 'desc', 25, 1);

            // Verify sorting
            System.assertEquals(3, accountsAsc.size(), 'Should return 3 accounts');
            System.assertEquals(3, accountsDesc.size(), 'Should return 3 accounts');
            System.assertNotEquals(accountsAsc[0].accountName, accountsDesc[0].accountName,
                'First account should be different for asc vs desc');
        }
        Test.stopTest();
    }

    /**
     * @description Test getPortfolioAccounts with activity metrics
     */
    @isTest
    static void testGetPortfolioAccountsActivityMetrics() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 2 - Needs Attention' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<CSD_CSMPortfolioController.AccountRow> accounts =
                CSD_CSMPortfolioController.getPortfolioAccounts('all', 'accountName', 'asc', 25, 1);

            // Find the account with activities
            CSD_CSMPortfolioController.AccountRow accountWithActivities = null;
            for (CSD_CSMPortfolioController.AccountRow acc : accounts) {
                if (acc.accountId == testAccount.Id) {
                    accountWithActivities = acc;
                    break;
                }
            }

            System.assertNotEquals(null, accountWithActivities, 'Should find account with activities');
            System.assertNotEquals(null, accountWithActivities.daysSinceLastActivity,
                'Should have days since last activity calculated');
            System.assertNotEquals(null, accountWithActivities.nextActivityDate,
                'Should have next activity date');
            System.assertNotEquals(null, accountWithActivities.daysUntilNextActivity,
                'Should have days until next activity calculated');
        }
        Test.stopTest();
    }

    /**
     * @description Test security - users only see their own accounts
     */
    @isTest
    static void testSecurityIsolation() {
        User testUser1 = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        // Create second user
        User testUser2 = new User(
            FirstName = 'Test2',
            LastName = 'CSM2',
            Email = 'testcsm2@example.com',
            Username = 'testcsm2' + System.currentTimeMillis() + '@example.com',
            Alias = 'tcsm2',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser2;

        Test.startTest();

        // User 1 should see 3 accounts
        System.runAs(testUser1) {
            CSD_CSMPortfolioController.PortfolioSummary summary1 =
                CSD_CSMPortfolioController.getPortfolioSummary();
            System.assertEquals(3, summary1.totalAccounts, 'User 1 should see 3 accounts');
        }

        // User 2 should see 0 accounts
        System.runAs(testUser2) {
            CSD_CSMPortfolioController.PortfolioSummary summary2 =
                CSD_CSMPortfolioController.getPortfolioSummary();
            System.assertEquals(0, summary2.totalAccounts, 'User 2 should see 0 accounts');
        }

        Test.stopTest();
    }

    /**
     * @description Test error handling for getPortfolioSummary
     */
    @isTest
    static void testGetPortfolioSummaryErrorHandling() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            // Should not throw exception even with no accounts
            try {
                CSD_CSMPortfolioController.PortfolioSummary summary =
                    CSD_CSMPortfolioController.getPortfolioSummary();
                System.assertNotEquals(null, summary, 'Summary should not be null');
            } catch (Exception e) {
                System.assert(false, 'Should not throw exception: ' + e.getMessage());
            }
        }
        Test.stopTest();
    }

    /**
     * @description Test default parameters for getPortfolioAccounts
     */
    @isTest
    static void testGetPortfolioAccountsDefaultParameters() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            // Call with null parameters - should use defaults
            List<CSD_CSMPortfolioController.AccountRow> accounts =
                CSD_CSMPortfolioController.getPortfolioAccounts(null, null, null, null, null);

            // Should return accounts with default parameters
            System.assertEquals(3, accounts.size(), 'Should return accounts with default parameters');
        }
        Test.stopTest();
    }

    /**
     * @description Test inactive accounts filter
     */
    @isTest
    static void testGetPortfolioAccountsInactiveFilter() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            // All accounts have recent activity in test data, so inactive filter should return fewer
            List<CSD_CSMPortfolioController.AccountRow> accounts =
                CSD_CSMPortfolioController.getPortfolioAccounts('inactive', 'accountName', 'asc', 25, 1);

            // Verify only accounts with no activity > 30 days are returned
            for (CSD_CSMPortfolioController.AccountRow acc : accounts) {
                System.assertEquals(true, acc.hasNoActivity,
                    'Inactive filter should only return accounts with no activity > 30 days');
            }
        }
        Test.stopTest();
    }

    /**
     * @description Test pipeline calculations
     */
    @isTest
    static void testPipelineCalculations() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];
        Account testAccount1 = [SELECT Id FROM Account WHERE Name = 'Test Account 1 - At Risk' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<CSD_CSMPortfolioController.AccountRow> accounts =
                CSD_CSMPortfolioController.getPortfolioAccounts('all', 'accountName', 'asc', 25, 1);

            // Find account with opportunity
            CSD_CSMPortfolioController.AccountRow accountWithPipeline = null;
            for (CSD_CSMPortfolioController.AccountRow acc : accounts) {
                if (acc.accountId == testAccount1.Id) {
                    accountWithPipeline = acc;
                    break;
                }
            }

            System.assertNotEquals(null, accountWithPipeline, 'Should find account with pipeline');
            System.assertEquals(50000, accountWithPipeline.openPipelineAmount,
                'Should have correct pipeline amount');
        }
        Test.stopTest();
    }
}
