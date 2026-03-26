/**
 * @description Trigger on Account object that automatically calculates and updates the Account Health Score
 * based on activity metrics, open cases, and overdue tasks. Fires after insert and after update
 * to ensure health score is always current.
 * @author Tribal AI Platform
 * @date 2024
 */
trigger CSD_AccountHealthScoreTrigger on Account (after insert, after update) {
    // Collect Account IDs that need health score calculation
    Set<Id> accountIds = new Set<Id>();

    for (Account acc : Trigger.new) {
        accountIds.add(acc.Id);
    }

    // Delegate to handler class for business logic
    if (!accountIds.isEmpty()) {
        CSD_AccountHealthScoreHandler.calculateHealthScores(accountIds);
    }
}
