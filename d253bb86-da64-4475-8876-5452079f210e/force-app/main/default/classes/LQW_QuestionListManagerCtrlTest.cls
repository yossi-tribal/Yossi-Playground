/**
 * @description Test class for LQW_QuestionListManagerCtrl
 * Provides comprehensive test coverage for all CRUD operations, bulk operations,
 * and point system calculations
 */
@isTest
private class LQW_QuestionListManagerCtrlTest {

    @testSetup
    static void setupTestData() {
        // Create test question lists
        List<LQW_Question_List__c> questionLists = new List<LQW_Question_List__c>();

        LQW_Question_List__c list1 = new LQW_Question_List__c();
        list1.LQW_List_Name__c = 'Test List 1';
        list1.LQW_Description__c = 'Description for test list 1';
        list1.LQW_Is_Active__c = true;
        list1.LQW_High_Quality_Threshold__c = 5;
        list1.LQW_Medium_Quality_Threshold__c = 3;
        list1.LQW_High_Quality_Label__c = 'High Quality';
        list1.LQW_Medium_Quality_Label__c = 'Medium Quality';
        list1.LQW_Low_Quality_Label__c = 'Low Quality';
        list1.LQW_High_Quality_Recommendation__c = 'Convert to Opportunity';
        list1.LQW_Medium_Quality_Recommendation__c = 'Convert with Manager Review';
        list1.LQW_Low_Quality_Recommendation__c = 'Nurture Lead';
        questionLists.add(list1);

        LQW_Question_List__c list2 = new LQW_Question_List__c();
        list2.LQW_List_Name__c = 'Test List 2';
        list2.LQW_Description__c = 'Description for test list 2';
        list2.LQW_Is_Active__c = false;
        list2.LQW_High_Quality_Threshold__c = 7;
        list2.LQW_Medium_Quality_Threshold__c = 4;
        questionLists.add(list2);

        insert questionLists;

        // Create test questions for list 1
        List<LQW_Qualification_Question__c> questions = new List<LQW_Qualification_Question__c>();

        LQW_Qualification_Question__c q1 = new LQW_Qualification_Question__c();
        q1.LQW_Question_List__c = list1.Id;
        q1.LQW_Question_Text__c = 'Test Question 1';
        q1.LQW_Question_Order__c = 1;
        q1.LQW_Score_Value__c = 2;
        q1.LQW_Point_Earning_Answer__c = 'Yes';
        q1.LQW_Is_Dealbreaker__c = true;
        q1.LQW_Dealbreaker_Value__c = 'No';
        q1.LQW_Is_Active__c = true;
        questions.add(q1);

        LQW_Qualification_Question__c q2 = new LQW_Qualification_Question__c();
        q2.LQW_Question_List__c = list1.Id;
        q2.LQW_Question_Text__c = 'Test Question 2';
        q2.LQW_Question_Order__c = 2;
        q2.LQW_Score_Value__c = 3;
        q2.LQW_Point_Earning_Answer__c = 'Both';
        q2.LQW_Is_Dealbreaker__c = false;
        q2.LQW_Is_Active__c = true;
        questions.add(q2);

        LQW_Qualification_Question__c q3 = new LQW_Qualification_Question__c();
        q3.LQW_Question_List__c = list1.Id;
        q3.LQW_Question_Text__c = 'Test Question 3';
        q3.LQW_Question_Order__c = 3;
        q3.LQW_Score_Value__c = 1;
        q3.LQW_Point_Earning_Answer__c = 'No';
        q3.LQW_Is_Dealbreaker__c = false;
        q3.LQW_Is_Active__c = false;
        questions.add(q3);

        insert questions;
    }

    @isTest
    static void testGetAllQuestionLists() {
        Test.startTest();
        List<LQW_QuestionListManagerCtrl.QuestionListData> result = LQW_QuestionListManagerCtrl.getAllQuestionLists();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(2, result.size(), 'Should return 2 question lists');

        // Verify first list has questions
        LQW_QuestionListManagerCtrl.QuestionListData list1Data = result[0];
        System.assertEquals('Test List 1', list1Data.listName, 'List name should match');
        System.assertEquals(3, list1Data.totalQuestions, 'Should have 3 total questions');
        System.assertEquals(2, list1Data.activeQuestions, 'Should have 2 active questions');
        System.assertEquals(5, list1Data.totalPossiblePoints, 'Total points should be 5 (2+3)');
        System.assertEquals(1, list1Data.dealbreakerCount, 'Should have 1 dealbreaker');
    }

    @isTest
    static void testGetQuestionList() {
        LQW_Question_List__c questionList = [SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Test List 1' LIMIT 1];

        Test.startTest();
        LQW_QuestionListManagerCtrl.QuestionListData result = LQW_QuestionListManagerCtrl.getQuestionList(questionList.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Test List 1', result.listName, 'List name should match');
        System.assertEquals(3, result.questions.size(), 'Should have 3 questions');
        System.assertEquals(3, result.totalQuestions, 'Total questions should be 3');
        System.assertEquals(2, result.activeQuestions, 'Active questions should be 2');
        System.assertEquals(5, result.totalPossiblePoints, 'Total possible points should be 5');
        System.assertEquals(1, result.dealbreakerCount, 'Dealbreaker count should be 1');
    }

    @isTest
    static void testSaveQuestionList_Create() {
        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.saveQuestionList(
            null,
            'New Test List',
            'New description',
            true,
            7,
            4,
            'Hot Lead',
            'Warm Lead',
            'Cold Lead',
            'Immediate Contact',
            'Schedule Follow-up',
            'Add to Nurture Campaign',
            false
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Save should succeed');
        System.assertNotEquals(null, result.recordId, 'Record ID should be returned');

        LQW_Question_List__c newList = [SELECT LQW_List_Name__c, LQW_Description__c, LQW_Is_Active__c,
                                         LQW_High_Quality_Threshold__c, LQW_Medium_Quality_Threshold__c,
                                         LQW_High_Quality_Label__c
                                         FROM LQW_Question_List__c WHERE Id = :result.recordId];
        System.assertEquals('New Test List', newList.LQW_List_Name__c, 'List name should match');
        System.assertEquals('New description', newList.LQW_Description__c, 'Description should match');
        System.assertEquals(true, newList.LQW_Is_Active__c, 'Should be active');
        System.assertEquals(7, newList.LQW_High_Quality_Threshold__c, 'High threshold should match');
        System.assertEquals(4, newList.LQW_Medium_Quality_Threshold__c, 'Medium threshold should match');
        System.assertEquals('Hot Lead', newList.LQW_High_Quality_Label__c, 'High label should match');
    }

    @isTest
    static void testSaveQuestionList_Update() {
        LQW_Question_List__c questionList = [SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Test List 1' LIMIT 1];

        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.saveQuestionList(
            questionList.Id,
            'Updated List Name',
            'Updated description',
            false,
            8,
            5,
            'Premium',
            'Standard',
            'Basic',
            'VIP Treatment',
            'Standard Process',
            'Basic Support',
            false
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Update should succeed');

        LQW_Question_List__c updatedList = [SELECT LQW_List_Name__c, LQW_Description__c, LQW_Is_Active__c,
                                             LQW_High_Quality_Threshold__c, LQW_Medium_Quality_Label__c
                                             FROM LQW_Question_List__c WHERE Id = :questionList.Id];
        System.assertEquals('Updated List Name', updatedList.LQW_List_Name__c, 'List name should be updated');
        System.assertEquals('Updated description', updatedList.LQW_Description__c, 'Description should be updated');
        System.assertEquals(false, updatedList.LQW_Is_Active__c, 'Should be inactive');
        System.assertEquals(8, updatedList.LQW_High_Quality_Threshold__c, 'Threshold should be updated');
        System.assertEquals('Standard', updatedList.LQW_Medium_Quality_Label__c, 'Label should be updated');
    }

    @isTest
    static void testSaveQuestionList_ValidationError() {
        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.saveQuestionList(
            null,
            '',
            'Description',
            true,
            5,
            3,
            'High Quality',
            'Medium Quality',
            'Low Quality',
            'Convert to Opportunity',
            'Manager Review',
            'Nurture Lead',
            false
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail validation');
        System.assert(result.message.contains('required'), 'Should contain required message');
    }

    @isTest
    static void testSaveQuestionList_UpdateWithInvalidId() {
        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.saveQuestionList(
            '001000000000000AAA',
            'Any Name',
            'Description',
            true,
            5,
            3,
            'High Quality',
            'Medium Quality',
            'Low Quality',
            'Convert to Opportunity',
            'Manager Review',
            'Nurture Lead',
            false
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Update should fail when list Id does not exist');
        System.assert(
            result.message != null && result.message.startsWith('Error saving question list:'),
            'Expected DML/query error message, got: ' + result.message
        );
    }

    @isTest
    static void testDeleteQuestionList() {
        LQW_Question_List__c questionList = [SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Test List 1' LIMIT 1];
        Integer questionCount = [SELECT COUNT() FROM LQW_Qualification_Question__c WHERE LQW_Question_List__c = :questionList.Id];
        System.assertEquals(3, questionCount, 'Should have 3 questions before delete');

        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.deleteQuestionList(questionList.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Delete should succeed');

        List<LQW_Question_List__c> remainingLists = [SELECT Id FROM LQW_Question_List__c WHERE Id = :questionList.Id];
        System.assertEquals(0, remainingLists.size(), 'List should be deleted');

        List<LQW_Qualification_Question__c> remainingQuestions = [SELECT Id FROM LQW_Qualification_Question__c WHERE LQW_Question_List__c = :questionList.Id];
        System.assertEquals(0, remainingQuestions.size(), 'All questions should be deleted');
    }

    @isTest
    static void testSaveQuestion_Create() {
        LQW_Question_List__c questionList = [SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Test List 1' LIMIT 1];

        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.saveQuestion(
            null,
            questionList.Id,
            'New Question Text',
            4,
            5,
            'Yes',
            true,
            'Yes',
            true
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Save should succeed');
        System.assertNotEquals(null, result.recordId, 'Record ID should be returned');

        LQW_Qualification_Question__c newQuestion = [SELECT LQW_Question_Text__c, LQW_Question_Order__c,
                                                      LQW_Score_Value__c, LQW_Point_Earning_Answer__c,
                                                      LQW_Is_Dealbreaker__c, LQW_Dealbreaker_Value__c, LQW_Is_Active__c
                                                      FROM LQW_Qualification_Question__c WHERE Id = :result.recordId];
        System.assertEquals('New Question Text', newQuestion.LQW_Question_Text__c, 'Question text should match');
        System.assertEquals(4, newQuestion.LQW_Question_Order__c, 'Order should match');
        System.assertEquals(5, newQuestion.LQW_Score_Value__c, 'Score should match');
        System.assertEquals('Yes', newQuestion.LQW_Point_Earning_Answer__c, 'Point earning answer should match');
        System.assertEquals(true, newQuestion.LQW_Is_Dealbreaker__c, 'Should be dealbreaker');
        System.assertEquals('Yes', newQuestion.LQW_Dealbreaker_Value__c, 'Dealbreaker value should match');
        System.assertEquals(true, newQuestion.LQW_Is_Active__c, 'Should be active');
    }

    @isTest
    static void testSaveQuestion_Update() {
        LQW_Qualification_Question__c question = [SELECT Id, LQW_Question_List__c FROM LQW_Qualification_Question__c
                                                   WHERE LQW_Question_Text__c = 'Test Question 1' LIMIT 1];

        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.saveQuestion(
            question.Id,
            question.LQW_Question_List__c,
            'Updated Question Text',
            10,
            7,
            'No',
            false,
            null,
            false
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Update should succeed');

        LQW_Qualification_Question__c updatedQuestion = [SELECT LQW_Question_Text__c, LQW_Question_Order__c,
                                                          LQW_Score_Value__c, LQW_Point_Earning_Answer__c,
                                                          LQW_Is_Dealbreaker__c, LQW_Is_Active__c
                                                          FROM LQW_Qualification_Question__c WHERE Id = :question.Id];
        System.assertEquals('Updated Question Text', updatedQuestion.LQW_Question_Text__c, 'Question text should be updated');
        System.assertEquals(10, updatedQuestion.LQW_Question_Order__c, 'Order should be updated');
        System.assertEquals(7, updatedQuestion.LQW_Score_Value__c, 'Score should be updated');
        System.assertEquals('No', updatedQuestion.LQW_Point_Earning_Answer__c, 'Point earning answer should be updated');
        System.assertEquals(false, updatedQuestion.LQW_Is_Dealbreaker__c, 'Should not be dealbreaker');
        System.assertEquals(false, updatedQuestion.LQW_Is_Active__c, 'Should be inactive');
    }

    @isTest
    static void testSaveQuestion_ValidationError() {
        LQW_Question_List__c questionList = [SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Test List 1' LIMIT 1];

        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.saveQuestion(
            null,
            questionList.Id,
            '',
            1,
            1,
            'Yes',
            false,
            null,
            true
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail validation');
        System.assert(result.message.contains('required'), 'Should contain required message');
    }

    @isTest
    static void testDeleteQuestion() {
        LQW_Qualification_Question__c question = [SELECT Id FROM LQW_Qualification_Question__c
                                                   WHERE LQW_Question_Text__c = 'Test Question 1' LIMIT 1];

        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.deleteQuestion(question.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Delete should succeed');

        List<LQW_Qualification_Question__c> remainingQuestions = [SELECT Id FROM LQW_Qualification_Question__c WHERE Id = :question.Id];
        System.assertEquals(0, remainingQuestions.size(), 'Question should be deleted');
    }

    @isTest
    static void testReorderQuestions() {
        List<LQW_Qualification_Question__c> questions = [SELECT Id FROM LQW_Qualification_Question__c
                                                          WHERE LQW_Question_Text__c LIKE 'Test Question%'
                                                          ORDER BY LQW_Question_Order__c ASC];
        System.assertEquals(3, questions.size(), 'Should have 3 questions');

        // Reverse the order
        List<Id> newOrder = new List<Id>{questions[2].Id, questions[1].Id, questions[0].Id};

        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.reorderQuestions(newOrder);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Reorder should succeed');

        List<LQW_Qualification_Question__c> reorderedQuestions = [SELECT Id, LQW_Question_Order__c
                                                                    FROM LQW_Qualification_Question__c
                                                                    WHERE Id IN :newOrder
                                                                    ORDER BY LQW_Question_Order__c ASC];
        System.assertEquals(questions[2].Id, reorderedQuestions[0].Id, 'First question should be the previous third');
        System.assertEquals(1, reorderedQuestions[0].LQW_Question_Order__c, 'Order should be 1');
        System.assertEquals(2, reorderedQuestions[1].LQW_Question_Order__c, 'Order should be 2');
        System.assertEquals(3, reorderedQuestions[2].LQW_Question_Order__c, 'Order should be 3');
    }

    @isTest
    static void testBulkUpdateQuestionStatus_Activate() {
        LQW_Question_List__c questionList = [SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Test List 1' LIMIT 1];

        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.bulkUpdateQuestionStatus(questionList.Id, true);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Bulk update should succeed');
        System.assert(result.message.contains('activated'), 'Message should contain activated');

        List<LQW_Qualification_Question__c> questions = [SELECT LQW_Is_Active__c FROM LQW_Qualification_Question__c
                                                          WHERE LQW_Question_List__c = :questionList.Id];
        for (LQW_Qualification_Question__c q : questions) {
            System.assertEquals(true, q.LQW_Is_Active__c, 'All questions should be active');
        }
    }

    @isTest
    static void testBulkUpdateQuestionStatus_Deactivate() {
        LQW_Question_List__c questionList = [SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Test List 1' LIMIT 1];

        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.bulkUpdateQuestionStatus(questionList.Id, false);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Bulk update should succeed');
        System.assert(result.message.contains('deactivated'), 'Message should contain deactivated');

        List<LQW_Qualification_Question__c> questions = [SELECT LQW_Is_Active__c FROM LQW_Qualification_Question__c
                                                          WHERE LQW_Question_List__c = :questionList.Id];
        for (LQW_Qualification_Question__c q : questions) {
            System.assertEquals(false, q.LQW_Is_Active__c, 'All questions should be inactive');
        }
    }

    @isTest
    static void testCloneQuestionList() {
        LQW_Question_List__c originalList = [SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Test List 1' LIMIT 1];
        Integer originalQuestionCount = [SELECT COUNT() FROM LQW_Qualification_Question__c WHERE LQW_Question_List__c = :originalList.Id];

        Test.startTest();
        LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.cloneQuestionList(originalList.Id, 'Cloned List');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Clone should succeed');
        System.assertNotEquals(null, result.recordId, 'New list ID should be returned');
        System.assert(result.message.contains('3'), 'Message should mention 3 questions');

        LQW_Question_List__c clonedList = [SELECT LQW_List_Name__c, LQW_Description__c, LQW_Is_Active__c
                                            FROM LQW_Question_List__c WHERE Id = :result.recordId];
        System.assertEquals('Cloned List', clonedList.LQW_List_Name__c, 'Cloned list name should match');
        System.assertEquals('Description for test list 1', clonedList.LQW_Description__c, 'Description should be cloned');

        Integer clonedQuestionCount = [SELECT COUNT() FROM LQW_Qualification_Question__c WHERE LQW_Question_List__c = :result.recordId];
        System.assertEquals(originalQuestionCount, clonedQuestionCount, 'Should have same number of questions');

        // Verify question details were cloned
        List<LQW_Qualification_Question__c> clonedQuestions = [SELECT LQW_Question_Text__c, LQW_Question_Order__c,
                                                                 LQW_Score_Value__c, LQW_Is_Dealbreaker__c
                                                                 FROM LQW_Qualification_Question__c
                                                                 WHERE LQW_Question_List__c = :result.recordId
                                                                 ORDER BY LQW_Question_Order__c ASC];
        System.assertEquals('Test Question 1', clonedQuestions[0].LQW_Question_Text__c, 'Question text should be cloned');
        System.assertEquals(2, clonedQuestions[0].LQW_Score_Value__c, 'Score value should be cloned');
        System.assertEquals(true, clonedQuestions[0].LQW_Is_Dealbreaker__c, 'Dealbreaker flag should be cloned');
    }

    @isTest
    static void testGetPointSystemSummary() {
        LQW_Question_List__c questionList = [SELECT Id FROM LQW_Question_List__c WHERE LQW_List_Name__c = 'Test List 1' LIMIT 1];

        Test.startTest();
        LQW_QuestionListManagerCtrl.PointSystemSummary result = LQW_QuestionListManagerCtrl.getPointSystemSummary(questionList.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(3, result.totalQuestionCount, 'Total question count should be 3');
        System.assertEquals(2, result.activeQuestionCount, 'Active question count should be 2');
        System.assertEquals(5, result.totalPossiblePoints, 'Total possible points should be 5 (2+3)');
        System.assertEquals(1, result.dealbreakerCount, 'Dealbreaker count should be 1');
    }

    @isTest
    static void testGetPointEarningAnswerPicklistValues() {
        Test.startTest();
        List<Map<String, String>> result = LQW_QuestionListManagerCtrl.getPointEarningAnswerPicklistValues();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return picklist values');

        // Verify structure
        Map<String, String> firstOption = result[0];
        System.assert(firstOption.containsKey('label'), 'Should have label key');
        System.assert(firstOption.containsKey('value'), 'Should have value key');
    }

    @isTest
    static void testGetDealbreakerValuePicklistValues() {
        Test.startTest();
        List<Map<String, String>> result = LQW_QuestionListManagerCtrl.getDealbreakerValuePicklistValues();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return picklist values');

        // Verify structure
        Map<String, String> firstOption = result[0];
        System.assert(firstOption.containsKey('label'), 'Should have label key');
        System.assert(firstOption.containsKey('value'), 'Should have value key');
    }

    @isTest
    static void testErrorHandling_InvalidListId() {
        Test.startTest();
        try {
            LQW_QuestionListManagerCtrl.QuestionListData result = LQW_QuestionListManagerCtrl.getQuestionList('001000000000000AAA');
            System.assert(false, 'Should throw exception for invalid ID');
        } catch (Exception e) {
            System.assertEquals(
                'System.AuraHandledException',
                e.getTypeName(),
                'Expected AuraHandledException; message was: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testErrorHandling_InvalidQuestionId() {
        Test.startTest();
        try {
            LQW_QuestionListManagerCtrl.SaveResult result = LQW_QuestionListManagerCtrl.deleteQuestion('001000000000000AAA');
            System.assert(false, 'Should throw exception for invalid ID');
        } catch (Exception e) {
            System.assertEquals(
                'System.AuraHandledException',
                e.getTypeName(),
                'Expected AuraHandledException; message was: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }
}
