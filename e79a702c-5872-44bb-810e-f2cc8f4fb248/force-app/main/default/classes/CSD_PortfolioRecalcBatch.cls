/**
 * @description Batch job that recalculates Account health scores for every
 * account where a given user is the Primary CSM. Used by the Portfolio
 * dashboard's "Recalculate all" CTA so we can process a portfolio of any
 * size without hitting synchronous governor limits (SOQL rows, DML rows,
 * CPU time). Each execute() scope is handed to CSD_AccountHealthScoreHandler
 * so the scoring logic remains a single source of truth.
 *
 * Sharing: with sharing, matching the rest of the project. The driving
 * Account query filters by Primary CSM so sharing rules don't remove
 * records the user would have otherwise seen.
 *
 * Batch size: recommended 200 (the default passed by the controller).
 * The handler issues 6 queries per scope (accounts, closed Tasks, Events,
 * and three Case/Task aggregates). 200 accounts gives comfortable headroom
 * under the 50k SOQL-rows-per-query governor even on activity-dense orgs.
 *
 * Stateful so we can accumulate progress counters (total accounts
 * recalculated, error count) across chunks for reporting in the finish()
 * hook or a future platform-event notification.
 */
public with sharing class CSD_PortfolioRecalcBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible
    private final Id targetUserId;

    /** Total accounts successfully recalculated across all chunks. */
    @TestVisible
    public Integer totalRecalculated = 0;

    /** Number of chunks that failed (caught inside execute). */
    @TestVisible
    public Integer chunkErrors = 0;

    public CSD_PortfolioRecalcBatch(Id targetUserId) {
        this.targetUserId = targetUserId;
    }

    /**
     * Driving query. Using a QueryLocator here (not an iterable) is what
     * lets the job process portfolios of any size — QueryLocator streams
     * results in chunks from the database instead of loading them into
     * memory upfront.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Id userId = this.targetUserId;
        return Database.getQueryLocator([
            SELECT Id
            FROM Account
            WHERE CSD_Primary_CSM__c = :userId
        ]);
    }

    /**
     * Recalculate health scores for the current chunk. Failures in a
     * single chunk don't abort the job — we log them on the stateful
     * counter so the finish() hook can still report totals.
     */
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }
        Set<Id> accountIds = new Set<Id>();
        for (Account a : scope) {
            accountIds.add(a.Id);
        }
        try {
            CSD_AccountHealthScoreHandler.calculateHealthScores(accountIds);
            this.totalRecalculated += accountIds.size();
        } catch (Exception e) {
            this.chunkErrors += 1;
            System.debug(LoggingLevel.ERROR,
                'CSD_PortfolioRecalcBatch chunk failed: ' + e.getMessage()
                + '\n' + e.getStackTraceString());
        }
    }

    /**
     * No-op today. Kept explicitly so future progress hooks (Platform
     * Event fire, email-on-failure, etc.) have an obvious place to live.
     * The LWC polls AsyncApexJob directly for completion, so no finish-
     * side notification is required for the current UX.
     */
    public void finish(Database.BatchableContext bc) {
        // intentionally empty - LWC polls AsyncApexJob for status
    }
}
