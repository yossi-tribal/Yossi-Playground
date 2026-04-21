/**
 * Tests for the Question List Manager tour orchestration helpers.
 * Pure functions — no LWC mounting required.
 */
import { legacyActionToContext, advanceChain } from '../qlmTourOrchestration';

describe('legacyActionToContext', () => {
    it('returns null when no action is set', () => {
        expect(legacyActionToContext(undefined)).toBeNull();
        expect(legacyActionToContext(null)).toBeNull();
        expect(legacyActionToContext('')).toBeNull();
    });

    it('maps each known legacy action to its current context name', () => {
        expect(legacyActionToContext('openListModal')).toBe('list-modal');
        expect(legacyActionToContext('openQuestionModal')).toBe('question-modal');
        expect(legacyActionToContext('selectFirstListIfNone')).toBe('list-selected');
    });

    it('returns null for unknown actions instead of throwing', () => {
        expect(legacyActionToContext('teleport')).toBeNull();
        expect(legacyActionToContext('openScoringModal')).toBeNull();
    });
});

describe('advanceChain', () => {
    const TOURS = [
        { id: 'intro', chain: ['lists', 'scoring', 'questions'] },
        { id: 'lists' },
        { id: 'scoring' },
        { id: 'questions' },
        { id: 'empty-chain', chain: [] }
    ];

    const FRESH = { activeChain: null, chainIndex: 0 };

    describe('no-op cases', () => {
        it('returns cleared state and null when no finished tour id is given', () => {
            expect(advanceChain(FRESH, null, TOURS))
                .toEqual({ state: FRESH, nextId: null });
            expect(advanceChain(FRESH, undefined, TOURS))
                .toEqual({ state: FRESH, nextId: null });
            expect(advanceChain(FRESH, '', TOURS))
                .toEqual({ state: FRESH, nextId: null });
        });

        it('returns cleared state and null when the finished tour has no chain', () => {
            expect(advanceChain(FRESH, 'lists', TOURS))
                .toEqual({ state: FRESH, nextId: null });
        });

        it('returns cleared state and null when the finished tour has an empty chain', () => {
            expect(advanceChain(FRESH, 'empty-chain', TOURS))
                .toEqual({ state: FRESH, nextId: null });
        });

        it('returns cleared state and null when the finished tour is unknown', () => {
            expect(advanceChain(FRESH, 'ghost', TOURS))
                .toEqual({ state: FRESH, nextId: null });
        });

        it('tolerates a missing tours catalog', () => {
            expect(advanceChain(FRESH, 'intro', null))
                .toEqual({ state: FRESH, nextId: null });
            expect(advanceChain(FRESH, 'intro', undefined))
                .toEqual({ state: FRESH, nextId: null });
        });
    });

    describe('chain lifecycle', () => {
        it('initialises the chain on first completion and returns the first id', () => {
            const result = advanceChain(FRESH, 'intro', TOURS);
            expect(result.nextId).toBe('lists');
            expect(result.state.activeChain).toEqual(['lists', 'scoring', 'questions']);
            expect(result.state.chainIndex).toBe(0);
        });

        it('does not mutate the source tour chain array', () => {
            const original = TOURS[0].chain.slice();
            const result = advanceChain(FRESH, 'intro', TOURS);
            // Mutating the returned state must not reach the source.
            result.state.activeChain.push('DAMAGE');
            expect(TOURS[0].chain).toEqual(original);
        });

        it('advances to the next tour mid-chain', () => {
            const state = {
                activeChain: ['lists', 'scoring', 'questions'],
                chainIndex: 0
            };
            const result = advanceChain(state, 'lists', TOURS);
            expect(result.nextId).toBe('scoring');
            expect(result.state).toEqual({
                activeChain: ['lists', 'scoring', 'questions'],
                chainIndex: 1
            });
        });

        it('ignores finishedId once a chain is active (uses position, not id)', () => {
            // Even if the caller passes a completely different id, an active
            // chain just walks the array. This keeps the host simple: it
            // always hands us whatever tour just completed.
            const state = {
                activeChain: ['lists', 'scoring', 'questions'],
                chainIndex: 0
            };
            const result = advanceChain(state, 'anything-goes', TOURS);
            expect(result.nextId).toBe('scoring');
        });

        it('clears the chain once the last tour in it finishes', () => {
            const state = {
                activeChain: ['lists', 'scoring', 'questions'],
                chainIndex: 2
            };
            const result = advanceChain(state, 'questions', TOURS);
            expect(result.nextId).toBeNull();
            expect(result.state).toEqual(FRESH);
        });

        it('progresses through an entire chain end-to-end', () => {
            let state = FRESH;
            let nextId;
            const path = [];

            ({ nextId, state } = advanceChain(state, 'intro', TOURS));
            while (nextId) {
                path.push(nextId);
                ({ nextId, state } = advanceChain(state, nextId, TOURS));
            }

            expect(path).toEqual(['lists', 'scoring', 'questions']);
            expect(state).toEqual(FRESH);
        });
    });

    describe('state-shape tolerance', () => {
        it('treats a null/undefined incoming state as fresh', () => {
            expect(advanceChain(null, 'intro', TOURS).nextId).toBe('lists');
            expect(advanceChain(undefined, 'intro', TOURS).nextId).toBe('lists');
        });

        it('treats a non-array activeChain as absent', () => {
            const state = { activeChain: 'nope', chainIndex: 0 };
            // Finished tour `intro` has a chain, so we re-init from it.
            const result = advanceChain(state, 'intro', TOURS);
            expect(result.nextId).toBe('lists');
        });
    });
});
