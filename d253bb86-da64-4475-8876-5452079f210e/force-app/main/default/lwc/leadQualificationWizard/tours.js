/**
 * Tours for the Lead Qualification Wizard.
 *
 * Each tour is a named mini-walkthrough. The "intro" tour auto-runs the first
 * time a user opens the wizard; the others are replay-only (via the 'i' menu).
 *
 * Target selectors must resolve inside the host's shadow DOM. We use
 * [data-tour="..."] attributes that live on the wizard's template so we don't
 * bind to volatile class names.
 *
 * The special selector "__dealbreaker_question__" is intercepted by the
 * wizard's target resolver and resolves to the first dealbreaker question row
 * in the current list (or null, in which case the coach falls back to center
 * placement).
 *
 * Keep body copy skimmable: 1 short sentence where possible, 2 max. Users are
 * busy non-technical reps — they need the gist at a glance.
 *
 * Bump `version` when step content meaningfully changes — users whose stored
 * state is an older version get re-prompted automatically.
 */

const WIZARD_TOURS = [
    {
        id: 'intro',
        version: 2,
        title: 'Welcome tour',
        summary: '60-second overview of the wizard.',
        icon: 'utility:magicwand',
        steps: [
            {
                id: 'welcome',
                title: 'Lead Qualification Wizard',
                body:
                    'Answer Yes / No questions. We score the lead and suggest what to do next.',
                placement: 'center',
                width: 'standard'
            },
            {
                id: 'lead-quality',
                title: 'Lead quality',
                body: 'The current tier, based on your answers. Updates live.',
                target: '[data-tour="lead-quality"]',
                placement: 'bottom',
                width: 'standard'
            },
            {
                id: 'recommended-action',
                title: 'What to do next',
                body: 'Our suggestion — convert, review, or nurture. Guidance, not a rule.',
                target: '[data-tour="recommended-action"]',
                placement: 'bottom',
                width: 'standard'
            },
            {
                id: 'progress',
                title: 'Progress',
                body: 'How many questions are left. Stop any time — answers save automatically.',
                target: '[data-tour="progress"]',
                placement: 'bottom',
                width: 'standard'
            },
            {
                id: 'questions',
                title: 'Answer each question',
                body: 'Click Yes or No. Click again to clear.',
                target: '[data-tour="questions"]',
                placement: 'top',
                width: 'standard'
            },
            {
                id: 'dealbreakers',
                title: 'Watch for dealbreakers',
                body:
                    'A ⚠ means one answer will disqualify the lead. We always confirm before saving it.',
                target: '__dealbreaker_question__',
                placement: 'top',
                width: 'standard'
            }
        ]
    },
    {
        id: 'scoring',
        version: 2,
        title: 'How scoring works',
        summary: 'Points, tiers, and what High / Medium / Low means.',
        icon: 'utility:rating',
        steps: [
            {
                id: 'scoring-what',
                title: 'Each answer is worth points',
                body: 'One answer earns the question\'s points. The other earns zero.',
                placement: 'center',
                width: 'standard'
            },
            {
                id: 'scoring-tier',
                title: 'Points become a tier',
                body: 'Totals map to Low / Medium / High. Admins set the cutoffs.',
                target: '[data-tour="lead-quality"]',
                placement: 'bottom',
                width: 'standard'
            },
            {
                id: 'scoring-live',
                title: 'Live updates',
                body: 'Change an answer, the score updates. Safe to experiment.',
                target: '[data-tour="progress"]',
                placement: 'bottom',
                width: 'standard'
            }
        ]
    },
    {
        id: 'dealbreakers',
        version: 2,
        title: 'Dealbreaker questions',
        summary: 'Questions that can disqualify a lead outright.',
        icon: 'utility:warning',
        steps: [
            {
                id: 'dealbreaker-what',
                title: 'This one\'s a dealbreaker',
                body:
                    'Questions marked ⚠ disqualify the lead instantly if answered the wrong way — regardless of score.',
                target: '__dealbreaker_question__',
                placement: 'top',
                width: 'standard'
            },
            {
                id: 'dealbreaker-confirm',
                title: 'We always confirm first',
                body: 'You\'ll get a prompt before any disqualifying answer saves. No accidents.',
                placement: 'center',
                width: 'standard'
            },
            {
                id: 'dealbreaker-reversible',
                title: 'And it\'s reversible',
                body: 'Change your answer later and the lead comes back. History is logged.',
                placement: 'center',
                width: 'standard'
            }
        ]
    },
    {
        id: 'recommended-action',
        version: 2,
        title: 'Recommended action',
        summary: 'Why we suggest convert, review, or nurture.',
        icon: 'utility:success',
        steps: [
            {
                id: 'ra-intro',
                title: 'One-line suggestion',
                body: 'Based on the tier: convert, route to a manager, or nurture.',
                target: '[data-tour="recommended-action"]',
                placement: 'bottom',
                width: 'standard'
            },
            {
                id: 'ra-guidance',
                title: 'Guidance, not a gate',
                body: 'Use your judgment — the wizard informs your call, it doesn\'t block it.',
                target: '[data-tour="recommended-action"]',
                placement: 'bottom',
                width: 'standard'
            }
        ]
    }
];

export default WIZARD_TOURS;
