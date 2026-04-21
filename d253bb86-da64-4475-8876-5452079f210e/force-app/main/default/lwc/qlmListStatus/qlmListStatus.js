/**
 * qlmListStatus
 *
 * Pure helpers for Question List Manager list-status logic: whether a list
 * is allowed to go live, and if not, why. Kept as its own LWC bundle so:
 *   (a) it's trivially unit-testable without Jest + Salesforce wire mocks, and
 *   (b) Tribal's deploy pipeline picks it up (it strips non-main JS files
 *       that live inside another component's bundle — see qlmAdminRequest
 *       and qlmTours for the same rationale).
 */

/**
 * Returns true when the given list has at least one question that could
 * actually be asked. Prefers `activeQuestions` (server-provided) and falls
 * back to `totalQuestions` for older payload shapes so existing lists
 * aren't accidentally locked out by a schema mismatch.
 *
 * @param {object|null|undefined} list
 * @returns {boolean}
 */
export function listHasQuestions(list) {
    if (!list) return false;
    if (typeof list.activeQuestions === 'number') {
        return list.activeQuestions > 0;
    }
    return (typeof list.totalQuestions === 'number' ? list.totalQuestions : 0) > 0;
}

/**
 * Returns true when the list is allowed to go live. A list can go live when:
 *   1. it has at least one question, AND
 *   2. it has assignment criteria configured OR is the default-fallback list.
 *
 * @param {object|null|undefined} list
 * @param {boolean} hasCriteria whether the list has assignment criteria
 * @returns {boolean}
 */
export function canListGoLive(list, hasCriteria) {
    if (!list) return false;
    if (!listHasQuestions(list)) return false;
    return Boolean(hasCriteria) || Boolean(list.isDefault);
}

/**
 * When a list can't go live, tells you which guard is tripping so callers
 * can surface a precise error message instead of a generic "can't activate".
 * Returns null when the list *can* go live.
 *
 *   'no-list'      — no list passed (defensive)
 *   'no-questions' — list has zero questions
 *   'no-criteria'  — list has questions but no criteria (and isn't default)
 *
 * @param {object|null|undefined} list
 * @param {boolean} hasCriteria
 * @returns {'no-list'|'no-questions'|'no-criteria'|null}
 */
export function listActivationBlockReason(list, hasCriteria) {
    if (!list) return 'no-list';
    if (!listHasQuestions(list)) return 'no-questions';
    if (!hasCriteria && !list.isDefault) return 'no-criteria';
    return null;
}
