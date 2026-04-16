/**
 * @description Test class for LQW_LeadQualificationController
 * Provides comprehensive test coverage for all methods including qualification data retrieval,
 * response saving, dealbreaker logic, status management, and error handling scenarios.
 */
@isTest
private class LQW_LeadQualificationControllerTest {

    /**
     * @description Creates test data for qualification questions and lead
     */
    @TestSetup
    static void setupTestData() {
        // Create test question list with threshold configuration
        LQW_Question_List__c questionList = new LQW_Question_List__c(
            LQW_List_Name__c = 'Test Question List',
            LQW_Description__c = 'Test question list for unit tests',
            LQW_Is_Active__c = true,
            LQW_High_Quality_Threshold__c = 5,
            LQW_Medium_Quality_Threshold__c = 3,
            LQW_High_Quality_Label__c = 'High Quality',
            LQW_Medium_Quality_Label__c = 'Medium Quality',
            LQW_Low_Quality_Label__c = 'Low Quality',
            LQW_High_Quality_Recommendation__c = 'Convert to Opportunity',
            LQW_Medium_Quality_Recommendation__c = 'Convert to Opportunity with Manager Review',
            LQW_Low_Quality_Recommendation__c = 'Nurture Lead (Do Not Convert)'
        );
        insert questionList;

        // Create test questions
        List<LQW_Qualification_Question__c> questions = new List<LQW_Qualification_Question__c>();

        // Question 1: Regular question (both answers earn points)
        questions.add(new LQW_Qualification_Question__c(
            LQW_Question_Text__c = 'Does the customer have budget?',
            LQW_Is_Active__c = true,
            LQW_Question_Order__c = 1,
            LQW_Is_Dealbreaker__c = false,
            LQW_Score_Value__c = 1,
            LQW_Point_Earning_Answer__c = 'Both',
            LQW_Question_List__c = questionList.Id
        ));

        // Question 2: Dealbreaker question (Yes = disqualify)
        questions.add(new LQW_Qualification_Question__c(
            LQW_Question_Text__c = 'Is the purchasing volume lower than $25K annually?',
            LQW_Is_Active__c = true,
            LQW_Question_Order__c = 2,
            LQW_Is_Dealbreaker__c = true,
            LQW_Dealbreaker_Value__c = 'Yes',
            LQW_Score_Value__c = 1,
            LQW_Point_Earning_Answer__c = 'Both',
            LQW_Question_List__c = questionList.Id
        ));

        // Question 3: Another regular question (both answers earn points)
        questions.add(new LQW_Qualification_Question__c(
            LQW_Question_Text__c = 'Can we deliver within their timeframe?',
            LQW_Is_Active__c = true,
            LQW_Question_Order__c = 3,
            LQW_Is_Dealbreaker__c = false,
            LQW_Score_Value__c = 2,
            LQW_Point_Earning_Answer__c = 'Both',
            LQW_Question_List__c = questionList.Id
        ));

        // Question 4: Inactive question (should not be returned)
        questions.add(new LQW_Qualification_Question__c(
            LQW_Question_Text__c = 'Inactive question?',
            LQW_Is_Active__c = false,
            LQW_Question_Order__c = 4,
            LQW_Is_Dealbreaker__c = false,
            LQW_Score_Value__c = 1,
            LQW_Point_Earning_Answer__c = 'Both',
            LQW_Question_List__c = questionList.Id
        ));

        // Question 5: Second dealbreaker (No = disqualify)
        questions.add(new LQW_Qualification_Question__c(
            LQW_Question_Text__c = 'Are they using a competitive product?',
            LQW_Is_Active__c = true,
            LQW_Question_Order__c = 5,
            LQW_Is_Dealbreaker__c = true,
            LQW_Dealbreaker_Value__c = 'No',
            LQW_Score_Value__c = 1,
            LQW_Point_Earning_Answer__c = 'Both',
            LQW_Question_List__c = questionList.Id
        ));

        insert questions;

        // Create test lead with question list assignment
        Lead testLead = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            Email = 'john.doe@testcompany.com',
            LQW_Question_List__c = questionList.Id
        );
        insert testLead;
    }

    /**
     * @description Test getLeadQualificationData with no responses
     */
    @isTest
    static void testGetQualificationData_NoResponses() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();
        LQW_LeadQualificationController.QualificationSummary result =
            LQW_LeadQualificationController.getLeadQualificationData(testLead.Id);
        Test.stopTest();

        // Should return 4 active questions (excluding inactive one)
        System.assertEquals(4, result.totalQuestions, 'Should return 4 active questions');
        System.assertEquals(4, result.questions.size(), 'Questions list should have 4 items');
        System.assertEquals(0, result.answeredCount, 'No questions should be answered');
        System.assertEquals(0, result.totalScore, 'Total score should be 0');
        System.assertEquals('Low Quality', result.leadRank, 'Rank should be Low Quality');
        System.assertEquals(false, result.isDisqualified, 'Lead should not be disqualified');
        System.assertEquals('Open - Not Contacted', result.leadStatus, 'Lead status should be Open - Not Contacted');
    }

    /**
     * @description Test getLeadQualificationData with some responses
     */
    @isTest
    static void testGetQualificationData_WithResponses() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        // Use two non-dealbreaker questions so both "Yes" answers earn points (order 2 is a dealbreaker in setup)
        List<LQW_Qualification_Question__c> questions = [
            SELECT Id FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            AND LQW_Is_Dealbreaker__c = false
            ORDER BY LQW_Question_Order__c
        ];

        // Create responses for two scoring questions (both Yes): score values 1 + 2 from setup
        List<LQW_Lead_Question_Response__c> responses = new List<LQW_Lead_Question_Response__c>();
        responses.add(new LQW_Lead_Question_Response__c(
            LQW_Lead__c = testLead.Id,
            LQW_Question__c = questions[0].Id,
            LQW_Response__c = 'Yes',
            LQW_Response_Date__c = System.now(),
            LQW_Last_Modified_Date__c = System.now()
        ));
        responses.add(new LQW_Lead_Question_Response__c(
            LQW_Lead__c = testLead.Id,
            LQW_Question__c = questions[1].Id,
            LQW_Response__c = 'Yes',
            LQW_Response_Date__c = System.now(),
            LQW_Last_Modified_Date__c = System.now()
        ));
        insert responses;

        Test.startTest();
        LQW_LeadQualificationController.QualificationSummary result =
            LQW_LeadQualificationController.getLeadQualificationData(testLead.Id);
        Test.stopTest();

        System.assertEquals(4, result.totalQuestions, 'Should return 4 active questions');
        System.assertEquals(2, result.answeredCount, 'Two questions should be answered');
        System.assertEquals(3, result.totalScore, 'Total score should be 3 (1+2)');
        System.assertEquals('Medium Quality', result.leadRank, 'Rank should be Medium Quality');
    }

    /**
     * @description Test saveQuestionResponse for new response
     */
    @isTest
    static void testSaveQuestionResponse_NewResponse() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        LQW_Qualification_Question__c question = [
            SELECT Id FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            ORDER BY LQW_Question_Order__c
            LIMIT 1
        ];

        Test.startTest();
        LQW_LeadQualificationController.ResponseSaveResult result =
            LQW_LeadQualificationController.saveQuestionResponse(testLead.Id, question.Id, 'Yes');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Save should be successful');
        System.assertEquals(false, result.wasDisqualified, 'Should not trigger disqualification');
        System.assertEquals(false, result.wasRestored, 'Should not trigger restoration');

        // Verify response was created
        List<LQW_Lead_Question_Response__c> responses = [
            SELECT Id, LQW_Response__c
            FROM LQW_Lead_Question_Response__c
            WHERE LQW_Lead__c = :testLead.Id
        ];
        System.assertEquals(1, responses.size(), 'One response should be created');
        System.assertEquals('Yes', responses[0].LQW_Response__c, 'Response should be Yes');

        // Check updated summary
        System.assertNotEquals(null, result.updatedSummary, 'Updated summary should be returned');
        System.assertEquals(1, result.updatedSummary.answeredCount, 'One question should be answered');
        System.assertEquals(1, result.updatedSummary.totalScore, 'Score should be 1');
    }

    /**
     * @description Test saveQuestionResponse for updating existing response
     */
    @isTest
    static void testSaveQuestionResponse_UpdateResponse() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        LQW_Qualification_Question__c question = [
            SELECT Id FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            ORDER BY LQW_Question_Order__c
            LIMIT 1
        ];

        // Create initial response
        LQW_Lead_Question_Response__c response = new LQW_Lead_Question_Response__c(
            LQW_Lead__c = testLead.Id,
            LQW_Question__c = question.Id,
            LQW_Response__c = 'Yes',
            LQW_Response_Date__c = System.now(),
            LQW_Last_Modified_Date__c = System.now()
        );
        insert response;

        Test.startTest();
        // Update response to No
        LQW_LeadQualificationController.ResponseSaveResult result =
            LQW_LeadQualificationController.saveQuestionResponse(testLead.Id, question.Id, 'No');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Update should be successful');

        // Verify response was updated
        LQW_Lead_Question_Response__c updatedResponse = [
            SELECT Id, LQW_Response__c
            FROM LQW_Lead_Question_Response__c
            WHERE Id = :response.Id
        ];
        System.assertEquals('No', updatedResponse.LQW_Response__c, 'Response should be updated to No');
    }

    /**
     * @description Test saveQuestionResponse for deleting response (toggle off)
     */
    @isTest
    static void testSaveQuestionResponse_DeleteResponse() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        LQW_Qualification_Question__c question = [
            SELECT Id FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            ORDER BY LQW_Question_Order__c
            LIMIT 1
        ];

        // Create initial response
        LQW_Lead_Question_Response__c response = new LQW_Lead_Question_Response__c(
            LQW_Lead__c = testLead.Id,
            LQW_Question__c = question.Id,
            LQW_Response__c = 'Yes',
            LQW_Response_Date__c = System.now(),
            LQW_Last_Modified_Date__c = System.now()
        );
        insert response;

        Test.startTest();
        // Delete response by passing null
        LQW_LeadQualificationController.ResponseSaveResult result =
            LQW_LeadQualificationController.saveQuestionResponse(testLead.Id, question.Id, null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Delete should be successful');

        // Verify response was deleted
        List<LQW_Lead_Question_Response__c> responses = [
            SELECT Id
            FROM LQW_Lead_Question_Response__c
            WHERE LQW_Lead__c = :testLead.Id
        ];
        System.assertEquals(0, responses.size(), 'Response should be deleted');
    }

    /**
     * @description Test dealbreaker response triggers disqualification
     */
    @isTest
    static void testSaveQuestionResponse_DealbreakerTriggers() {
        Lead testLead = [SELECT Id, Status FROM Lead LIMIT 1];
        LQW_Qualification_Question__c dealbreakerQuestion = [
            SELECT Id
            FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            AND LQW_Is_Dealbreaker__c = true
            AND LQW_Dealbreaker_Value__c = 'Yes'
            LIMIT 1
        ];

        Test.startTest();
        // Answer Yes to dealbreaker question (should disqualify)
        LQW_LeadQualificationController.ResponseSaveResult result =
            LQW_LeadQualificationController.saveQuestionResponse(testLead.Id, dealbreakerQuestion.Id, 'Yes');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Save should be successful');
        System.assertEquals(true, result.wasDisqualified, 'Should trigger disqualification');
        System.assertEquals('Disqualified', result.newLeadStatus, 'Lead status should be Disqualified');

        // Verify lead status was updated
        Lead updatedLead = [SELECT Id, Status, Description FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals('Disqualified', updatedLead.Status, 'Lead should be disqualified');
        System.assert(updatedLead.Description.contains('[PREV_STATUS:'), 'Description should contain status marker');

        // Check updated summary
        System.assertEquals(true, result.updatedSummary.isDisqualified, 'Summary should show disqualified');
        System.assertEquals('Disqualified', result.updatedSummary.leadRank, 'Rank should be Disqualified');
    }

    /**
     * @description Test dealbreaker removal restores previous status
     */
    @isTest
    static void testSaveQuestionResponse_DealbreakerRestores() {
        Lead testLead = [SELECT Id, Status FROM Lead LIMIT 1];
        LQW_Qualification_Question__c dealbreakerQuestion = [
            SELECT Id
            FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            AND LQW_Is_Dealbreaker__c = true
            AND LQW_Dealbreaker_Value__c = 'Yes'
            LIMIT 1
        ];

        // First, trigger disqualification
        LQW_Lead_Question_Response__c response = new LQW_Lead_Question_Response__c(
            LQW_Lead__c = testLead.Id,
            LQW_Question__c = dealbreakerQuestion.Id,
            LQW_Response__c = 'Yes',
            LQW_Response_Date__c = System.now(),
            LQW_Last_Modified_Date__c = System.now()
        );
        insert response;

        // Update lead to disqualified with marker
        testLead = [SELECT Id, Status, Description FROM Lead WHERE Id = :testLead.Id];
        testLead.Status = 'Disqualified';
        testLead.Description = '[PREV_STATUS:Open - Not Contacted] Test description';
        update testLead;

        Test.startTest();
        // Change response to No (should restore status)
        LQW_LeadQualificationController.ResponseSaveResult result =
            LQW_LeadQualificationController.saveQuestionResponse(testLead.Id, dealbreakerQuestion.Id, 'No');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Save should be successful');
        System.assertEquals(true, result.wasRestored, 'Should trigger restoration');
        System.assertEquals('Open - Not Contacted', result.newLeadStatus, 'Status should be restored');

        // Verify lead status was restored
        Lead restoredLead = [SELECT Id, Status, Description FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals('Open - Not Contacted', restoredLead.Status, 'Status should be restored');
        System.assertEquals(false, restoredLead.Description.contains('[PREV_STATUS:'), 'Marker should be removed');
    }

    /**
     * @description Test toggling off dealbreaker response restores status
     */
    @isTest
    static void testSaveQuestionResponse_DealbreakerToggleOff() {
        Lead testLead = [SELECT Id, Status FROM Lead LIMIT 1];
        LQW_Qualification_Question__c dealbreakerQuestion = [
            SELECT Id
            FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            AND LQW_Is_Dealbreaker__c = true
            AND LQW_Dealbreaker_Value__c = 'Yes'
            LIMIT 1
        ];

        // First, trigger disqualification
        LQW_Lead_Question_Response__c response = new LQW_Lead_Question_Response__c(
            LQW_Lead__c = testLead.Id,
            LQW_Question__c = dealbreakerQuestion.Id,
            LQW_Response__c = 'Yes',
            LQW_Response_Date__c = System.now(),
            LQW_Last_Modified_Date__c = System.now()
        );
        insert response;

        // Update lead to disqualified
        testLead = [SELECT Id FROM Lead WHERE Id = :testLead.Id];
        testLead.Status = 'Disqualified';
        testLead.Description = '[PREV_STATUS:Open - Not Contacted]';
        update testLead;

        Test.startTest();
        // Toggle off response (pass null)
        LQW_LeadQualificationController.ResponseSaveResult result =
            LQW_LeadQualificationController.saveQuestionResponse(testLead.Id, dealbreakerQuestion.Id, null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Save should be successful');
        System.assertEquals(true, result.wasRestored, 'Should trigger restoration');

        // Verify response was deleted
        List<LQW_Lead_Question_Response__c> responses = [
            SELECT Id FROM LQW_Lead_Question_Response__c WHERE Id = :response.Id
        ];
        System.assertEquals(0, responses.size(), 'Response should be deleted');
    }

    /**
     * @description Test multiple dealbreakers - removal of one should not restore if another exists
     */
    @isTest
    static void testSaveQuestionResponse_MultipleDealbreakersPreventsRestore() {
        Lead testLead = [SELECT Id, Status FROM Lead LIMIT 1];
        List<LQW_Qualification_Question__c> dealbreakerQuestions = [
            SELECT Id, LQW_Dealbreaker_Value__c
            FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            AND LQW_Is_Dealbreaker__c = true
            ORDER BY LQW_Question_Order__c
        ];

        System.assert(dealbreakerQuestions.size() >= 2, 'Need at least 2 dealbreaker questions');

        // Create dealbreaker responses for both questions
        List<LQW_Lead_Question_Response__c> responses = new List<LQW_Lead_Question_Response__c>();
        responses.add(new LQW_Lead_Question_Response__c(
            LQW_Lead__c = testLead.Id,
            LQW_Question__c = dealbreakerQuestions[0].Id,
            LQW_Response__c = dealbreakerQuestions[0].LQW_Dealbreaker_Value__c,
            LQW_Response_Date__c = System.now(),
            LQW_Last_Modified_Date__c = System.now()
        ));
        responses.add(new LQW_Lead_Question_Response__c(
            LQW_Lead__c = testLead.Id,
            LQW_Question__c = dealbreakerQuestions[1].Id,
            LQW_Response__c = dealbreakerQuestions[1].LQW_Dealbreaker_Value__c,
            LQW_Response_Date__c = System.now(),
            LQW_Last_Modified_Date__c = System.now()
        ));
        insert responses;

        // Disqualify lead
        testLead.Status = 'Disqualified';
        testLead.Description = '[PREV_STATUS:Open - Not Contacted]';
        update testLead;

        Test.startTest();
        // Remove first dealbreaker response
        String nonDealbreakerValue = (dealbreakerQuestions[0].LQW_Dealbreaker_Value__c == 'Yes') ? 'No' : 'Yes';
        LQW_LeadQualificationController.ResponseSaveResult result =
            LQW_LeadQualificationController.saveQuestionResponse(
                testLead.Id,
                dealbreakerQuestions[0].Id,
                nonDealbreakerValue
            );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Save should be successful');
        System.assertEquals(false, result.wasRestored, 'Should NOT restore (other dealbreaker exists)');

        // Verify lead is still disqualified
        Lead verifyLead = [SELECT Id, Status FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals('Disqualified', verifyLead.Status, 'Lead should remain disqualified');
    }

    /**
     * @description Test lead rank calculations
     */
    @isTest
    static void testLeadRankCalculations() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        List<LQW_Qualification_Question__c> questions = [
            SELECT Id, LQW_Score_Value__c
            FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            AND LQW_Is_Dealbreaker__c = false
            ORDER BY LQW_Question_Order__c
        ];

        // Answer enough questions to get 5+ score (High Quality)
        List<LQW_Lead_Question_Response__c> responses = new List<LQW_Lead_Question_Response__c>();
        for (LQW_Qualification_Question__c question : questions) {
            responses.add(new LQW_Lead_Question_Response__c(
                LQW_Lead__c = testLead.Id,
                LQW_Question__c = question.Id,
                LQW_Response__c = 'Yes',
                LQW_Response_Date__c = System.now(),
                LQW_Last_Modified_Date__c = System.now()
            ));
        }
        insert responses;

        Test.startTest();
        LQW_LeadQualificationController.QualificationSummary result =
            LQW_LeadQualificationController.getLeadQualificationData(testLead.Id);
        Test.stopTest();

        // Total score should be 1 + 2 = 3 (from non-dealbreaker questions)
        System.assertEquals(3, result.totalScore, 'Total score should be 3');
        System.assertEquals('Medium Quality', result.leadRank, 'Rank should be Medium Quality (3-4 points)');
    }

    @isTest
    static void testGetQualificationData_NullLeadId() {
        Test.startTest();
        try {
            LQW_LeadQualificationController.getLeadQualificationData(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (Exception e) {
            System.assertEquals('System.AuraHandledException', e.getTypeName());
        }
        Test.stopTest();
    }

    /**
     * @description Test error handling for invalid lead ID
     */
    @isTest
    static void testGetQualificationData_InvalidLeadId() {
        // Account-shaped Id cannot match a Lead row; avoids collisions with real 00Q Lead Ids in shared dev orgs
        Id fakeLeadId = '001000000000000AAA';

        Test.startTest();
        try {
            LQW_LeadQualificationController.QualificationSummary result =
                LQW_LeadQualificationController.getLeadQualificationData(fakeLeadId);
            System.assert(false, 'Should have thrown an exception');
        } catch (Exception e) {
            System.assertEquals(
                'System.AuraHandledException',
                e.getTypeName(),
                'Expected AuraHandledException; message was: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description Test question ordering
     */
    @isTest
    static void testQuestionOrdering() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();
        LQW_LeadQualificationController.QualificationSummary result =
            LQW_LeadQualificationController.getLeadQualificationData(testLead.Id);
        Test.stopTest();

        // Verify questions are ordered by Question_Order__c
        for (Integer i = 0; i < result.questions.size() - 1; i++) {
            Integer currentOrder = result.questions[i].questionOrder != null ? result.questions[i].questionOrder : 999;
            Integer nextOrder = result.questions[i + 1].questionOrder != null ? result.questions[i + 1].questionOrder : 999;
            System.assert(currentOrder <= nextOrder, 'Questions should be ordered by Question_Order__c');
        }
    }

    /**
     * @description Test disqualification reason extraction
     */
    @isTest
    static void testDisqualificationReasonExtraction() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        LQW_Qualification_Question__c dealbreakerQuestion = [
            SELECT Id, LQW_Question_Text__c
            FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            AND LQW_Is_Dealbreaker__c = true
            AND LQW_Dealbreaker_Value__c = 'Yes'
            LIMIT 1
        ];

        // Create dealbreaker response
        LQW_Lead_Question_Response__c response = new LQW_Lead_Question_Response__c(
            LQW_Lead__c = testLead.Id,
            LQW_Question__c = dealbreakerQuestion.Id,
            LQW_Response__c = 'Yes',
            LQW_Response_Date__c = System.now(),
            LQW_Last_Modified_Date__c = System.now()
        );
        insert response;

        // Update lead status
        testLead = [SELECT Id FROM Lead WHERE Id = :testLead.Id];
        testLead.Status = 'Disqualified';
        update testLead;

        Test.startTest();
        LQW_LeadQualificationController.QualificationSummary result =
            LQW_LeadQualificationController.getLeadQualificationData(testLead.Id);
        Test.stopTest();

        System.assertEquals(true, result.isDisqualified, 'Should be disqualified');
        System.assertNotEquals(null, result.disqualificationReason, 'Should have disqualification reason');
        System.assert(result.disqualificationReason.contains('Dealbreaker'), 'Reason should mention dealbreaker');
        System.assert(result.disqualificationReason.contains(dealbreakerQuestion.LQW_Question_Text__c),
            'Reason should include question text');
    }

    /**
     * @description Test response history retrieval with question list grouping
     */
    @isTest
    static void testGetResponseHistory() {
        Lead testLead = [SELECT Id, LQW_Question_List__c FROM Lead LIMIT 1];
        List<LQW_Qualification_Question__c> questions = [
            SELECT Id FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            ORDER BY LQW_Question_Order__c
            LIMIT 3
        ];

        // Create responses for multiple questions
        List<LQW_Lead_Question_Response__c> responses = new List<LQW_Lead_Question_Response__c>();
        for (Integer i = 0; i < questions.size(); i++) {
            responses.add(new LQW_Lead_Question_Response__c(
                LQW_Lead__c = testLead.Id,
                LQW_Question__c = questions[i].Id,
                LQW_Response__c = (i == 0 ? 'Yes' : 'No'),
                LQW_Response_Date__c = System.now().addDays(-i),
                LQW_Last_Modified_Date__c = System.now().addDays(-i),
                LQW_Question_List__c = testLead.LQW_Question_List__c
            ));
        }
        insert responses;

        Test.startTest();
        List<LQW_LeadQualificationController.ResponseHistoryGroup> history =
            LQW_LeadQualificationController.getResponseHistory(testLead.Id);
        Test.stopTest();

        System.assertNotEquals(null, history, 'History should not be null');
        System.assertEquals(1, history.size(), 'Should have one question list group');
        System.assertEquals(3, history[0].responses.size(), 'Should have three responses in the group');
        System.assertNotEquals(null, history[0].questionListName, 'Question list name should be set');
        System.assertNotEquals(null, history[0].earliestDate, 'Earliest date should be set');
        System.assertNotEquals(null, history[0].latestDate, 'Latest date should be set');
    }

    /**
     * @description Test question list filtering in getLeadQualificationData
     */
    @isTest
    static void testQuestionListFiltering() {
        Lead testLead = [SELECT Id, LQW_Question_List__c FROM Lead LIMIT 1];

        Test.startTest();
        LQW_LeadQualificationController.QualificationSummary result =
            LQW_LeadQualificationController.getLeadQualificationData(testLead.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.questionListId, 'Question list ID should be set');
        System.assertNotEquals(null, result.questionListName, 'Question list name should be set');
        System.assertEquals(4, result.totalQuestions, 'Should return 4 active questions from the assigned list');
    }

    /**
     * @description Test question list snapshot storage on response save
     */
    @isTest
    static void testQuestionListSnapshot() {
        Lead testLead = [SELECT Id, LQW_Question_List__c FROM Lead LIMIT 1];
        LQW_Qualification_Question__c question = [
            SELECT Id FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            ORDER BY LQW_Question_Order__c
            LIMIT 1
        ];

        Test.startTest();
        LQW_LeadQualificationController.ResponseSaveResult result =
            LQW_LeadQualificationController.saveQuestionResponse(testLead.Id, question.Id, 'Yes');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Save should be successful');

        // Verify question list snapshot was stored
        LQW_Lead_Question_Response__c savedResponse = [
            SELECT Id, LQW_Question_List__c
            FROM LQW_Lead_Question_Response__c
            WHERE LQW_Lead__c = :testLead.Id AND LQW_Question__c = :question.Id
            LIMIT 1
        ];
        System.assertEquals(testLead.LQW_Question_List__c, savedResponse.LQW_Question_List__c,
            'Question list snapshot should match lead\'s current question list');
    }
}
