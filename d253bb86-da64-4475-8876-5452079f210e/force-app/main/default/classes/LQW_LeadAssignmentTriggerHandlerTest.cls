/**
 * @description Test class for LQW_LeadAssignmentTriggerHandler
 * Tests code-driven criteria evaluation, default fallback, and auto-create functionality
 */
@isTest
private class LQW_LeadAssignmentTriggerHandlerTest {

    /**
     * @description Test data setup
     */
    @testSetup
    static void setupTestData() {
        // Create question lists
        List<LQW_Question_List__c> questionLists = new List<LQW_Question_List__c>();

        // Default list
        LQW_Question_List__c defaultList = new LQW_Question_List__c();
        defaultList.LQW_List_Name__c = 'General Qualification';
        defaultList.LQW_Description__c = 'Default questions for all leads';
        defaultList.LQW_Is_Active__c = true;
        defaultList.LQW_Is_Default__c = true;
        defaultList.LQW_High_Quality_Threshold__c = 5;
        defaultList.LQW_Medium_Quality_Threshold__c = 3;
        questionLists.add(defaultList);

        // Enterprise list
        LQW_Question_List__c enterpriseList = new LQW_Question_List__c();
        enterpriseList.LQW_List_Name__c = 'Enterprise Leads';
        enterpriseList.LQW_Description__c = 'Questions for enterprise leads';
        enterpriseList.LQW_Is_Active__c = true;
        enterpriseList.LQW_Is_Default__c = false;
        enterpriseList.LQW_High_Quality_Threshold__c = 7;
        enterpriseList.LQW_Medium_Quality_Threshold__c = 4;
        questionLists.add(enterpriseList);

        // Partner list
        LQW_Question_List__c partnerList = new LQW_Question_List__c();
        partnerList.LQW_List_Name__c = 'Partner Leads';
        partnerList.LQW_Description__c = 'Questions for partner leads';
        partnerList.LQW_Is_Active__c = true;
        partnerList.LQW_Is_Default__c = false;
        partnerList.LQW_High_Quality_Threshold__c = 6;
        partnerList.LQW_Medium_Quality_Threshold__c = 3;
        questionLists.add(partnerList);

        insert questionLists;

        // Create sample questions for each list
        List<LQW_Qualification_Question__c> questions = new List<LQW_Qualification_Question__c>();

        for (LQW_Question_List__c questionList : questionLists) {
            for (Integer i = 1; i <= 3; i++) {
                LQW_Qualification_Question__c question = new LQW_Qualification_Question__c();
                question.LQW_Question_List__c = questionList.Id;
                question.LQW_Question_Text__c = 'Sample question ' + i + ' for ' + questionList.LQW_List_Name__c;
                question.LQW_Question_Order__c = i;
                question.LQW_Score_Value__c = 1;
                question.LQW_Point_Earning_Answer__c = 'Yes';
                question.LQW_Is_Active__c = true;
                question.LQW_Is_Dealbreaker__c = false;
                questions.add(question);
            }
        }

        insert questions;
    }

    /**
     * @description Test auto-assignment on lead insert with Web lead source
     */
    @isTest
    static void testLeadInsert_WebSource_AssignsEnterpriseList() {
        // Get the Enterprise list
        LQW_Question_List__c enterpriseList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Enterprise Leads' LIMIT 1
        ];

        Test.startTest();

        // Create lead with Web source
        Lead testLead = new Lead();
        testLead.FirstName = 'Test';
        testLead.LastName = 'Lead';
        testLead.Company = 'Test Company';
        testLead.LeadSource = 'Web';
        testLead.Status = 'Open - Not Contacted';
        insert testLead;

        Test.stopTest();

        // Verify Enterprise list was assigned
        Lead updatedLead = [SELECT Id, LQW_Question_List__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(enterpriseList.Id, updatedLead.LQW_Question_List__c,
            'Enterprise list should be assigned to Web leads');
    }

    /**
     * @description Test auto-assignment on lead insert with Partner Referral source
     */
    @isTest
    static void testLeadInsert_PartnerReferral_AssignsPartnerList() {
        // Get the Partner list
        LQW_Question_List__c partnerList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Partner Leads' LIMIT 1
        ];

        Test.startTest();

        // Create lead with Partner Referral source
        Lead testLead = new Lead();
        testLead.FirstName = 'Test';
        testLead.LastName = 'Partner Lead';
        testLead.Company = 'Partner Company';
        testLead.LeadSource = 'Partner Referral';
        testLead.Status = 'Open - Not Contacted';
        insert testLead;

        Test.stopTest();

        // Verify Partner list was assigned
        Lead updatedLead = [SELECT Id, LQW_Question_List__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(partnerList.Id, updatedLead.LQW_Question_List__c,
            'Partner list should be assigned to Partner Referral leads');
    }

    /**
     * @description Test default list assignment when no criteria match
     */
    @isTest
    static void testLeadInsert_NoMatch_AssignsDefaultList() {
        // Get the default list
        LQW_Question_List__c defaultList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_Is_Default__c = true LIMIT 1
        ];

        Test.startTest();

        // Create lead with source that doesn't match any criteria
        Lead testLead = new Lead();
        testLead.FirstName = 'Test';
        testLead.LastName = 'Default Lead';
        testLead.Company = 'Default Company';
        testLead.LeadSource = 'Other';
        testLead.Status = 'Open - Not Contacted';
        insert testLead;

        Test.stopTest();

        // Verify default list was assigned
        Lead updatedLead = [SELECT Id, LQW_Question_List__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(defaultList.Id, updatedLead.LQW_Question_List__c,
            'Default list should be assigned when no criteria match');
    }

    /**
     * @description Test lead update with changed lead source
     */
    @isTest
    static void testLeadUpdate_SourceChanged_ReassignsList() {
        // Get the lists
        LQW_Question_List__c enterpriseList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Enterprise Leads' LIMIT 1
        ];
        LQW_Question_List__c partnerList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Partner Leads' LIMIT 1
        ];

        // Create lead with Web source (will get Enterprise list)
        Lead testLead = new Lead();
        testLead.FirstName = 'Test';
        testLead.LastName = 'Update Lead';
        testLead.Company = 'Update Company';
        testLead.LeadSource = 'Web';
        testLead.Status = 'Open - Not Contacted';
        insert testLead;

        // Verify initial assignment
        Lead leadAfterInsert = [SELECT Id, LQW_Question_List__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(enterpriseList.Id, leadAfterInsert.LQW_Question_List__c);

        Test.startTest();

        // Update lead source to Partner Referral
        testLead.LeadSource = 'Partner Referral';
        update testLead;

        Test.stopTest();

        // Verify list was reassigned to Partner list
        Lead leadAfterUpdate = [SELECT Id, LQW_Question_List__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(partnerList.Id, leadAfterUpdate.LQW_Question_List__c,
            'Partner list should be assigned after source change');
    }

    /**
     * @description Test bulk lead insert
     */
    @isTest
    static void testBulkLeadInsert_AssignsCorrectLists() {
        // Get the lists
        LQW_Question_List__c enterpriseList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Enterprise Leads' LIMIT 1
        ];
        LQW_Question_List__c partnerList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Partner Leads' LIMIT 1
        ];
        LQW_Question_List__c defaultList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_Is_Default__c = true LIMIT 1
        ];

        List<Lead> testLeads = new List<Lead>();

        // Create 50 Web leads
        for (Integer i = 0; i < 50; i++) {
            Lead lead = new Lead();
            lead.FirstName = 'Web';
            lead.LastName = 'Lead ' + i;
            lead.Company = 'Company ' + i;
            lead.LeadSource = 'Web';
            lead.Status = 'Open - Not Contacted';
            testLeads.add(lead);
        }

        // Create 50 Partner leads
        for (Integer i = 0; i < 50; i++) {
            Lead lead = new Lead();
            lead.FirstName = 'Partner';
            lead.LastName = 'Lead ' + i;
            lead.Company = 'Partner Company ' + i;
            lead.LeadSource = 'Partner Referral';
            lead.Status = 'Open - Not Contacted';
            testLeads.add(lead);
        }

        // Create 50 Other leads
        for (Integer i = 0; i < 50; i++) {
            Lead lead = new Lead();
            lead.FirstName = 'Other';
            lead.LastName = 'Lead ' + i;
            lead.Company = 'Other Company ' + i;
            lead.LeadSource = 'Other';
            lead.Status = 'Open - Not Contacted';
            testLeads.add(lead);
        }

        Test.startTest();
        insert testLeads;
        Test.stopTest();

        // Verify assignments
        List<Lead> webLeads = [
            SELECT Id, LQW_Question_List__c FROM Lead WHERE LeadSource = 'Web'
        ];
        List<Lead> partnerLeads = [
            SELECT Id, LQW_Question_List__c FROM Lead WHERE LeadSource = 'Partner Referral'
        ];
        List<Lead> otherLeads = [
            SELECT Id, LQW_Question_List__c FROM Lead WHERE LeadSource = 'Other'
        ];

        System.assertEquals(50, webLeads.size(), 'Should have 50 Web leads');
        System.assertEquals(50, partnerLeads.size(), 'Should have 50 Partner leads');
        System.assertEquals(50, otherLeads.size(), 'Should have 50 Other leads');

        // Verify all Web leads got Enterprise list
        for (Lead lead : webLeads) {
            System.assertEquals(enterpriseList.Id, lead.LQW_Question_List__c,
                'Web leads should get Enterprise list');
        }

        // Verify all Partner leads got Partner list
        for (Lead lead : partnerLeads) {
            System.assertEquals(partnerList.Id, lead.LQW_Question_List__c,
                'Partner leads should get Partner list');
        }

        // Verify all Other leads got default list
        for (Lead lead : otherLeads) {
            System.assertEquals(defaultList.Id, lead.LQW_Question_List__c,
                'Other leads should get default list');
        }
    }

    /**
     * @description Test assignment criteria JSON sync
     */
    @isTest
    static void testAssignmentCriteriaJSON_IsSynced() {
        Test.startTest();

        // Create lead to trigger sync
        Lead testLead = new Lead();
        testLead.FirstName = 'Test';
        testLead.LastName = 'JSON Sync';
        testLead.Company = 'JSON Company';
        testLead.LeadSource = 'Web';
        testLead.Status = 'Open - Not Contacted';
        insert testLead;

        Test.stopTest();

        // Verify Assignment_Criteria__c is populated
        LQW_Question_List__c enterpriseList = [
            SELECT Id, LQW_List_Name__c, LQW_Assignment_Criteria__c
            FROM LQW_Question_List__c
            WHERE LQW_List_Name__c = 'Enterprise Leads'
            LIMIT 1
        ];

        System.assertNotEquals(null, enterpriseList.LQW_Assignment_Criteria__c,
            'Assignment criteria JSON should be populated');
        System.assert(enterpriseList.LQW_Assignment_Criteria__c.contains('LeadSource'),
            'Assignment criteria should contain LeadSource field');
        System.assert(enterpriseList.LQW_Assignment_Criteria__c.contains('Web'),
            'Assignment criteria should contain Web value');
    }

    /**
     * @description Test inactive list is not assigned
     */
    @isTest
    static void testInactiveList_NotAssigned() {
        // Get the default list
        LQW_Question_List__c defaultList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_Is_Default__c = true LIMIT 1
        ];

        // Deactivate Enterprise list
        LQW_Question_List__c enterpriseList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Enterprise Leads' LIMIT 1
        ];
        enterpriseList.LQW_Is_Active__c = false;
        update enterpriseList;

        Test.startTest();

        // Create Web lead (normally would get Enterprise list)
        Lead testLead = new Lead();
        testLead.FirstName = 'Test';
        testLead.LastName = 'Inactive Test';
        testLead.Company = 'Test Company';
        testLead.LeadSource = 'Web';
        testLead.Status = 'Open - Not Contacted';
        insert testLead;

        Test.stopTest();

        // Verify default list was assigned instead
        Lead updatedLead = [SELECT Id, LQW_Question_List__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(defaultList.Id, updatedLead.LQW_Question_List__c,
            'Default list should be assigned when matching list is inactive');
    }

    /**
     * @description Test auto-create example list when no lists exist
     */
    @isTest
    static void testAutoCreateExampleList() {
        // Delete all question lists and questions first
        delete [SELECT Id FROM LQW_Qualification_Question__c];
        delete [SELECT Id FROM LQW_Question_List__c];

        // Verify no lists exist
        Integer listCount = [SELECT COUNT() FROM LQW_Question_List__c];
        System.assertEquals(0, listCount, 'Should start with no lists');

        // Enable starter-list seeding for this test (it's off by default)
        LQW_Settings__c seedOn = new LQW_Settings__c();
        seedOn.LQW_Auto_Seed_Starter_List__c = true;
        insert seedOn;

        Test.startTest();

        // Create a lead - this should trigger auto-create
        Lead testLead = new Lead();
        testLead.FirstName = 'Auto';
        testLead.LastName = 'Create Test';
        testLead.Company = 'Auto Company';
        testLead.LeadSource = 'Web';
        testLead.Status = 'Open - Not Contacted';
        insert testLead;

        Test.stopTest();

        // Verify example list was created
        List<LQW_Question_List__c> createdLists = [
            SELECT Id, LQW_List_Name__c, LQW_Is_Default__c
            FROM LQW_Question_List__c
        ];
        System.assertEquals(1, createdLists.size(), 'One list should be auto-created');
        System.assertEquals('General Qualification', createdLists[0].LQW_List_Name__c,
            'List should be named General Qualification');
        System.assertEquals(true, createdLists[0].LQW_Is_Default__c,
            'Auto-created list should be default');

        // Verify questions were created
        List<LQW_Qualification_Question__c> createdQuestions = [
            SELECT Id FROM LQW_Qualification_Question__c
            WHERE LQW_Question_List__c = :createdLists[0].Id
        ];
        System.assertEquals(9, createdQuestions.size(),
            '9 example questions should be created');

        // Verify lead was assigned the auto-created list
        Lead updatedLead = [SELECT Id, LQW_Question_List__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(createdLists[0].Id, updatedLead.LQW_Question_List__c,
            'Lead should be assigned auto-created list');
    }

    /**
     * @description Test lead with no relevant field changes doesn't trigger reassignment
     */
    @isTest
    static void testLeadUpdate_NoRelevantChanges_NoReassignment() {
        // Get the Enterprise list
        LQW_Question_List__c enterpriseList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Enterprise Leads' LIMIT 1
        ];

        // Create lead with Web source
        Lead testLead = new Lead();
        testLead.FirstName = 'Test';
        testLead.LastName = 'Update Test';
        testLead.Company = 'Update Company';
        testLead.LeadSource = 'Web';
        testLead.Status = 'Open - Not Contacted';
        insert testLead;

        // Verify initial assignment
        Lead leadAfterInsert = [SELECT Id, LQW_Question_List__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(enterpriseList.Id, leadAfterInsert.LQW_Question_List__c);

        Test.startTest();

        // Update non-relevant field
        testLead.FirstName = 'Updated First Name';
        testLead.Email = 'updated@test.com';
        update testLead;

        Test.stopTest();

        // Verify list assignment didn't change
        Lead leadAfterUpdate = [SELECT Id, LQW_Question_List__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(enterpriseList.Id, leadAfterUpdate.LQW_Question_List__c,
            'List assignment should not change when non-relevant fields are updated');
    }

    // ────────────────────────────────────────────────────────────────────
    // Declarative RULES table — operator coverage
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description A rule using `contains` matches leads whose Company name
     * contains the configured substring (case-insensitive).
     */
    @isTest
    static void testRule_ContainsOperator_MatchesSubstring() {
        LQW_Question_List__c enterpriseList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Enterprise Leads' LIMIT 1
        ];
        LQW_LeadAssignmentTriggerHandler.RULES = new List<LQW_LeadAssignmentTriggerHandler.AssignmentRule>{
            new LQW_LeadAssignmentTriggerHandler.AssignmentRule('Enterprise Leads',
                new List<LQW_LeadAssignmentTriggerHandler.Condition>{
                    new LQW_LeadAssignmentTriggerHandler.Condition('Company', 'contains', 'Acme')
                })
        };

        Test.startTest();
        Lead l = new Lead(LastName = 'Contains', Company = 'ACME Industries', Status = 'Open - Not Contacted');
        insert l;
        Test.stopTest();

        Lead result = [SELECT LQW_Question_List__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(enterpriseList.Id, result.LQW_Question_List__c,
            'Contains operator should match case-insensitively');
    }

    /**
     * @description A rule using `gt` matches leads with a numeric field
     * strictly greater than the configured threshold.
     */
    @isTest
    static void testRule_GreaterThanOperator_MatchesRevenue() {
        LQW_Question_List__c enterpriseList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Enterprise Leads' LIMIT 1
        ];
        LQW_LeadAssignmentTriggerHandler.RULES = new List<LQW_LeadAssignmentTriggerHandler.AssignmentRule>{
            new LQW_LeadAssignmentTriggerHandler.AssignmentRule('Enterprise Leads',
                new List<LQW_LeadAssignmentTriggerHandler.Condition>{
                    new LQW_LeadAssignmentTriggerHandler.Condition('AnnualRevenue', 'gt', 1000000)
                })
        };

        Test.startTest();
        Lead rich = new Lead(LastName = 'Rich', Company = 'RichCo', AnnualRevenue = 2500000, Status = 'Open - Not Contacted');
        Lead poor = new Lead(LastName = 'Poor', Company = 'PoorCo', AnnualRevenue = 500000, Status = 'Open - Not Contacted');
        insert new List<Lead>{ rich, poor };
        Test.stopTest();

        Map<Id, Lead> byId = new Map<Id, Lead>([
            SELECT Id, LQW_Question_List__c FROM Lead WHERE Id IN (:rich.Id, :poor.Id)
        ]);
        System.assertEquals(enterpriseList.Id, byId.get(rich.Id).LQW_Question_List__c,
            'Lead above threshold should be assigned');
        System.assertNotEquals(enterpriseList.Id, byId.get(poor.Id).LQW_Question_List__c,
            'Lead below threshold should NOT be assigned by this rule (falls to default)');
    }

    /**
     * @description A rule using `in` matches leads whose field equals any of
     * a comma-separated list of values.
     */
    @isTest
    static void testRule_InOperator_MatchesAnyOfList() {
        LQW_Question_List__c partnerList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Partner Leads' LIMIT 1
        ];
        LQW_LeadAssignmentTriggerHandler.RULES = new List<LQW_LeadAssignmentTriggerHandler.AssignmentRule>{
            new LQW_LeadAssignmentTriggerHandler.AssignmentRule('Partner Leads',
                new List<LQW_LeadAssignmentTriggerHandler.Condition>{
                    new LQW_LeadAssignmentTriggerHandler.Condition('LeadSource', 'in', 'Partner Referral, External Referral, Other')
                })
        };

        Test.startTest();
        Lead l = new Lead(LastName = 'InList', Company = 'InCo', LeadSource = 'External Referral', Status = 'Open - Not Contacted');
        insert l;
        Test.stopTest();

        Lead result = [SELECT LQW_Question_List__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(partnerList.Id, result.LQW_Question_List__c,
            'In operator should match any comma-separated value');
    }

    /**
     * @description A rule using `isBlank` matches leads missing a field.
     */
    @isTest
    static void testRule_IsBlankOperator() {
        LQW_Question_List__c enterpriseList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Enterprise Leads' LIMIT 1
        ];
        LQW_LeadAssignmentTriggerHandler.RULES = new List<LQW_LeadAssignmentTriggerHandler.AssignmentRule>{
            new LQW_LeadAssignmentTriggerHandler.AssignmentRule('Enterprise Leads',
                new List<LQW_LeadAssignmentTriggerHandler.Condition>{
                    new LQW_LeadAssignmentTriggerHandler.Condition('Industry', 'isBlank', null)
                })
        };

        Test.startTest();
        Lead blank = new Lead(LastName = 'Blank', Company = 'BlankCo', Status = 'Open - Not Contacted');
        Lead filled = new Lead(LastName = 'Filled', Company = 'FilledCo', Industry = 'Technology', Status = 'Open - Not Contacted');
        insert new List<Lead>{ blank, filled };
        Test.stopTest();

        Map<Id, Lead> byId = new Map<Id, Lead>([
            SELECT Id, LQW_Question_List__c FROM Lead WHERE Id IN (:blank.Id, :filled.Id)
        ]);
        System.assertEquals(enterpriseList.Id, byId.get(blank.Id).LQW_Question_List__c,
            'isBlank should match the blank-industry lead');
        System.assertNotEquals(enterpriseList.Id, byId.get(filled.Id).LQW_Question_List__c,
            'isBlank should NOT match the lead with an industry');
    }

    /**
     * @description A multi-condition rule only matches when ALL conditions match.
     */
    @isTest
    static void testRule_MultiCondition_AllMustMatch() {
        LQW_Question_List__c enterpriseList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Enterprise Leads' LIMIT 1
        ];
        LQW_LeadAssignmentTriggerHandler.RULES = new List<LQW_LeadAssignmentTriggerHandler.AssignmentRule>{
            new LQW_LeadAssignmentTriggerHandler.AssignmentRule('Enterprise Leads',
                new List<LQW_LeadAssignmentTriggerHandler.Condition>{
                    new LQW_LeadAssignmentTriggerHandler.Condition('Industry', 'equals', 'Technology'),
                    new LQW_LeadAssignmentTriggerHandler.Condition('AnnualRevenue', 'gte', 1000000)
                })
        };

        Test.startTest();
        Lead both     = new Lead(LastName = 'Both',    Company = 'BothCo',    Industry = 'Technology', AnnualRevenue = 1500000, Status = 'Open - Not Contacted');
        Lead wrongInd = new Lead(LastName = 'WrongInd',Company = 'WrongCo',   Industry = 'Retail',     AnnualRevenue = 1500000, Status = 'Open - Not Contacted');
        Lead lowRev   = new Lead(LastName = 'LowRev',  Company = 'LowCo',     Industry = 'Technology', AnnualRevenue = 500000,  Status = 'Open - Not Contacted');
        insert new List<Lead>{ both, wrongInd, lowRev };
        Test.stopTest();

        Map<Id, Lead> byId = new Map<Id, Lead>([
            SELECT Id, LQW_Question_List__c FROM Lead WHERE Id IN (:both.Id, :wrongInd.Id, :lowRev.Id)
        ]);
        System.assertEquals(enterpriseList.Id, byId.get(both.Id).LQW_Question_List__c,
            'Lead satisfying both conditions should match');
        System.assertNotEquals(enterpriseList.Id, byId.get(wrongInd.Id).LQW_Question_List__c,
            'Wrong industry should not match even with high revenue');
        System.assertNotEquals(enterpriseList.Id, byId.get(lowRev.Id).LQW_Question_List__c,
            'Low revenue should not match even with correct industry');
    }

    /**
     * @description A rule that targets a list name that does not exist in the
     * org must be silently skipped — not crash the trigger.
     */
    @isTest
    static void testRule_MissingListName_SilentlySkipped() {
        LQW_LeadAssignmentTriggerHandler.RULES = new List<LQW_LeadAssignmentTriggerHandler.AssignmentRule>{
            new LQW_LeadAssignmentTriggerHandler.AssignmentRule('Nonexistent List',
                new List<LQW_LeadAssignmentTriggerHandler.Condition>{
                    new LQW_LeadAssignmentTriggerHandler.Condition('LeadSource', 'equals', 'Web')
                })
        };
        LQW_Question_List__c defaultList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_Is_Default__c = true LIMIT 1
        ];

        Test.startTest();
        Lead l = new Lead(LastName = 'Orphan', Company = 'OrphanCo', LeadSource = 'Web', Status = 'Open - Not Contacted');
        insert l;
        Test.stopTest();

        Lead result = [SELECT LQW_Question_List__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(defaultList.Id, result.LQW_Question_List__c,
            'Lead should fall through to the default list when rule targets missing list');
    }

    /**
     * @description Starter-list seeding is OFF by default. An empty org that
     * receives a Lead must not auto-create any Question Lists unless the
     * LQW_Settings__c toggle is explicitly enabled.
     */
    @isTest
    static void testStarterSeed_DisabledByDefault_DoesNotSeed() {
        delete [SELECT Id FROM LQW_Qualification_Question__c];
        delete [SELECT Id FROM LQW_Question_List__c];
        System.assertEquals(0, [SELECT COUNT() FROM LQW_Question_List__c],
            'Test setup should leave zero lists');

        Test.startTest();

        Lead l = new Lead(LastName = 'NoSeed', Company = 'NoSeedCo', LeadSource = 'Web', Status = 'Open - Not Contacted');
        insert l;

        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM LQW_Question_List__c],
            'Starter list should NOT be created when LQW_Settings__c toggle is off');

        Lead after = [SELECT LQW_Question_List__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(null, after.LQW_Question_List__c,
            'Lead has no list to assign when seeding is off and no lists exist');
    }

    /**
     * @description 200-Lead bulk insert stays well inside SOQL/DML governor
     * limits. The handler is expected to issue a small, constant number of
     * queries and DMLs regardless of how many Leads are in the trigger batch.
     */
    @isTest
    static void testBulkInsert_200Leads_StaysWithinGovernorLimits() {
        LQW_Question_List__c enterpriseList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Enterprise Leads' LIMIT 1
        ];
        LQW_Question_List__c partnerList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Partner Leads' LIMIT 1
        ];
        LQW_Question_List__c defaultList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_Is_Default__c = true LIMIT 1
        ];

        // Build 200 leads: split roughly into three buckets so every branch
        // of evaluateLeadCriteria is exercised in a single DML call.
        List<Lead> bulkLeads = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            Lead l = new Lead();
            l.LastName = 'Bulk ' + i;
            l.Company = 'Bulk Co ' + i;
            l.Status = 'Open - Not Contacted';
            if (Math.mod(i, 3) == 0) {
                l.LeadSource = 'Web';             // -> Enterprise Leads
            } else if (Math.mod(i, 3) == 1) {
                l.LeadSource = 'Partner Referral'; // -> Partner Leads
            } else {
                l.LeadSource = 'Other';           // -> default fallback
            }
            bulkLeads.add(l);
        }

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer dmlBefore  = Limits.getDmlStatements();

        insert bulkLeads;

        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Integer dmlUsed  = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        // Handler should issue a small, constant number of queries/DMLs,
        // independent of the batch size. Assertions are loose on purpose —
        // a regression to per-lead SOQL would blow past these by orders of
        // magnitude.
        System.assert(soqlUsed < 20,
            'Bulk insert of 200 leads should not issue more than ~20 SOQL; used ' + soqlUsed);
        System.assert(dmlUsed < 20,
            'Bulk insert of 200 leads should not issue more than ~20 DML; used ' + dmlUsed);

        // Verify the assignment mix is correct end-to-end.
        List<Lead> results = [
            SELECT Id, LeadSource, LQW_Question_List__c FROM Lead WHERE Id IN :bulkLeads
        ];
        Integer enterpriseCount = 0;
        Integer partnerCount    = 0;
        Integer defaultCount    = 0;
        for (Lead l : results) {
            if (l.LQW_Question_List__c == enterpriseList.Id) enterpriseCount++;
            else if (l.LQW_Question_List__c == partnerList.Id) partnerCount++;
            else if (l.LQW_Question_List__c == defaultList.Id) defaultCount++;
        }
        // 200 / 3 = 67, 67, 66 — assert each bucket was assigned.
        System.assert(enterpriseCount >= 66 && enterpriseCount <= 68,
            'Expected ~67 Web leads on Enterprise list; got ' + enterpriseCount);
        System.assert(partnerCount >= 66 && partnerCount <= 68,
            'Expected ~67 Partner Referral leads on Partner list; got ' + partnerCount);
        System.assert(defaultCount >= 65 && defaultCount <= 67,
            'Expected ~66 Other leads on default list; got ' + defaultCount);
    }

    /**
     * @description generateCriteriaJSON emits the JSON shape expected by the
     * admin UI and the conflict-detection logic — keys field, label, operator, value.
     */
    @isTest
    static void testGenerateCriteriaJSON_ShapeMatchesContract() {
        LQW_LeadAssignmentTriggerHandler.RULES = new List<LQW_LeadAssignmentTriggerHandler.AssignmentRule>{
            new LQW_LeadAssignmentTriggerHandler.AssignmentRule('Enterprise Leads',
                new List<LQW_LeadAssignmentTriggerHandler.Condition>{
                    new LQW_LeadAssignmentTriggerHandler.Condition('AnnualRevenue', 'gt', 1000000)
                })
        };
        LQW_Question_List__c ql = new LQW_Question_List__c(LQW_List_Name__c = 'Enterprise Leads');

        Test.startTest();
        String criteriaStr = LQW_LeadAssignmentTriggerHandler.generateCriteriaJSON(ql);
        Test.stopTest();

        System.assertNotEquals(null, criteriaStr, 'JSON should be emitted for rules targeting this list');
        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(criteriaStr);
        System.assertEquals(1, parsed.size(), 'Exactly one condition expected');
        Map<String, Object> row = (Map<String, Object>) parsed[0];
        System.assertEquals('AnnualRevenue', row.get('field'));
        System.assertEquals('Annual Revenue', row.get('label'));
        System.assertEquals('gt', row.get('operator'));
        System.assertEquals('1000000', row.get('value'));
    }
}
