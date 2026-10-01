@isTest
private class POC_TrackingBoardControllerTest {
    @isTest
    static void getPocs_returnsStoredFieldsAndBlanks() {
        Account account = new Account(Name = 'Enersys');
        insert account;

        Opportunity opportunity = new Opportunity(
            Name = 'Enersys Expansion',
            AccountId = account.Id,
            StageName = openStage(),
            CloseDate = Date.today().addDays(90),
            Amount = 120000
        );
        insert opportunity;

        insert new List<POC__c>{
            new POC__c(
                Name = 'Alpha Water POC',
                Account__c = account.Id,
                Primary_Opportunity__c = opportunity.Id,
                Lifecycle_Status__c = 'Active',
                POC_Type__c = 'Paid',
                Length__c = '2 Weeks',
                Health__c = 'Green',
                Start_Date__c = Date.newInstance(2026, 6, 3),
                End_Date__c = Date.newInstance(2026, 12, 31),
                Next_Steps__c = 'Kickoff meeting - week of July\nConfirm the success plan'
            ),
            new POC__c(
                Name = 'Mesa Imaging POC',
                Account__c = account.Id,
                Lifecycle_Status__c = 'Pre-POC',
                POC_Type__c = 'Un-Paid'
            ),
            new POC__c(
                Name = 'Zulu Systems POC',
                Account__c = account.Id,
                Lifecycle_Status__c = 'Complete',
                Health__c = 'Red',
                Length__c = '1 Month'
            )
        };

        Test.startTest();
        POC_TrackingBoardController.BoardData data = POC_TrackingBoardController.getPocs();
        Test.stopTest();

        Assert.isNotNull(data.currencyCode, 'The board needs a currency code to format opportunity amount.');
        Assert.isFalse(data.truncated, 'Three records should not hit the board limit.');
        Assert.areEqual(3, data.pocs.size(), 'Every POC the running user can read should be returned.');

        Assert.areEqual('Alpha Water POC', data.pocs[0].name);
        Assert.areEqual('Mesa Imaging POC', data.pocs[1].name);
        Assert.areEqual('Zulu Systems POC', data.pocs[2].name);

        POC_TrackingBoardController.BoardRow alpha = data.pocs[0];
        Assert.areEqual(account.Id, alpha.accountId);
        Assert.areEqual('Enersys', alpha.accountName);
        Assert.areEqual(opportunity.Id, alpha.opportunityId);
        Assert.areEqual('Enersys Expansion', alpha.opportunityName);
        Assert.areEqual('Active', alpha.lifecycleStatus);
        Assert.areEqual('Paid', alpha.pocType);
        Assert.areEqual('2 Weeks', alpha.length);
        Assert.areEqual('Green', alpha.health);
        Assert.areEqual(Date.newInstance(2026, 6, 3), alpha.startDate);
        Assert.areEqual(Date.newInstance(2026, 12, 31), alpha.endDate);
        Assert.isTrue(alpha.nextSteps.startsWith('Kickoff meeting'), 'Next steps should round-trip.');
        Assert.areEqual(0, alpha.opportunityAmount.compareTo(Decimal.valueOf(120000)));
        Assert.areEqual(UserInfo.getUserId(), alpha.ownerId);
        Assert.isNotNull(alpha.ownerName);

        POC_TrackingBoardController.BoardRow mesa = data.pocs[1];
        Assert.areEqual('Pre-POC', mesa.lifecycleStatus);
        Assert.areEqual('Un-Paid', mesa.pocType);
        Assert.isNull(mesa.health);
        Assert.isNull(mesa.length);
        Assert.isNull(mesa.opportunityId);
        Assert.isNull(mesa.opportunityAmount);
        Assert.isNull(mesa.nextSteps);
        Assert.isNull(mesa.startDate);
        Assert.isNull(mesa.endDate);
    }

    private static String openStage() {
        List<OpportunityStage> stages = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsActive = true AND IsClosed = false
            LIMIT 1
        ];
        return stages.isEmpty() ? 'Prospecting' : stages[0].MasterLabel;
    }
}
