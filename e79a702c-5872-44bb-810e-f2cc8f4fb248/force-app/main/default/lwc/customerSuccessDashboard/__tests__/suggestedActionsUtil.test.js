import { buildSuggestedActionsList } from '../suggestedActionsUtil';

describe('buildSuggestedActionsList', () => {
    it('returns an empty array when summary is null or undefined', () => {
        expect(buildSuggestedActionsList(null)).toEqual([]);
        expect(buildSuggestedActionsList(undefined)).toEqual([]);
    });

    it('ends with Log a call with log-call handler and ariaLabel', () => {
        const list = buildSuggestedActionsList({
            overdueTasks: 0,
            highPriorityCasesCount: 0,
            daysSinceLastActivity: 5,
            daysUntilNextActivity: 14
        });
        expect(list.length).toBeGreaterThanOrEqual(1);
        const last = list[list.length - 1];
        expect(last.handler).toBe('log-call');
        expect(last.text).toBe('Log a call');
        expect(last.ariaLabel).toContain('call');
    });

    it('adds overdue-tasks when overdueTasks > 0', () => {
        const list = buildSuggestedActionsList({
            overdueTasks: 3,
            highPriorityCasesCount: 0,
            daysSinceLastActivity: 1,
            daysUntilNextActivity: 7
        });
        expect(list[0].handler).toBe('overdue-tasks');
        expect(list[0].text).toBe('Complete overdue tasks');
    });

    it('adds high-priority-cases when highPriorityCasesCount > 0', () => {
        const list = buildSuggestedActionsList({
            overdueTasks: 0,
            highPriorityCasesCount: 2,
            daysSinceLastActivity: 1,
            daysUntilNextActivity: 7
        });
        expect(list[0].handler).toBe('high-priority-cases');
    });

    it('adds schedule-checkin when daysSinceLastActivity > 30', () => {
        const list = buildSuggestedActionsList({
            overdueTasks: 0,
            highPriorityCasesCount: 0,
            daysSinceLastActivity: 45,
            daysUntilNextActivity: 7
        });
        expect(list.map((a) => a.handler)).toContain('schedule-checkin');
    });

    it('adds plan-touchpoint only when daysUntilNextActivity is null, not when 0 (today)', () => {
        const withNull = buildSuggestedActionsList({
            overdueTasks: 0,
            highPriorityCasesCount: 0,
            daysSinceLastActivity: 5,
            daysUntilNextActivity: null
        });
        const touchNull = withNull.find((a) => a.handler === 'plan-touchpoint');
        expect(touchNull).toBeDefined();
        expect(touchNull.touchpointChooser).toBe(true);
        expect(touchNull.subline).toBe('Task, event, or email');

        const withZero = buildSuggestedActionsList({
            overdueTasks: 0,
            highPriorityCasesCount: 0,
            daysSinceLastActivity: 5,
            daysUntilNextActivity: 0
        });
        expect(withZero.find((a) => a.handler === 'plan-touchpoint')).toBeUndefined();
    });

    it('orders stacked conditions: overdue before cases before schedule before plan before log', () => {
        const list = buildSuggestedActionsList({
            overdueTasks: 1,
            highPriorityCasesCount: 1,
            daysSinceLastActivity: 60,
            daysUntilNextActivity: null
        });
        const handlers = list.map((a) => a.handler);
        expect(handlers.indexOf('overdue-tasks')).toBeLessThan(handlers.indexOf('high-priority-cases'));
        expect(handlers.indexOf('high-priority-cases')).toBeLessThan(handlers.indexOf('schedule-checkin'));
        expect(handlers.indexOf('schedule-checkin')).toBeLessThan(handlers.indexOf('plan-touchpoint'));
        expect(handlers.indexOf('plan-touchpoint')).toBeLessThan(handlers.indexOf('log-call'));
    });
});
