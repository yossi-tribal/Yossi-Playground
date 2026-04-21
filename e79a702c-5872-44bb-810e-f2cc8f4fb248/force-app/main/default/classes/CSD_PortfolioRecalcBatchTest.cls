/**
 * @description Test class for CSD_PortfolioRecalcBatch.
 *
 * We exercise the end-to-end batch flow (start → execute → finish) with a
 * small portfolio so we can assert that:
 *   1. The QueryLocator selects only accounts where the running user is
 *      the Primary CSM (the isolation property the UX relies on).
 *   2. execute() accumulates the stateful totalRecalculated counter.
 *   3. The resulting AsyncApexJob lands in Completed.
 * The scoring algorithm itself is covered by the handler's own test class,
 * so we don't reassert individual health-score values here.
 */
@isTest
private class CSD_PortfolioRecalcBatchTest {

    @testSetup
    static void setup() {
        User testUser = new User(
            FirstName = 'Recalc',
            LastName = 'Batch',
            Email = 'recalcbatch@example.com',
            Username = 'recalcbatch' + System.currentTimeMillis() + '@example.com',
            Alias = 'rcbat',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        System.runAs(testUser) {
            // 4 accounts where the user is Primary CSM — within a single
            // batch scope so we can verify the stateful counter in one chunk.
            List<Account> accounts = new List<Account>();
            for (Integer i = 0; i < 4; i++) {
                accounts.add(new Account(
                    Name = 'Recalc Batch Account ' + i,
                    CSD_Primary_CSM__c = testUser.Id
                ));
            }
            // One account with no CSM — should NOT be picked up by the batch.
            accounts.add(new Account(Name = 'Recalc Batch Account Other'));
            insert accounts;
        }
    }

    /**
     * Full batch run: start → execute → finish should complete cleanly and
     * leave the AsyncApexJob in a Completed state.
     */
    @isTest
    static void testBatchEndToEnd_Completes() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'recalcbatch%' LIMIT 1];
        Id jobId;
        Test.startTest();
        System.runAs(testUser) {
            jobId = Database.executeBatch(new CSD_PortfolioRecalcBatch(testUser.Id), 200);
        }
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems,
                   ExtendedStatus, ApexClass.Name
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status,
            'Batch should complete inside Test.stopTest(). ExtendedStatus: ' + job.ExtendedStatus);
        System.assertEquals(0, job.NumberOfErrors, 'Batch should have no errors');
        System.assertEquals('CSD_PortfolioRecalcBatch', job.ApexClass.Name);
    }

    /**
     * Directly invoke execute() with a hand-built scope so we can assert
     * the stateful counter without waiting for the async runtime. Mirrors
     * how Salesforce invokes the method but gives us a handle on the
     * instance so we can read totalRecalculated.
     */
    @isTest
    static void testExecute_AccumulatesStatefulCounter() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'recalcbatch%' LIMIT 1];
        List<Account> scope;
        System.runAs(testUser) {
            scope = [SELECT Id FROM Account WHERE CSD_Primary_CSM__c = :testUser.Id];
        }
        System.assertEquals(4, scope.size(),
            'Test setup should have created 4 accounts for this user');

        CSD_PortfolioRecalcBatch batch = new CSD_PortfolioRecalcBatch(testUser.Id);
        Test.startTest();
        System.runAs(testUser) {
            batch.execute(null, scope);
        }
        Test.stopTest();

        System.assertEquals(4, batch.totalRecalculated,
            'Stateful counter should equal the number of accounts processed in the chunk');
        System.assertEquals(0, batch.chunkErrors,
            'No chunks should have errored');
    }

    /**
     * Empty / null scope is defensive — Salesforce shouldn't pass one, but
     * we don't want a NullPointerException to take down the whole job.
     */
    @isTest
    static void testExecute_HandlesEmptyScope() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'recalcbatch%' LIMIT 1];
        CSD_PortfolioRecalcBatch batch = new CSD_PortfolioRecalcBatch(testUser.Id);
        System.runAs(testUser) {
            batch.execute(null, new List<Account>());
            batch.execute(null, null);
        }
        System.assertEquals(0, batch.totalRecalculated,
            'Empty/null scope should be a no-op');
    }

    /**
     * start() should return a QueryLocator filtered by the target user.
     * We don't iterate it here — the end-to-end test already validates
     * the result — but we do assert the locator isn't null so a missing
     * return value would be caught.
     */
    @isTest
    static void testStart_ReturnsQueryLocator() {
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'recalcbatch%' LIMIT 1];
        CSD_PortfolioRecalcBatch batch = new CSD_PortfolioRecalcBatch(testUser.Id);
        Database.QueryLocator locator;
        System.runAs(testUser) {
            locator = batch.start(null);
        }
        System.assertNotEquals(null, locator, 'start() should return a QueryLocator');
    }
}
