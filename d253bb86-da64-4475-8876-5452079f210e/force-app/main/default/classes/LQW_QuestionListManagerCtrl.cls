/**
 * @description Apex controller for the Question List Manager LWC component
 * Provides comprehensive CRUD operations for Question Lists and Questions with bulk operations,
 * point system calculations, and list cloning capabilities. Ensures data integrity and security.
 */
public with sharing class LQW_QuestionListManagerCtrl {

    /**
     * @description Wrapper class for Question List with its questions
     */
    public class QuestionListData {
        @AuraEnabled public String listId;
        @AuraEnabled public String listNumber;
        @AuraEnabled public String listName;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public List<QuestionData> questions;
        @AuraEnabled public Integer totalQuestions;
        @AuraEnabled public Integer activeQuestions;
        @AuraEnabled public Integer totalPossiblePoints;
        @AuraEnabled public Integer dealbreakerCount;
        @AuraEnabled public Decimal highQualityThreshold;
        @AuraEnabled public Decimal mediumQualityThreshold;
        @AuraEnabled public String highQualityLabel;
        @AuraEnabled public String mediumQualityLabel;
        @AuraEnabled public String lowQualityLabel;
        @AuraEnabled public String highQualityRecommendation;
        @AuraEnabled public String mediumQualityRecommendation;
        @AuraEnabled public String lowQualityRecommendation;
        @AuraEnabled public String assignmentCriteria;
        @AuraEnabled public Boolean isDefault;
        @AuraEnabled public Boolean hasConflict;
        @AuraEnabled public List<String> conflictingListNames;

        public QuestionListData() {
            this.questions = new List<QuestionData>();
            this.totalQuestions = 0;
            this.activeQuestions = 0;
            this.totalPossiblePoints = 0;
            this.dealbreakerCount = 0;
            this.isActive = true;
            this.highQualityThreshold = 5;
            this.mediumQualityThreshold = 3;
            this.highQualityLabel = 'High Quality';
            this.mediumQualityLabel = 'Medium Quality';
            this.lowQualityLabel = 'Low Quality';
            this.highQualityRecommendation = 'Convert to Opportunity';
            this.mediumQualityRecommendation = 'Convert to Opportunity with Manager Review';
            this.lowQualityRecommendation = 'Nurture Lead (Do Not Convert)';
            this.isDefault = false;
            this.hasConflict = false;
            this.conflictingListNames = new List<String>();
        }
    }

    /**
     * @description Wrapper class for individual Question data
     */
    public class QuestionData {
        @AuraEnabled public String questionId;
        @AuraEnabled public String questionNumber;
        @AuraEnabled public String questionText;
        @AuraEnabled public Integer questionOrder;
        @AuraEnabled public Integer scoreValue;
        @AuraEnabled public String pointEarningAnswer;
        @AuraEnabled public Boolean isDealbreaker;
        @AuraEnabled public String dealbreakerValue;
        @AuraEnabled public Boolean isActive;

        public QuestionData() {
            this.scoreValue = 1;
            this.isDealbreaker = false;
            this.isActive = true;
            this.pointEarningAnswer = 'Both';
        }
    }

    /**
     * @description Wrapper class for save operation results
     */
    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String recordId;

        public SaveResult() {
            this.success = false;
        }
    }

    /**
     * @description Wrapper class for point system summary
     */
    public class PointSystemSummary {
        @AuraEnabled public Integer totalPossiblePoints;
        @AuraEnabled public Integer dealbreakerCount;
        @AuraEnabled public Integer activeQuestionCount;
        @AuraEnabled public Integer totalQuestionCount;

        public PointSystemSummary() {
            this.totalPossiblePoints = 0;
            this.dealbreakerCount = 0;
            this.activeQuestionCount = 0;
            this.totalQuestionCount = 0;
        }
    }

    /**
     * @description Retrieves all question lists with their questions and point system summaries
     * @return List<QuestionListData> All question lists with complete details
     */
    @AuraEnabled(cacheable=true)
    public static List<QuestionListData> getAllQuestionLists() {
        try {
            List<QuestionListData> result = new List<QuestionListData>();

            // Get all question lists
            List<LQW_Question_List__c> questionLists = [
                SELECT Id, Name, LQW_List_Name__c, LQW_Description__c, LQW_Is_Active__c,
                       LQW_High_Quality_Threshold__c, LQW_Medium_Quality_Threshold__c,
                       LQW_High_Quality_Label__c, LQW_Medium_Quality_Label__c, LQW_Low_Quality_Label__c,
                       LQW_High_Quality_Recommendation__c, LQW_Medium_Quality_Recommendation__c, LQW_Low_Quality_Recommendation__c,
                       LQW_Assignment_Criteria__c, LQW_Is_Default__c
                FROM LQW_Question_List__c
                WITH USER_MODE
                ORDER BY LQW_List_Name__c ASC NULLS LAST, Name ASC
            ];

            // Get all questions for all lists in one query (bulkified)
            Map<Id, List<LQW_Qualification_Question__c>> questionsMap = new Map<Id, List<LQW_Qualification_Question__c>>();
            List<LQW_Qualification_Question__c> allQuestions = [
                SELECT Id, Name, LQW_Question_Text__c, LQW_Question_Order__c,
                       LQW_Score_Value__c, LQW_Point_Earning_Answer__c,
                       LQW_Is_Dealbreaker__c, LQW_Dealbreaker_Value__c,
                       LQW_Is_Active__c, LQW_Question_List__c
                FROM LQW_Qualification_Question__c
                WHERE LQW_Question_List__c != null
                WITH USER_MODE
                ORDER BY LQW_Question_Order__c ASC NULLS LAST, Name ASC
            ];

            // Group questions by list
            for (LQW_Qualification_Question__c question : allQuestions) {
                if (!questionsMap.containsKey(question.LQW_Question_List__c)) {
                    questionsMap.put(question.LQW_Question_List__c, new List<LQW_Qualification_Question__c>());
                }
                questionsMap.get(question.LQW_Question_List__c).add(question);
            }

            // Build result with point system calculations
            for (LQW_Question_List__c questionList : questionLists) {
                QuestionListData listData = new QuestionListData();
                listData.listId = questionList.Id;
                listData.listNumber = questionList.Name;
                listData.listName = questionList.LQW_List_Name__c;
                listData.description = questionList.LQW_Description__c;
                listData.isActive = questionList.LQW_Is_Active__c;
                // Populate threshold and label fields from the database
                listData.highQualityThreshold = questionList.LQW_High_Quality_Threshold__c != null ? questionList.LQW_High_Quality_Threshold__c : 5;
                listData.mediumQualityThreshold = questionList.LQW_Medium_Quality_Threshold__c != null ? questionList.LQW_Medium_Quality_Threshold__c : 3;
                listData.highQualityLabel = String.isNotBlank(questionList.LQW_High_Quality_Label__c) ? questionList.LQW_High_Quality_Label__c : 'High Quality';
                listData.mediumQualityLabel = String.isNotBlank(questionList.LQW_Medium_Quality_Label__c) ? questionList.LQW_Medium_Quality_Label__c : 'Medium Quality';
                listData.lowQualityLabel = String.isNotBlank(questionList.LQW_Low_Quality_Label__c) ? questionList.LQW_Low_Quality_Label__c : 'Low Quality';
                listData.highQualityRecommendation = String.isNotBlank(questionList.LQW_High_Quality_Recommendation__c) ? questionList.LQW_High_Quality_Recommendation__c : 'Convert to Opportunity';
                listData.mediumQualityRecommendation = String.isNotBlank(questionList.LQW_Medium_Quality_Recommendation__c) ? questionList.LQW_Medium_Quality_Recommendation__c : 'Convert to Opportunity with Manager Review';
                listData.lowQualityRecommendation = String.isNotBlank(questionList.LQW_Low_Quality_Recommendation__c) ? questionList.LQW_Low_Quality_Recommendation__c : 'Nurture Lead (Do Not Convert)';
                // Populate assignment criteria and default flag
                listData.assignmentCriteria = questionList.LQW_Assignment_Criteria__c;
                listData.isDefault = questionList.LQW_Is_Default__c;

                // Add questions if they exist for this list
                if (questionsMap.containsKey(questionList.Id)) {
                    for (LQW_Qualification_Question__c question : questionsMap.get(questionList.Id)) {
                        QuestionData qData = mapQuestionToWrapper(question);
                        listData.questions.add(qData);

                        // Calculate point system metrics
                        listData.totalQuestions++;
                        if (qData.isActive) {
                            listData.activeQuestions++;
                            listData.totalPossiblePoints += qData.scoreValue;
                        }
                        if (qData.isDealbreaker) {
                            listData.dealbreakerCount++;
                        }
                    }
                }

                result.add(listData);
            }

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving question lists: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves a single question list with its questions
     * @param listId The ID of the question list
     * @return QuestionListData Question list with complete details
     */
    @AuraEnabled(cacheable=false)
    public static QuestionListData getQuestionList(Id listId) {
        try {
            List<LQW_Question_List__c> questionLists = [
                SELECT Id, Name, LQW_List_Name__c, LQW_Description__c, LQW_Is_Active__c,
                       LQW_High_Quality_Threshold__c, LQW_Medium_Quality_Threshold__c,
                       LQW_High_Quality_Label__c, LQW_Medium_Quality_Label__c, LQW_Low_Quality_Label__c,
                       LQW_High_Quality_Recommendation__c, LQW_Medium_Quality_Recommendation__c, LQW_Low_Quality_Recommendation__c,
                       LQW_Assignment_Criteria__c, LQW_Is_Default__c
                FROM LQW_Question_List__c
                WHERE Id = :listId
                WITH USER_MODE
                LIMIT 1
            ];
            if (questionLists.isEmpty()) {
                throw new AuraHandledException('Error retrieving question list: Question list not found.');
            }
            LQW_Question_List__c questionList = questionLists[0];

            QuestionListData listData = new QuestionListData();
            listData.listId = questionList.Id;
            listData.listNumber = questionList.Name;
            listData.listName = questionList.LQW_List_Name__c;
            listData.description = questionList.LQW_Description__c;
            listData.isActive = questionList.LQW_Is_Active__c;
            // Populate threshold and label fields from the database
            listData.highQualityThreshold = questionList.LQW_High_Quality_Threshold__c != null ? questionList.LQW_High_Quality_Threshold__c : 5;
            listData.mediumQualityThreshold = questionList.LQW_Medium_Quality_Threshold__c != null ? questionList.LQW_Medium_Quality_Threshold__c : 3;
            listData.highQualityLabel = String.isNotBlank(questionList.LQW_High_Quality_Label__c) ? questionList.LQW_High_Quality_Label__c : 'High Quality';
            listData.mediumQualityLabel = String.isNotBlank(questionList.LQW_Medium_Quality_Label__c) ? questionList.LQW_Medium_Quality_Label__c : 'Medium Quality';
            listData.lowQualityLabel = String.isNotBlank(questionList.LQW_Low_Quality_Label__c) ? questionList.LQW_Low_Quality_Label__c : 'Low Quality';
            listData.highQualityRecommendation = String.isNotBlank(questionList.LQW_High_Quality_Recommendation__c) ? questionList.LQW_High_Quality_Recommendation__c : 'Convert to Opportunity';
            listData.mediumQualityRecommendation = String.isNotBlank(questionList.LQW_Medium_Quality_Recommendation__c) ? questionList.LQW_Medium_Quality_Recommendation__c : 'Convert to Opportunity with Manager Review';
            listData.lowQualityRecommendation = String.isNotBlank(questionList.LQW_Low_Quality_Recommendation__c) ? questionList.LQW_Low_Quality_Recommendation__c : 'Nurture Lead (Do Not Convert)';
            // Populate assignment criteria and default flag
            listData.assignmentCriteria = questionList.LQW_Assignment_Criteria__c;
            listData.isDefault = questionList.LQW_Is_Default__c;

            // Get questions for this list
            List<LQW_Qualification_Question__c> questions = [
                SELECT Id, Name, LQW_Question_Text__c, LQW_Question_Order__c,
                       LQW_Score_Value__c, LQW_Point_Earning_Answer__c,
                       LQW_Is_Dealbreaker__c, LQW_Dealbreaker_Value__c, LQW_Is_Active__c
                FROM LQW_Qualification_Question__c
                WHERE LQW_Question_List__c = :listId
                WITH USER_MODE
                ORDER BY LQW_Question_Order__c ASC NULLS LAST, Name ASC
            ];

            for (LQW_Qualification_Question__c question : questions) {
                QuestionData qData = mapQuestionToWrapper(question);
                listData.questions.add(qData);

                listData.totalQuestions++;
                if (qData.isActive) {
                    listData.activeQuestions++;
                    listData.totalPossiblePoints += qData.scoreValue;
                }
                if (qData.isDealbreaker) {
                    listData.dealbreakerCount++;
                }
            }

            return listData;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving question list: ' + e.getMessage());
        }
    }

    /**
     * @description Creates or updates a question list with threshold configuration
     * @param listId The ID of the list to update (null for new list)
     * @param listName The name of the list
     * @param description The description
     * @param isActive Whether the list is active
     * @param highQualityThreshold Minimum points for High Quality tier
     * @param mediumQualityThreshold Minimum points for Medium Quality tier
     * @param highQualityLabel Label for High Quality tier
     * @param mediumQualityLabel Label for Medium Quality tier
     * @param lowQualityLabel Label for Low Quality tier
     * @param highQualityRecommendation Recommendation for High Quality tier
     * @param mediumQualityRecommendation Recommendation for Medium Quality tier
     * @param lowQualityRecommendation Recommendation for Low Quality tier
     * @param isDefault Whether this is the default fallback list
     * @return SaveResult Result of the save operation
     */
    @AuraEnabled(cacheable=false)
    public static SaveResult saveQuestionList(
        Id listId, String listName, String description, Boolean isActive,
        Decimal highQualityThreshold, Decimal mediumQualityThreshold,
        String highQualityLabel, String mediumQualityLabel, String lowQualityLabel,
        String highQualityRecommendation, String mediumQualityRecommendation, String lowQualityRecommendation,
        Boolean isDefault
    ) {
        SaveResult result = new SaveResult();

        try {
            // Validate input
            if (String.isBlank(listName)) {
                result.message = 'List name is required.';
                return result;
            }

            LQW_Question_List__c questionList;

            if (listId != null) {
                // Update existing list
                questionList = [SELECT Id FROM LQW_Question_List__c WHERE Id = :listId WITH USER_MODE LIMIT 1];
                questionList.LQW_List_Name__c = listName;
                questionList.LQW_Description__c = description;
                questionList.LQW_Is_Active__c = isActive;
                questionList.LQW_High_Quality_Threshold__c = highQualityThreshold;
                questionList.LQW_Medium_Quality_Threshold__c = mediumQualityThreshold;
                questionList.LQW_High_Quality_Label__c = highQualityLabel;
                questionList.LQW_Medium_Quality_Label__c = mediumQualityLabel;
                questionList.LQW_Low_Quality_Label__c = lowQualityLabel;
                questionList.LQW_High_Quality_Recommendation__c = highQualityRecommendation;
                questionList.LQW_Medium_Quality_Recommendation__c = mediumQualityRecommendation;
                questionList.LQW_Low_Quality_Recommendation__c = lowQualityRecommendation;
                questionList.LQW_Is_Default__c = isDefault != null ? isDefault : false;
                update as user questionList;
                result.message = 'Question list updated successfully.';
            } else {
                // Create new list
                questionList = new LQW_Question_List__c();
                questionList.LQW_List_Name__c = listName;
                questionList.LQW_Description__c = description;
                questionList.LQW_Is_Active__c = isActive != null ? isActive : true;
                questionList.LQW_High_Quality_Threshold__c = highQualityThreshold;
                questionList.LQW_Medium_Quality_Threshold__c = mediumQualityThreshold;
                questionList.LQW_High_Quality_Label__c = highQualityLabel;
                questionList.LQW_Medium_Quality_Label__c = mediumQualityLabel;
                questionList.LQW_Low_Quality_Label__c = lowQualityLabel;
                questionList.LQW_High_Quality_Recommendation__c = highQualityRecommendation;
                questionList.LQW_Medium_Quality_Recommendation__c = mediumQualityRecommendation;
                questionList.LQW_Low_Quality_Recommendation__c = lowQualityRecommendation;
                questionList.LQW_Is_Default__c = isDefault != null ? isDefault : false;
                insert as user questionList;
                result.message = 'Question list created successfully.';
            }

            result.success = true;
            result.recordId = questionList.Id;
            return result;

        } catch (Exception e) {
            result.message = 'Error saving question list: ' + e.getMessage();
            return result;
        }
    }

    /**
     * @description Deletes a question list and all its questions
     * @param listId The ID of the list to delete
     * @return SaveResult Result of the delete operation
     */
    @AuraEnabled(cacheable=false)
    public static SaveResult deleteQuestionList(Id listId) {
        SaveResult result = new SaveResult();

        try {
            // Delete all questions first (cascade)
            List<LQW_Qualification_Question__c> questions = [
                SELECT Id FROM LQW_Qualification_Question__c WHERE LQW_Question_List__c = :listId WITH USER_MODE
            ];
            if (!questions.isEmpty()) {
                delete as user questions;
            }

            // Delete the list
            LQW_Question_List__c questionList = [SELECT Id FROM LQW_Question_List__c WHERE Id = :listId WITH USER_MODE LIMIT 1];
            delete as user questionList;

            result.success = true;
            result.message = 'Question list and all associated questions deleted successfully.';
            return result;

        } catch (Exception e) {
            result.message = 'Error deleting question list: ' + e.getMessage();
            return result;
        }
    }

    /**
     * @description Creates or updates a question
     * @param questionId The ID of the question to update (null for new)
     * @param listId The ID of the question list
     * @param questionText The question text
     * @param questionOrder The display order
     * @param scoreValue The point value
     * @param pointEarningAnswer Which answer earns points
     * @param isDealbreaker Whether this is a dealbreaker question
     * @param dealbreakerValue The value that triggers disqualification
     * @param isActive Whether the question is active
     * @return SaveResult Result of the save operation
     */
    @AuraEnabled(cacheable=false)
    public static SaveResult saveQuestion(
        Id questionId, Id listId, String questionText, Integer questionOrder,
        Integer scoreValue, String pointEarningAnswer, Boolean isDealbreaker,
        String dealbreakerValue, Boolean isActive
    ) {
        SaveResult result = new SaveResult();

        try {
            // Validate input
            if (listId == null) {
                result.message = 'Question list is required.';
                return result;
            }
            if (String.isBlank(questionText)) {
                result.message = 'Question text is required.';
                return result;
            }

            LQW_Qualification_Question__c question;

            if (questionId != null) {
                // Update existing question
                question = [SELECT Id FROM LQW_Qualification_Question__c WHERE Id = :questionId WITH USER_MODE LIMIT 1];
            } else {
                // Create new question
                question = new LQW_Qualification_Question__c();
                question.LQW_Question_List__c = listId;
            }

            question.LQW_Question_Text__c = questionText;
            question.LQW_Question_Order__c = questionOrder;
            question.LQW_Score_Value__c = scoreValue != null ? scoreValue : 1;
            question.LQW_Point_Earning_Answer__c = String.isNotBlank(pointEarningAnswer) ? pointEarningAnswer : 'Both';
            question.LQW_Is_Dealbreaker__c = isDealbreaker != null ? isDealbreaker : false;
            question.LQW_Dealbreaker_Value__c = dealbreakerValue;
            question.LQW_Is_Active__c = isActive != null ? isActive : true;

            upsert as user question;

            result.success = true;
            result.recordId = question.Id;
            result.message = questionId != null ? 'Question updated successfully.' : 'Question created successfully.';
            return result;

        } catch (Exception e) {
            result.message = 'Error saving question: ' + e.getMessage();
            return result;
        }
    }

    /**
     * @description Deletes a question
     * @param questionId The ID of the question to delete
     * @return SaveResult Result of the delete operation
     */
    @AuraEnabled(cacheable=false)
    public static SaveResult deleteQuestion(Id questionId) {
        SaveResult result = new SaveResult();

        try {
            List<LQW_Qualification_Question__c> questions = [
                SELECT Id FROM LQW_Qualification_Question__c WHERE Id = :questionId WITH USER_MODE LIMIT 1
            ];
            if (questions.isEmpty()) {
                throw new AuraHandledException('Error deleting question: Question not found.');
            }
            delete as user questions;

            result.success = true;
            result.message = 'Question deleted successfully.';
            return result;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting question: ' + e.getMessage());
        }
    }

    /**
     * @description Reorders questions within a list
     * @param questionIdsInOrder List of question IDs in the desired order
     * @return SaveResult Result of the reorder operation
     */
    @AuraEnabled(cacheable=false)
    public static SaveResult reorderQuestions(List<Id> questionIdsInOrder) {
        SaveResult result = new SaveResult();

        try {
            if (questionIdsInOrder == null || questionIdsInOrder.isEmpty()) {
                result.message = 'No questions to reorder.';
                return result;
            }

            List<LQW_Qualification_Question__c> questionsToUpdate = [
                SELECT Id FROM LQW_Qualification_Question__c WHERE Id IN :questionIdsInOrder WITH USER_MODE
            ];

            Map<Id, LQW_Qualification_Question__c> questionMap = new Map<Id, LQW_Qualification_Question__c>(questionsToUpdate);

            Integer orderIndex = 1;
            List<LQW_Qualification_Question__c> orderedQuestions = new List<LQW_Qualification_Question__c>();

            for (Id questionId : questionIdsInOrder) {
                if (questionMap.containsKey(questionId)) {
                    LQW_Qualification_Question__c question = questionMap.get(questionId);
                    question.LQW_Question_Order__c = orderIndex;
                    orderedQuestions.add(question);
                    orderIndex++;
                }
            }

            if (!orderedQuestions.isEmpty()) {
                update as user orderedQuestions;
            }

            result.success = true;
            result.message = 'Questions reordered successfully.';
            return result;

        } catch (Exception e) {
            result.message = 'Error reordering questions: ' + e.getMessage();
            return result;
        }
    }

    /**
     * @description Bulk activates or deactivates all questions in a list
     * @param listId The ID of the question list
     * @param isActive The active status to set
     * @return SaveResult Result of the bulk operation
     */
    @AuraEnabled(cacheable=false)
    public static SaveResult bulkUpdateQuestionStatus(Id listId, Boolean isActive) {
        SaveResult result = new SaveResult();

        try {
            List<LQW_Qualification_Question__c> questions = [
                SELECT Id, LQW_Is_Active__c
                FROM LQW_Qualification_Question__c
                WHERE LQW_Question_List__c = :listId
                WITH USER_MODE
            ];

            if (questions.isEmpty()) {
                result.message = 'No questions found in this list.';
                return result;
            }

            for (LQW_Qualification_Question__c question : questions) {
                question.LQW_Is_Active__c = isActive;
            }

            update as user questions;

            result.success = true;
            result.message = questions.size() + ' question(s) ' + (isActive ? 'activated' : 'deactivated') + ' successfully.';
            return result;

        } catch (Exception e) {
            result.message = 'Error updating question status: ' + e.getMessage();
            return result;
        }
    }

    /**
     * @description Clones a question list with all its questions
     * @param listId The ID of the list to clone
     * @param newListName The name for the cloned list
     * @return SaveResult Result of the clone operation
     */
    @AuraEnabled(cacheable=false)
    public static SaveResult cloneQuestionList(Id listId, String newListName) {
        SaveResult result = new SaveResult();

        try {
            // Validate input
            if (String.isBlank(newListName)) {
                result.message = 'New list name is required.';
                return result;
            }

            // Get original list
            LQW_Question_List__c originalList = [
                SELECT Id, LQW_List_Name__c, LQW_Description__c, LQW_Is_Active__c,
                       LQW_High_Quality_Threshold__c, LQW_Medium_Quality_Threshold__c,
                       LQW_High_Quality_Label__c, LQW_Medium_Quality_Label__c, LQW_Low_Quality_Label__c,
                       LQW_High_Quality_Recommendation__c, LQW_Medium_Quality_Recommendation__c, LQW_Low_Quality_Recommendation__c,
                       LQW_Is_Default__c
                FROM LQW_Question_List__c
                WHERE Id = :listId
                WITH USER_MODE
                LIMIT 1
            ];

            // Create new list
            LQW_Question_List__c newList = new LQW_Question_List__c();
            newList.LQW_List_Name__c = newListName;
            newList.LQW_Description__c = originalList.LQW_Description__c;
            newList.LQW_Is_Active__c = originalList.LQW_Is_Active__c;
            newList.LQW_High_Quality_Threshold__c = originalList.LQW_High_Quality_Threshold__c;
            newList.LQW_Medium_Quality_Threshold__c = originalList.LQW_Medium_Quality_Threshold__c;
            newList.LQW_High_Quality_Label__c = originalList.LQW_High_Quality_Label__c;
            newList.LQW_Medium_Quality_Label__c = originalList.LQW_Medium_Quality_Label__c;
            newList.LQW_Low_Quality_Label__c = originalList.LQW_Low_Quality_Label__c;
            newList.LQW_High_Quality_Recommendation__c = originalList.LQW_High_Quality_Recommendation__c;
            newList.LQW_Medium_Quality_Recommendation__c = originalList.LQW_Medium_Quality_Recommendation__c;
            newList.LQW_Low_Quality_Recommendation__c = originalList.LQW_Low_Quality_Recommendation__c;
            newList.LQW_Is_Default__c = false; // Cloned list is never default
            insert as user newList;

            // Get all questions from original list
            List<LQW_Qualification_Question__c> originalQuestions = [
                SELECT LQW_Question_Text__c, LQW_Question_Order__c, LQW_Score_Value__c,
                       LQW_Point_Earning_Answer__c, LQW_Is_Dealbreaker__c,
                       LQW_Dealbreaker_Value__c, LQW_Is_Active__c
                FROM LQW_Qualification_Question__c
                WHERE LQW_Question_List__c = :listId
                WITH USER_MODE
            ];

            // Clone all questions
            if (!originalQuestions.isEmpty()) {
                List<LQW_Qualification_Question__c> newQuestions = new List<LQW_Qualification_Question__c>();

                for (LQW_Qualification_Question__c originalQuestion : originalQuestions) {
                    LQW_Qualification_Question__c newQuestion = new LQW_Qualification_Question__c();
                    newQuestion.LQW_Question_List__c = newList.Id;
                    newQuestion.LQW_Question_Text__c = originalQuestion.LQW_Question_Text__c;
                    newQuestion.LQW_Question_Order__c = originalQuestion.LQW_Question_Order__c;
                    newQuestion.LQW_Score_Value__c = originalQuestion.LQW_Score_Value__c;
                    newQuestion.LQW_Point_Earning_Answer__c = originalQuestion.LQW_Point_Earning_Answer__c;
                    newQuestion.LQW_Is_Dealbreaker__c = originalQuestion.LQW_Is_Dealbreaker__c;
                    newQuestion.LQW_Dealbreaker_Value__c = originalQuestion.LQW_Dealbreaker_Value__c;
                    newQuestion.LQW_Is_Active__c = originalQuestion.LQW_Is_Active__c;
                    newQuestions.add(newQuestion);
                }

                insert as user newQuestions;
            }

            result.success = true;
            result.recordId = newList.Id;
            result.message = 'Question list cloned successfully with ' + originalQuestions.size() + ' question(s).';
            return result;

        } catch (Exception e) {
            result.message = 'Error cloning question list: ' + e.getMessage();
            return result;
        }
    }

    /**
     * @description Gets point system summary for a specific list
     * @param listId The ID of the question list
     * @return PointSystemSummary Point system metrics
     */
    @AuraEnabled(cacheable=false)
    public static PointSystemSummary getPointSystemSummary(Id listId) {
        try {
            PointSystemSummary summary = new PointSystemSummary();

            List<LQW_Qualification_Question__c> questions = [
                SELECT LQW_Score_Value__c, LQW_Is_Active__c, LQW_Is_Dealbreaker__c
                FROM LQW_Qualification_Question__c
                WHERE LQW_Question_List__c = :listId
                WITH USER_MODE
            ];

            summary.totalQuestionCount = questions.size();

            for (LQW_Qualification_Question__c question : questions) {
                if (question.LQW_Is_Active__c == true) {
                    summary.activeQuestionCount++;
                    Integer scoreValue = question.LQW_Score_Value__c != null ?
                        Integer.valueOf(question.LQW_Score_Value__c) : 1;
                    summary.totalPossiblePoints += scoreValue;
                }
                if (question.LQW_Is_Dealbreaker__c == true) {
                    summary.dealbreakerCount++;
                }
            }

            return summary;

        } catch (Exception e) {
            throw new AuraHandledException('Error calculating point system summary: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves picklist values for Point Earning Answer field
     * @return List<Map<String, String>> Picklist options with label and value
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getPointEarningAnswerPicklistValues() {
        List<Map<String, String>> options = new List<Map<String, String>>();

        Schema.DescribeFieldResult fieldResult = LQW_Qualification_Question__c.LQW_Point_Earning_Answer__c.getDescribe();
        List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }

        return options;
    }

    /**
     * @description Retrieves picklist values for Dealbreaker Value field
     * @return List<Map<String, String>> Picklist options with label and value
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getDealbreakerValuePicklistValues() {
        List<Map<String, String>> options = new List<Map<String, String>>();

        Schema.DescribeFieldResult fieldResult = LQW_Qualification_Question__c.LQW_Dealbreaker_Value__c.getDescribe();
        List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }

        return options;
    }

    /**
     * @description Wrapper class for conflict detection results
     */
    public class ConflictDetectionResult {
        @AuraEnabled public Boolean hasConflicts;
        @AuraEnabled public List<ConflictPair> conflicts;

        public ConflictDetectionResult() {
            this.hasConflicts = false;
            this.conflicts = new List<ConflictPair>();
        }
    }

    /**
     * @description Wrapper class for a pair of conflicting lists
     */
    public class ConflictPair {
        @AuraEnabled public String list1Id;
        @AuraEnabled public String list1Name;
        @AuraEnabled public String list2Id;
        @AuraEnabled public String list2Name;
        @AuraEnabled public String conflictDescription;

        public ConflictPair() {
        }
    }

    /**
     * @description Detects criteria conflicts across all active question lists
     * Compares Assignment_Criteria__c JSON to find overlapping rules
     * @return ConflictDetectionResult Conflict detection results
     */
    @AuraEnabled(cacheable=false)
    public static ConflictDetectionResult detectCriteriaConflicts() {
        ConflictDetectionResult result = new ConflictDetectionResult();

        try {
            // Get all active non-default lists
            // Note: Cannot filter LongTextArea field LQW_Assignment_Criteria__c in WHERE clause
            List<LQW_Question_List__c> questionLists = [
                SELECT Id, LQW_List_Name__c, LQW_Assignment_Criteria__c
                FROM LQW_Question_List__c
                WHERE LQW_Is_Active__c = true
                AND LQW_Is_Default__c = false
                WITH USER_MODE
                ORDER BY LQW_List_Name__c ASC
            ];

            // Parse criteria for each list
            Map<Id, List<Map<String, String>>> listCriteriaMap = new Map<Id, List<Map<String, String>>>();

            for (LQW_Question_List__c questionList : questionLists) {
                // Skip if no criteria
                if (String.isBlank(questionList.LQW_Assignment_Criteria__c)) {
                    continue;
                }

                try {
                    List<Object> criteriaList = (List<Object>) JSON.deserializeUntyped(questionList.LQW_Assignment_Criteria__c);
                    List<Map<String, String>> parsedCriteria = new List<Map<String, String>>();

                    for (Object criteriaObj : criteriaList) {
                        Map<String, Object> criteriaMap = (Map<String, Object>) criteriaObj;
                        Map<String, String> parsedMap = new Map<String, String>();
                        parsedMap.put('field', String.valueOf(criteriaMap.get('field')));
                        parsedMap.put('operator', String.valueOf(criteriaMap.get('operator')));
                        parsedMap.put('value', String.valueOf(criteriaMap.get('value')));
                        parsedCriteria.add(parsedMap);
                    }

                    listCriteriaMap.put(questionList.Id, parsedCriteria);
                } catch (Exception e) {
                    // Skip lists with invalid JSON
                    continue;
                }
            }

            // Compare each list against all others
            for (Integer i = 0; i < questionLists.size(); i++) {
                for (Integer j = i + 1; j < questionLists.size(); j++) {
                    LQW_Question_List__c list1 = questionLists[i];
                    LQW_Question_List__c list2 = questionLists[j];

                    if (listCriteriaMap.containsKey(list1.Id) && listCriteriaMap.containsKey(list2.Id)) {
                        List<Map<String, String>> criteria1 = listCriteriaMap.get(list1.Id);
                        List<Map<String, String>> criteria2 = listCriteriaMap.get(list2.Id);

                        // Check for overlapping criteria
                        if (hasOverlappingCriteria(criteria1, criteria2)) {
                            ConflictPair conflict = new ConflictPair();
                            conflict.list1Id = list1.Id;
                            conflict.list1Name = list1.LQW_List_Name__c;
                            conflict.list2Id = list2.Id;
                            conflict.list2Name = list2.LQW_List_Name__c;
                            conflict.conflictDescription = 'Both lists have overlapping assignment criteria';
                            result.conflicts.add(conflict);
                            result.hasConflicts = true;
                        }
                    }
                }
            }

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error detecting criteria conflicts: ' + e.getMessage());
        }
    }

    /**
     * @description Checks if two criteria lists have overlapping rules
     * @param criteria1 First list's criteria
     * @param criteria2 Second list's criteria
     * @return Boolean True if there is overlap
     */
    private static Boolean hasOverlappingCriteria(List<Map<String, String>> criteria1, List<Map<String, String>> criteria2) {
        // Simple overlap detection: if any criterion matches exactly, they overlap
        for (Map<String, String> c1 : criteria1) {
            for (Map<String, String> c2 : criteria2) {
                if (c1.get('field') == c2.get('field') &&
                    c1.get('operator') == c2.get('operator') &&
                    c1.get('value') == c2.get('value')) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * @description Creates a default question list with 9 pre-configured questions
     * This method replicates the same logic as ensureExampleListExists() from the trigger handler
     * Allows admin UI to bootstrap the default list on demand
     * @return SaveResult Result of the create operation with the new list ID
     */
    @AuraEnabled(cacheable=false)
    public static SaveResult createDefaultQuestionList() {
        SaveResult result = new SaveResult();

        try {
            // Check if a default list already exists
            List<LQW_Question_List__c> existingDefaultLists = [
                SELECT Id, LQW_List_Name__c
                FROM LQW_Question_List__c
                WHERE LQW_Is_Default__c = true
                WITH USER_MODE
                LIMIT 1
            ];

            if (!existingDefaultLists.isEmpty()) {
                result.message = 'A default question list already exists: ' + existingDefaultLists[0].LQW_List_Name__c;
                return result;
            }

            // Create the "General Qualification" default list
            LQW_Question_List__c defaultList = new LQW_Question_List__c();
            defaultList.LQW_List_Name__c = 'General Qualification';
            defaultList.LQW_Description__c = 'Default qualification questions for all leads';
            defaultList.LQW_Is_Active__c = true;
            defaultList.LQW_Is_Default__c = true;
            defaultList.LQW_High_Quality_Threshold__c = 5;
            defaultList.LQW_Medium_Quality_Threshold__c = 3;
            defaultList.LQW_High_Quality_Label__c = 'High Quality';
            defaultList.LQW_Medium_Quality_Label__c = 'Medium Quality';
            defaultList.LQW_Low_Quality_Label__c = 'Low Quality';
            defaultList.LQW_High_Quality_Recommendation__c = 'Convert to Opportunity';
            defaultList.LQW_Medium_Quality_Recommendation__c = 'Convert to Opportunity with Manager Review';
            defaultList.LQW_Low_Quality_Recommendation__c = 'Nurture Lead (Do Not Convert)';
            insert as user defaultList;

            // Create the 9 pre-configured qualification questions
            List<LQW_Qualification_Question__c> defaultQuestions = new List<LQW_Qualification_Question__c>();

            // Question 1: Dealbreaker - Low purchasing volume
            defaultQuestions.add(createDefaultQuestion(
                defaultList.Id,
                'Is the customer purchasing volume lower than $25K annually?',
                1, 1, 'No', true, 'Yes'
            ));

            // Question 2: Dealbreaker - Contracts
            defaultQuestions.add(createDefaultQuestion(
                defaultList.Id,
                'Are they under any contracts that would prevent them from doing business with us?',
                2, 1, 'No', true, 'Yes'
            ));

            // Question 3: Competitive product
            defaultQuestions.add(createDefaultQuestion(
                defaultList.Id,
                'Is the customer using a competitive product or a product we can upgrade?',
                3, 1, 'Yes', false, null
            ));

            // Question 4: Multiple categories
            defaultQuestions.add(createDefaultQuestion(
                defaultList.Id,
                'Does the customer purchases across more than one of our categories?',
                4, 1, 'Yes', false, null
            ));

            // Question 5: Compelling event
            defaultQuestions.add(createDefaultQuestion(
                defaultList.Id,
                'Is there a compelling event or reason to act within a reasonable window (e.g., 3–6 months)?',
                5, 1, 'Yes', false, null
            ));

            // Question 6: Solution fit
            defaultQuestions.add(createDefaultQuestion(
                defaultList.Id,
                'Does our solution address the core need without significant gaps?',
                6, 1, 'Yes', false, null
            ));

            // Question 7: Delivery capability
            defaultQuestions.add(createDefaultQuestion(
                defaultList.Id,
                'Can we deliver within their required timeframe and scope?',
                7, 1, 'Yes', false, null
            ));

            // Question 8: Budget
            defaultQuestions.add(createDefaultQuestion(
                defaultList.Id,
                'Does the lead have budget already allocated OR a viable path to obtain budget?',
                8, 1, 'Yes', false, null
            ));

            // Question 9: Decision maker
            defaultQuestions.add(createDefaultQuestion(
                defaultList.Id,
                'Have you identified the decision maker or someone directly involved in the decision?',
                9, 1, 'Yes', false, null
            ));

            insert as user defaultQuestions;

            result.success = true;
            result.recordId = defaultList.Id;
            result.message = 'Default question list created successfully with 9 pre-configured questions.';
            return result;

        } catch (Exception e) {
            result.message = 'Error creating default question list: ' + e.getMessage();
            return result;
        }
    }

    /**
     * @description Helper method to create a default qualification question
     * @param listId The question list ID
     * @param questionText The question text
     * @param order The question order
     * @param scoreValue The point value
     * @param pointEarningAnswer Which answer earns points
     * @param isDealbreaker Whether this is a dealbreaker
     * @param dealbreakerValue The dealbreaker value
     * @return LQW_Qualification_Question__c The created question
     */
    private static LQW_Qualification_Question__c createDefaultQuestion(
        Id listId, String questionText, Integer order, Integer scoreValue,
        String pointEarningAnswer, Boolean isDealbreaker, String dealbreakerValue
    ) {
        LQW_Qualification_Question__c question = new LQW_Qualification_Question__c();
        question.LQW_Question_List__c = listId;
        question.LQW_Question_Text__c = questionText;
        question.LQW_Question_Order__c = order;
        question.LQW_Score_Value__c = scoreValue;
        question.LQW_Point_Earning_Answer__c = pointEarningAnswer;
        question.LQW_Is_Dealbreaker__c = isDealbreaker;
        question.LQW_Dealbreaker_Value__c = dealbreakerValue;
        question.LQW_Is_Active__c = true;
        return question;
    }

    /**
     * @description Helper method to map Question SObject to wrapper class
     * @param question The question SObject
     * @return QuestionData The wrapper class instance
     */
    private static QuestionData mapQuestionToWrapper(LQW_Qualification_Question__c question) {
        QuestionData qData = new QuestionData();
        qData.questionId = question.Id;
        qData.questionNumber = question.Name;
        qData.questionText = question.LQW_Question_Text__c;
        qData.questionOrder = question.LQW_Question_Order__c != null ?
            Integer.valueOf(question.LQW_Question_Order__c) : null;
        qData.scoreValue = question.LQW_Score_Value__c != null ?
            Integer.valueOf(question.LQW_Score_Value__c) : 1;
        qData.pointEarningAnswer = String.isNotBlank(question.LQW_Point_Earning_Answer__c) ?
            question.LQW_Point_Earning_Answer__c : 'Both';
        qData.isDealbreaker = question.LQW_Is_Dealbreaker__c;
        qData.dealbreakerValue = question.LQW_Dealbreaker_Value__c;
        qData.isActive = question.LQW_Is_Active__c;
        return qData;
    }
}
