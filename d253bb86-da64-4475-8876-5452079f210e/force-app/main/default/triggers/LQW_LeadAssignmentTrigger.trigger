/**
 * @description Trigger on Lead object for automatic question list assignment
 * Delegates to LeadAssignmentTriggerHandler for code-driven criteria evaluation
 * Replaces the record-triggered flow for question list assignment
 */
trigger LQW_LeadAssignmentTrigger on Lead (after insert, after update) {
    LQW_LeadAssignmentTriggerHandler handler = new LQW_LeadAssignmentTriggerHandler();
    handler.handleAfterInsertUpdate(Trigger.new, Trigger.oldMap);
}
