/**
 * @description Trigger handler for Lead question list assignment.
 * Reads the declarative RULES table below to auto-assign the right
 * Question List to each new/updated Lead. Falls back to the list marked
 * Is_Default when no rule matches. Auto-seeds a starter list on first run.
 *
 * Security note: All SOQL/DML in this handler runs in SYSTEM_MODE on purpose.
 * Auto-assignment of a Question List must succeed regardless of the triggering
 * user's FLS/CRUD on LQW_* objects. A partner or portal user creating a Lead
 * typically has no access to the admin objects; the trigger still needs to
 * assign a list so downstream scoring works. The user's own CRUD on Lead is
 * already enforced by the platform when they insert/update the Lead record.
 */
public with sharing class LQW_LeadAssignmentTriggerHandler {

    // ─────────────────────────────────────────────────────────────────────
    // ASSIGNMENT RULES — HOW TO EDIT
    // ─────────────────────────────────────────────────────────────────────
    // Add, edit, or remove rows in the RULES list below to change how
    // leads are auto-assigned to Question Lists. Each rule targets one
    // Question List by its List Name (the LQW_List_Name__c field) and
    // carries one or more conditions. A rule matches when ALL its
    // conditions match the Lead. The first matching rule wins. If no
    // rule matches, the list marked Is_Default is used as the fallback.
    //
    // If a rule references a List Name that doesn't exist (or isn't
    // active) in the org, it's silently skipped. Renaming a Question
    // List in Setup also requires updating the rule.
    //
    // EXAMPLE — add this inside the RULES block to route tech leads
    // with revenue over $1M to a "High-Value Leads" list:
    //
    //     new AssignmentRule('High-Value Leads', new List<Condition>{
    //         new Condition('Industry',      'equals', 'Technology'),
    //         new Condition('AnnualRevenue', 'gt',     1000000)
    //     }),
    //
    // SUPPORTED OPERATORS (case-insensitive):
    //   equals, notEquals      — any field type
    //   contains, notContains  — text; case-insensitive substring match
    //   in, notIn              — value is a comma-separated list of options
    //   gt, lt, gte, lte       — numeric fields (Integer / Decimal / Currency)
    //   isBlank, isNotBlank    — ignores the value argument
    //   isTrue, isFalse        — checkbox fields; ignores the value argument
    // ─────────────────────────────────────────────────────────────────────
    @TestVisible
    private static List<AssignmentRule> RULES = new List<AssignmentRule>{
        new AssignmentRule('Enterprise Leads', new List<Condition>{
            new Condition('LeadSource', 'equals', 'Web')
        }),
        new AssignmentRule('Partner Leads', new List<Condition>{
            new Condition('LeadSource', 'equals', 'Partner Referral')
        })
        // ─── ADD MORE RULES ABOVE THIS LINE ───
    };

    // ─────────────────────────────────────────────────────────────────────
    // Inner classes. You generally don't need to edit these.
    // ─────────────────────────────────────────────────────────────────────

    public class AssignmentRule {
        public String listName;
        public List<Condition> conditions;
        public AssignmentRule(String listName, List<Condition> conditions) {
            this.listName = listName;
            this.conditions = (conditions != null) ? conditions : new List<Condition>();
        }
    }

    public class Condition {
        public String field;
        public String op;
        public Object value;
        public Condition(String field, String op, Object value) {
            this.field = field;
            this.op = op;
            this.value = value;
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Internals
    // ─────────────────────────────────────────────────────────────────────

    private static Boolean hasAutoCreatedExample = false;

    @TestVisible
    private static final String BYPASS_CUSTOM_PERMISSION = 'LQW_Bypass_Lead_Assignment';

    // Test-only override for the bypass check. See comment on isAssignmentBypassed().
    @TestVisible
    private static Boolean bypassOverrideForTest = null;

    /**
     * @description Main handler method for after insert/update events
     * @param newLeads List of new/updated Lead records
     * @param oldLeadMap Map of old Lead records (null on insert)
     */
    public void handleAfterInsertUpdate(List<Lead> newLeads, Map<Id, Lead> oldLeadMap) {
        try {
            // Opt-out: skip entirely if the current user holds the bypass
            // custom permission (e.g. data loader / integration user).
            if (isAssignmentBypassed()) {
                return;
            }

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
                return;
            }

            // Index lists by their List Name for O(1) rule lookup
            Map<String, LQW_Question_List__c> listsByName = new Map<String, LQW_Question_List__c>();
            Id defaultListId = null;
            for (LQW_Question_List__c ql : questionLists) {
                if (String.isNotBlank(ql.LQW_List_Name__c)) {
                    listsByName.put(ql.LQW_List_Name__c, ql);
                }
                if (ql.LQW_Is_Default__c == true && defaultListId == null) {
                    defaultListId = ql.Id;
                }
            }

            // Prepare leads to update
            List<Lead> leadsToUpdate = new List<Lead>();

            for (Lead newLead : newLeads) {
                Lead oldLead = (oldLeadMap != null) ? oldLeadMap.get(newLead.Id) : null;

                if (shouldEvaluateLead(newLead, oldLead)) {
                    Id assignedListId = evaluateLeadCriteria(newLead, listsByName);

                    if (assignedListId == null && defaultListId != null) {
                        assignedListId = defaultListId;
                    }

                    if (assignedListId != null && assignedListId != newLead.LQW_Question_List__c) {
                        leadsToUpdate.add(new Lead(
                            Id = newLead.Id,
                            LQW_Question_List__c = assignedListId
                        ));
                    }
                }
            }

            if (!leadsToUpdate.isEmpty()) {
                update as system leadsToUpdate;
            }

            // Keep Assignment_Criteria__c JSON in sync with the RULES table so
            // the admin UI and conflict detection have an accurate picture.
            syncAssignmentCriteriaJSON(questionLists);

        } catch (Exception e) {
            System.debug('Error in LeadAssignmentTriggerHandler: ' + e.getMessage());
            // Continue execution - don't block lead creation/update
        }
    }

    /**
     * @description Returns true when the current user holds the bypass custom
     * permission, or a test has explicitly set the override.
     */
    private static Boolean isAssignmentBypassed() {
        if (bypassOverrideForTest != null) {
            return bypassOverrideForTest;
        }
        return FeatureManagement.checkPermission(BYPASS_CUSTOM_PERMISSION);
    }

    /**
     * @description Evaluates the lead against the declarative RULES table.
     * Returns the Id of the first rule's target list that matches, or null.
     */
    private Id evaluateLeadCriteria(Lead lead, Map<String, LQW_Question_List__c> listsByName) {
        for (AssignmentRule rule : RULES) {
            LQW_Question_List__c ql = listsByName.get(rule.listName);
            if (ql == null || ql.LQW_Is_Default__c == true) {
                // Rule targets a list that doesn't exist / isn't active, or
                // the default list (which is handled as a fallback elsewhere).
                continue;
            }
            if (ruleMatches(lead, rule)) {
                return ql.Id;
            }
        }
        return null;
    }

    /**
     * @description A rule matches when ALL its conditions match. An empty
     * rule (no conditions) is treated as a non-match to avoid accidental
     * catch-alls — use Is_Default for that.
     */
    private static Boolean ruleMatches(Lead lead, AssignmentRule rule) {
        if (rule.conditions == null || rule.conditions.isEmpty()) {
            return false;
        }
        for (Condition c : rule.conditions) {
            if (!matchesCondition(lead, c)) {
                return false;
            }
        }
        return true;
    }

    /**
     * @description Evaluates one condition against the lead.
     * Resilient to missing fields and type mismatches — returns false rather
     * than throwing, so a rule typo never breaks lead DML.
     */
    private static Boolean matchesCondition(Lead lead, Condition c) {
        if (c == null || String.isBlank(c.field) || String.isBlank(c.op)) {
            return false;
        }

        Object leadVal;
        try {
            leadVal = lead.get(c.field);
        } catch (Exception e) {
            return false;
        }

        String op = c.op.toLowerCase();
        String leadStr = (leadVal == null) ? null : String.valueOf(leadVal);
        String ruleStr = (c.value == null) ? null : String.valueOf(c.value);

        if (op == 'isblank') {
            return String.isBlank(leadStr);
        }
        if (op == 'isnotblank') {
            return String.isNotBlank(leadStr);
        }
        if (op == 'istrue') {
            return leadVal == true;
        }
        if (op == 'isfalse') {
            return leadVal == false;
        }
        if (op == 'equals') {
            if (leadVal == null && c.value == null) return true;
            if (leadVal == null || c.value == null) return false;
            Decimal ln = tryDecimal(leadVal);
            Decimal rn = tryDecimal(c.value);
            if (ln != null && rn != null) return ln == rn;
            return leadStr == ruleStr;
        }
        if (op == 'notequals') {
            if (leadVal == null && c.value == null) return false;
            if (leadVal == null || c.value == null) return true;
            Decimal ln = tryDecimal(leadVal);
            Decimal rn = tryDecimal(c.value);
            if (ln != null && rn != null) return ln != rn;
            return leadStr != ruleStr;
        }
        if (op == 'contains') {
            if (leadStr == null || ruleStr == null) return false;
            return leadStr.toLowerCase().contains(ruleStr.toLowerCase());
        }
        if (op == 'notcontains') {
            if (leadStr == null) return true;
            if (ruleStr == null) return true;
            return !leadStr.toLowerCase().contains(ruleStr.toLowerCase());
        }
        if (op == 'in' || op == 'notin') {
            if (ruleStr == null) return op == 'notin';
            Boolean found = false;
            for (String item : ruleStr.split(',')) {
                if (leadStr != null && item.trim().equalsIgnoreCase(leadStr.trim())) {
                    found = true;
                    break;
                }
            }
            return (op == 'in') ? found : !found;
        }
        if (op == 'gt' || op == 'lt' || op == 'gte' || op == 'lte') {
            Decimal ln = tryDecimal(leadVal);
            Decimal rn = tryDecimal(c.value);
            if (ln == null || rn == null) return false;
            if (op == 'gt')  return ln > rn;
            if (op == 'lt')  return ln < rn;
            if (op == 'gte') return ln >= rn;
            if (op == 'lte') return ln <= rn;
        }

        return false;
    }

    private static Decimal tryDecimal(Object v) {
        if (v == null) return null;
        if (v instanceof Decimal) return (Decimal) v;
        if (v instanceof Integer) return Decimal.valueOf((Integer) v);
        if (v instanceof Long) return Decimal.valueOf((Long) v);
        if (v instanceof Double) return Decimal.valueOf(String.valueOf((Double) v));
        if (v instanceof String) {
            try {
                return Decimal.valueOf((String) v);
            } catch (Exception e) {
                return null;
            }
        }
        return null;
    }

    /**
     * @description Determines if lead should be evaluated.
     * On insert: always. On update: only when one of the Lead fields
     * referenced by the RULES table actually changed. Watched-field set is
     * derived from RULES, so adding a new rule automatically starts watching
     * its field(s) — no second list to maintain.
     */
    private Boolean shouldEvaluateLead(Lead newLead, Lead oldLead) {
        if (oldLead == null) {
            return true;
        }
        for (String f : getWatchedFields()) {
            Object newVal;
            Object oldVal;
            try {
                newVal = newLead.get(f);
                oldVal = oldLead.get(f);
            } catch (Exception e) {
                continue;
            }
            if (newVal != oldVal) {
                return true;
            }
        }
        return false;
    }

    private static Set<String> getWatchedFields() {
        Set<String> fields = new Set<String>();
        for (AssignmentRule rule : RULES) {
            for (Condition c : rule.conditions) {
                if (String.isNotBlank(c.field)) {
                    fields.add(c.field);
                }
            }
        }
        return fields;
    }

    /**
     * @description Serializes the RULES table into the JSON format stored on
     * LQW_Question_List__c.LQW_Assignment_Criteria__c. Only rules targeting a
     * list in the given list are emitted; the field is cleared for lists
     * with no matching rule.
     */
    private void syncAssignmentCriteriaJSON(List<LQW_Question_List__c> questionLists) {
        List<LQW_Question_List__c> listsToUpdate = new List<LQW_Question_List__c>();

        for (LQW_Question_List__c ql : questionLists) {
            String criteriaJSON = generateCriteriaJSON(ql);
            if (criteriaJSON != ql.LQW_Assignment_Criteria__c) {
                listsToUpdate.add(new LQW_Question_List__c(
                    Id = ql.Id,
                    LQW_Assignment_Criteria__c = criteriaJSON
                ));
            }
        }

        if (!listsToUpdate.isEmpty()) {
            update as system listsToUpdate;
        }
    }

    /**
     * @description Returns a JSON array of {field, label, operator, value}
     * objects from every rule whose listName matches the given list, or null
     * if there are no such rules. Matches the shape expected by
     * LQW_QuestionListManagerCtrl.detectCriteriaConflicts.
     */
    @TestVisible
    private static String generateCriteriaJSON(LQW_Question_List__c questionList) {
        if (String.isBlank(questionList.LQW_List_Name__c)) {
            return null;
        }
        List<Map<String, String>> out = new List<Map<String, String>>();
        for (AssignmentRule rule : RULES) {
            if (rule.listName != questionList.LQW_List_Name__c) continue;
            for (Condition c : rule.conditions) {
                out.add(new Map<String, String>{
                    'field'    => c.field,
                    'label'    => humanizeFieldName(c.field),
                    'operator' => c.op,
                    'value'    => (c.value == null) ? '' : String.valueOf(c.value)
                });
            }
        }
        return out.isEmpty() ? null : JSON.serialize(out);
    }

    /**
     * @description Best-effort human label from an API field name.
     * AnnualRevenue -> "Annual Revenue", LeadSource -> "Lead Source",
     * LQW_Foo_Bar__c -> "Foo Bar". No Schema describe call — keeps this
     * evaluator free of per-call overhead.
     */
    private static String humanizeFieldName(String apiName) {
        if (String.isBlank(apiName)) return apiName;
        String n = apiName;
        if (n.startsWithIgnoreCase('LQW_') && n.endsWithIgnoreCase('__c')) {
            n = n.substring(4, n.length() - 3);
        } else if (n.endsWithIgnoreCase('__c')) {
            n = n.substring(0, n.length() - 3);
        }
        n = n.replace('_', ' ');
        // Insert spaces between camelCase segments: "LeadSource" -> "Lead Source".
        // Apex `String ==` is case-insensitive, so use .equals() for the uppercase check.
        String spaced = '';
        for (Integer i = 0; i < n.length(); i++) {
            String ch = n.substring(i, i + 1);
            Boolean isUpper = !ch.equals(ch.toLowerCase());
            String prev = (i > 0) ? n.substring(i - 1, i) : '';
            if (i > 0 && isUpper && !prev.equals(' ')) {
                spaced += ' ';
            }
            spaced += ch;
        }
        return spaced.trim();
    }

    // ─────────────────────────────────────────────────────────────────────
    // One-time starter-list seeding (first install). Kept for continuity;
    // the P1 "seed toggle" work will gate this behind a custom setting.
    // ─────────────────────────────────────────────────────────────────────

    private void ensureExampleListExists() {
        if (hasAutoCreatedExample) {
            return;
        }
        hasAutoCreatedExample = true;

        Integer listCount = [SELECT COUNT() FROM LQW_Question_List__c WITH SYSTEM_MODE LIMIT 1];
        if (listCount != 0) {
            return;
        }

        LQW_Question_List__c exampleList = new LQW_Question_List__c();
        exampleList.LQW_List_Name__c = 'General Qualification';
        exampleList.LQW_Description__c = 'Default qualification questions for all leads';
        exampleList.LQW_Is_Active__c = true;
        exampleList.LQW_Is_Default__c = true;
        exampleList.LQW_High_Quality_Threshold__c = 5;
        exampleList.LQW_Medium_Quality_Threshold__c = 3;
        exampleList.LQW_High_Quality_Label__c = 'High Quality';
        exampleList.LQW_Medium_Quality_Label__c = 'Medium Quality';
        exampleList.LQW_Low_Quality_Label__c = 'Low Quality';
        exampleList.LQW_High_Quality_Recommendation__c = 'Convert to Opportunity';
        exampleList.LQW_Medium_Quality_Recommendation__c = 'Convert to Opportunity with Manager Review';
        exampleList.LQW_Low_Quality_Recommendation__c = 'Nurture Lead (Do Not Convert)';
        insert as system exampleList;

        List<LQW_Qualification_Question__c> exampleQuestions = new List<LQW_Qualification_Question__c>{
            createExampleQuestion(exampleList.Id, 'Is the customer purchasing volume lower than $25K annually?', 1, 1, 'No', true, 'Yes'),
            createExampleQuestion(exampleList.Id, 'Are they under any contracts that would prevent them from doing business with us?', 2, 1, 'No', true, 'Yes'),
            createExampleQuestion(exampleList.Id, 'Is the customer using a competitive product or a product we can upgrade?', 3, 1, 'Yes', false, null),
            createExampleQuestion(exampleList.Id, 'Does the customer purchases across more than one of our categories?', 4, 1, 'Yes', false, null),
            createExampleQuestion(exampleList.Id, 'Is there a compelling event or reason to act within a reasonable window (e.g., 3–6 months)?', 5, 1, 'Yes', false, null),
            createExampleQuestion(exampleList.Id, 'Does our solution address the core need without significant gaps?', 6, 1, 'Yes', false, null),
            createExampleQuestion(exampleList.Id, 'Can we deliver within their required timeframe and scope?', 7, 1, 'Yes', false, null),
            createExampleQuestion(exampleList.Id, 'Does the lead have budget already allocated OR a viable path to obtain budget?', 8, 1, 'Yes', false, null),
            createExampleQuestion(exampleList.Id, 'Have you identified the decision maker or someone directly involved in the decision?', 9, 1, 'Yes', false, null)
        };
        insert as system exampleQuestions;
    }

    private LQW_Qualification_Question__c createExampleQuestion(
        Id listId, String questionText, Integer orderNum, Integer scoreValue,
        String pointEarningAnswer, Boolean isDealbreaker, String dealbreakerValue
    ) {
        LQW_Qualification_Question__c q = new LQW_Qualification_Question__c();
        q.LQW_Question_List__c = listId;
        q.LQW_Question_Text__c = questionText;
        q.LQW_Question_Order__c = orderNum;
        q.LQW_Score_Value__c = scoreValue;
        q.LQW_Point_Earning_Answer__c = pointEarningAnswer;
        q.LQW_Is_Dealbreaker__c = isDealbreaker;
        q.LQW_Dealbreaker_Value__c = dealbreakerValue;
        q.LQW_Is_Active__c = true;
        return q;
    }
}
