/**
 * @description Schedulable batch class for recalculating opportunity health scores. Queries all open
 * opportunities, calls OpportunityHealthController to calculate scores, and updates health fields.
 * Designed to run on a schedule (e.g., nightly) to keep scores current for reporting and list views.
 */
public with sharing class OHT_OpportunityHealthBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {

    private Integer recordsProcessed = 0;
    private Integer recordsSuccessful = 0;
    private Integer recordsFailed = 0;

    /**
     * @description Schedulable execute method to launch the batch job
     * @param sc SchedulableContext
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new OHT_OpportunityHealthBatch(), 200);
    }

    /**
     * @description Start method - queries all open opportunities
     * @param bc BatchableContext
     * @return Database.QueryLocator for open opportunities
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query all open opportunities with necessary fields for health score calculation
        return Database.getQueryLocator([
            SELECT Id, Name, StageName, CloseDate, LastActivityDate,
                   IsClosed, IsWon, CreatedDate,
                   OHT_Health_Score__c, OHT_Risk_Level__c, OHT_Health_Score_Last_Updated__c
            FROM Opportunity
            WHERE IsClosed = false
        ]);
    }

    /**
     * @description Execute method - processes batch of opportunities and updates health scores
     * @param bc BatchableContext
     * @param opportunities List of opportunities in this batch
     */
    public void execute(Database.BatchableContext bc, List<Opportunity> opportunities) {
        recordsProcessed += opportunities.size();

        try {
            // Use the controller's bulk update method
            OHT_OpportunityHealthController.updateHealthScoresForOpportunities(opportunities);
            recordsSuccessful += opportunities.size();
        } catch (Exception e) {
            recordsFailed += opportunities.size();
            System.debug('Error processing batch: ' + e.getMessage());
        }
    }

    /**
     * @description Finish method - logs completion statistics
     * @param bc BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('OpportunityHealthBatch completed. ' +
                     'Processed: ' + recordsProcessed + ', ' +
                     'Successful: ' + recordsSuccessful + ', ' +
                     'Failed: ' + recordsFailed);
    }
}
