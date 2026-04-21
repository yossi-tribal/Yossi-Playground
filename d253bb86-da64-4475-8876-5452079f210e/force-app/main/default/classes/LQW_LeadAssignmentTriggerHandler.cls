/**
 * @description Trigger handler for Lead question list assignment
 * Contains code-driven criteria evaluation logic per list (editable via Tribal)
 * Auto-syncs Assignment_Criteria__c JSON after evaluation
 * Handles default fallback via Is_Default__c
 * Auto-creates example list with sample questions on first run
 *
 * Security note: All SOQL/DML in this handler runs in SYSTEM_MODE on purpose.
 * Auto-assignment of a Question List must succeed regardless of the triggering
 * user's FLS/CRUD on LQW_* objects. A partner or portal user creating a Lead
 * typically has no access to the admin objects; the trigger still needs to
 * assign a list so downstream scoring works. The user's own CRUD on Lead is
 * already enforced by the platform when they insert/update the Lead record.
 */
public with sharing class LQW_LeadAssignmentTriggerHandler {

    private static Boolean hasAutoCreatedExample = false;

    /**
     * @description Main handler method for after insert/update events
     * @param newLeads List of new/updated Lead records
     * @param oldLeadMap Map of old Lead records (null on insert)
     */
    public void handleAfterInsertUpdate(List<Lead> newLeads, Map<Id, Lead> oldLeadMap) {
        try {
            // Auto-create example list if no lists exist (one-time operation)
            ensureExampleListExists();

            // Get all active question lists with criteria fields
            List<LQW_Question_List__c> questionLists = [
                SELECT Id, Name, LQW_List_Name__c, LQW_Is_Active__c,
                       LQW_Assignment_Criteria__c, LQW_Is_Default__c
                FROM LQW_Question_List__c
                WHERE LQW_Is_Active__c = true
                WITH SYSTEM_MODE
                ORDER BY LQW_Is_Default__c ASC, Name ASC
            ];

            if (questionLists.isEmpty()) {
                return; // No question lists available
            }

            // Find the default list (fallback)
            Id defaultListId = null;
            for (LQW_Question_List__c questionList : questionLists) {
                if (questionList.LQW_Is_Default__c == true) {
                    defaultListId = questionList.Id;
                    break;
                }
            }

            // Prepare leads to update
            List<Lead> leadsToUpdate = new List<Lead>();

            for (Lead newLead : newLeads) {
                // Only process if question list is not already assigned or lead fields changed
                Lead oldLead = oldLeadMap != null ? oldLeadMap.get(newLead.Id) : null;

                if (shouldEvaluateLead(newLead, oldLead)) {
                    Id assignedListId = evaluateLeadCriteria(newLead, questionLists);

                    // If no match found, use default list
                    if (assignedListId == null && defaultListId != null) {
                        assignedListId = defaultListId;
                    }

                    // Only update if assignment changed
                    if (assignedListId != null && assignedListId != newLead.LQW_Question_List__c) {
                        Lead leadToUpdate = new Lead(Id = newLead.Id);
                        leadToUpdate.LQW_Question_List__c = assignedListId;
                        leadsToUpdate.add(leadToUpdate);
                    }
                }
            }

            // Update leads with new assignments
            if (!leadsToUpdate.isEmpty()) {
                update as system leadsToUpdate;
            }

            // Auto-sync Assignment_Criteria__c JSON for all lists
            syncAssignmentCriteriaJSON(questionLists);

        } catch (Exception e) {
            System.debug('Error in LeadAssignmentTriggerHandler: ' + e.getMessage());
            // Continue execution - don't block lead creation/update
        }
    }

    /**
     * @description Determines if lead should be evaluated for question list assignment
     * @param newLead The new/updated lead
     * @param oldLead The old lead (null on insert)
     * @return Boolean True if lead should be evaluated
     */
    private Boolean shouldEvaluateLead(Lead newLead, Lead oldLead) {
        // Always evaluate on insert
        if (oldLead == null) {
            return true;
        }

        // Evaluate on update if relevant fields changed
        // Check if LeadSource, Company, Industry, or other criteria fields changed
        return (
            newLead.LeadSource != oldLead.LeadSource ||
            newLead.Company != oldLead.Company ||
            newLead.Industry != oldLead.Industry ||
            newLead.Status != oldLead.Status ||
            newLead.Rating != oldLead.Rating ||
            newLead.AnnualRevenue != oldLead.AnnualRevenue ||
            newLead.NumberOfEmployees != oldLead.NumberOfEmployees
        );
    }

    /**
     * @description Evaluates lead against all question list criteria
     * CODE-DRIVEN CRITERIA LOGIC - EDITABLE VIA TRIBAL
     * @param lead The lead to evaluate
     * @param questionLists All active question lists
     * @return Id The ID of the first matching question list, or null if no match
     */
    private Id evaluateLeadCriteria(Lead lead, List<LQW_Question_List__c> questionLists) {
        // EXAMPLE CRITERIA LOGIC - MODIFY THIS CODE IN TRIBAL TO CHANGE ASSIGNMENT RULES

        for (LQW_Question_List__c questionList : questionLists) {
            // Skip default list in criteria evaluation (it's the fallback)
            if (questionList.LQW_Is_Default__c == true) {
                continue;
            }

            // EXAMPLE: Assign "Enterprise Leads" list to Web leads
            if (questionList.LQW_List_Name__c == 'Enterprise Leads') {
                if (lead.LeadSource == 'Web') {
                    return questionList.Id;
                }
            }

            // EXAMPLE: Assign "Partner Leads" list to Partner Channel leads
            if (questionList.LQW_List_Name__c == 'Partner Leads') {
                if (lead.LeadSource == 'Partner Referral') {
                    return questionList.Id;
                }
            }

            // ADD MORE CRITERIA RULES HERE AS NEEDED
            // Each if block should:
            // 1. Check the list name
            // 2. Evaluate lead fields against conditions
            // 3. Return questionList.Id if match found
        }

        return null; // No match found
    }

    /**
     * @description Auto-syncs Assignment_Criteria__c JSON based on code evaluation
     * Parses the evaluateLeadCriteria method to extract criteria and store as JSON
     * @param questionLists All active question lists
     */
    private void syncAssignmentCriteriaJSON(List<LQW_Question_List__c> questionLists) {
        List<LQW_Question_List__c> listsToUpdate = new List<LQW_Question_List__c>();

        for (LQW_Question_List__c questionList : questionLists) {
            String criteriaJSON = generateCriteriaJSON(questionList);

            // Only update if criteria changed
            if (criteriaJSON != questionList.LQW_Assignment_Criteria__c) {
                LQW_Question_List__c listToUpdate = new LQW_Question_List__c(Id = questionList.Id);
                listToUpdate.LQW_Assignment_Criteria__c = criteriaJSON;
                listsToUpdate.add(listToUpdate);
            }
        }

        if (!listsToUpdate.isEmpty()) {
            update as system listsToUpdate;
        }
    }

    /**
     * @description Generates JSON representation of criteria for a question list
     * Matches the criteria logic in evaluateLeadCriteria method
     * @param questionList The question list
     * @return String JSON array of criteria objects
     */
    private String generateCriteriaJSON(LQW_Question_List__c questionList) {
        List<Map<String, String>> criteria = new List<Map<String, String>>();

        // SYNC THIS WITH evaluateLeadCriteria METHOD
        // Generate JSON matching the code-driven criteria

        if (questionList.LQW_List_Name__c == 'Enterprise Leads') {
            criteria.add(new Map<String, String>{
                'field' => 'LeadSource',
                'label' => 'Lead Source',
                'operator' => 'equals',
                'value' => 'Web'
            });
        }

        if (questionList.LQW_List_Name__c == 'Partner Leads') {
            criteria.add(new Map<String, String>{
                'field' => 'LeadSource',
                'label' => 'Lead Source',
                'operator' => 'equals',
                'value' => 'Partner Referral'
            });
        }

        // ADD MORE CRITERIA JSON GENERATION HERE TO MATCH evaluateLeadCriteria

        return criteria.isEmpty() ? null : JSON.serialize(criteria);
    }

    /**
     * @description Ensures an example question list exists
     * Auto-creates "General Qualification" list with sample questions on first run
     */
    private void ensureExampleListExists() {
        // Prevent infinite recursion and only run once per transaction
        if (hasAutoCreatedExample) {
            return;
        }
        hasAutoCreatedExample = true;

        // Check if any question lists exist
        Integer listCount = [SELECT COUNT() FROM LQW_Question_List__c WITH SYSTEM_MODE LIMIT 1];

        if (listCount == 0) {
            // Create example question list
            LQW_Question_List__c exampleList = new LQW_Question_List__c();
            exampleList.LQW_List_Name__c = 'General Qualification';
            exampleList.LQW_Description__c = 'Default qualification questions for all leads';
            exampleList.LQW_Is_Active__c = true;
            exampleList.LQW_Is_Default__c = true; // Mark as default
            exampleList.LQW_High_Quality_Threshold__c = 5;
            exampleList.LQW_Medium_Quality_Threshold__c = 3;
            exampleList.LQW_High_Quality_Label__c = 'High Quality';
            exampleList.LQW_Medium_Quality_Label__c = 'Medium Quality';
            exampleList.LQW_Low_Quality_Label__c = 'Low Quality';
            exampleList.LQW_High_Quality_Recommendation__c = 'Convert to Opportunity';
            exampleList.LQW_Medium_Quality_Recommendation__c = 'Convert to Opportunity with Manager Review';
            exampleList.LQW_Low_Quality_Recommendation__c = 'Nurture Lead (Do Not Convert)';
            insert as system exampleList;

            // Create example questions
            List<LQW_Qualification_Question__c> exampleQuestions = new List<LQW_Qualification_Question__c>();

            // Question 1: Dealbreaker - Low purchasing volume
            exampleQuestions.add(createExampleQuestion(
                exampleList.Id,
                'Is the customer purchasing volume lower than $25K annually?',
                1, 1, 'No', true, 'Yes'
            ));

            // Question 2: Dealbreaker - Contracts
            exampleQuestions.add(createExampleQuestion(
                exampleList.Id,
                'Are they under any contracts that would prevent them from doing business with us?',
                2, 1, 'No', true, 'Yes'
            ));

            // Question 3: Competitive product
            exampleQuestions.add(createExampleQuestion(
                exampleList.Id,
                'Is the customer using a competitive product or a product we can upgrade?',
                3, 1, 'Yes', false, null
            ));

            // Question 4: Multiple categories
            exampleQuestions.add(createExampleQuestion(
                exampleList.Id,
                'Does the customer purchases across more than one of our categories?',
                4, 1, 'Yes', false, null
            ));

            // Question 5: Compelling event
            exampleQuestions.add(createExampleQuestion(
                exampleList.Id,
                'Is there a compelling event or reason to act within a reasonable window (e.g., 3–6 months)?',
                5, 1, 'Yes', false, null
            ));

            // Question 6: Solution fit
            exampleQuestions.add(createExampleQuestion(
                exampleList.Id,
                'Does our solution address the core need without significant gaps?',
                6, 1, 'Yes', false, null
            ));

            // Question 7: Delivery capability
            exampleQuestions.add(createExampleQuestion(
                exampleList.Id,
                'Can we deliver within their required timeframe and scope?',
                7, 1, 'Yes', false, null
            ));

            // Question 8: Budget
            exampleQuestions.add(createExampleQuestion(
                exampleList.Id,
                'Does the lead have budget already allocated OR a viable path to obtain budget?',
                8, 1, 'Yes', false, null
            ));

            // Question 9: Decision maker
            exampleQuestions.add(createExampleQuestion(
                exampleList.Id,
                'Have you identified the decision maker or someone directly involved in the decision?',
                9, 1, 'Yes', false, null
            ));

            insert as system exampleQuestions;
        }
    }

    /**
     * @description Helper method to create an example qualification question
     * @param listId The question list ID
     * @param questionText The question text
     * @param order The question order
     * @param scoreValue The point value
     * @param pointEarningAnswer Which answer earns points
     * @param isDealbreaker Whether this is a dealbreaker
     * @param dealbreakerValue The dealbreaker value
     * @return LQW_Qualification_Question__c The created question
     */
    private LQW_Qualification_Question__c createExampleQuestion(
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
}
