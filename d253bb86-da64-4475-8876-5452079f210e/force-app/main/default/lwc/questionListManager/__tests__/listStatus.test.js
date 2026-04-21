import {
    listHasQuestions,
    canListGoLive,
    listActivationBlockReason
} from '../listStatus';

describe('listHasQuestions', () => {
    it('returns false for null / undefined', () => {
        expect(listHasQuestions(null)).toBe(false);
        expect(listHasQuestions(undefined)).toBe(false);
    });

    it('uses activeQuestions when present', () => {
        expect(listHasQuestions({ activeQuestions: 0, totalQuestions: 5 })).toBe(false);
        expect(listHasQuestions({ activeQuestions: 1, totalQuestions: 5 })).toBe(true);
    });

    it('falls back to totalQuestions when activeQuestions is missing', () => {
        expect(listHasQuestions({ totalQuestions: 0 })).toBe(false);
        expect(listHasQuestions({ totalQuestions: 3 })).toBe(true);
    });

    it('returns false when both counters are missing', () => {
        expect(listHasQuestions({})).toBe(false);
    });

    it('handles non-number values defensively', () => {
        expect(listHasQuestions({ activeQuestions: 'not-a-number', totalQuestions: 2 })).toBe(true);
        expect(listHasQuestions({ activeQuestions: null, totalQuestions: null })).toBe(false);
    });
});

describe('canListGoLive', () => {
    it('returns false when there is no list', () => {
        expect(canListGoLive(null, true)).toBe(false);
        expect(canListGoLive(undefined, true)).toBe(false);
    });

    it('blocks lists with zero questions even when criteria are set', () => {
        expect(canListGoLive({ activeQuestions: 0 }, true)).toBe(false);
    });

    it('blocks lists with zero questions even when they are the default list', () => {
        expect(canListGoLive({ activeQuestions: 0, isDefault: true }, false)).toBe(false);
    });

    it('allows a list with questions and criteria', () => {
        expect(canListGoLive({ activeQuestions: 3 }, true)).toBe(true);
    });

    it('allows the default list once it has questions, without criteria', () => {
        expect(canListGoLive({ activeQuestions: 3, isDefault: true }, false)).toBe(true);
    });

    it('blocks a non-default list with questions but no criteria', () => {
        expect(canListGoLive({ activeQuestions: 3, isDefault: false }, false)).toBe(false);
    });

    it('treats a truthy criteria value as "has criteria"', () => {
        expect(canListGoLive({ activeQuestions: 1 }, 'yes')).toBe(true);
        expect(canListGoLive({ activeQuestions: 1 }, 0)).toBe(false);
    });
});

describe('listActivationBlockReason', () => {
    it('returns "no-list" when no list', () => {
        expect(listActivationBlockReason(null, true)).toBe('no-list');
    });

    it('returns "no-questions" when the list is empty, even if criteria exist', () => {
        expect(listActivationBlockReason({ activeQuestions: 0 }, true)).toBe('no-questions');
    });

    it('returns "no-questions" before "no-criteria" when both apply', () => {
        expect(listActivationBlockReason({ activeQuestions: 0 }, false)).toBe('no-questions');
    });

    it('returns "no-criteria" for a non-default list with questions but no criteria', () => {
        expect(listActivationBlockReason({ activeQuestions: 2, isDefault: false }, false))
            .toBe('no-criteria');
    });

    it('returns null when the default list has questions (no criteria needed)', () => {
        expect(listActivationBlockReason({ activeQuestions: 2, isDefault: true }, false)).toBeNull();
    });

    it('returns null when a regular list has questions and criteria', () => {
        expect(listActivationBlockReason({ activeQuestions: 2 }, true)).toBeNull();
    });
});
