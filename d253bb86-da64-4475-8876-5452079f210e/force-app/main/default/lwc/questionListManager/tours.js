/**
 * Tours for the Question List Manager.
 *
 * The manager has a "welcome" state (no lists) and a "master-detail" state
 * (with lists). Tours that reference target selectors gracefully fall back to
 * center placement when the target isn't on the page (e.g., the detail panel
 * is hidden in welcome state).
 *
 * Each step may declare a `context` so the host can put the LWC into the
 * right state before the coach measures the step's target. See
 * `_ensureStepContext` in `questionListManager.js` for the supported values:
 *   - 'list-selected'   — pick the first list if none is selected; close
 *                         any tour-opened modals so the page is visible.
 *   - 'list-modal'      — open the New List modal.
 *   - 'question-modal'  — open the New Question modal (and select a list).
 *   - 'scoring-editing' — select a list + put the Scoring Guide into edit
 *                         mode so tier inputs render.
 *   - 'no-modal'        — page-level step; close any tour-opened modals.
 *
 * A tour may also declare a `chain` — an ordered list of tour ids to auto-run
 * after this one completes. Used by the Welcome tour to walk users through
 * every other tour in sequence. Skipping at any point aborts the chain.
 *
 * The legacy `action` field still works for back-compat.
 *
 * Keep body copy skimmable: 1 short sentence where possible, 2 max. Users are
 * busy non-technical admins — they need the gist at a glance.
 *
 * Bump `version` when a tour's content meaningfully changes; users get
 * re-prompted the next time they open the manager.
 */

const MANAGER_TOURS = [
    {
        id: 'intro',
        version: 5,
        title: 'Welcome tour',
        summary: 'Guided walkthrough of every tour, end to end.',
        icon: 'utility:einstein',
        // The Welcome tour chains into every other tour automatically: once
        // this tour's steps end, the host starts each of these in order.
        // Skipping at any point aborts the chain.
        chain: ['lists', 'scoring', 'questions', 'lifecycle'],
        steps: [
            {
                id: 'welcome',
                title: 'Question List Manager',
                body:
                    'Build the qualification playbook your reps see in the wizard. We\'ll walk through everything — lists, scoring, questions, and going live — one tour at a time.',
                placement: 'center',
                width: 'standard',
                context: 'no-modal'
            },
            {
                id: 'lists',
                title: 'Your question lists',
                body: 'Each playbook is a list. Create, switch, or search on the left.',
                target: '[data-tour="lists-panel"]',
                placement: 'right',
                width: 'standard',
                context: 'list-selected'
            },
            {
                id: 'details',
                title: 'List details',
                body:
                    'When you pick a list, its rules, scoring, and questions show here. Below: Assignment Rules, Scoring Guide, and the Question Overview.',
                target: '[data-tour="list-header"]',
                placement: 'bottom',
                width: 'standard',
                context: 'list-selected'
            },
            {
                id: 'replay',
                title: 'Replay anytime',
                body:
                    'Click this info icon to replay any tour. Hit Next and we\'ll dive into Creating a list, Scoring, Questions, and Going Live — back-to-back.',
                target: '[data-tour="info-icon"]',
                placement: 'bottom',
                width: 'standard',
                context: 'list-selected'
            }
        ]
    },
    {
        id: 'lists',
        version: 6,
        title: 'Creating a list',
        summary: 'Walk through every field in the New List modal.',
        icon: 'utility:list',
        // When this tour ends (finish or skip), host should close any modal
        // it opened so the user isn't left staring at an empty draft.
        closeModalOnEnd: 'list',
        steps: [
            {
                id: 'lists-intro',
                title: 'A list is a playbook',
                body:
                    'Each list has a name, point thresholds, and recommended actions. We\'ll open the New List modal so you can see them.',
                placement: 'center',
                width: 'standard',
                context: 'no-modal'
            },
            {
                id: 'lists-new-button',
                title: 'Click + to start',
                body: 'This is how you create a new list at any time.',
                target: '[data-tour="new-list-button"]',
                placement: 'right',
                width: 'standard',
                context: 'no-modal'
            },
            {
                id: 'list-modal-name',
                title: 'Give it a name',
                body: 'Pick something your team will recognize — e.g. "UK Enterprise Leads".',
                target: '[data-tour="list-modal-name"]',
                placement: 'bottom',
                width: 'standard',
                context: 'list-modal'
            },
            {
                id: 'list-modal-high',
                title: 'High Quality tier',
                body:
                    'Set the minimum points for a hot lead, the label reps see, and what they should do (e.g. convert now).',
                target: '[data-tour="list-modal-high-tier"]',
                placement: 'top',
                width: 'standard',
                context: 'list-modal'
            },
            {
                id: 'list-modal-medium',
                title: 'Medium Quality tier',
                body:
                    'The warm zone — between the High threshold above and this minimum. Usually routed to a manager for review.',
                target: '[data-tour="list-modal-medium-tier"]',
                placement: 'top',
                width: 'standard',
                context: 'list-modal'
            },
            {
                id: 'list-modal-low',
                title: 'Low Quality tier',
                body:
                    'Everything below Medium. Common actions: Nurture, or Do Not Convert.',
                target: '[data-tour="list-modal-low-tier"]',
                placement: 'top',
                width: 'standard',
                context: 'list-modal'
            },
            {
                id: 'list-modal-finish',
                title: 'Hit Save to create the list',
                body:
                    'You can edit thresholds and labels later from the list\'s detail panel. Closing this walkthrough discards the draft.',
                target: '[data-tour="list-modal-save"]',
                placement: 'top',
                width: 'standard',
                context: 'list-modal'
            }
        ]
    },
    {
        id: 'scoring',
        version: 4,
        title: 'Scoring thresholds',
        summary: 'Walk every field in the Scoring Guide editor.',
        icon: 'utility:rating',
        // When this tour ends (finish or skip), host should exit scoring edit
        // mode if the tour was the one that opened it.
        closeScoringEditOnEnd: true,
        steps: [
            {
                id: 'scoring-what',
                title: 'Points add up to a tier',
                body:
                    'Every active question contributes points. Thresholds decide where a lead lands: Low, Medium, or High.',
                target: '[data-tour="scoring-guide"]',
                placement: 'top',
                width: 'standard',
                context: 'list-selected'
            },
            {
                id: 'scoring-edit',
                title: 'Hit Edit to tune the guide',
                body:
                    'Edit lets you change thresholds, the labels reps see, and the recommended action for each tier. We\'ll open it for you next.',
                target: '[data-tour="scoring-edit-button"]',
                placement: 'left',
                width: 'standard',
                context: 'list-selected'
            },
            {
                id: 'scoring-min-score',
                title: 'Minimum Score sets the floor',
                body:
                    'A lead scoring this or higher lands in the High tier. Pick it based on the Active Points total below — e.g. if your questions add up to 10, a High floor of 7 means "answered most of the high-value questions right".',
                target: '[data-tour="scoring-edit-high-min"]',
                placement: 'bottom',
                width: 'wide',
                context: 'scoring-editing'
            },
            {
                id: 'scoring-label',
                title: 'Display Label is what reps see',
                body:
                    'The badge in the wizard for this tier — "Hot Lead", "Qualified", "Priority". Short and specific beats generic.',
                target: '[data-tour="scoring-edit-high-label"]',
                placement: 'bottom',
                width: 'standard',
                context: 'scoring-editing'
            },
            {
                id: 'scoring-recommendation',
                title: 'Recommendation tells them what to do',
                body:
                    'The suggested action rendered alongside the badge — "Convert to Opportunity", "Book a demo", "Schedule discovery". This is the nudge that closes the loop.',
                target: '[data-tour="scoring-edit-high-reco"]',
                placement: 'top',
                width: 'standard',
                context: 'scoring-editing'
            },
            {
                id: 'scoring-low-tier',
                title: 'Low has no minimum',
                body:
                    'Low is the catch-all: anything below the Medium threshold lands here. Only Label and Recommendation are editable — common choices are "Nurture" or "Do Not Convert".',
                target: '[data-tour="scoring-edit-low-tier"]',
                placement: 'top',
                width: 'standard',
                context: 'scoring-editing'
            },
            {
                id: 'scoring-save',
                title: 'Save Changes to apply',
                body:
                    'Save updates this list\'s guide immediately. Closing this walkthrough keeps your current values — nothing is saved until you click here yourself.',
                target: '[data-tour="scoring-edit-save"]',
                placement: 'left',
                width: 'standard',
                context: 'scoring-editing'
            }
        ]
    },
    {
        id: 'questions',
        version: 7,
        title: 'Building a question',
        summary: 'Walk through every field in the New Question modal.',
        icon: 'utility:questions_and_answers',
        closeModalOnEnd: 'question',
        steps: [
            {
                id: 'questions-intro',
                title: 'A question is a scorable prompt',
                body:
                    'Reps answer each one in the wizard. We\'ll open the New Question modal so you can see every field.',
                placement: 'center',
                width: 'standard',
                context: 'list-selected'
            },
            {
                id: 'questions-new-row',
                title: 'Add a new question',
                body:
                    'The "Add New Question" row at the bottom of any list opens the modal. We\'ll open it for you next.',
                target: '[data-tour="new-question-row"]',
                placement: 'top',
                width: 'standard',
                context: 'list-selected'
            },
            {
                id: 'question-modal-text',
                title: 'Write the question',
                body:
                    'Keep it clear and Yes/No-friendly — e.g. "Does the lead have budget confirmed?".',
                target: '[data-tour="question-modal-text"]',
                placement: 'bottom',
                width: 'standard',
                context: 'question-modal'
            },
            {
                id: 'question-modal-score',
                title: 'Points if answered the right way',
                body: 'How much this question contributes to the total score.',
                target: '[data-tour="question-modal-score"]',
                placement: 'bottom',
                width: 'standard',
                context: 'question-modal'
            },
            {
                id: 'question-modal-earning',
                title: 'Which answer earns the points',
                body:
                    'Yes, No, or Both. "Both" means either answer earns the points — useful when you just need confirmation.',
                target: '[data-tour="question-modal-earning"]',
                placement: 'bottom',
                width: 'standard',
                context: 'question-modal'
            },
            {
                id: 'question-modal-active',
                title: 'Only Active questions reach reps',
                body:
                    'The wizard skips inactive questions, so untoggle to retire one without deleting it (history is kept). Inactive questions don\'t count toward the score either.',
                target: '[data-tour="question-modal-active"]',
                placement: 'bottom',
                width: 'standard',
                context: 'question-modal'
            },
            {
                id: 'question-modal-dealbreaker',
                title: 'Dealbreaker (optional)',
                body:
                    'Toggle this on to mark the question as a dealbreaker — a specific answer will then auto-disqualify the lead.',
                target: '[data-tour="question-modal-dealbreaker"]',
                placement: 'top',
                width: 'standard',
                context: 'question-modal'
            },
            {
                id: 'question-modal-dealbreaker-value',
                title: 'Pick the disqualifying answer',
                body:
                    'This is the answer that triggers disqualification. If a rep picks it the lead is marked Not Qualified — they get a confirmation prompt first.',
                target: '[data-tour="question-modal-dealbreaker-value"]',
                placement: 'top',
                width: 'standard',
                // Forces Is Dealbreaker on so this combobox is rendered.
                context: 'question-modal-dealbreaker'
            },
            {
                id: 'question-modal-finish',
                title: 'Save to add it to the list',
                body:
                    'The new question appears in this list\'s table and rolls into your scoring. Closing this walkthrough discards the draft.',
                target: '[data-tour="question-modal-save"]',
                placement: 'top',
                width: 'standard',
                context: 'question-modal'
            }
        ]
    },
    {
        id: 'lifecycle',
        version: 1,
        title: 'Going Live',
        summary: 'How a list reaches reps in the wizard.',
        icon: 'utility:broadcast',
        steps: [
            {
                id: 'lifecycle-intro',
                title: 'Lists go Live for the wizard',
                body:
                    'Reps only see Live lists in the wizard. Going Live takes three things: questions, scoring, and assignment rules.',
                placement: 'center',
                width: 'standard',
                context: 'list-selected'
            },
            {
                id: 'lifecycle-assignment',
                title: 'Assignment rules come from Tribal',
                body:
                    'Who-gets-which-list is configured in code by Tribal — not editable here. The badge tells you the state: Criteria-Based, Default Fallback, or No Criteria Set.',
                target: '[data-tour="assignment-rules"]',
                placement: 'bottom',
                width: 'standard',
                context: 'list-with-rules-expanded'
            },
            {
                id: 'lifecycle-live',
                title: 'Flip Live to publish',
                body:
                    'Only Live lists appear in the wizard. A list can\'t go Live without assignment rules (unless it\'s the Default Fallback) — ask Tribal to wire them up first.',
                target: '[data-tour="list-status-toggle"]',
                placement: 'bottom',
                width: 'standard',
                context: 'list-with-rules-expanded'
            }
        ]
    }
];

export default MANAGER_TOURS;
