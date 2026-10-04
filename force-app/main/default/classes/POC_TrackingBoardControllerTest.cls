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
        Assert.isTrue(data.canUpdate, 'The running user can update POC records.');
        Assert.isTrue(data.canCreate, 'The running user can create POC records.');
        Assert.isNotNull(data.fields, 'Field update flags should be returned with the board.');
        Assert.isTrue(data.fields.name, 'Name should be updateable for the running user.');
        Assert.isTrue(data.fields.account, 'Account should be updateable for the running user.');
        Assert.isTrue(data.fields.opportunity, 'Primary Opportunity should be updateable for the running user.');
        Assert.isTrue(data.fields.lifecycleStatus, 'Lifecycle Status should be updateable for the running user.');
        Assert.isTrue(data.fields.pocType, 'POC Type should be updateable for the running user.');
        Assert.isTrue(data.fields.length, 'Length should be updateable for the running user.');
        Assert.isTrue(data.fields.health, 'Health should be updateable for the running user.');
        Assert.isTrue(data.fields.startDate, 'Start Date should be updateable for the running user.');
        Assert.isTrue(data.fields.endDate, 'End Date should be updateable for the running user.');
        Assert.isTrue(data.fields.nextSteps, 'Next Steps should be updateable for the running user.');
        Assert.isFalse(
            Schema.sObjectType.POC__c.fields.Opportunity_Amount__c.isUpdateable(),
            'Opportunity Amount is a formula and must stay read-only.'
        );
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
        Assert.areEqual(Decimal.valueOf(120000), alpha.opportunityAmount);
        Assert.areEqual(UserInfo.getUserId(), alpha.ownerId);

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

    @isTest
    static void updatePoc_savesEditableFields() {
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

        POC__c poc = new POC__c(
            Name = 'Alpha Water POC',
            Account__c = account.Id,
            Primary_Opportunity__c = opportunity.Id,
            Lifecycle_Status__c = 'Pre-POC',
            POC_Type__c = 'Un-Paid',
            Length__c = '2 Weeks',
            Health__c = 'Yellow',
            Start_Date__c = Date.newInstance(2026, 6, 3),
            End_Date__c = Date.newInstance(2026, 7, 1),
            Next_Steps__c = 'Original next step'
        );
        insert poc;

        POC_TrackingBoardController.PocUpdate input = new POC_TrackingBoardController.PocUpdate();
        input.id = poc.Id;
        input.name = 'Alpha Water POC Updated';
        input.accountId = account.Id;
        input.opportunityId = opportunity.Id;
        input.lifecycleStatus = 'Active';
        input.pocType = 'Paid';
        input.length = '1 Month';
        input.health = 'Green';
        input.startDate = Date.newInstance(2026, 6, 10);
        input.endDate = Date.newInstance(2026, 8, 1);
        input.nextSteps = 'Confirm the success plan';

        Test.startTest();
        POC_TrackingBoardController.updatePoc(input);
        Test.stopTest();

        POC__c saved = [
            SELECT Name, Lifecycle_Status__c, POC_Type__c, Length__c, Health__c,
                   Start_Date__c, End_Date__c, Next_Steps__c, Opportunity_Amount__c,
                   Account__c, Primary_Opportunity__c
            FROM POC__c
            WHERE Id = :poc.Id
        ];
        Assert.areEqual('Alpha Water POC Updated', saved.Name);
        Assert.areEqual(account.Id, saved.Account__c);
        Assert.areEqual(opportunity.Id, saved.Primary_Opportunity__c);
        Assert.areEqual('Active', saved.Lifecycle_Status__c);
        Assert.areEqual('Paid', saved.POC_Type__c);
        Assert.areEqual('1 Month', saved.Length__c);
        Assert.areEqual('Green', saved.Health__c);
        Assert.areEqual(Date.newInstance(2026, 6, 10), saved.Start_Date__c);
        Assert.areEqual(Date.newInstance(2026, 8, 1), saved.End_Date__c);
        Assert.areEqual('Confirm the success plan', saved.Next_Steps__c);
        Assert.areEqual(Decimal.valueOf(120000), saved.Opportunity_Amount__c);

        POC_TrackingBoardController.BoardData data = POC_TrackingBoardController.getPocs();
        POC_TrackingBoardController.BoardRow row = data.pocs[0];
        Assert.areEqual('Alpha Water POC Updated', row.name);
        Assert.areEqual('Active', row.lifecycleStatus);
        Assert.areEqual('Confirm the success plan', row.nextSteps);
    }

    @isTest
    static void updatePoc_rejectsOpportunityOnAnotherAccount() {
        Account home = new Account(Name = 'Home Account');
        Account other = new Account(Name = 'Other Account');
        insert new List<Account>{ home, other };

        Opportunity foreignOpportunity = new Opportunity(
            Name = 'Foreign Deal',
            AccountId = other.Id,
            StageName = openStage(),
            CloseDate = Date.today().addDays(45),
            Amount = 80000
        );
        insert foreignOpportunity;

        POC__c poc = new POC__c(
            Name = 'Mismatch POC',
            Account__c = home.Id,
            Lifecycle_Status__c = 'Pre-POC'
        );
        insert poc;

        POC_TrackingBoardController.PocUpdate input = new POC_TrackingBoardController.PocUpdate();
        input.id = poc.Id;
        input.name = poc.Name;
        input.accountId = home.Id;
        input.opportunityId = foreignOpportunity.Id;
        input.lifecycleStatus = 'Pre-POC';

        Test.startTest();
        try {
            POC_TrackingBoardController.updatePoc(input);
            Assert.fail('A mismatched Opportunity Account should be rejected.');
        } catch (AuraHandledException error) {
            Assert.isTrue(
                error.getMessage().contains('different Account'),
                'Expected the validation rule message, got: ' + error.getMessage()
            );
        }
        Test.stopTest();

        POC__c saved = [
            SELECT Primary_Opportunity__c, Account__c
            FROM POC__c
            WHERE Id = :poc.Id
        ];
        Assert.areEqual(home.Id, saved.Account__c);
        Assert.isNull(saved.Primary_Opportunity__c, 'A blocked save must leave the POC unchanged.');
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
