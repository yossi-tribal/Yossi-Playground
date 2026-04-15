/**
 * @description Test class for CSD_CSMPortfolioController
 * @author Tribal AI Platform
 * @date 2024
 */
@isTest
private class CSD_CSMPortfolioControllerTest {

    private static Datetime midday(Date dateValue) {
        return Datetime.newInstance(dateValue, Time.newInstance(12, 0, 0, 0));
    }

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
            // Five total open cases on acc1 triggers At Risk in automated health scoring
            cases.add(new Case(
                AccountId = acc1.Id,
                Subject = 'Test Case 3 - Low Open',
                Priority = 'Low',
                Status = 'New'
            ));
            cases.add(new Case(
                AccountId = acc1.Id,
                Subject = 'Test Case 4 - Low Open',
                Priority = 'Low',
                Status = 'New'
            ));
            cases.add(new Case(
                AccountId = acc1.Id,
                Subject = 'Test Case 5 - Low Open',
                Priority = 'Low',
                Status = 'New'
            ));
            insert cases;

            // Create additional cases with backdated CreatedDates for portfolio trend coverage
            List<Case> trendCases = new List<Case>();
            trendCases.add(new Case(
                AccountId = acc1.Id,
                Subject = 'Trend Case Current Year 1',
                Priority = 'Low',
                Status = 'Closed'
            ));
            trendCases.add(new Case(
                AccountId = acc2.Id,
                Subject = 'Trend Case Current Year 2',
                Priority = 'Low',
                Status = 'Closed'
            ));
            trendCases.add(new Case(
                AccountId = acc3.Id,
                Subject = 'Trend Case Prior Year',
                Priority = 'Low',
                Status = 'Closed'
            ));
            insert trendCases;

            Test.setCreatedDate(trendCases[0].Id, midday(Date.today().addMonths(-2)));
            Test.setCreatedDate(trendCases[1].Id, midday(Date.today().addMonths(-1)));
            Test.setCreatedDate(trendCases[2].Id, midday(Date.today().addMonths(-1).addYears(-1)));

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
            System.assertEquals(5, summary.totalOpenCases, 'Should have 5 open cases on at-risk account');
            System.assertEquals(1, summary.totalOverdueTasks, 'Should have 1 overdue task');
            System.assertEquals(125000, summary.totalOpenPipeline, 'Should have total pipeline of 125000');
            System.assert(summary.ytdCaseCount >= 4, 'Should include current-year portfolio cases in the summary');
            System.assertEquals(1, summary.priorYearCaseCount, 'Should include prior-year portfolio case count');
            System.assertEquals(3, summary.closedCasesAllTimeCount, 'Three closed cases in portfolio setup');
            System.assertNotEquals(null, summary.averageCaseResolutionHours, 'Average elapsed hours for closed cases');
        }
        Test.stopTest();
    }

    /**
     * @description Test portfolio case trend aggregates are populated for the snapshot
     */
    @isTest
    static void testGetPortfolioSummaryCaseTrends() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            CSD_CSMPortfolioController.PortfolioSummary summary = CSD_CSMPortfolioController.getPortfolioSummary();

            Integer currentWindowTotal =
                summary.caseMonth1 + summary.caseMonth2 + summary.caseMonth3 +
                summary.caseMonth4 + summary.caseMonth5 + summary.caseMonth6 +
                summary.caseMonth7 + summary.caseMonth8 + summary.caseMonth9 +
                summary.caseMonth10 + summary.caseMonth11 + summary.caseMonth12;
            Integer priorWindowTotal =
                summary.caseMonth1Prev + summary.caseMonth2Prev + summary.caseMonth3Prev +
                summary.caseMonth4Prev + summary.caseMonth5Prev + summary.caseMonth6Prev +
                summary.caseMonth7Prev + summary.caseMonth8Prev + summary.caseMonth9Prev +
                summary.caseMonth10Prev + summary.caseMonth11Prev + summary.caseMonth12Prev;

            System.assert(currentWindowTotal > 0, 'Current portfolio case trend should include recent cases');
            System.assert(priorWindowTotal > 0, 'Prior-year portfolio case trend should include comparison data');
            System.assertNotEquals('', summary.caseMonth1Label, 'Case trend labels should be populated');
            System.assertNotEquals('', summary.caseMonth12Label, 'Month 12 case trend label should be populated');
            System.assertNotEquals('', summary.caseMonth7Label, 'Month 7 case trend label should be populated');

            System.assertNotEquals('', summary.wonMonth12Label, 'Month 12 revenue label should be populated');
            System.assert(summary.wonMonth12 >= 0, 'Current month revenue should be non-negative');
            System.assert(summary.prevWonMonth12 >= 0, 'Prior year current month revenue should be non-negative');
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
            System.assertEquals(5, accounts[0].openCasesCount, 'Should have 5 open cases');
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
            System.assertEquals(0, summary2.ytdCaseCount, 'User 2 should have no current-year case counts');
            System.assertEquals(0, summary2.caseMonth1, 'User 2 should have empty trend counts');
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

    /**
     * @description Test getPortfolioHealthBreakdown returns correct factor counts
     */
    @isTest
    static void testGetPortfolioHealthBreakdown() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            CSD_CSMPortfolioController.PortfolioHealthBreakdown breakdown =
                CSD_CSMPortfolioController.getPortfolioHealthBreakdown();

            System.assertNotEquals(null, breakdown, 'Breakdown should not be null');

            // Verify all factor counters sum to 3 (total portfolio accounts)
            Integer activityTotal = breakdown.accountsInactiveRed + breakdown.accountsInactiveYellow + breakdown.accountsInactiveGreen;
            System.assertEquals(3, activityTotal, 'Activity factor should cover all 3 accounts');

            Integer overdueTotal = breakdown.accountsOverdueRed + breakdown.accountsOverdueYellow + breakdown.accountsOverdueGreen;
            System.assertEquals(3, overdueTotal, 'Overdue factor should cover all 3 accounts');

            Integer highPriTotal = breakdown.accountsHighPriRed + breakdown.accountsHighPriYellow + breakdown.accountsHighPriGreen;
            System.assertEquals(3, highPriTotal, 'High-pri factor should cover all 3 accounts');

            Integer casesTotal = breakdown.accountsCasesRed + breakdown.accountsCasesYellow + breakdown.accountsCasesGreen;
            System.assertEquals(3, casesTotal, 'Cases factor should cover all 3 accounts');

            // Account 1 has 1 high-pri case, so highPriYellow should be >= 1
            System.assert(breakdown.accountsHighPriYellow >= 1, 'Should have at least 1 account in high-pri yellow');

            // Account 2 has 1 overdue task, so overdueYellow should be >= 1
            System.assert(breakdown.accountsOverdueYellow >= 1, 'Should have at least 1 account in overdue yellow');
        }
        Test.stopTest();
    }

    /**
     * @description Test getOverdueTasksForPortfolio returns overdue tasks
     */
    @isTest
    static void testGetOverdueTasksForPortfolio() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<CSD_CSMPortfolioController.OverdueTaskRow> tasks =
                CSD_CSMPortfolioController.getOverdueTasksForPortfolio();

            System.assertNotEquals(null, tasks, 'Tasks list should not be null');
            System.assertEquals(1, tasks.size(), 'Should have 1 overdue task');

            CSD_CSMPortfolioController.OverdueTaskRow task = tasks[0];
            System.assertEquals('Overdue Task', task.subject, 'Should match task subject');
            System.assert(task.daysOverdue > 0, 'Days overdue should be positive');
            System.assertEquals('Not Started', task.status, 'Task status should be included for KPI modal rows');
            System.assertNotEquals(null, task.taskId, 'Task ID should not be null');
            System.assertNotEquals(null, task.accountName, 'Account name should not be null');
            System.assertNotEquals(null, task.accountId, 'Account ID should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Test getHighPriorityCasesForPortfolio returns high-pri cases
     */
    @isTest
    static void testGetHighPriorityCasesForPortfolio() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<CSD_CSMPortfolioController.HighPriorityCaseRow> cases =
                CSD_CSMPortfolioController.getHighPriorityCasesForPortfolio();

            System.assertNotEquals(null, cases, 'Cases list should not be null');
            System.assertEquals(1, cases.size(), 'Should have 1 high-priority case');

            CSD_CSMPortfolioController.HighPriorityCaseRow c = cases[0];
            System.assertEquals('High', c.priority, 'Should be high priority');
            System.assertNotEquals(null, c.caseId, 'Case ID should not be null');
            System.assertNotEquals(null, c.caseNumber, 'Case number should not be null');
            System.assertNotEquals(null, c.accountName, 'Account name should not be null');
        }
        Test.stopTest();
    }

    /**
     * @description Test getAllOpenCasesForPortfolio returns portfolio KPI modal rows
     */
    @isTest
    static void testGetAllOpenCasesForPortfolio() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<CSD_CSMPortfolioController.PortfolioCaseRow> cases =
                CSD_CSMPortfolioController.getAllOpenCasesForPortfolio();

            System.assertNotEquals(null, cases, 'Cases list should not be null');
            System.assertEquals(5, cases.size(), 'Should return every open case across the portfolio');

            CSD_CSMPortfolioController.PortfolioCaseRow firstCase = cases[0];
            System.assertNotEquals(null, firstCase.caseId, 'Case ID should be populated');
            System.assertNotEquals('', firstCase.caseNumber, 'Case number should be populated');
            System.assertNotEquals('', firstCase.accountName, 'Account name should be populated');
            System.assertNotEquals('', firstCase.ownerName, 'Owner name should be populated');
            System.assert(firstCase.age >= 0, 'Case age should be non-negative');
            System.assertEquals('Test Account 1 - At Risk', firstCase.accountName,
                'Open case rows should stay scoped to assigned portfolio accounts');
        }
        Test.stopTest();
    }

    /**
     * @description Test getAllOpenOpportunitiesForPortfolio returns portfolio KPI modal rows
     */
    @isTest
    static void testGetAllOpenOpportunitiesForPortfolio() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<CSD_CSMPortfolioController.PortfolioOpportunityRow> opportunities =
                CSD_CSMPortfolioController.getAllOpenOpportunitiesForPortfolio();

            System.assertNotEquals(null, opportunities, 'Opportunities list should not be null');
            System.assertEquals(2, opportunities.size(), 'Should return all open opportunities across the portfolio');

            CSD_CSMPortfolioController.PortfolioOpportunityRow firstOpportunity = opportunities[0];
            System.assertNotEquals(null, firstOpportunity.opportunityId, 'Opportunity ID should be populated');
            System.assertNotEquals('', firstOpportunity.name, 'Opportunity name should be populated');
            System.assertNotEquals('', firstOpportunity.accountName, 'Account name should be populated');
            System.assertNotEquals('', firstOpportunity.ownerName, 'Owner name should be populated');
            System.assert(firstOpportunity.amount > 0, 'Opportunity amount should be populated');
            System.assertEquals('Test Account 1 - At Risk', firstOpportunity.accountName,
                'Opportunities should stay scoped to assigned portfolio accounts');
        }
        Test.stopTest();
    }

    /**
     * @description Test AccountRow health factor fields and recent activities are populated
     */
    @isTest
    static void testAccountRowHealthFactorFields() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testcsm%' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<CSD_CSMPortfolioController.AccountRow> accounts =
                CSD_CSMPortfolioController.getPortfolioAccounts('all', 'accountName', 'asc', 25, 1);

            for (CSD_CSMPortfolioController.AccountRow acc : accounts) {
                // Health factor fields should be populated (not null for numeric types)
                System.assertNotEquals(null, acc.totalOpenCasesForHealth,
                    'totalOpenCasesForHealth should be set for ' + acc.accountName);
                System.assertNotEquals(null, acc.highPriorityCasesForHealth,
                    'highPriorityCasesForHealth should be set for ' + acc.accountName);
                System.assertNotEquals(null, acc.overdueTasksForHealth,
                    'overdueTasksForHealth should be set for ' + acc.accountName);

                // Recent activities should be a non-null list
                System.assertNotEquals(null, acc.recentActivities,
                    'recentActivities should not be null for ' + acc.accountName);
            }

            // Account 2 (Needs Attention) has a completed task, so it should have recent activities
            Account acc2 = [SELECT Id FROM Account WHERE Name = 'Test Account 2 - Needs Attention' LIMIT 1];
            for (CSD_CSMPortfolioController.AccountRow acc : accounts) {
                if (acc.accountId == acc2.Id) {
                    System.assert(acc.recentActivities.size() > 0,
                        'Account 2 should have recent activities from completed task');
                    for (CSD_CSMPortfolioController.RecentActivity ra : acc.recentActivities) {
                        System.assertNotEquals(null, ra.activityId,
                            'Each recent activity should have an activityId');
                    }
                    break;
                }
            }

            // Verify primaryContactId is populated when primaryContactName is set
            for (CSD_CSMPortfolioController.AccountRow acc : accounts) {
                if (acc.primaryContactName != null) {
                    System.assertNotEquals(null, acc.primaryContactId,
                        'primaryContactId should be set when primaryContactName is set for ' + acc.accountName);
                }
            }
        }
        Test.stopTest();
    }
}
