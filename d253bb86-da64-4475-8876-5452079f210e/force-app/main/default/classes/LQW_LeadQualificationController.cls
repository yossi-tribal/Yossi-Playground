/**
 * @description Apex controller for the Lead Qualification Wizard LWC
 * Provides methods to retrieve qualification questions and responses, save/delete responses
 * with dealbreaker validation, calculate lead quality scores and rankings, manage lead status
 * updates for auto-disqualification and restoration, and handle status marker storage in Lead Description field.
 * Includes comprehensive error handling, security validation, and transaction safety.
 */
public with sharing class LQW_LeadQualificationController {

    private static final String STATUS_MARKER_PREFIX = '[PREV_STATUS:';
    private static final String STATUS_MARKER_SUFFIX = ']';
    private static final String DISQUALIFIED_STATUS = 'Disqualified';
    private static final String DEFAULT_STATUS = 'Open - Not Contacted';

    // Canonical picklist API values for Lead.LQW_Lead_Quality__c.
    // These are the stable, restricted-picklist fullName values stored on the field.
    // Display labels (potentially admin-customized per Question List) are tracked separately
    // in QualificationSummary.leadRank and the per-list label fields.
    public static final String CODE_HIGH_QUALITY = 'High_Quality';
    public static final String CODE_MEDIUM_QUALITY = 'Medium_Quality';
    public static final String CODE_LOW_QUALITY = 'Low_Quality';
    public static final String CODE_DISQUALIFIED = 'DISQUALIFIED';

    /**
     * @description Wrapper class for question data with response state
     */
    public class QuestionData {
        @AuraEnabled public String questionId;
        @AuraEnabled public String questionText;
        @AuraEnabled public Integer questionOrder;
        @AuraEnabled public Boolean isDealbreaker;
        @AuraEnabled public String dealbreakerValue;
        @AuraEnabled public Integer scoreValue;
        @AuraEnabled public String pointEarningAnswer;
        @AuraEnabled public String currentResponse;
        @AuraEnabled public String responseId;

        public QuestionData() {
            this.scoreValue = 1;
            this.isDealbreaker = false;
            this.pointEarningAnswer = 'Both';
        }
    }

    /**
     * @description Wrapper class for complete qualification overview
     */
    public class QualificationSummary {
        @AuraEnabled public List<QuestionData> questions;
        @AuraEnabled public Integer totalScore;
        @AuraEnabled public String leadRank;
        // Canonical picklist API value written to Lead.LQW_Lead_Quality__c.
        // Stays stable regardless of per-list label customization.
        @AuraEnabled public String leadQualityCode;
        @AuraEnabled public String leadStatus;
        @AuraEnabled public Boolean isDisqualified;
        @AuraEnabled public String disqualificationReason;
        @AuraEnabled public Integer answeredCount;
        @AuraEnabled public Integer totalQuestions;
        @AuraEnabled public String questionListId;
        @AuraEnabled public String questionListName;
        @AuraEnabled public Integer previousResponseCount;
        @AuraEnabled public String highQualityLabel;
        @AuraEnabled public String mediumQualityLabel;
        @AuraEnabled public String lowQualityLabel;
        @AuraEnabled public String highQualityRecommendation;
        @AuraEnabled public String mediumQualityRecommendation;
        @AuraEnabled public String lowQualityRecommendation;

        public QualificationSummary() {
            this.questions = new List<QuestionData>();
            this.totalScore = 0;
            this.answeredCount = 0;
            this.totalQuestions = 0;
            this.isDisqualified = false;
            this.previousResponseCount = 0;
            this.highQualityLabel = 'High Quality';
            this.mediumQualityLabel = 'Medium Quality';
            this.lowQualityLabel = 'Low Quality';
            this.highQualityRecommendation = 'Convert to Opportunity';
            this.mediumQualityRecommendation = 'Convert to Opportunity with Manager Review';
            this.lowQualityRecommendation = 'Nurture Lead (Do Not Convert)';
        }
    }

    /**
     * @description Wrapper class for save operation results
     */
    public class ResponseSaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Boolean wasDisqualified;
        @AuraEnabled public Boolean wasRestored;
        @AuraEnabled public String newLeadStatus;
        @AuraEnabled public QualificationSummary updatedSummary;

        public ResponseSaveResult() {
            this.success = false;
            this.wasDisqualified = false;
            this.wasRestored = false;
        }
    }

    /**
     * @description Wrapper class for response history grouped by question list
     */
    public class ResponseHistoryGroup {
        @AuraEnabled public String questionListId;
        @AuraEnabled public String questionListName;
        @AuraEnabled public String earliestDate;
        @AuraEnabled public String latestDate;
        @AuraEnabled public List<HistoricalResponse> responses;

        public ResponseHistoryGroup() {
            this.responses = new List<HistoricalResponse>();
        }
    }

    /**
     * @description Wrapper class for individual historical response
     */
    public class HistoricalResponse {
        @AuraEnabled public String questionText;
        @AuraEnabled public String response;
        @AuraEnabled public String responseDate;
        @AuraEnabled public Boolean isDealbreaker;

        public HistoricalResponse() {
            this.isDealbreaker = false;
        }
    }

    /**
     * @description Retrieves complete qualification data for a lead
     * @param leadId The ID of the lead record
     * @return QualificationSummary Complete qualification state including questions, responses, and scoring
     */
    @AuraEnabled(cacheable=false)
    public static QualificationSummary getLeadQualificationData(Id leadId) {
        try {
            QualificationSummary summary = new QualificationSummary();

            if (leadId == null) {
                throw new AuraHandledException('You do not have access to this lead record.');
            }

            // Single list query avoids "no rows" exceptions and maps missing leads to the same access message
            List<Lead> leadRecords = [
                SELECT Id, Status, Description, LQW_Question_List__c,
                       LQW_Question_List__r.LQW_List_Name__c,
                       LQW_Question_List__r.LQW_High_Quality_Threshold__c,
                       LQW_Question_List__r.LQW_Medium_Quality_Threshold__c,
                       LQW_Question_List__r.LQW_High_Quality_Label__c,
                       LQW_Question_List__r.LQW_Medium_Quality_Label__c,
                       LQW_Question_List__r.LQW_Low_Quality_Label__c,
                       LQW_Question_List__r.LQW_High_Quality_Recommendation__c,
                       LQW_Question_List__r.LQW_Medium_Quality_Recommendation__c,
                       LQW_Question_List__r.LQW_Low_Quality_Recommendation__c
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];
            if (leadRecords.isEmpty()) {
                throw new AuraHandledException('You do not have access to this lead record.');
            }
            Lead lead = leadRecords[0];
            summary.leadStatus = lead.Status;
            summary.isDisqualified = (lead.Status == DISQUALIFIED_STATUS);

            // If Lead has no question list assigned, fallback to the default question list
            Id effectiveQuestionListId = lead.LQW_Question_List__c;
            LQW_Question_List__c effectiveQuestionList = null;

            if (effectiveQuestionListId != null) {
                // Lead has an explicit question list assignment
                effectiveQuestionList = lead.LQW_Question_List__r;
                summary.questionListId = effectiveQuestionListId;
                summary.questionListName = lead.LQW_Question_List__r?.LQW_List_Name__c;
            } else {
                // Fallback to default question list if no explicit assignment
                List<LQW_Question_List__c> defaultLists = [
                    SELECT Id, Name, LQW_List_Name__c,
                           LQW_High_Quality_Threshold__c, LQW_Medium_Quality_Threshold__c,
                           LQW_High_Quality_Label__c, LQW_Medium_Quality_Label__c, LQW_Low_Quality_Label__c,
                           LQW_High_Quality_Recommendation__c, LQW_Medium_Quality_Recommendation__c, LQW_Low_Quality_Recommendation__c
                    FROM LQW_Question_List__c
                    WHERE LQW_Is_Active__c = true
                    AND LQW_Is_Default__c = true
                    ORDER BY Name ASC
                    LIMIT 1
                ];

                if (!defaultLists.isEmpty()) {
                    effectiveQuestionList = defaultLists[0];
                    effectiveQuestionListId = effectiveQuestionList.Id;
                    summary.questionListId = effectiveQuestionListId;
                    summary.questionListName = effectiveQuestionList.LQW_List_Name__c;
                }
            }

            // Populate threshold and label fields from effective question list
            if (effectiveQuestionList != null) {
                summary.highQualityLabel = String.isNotBlank(effectiveQuestionList.LQW_High_Quality_Label__c) ?
                    effectiveQuestionList.LQW_High_Quality_Label__c : 'High Quality';
                summary.mediumQualityLabel = String.isNotBlank(effectiveQuestionList.LQW_Medium_Quality_Label__c) ?
                    effectiveQuestionList.LQW_Medium_Quality_Label__c : 'Medium Quality';
                summary.lowQualityLabel = String.isNotBlank(effectiveQuestionList.LQW_Low_Quality_Label__c) ?
                    effectiveQuestionList.LQW_Low_Quality_Label__c : 'Low Quality';
                summary.highQualityRecommendation = String.isNotBlank(effectiveQuestionList.LQW_High_Quality_Recommendation__c) ?
                    effectiveQuestionList.LQW_High_Quality_Recommendation__c : 'Convert to Opportunity';
                summary.mediumQualityRecommendation = String.isNotBlank(effectiveQuestionList.LQW_Medium_Quality_Recommendation__c) ?
                    effectiveQuestionList.LQW_Medium_Quality_Recommendation__c : 'Convert to Opportunity with Manager Review';
                summary.lowQualityRecommendation = String.isNotBlank(effectiveQuestionList.LQW_Low_Quality_Recommendation__c) ?
                    effectiveQuestionList.LQW_Low_Quality_Recommendation__c : 'Nurture Lead (Do Not Convert)';
            }

            // Count previous responses from different question lists
            if (lead.LQW_Question_List__c != null) {
                List<AggregateResult> previousResponsesCount = [
                    SELECT COUNT(Id) responseCount
                    FROM LQW_Lead_Question_Response__c
                    WHERE LQW_Lead__c = :leadId
                    AND LQW_Question_List__c != null
                    AND LQW_Question_List__c != :lead.LQW_Question_List__c
                ];
                if (!previousResponsesCount.isEmpty()) {
                    summary.previousResponseCount = Integer.valueOf(previousResponsesCount[0].get('responseCount'));
                }
            }

            // Get active questions filtered by effective question list
            List<LQW_Qualification_Question__c> questions;
            if (effectiveQuestionListId != null) {
                questions = [
                    SELECT Id, Name, LQW_Question_Text__c, LQW_Question_Order__c,
                           LQW_Is_Dealbreaker__c, LQW_Dealbreaker_Value__c, LQW_Score_Value__c,
                           LQW_Point_Earning_Answer__c
                    FROM LQW_Qualification_Question__c
                    WHERE LQW_Is_Active__c = true
                    AND LQW_Question_List__c = :effectiveQuestionListId
                    ORDER BY LQW_Question_Order__c ASC NULLS LAST, Name ASC
                ];
            } else {
                // No question list available - return empty list
                questions = new List<LQW_Qualification_Question__c>();
            }

            summary.totalQuestions = questions.size();

            // Get existing responses for this lead
            Map<Id, LQW_Lead_Question_Response__c> responseMap = new Map<Id, LQW_Lead_Question_Response__c>();
            List<LQW_Lead_Question_Response__c> responses = [
                SELECT Id, LQW_Question__c, LQW_Response__c
                FROM LQW_Lead_Question_Response__c
                WHERE LQW_Lead__c = :leadId
            ];

            for (LQW_Lead_Question_Response__c response : responses) {
                responseMap.put(response.LQW_Question__c, response);
            }

            // Build question data with responses
            Integer totalScore = 0;
            Integer answeredCount = 0;

            for (LQW_Qualification_Question__c question : questions) {
                QuestionData qData = new QuestionData();
                qData.questionId = question.Id;
                qData.questionText = question.LQW_Question_Text__c;
                qData.questionOrder = question.LQW_Question_Order__c != null ?
                    Integer.valueOf(question.LQW_Question_Order__c) : null;
                qData.isDealbreaker = question.LQW_Is_Dealbreaker__c;
                qData.dealbreakerValue = question.LQW_Dealbreaker_Value__c;
                qData.scoreValue = question.LQW_Score_Value__c != null ?
                    Integer.valueOf(question.LQW_Score_Value__c) : 1;
                qData.pointEarningAnswer = String.isNotBlank(question.LQW_Point_Earning_Answer__c) ?
                    question.LQW_Point_Earning_Answer__c : 'Both';

                // Check for existing response
                if (responseMap.containsKey(question.Id)) {
                    LQW_Lead_Question_Response__c response = responseMap.get(question.Id);
                    qData.currentResponse = response.LQW_Response__c;
                    qData.responseId = response.Id;

                    if (String.isNotBlank(response.LQW_Response__c)) {
                        answeredCount++;

                        // Check if this is a dealbreaker answer (never earns points)
                        Boolean isDealbreaker = qData.isDealbreaker &&
                                               response.LQW_Response__c == qData.dealbreakerValue;

                        // Check if response matches the point-earning answer configuration
                        Boolean earnsPoints = false;
                        if (!isDealbreaker) {
                            if (qData.pointEarningAnswer == 'Both') {
                                earnsPoints = true; // Both answers earn points
                            } else if (qData.pointEarningAnswer == response.LQW_Response__c) {
                                earnsPoints = true; // Response matches configured point-earning answer
                            }
                        }

                        if (earnsPoints) {
                            totalScore += qData.scoreValue;
                        }
                    }
                }

                summary.questions.add(qData);
            }

            summary.totalScore = totalScore;
            summary.answeredCount = answeredCount;

            // Calculate lead rank using dynamic thresholds from question list
            Decimal highThreshold = lead.LQW_Question_List__r?.LQW_High_Quality_Threshold__c != null ?
                lead.LQW_Question_List__r.LQW_High_Quality_Threshold__c : 5;
            Decimal mediumThreshold = lead.LQW_Question_List__r?.LQW_Medium_Quality_Threshold__c != null ?
                lead.LQW_Question_List__r.LQW_Medium_Quality_Threshold__c : 3;

            summary.leadRank = calculateLeadRank(totalScore, summary.isDisqualified, highThreshold, mediumThreshold,
                summary.highQualityLabel, summary.mediumQualityLabel, summary.lowQualityLabel);
            summary.leadQualityCode = calculateLeadQualityCode(totalScore, summary.isDisqualified,
                highThreshold, mediumThreshold);

            // Extract disqualification reason if applicable
            if (summary.isDisqualified) {
                summary.disqualificationReason = extractDisqualificationReason(summary.questions, responseMap);
            }

            return summary;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving qualification data: ' + e.getMessage());
        }
    }

    /**
     * @description Saves or deletes a question response and handles dealbreaker logic
     * @param leadId The ID of the lead record
     * @param questionId The ID of the question being answered
     * @param response The response value (Yes/No) or null to delete
     * @return ResponseSaveResult Result of the save operation including updated summary
     */
    @AuraEnabled(cacheable=false)
    public static ResponseSaveResult saveQuestionResponse(Id leadId, Id questionId, String response) {
        ResponseSaveResult result = new ResponseSaveResult();

        try {
            // Validate lead access
            if (!isLeadAccessible(leadId)) {
                result.message = 'You do not have access to this lead record.';
                return result;
            }

            // Get question details
            LQW_Qualification_Question__c question = [
                SELECT Id, LQW_Is_Dealbreaker__c, LQW_Dealbreaker_Value__c, LQW_Question_Text__c
                FROM LQW_Qualification_Question__c
                WHERE Id = :questionId
                LIMIT 1
            ];

            // Get existing response if any
            List<LQW_Lead_Question_Response__c> existingResponses = [
                SELECT Id, LQW_Response__c
                FROM LQW_Lead_Question_Response__c
                WHERE LQW_Lead__c = :leadId AND LQW_Question__c = :questionId
                LIMIT 1
            ];

            Boolean hadDealbreakerResponse = false;
            if (!existingResponses.isEmpty() && question.LQW_Is_Dealbreaker__c) {
                String existingResponse = existingResponses[0].LQW_Response__c;
                hadDealbreakerResponse = (existingResponse == question.LQW_Dealbreaker_Value__c);
            }

            // Check if new response triggers dealbreaker
            Boolean triggersDisqualification = false;
            if (String.isNotBlank(response) && question.LQW_Is_Dealbreaker__c) {
                triggersDisqualification = (response == question.LQW_Dealbreaker_Value__c);
            }

            // Get lead's current question list for snapshot
            Lead leadForQuestionList = [SELECT Id, LQW_Question_List__c FROM Lead WHERE Id = :leadId LIMIT 1];

            // Handle response save/delete
            if (String.isBlank(response)) {
                // Delete response (toggle off)
                if (!existingResponses.isEmpty()) {
                    delete existingResponses[0];
                }
            } else {
                // Save or update response
                LQW_Lead_Question_Response__c responseRecord;

                if (!existingResponses.isEmpty()) {
                    responseRecord = existingResponses[0];
                    responseRecord.LQW_Response__c = response;
                    responseRecord.LQW_Last_Modified_Date__c = System.now();
                    // Update question list snapshot if changed
                    if (leadForQuestionList.LQW_Question_List__c != null) {
                        responseRecord.LQW_Question_List__c = leadForQuestionList.LQW_Question_List__c;
                    }
                } else {
                    responseRecord = new LQW_Lead_Question_Response__c();
                    responseRecord.LQW_Lead__c = leadId;
                    responseRecord.LQW_Question__c = questionId;
                    responseRecord.LQW_Response__c = response;
                    responseRecord.LQW_Response_Date__c = System.now();
                    responseRecord.LQW_Last_Modified_Date__c = System.now();
                    // Store question list snapshot
                    if (leadForQuestionList.LQW_Question_List__c != null) {
                        responseRecord.LQW_Question_List__c = leadForQuestionList.LQW_Question_List__c;
                    }
                }

                upsert responseRecord;
            }

            // Handle lead status changes
            Lead lead = [SELECT Id, Status, Description, LQW_Lead_Quality__c FROM Lead WHERE Id = :leadId LIMIT 1];
            Boolean needsStatusUpdate = false;

            if (triggersDisqualification && lead.Status != DISQUALIFIED_STATUS) {
                // Store previous status and disqualify
                storePreviousStatus(lead);
                lead.Status = DISQUALIFIED_STATUS;
                needsStatusUpdate = true;
                result.wasDisqualified = true;
                result.message = 'Lead automatically disqualified due to dealbreaker response.';
            } else if (hadDealbreakerResponse && !triggersDisqualification && lead.Status == DISQUALIFIED_STATUS) {
                // Restore previous status if dealbreaker was removed/changed
                Boolean canRestore = canRestoreLeadStatus(leadId, questionId);
                if (canRestore) {
                    restorePreviousStatus(lead);
                    needsStatusUpdate = true;
                    result.wasRestored = true;
                    result.message = 'Lead status restored after dealbreaker removal.';
                }
            }

            // Persist status/description first so getLeadQualificationData reads current Lead.Status from the DB
            if (needsStatusUpdate) {
                Lead statusPatch = new Lead(Id = lead.Id, Status = lead.Status, Description = lead.Description);
                update statusPatch;
            }

            QualificationSummary tempSummary = getLeadQualificationData(leadId);
            update new Lead(Id = leadId, LQW_Lead_Quality__c = tempSummary.leadQualityCode);

            if (needsStatusUpdate) {
                result.newLeadStatus = tempSummary.leadStatus;
            }

            // Get updated qualification summary
            result.updatedSummary = getLeadQualificationData(leadId);
            result.success = true;

            if (String.isBlank(result.message)) {
                result.message = 'Response saved successfully.';
            }

            return result;

        } catch (Exception e) {
            result.message = 'Error saving response: ' + e.getMessage();
            return result;
        }
    }

    /**
     * @description Calculates lead rank based on total score, disqualification status, and dynamic thresholds
     * @param totalScore The total qualification score
     * @param isDisqualified Whether the lead is disqualified
     * @param highThreshold Minimum points for High Quality tier
     * @param mediumThreshold Minimum points for Medium Quality tier
     * @param highLabel Label for High Quality tier
     * @param mediumLabel Label for Medium Quality tier
     * @param lowLabel Label for Low Quality tier
     * @return String Lead rank using dynamic labels
     */
    private static String calculateLeadRank(Integer totalScore, Boolean isDisqualified,
                                           Decimal highThreshold, Decimal mediumThreshold,
                                           String highLabel, String mediumLabel, String lowLabel) {
        if (isDisqualified) {
            return 'Disqualified';
        } else if (totalScore >= highThreshold) {
            return highLabel;
        } else if (totalScore >= mediumThreshold) {
            return mediumLabel;
        } else {
            return lowLabel;
        }
    }

    /**
     * @description Returns the canonical picklist API value for Lead.LQW_Lead_Quality__c.
     * Decoupled from calculateLeadRank so the picklist (restricted) stays valid even when
     * an admin sets custom display labels on a Question List.
     */
    private static String calculateLeadQualityCode(Integer totalScore, Boolean isDisqualified,
                                                  Decimal highThreshold, Decimal mediumThreshold) {
        if (isDisqualified) {
            return CODE_DISQUALIFIED;
        } else if (totalScore >= highThreshold) {
            return CODE_HIGH_QUALITY;
        } else if (totalScore >= mediumThreshold) {
            return CODE_MEDIUM_QUALITY;
        } else {
            return CODE_LOW_QUALITY;
        }
    }

    /**
     * @description Checks if current user has access to the lead record
     * @param leadId The ID of the lead record
     * @return Boolean True if user has access, false otherwise
     */
    private static Boolean isLeadAccessible(Id leadId) {
        try {
            List<Lead> leads = [SELECT Id FROM Lead WHERE Id = :leadId LIMIT 1];
            return !leads.isEmpty();
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * @description Stores the current lead status in the Description field before disqualification
     * @param lead The lead record to update
     */
    private static void storePreviousStatus(Lead lead) {
        String currentStatus = lead.Status;
        String marker = STATUS_MARKER_PREFIX + currentStatus + STATUS_MARKER_SUFFIX;

        if (String.isBlank(lead.Description)) {
            lead.Description = marker;
        } else {
            // Remove any existing marker first
            lead.Description = removeStatusMarker(lead.Description);
            lead.Description = marker + ' ' + lead.Description;
        }
    }

    /**
     * @description Restores the previous lead status from the Description field
     * @param lead The lead record to update
     */
    private static void restorePreviousStatus(Lead lead) {
        String previousStatus = extractPreviousStatus(lead.Description);

        if (String.isNotBlank(previousStatus)) {
            lead.Status = previousStatus;
        } else {
            lead.Status = DEFAULT_STATUS;
        }

        // Clean up the marker from description
        if (String.isNotBlank(lead.Description)) {
            lead.Description = removeStatusMarker(lead.Description);
        }
    }

    /**
     * @description Extracts the previous status value from the Description field
     * @param description The lead description field value
     * @return String The previous status or null if not found
     */
    private static String extractPreviousStatus(String description) {
        if (String.isBlank(description)) {
            return null;
        }

        Integer startIndex = description.indexOf(STATUS_MARKER_PREFIX);
        if (startIndex == -1) {
            return null;
        }

        Integer endIndex = description.indexOf(STATUS_MARKER_SUFFIX, startIndex);
        if (endIndex == -1) {
            return null;
        }

        String statusValue = description.substring(
            startIndex + STATUS_MARKER_PREFIX.length(),
            endIndex
        );

        return String.isNotBlank(statusValue) ? statusValue.trim() : null;
    }

    /**
     * @description Removes the status marker from the description field
     * @param description The lead description field value
     * @return String The description with marker removed
     */
    private static String removeStatusMarker(String description) {
        if (String.isBlank(description)) {
            return description;
        }

        Integer startIndex = description.indexOf(STATUS_MARKER_PREFIX);
        if (startIndex == -1) {
            return description;
        }

        Integer endIndex = description.indexOf(STATUS_MARKER_SUFFIX, startIndex);
        if (endIndex == -1) {
            return description;
        }

        String result = description.substring(0, startIndex) +
                       description.substring(endIndex + STATUS_MARKER_SUFFIX.length());

        return result.trim();
    }

    /**
     * @description Checks if lead can be restored (no other active dealbreakers)
     * @param leadId The ID of the lead record
     * @param excludeQuestionId The question ID to exclude from check (the one being changed)
     * @return Boolean True if lead can be restored, false if other dealbreakers exist
     */
    private static Boolean canRestoreLeadStatus(Id leadId, Id excludeQuestionId) {
        // Get all dealbreaker questions
        List<LQW_Qualification_Question__c> dealbreakerQuestions = [
            SELECT Id, LQW_Dealbreaker_Value__c
            FROM LQW_Qualification_Question__c
            WHERE LQW_Is_Active__c = true
            AND LQW_Is_Dealbreaker__c = true
            AND Id != :excludeQuestionId
        ];

        if (dealbreakerQuestions.isEmpty()) {
            return true;
        }

        // Get all responses for this lead (excluding the one being changed)
        List<LQW_Lead_Question_Response__c> responses = [
            SELECT Id, LQW_Question__c, LQW_Response__c
            FROM LQW_Lead_Question_Response__c
            WHERE LQW_Lead__c = :leadId
            AND LQW_Question__c != :excludeQuestionId
        ];

        // Check if any other dealbreaker responses exist
        Map<Id, String> responseMap = new Map<Id, String>();
        for (LQW_Lead_Question_Response__c response : responses) {
            responseMap.put(response.LQW_Question__c, response.LQW_Response__c);
        }

        for (LQW_Qualification_Question__c question : dealbreakerQuestions) {
            if (responseMap.containsKey(question.Id)) {
                String response = responseMap.get(question.Id);
                if (response == question.LQW_Dealbreaker_Value__c) {
                    return false; // Another dealbreaker exists
                }
            }
        }

        return true;
    }

    /**
     * @description Extracts the disqualification reason based on dealbreaker responses
     * @param questions List of question data
     * @param responseMap Map of question ID to response record
     * @return String The disqualification reason or null
     */
    private static String extractDisqualificationReason(
        List<QuestionData> questions,
        Map<Id, LQW_Lead_Question_Response__c> responseMap
    ) {
        for (QuestionData qData : questions) {
            if (qData.isDealbreaker && responseMap.containsKey(qData.questionId)) {
                LQW_Lead_Question_Response__c response = responseMap.get(qData.questionId);
                if (response.LQW_Response__c == qData.dealbreakerValue) {
                    return 'Dealbreaker: ' + qData.questionText + ' (Answered: ' + response.LQW_Response__c + ')';
                }
            }
        }
        return null;
    }

    /**
     * @description Retrieves complete response history for a lead grouped by question list
     * @param leadId The ID of the lead record
     * @return List<ResponseHistoryGroup> Response history grouped by question list
     */
    @AuraEnabled(cacheable=false)
    public static List<ResponseHistoryGroup> getResponseHistory(Id leadId) {
        try {
            // Validate lead access
            if (!isLeadAccessible(leadId)) {
                throw new AuraHandledException('You do not have access to this lead record.');
            }

            // Get all responses for this lead with question and question list details
            List<LQW_Lead_Question_Response__c> responses = [
                SELECT Id, LQW_Response__c, LQW_Response_Date__c,
                       LQW_Question__r.LQW_Question_Text__c,
                       LQW_Question__r.LQW_Is_Dealbreaker__c,
                       LQW_Question__r.LQW_Dealbreaker_Value__c,
                       LQW_Question_List__c,
                       LQW_Question_List__r.LQW_List_Name__c
                FROM LQW_Lead_Question_Response__c
                WHERE LQW_Lead__c = :leadId
                AND LQW_Response__c != null
                ORDER BY LQW_Question_List__c, LQW_Response_Date__c ASC
            ];

            // Group responses by question list
            Map<String, ResponseHistoryGroup> groupMap = new Map<String, ResponseHistoryGroup>();

            for (LQW_Lead_Question_Response__c resp : responses) {
                Id questionListId = resp.LQW_Question_List__c;

                // Use a special key for responses without a question list
                String groupKey = questionListId != null ? String.valueOf(questionListId) : 'no_list';

                if (!groupMap.containsKey(groupKey)) {
                    ResponseHistoryGroup historyGroup = new ResponseHistoryGroup();
                    historyGroup.questionListId = questionListId;
                    historyGroup.questionListName = resp.LQW_Question_List__r?.LQW_List_Name__c;
                    if (historyGroup.questionListName == null) {
                        historyGroup.questionListName = 'Unassigned Question List';
                    }
                    groupMap.put(groupKey, historyGroup);
                }

                ResponseHistoryGroup historyGroup = groupMap.get(groupKey);

                // Create historical response
                HistoricalResponse histResp = new HistoricalResponse();
                histResp.questionText = resp.LQW_Question__r?.LQW_Question_Text__c;
                histResp.response = resp.LQW_Response__c;
                histResp.responseDate = resp.LQW_Response_Date__c != null ?
                    resp.LQW_Response_Date__c.format('MMM dd, yyyy h:mm a') : '';

                // Check if this was a dealbreaker response
                if (resp.LQW_Question__r?.LQW_Is_Dealbreaker__c == true &&
                    resp.LQW_Response__c == resp.LQW_Question__r?.LQW_Dealbreaker_Value__c) {
                    histResp.isDealbreaker = true;
                }

                historyGroup.responses.add(histResp);

                // Update date range
                String formattedDate = resp.LQW_Response_Date__c != null ?
                    resp.LQW_Response_Date__c.format('MMM dd, yyyy') : '';
                if (String.isBlank(historyGroup.earliestDate)) {
                    historyGroup.earliestDate = formattedDate;
                }
                historyGroup.latestDate = formattedDate;
            }

            return groupMap.values();

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving response history: ' + e.getMessage());
        }
    }
}
