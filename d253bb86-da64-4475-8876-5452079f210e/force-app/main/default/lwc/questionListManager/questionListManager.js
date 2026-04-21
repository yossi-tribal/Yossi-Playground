import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import USER_ID from '@salesforce/user/Id';
import managerTours from './tours';
import { legacyActionToContext, advanceChain } from './tourOrchestration';
import { buildAdminRequestText, copyTextToClipboard } from './adminRequest';
import {
    listHasQuestions,
    canListGoLive,
    listActivationBlockReason
} from './listStatus';
import getAllQuestionLists from '@salesforce/apex/LQW_QuestionListManagerCtrl.getAllQuestionLists';
import saveQuestionList from '@salesforce/apex/LQW_QuestionListManagerCtrl.saveQuestionList';
import deleteQuestionList from '@salesforce/apex/LQW_QuestionListManagerCtrl.deleteQuestionList';
import saveQuestion from '@salesforce/apex/LQW_QuestionListManagerCtrl.saveQuestion';
import deleteQuestion from '@salesforce/apex/LQW_QuestionListManagerCtrl.deleteQuestion';
import bulkUpdateQuestionStatus from '@salesforce/apex/LQW_QuestionListManagerCtrl.bulkUpdateQuestionStatus';
import cloneQuestionList from '@salesforce/apex/LQW_QuestionListManagerCtrl.cloneQuestionList';
import getPointEarningAnswerPicklistValues from '@salesforce/apex/LQW_QuestionListManagerCtrl.getPointEarningAnswerPicklistValues';
import getDealbreakerValuePicklistValues from '@salesforce/apex/LQW_QuestionListManagerCtrl.getDealbreakerValuePicklistValues';
import detectCriteriaConflicts from '@salesforce/apex/LQW_QuestionListManagerCtrl.detectCriteriaConflicts';
import reorderQuestions from '@salesforce/apex/LQW_QuestionListManagerCtrl.reorderQuestions';
import createDefaultQuestionList from '@salesforce/apex/LQW_QuestionListManagerCtrl.createDefaultQuestionList';

export default class QuestionListManager extends LightningElement {
    @track questionLists = [];
    // True once the @wire has resolved at least once. Used to gate the
    // welcome empty state so it doesn't flash on initial page load before
    // the wire returns.
    @track questionListsLoaded = false;
    @track selectedList = null;
    @track selectedQuestion = null;
    @track isLoading = false;
    @track showListModal = false;
    @track showQuestionModal = false;
    @track showCloneModal = false;
    @track showConflictModal = false;
    @track searchTerm = '';
    @track error = null;
    @track isScoringGuideEditing = false;
    @track scoringGuideForm = {};
    @track detectedConflicts = null;
    @track isAssignmentRulesExpanded = false;

    // Drag and drop state
    @track draggedQuestionId = null;
    @track dragOverQuestionId = null;

    // Form fields for list
    @track listFormData = {
        listId: null,
        listName: '',
        description: '',
        isActive: false,
        highQualityThreshold: 5,
        mediumQualityThreshold: 3,
        highQualityLabel: 'High Quality',
        mediumQualityLabel: 'Medium Quality',
        lowQualityLabel: 'Low Quality',
        highQualityRecommendation: 'Convert to Opportunity',
        mediumQualityRecommendation: 'Convert to Opportunity with Manager Review',
        lowQualityRecommendation: 'Nurture Lead (Do Not Convert)'
    };

    // Form fields for question
    @track questionFormData = {
        questionId: null,
        questionText: '',
        scoreValue: 1,
        pointEarningAnswer: 'Both',
        isDealbreaker: false,
        dealbreakerValue: null,
        isActive: true
    };

    @track cloneListName = '';

    pointEarningAnswerOptions = [];
    dealbreakerValueOptions = [];
    wiredQuestionListsResult;

    // Onboarding coach wiring. Tours are imported as pure data from tours.js
    // and augmented here with onEnter callbacks keyed off each step's
    // `action` metadata (e.g. 'openListModal'). This keeps tour copy
    // declarative while allowing steps to open modals before the coach
    // measures their targets.
    currentUserId = USER_ID;
    _coachBootstrapped = false;
    // Tracks which modal (if any) a tour opened, so we can close it when the
    // tour ends (complete or skip) — the user just watched a walkthrough,
    // they shouldn't be left staring at an empty draft.
    _tourOpenedModal = null;
    // Tracks whether a tour put the Scoring Guide into edit mode so we can
    // exit that mode on tour end without clobbering user-opened edits.
    _tourOpenedScoringEdit = false;
    // Active tour chain (e.g., Welcome tour walks into every other tour).
    // Populated by handleTourSelect / autoStartIfUnseen when a tour with a
    // `chain` field starts, advanced on complete, aborted on skip.
    _activeChain = null;
    _chainIndex = 0;

    // On narrow viewports the list panel is presented as an off-canvas
    // drawer instead of a persistent sidebar. The CSS handles layout;
    // this flag just toggles the class that reveals the drawer.
    @track _mobileListOpen = false;

    // Flips true for a couple of seconds after the admin handoff button is
    // clicked so we can swap the label/icon to a "Copied" confirmation.
    @track _adminRequestCopied = false;
    _adminRequestCopiedTimeout = null;

    get tours() {
        return managerTours.map((tour) => ({
            ...tour,
            steps: tour.steps.map((step) => this._augmentStep(tour, step))
        }));
    }

    /**
     * Each tour step declares the host context it needs via `step.context`
     * (and/or the legacy `step.action`). We attach an `onEnter` callback
     * that puts the LWC into that state — selecting a list, opening a
     * modal, etc. — *before* the coach measures the step's target. This is
     * what lets a step like "List details" actually point at a populated
     * details panel instead of the empty-selection placeholder.
     *
     * Supported context values:
     *   'list-selected'              — make sure a list is selected; close
     *                                   any tour-opened modals.
     *   'list-with-rules-expanded'   — list selected + Assignment Rules
     *                                   section expanded (so the lifecycle
     *                                   tour can point at populated rules).
     *   'list-modal'                 — open the New List modal (closes
     *                                   question modal if it was open).
     *   'question-modal'             — make sure a list is selected, open
     *                                   the New Question modal.
     *   'question-modal-dealbreaker' — like 'question-modal', but also flips
     *                                   Is Dealbreaker on so the
     *                                   Dealbreaker Value combobox renders.
     *   'scoring-editing'            — list selected + Scoring Guide in
     *                                   edit mode (so tier inputs render
     *                                   and the tour can target them).
     *   'no-modal'                   — page-level step; close any
     *                                   tour-opened modals.
     *
     * Legacy `action` values are mapped to the matching context.
     */
    _augmentStep(tour, step) {
        const context = step.context || legacyActionToContext(step.action);
        if (!context) return step;
        const handler = () => this._ensureStepContext(context);
        return { ...step, onEnter: handler };
    }

    _ensureStepContext(context) {
        switch (context) {
            case 'list-modal':
                this._closeQuestionModalIfTourOpened();
                this._closeScoringEditIfTourOpened();
                this._ensureListModalOpen();
                break;
            case 'question-modal':
                this._closeListModalIfTourOpened();
                this._closeScoringEditIfTourOpened();
                this._ensureQuestionModalOpen();
                break;
            case 'question-modal-dealbreaker':
                this._closeListModalIfTourOpened();
                this._closeScoringEditIfTourOpened();
                this._ensureQuestionModalOpen();
                // Flip Is Dealbreaker on so the Dealbreaker Value combobox
                // renders and the tour can point at it. Wrapped in a
                // new-object assignment so LWC reactivity picks it up.
                if (!this.questionFormData.isDealbreaker) {
                    this.questionFormData = {
                        ...this.questionFormData,
                        isDealbreaker: true
                    };
                }
                break;
            case 'list-selected':
                this._closeListModalIfTourOpened();
                this._closeQuestionModalIfTourOpened();
                this._closeScoringEditIfTourOpened();
                this._ensureListSelected();
                break;
            case 'list-with-rules-expanded':
                this._closeListModalIfTourOpened();
                this._closeQuestionModalIfTourOpened();
                this._closeScoringEditIfTourOpened();
                this._ensureListSelected();
                this.isAssignmentRulesExpanded = true;
                break;
            case 'scoring-editing':
                this._closeListModalIfTourOpened();
                this._closeQuestionModalIfTourOpened();
                this._ensureListSelected();
                this._ensureScoringEditOpen();
                break;
            case 'no-modal':
            default:
                this._closeListModalIfTourOpened();
                this._closeQuestionModalIfTourOpened();
                this._closeScoringEditIfTourOpened();
                break;
        }
    }

    _ensureListSelected() {
        if (!this.selectedList && this.questionLists.length > 0) {
            this.selectedList = this.questionLists[0];
        }
    }

    _ensureListModalOpen() {
        if (!this.showListModal) {
            this.handleNewList();
            this._tourOpenedModal = 'list';
        }
    }

    _ensureQuestionModalOpen() {
        this._ensureListSelected();
        if (!this.selectedList) return;
        if (!this.showQuestionModal) {
            this.handleNewQuestion();
            this._tourOpenedModal = 'question';
        }
    }

    _closeListModalIfTourOpened() {
        if (this.showListModal && this._tourOpenedModal === 'list') {
            this.showListModal = false;
            this._tourOpenedModal = null;
        }
    }

    _closeQuestionModalIfTourOpened() {
        if (this.showQuestionModal && this._tourOpenedModal === 'question') {
            this.showQuestionModal = false;
            this._tourOpenedModal = null;
        }
    }

    _ensureScoringEditOpen() {
        if (!this.selectedList) return;
        if (!this.isScoringGuideEditing) {
            this.handleEditScoringGuide();
            this._tourOpenedScoringEdit = true;
        }
    }

    _closeScoringEditIfTourOpened() {
        if (this.isScoringGuideEditing && this._tourOpenedScoringEdit) {
            this.handleCancelScoringGuideEdit();
            this._tourOpenedScoringEdit = false;
        }
    }

    _cleanupTourSideEffects() {
        // Close whichever modal / edit surface the tour opened. If the user
        // opened something themselves (e.g. by navigating back through the
        // tour) we still close it — tours are meant to be non-destructive
        // walkthroughs, nothing should persist.
        if (this._tourOpenedModal === 'list') {
            this.showListModal = false;
        } else if (this._tourOpenedModal === 'question') {
            this.showQuestionModal = false;
        }
        this._tourOpenedModal = null;
        if (this._tourOpenedScoringEdit) {
            this.handleCancelScoringGuideEdit();
            this._tourOpenedScoringEdit = false;
        }
    }

    handleTourComplete(event) {
        const finishedId = event?.detail?.tourId;
        // If this tour is part of an active chain (or starts one), advance
        // to the next tour before cleaning up side effects — the next tour
        // may need a clean slate (e.g. Creating-a-list expects no scoring
        // edit open) but it will set its own context on its first step.
        const nextTourId = this._nextChainedTour(finishedId);
        this._cleanupTourSideEffects();
        if (nextTourId) {
            // Defer a frame so the coach finishes its own teardown before
            // we ask it to start the next tour. Without this we can race
            // its `stop()` → new startTour → layout sequence.
            window.requestAnimationFrame(() => this._startChainedTour(nextTourId));
        }
    }

    handleTourSkip() {
        // Skipping aborts any in-flight chain — the user signalled "enough".
        this._activeChain = null;
        this._chainIndex = 0;
        this._cleanupTourSideEffects();
    }

    /**
     * Return the id of the next tour to run after `finishedId` finishes,
     * or null if there is none. Delegates the decision logic to the pure
     * `advanceChain` helper (see `tourOrchestration.js`) and just writes
     * the returned state back to the component.
     */
    _nextChainedTour(finishedId) {
        const current = {
            activeChain: this._activeChain,
            chainIndex: this._chainIndex
        };
        const { state, nextId } = advanceChain(current, finishedId, managerTours);
        this._activeChain = state.activeChain;
        this._chainIndex = state.chainIndex;
        return nextId;
    }

    _startChainedTour(tourId) {
        const coach = this.refs?.coach;
        if (!coach) {
            this._activeChain = null;
            this._chainIndex = 0;
            return;
        }
        coach.startTour(tourId, { force: true });
    }

    connectedCallback() {
        this.loadPicklistValues();
        this.loadConflictDetection();
        this._hideAppPageHeader();
    }

    /**
     * Hide the App Page banner Salesforce auto-renders above this LWC (icon
     * + tab label). That banner lives outside our shadow root, so the
     * component CSS file can't touch it. This uses a portable two-layer
     * approach so it survives both LWS sandboxing and future Salesforce
     * markup changes:
     *
     *   Layer 1: inject a global stylesheet hiding every known SLDS / Aura
     *            page-header class. Fast, idempotent, allowed under LWS.
     *   Layer 2: walk the DOM outside our shadow root (crossing shadow
     *            boundaries via getRootNode().host) and hide siblings that
     *            look like a page header but slipped through Layer 1.
     *
     * IMPORTANT: this LWC's own header MUST NOT use the .slds-page-header
     * class, or Layer 1 would hide it too. We use .manager-header instead.
     *
     * Layer 2 fires three times (0 / 200 / 800ms) because Salesforce sometimes
     * re-renders the header asynchronously after we mount. There's no
     * disconnectedCallback cleanup on purpose — leaving the global style in
     * place avoids a brief flash of the header during Aura nav transitions
     * where the old LWC unmounts a moment before the new one mounts.
     */
    _hideAppPageHeader() {
        if (typeof document === 'undefined') return;
        try {
            const STYLE_ID = 'qlm-hide-app-page-header';
            if (!document.getElementById(STYLE_ID)) {
                const style = document.createElement('style');
                style.id = STYLE_ID;
                style.textContent = [
                    '.slds-page-header',
                    '.slds-page-header_joined',
                    '.forceAppBuilderAppPageHeader',
                    '.appBuilderPageHeader',
                    '.appPageHeader',
                    '.entityNameTitle',
                    '.entityHeader',
                    '.forceCommunityThemeLayout .slds-page-header',
                    '.oneCenterStage > .slds-page-header',
                    'div[data-component-id="flexipage_appHomeTemplateDesktop"] > .slds-page-header',
                    'div[data-aura-class*="AppHomeTemplate"] > .slds-page-header',
                    'div[data-aura-class*="appBuilderTabset"] > :first-child',
                    'div[data-component-id*="appHomeTemplate"] > div:first-child'
                ].join(',\n') + '{display:none !important;}';
                document.head.appendChild(style);
            }
        } catch (_) { /* hardened context — ignore */ }

        // Fire the DOM-walk fallback now and again on a couple of delays so we
        // catch the App Page header on its late re-render.
        this._walkAndHideHeaderSiblings();
        setTimeout(() => this._walkAndHideHeaderSiblings(), 200);
        setTimeout(() => this._walkAndHideHeaderSiblings(), 800);
        setTimeout(() => this._walkAndHideHeaderSiblings(), 2000);
    }

    _walkAndHideHeaderSiblings() {
        if (typeof document === 'undefined') return;
        const HEADER_CLASS_RE = /page.?header|PageHeader|highlightsPanel|entityNameTitle|entityHeader|appBuilder/i;
        const APP_PAGE_LABEL = 'Question List Manager';
        const MAX_HOPS = 15;
        try {
            const host = this.template?.host;
            if (!host) return;

            const isSelfOrInside = (el, refSet) => {
                for (const ref of refSet) {
                    if (ref === el || ref.contains(el) || el.contains(ref)) return true;
                }
                return false;
            };

            // Hide the H1 itself and at most one immediate wrapper (the band
            // that holds the icon next to it). Stay extremely conservative:
            // never walk into anything tall enough to be a layout container,
            // because hiding those creates phantom click-intercepts.
            const hideHeadingBand = (heading, stopAt) => {
                try { heading.style.display = 'none'; } catch (_) { /* read-only */ }
                const direct = heading.parentElement;
                if (!direct || direct === stopAt) return;
                const r = direct.getBoundingClientRect();
                if (r.height > 0 && r.height <= 100) {
                    try { direct.style.display = 'none'; } catch (_) { /* read-only */ }
                }
            };

            // Build set of nodes we never want to hide (self + every ancestor
            // host across shadow boundaries).
            const ancestors = new Set();
            let node = host;
            for (let i = 0; i < MAX_HOPS && node; i++) {
                ancestors.add(node);
                const root = node.getRootNode && node.getRootNode();
                node = (node.parentElement)
                    || (root && root.host)
                    || null;
            }

            // Walk up again, this time scanning each parent's children for
            // anything header-shaped.
            node = host;
            for (let i = 0; i < MAX_HOPS && node; i++) {
                const parent = node.parentElement
                    || (node.getRootNode && node.getRootNode().host);
                if (!parent || !parent.querySelectorAll) {
                    node = parent;
                    continue;
                }
                const candidates = parent.querySelectorAll('*');
                for (const el of candidates) {
                    if (isSelfOrInside(el, ancestors)) continue;
                    const cls = String(el.getAttribute && el.getAttribute('class') || '');
                    const role = el.getAttribute && el.getAttribute('role');
                    const tag = el.tagName;
                    const isLevel1Heading = tag === 'H1'
                        || (role === 'heading' && el.getAttribute('aria-level') === '1');
                    const matchesByText = isLevel1Heading
                        && (el.textContent || '').trim() === APP_PAGE_LABEL;
                    const looksLikeHeader = HEADER_CLASS_RE.test(cls) || role === 'banner';
                    if (matchesByText) {
                        // Found the App Page label heading — hide its visible band.
                        hideHeadingBand(el, parent);
                        continue;
                    }
                    if (!looksLikeHeader) continue;
                    try { el.style.display = 'none'; } catch (_) { /* SVG style is read-only sometimes */ }
                }
                node = parent;
            }
        } catch (_) { /* hardened context — ignore */ }
    }

    renderedCallback() {
        // Only bootstrap the onboarding coach once at least one Question List
        // is on screen. The welcome (no-lists) state has nothing meaningful to
        // walk through, so we keep the coach unmounted until then. The coach
        // element itself is also gated by lwc:if={hasQuestionLists} in the
        // template, so this.refs.coach is null until lists arrive.
        if (this._coachBootstrapped) return;
        if (!this.hasQuestionLists) return;
        const coach = this.refs?.coach;
        if (!coach) return;
        this._coachBootstrapped = true;
        coach.setTargetResolver((selector) => {
            if (!selector) return null;
            try {
                return this.template.querySelector(selector);
            } catch (e) {
                return null;
            }
        });
        coach.autoStartIfUnseen('intro');
    }

    handleTourSelect(event) {
        const tourId = event?.detail?.tourId;
        if (!tourId) return;
        const coach = this.refs?.coach;
        if (!coach) return;
        // Reset any in-flight chain — the user explicitly picked a new tour,
        // so we don't want a stale Welcome chain to flow through afterwards.
        this._activeChain = null;
        this._chainIndex = 0;
        coach.startTour(tourId, { force: true });
    }

    @wire(getAllQuestionLists)
    wiredQuestionLists(result) {
        this.wiredQuestionListsResult = result;
        if (result.data) {
            this.questionLists = result.data;
            this.error = null;
            this.questionListsLoaded = true;
            // If a list was selected, re-select it after refresh
            if (this.selectedList) {
                const updatedList = this.questionLists.find(list => list.listId === this.selectedList.listId);
                if (updatedList) {
                    this.selectedList = updatedList;
                }
            }
        } else if (result.error) {
            this.error = result.error;
            this.questionLists = [];
            this.questionListsLoaded = true;
            this.showToast('Error', 'Failed to load question lists', 'error');
        }
    }

    async loadPicklistValues() {
        try {
            const [pointEarningAnswers, dealbreakerValues] = await Promise.all([
                getPointEarningAnswerPicklistValues(),
                getDealbreakerValuePicklistValues()
            ]);
            this.pointEarningAnswerOptions = pointEarningAnswers;
            this.dealbreakerValueOptions = dealbreakerValues;
        } catch (error) {
            console.error('Error loading picklist values:', error);
        }
    }

    get filteredQuestionLists() {
        let lists = this.questionLists;
        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            lists = lists.filter(list =>
                list.listName?.toLowerCase().includes(term) ||
                list.description?.toLowerCase().includes(term)
            );
        }
        // Add selected class to each list for styling
        return lists.map(list => {
            return {
                ...list,
                itemClass: list.listId === this.selectedList?.listId ? 'list-item-wrapper selected' : 'list-item-wrapper'
            };
        });
    }

    get hasQuestionLists() {
        return this.questionLists && this.questionLists.length > 0;
    }

    // Show the welcome state only after the wire has resolved AND it confirmed
    // the user has zero lists. Prevents a brief flash of the welcome state on
    // initial page load before the @wire fulfills.
    get showWelcomeState() {
        return this.questionListsLoaded && !this.hasQuestionLists;
    }

    get selectedListQuestions() {
        return this.selectedList?.questions || [];
    }

    get displayQuestions() {
        const questions = this.selectedList?.questions || [];
        let displayOrder = 1;

        return questions.map((question) => {
            const displayQuestion = { ...question };

            // Assign sequential display order only to active questions
            if (question.isActive) {
                displayQuestion.displayOrder = displayOrder;
                displayQuestion.displayOrderText = String(displayOrder);
                displayOrder++;
            } else {
                displayQuestion.displayOrder = null;
                displayQuestion.displayOrderText = '—';
            }

            // Add CSS classes for styling
            displayQuestion.isInactive = !question.isActive;
            displayQuestion.isDraggable = question.isActive;
            displayQuestion.rowClass = 'table-row' +
                (this.draggedQuestionId === question.questionId ? ' dragging' : '') +
                (this.dragOverQuestionId === question.questionId ? ' drag-over' : '') +
                (!question.isActive ? ' inactive-row' : '');
            displayQuestion.cardClass = 'question-card' + (!question.isActive ? ' question-card-inactive' : '');
            displayQuestion.numberBadgeClass = question.isActive ? 'question-number-badge' : 'question-number-badge-inactive';

            return displayQuestion;
        });
    }

    get hasSelectedList() {
        return this.selectedList !== null;
    }

    get hasQuestions() {
        return this.selectedListQuestions.length > 0;
    }

    get selectedListSummary() {
        if (!this.selectedList) return '';
        return `${this.selectedList.activeQuestions} of ${this.selectedList.totalQuestions} questions active | ${this.selectedList.totalPossiblePoints} total points | ${this.selectedList.dealbreakerCount} dealbreakers`;
    }

    get avgPointsPerQuestion() {
        if (!this.selectedList || this.selectedList.activeQuestions === 0) return 0;
        return (this.selectedList.totalPossiblePoints / this.selectedList.activeQuestions).toFixed(1);
    }

    get totalActivePoints() {
        if (!this.selectedList || !this.selectedList.questions) return 0;
        return this.selectedList.questions
            .filter(q => q.isActive)
            .reduce((sum, q) => sum + (q.scoreValue || 0), 0);
    }

    get activeDealbreakers() {
        if (!this.selectedList || !this.selectedList.questions) return 0;
        return this.selectedList.questions
            .filter(q => q.isActive && q.isDealbreaker)
            .length;
    }

    get scoringTiers() {
        if (!this.selectedList) return [];
        return [
            {
                key: 'high',
                label: this.selectedList.highQualityLabel || 'High Quality',
                threshold: this.selectedList.highQualityThreshold || 5,
                recommendation: this.selectedList.highQualityRecommendation || 'Convert to Opportunity',
                color: 'success',
                icon: 'utility:success',
                cssClass: 'tier-high'
            },
            {
                key: 'medium',
                label: this.selectedList.mediumQualityLabel || 'Medium Quality',
                threshold: this.selectedList.mediumQualityThreshold || 3,
                recommendation: this.selectedList.mediumQualityRecommendation || 'Convert to Opportunity with Manager Review',
                color: 'warning',
                icon: 'utility:warning',
                cssClass: 'tier-medium'
            },
            {
                key: 'low',
                label: this.selectedList.lowQualityLabel || 'Low Quality',
                threshold: 0,
                recommendation: this.selectedList.lowQualityRecommendation || 'Nurture Lead (Do Not Convert)',
                color: 'error',
                icon: 'utility:error',
                cssClass: 'tier-low'
            }
        ];
    }

    get thresholdValidationMessage() {
        const high = parseFloat(this.listFormData.highQualityThreshold);
        const medium = parseFloat(this.listFormData.mediumQualityThreshold);
        const isNewList = this.listFormData.listId === null;
        const totalPoints = this.selectedList ? this.selectedList.totalPossiblePoints : 0;

        if (high <= medium) {
            return 'High threshold must be greater than Medium threshold';
        }
        // Skip "exceeds total points" validation for new lists since they have no questions yet
        if (!isNewList) {
            if (high > totalPoints && totalPoints > 0) {
                return `High threshold exceeds total possible points (${totalPoints})`;
            }
            if (medium > totalPoints && totalPoints > 0) {
                return `Medium threshold exceeds total possible points (${totalPoints})`;
            }
        }
        return null;
    }

    get isThresholdValid() {
        return this.thresholdValidationMessage === null;
    }

    get scoringGuideValidationMessage() {
        const high = parseFloat(this.scoringGuideForm.highQualityThreshold);
        const medium = parseFloat(this.scoringGuideForm.mediumQualityThreshold);
        const totalPoints = this.selectedList ? this.selectedList.totalPossiblePoints : 0;

        if (high <= medium) {
            return 'High threshold must be greater than Medium threshold';
        }
        if (high > totalPoints && totalPoints > 0) {
            return `High threshold (${high}) exceeds total possible points (${totalPoints})`;
        }
        if (medium > totalPoints && totalPoints > 0) {
            return `Medium threshold (${medium}) exceeds total possible points (${totalPoints})`;
        }
        return null;
    }

    get isScoringGuideValid() {
        return this.scoringGuideValidationMessage === null;
    }

    get suggestedHighThreshold() {
        const totalPoints = this.selectedList ? this.selectedList.totalPossiblePoints : 10;
        return Math.round(totalPoints * 0.55);
    }

    get suggestedMediumThreshold() {
        const totalPoints = this.selectedList ? this.selectedList.totalPossiblePoints : 10;
        return Math.round(totalPoints * 0.33);
    }

    get isEditingList() {
        return this.listFormData.listId !== null;
    }

    get isEditingQuestion() {
        return this.questionFormData.questionId !== null;
    }

    get listModalTitle() {
        return this.isEditingList ? 'Edit Question List' : 'New Question List';
    }

    get questionModalTitle() {
        return this.isEditingQuestion ? 'Edit Question' : 'New Question';
    }

    get hasAssignmentCriteria() {
        return this.selectedList && this.selectedList.assignmentCriteria && this.selectedList.assignmentCriteria.trim() !== '';
    }

    get formattedAssignmentCriteria() {
        if (!this.hasAssignmentCriteria) return '';
        try {
            const parsed = JSON.parse(this.selectedList.assignmentCriteria);
            return JSON.stringify(parsed, null, 2);
        } catch {
            return this.selectedList.assignmentCriteria;
        }
    }

    get hasConflicts() {
        if (!this.selectedList || !this.detectedConflicts) return false;

        // Check if current list is involved in any conflict
        const listId = this.selectedList.listId;
        return this.detectedConflicts.conflicts && this.detectedConflicts.conflicts.some(conflict =>
            conflict.list1Id === listId || conflict.list2Id === listId
        );
    }

    get hasDetectedConflicts() {
        return this.detectedConflicts && this.detectedConflicts.hasConflicts;
    }

    get conflictList() {
        if (!this.detectedConflicts || !this.detectedConflicts.conflicts) return [];

        return this.detectedConflicts.conflicts.map((conflict, index) => ({
            key: `conflict-${index}`,
            index: index + 1,
            list1Id: conflict.list1Id,
            list1Name: conflict.list1Name,
            list2Id: conflict.list2Id,
            list2Name: conflict.list2Name,
            conflictDescription: conflict.conflictDescription
        }));
    }

    get assignmentRulesToggleIcon() {
        return this.isAssignmentRulesExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get assignmentRulesToggleTitle() {
        return this.isAssignmentRulesExpanded ? 'Collapse Assignment Rules' : 'Expand Assignment Rules';
    }

    get parsedCriteriaRules() {
        if (!this.hasAssignmentCriteria) return [];
        try {
            const parsed = JSON.parse(this.selectedList.assignmentCriteria);
            if (Array.isArray(parsed)) {
                return parsed.map((rule, index) => ({
                    key: `rule-${index}`,
                    field: rule.field || '',
                    label: rule.label || rule.field || '',
                    operator: rule.operator || '',
                    value: rule.value || '',
                    displayOperator: this.formatOperator(rule.operator),
                    displayValue: this.formatValue(rule.value)
                }));
            }
            return [];
        } catch {
            return [];
        }
    }

    get canActivateList() {
        return canListGoLive(this.selectedList, this.hasAssignmentCriteria);
    }

    get selectedListHasQuestions() {
        return listHasQuestions(this.selectedList);
    }

    get listStatusText() {
        return this.selectedList?.isActive ? 'Live' : 'Off';
    }

    get toggleSwitchClass() {
        return this.selectedList?.isActive ? 'toggle-switch active' : 'toggle-switch';
    }

    get listStatusToggleTitle() {
        if (!this.selectedList) return '';
        if (this.selectedList.isActive) {
            return 'Click to deactivate this list';
        }
        if (this.canActivateList) {
            return 'Click to activate this list';
        }
        if (!this.selectedListHasQuestions) {
            return 'Cannot activate - add at least one question first';
        }
        return 'Cannot activate - no assignment criteria set';
    }

    formatOperator(operator) {
        const operatorMap = {
            'equals': 'equals',
            'notEquals': 'does not equal',
            'contains': 'contains',
            'startsWith': 'starts with',
            'endsWith': 'ends with',
            'greaterThan': '>',
            'lessThan': '<',
            'greaterOrEqual': '≥',
            'lessOrEqual': '≤'
        };
        return operatorMap[operator] || operator;
    }

    formatValue(value) {
        if (value === null || value === undefined) return 'null';
        if (typeof value === 'boolean') return value ? 'True' : 'False';
        return String(value);
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleSelectList(event) {
        const listId = event.currentTarget.dataset.listId;
        this.selectedList = this.questionLists.find(list => list.listId === listId);
        // On mobile the sidebar is a drawer; picking a list should dismiss
        // it so the detail view is immediately visible.
        this._mobileListOpen = false;
    }

    handleOpenMobileList() {
        this._mobileListOpen = true;
    }

    handleCloseMobileList() {
        this._mobileListOpen = false;
    }

    get managerContainerClass() {
        return this._mobileListOpen
            ? 'manager-container manager-container--list-drawer-open'
            : 'manager-container';
    }

    // The empty-state now hosts its own searchable list picker rather than
    // asking the user to discover a sidebar / drawer. Reuses `searchTerm`
    // and `filteredQuestionLists` so typing in either search box stays in
    // sync — no need for a second piece of state.
    get emptyStatePickerLists() {
        return this.filteredQuestionLists;
    }

    get hasFilteredLists() {
        return this.emptyStatePickerLists.length > 0;
    }

    handleClearEmptyStateSearch() {
        this.searchTerm = '';
    }

    // Keyboard access for the empty-state list items: Enter or Space selects
    // the focused list (so the picker isn't mouse-only).
    handleEmptyStatePickerKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ' || event.key === 'Spacebar') {
            event.preventDefault();
            this.handleSelectList(event);
        }
    }

    handleNewList() {
        this.listFormData = {
            listId: null,
            listName: '',
            description: '',
            isActive: false,
            highQualityThreshold: 5,
            mediumQualityThreshold: 3,
            highQualityLabel: 'High Quality',
            mediumQualityLabel: 'Medium Quality',
            lowQualityLabel: 'Low Quality',
            highQualityRecommendation: 'Convert to Opportunity',
            mediumQualityRecommendation: 'Convert to Opportunity with Manager Review',
            lowQualityRecommendation: 'Nurture Lead (Do Not Convert)'
        };
        this.showListModal = true;
    }

    handleEditList() {
        if (!this.selectedList) return;
        this.listFormData = {
            listId: this.selectedList.listId,
            listName: this.selectedList.listName,
            description: this.selectedList.description,
            isActive: this.selectedList.isActive,
            highQualityThreshold: this.selectedList.highQualityThreshold || 5,
            mediumQualityThreshold: this.selectedList.mediumQualityThreshold || 3,
            highQualityLabel: this.selectedList.highQualityLabel || 'High Quality',
            mediumQualityLabel: this.selectedList.mediumQualityLabel || 'Medium Quality',
            lowQualityLabel: this.selectedList.lowQualityLabel || 'Low Quality',
            highQualityRecommendation: this.selectedList.highQualityRecommendation || 'Convert to Opportunity',
            mediumQualityRecommendation: this.selectedList.mediumQualityRecommendation || 'Convert to Opportunity with Manager Review',
            lowQualityRecommendation: this.selectedList.lowQualityRecommendation || 'Nurture Lead (Do Not Convert)'
        };
        this.showListModal = true;
    }

    async handleDeleteList() {
        if (!this.selectedList) return;

        if (!confirm(`Are you sure you want to delete "${this.selectedList.listName}" and all its questions?`)) {
            return;
        }

        this.isLoading = true;
        try {
            const result = await deleteQuestionList({ listId: this.selectedList.listId });
            if (result.success) {
                this.showToast('Success', result.message, 'success');
                this.selectedList = null;
                await refreshApex(this.wiredQuestionListsResult);
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error deleting question list:', error);
            this.showToast('Error', 'Failed to delete question list', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCloneList() {
        if (!this.selectedList) return;
        this.cloneListName = `${this.selectedList.listName} (Copy)`;
        this.showCloneModal = true;
    }

    async handleSaveClone() {
        if (!this.cloneListName || !this.selectedList) return;

        this.isLoading = true;
        try {
            const result = await cloneQuestionList({
                listId: this.selectedList.listId,
                newListName: this.cloneListName
            });
            if (result.success) {
                this.showToast('Success', result.message, 'success');
                this.showCloneModal = false;
                await refreshApex(this.wiredQuestionListsResult);
                // Select the newly cloned list
                const clonedList = this.questionLists.find(list => list.listId === result.recordId);
                if (clonedList) {
                    this.selectedList = clonedList;
                }
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error cloning question list:', error);
            this.showToast('Error', 'Failed to clone question list', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleNewQuestion() {
        if (!this.selectedList) return;
        this.questionFormData = {
            questionId: null,
            questionText: '',
            scoreValue: 1,
            pointEarningAnswer: 'Both',
            isDealbreaker: false,
            dealbreakerValue: null,
            isActive: true
        };
        this.showQuestionModal = true;
    }

    handleEditQuestion(event) {
        const questionId = event.currentTarget.dataset.questionId;
        const question = this.selectedList.questions.find(q => q.questionId === questionId);
        if (!question) return;

        this.questionFormData = {
            questionId: question.questionId,
            questionText: question.questionText,
            scoreValue: question.scoreValue,
            pointEarningAnswer: question.pointEarningAnswer,
            isDealbreaker: question.isDealbreaker,
            dealbreakerValue: question.dealbreakerValue,
            isActive: question.isActive
        };
        this.showQuestionModal = true;
    }

    async handleDeleteQuestion(event) {
        const questionId = event.currentTarget.dataset.questionId;
        const question = this.selectedList.questions.find(q => q.questionId === questionId);

        if (!confirm(`Are you sure you want to delete "${question.questionText}"?`)) {
            return;
        }

        this.isLoading = true;
        try {
            const result = await deleteQuestion({ questionId: questionId });
            if (result.success) {
                this.showToast('Success', result.message, 'success');
                await refreshApex(this.wiredQuestionListsResult);
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error deleting question:', error);
            this.showToast('Error', 'Failed to delete question', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleActivateAll() {
        if (!this.selectedList) return;

        this.isLoading = true;
        try {
            const result = await bulkUpdateQuestionStatus({
                listId: this.selectedList.listId,
                isActive: true
            });
            if (result.success) {
                this.showToast('Success', result.message, 'success');
                await refreshApex(this.wiredQuestionListsResult);
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error activating questions:', error);
            this.showToast('Error', 'Failed to activate questions', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeactivateAll() {
        if (!this.selectedList) return;

        this.isLoading = true;
        try {
            const result = await bulkUpdateQuestionStatus({
                listId: this.selectedList.listId,
                isActive: false
            });
            if (result.success) {
                this.showToast('Success', result.message, 'success');
                await refreshApex(this.wiredQuestionListsResult);
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error deactivating questions:', error);
            this.showToast('Error', 'Failed to deactivate questions', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleListFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.listFormData = { ...this.listFormData, [field]: value };
    }

    handleQuestionFieldChange(event) {
        const field = event.target.dataset.field;
        let value = event.target.value;

        if (event.target.type === 'checkbox') {
            value = event.target.checked;
        } else if (field === 'scoreValue') {
            value = value ? parseInt(value, 10) : null;
        }

        this.questionFormData = { ...this.questionFormData, [field]: value };
    }

    handleCloneNameChange(event) {
        this.cloneListName = event.target.value;
    }

    async handleSaveList() {
        if (!this.isThresholdValid) {
            this.showToast('Validation Error', this.thresholdValidationMessage, 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await saveQuestionList({
                listId: this.listFormData.listId,
                listName: this.listFormData.listName,
                description: this.listFormData.description,
                isActive: this.listFormData.isActive,
                highQualityThreshold: parseFloat(this.listFormData.highQualityThreshold),
                mediumQualityThreshold: parseFloat(this.listFormData.mediumQualityThreshold),
                highQualityLabel: this.listFormData.highQualityLabel,
                mediumQualityLabel: this.listFormData.mediumQualityLabel,
                lowQualityLabel: this.listFormData.lowQualityLabel,
                highQualityRecommendation: this.listFormData.highQualityRecommendation,
                mediumQualityRecommendation: this.listFormData.mediumQualityRecommendation,
                lowQualityRecommendation: this.listFormData.lowQualityRecommendation
            });
            if (result.success) {
                this.showToast('Success', result.message, 'success');
                this.showListModal = false;
                await refreshApex(this.wiredQuestionListsResult);
                // Select the newly created/updated list
                const list = this.questionLists.find(l => l.listId === result.recordId);
                if (list) {
                    this.selectedList = list;
                }
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error saving question list:', error);
            this.showToast('Error', 'Failed to save question list', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSaveQuestion() {
        if (!this.selectedList) return;

        this.isLoading = true;
        try {
            const result = await saveQuestion({
                questionId: this.questionFormData.questionId,
                listId: this.selectedList.listId,
                questionText: this.questionFormData.questionText,
                questionOrder: null,
                scoreValue: this.questionFormData.scoreValue,
                pointEarningAnswer: this.questionFormData.pointEarningAnswer,
                isDealbreaker: this.questionFormData.isDealbreaker,
                dealbreakerValue: this.questionFormData.dealbreakerValue,
                isActive: this.questionFormData.isActive
            });
            if (result.success) {
                this.showToast('Success', result.message, 'success');
                this.showQuestionModal = false;
                await refreshApex(this.wiredQuestionListsResult);
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error saving question:', error);
            this.showToast('Error', 'Failed to save question', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCloseListModal() {
        this.showListModal = false;
    }

    handleCloseQuestionModal() {
        this.showQuestionModal = false;
    }

    handleCloseCloneModal() {
        this.showCloneModal = false;
    }


    handleEditScoringGuide() {
        if (!this.selectedList) return;

        // Initialize form with current values
        this.scoringGuideForm = {
            highQualityThreshold: this.selectedList.highQualityThreshold || 5,
            mediumQualityThreshold: this.selectedList.mediumQualityThreshold || 3,
            highQualityLabel: this.selectedList.highQualityLabel || 'High Quality',
            mediumQualityLabel: this.selectedList.mediumQualityLabel || 'Medium Quality',
            lowQualityLabel: this.selectedList.lowQualityLabel || 'Low Quality',
            highQualityRecommendation: this.selectedList.highQualityRecommendation || 'Convert to Opportunity',
            mediumQualityRecommendation: this.selectedList.mediumQualityRecommendation || 'Convert to Opportunity with Manager Review',
            lowQualityRecommendation: this.selectedList.lowQualityRecommendation || 'Nurture Lead (Do Not Convert)'
        };
        this.isScoringGuideEditing = true;
    }

    handleCancelScoringGuideEdit() {
        this.isScoringGuideEditing = false;
        this.scoringGuideForm = {};
    }

    handleScoringGuideFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'number' ? parseFloat(event.target.value) : event.target.value;
        this.scoringGuideForm = { ...this.scoringGuideForm, [field]: value };
    }

    async handleSaveScoringGuide() {
        if (!this.selectedList) return;

        // Validate before saving
        if (!this.isScoringGuideValid) {
            this.showToast('Validation Error', this.scoringGuideValidationMessage, 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await saveQuestionList({
                listId: this.selectedList.listId,
                listName: this.selectedList.listName,
                description: this.selectedList.description,
                isActive: this.selectedList.isActive,
                highQualityThreshold: parseFloat(this.scoringGuideForm.highQualityThreshold),
                mediumQualityThreshold: parseFloat(this.scoringGuideForm.mediumQualityThreshold),
                highQualityLabel: this.scoringGuideForm.highQualityLabel,
                mediumQualityLabel: this.scoringGuideForm.mediumQualityLabel,
                lowQualityLabel: this.scoringGuideForm.lowQualityLabel,
                highQualityRecommendation: this.scoringGuideForm.highQualityRecommendation,
                mediumQualityRecommendation: this.scoringGuideForm.mediumQualityRecommendation,
                lowQualityRecommendation: this.scoringGuideForm.lowQualityRecommendation
            });
            if (result.success) {
                this.showToast('Success', 'Scoring guide updated successfully', 'success');
                this.isScoringGuideEditing = false;
                this.scoringGuideForm = {};
                await refreshApex(this.wiredQuestionListsResult);
                // Re-select the list to get updated data
                const list = this.questionLists.find(l => l.listId === result.recordId);
                if (list) {
                    this.selectedList = list;
                }
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error saving scoring guide:', error);
            this.showToast('Error', 'Failed to save scoring guide', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadConflictDetection() {
        try {
            const result = await detectCriteriaConflicts();
            this.detectedConflicts = result;

            // Show a toast if conflicts are detected
            if (result.hasConflicts) {
                this.showToast('Warning', `${result.conflicts.length} assignment rule conflict(s) detected`, 'warning');
            }
        } catch (error) {
            console.error('Error detecting conflicts:', error);
            // Don't show error toast for conflict detection as it's not critical
        }
    }

    handleViewConflicts() {
        this.showConflictModal = true;
    }

    handleCloseConflictModal() {
        this.showConflictModal = false;
    }

    handleToggleAssignmentRules() {
        this.isAssignmentRulesExpanded = !this.isAssignmentRulesExpanded;
    }

    get adminHandoffIcon() {
        return this._adminRequestCopied ? 'utility:check' : 'utility:copy_to_clipboard';
    }

    get adminHandoffLabel() {
        return this._adminRequestCopied
            ? 'Copied — paste into email or Slack'
            : 'Copy details for admin';
    }

    // Thin wrapper around the pure helper so the component's imperative
    // state (selectedList + derived getters) can feed into the text
    // builder without the builder having to know about LWC.
    _buildAdminRequestText() {
        return buildAdminRequestText({
            list: this.selectedList,
            hasCriteria: this.hasAssignmentCriteria,
            parsedCriteriaRules: this.parsedCriteriaRules,
            scoringTiers: this.scoringTiers,
            formattedCriteria: this.formattedAssignmentCriteria
        });
    }

    async handleCopyAdminRequest() {
        const text = this._buildAdminRequestText();
        const copied = await copyTextToClipboard(text);

        if (copied) {
            this._adminRequestCopied = true;
            if (this._adminRequestCopiedTimeout) {
                clearTimeout(this._adminRequestCopiedTimeout);
            }
            this._adminRequestCopiedTimeout = setTimeout(() => {
                this._adminRequestCopied = false;
                this._adminRequestCopiedTimeout = null;
            }, 2500);
            this.showToast(
                'Copied to clipboard',
                'Paste into email or Slack to send to your admin.',
                'success'
            );
        } else {
            this.showToast(
                'Couldn\'t copy automatically',
                'Your browser blocked clipboard access. Please copy the details manually.',
                'warning'
            );
        }
    }

    async handleToggleListStatus() {
        if (!this.selectedList) return;

        const newStatus = !this.selectedList.isActive;

        // Guard logic: prevent activation when the list isn't ready. We ask
        // the status helper *why* it's blocked so we can surface a precise
        // message instead of a generic "can't activate".
        if (newStatus) {
            const blockReason = listActivationBlockReason(
                this.selectedList,
                this.hasAssignmentCriteria
            );
            if (blockReason === 'no-questions') {
                this.showToast(
                    'Cannot Activate List',
                    'This list has no questions yet. Add at least one active question before going live.',
                    'error'
                );
                return;
            }
            if (blockReason === 'no-criteria') {
                this.showToast(
                    'Cannot Activate List',
                    'This list can\'t be activated without assignment criteria. Configure rules in Tribal first.',
                    'error'
                );
                return;
            }
            if (blockReason) {
                return;
            }
        }

        // OPTIMISTIC UPDATE: Update local state immediately for instant UI feedback
        // Save the original state in case we need to revert on error
        const originalSelectedList = { ...this.selectedList };
        const originalQuestionLists = [...this.questionLists];

        // Update selectedList immediately (toggle animation shows instantly)
        this.selectedList = {
            ...this.selectedList,
            isActive: newStatus
        };

        // Update the matching item in questionLists array
        this.questionLists = this.questionLists.map(list => {
            if (list.listId === this.selectedList.listId) {
                return {
                    ...list,
                    isActive: newStatus
                };
            }
            return list;
        });

        // Save to backend silently in the background (no isLoading spinner)
        try {
            const result = await saveQuestionList({
                listId: this.selectedList.listId,
                listName: this.selectedList.listName,
                description: this.selectedList.description,
                isActive: newStatus,
                highQualityThreshold: this.selectedList.highQualityThreshold,
                mediumQualityThreshold: this.selectedList.mediumQualityThreshold,
                highQualityLabel: this.selectedList.highQualityLabel,
                mediumQualityLabel: this.selectedList.mediumQualityLabel,
                lowQualityLabel: this.selectedList.lowQualityLabel,
                highQualityRecommendation: this.selectedList.highQualityRecommendation,
                mediumQualityRecommendation: this.selectedList.mediumQualityRecommendation,
                lowQualityRecommendation: this.selectedList.lowQualityRecommendation,
                isDefault: this.selectedList.isDefault
            });

            if (result.success) {
                const statusText = newStatus ? 'activated' : 'deactivated';
                this.showToast('Success', `List ${statusText} successfully`, 'success');
                // Local state is already correct - no need to refresh
            } else {
                // Revert local state on error
                this.selectedList = originalSelectedList;
                this.questionLists = originalQuestionLists;
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error toggling list status:', error);
            // Revert local state on error
            this.selectedList = originalSelectedList;
            this.questionLists = originalQuestionLists;
            this.showToast('Error', 'Failed to update list status', 'error');
        }
    }

    handleConfigureInTribal() {
        // This is a placeholder URL - in production, this would navigate to Tribal's configuration panel
        // Since we don't have the actual Tribal URL, we'll show a message
        this.showToast('Info', 'Please contact your administrator to configure assignment rules in Tribal.', 'info');

        // In a real implementation, you would use:
        // window.open('https://tribal-config-url.com/assignment-rules', '_blank');
    }

    async handleGenerateDefaultList() {
        this.isLoading = true;
        try {
            const result = await createDefaultQuestionList();
            if (result.success) {
                this.showToast('Success', result.message, 'success');
                // Refresh the question lists to load the new default list
                await refreshApex(this.wiredQuestionListsResult);
                // Auto-select the newly created default list
                const defaultList = this.questionLists.find(list => list.listId === result.recordId);
                if (defaultList) {
                    this.selectedList = defaultList;
                }
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error generating default list:', error);
            this.showToast('Error', 'Failed to generate default question list', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCreateEmptyList() {
        // Delegates to handleNewList to open the modal for creating an empty list
        this.handleNewList();
    }

    // Drag and Drop Event Handlers

    handleDragStart(event) {
        const questionId = event.currentTarget.dataset.questionId;
        this.draggedQuestionId = questionId;
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', questionId);

        // Add visual feedback
        event.currentTarget.style.opacity = '0.5';
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';

        const questionId = event.currentTarget.dataset.questionId;
        this.dragOverQuestionId = questionId;
    }

    handleDragLeave(event) {
        const questionId = event.currentTarget.dataset.questionId;
        if (this.dragOverQuestionId === questionId) {
            this.dragOverQuestionId = null;
        }
    }

    handleDragEnd(event) {
        // Clean up visual states
        event.currentTarget.style.opacity = '';
        this.draggedQuestionId = null;
        this.dragOverQuestionId = null;
    }

    async handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();

        const draggedQuestionId = event.dataTransfer.getData('text/plain');
        const targetQuestionId = event.currentTarget.dataset.questionId;

        if (!draggedQuestionId || !targetQuestionId || draggedQuestionId === targetQuestionId) {
            this.draggedQuestionId = null;
            this.dragOverQuestionId = null;
            return;
        }

        // Get only active questions for reordering
        const activeQuestions = this.selectedListQuestions.filter(q => q.isActive);

        // Find indices
        const draggedIndex = activeQuestions.findIndex(q => q.questionId === draggedQuestionId);
        const targetIndex = activeQuestions.findIndex(q => q.questionId === targetQuestionId);

        if (draggedIndex === -1 || targetIndex === -1) {
            this.draggedQuestionId = null;
            this.dragOverQuestionId = null;
            return;
        }

        // Reorder the active questions array
        const reorderedQuestions = [...activeQuestions];
        const [draggedQuestion] = reorderedQuestions.splice(draggedIndex, 1);
        reorderedQuestions.splice(targetIndex, 0, draggedQuestion);

        // Extract question IDs in the new order
        const orderedQuestionIds = reorderedQuestions.map(q => q.questionId);

        // OPTIMISTIC UPDATE: Update local state immediately for instant UI feedback
        // Save the original questions array in case we need to revert on error
        const originalQuestions = [...this.selectedList.questions];

        // Update question order for active questions based on their new position
        const updatedQuestions = this.selectedList.questions.map(question => {
            const newIndex = orderedQuestionIds.indexOf(question.questionId);
            if (newIndex !== -1) {
                // This is an active question that was reordered - update its order
                return {
                    ...question,
                    questionOrder: newIndex + 1
                };
            }
            // Inactive question or not in the reorder list - keep as is
            return question;
        });

        // Sort by question order to display in the correct order
        updatedQuestions.sort((a, b) => {
            if (a.questionOrder === null || a.questionOrder === undefined) return 1;
            if (b.questionOrder === null || b.questionOrder === undefined) return -1;
            return a.questionOrder - b.questionOrder;
        });

        // Update selectedList with new order immediately - UI updates instantly
        this.selectedList = {
            ...this.selectedList,
            questions: updatedQuestions
        };

        // Clean up drag state immediately for instant visual feedback
        this.draggedQuestionId = null;
        this.dragOverQuestionId = null;

        // Save to backend silently in the background
        try {
            const result = await reorderQuestions({ questionIdsInOrder: orderedQuestionIds });
            if (!result.success) {
                // Revert local state on error
                this.selectedList = {
                    ...this.selectedList,
                    questions: originalQuestions
                };
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error reordering questions:', error);
            // Revert local state on error
            this.selectedList = {
                ...this.selectedList,
                questions: originalQuestions
            };
            this.showToast('Error', 'Failed to reorder questions', 'error');
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}
