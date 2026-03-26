/**
 * @description Handler class for Event Health Score calculation trigger.
 * Identifies affected Accounts when Events are created, updated, or deleted,
 * and triggers health score recalculation. Handles bulk operations efficiently.
 * @author Tribal AI Platform
 * @date 2024
 */
public with sharing class CSD_EventHealthScoreHandler {

    /**
     * @description Processes Event records and triggers health score calculation for affected Accounts
     * @param newEvents List of new/updated Event records (from Trigger.new)
     * @param oldEvents List of old Event records (from Trigger.old)
     */
    public static void handleEventChanges(List<Event> newEvents, List<Event> oldEvents) {
        Set<Id> affectedAccountIds = new Set<Id>();

        // Collect Account IDs from new/updated Events
        if (newEvents != null) {
            for (Event e : newEvents) {
                if (e.WhatId != null && e.WhatId.getSObjectType() == Schema.Account.SObjectType) {
                    affectedAccountIds.add(e.WhatId);
                }
            }
        }

        // Collect Account IDs from deleted Events
        if (oldEvents != null) {
            for (Event e : oldEvents) {
                if (e.WhatId != null && e.WhatId.getSObjectType() == Schema.Account.SObjectType) {
                    affectedAccountIds.add(e.WhatId);
                }
            }
        }

        // Trigger health score recalculation for all affected Accounts
        if (!affectedAccountIds.isEmpty()) {
            CSD_AccountHealthScoreHandler.calculateHealthScores(affectedAccountIds);
        }
    }
}
