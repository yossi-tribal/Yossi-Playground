/**
 * @description Trigger on Event object that automatically updates the related Account's health score
 * when events are created, updated, or deleted. Ensures health score reflects activity recency
 * in real-time.
 * @author Tribal AI Platform
 * @date 2024
 */
trigger CSD_EventHealthScoreTrigger on Event (after insert, after update, after delete) {
    // Delegate to handler class for business logic
    CSD_EventHealthScoreHandler.handleEventChanges(Trigger.new, Trigger.old);
}
