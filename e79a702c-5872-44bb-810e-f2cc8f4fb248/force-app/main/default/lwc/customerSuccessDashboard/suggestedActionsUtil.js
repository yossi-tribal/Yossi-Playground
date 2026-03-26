/**
 * Pure helpers for building the suggested-actions list (testable without the LWC runtime).
 * @param {object|null|undefined} summary Dashboard summary from Apex
 * @returns {Array<object>} Ordered suggested actions with handler keys and a11y metadata
 */
export function buildSuggestedActionsList(summary) {
    if (!summary) {
        return [];
    }

    const actions = [];

    if (summary.overdueTasks > 0) {
        actions.push({
            text: 'Complete overdue tasks',
            badge: 'Urgent',
            urgency: 'danger',
            handler: 'overdue-tasks',
            showBadge: true,
            ariaLabel: 'Urgent: Complete overdue tasks'
        });
    }

    if (summary.highPriorityCasesCount > 0) {
        actions.push({
            text: 'Review priority cases',
            badge: 'Urgent',
            urgency: 'warning',
            handler: 'high-priority-cases',
            showBadge: true,
            ariaLabel: 'Urgent: Review priority cases'
        });
    }

    if (summary.daysSinceLastActivity && summary.daysSinceLastActivity > 30) {
        actions.push({
            text: 'Schedule check-in',
            badge: 'Important',
            urgency: 'warning',
            handler: 'schedule-checkin',
            showBadge: true,
            ariaLabel: 'Important: Schedule check-in'
        });
    }

    // Use null check only: 0 means activity today (still upcoming)
    if (summary.daysUntilNextActivity == null) {
        actions.push({
            text: 'Plan touchpoint',
            subline: 'Task, event, or email',
            badge: '',
            urgency: 'info',
            handler: 'plan-touchpoint',
            showBadge: false,
            touchpointChooser: true,
            ariaLabel: 'Plan touchpoint. Opens options to create a task, schedule an event, or email a contact.'
        });
    }

    actions.push({
        text: 'Log a call',
        badge: '',
        urgency: 'info',
        handler: 'log-call',
        showBadge: false,
        ariaLabel: 'Log a completed call for this account'
    });

    return actions;
}
