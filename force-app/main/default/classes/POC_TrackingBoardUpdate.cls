/** Supported top-level LWC request type for edits to a POC board record. */
public class POC_TrackingBoardUpdate {
    @AuraEnabled public Id id { get; set; }
    @AuraEnabled public String name { get; set; }
    @AuraEnabled public Id accountId { get; set; }
    @AuraEnabled public Id opportunityId { get; set; }
    @AuraEnabled public String lifecycleStatus { get; set; }
    @AuraEnabled public String pocType { get; set; }
    @AuraEnabled public String length { get; set; }
    @AuraEnabled public String health { get; set; }
    @AuraEnabled public Date startDate { get; set; }
    @AuraEnabled public Date endDate { get; set; }
    @AuraEnabled public String nextSteps { get; set; }
}
