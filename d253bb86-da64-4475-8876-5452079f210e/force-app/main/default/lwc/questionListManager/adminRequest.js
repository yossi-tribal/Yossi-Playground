/**
 * Pure helpers for the Question List Manager's "Copy details for admin"
 * handoff.
 *
 * The goal: let a non-admin user who can't configure Tribal/Salesforce
 * assignment rules themselves send their admin a clean, self-contained
 * request with every detail the admin needs (list identity, current
 * state, scoring, existing criteria, and a clearly-marked placeholder
 * for the proposed criteria).
 *
 * Kept as pure functions so the text generation is easy to unit test
 * across the four meaningful input shapes:
 *   1. Default fallback list
 *   2. List with criteria already configured
 *   3. List with no criteria yet
 *   4. Malformed / partial list (defensive defaults)
 */

/**
 * Build the admin handoff text block from an explicit context object.
 *
 * The component passes everything it already derives for the UI so this
 * function stays stateless and free of LWC ceremony. Callers should pass:
 *   - list:                the selectedList object (or null)
 *   - hasCriteria:         boolean, from the component's hasAssignmentCriteria
 *   - parsedCriteriaRules: array of rule pills with displayOperator/displayValue
 *   - scoringTiers:        array of {label, threshold, recommendation}
 *   - formattedCriteria:   fallback criteria string if parsed rules are empty
 *
 * Returns a plain-text string ready to paste into email/Slack/Jira.
 */
export function buildAdminRequestText({
    list = {},
    hasCriteria = false,
    parsedCriteriaRules = [],
    scoringTiers = [],
    formattedCriteria = ''
} = {}) {
    const safeList = list || {};
    const lines = [];

    lines.push('Lead Qualification List — Admin Request');
    lines.push('========================================');
    lines.push('');
    lines.push(`List Name:   ${safeList.listName || '(unnamed)'}`);
    lines.push(`List ID:     ${safeList.listId || '(unknown)'}`);
    if (safeList.description) {
        lines.push(`Description: ${safeList.description}`);
    }

    const statusBits = [];
    statusBits.push(safeList.isActive ? 'Active' : 'Inactive');
    if (safeList.isDefault) statusBits.push('Default Fallback');
    lines.push(`Status:      ${statusBits.join(' • ')}`);

    let currentAssignment;
    if (safeList.isDefault) {
        currentAssignment = 'Default fallback list (assigned when no other list matches)';
    } else if (hasCriteria) {
        currentAssignment = 'Criteria-based (see existing rules below)';
    } else {
        currentAssignment = 'None configured yet';
    }
    lines.push(`Current Assignment: ${currentAssignment}`);
    lines.push('');

    lines.push('Questions & Scoring');
    lines.push('-------------------');
    lines.push(`Active questions:      ${safeList.activeQuestions ?? 0} of ${safeList.totalQuestions ?? 0}`);
    lines.push(`Total possible points: ${safeList.totalPossiblePoints ?? 0}`);
    lines.push(`Dealbreakers:          ${safeList.dealbreakerCount ?? 0}`);

    const tiers = Array.isArray(scoringTiers) ? scoringTiers : [];
    if (tiers.length) {
        lines.push('');
        lines.push('Scoring tiers:');
        tiers.forEach((tier) => {
            if (!tier) return;
            lines.push(`  • ${tier.label}: ${tier.threshold}+ pts → ${tier.recommendation}`);
        });
    }
    lines.push('');

    if (hasCriteria) {
        lines.push('Existing Assignment Criteria');
        lines.push('----------------------------');
        const rules = Array.isArray(parsedCriteriaRules) ? parsedCriteriaRules : [];
        if (rules.length) {
            rules.forEach((rule) => {
                if (!rule) return;
                lines.push(`  • ${rule.label} ${rule.displayOperator} ${rule.displayValue}`);
            });
        } else {
            lines.push(formattedCriteria || '(unparseable)');
        }
        lines.push('');
    }

    lines.push('Proposed Assignment Criteria');
    lines.push('----------------------------');
    lines.push('[Replace this line with the criteria you want, e.g.');
    lines.push(' Industry equals "SaaS" AND Annual Revenue greater than 1000000]');
    lines.push('');
    lines.push('Additional Notes');
    lines.push('----------------');
    lines.push('[Anything else the admin should know — context, urgency, etc.]');
    lines.push('');
    lines.push('Thanks!');

    return lines.join('\n');
}

/**
 * Attempt to copy `text` to the clipboard, falling back to a hidden
 * textarea + document.execCommand when the async Clipboard API is
 * unavailable or blocked (older browsers, some Salesforce contexts).
 *
 * Returns true on success. Takes optional `deps` to make the whole
 * thing testable without touching real DOM clipboard APIs:
 *   - deps.clipboardWrite: async (text) => void
 *   - deps.fallbackCopy:   (text) => boolean
 */
export async function copyTextToClipboard(text, deps = {}) {
    const clipboardWrite =
        deps.clipboardWrite
        || (typeof navigator !== 'undefined'
            && navigator.clipboard
            && navigator.clipboard.writeText
            && ((t) => navigator.clipboard.writeText(t)));

    if (clipboardWrite) {
        try {
            await clipboardWrite(text);
            return true;
        } catch (err) {
            // fall through to the textarea fallback
        }
    }

    const fallback = deps.fallbackCopy || _execCommandCopyFallback;
    try {
        return Boolean(fallback(text));
    } catch (err) {
        return false;
    }
}

function _execCommandCopyFallback(text) {
    if (typeof document === 'undefined') return false;
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.setAttribute('readonly', '');
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    let ok = false;
    try {
        ok = document.execCommand && document.execCommand('copy');
    } catch (e) {
        ok = false;
    }
    document.body.removeChild(textarea);
    return ok;
}
