/**
 * @description Trigger on Task object that automatically updates the related Account's health score
 * when tasks are created, updated, or deleted. Ensures health score reflects overdue tasks
 * and activity recency in real-time.
 * @author Tribal AI Platform
 * @date 2024
 */
trigger CSD_TaskHealthScoreTrigger on Task (after insert, after update, after delete) {
    // Delegate to handler class for business logic
    CSD_TaskHealthScoreHandler.handleTaskChanges(Trigger.new, Trigger.old);
}
