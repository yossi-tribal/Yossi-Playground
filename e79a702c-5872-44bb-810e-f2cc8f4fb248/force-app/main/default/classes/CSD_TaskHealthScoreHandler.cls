/**
 * @description Handler class for Task Health Score calculation trigger.
 * Identifies affected Accounts when Tasks are created, updated, or deleted,
 * and triggers health score recalculation. Handles bulk operations efficiently.
 * @author Tribal AI Platform
 * @date 2024
 */
public with sharing class CSD_TaskHealthScoreHandler {

    /**
     * @description Processes Task records and triggers health score calculation for affected Accounts
     * @param newTasks List of new/updated Task records (from Trigger.new)
     * @param oldTasks List of old Task records (from Trigger.old)
     */
    public static void handleTaskChanges(List<Task> newTasks, List<Task> oldTasks) {
        Set<Id> affectedAccountIds = new Set<Id>();

        // Collect Account IDs from new/updated Tasks
        if (newTasks != null) {
            for (Task t : newTasks) {
                if (t.WhatId != null && t.WhatId.getSObjectType() == Schema.Account.SObjectType) {
                    affectedAccountIds.add(t.WhatId);
                }
            }
        }

        // Collect Account IDs from deleted Tasks
        if (oldTasks != null) {
            for (Task t : oldTasks) {
                if (t.WhatId != null && t.WhatId.getSObjectType() == Schema.Account.SObjectType) {
                    affectedAccountIds.add(t.WhatId);
                }
            }
        }

        // Trigger health score recalculation for all affected Accounts
        if (!affectedAccountIds.isEmpty()) {
            CSD_AccountHealthScoreHandler.calculateHealthScores(affectedAccountIds);
        }
    }
}
