/**
 * @description Trigger on Case object that automatically updates the related Account's health score
 * when cases are created, updated, or deleted. Ensures health score reflects current case load
 * and priority levels in real-time.
 * @author Tribal AI Platform
 * @date 2024
 */
trigger CSD_CaseHealthScoreTrigger on Case (after insert, after update, after delete) {
    // Delegate to handler class for business logic
    CSD_CaseHealthScoreHandler.handleCaseChanges(Trigger.new, Trigger.old);
}
