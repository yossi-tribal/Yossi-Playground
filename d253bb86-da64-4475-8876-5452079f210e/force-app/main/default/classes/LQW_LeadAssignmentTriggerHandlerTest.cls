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

    /**
     * @description When the current user has the bypass custom permission,
     * the trigger must not assign any Question List on insert.
     */
    @isTest
    static void testBypassCustomPermission_SkipsAssignmentOnInsert() {
        LQW_LeadAssignmentTriggerHandler.bypassOverrideForTest = true;

        Test.startTest();

        Lead testLead = new Lead();
        testLead.LastName = 'Bypassed';
        testLead.Company = 'Bypass Co';
        testLead.LeadSource = 'Web';   // Would normally assign Enterprise Leads
        testLead.Status = 'Open - Not Contacted';
        insert testLead;

        Test.stopTest();

        Lead result = [SELECT Id, LQW_Question_List__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(null, result.LQW_Question_List__c,
            'Bypass permission should prevent any Question List from being assigned');
    }

    /**
     * @description When the override is explicitly false (no bypass), the
     * trigger behaves normally. Guards against the override leaking state
     * between tests and documents the default-off branch.
     */
    @isTest
    static void testBypassCustomPermission_WhenDisabled_AssignsAsUsual() {
        LQW_Question_List__c enterpriseList = [
            SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Enterprise Leads' LIMIT 1
        ];
        LQW_LeadAssignmentTriggerHandler.bypassOverrideForTest = false;

        Test.startTest();

        Lead testLead = new Lead();
        testLead.LastName = 'NotBypassed';
        testLead.Company = 'Assigned Co';
        testLead.LeadSource = 'Web';
        testLead.Status = 'Open - Not Contacted';
        insert testLead;

        Test.stopTest();

        Lead result = [SELECT Id, LQW_Question_List__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(enterpriseList.Id, result.LQW_Question_List__c,
            'With override=false, normal assignment must still run');
    }
}
