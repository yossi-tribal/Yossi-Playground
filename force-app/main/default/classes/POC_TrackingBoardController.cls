/**
 * Reads and updates POC__c records for the tracking board.
 * Create, update, and per-field edit flags come from object and field describe.
 * Sharing and field access are enforced with USER_MODE. Opportunity_Amount__c
 * is a formula and is never written.
 */
public with sharing class POC_TrackingBoardController {
    public class BoardData {
        @AuraEnabled public String currencyCode;
        @AuraEnabled public Boolean truncated;
        @AuraEnabled public Boolean canCreate;
        @AuraEnabled public Boolean canUpdate;
        @AuraEnabled public FieldAccess fields;
        @AuraEnabled public List<BoardRow> pocs;
    }

    public class FieldAccess {
        @AuraEnabled public Boolean name;
        @AuraEnabled public Boolean account;
        @AuraEnabled public Boolean opportunity;
        @AuraEnabled public Boolean lifecycleStatus;
        @AuraEnabled public Boolean pocType;
        @AuraEnabled public Boolean length;
        @AuraEnabled public Boolean health;
        @AuraEnabled public Boolean startDate;
        @AuraEnabled public Boolean endDate;
        @AuraEnabled public Boolean nextSteps;
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
        data.canCreate = Schema.sObjectType.POC__c.isCreateable();
        data.canUpdate = Schema.sObjectType.POC__c.isUpdateable();
        data.fields = describeFieldAccess();
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
            data.pocs.add(toRow(record));
        }
        return data;
    }

    @AuraEnabled
    public static void updatePoc(POC_TrackingBoardUpdate input) {
        if (input == null || input.id == null) {
            throw handled('A POC record is required.');
        }
        if (!Schema.sObjectType.POC__c.isUpdateable()) {
            throw handled('You do not have permission to update POC records.');
        }

        List<POC__c> existing = [
            SELECT Id
            FROM POC__c
            WHERE Id = :input.id
            WITH USER_MODE
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            throw handled('You do not have access to this POC.');
        }

        POC__c record = new POC__c(Id = input.id);
        if (Schema.sObjectType.POC__c.fields.Name.isUpdateable()) {
            if (String.isBlank(input.name)) {
                throw handled('POC Name is required.');
            }
            record.Name = input.name.trim();
        }
        if (Schema.sObjectType.POC__c.fields.Account__c.isUpdateable()) {
            if (input.accountId == null) {
                throw handled('Account is required.');
            }
            record.Account__c = input.accountId;
        }
        if (Schema.sObjectType.POC__c.fields.Lifecycle_Status__c.isUpdateable()) {
            if (String.isBlank(input.lifecycleStatus)) {
                throw handled('Lifecycle Status is required.');
            }
            record.Lifecycle_Status__c = input.lifecycleStatus;
        }
        if (Schema.sObjectType.POC__c.fields.Primary_Opportunity__c.isUpdateable()) {
            record.Primary_Opportunity__c = input.opportunityId;
        }
        if (Schema.sObjectType.POC__c.fields.POC_Type__c.isUpdateable()) {
            record.POC_Type__c = blankToNull(input.pocType);
        }
        if (Schema.sObjectType.POC__c.fields.Length__c.isUpdateable()) {
            record.Length__c = blankToNull(input.length);
        }
        if (Schema.sObjectType.POC__c.fields.Health__c.isUpdateable()) {
            record.Health__c = blankToNull(input.health);
        }
        if (Schema.sObjectType.POC__c.fields.Start_Date__c.isUpdateable()) {
            record.Start_Date__c = input.startDate;
        }
        if (Schema.sObjectType.POC__c.fields.End_Date__c.isUpdateable()) {
            record.End_Date__c = input.endDate;
        }
        if (Schema.sObjectType.POC__c.fields.Next_Steps__c.isUpdateable()) {
            record.Next_Steps__c = blankToNull(input.nextSteps);
        }

        try {
            Database.update(new List<POC__c>{ record }, AccessLevel.USER_MODE);
        } catch (DmlException error) {
            throw handled(dmlMessage(error));
        } catch (System.SecurityException error) {
            throw handled('You do not have permission to update this POC.');
        }
    }

    private static FieldAccess describeFieldAccess() {
        FieldAccess access = new FieldAccess();
        access.name = Schema.sObjectType.POC__c.fields.Name.isUpdateable();
        access.account = Schema.sObjectType.POC__c.fields.Account__c.isUpdateable();
        access.opportunity = Schema.sObjectType.POC__c.fields.Primary_Opportunity__c.isUpdateable();
        access.lifecycleStatus = Schema.sObjectType.POC__c.fields.Lifecycle_Status__c.isUpdateable();
        access.pocType = Schema.sObjectType.POC__c.fields.POC_Type__c.isUpdateable();
        access.length = Schema.sObjectType.POC__c.fields.Length__c.isUpdateable();
        access.health = Schema.sObjectType.POC__c.fields.Health__c.isUpdateable();
        access.startDate = Schema.sObjectType.POC__c.fields.Start_Date__c.isUpdateable();
        access.endDate = Schema.sObjectType.POC__c.fields.End_Date__c.isUpdateable();
        access.nextSteps = Schema.sObjectType.POC__c.fields.Next_Steps__c.isUpdateable();
        return access;
    }

    private static BoardRow toRow(POC__c record) {
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
        return row;
    }

    private static String blankToNull(String value) {
        return String.isBlank(value) ? null : value;
    }

    private static String dmlMessage(DmlException error) {
        List<String> messages = new List<String>();
        for (Integer index = 0; index < error.getNumDml(); index++) {
            messages.add(error.getDmlMessage(index));
        }
        return messages.isEmpty() ? error.getMessage() : String.join(messages, ' ');
    }

    private static AuraHandledException handled(String message) {
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }
}
