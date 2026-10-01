/**
 * Reads POC__c records for the tracking board. Field list is limited to columns
 * that exist on the object today. Sharing and field access are enforced.
 */
public with sharing class POC_TrackingBoardController {
    public class BoardData {
        @AuraEnabled public String currencyCode;
        @AuraEnabled public Boolean truncated;
        @AuraEnabled public List<BoardRow> pocs;
    }

    public class BoardRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String lifecycleStatus;
        @AuraEnabled public String pocType;
        @AuraEnabled public String length;
        @AuraEnabled public String health;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String nextSteps;
        @AuraEnabled public Decimal opportunityAmount;
        @AuraEnabled public Id ownerId;
        @AuraEnabled public String ownerName;
    }

    private static final Integer ROW_LIMIT = 500;

    @AuraEnabled(cacheable=true)
    public static BoardData getPocs() {
        BoardData data = new BoardData();
        data.currencyCode = UserInfo.getDefaultCurrency();
        data.pocs = new List<BoardRow>();

        Integer rowLimit = ROW_LIMIT;
        List<POC__c> records = [
            SELECT Id, Name,
                   Account__c, Account__r.Name,
                   Primary_Opportunity__c, Primary_Opportunity__r.Name,
                   Lifecycle_Status__c, POC_Type__c, Length__c, Health__c,
                   Start_Date__c, End_Date__c, Next_Steps__c,
                   Opportunity_Amount__c,
                   OwnerId, Owner.Name
            FROM POC__c
            WITH USER_MODE
            ORDER BY Name
            LIMIT :rowLimit
        ];
        data.truncated = records.size() == ROW_LIMIT;

        for (POC__c record : records) {
            BoardRow row = new BoardRow();
            row.id = record.Id;
            row.name = record.Name;
            row.accountId = record.Account__c;
            row.accountName = record.Account__r == null ? null : record.Account__r.Name;
            row.opportunityId = record.Primary_Opportunity__c;
            row.opportunityName = record.Primary_Opportunity__r == null ? null : record.Primary_Opportunity__r.Name;
            row.lifecycleStatus = record.Lifecycle_Status__c;
            row.pocType = record.POC_Type__c;
            row.length = record.Length__c;
            row.health = record.Health__c;
            row.startDate = record.Start_Date__c;
            row.endDate = record.End_Date__c;
            row.nextSteps = record.Next_Steps__c;
            row.opportunityAmount = record.Opportunity_Amount__c;
            row.ownerId = record.OwnerId;
            row.ownerName = record.Owner == null ? null : record.Owner.Name;
            data.pocs.add(row);
        }
        return data;
    }
}
