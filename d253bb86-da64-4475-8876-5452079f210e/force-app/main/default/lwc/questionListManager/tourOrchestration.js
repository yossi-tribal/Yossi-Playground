/**
 * Pure helpers for the Question List Manager's tour orchestration.
 *
 * These live outside the LWC class so they can be unit tested without the
 * ceremony of mounting a component. The LWC owns the imperative state
 * (which modal is open, whether the Scoring Guide is in edit mode); these
 * helpers own the declarative decisions (what context does a step need,
 * what tour runs next after this one).
 */

const LEGACY_ACTION_MAP = {
    openListModal: 'list-modal',
    openQuestionModal: 'question-modal',
    selectFirstListIfNone: 'list-selected'
};

/**
 * Map the legacy `step.action` metadata to the current `context` vocabulary.
 * Returns null when the action is unset or unrecognized; callers should treat
 * null as "no onEnter hook needed — the step just renders".
 */
export function legacyActionToContext(action) {
    if (!action) return null;
    return LEGACY_ACTION_MAP[action] || null;
}

/**
 * Decide which tour (if any) should run after `finishedId` completes, and
 * return the updated chain state. The caller owns the state — this function
 * is pure.
 *
 * First completion: pass `{ activeChain: null, chainIndex: 0 }`. If the
 * finished tour declares a `chain: [...]`, the first entry is returned as
 * `nextId` and the chain is initialised. Subsequent completions advance
 * the index until the chain is exhausted, at which point the returned
 * state is reset and `nextId` is null.
 *
 * An unknown tour id, a tour with no `chain`, or an empty chain all return
 * `{ state: cleared, nextId: null }` — there is nothing to chain into.
 */
export function advanceChain(state, finishedId, tours) {
    const cleared = { activeChain: null, chainIndex: 0 };
    if (!finishedId) return { state: cleared, nextId: null };

    let activeChain =
        state && Array.isArray(state.activeChain) ? state.activeChain : null;
    let chainIndex =
        state && Number.isInteger(state.chainIndex) ? state.chainIndex : 0;

    if (!activeChain) {
        const tour = Array.isArray(tours)
            ? tours.find((t) => t && t.id === finishedId)
            : null;
        const chain = tour && Array.isArray(tour.chain) ? tour.chain : null;
        if (!chain || chain.length === 0) {
            return { state: cleared, nextId: null };
        }
        // Copy so we never mutate the source tour definition.
        activeChain = chain.slice();
        chainIndex = 0;
    } else {
        chainIndex += 1;
    }

    const nextId = activeChain[chainIndex] || null;
    if (!nextId) {
        return { state: cleared, nextId: null };
    }
    return { state: { activeChain, chainIndex }, nextId };
}
