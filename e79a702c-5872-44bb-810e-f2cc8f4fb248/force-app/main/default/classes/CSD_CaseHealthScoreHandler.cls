/**
 * @description Handler class for Case Health Score calculation trigger.
 * Identifies affected Accounts when Cases are created, updated, or deleted,
 * and triggers health score recalculation. Handles bulk operations efficiently.
 * @author Tribal AI Platform
 * @date 2024
 */
public with sharing class CSD_CaseHealthScoreHandler {

    /**
     * @description Processes Case records and triggers health score calculation for affected Accounts
     * @param newCases List of new/updated Case records (from Trigger.new)
     * @param oldCases List of old Case records (from Trigger.old)
     */
    public static void handleCaseChanges(List<Case> newCases, List<Case> oldCases) {
        Set<Id> affectedAccountIds = new Set<Id>();

        // Collect Account IDs from new/updated Cases
        if (newCases != null) {
            for (Case c : newCases) {
                if (c.AccountId != null) {
                    affectedAccountIds.add(c.AccountId);
                }
            }
        }

        // Collect Account IDs from deleted Cases
        if (oldCases != null) {
            for (Case c : oldCases) {
                if (c.AccountId != null) {
                    affectedAccountIds.add(c.AccountId);
                }
            }
        }

        // Trigger health score recalculation for all affected Accounts
        if (!affectedAccountIds.isEmpty()) {
            CSD_AccountHealthScoreHandler.calculateHealthScores(affectedAccountIds);
        }
    }
}
