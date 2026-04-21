/**
 * Tests for onboardingStorage — pure JS module, no DOM.
 *
 * We clear localStorage between every test so prior state never leaks.
 */
import {
    buildScopeKey,
    isCompleted,
    markCompleted,
    recordSkip,
    reset,
    getStatus
} from 'c/onboardingStorage';

describe('c/onboardingStorage', () => {
    beforeEach(() => {
        window.localStorage.clear();
    });

    describe('buildScopeKey', () => {
        it('joins userId + componentName with a "::" separator', () => {
            expect(buildScopeKey('005abc', 'leadQualificationWizard')).toBe(
                '005abc::leadQualificationWizard'
            );
        });

        it('falls back to placeholders when inputs are missing', () => {
            expect(buildScopeKey(null, null)).toBe('__anon__::__unknown__');
            expect(buildScopeKey('005abc', null)).toBe('005abc::__unknown__');
            expect(buildScopeKey(null, 'foo')).toBe('__anon__::foo');
        });
    });

    describe('markCompleted + isCompleted', () => {
        const scope = buildScopeKey('user1', 'wizard');

        it('returns false when nothing has been written', () => {
            expect(isCompleted(scope, 'intro')).toBe(false);
        });

        it('returns true after markCompleted when version matches', () => {
            markCompleted(scope, 'intro', 1);
            expect(isCompleted(scope, 'intro', 1)).toBe(true);
        });

        it('returns false when the stored version is older than expected', () => {
            markCompleted(scope, 'intro', 1);
            expect(isCompleted(scope, 'intro', 2)).toBe(false);
        });

        it('returns true when expectedVersion is omitted, regardless of stored version', () => {
            markCompleted(scope, 'intro', 2);
            expect(isCompleted(scope, 'intro')).toBe(true);
        });

        it('scopes by user — one user completing does not affect another', () => {
            const userA = buildScopeKey('userA', 'wizard');
            const userB = buildScopeKey('userB', 'wizard');
            markCompleted(userA, 'intro', 1);
            expect(isCompleted(userA, 'intro', 1)).toBe(true);
            expect(isCompleted(userB, 'intro', 1)).toBe(false);
        });

        it('scopes by component — two LWCs keep separate status', () => {
            const wizard = buildScopeKey('user1', 'wizard');
            const manager = buildScopeKey('user1', 'manager');
            markCompleted(wizard, 'intro', 1);
            expect(isCompleted(wizard, 'intro', 1)).toBe(true);
            expect(isCompleted(manager, 'intro', 1)).toBe(false);
        });
    });

    describe('recordSkip anti-nag', () => {
        const scope = buildScopeKey('user1', 'wizard');

        it('does not auto-complete after a single skip', () => {
            recordSkip(scope, 'intro', 1);
            expect(isCompleted(scope, 'intro', 1)).toBe(false);
            const status = getStatus(scope, 'intro');
            expect(status.skips).toBe(1);
            expect(status.autoCompletedFromSkips).toBeUndefined();
        });

        it('auto-completes after the second skip', () => {
            recordSkip(scope, 'intro', 1);
            recordSkip(scope, 'intro', 1);
            expect(isCompleted(scope, 'intro', 1)).toBe(true);
            const status = getStatus(scope, 'intro');
            expect(status.skips).toBe(2);
            expect(status.autoCompletedFromSkips).toBe(true);
        });

        it('tracks firstSkipAt and lastSkipAt timestamps', () => {
            const entry = recordSkip(scope, 'intro', 1);
            expect(entry.firstSkipAt).toBeTruthy();
            expect(entry.lastSkipAt).toBe(entry.firstSkipAt);
            const entry2 = recordSkip(scope, 'intro', 1);
            expect(entry2.firstSkipAt).toBe(entry.firstSkipAt);
            expect(entry2.lastSkipAt).toBeGreaterThanOrEqual(entry.firstSkipAt);
        });
    });

    describe('reset', () => {
        const scope = buildScopeKey('user1', 'wizard');

        it('clears a single tour when tourId is supplied', () => {
            markCompleted(scope, 'intro', 1);
            markCompleted(scope, 'scoring', 1);
            reset(scope, 'intro');
            expect(isCompleted(scope, 'intro', 1)).toBe(false);
            expect(isCompleted(scope, 'scoring', 1)).toBe(true);
        });

        it('clears every tour in the scope when tourId is omitted', () => {
            markCompleted(scope, 'intro', 1);
            markCompleted(scope, 'scoring', 1);
            markCompleted(scope, 'dealbreakers', 1);
            reset(scope);
            expect(isCompleted(scope, 'intro', 1)).toBe(false);
            expect(isCompleted(scope, 'scoring', 1)).toBe(false);
            expect(isCompleted(scope, 'dealbreakers', 1)).toBe(false);
        });

        it('does not clear other scopes when resetting one scope', () => {
            const other = buildScopeKey('user2', 'wizard');
            markCompleted(scope, 'intro', 1);
            markCompleted(other, 'intro', 1);
            reset(scope);
            expect(isCompleted(scope, 'intro', 1)).toBe(false);
            expect(isCompleted(other, 'intro', 1)).toBe(true);
        });
    });

    describe('getStatus', () => {
        const scope = buildScopeKey('user1', 'wizard');

        it('returns null when no entry exists', () => {
            expect(getStatus(scope, 'intro')).toBeNull();
        });

        it('returns the completed entry shape after markCompleted', () => {
            markCompleted(scope, 'intro', 3);
            const status = getStatus(scope, 'intro');
            expect(status.completed).toBe(true);
            expect(status.version).toBe(3);
            expect(typeof status.at).toBe('number');
        });
    });
});
