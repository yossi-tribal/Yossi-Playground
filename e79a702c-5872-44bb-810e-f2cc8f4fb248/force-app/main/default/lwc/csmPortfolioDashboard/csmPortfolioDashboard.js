import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPortfolioSummary from '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioSummary';
import getPortfolioAccounts from '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioAccounts';
import getUpcomingRenewals from '@salesforce/apex/CSD_CSMPortfolioController.getUpcomingRenewals';
import getPortfolioHealthBreakdown from '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioHealthBreakdown';
import getOverdueTasksForPortfolio from '@salesforce/apex/CSD_CSMPortfolioController.getOverdueTasksForPortfolio';
import getHighPriorityCasesForPortfolio from '@salesforce/apex/CSD_CSMPortfolioController.getHighPriorityCasesForPortfolio';
import getAllOpenCasesForPortfolio from '@salesforce/apex/CSD_CSMPortfolioController.getAllOpenCasesForPortfolio';
import getAllOpenOpportunitiesForPortfolio from '@salesforce/apex/CSD_CSMPortfolioController.getAllOpenOpportunitiesForPortfolio';
import getAllOpenTasksForPortfolio from '@salesforce/apex/CSD_CSMPortfolioController.getAllOpenTasksForPortfolio';
import getPortfolioCasesForMonth from '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioCasesForMonth';
import getPortfolioClosedWonForMonth from '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioClosedWonForMonth';
import getClosedWonOpportunitiesForPortfolio from '@salesforce/apex/CSD_CSMPortfolioController.getClosedWonOpportunitiesForPortfolio';
import getCasesOpenedInLastDaysForPortfolio from '@salesforce/apex/CSD_CSMPortfolioController.getCasesOpenedInLastDaysForPortfolio';
import getCasesOpenedYtdForPortfolio from '@salesforce/apex/CSD_CSMPortfolioController.getCasesOpenedYtdForPortfolio';
import getUpcomingEventsForPortfolio from '@salesforce/apex/CSD_CSMPortfolioController.getUpcomingEventsForPortfolio';
import startPortfolioRecalc from '@salesforce/apex/CSD_CSMPortfolioController.startPortfolioRecalc';
import getRecalcJobStatus from '@salesforce/apex/CSD_CSMPortfolioController.getRecalcJobStatus';
import createTask from '@salesforce/apex/CSD_CSDashboardController.createTask';
import createEvent from '@salesforce/apex/CSD_CSDashboardController.createEvent';
import getTaskPicklistValues from '@salesforce/apex/CSD_CSDashboardController.getTaskPicklistValues';
import { formatAverageResolutionHours } from 'c/csdResolutionFormat';
import currentUserId from '@salesforce/user/Id';

export default class CsmPortfolioDashboard extends NavigationMixin(LightningElement) {
    @track summary = null;
    @track accounts = [];
    @track renewals = [];
    @track isLoading = true;
    @track error = null;

    @track currentFilter = 'all';
    @track sortField = 'accountName';
    @track sortDirection = 'asc';
    /**
     * Server-side fetch chunk size. We pull this many accounts per Apex
     * call. Independent of how many we *show* at once (visibleCount) —
     * loading 25 at a time means most "View more" clicks are an instant
     * client-side reveal rather than a network round-trip.
     */
    @track pageSize = 25;
    /** Server cursor: which page have we fetched up through. */
    @track currentPage = 1;
    /**
     * Number of accounts currently revealed in the table. Starts at 5
     * and grows in 5-row increments via the "View more" row at the
     * bottom of the table. Reset to 5 whenever filter or sort changes.
     */
    @track visibleCount = 5;
    /** Increment used by each "View more" click. */
    INITIAL_VISIBLE_COUNT = 5;
    VIEW_MORE_INCREMENT = 5;
    /**
     * True when the last server response was a "full" page, meaning
     * there might be more rows beyond what we've already loaded. We
     * treat the server as "has more" optimistically until a partial
     * page proves otherwise.
     */
    @track serverHasMore = false;
    @track totalAccountCount = 0;
    @track isAccountsLoading = false;

    @track expandedAccountId = null;
    @track showAccountModal = false;
    @track selectedAccountId = null;
    @track selectedAccountName = '';
    @track snapshotExpanded = false;
    _snapshotStorageKey = 'csd.portfolio.snapshotExpanded';
    @track isRecalculatingAll = false;
    /**
     * Live progress of the async recalc job, populated by the poller.
     * Shape: { status, processedChunks, totalChunks, numberOfErrors, done }.
     * totalChunks = number of batch chunks (RECALC_BATCH_SIZE accounts
     * each in the Apex controller), so "processed / total" is chunk-
     * granular, not account-granular. That's deliberate: AsyncApexJob
     * doesn't track per-record progress and queueing an extra counter
     * would require a custom object. Chunks are good enough for a
     * "Processing … of …" UI.
     */
    @track recalcProgress = null;
    /**
     * Structured error captured from a failed recalc run so we can
     * render a dedicated modal ("what failed + copy-for-admin message")
     * instead of a disappearing toast. Shape:
     * { jobId, status, processedChunks, totalChunks, numberOfErrors,
     *   extendedStatus, message, userMessage }.
     * Null when there is no outstanding error to surface.
     */
    @track recalcError = null;
    @track recalcAdminCopied = false;
    /** Setinterval handle for the recalc status poller. */
    _recalcPollTimer = null;
    /** AsyncApexJob Id of the in-flight recalc run, if any. */
    _recalcJobId = null;

    @track _activeTooltipKey = null;
    _touchTimer = null;

    @track showActivityModal = false;
    @track activityModalObjectApiName = '';
    @track activityModalTitle = '';
    @track activityModalIsLogCall = false;
    @track activityModalSaving = false;
    @track activityForm = {
        Subject: '', WhoId: null, WhatId: null,
        ActivityDate: null, Status: '', Priority: 'Normal', Type: '',
        OwnerId: currentUserId, Description: '',
        StartDateTime: null, EndDateTime: null,
        IsAllDayEvent: false, Location: ''
    };
    @track whoIdObjectType = 'Contact';
    @track whatIdObjectType = 'Account';
    @track taskPicklistValues = null;
    @track showWhoIdEntityMenu = false;
    @track showWhatIdEntityMenu = false;

    @track showHealthBreakdownModal = false;
    @track healthBreakdown = null;

    @track showKpiModal = false;
    @track kpiModalTitle = '';
    @track kpiModalData = [];
    @track kpiModalType = '';
    @track kpiModalEmptyMessage = '';

    @track showSuggestedActionModal = false;
    @track suggestedActionModalTitle = '';
    @track suggestedActionModalItems = [];
    @track suggestedActionModalType = '';
    @track suggestedActionModalLoading = false;

    @track secOpenTasks = false;
    @track secCases = false;
    @track secOpportunities = false;
    @track secUpcomingEvents = false;
    @track openTasksList = [];
    @track openCasesList = [];
    @track openOpportunitiesList = [];
    @track upcomingEventsList = [];
    @track detailListsLoaded = false;

    /**
     * Demo mode — when the page URL has ?c__demo=<name> we skip Apex and
     * seed tracked state directly so reviewers can see any empty/error
     * screen without having to mutate real data.
     * See _applyDemoState() for the supported names.
     */
    _demoState = null;

    @wire(CurrentPageReference)
    _handlePageRef(pageRef) {
        if (!pageRef) return;
        const demo =
            (pageRef.state && (pageRef.state.c__demo || pageRef.state.demo)) ||
            null;
        if (demo) {
            this._demoState = String(demo).toLowerCase();
        }
    }

    connectedCallback() {
        this._applySnapshotPreferenceFromStorage();
        this._hideAppPageHeader();
        if (this._applyDemoState(this._demoState)) {
            // Demo mode took over — no Apex call needed.
            return;
        }
        this.loadPortfolioData();
    }

    /*
     * Stop any in-flight pollers when the component is torn down so we
     * don't leak timers (e.g. user navigates away mid-recalc). The job
     * itself keeps running on the server — this just stops the UI from
     * asking about it.
     */
    disconnectedCallback() {
        this._stopRecalcPolling();
    }

    /**
     * Returns true when we handled the named demo state (and therefore the
     * normal Apex load should be skipped). Supported names:
     *   - 'onboarding'           → user has no accounts as Primary CSM
     *   - 'filter-empty'         → has accounts, filter hides them all
     *   - 'error'                → fatal load error (full-page)
     *   - 'permission'           → permission-denied error (full-page)
     *   - 'not-assessed-banner'  → portfolio has accounts, all Not Assessed
     *   - 'recalc-error'         → healthy portfolio, recalc error modal open
     *   - 'recalc-error-start'   → recalc error modal, failure before start
     *   - 'large'                → 30 seeded accounts for testing View More
     */
    _applyDemoState(name) {
        if (!name) return false;
        this.isLoading = false;
        this.error = null;

        switch (name) {
            case 'onboarding':
                this.summary = {
                    totalAccounts: 0,
                    notAssessedAccounts: 0,
                    currentUserName: 'Demo User'
                };
                this.accounts = [];
                return true;

            case 'filter-empty':
                this.summary = {
                    totalAccounts: 3,
                    healthyAccounts: 2,
                    needsAttentionAccounts: 1,
                    atRiskAccounts: 0,
                    notAssessedAccounts: 0,
                    currentUserName: 'Demo User'
                };
                this.accounts = [];
                this.currentFilter = 'at-risk';
                return true;

            case 'error':
                this.summary = null;
                this.error = {
                    body: { message: 'Simulated load failure (demo mode).' },
                    message: 'Simulated load failure (demo mode).'
                };
                return true;

            case 'permission':
                this.summary = null;
                this.error = {
                    body: {
                        message:
                            'INSUFFICIENT_ACCESS: insufficient access rights on cross-reference id (demo mode).'
                    },
                    message: 'INSUFFICIENT_ACCESS (demo mode).'
                };
                return true;

            case 'recalc-error':
                // Real-shaped portfolio so the dashboard behind the modal
                // looks like an actual run, then auto-open the error modal
                // with a realistic governor-limit failure payload.
                this.summary = {
                    totalAccounts: 8432,
                    healthyAccounts: 6100,
                    needsAttentionAccounts: 1800,
                    atRiskAccounts: 500,
                    notAssessedAccounts: 32,
                    portfolioHealthTrend: 'declining',
                    accountsImproved: 145,
                    accountsDeclined: 312,
                    accountsStable: 7943,
                    accountsWithPriorScore: 8400,
                    currentUserName: 'Demo User'
                };
                this.accounts = [
                    { accountId: 'demo-1', accountName: 'Acme Corp', healthBand: 'Healthy', healthScore: 92 },
                    { accountId: 'demo-2', accountName: 'Globex LLC', healthBand: 'Needs Attention', healthScore: 68 },
                    { accountId: 'demo-3', accountName: 'Umbrella Inc', healthBand: 'At Risk', healthScore: 41 }
                ];
                this.totalAccountCount = 8432;
                this.recalcError = {
                    jobId: '707D000000ABCDEF',
                    status: 'Failed',
                    processedChunks: 17,
                    totalChunks: 42,
                    numberOfErrors: 3,
                    extendedStatus:
                        'First error: Too many SOQL queries: 101'
                };
                return true;

            case 'large': {
                /*
                 * Seeds a portfolio of 30 accounts so you can drive the
                 * "View more" flow end-to-end. We start the user at 5
                 * visible (the default), give them 30 in the local buffer,
                 * and tell the component the server has nothing more to
                 * fetch — every "View more" click resolves locally.
                 */
                const bands = ['Healthy', 'Needs Attention', 'At Risk'];
                const colors = ['green', 'yellow', 'red'];
                const companyRoots = [
                    'Acme', 'Globex', 'Initech', 'Umbrella', 'Soylent',
                    'Stark', 'Wayne', 'Wonka', 'Cyberdyne', 'Pied Piper',
                    'Hooli', 'Massive Dynamic', 'Tyrell', 'Oscorp', 'Vandelay',
                    'Vehement', 'Bluth', 'Rekall', 'Aperture', 'Black Mesa',
                    'Sirius', 'Olivia Pope', 'Dunder Mifflin', 'Sterling Cooper',
                    'Pendant', 'Nakatomi', 'Veridian', 'Globe-Tek',
                    'Northwind', 'Contoso'
                ];
                const suffixes = ['Corp', 'LLC', 'Industries', 'Group',
                    'Holdings', 'Partners', 'Inc'];
                const seeded = companyRoots.map((root, i) => {
                    const bandIdx = i % bands.length;
                    const score = bandIdx === 0 ? 80 + (i % 18)
                        : bandIdx === 1 ? 55 + (i % 15)
                            : 25 + (i % 25);
                    return {
                        accountId: `demo-large-${i + 1}`,
                        accountName: `${root} ${suffixes[i % suffixes.length]}`,
                        healthBand: bands[bandIdx],
                        healthScore: score,
                        healthScoreColor: colors[bandIdx],
                        daysSinceLastActivity: i % 7 === 0 ? null : (i * 3) % 30,
                        daysUntilNextActivity: i % 5 === 0 ? null : (i * 2) % 21,
                        nextActivityDate: null,
                        openCasesCount: i % 4,
                        highPriorityCasesCount: i % 9 === 0 ? 1 : 0,
                        openTasksCount: i % 3,
                        overdueTasksCount: i % 11 === 0 ? 1 : 0,
                        openPipelineAmount: ((i * 137) % 900) * 1000,
                        renewalDate: null,
                        primaryContactName: null,
                        primaryContactId: null,
                        recentActivities: []
                    };
                });
                this.summary = {
                    totalAccounts: seeded.length,
                    healthyAccounts: seeded.filter(a => a.healthBand === 'Healthy').length,
                    needsAttentionAccounts: seeded.filter(a => a.healthBand === 'Needs Attention').length,
                    atRiskAccounts: seeded.filter(a => a.healthBand === 'At Risk').length,
                    notAssessedAccounts: 0,
                    // Mock a healthy improvement vs last calculation so
                    // the new portfolio trend chip has something to show.
                    portfolioHealthTrend: 'improving',
                    accountsImproved: 7,
                    accountsDeclined: 2,
                    accountsStable: 18,
                    accountsWithPriorScore: 27,
                    currentUserName: 'Demo User'
                };
                this.accounts = seeded;
                this.totalAccountCount = seeded.length;
                this.serverHasMore = false;
                this.visibleCount = this.INITIAL_VISIBLE_COUNT;
                return true;
            }

            case 'recalc-error-start':
                // Same scaffolding, but the error shape represents a
                // failure before the batch even started processing
                // chunks (e.g. permissions, Apex compile issue).
                this.summary = {
                    totalAccounts: 8432,
                    healthyAccounts: 6100,
                    needsAttentionAccounts: 1800,
                    atRiskAccounts: 500,
                    notAssessedAccounts: 32,
                    currentUserName: 'Demo User'
                };
                this.accounts = [
                    { accountId: 'demo-1', accountName: 'Acme Corp', healthBand: 'Healthy', healthScore: 92 }
                ];
                this.totalAccountCount = 8432;
                this.recalcError = {
                    jobId: null,
                    status: 'Failed',
                    processedChunks: 0,
                    totalChunks: 0,
                    numberOfErrors: 1,
                    extendedStatus:
                        'System.QueryException: Insufficient privileges to access AsyncApexJob'
                };
                return true;

            case 'not-assessed-banner':
                this.summary = {
                    totalAccounts: 3,
                    notAssessedAccounts: 3,
                    healthyAccounts: 0,
                    needsAttentionAccounts: 0,
                    atRiskAccounts: 0,
                    currentUserName: 'Demo User'
                };
                this.accounts = [
                    {
                        accountId: 'demo-1',
                        accountName: 'Acme Corp',
                        healthBand: 'Not Assessed',
                        healthScore: null
                    },
                    {
                        accountId: 'demo-2',
                        accountName: 'Globex LLC',
                        healthBand: 'Not Assessed',
                        healthScore: null
                    },
                    {
                        accountId: 'demo-3',
                        accountName: 'Umbrella Inc',
                        healthBand: 'Not Assessed',
                        healthScore: null
                    }
                ];
                this.totalAccountCount = 3;
                return true;

            default:
                // Unknown demo value — fall through to real load.
                return false;
        }
    }

    /**
     * Lightning App Pages render a banner above the flexipage with the
     * CustomTab's motif icon and label ("My Portfolio" with the pink
     * trophy in our case). We surface our own, richer header inside the
     * LWC, so that duplicate banner is just visual noise.
     *
     * Since the banner lives outside our shadow root we can't style it
     * directly from component CSS — instead we inject a one-time <style>
     * into document.head. It's idempotent (guarded by an id) and only
     * active while a csmPortfolioDashboard is mounted anywhere on the
     * page (we keep it in place; removing it would flash the banner if
     * two instances of the LWC coexist briefly during nav transitions).
     */
    _hideAppPageHeader() {
        if (typeof document === 'undefined') {
            return;
        }
        // Step 1 — inject a broad style. Our LWC deliberately does NOT use
        // .slds-page-header anywhere, so it's safe to hide that class while
        // this dashboard is mounted. We also target several aura/flexipage
        // wrappers we've seen in the wild.
        const STYLE_ID = 'csd-hide-app-page-header';
        if (!document.getElementById(STYLE_ID)) {
            try {
                const style = document.createElement('style');
                style.id = STYLE_ID;
                style.textContent = [
                    '.slds-page-header',
                    '.slds-page-header_joined',
                    '.forceAppBuilderAppPageHeader',
                    '.appBuilderPageHeader',
                    '.forceCommunityThemeLayout .slds-page-header',
                    '.oneCenterStage > .slds-page-header',
                    'div[data-component-id="flexipage_appHomeTemplateDesktop"] > .slds-page-header',
                    'div[data-aura-class*="AppHomeTemplate"] > .slds-page-header'
                ].join(',\n                    ')
                    + ' { display: none !important; }';
                document.head.appendChild(style);
            } catch (_) {
                /* no-op */
            }
        }

        // Step 2 — DOM-walk fallback. Some LEX builds render the App Page
        // banner with class names our selectors don't catch (e.g. Aura-
        // generated class names that change between releases). We walk up
        // from our host, crossing shadow boundaries, and hide any nearby
        // element that looks like a page header (banner role, or a class
        // name containing "pageHeader").  We do this once on mount and
        // again after 200ms to catch LEX's post-mount re-render.
        this._walkAndHideHeaderSiblings();
        setTimeout(() => this._walkAndHideHeaderSiblings(), 200);
        setTimeout(() => this._walkAndHideHeaderSiblings(), 800);
    }

    _walkAndHideHeaderSiblings() {
        try {
            let node = this.template && this.template.host;
            let hops = 0;
            const HEADER_HINT = /page.?header|PageHeader|highlightsPanel/i;
            while (node && hops < 15) {
                hops += 1;
                const root = node.getRootNode ? node.getRootNode() : null;
                const parent =
                    node.parentNode || (root && root.host ? root.host : null);
                if (!parent) break;
                if (parent.querySelectorAll) {
                    const candidates = parent.querySelectorAll('*');
                    candidates.forEach((el) => {
                        if (
                            el === node ||
                            (el.contains && el.contains(node)) ||
                            (node.contains && node.contains(el))
                        ) {
                            return;
                        }
                        // className on HTMLElement is a string, on SVG it's
                        // an SVGAnimatedString — coerce defensively.
                        const clsRaw =
                            el.getAttribute && el.getAttribute('class');
                        const cls = clsRaw ? String(clsRaw) : '';
                        const role = el.getAttribute && el.getAttribute('role');
                        const hasHeaderClass = cls && HEADER_HINT.test(cls);
                        const hasBannerRole = role === 'banner';
                        if (hasHeaderClass || hasBannerRole) {
                            try {
                                el.style.display = 'none';
                            } catch (_) {
                                /* elements without writeable style, skip */
                            }
                        }
                    });
                }
                node =
                    root && root.host && root.host !== parent
                        ? root.host
                        : parent;
            }
        } catch (_) {
            /* no-op */
        }
    }

    _applySnapshotPreferenceFromStorage() {
        try {
            const v = localStorage.getItem(this._snapshotStorageKey);
            if (v === 'true') {
                this.snapshotExpanded = true;
            } else if (v === 'false') {
                this.snapshotExpanded = false;
            }
        } catch (e) {
            // localStorage may be unavailable
        }
    }

    _persistSnapshotPreference() {
        try {
            localStorage.setItem(this._snapshotStorageKey, String(this.snapshotExpanded));
        } catch (e) {
            // ignore
        }
    }

    loadPortfolioData() {
        this.isLoading = true;
        this.error = null;

        const promises = [
            getPortfolioSummary()
                .then(result => { this.summary = result; })
                .catch(err => this.handleError('Failed to load portfolio summary', err)),

            this.loadAccounts(),

            getUpcomingRenewals({ daysAhead: 90 })
                .then(result => { this.renewals = result || []; })
                .catch(err => this.handleError('Failed to load renewals', err)),

            this.loadDetailLists()
        ];

        Promise.all(promises).then(() => { this.isLoading = false; });
    }

    /**
     * Fetch accounts from Apex.
     * @param {boolean} append When true, the new page is appended to the
     *   existing list (used by "View more" once we exhaust the locally
     *   buffered rows). When false (default), the existing list is
     *   replaced — the right behavior for filter/sort changes.
     */
    loadAccounts(append = false) {
        return getPortfolioAccounts({
            filterType: this.currentFilter,
            sortField: this.sortField,
            sortDirection: this.sortDirection,
            pageSize: this.pageSize,
            pageNumber: this.currentPage
        })
            .then(result => {
                const list = result || [];
                // A "full" page suggests there might be more rows behind
                // it. A partial (or empty) page is the definitive end.
                this.serverHasMore = list.length >= this.pageSize;
                if (append) {
                    this.accounts = [...(this.accounts || []), ...list];
                } else {
                    this.accounts = list;
                    this.expandedAccountId = null;
                }
            })
            .catch(err => {
                this.handleError('Failed to load accounts', err);
            });
    }

    loadDetailLists() {
        return Promise.all([
            getAllOpenTasksForPortfolio()
                .then(result => { this.openTasksList = result || []; })
                .catch(err => this.handleError('Failed to load open tasks', err)),

            getAllOpenCasesForPortfolio()
                .then(result => { this.openCasesList = result || []; })
                .catch(err => this.handleError('Failed to load open cases', err)),

            getAllOpenOpportunitiesForPortfolio()
                .then(result => { this.openOpportunitiesList = result || []; })
                .catch(err => this.handleError('Failed to load open opportunities', err)),

            getUpcomingEventsForPortfolio()
                .then(result => { this.upcomingEventsList = result || []; })
                .catch(err => this.handleError('Failed to load upcoming events', err))
        ]).then(() => { this.detailListsLoaded = true; });
    }

    handleToggleSection(event) {
        const section = event.currentTarget.dataset.section;
        if (section === 'openTasks') {
            this.secOpenTasks = !this.secOpenTasks;
        } else if (section === 'cases') {
            this.secCases = !this.secCases;
        } else if (section === 'opportunities') {
            this.secOpportunities = !this.secOpportunities;
        } else if (section === 'upcomingEvents') {
            this.secUpcomingEvents = !this.secUpcomingEvents;
        }
    }

    handleViewAllTasks() {
        this.handleOpenTasksClick();
    }

    handleViewAllCases() {
        this.handleOpenCasesClick();
    }

    handleViewAllOpportunities() {
        this.handleOpenPipelineClick();
    }

    handleDetailRecordClick(event) {
        const recordId = event.currentTarget.dataset.id;
        if (recordId) {
            this.navigateToRecord(recordId);
        }
    }

    // ── Filter Handlers ──

    handleFilterClick(event) {
        const filter = event.currentTarget.dataset.filter;
        if (filter && filter !== this.currentFilter) {
            this.applyAccountFocus(filter);
        }
    }

    handleHealthBarClick(event) {
        const segment = event.currentTarget.dataset.segment;
        if (!segment) return;
        const filterMap = { green: 'healthy', yellow: 'needs-attention', red: 'at-risk', gray: 'all' };
        const newFilter = filterMap[segment] || 'all';
        if (newFilter !== this.currentFilter) {
            this.applyAccountFocus(newFilter);
        }
    }

    handleSuggestedActionClick(event) {
        const actionType = event.currentTarget.dataset.actionType;
        if (!actionType) return;
        this.openSuggestedAction(actionType);
    }

    openSuggestedAction(actionType) {
        if (actionType === 'overdue') {
            this.suggestedActionModalTitle = 'Overdue Tasks Across Portfolio';
            this.suggestedActionModalType = 'task';
            this.suggestedActionModalLoading = true;
            this.showSuggestedActionModal = true;

            getOverdueTasksForPortfolio()
                .then(result => {
                    if (result && result.length === 1) {
                        this.showSuggestedActionModal = false;
                        this[NavigationMixin.Navigate]({
                            type: 'standard__recordPage',
                            attributes: { recordId: result[0].taskId, objectApiName: 'Task', actionName: 'view' }
                        });
                    } else {
                        this.suggestedActionModalItems = (result || []).map(t => ({
                            id: t.taskId,
                            accountName: t.accountName,
                            subject: t.subject,
                            metric: `${t.daysOverdue}d overdue`,
                            metricClass: 'action-modal-item-metric action-modal-item-metric--danger'
                        }));
                    }
                    this.suggestedActionModalLoading = false;
                })
                .catch(err => {
                    this.handleError('Failed to load overdue tasks', err);
                    this.suggestedActionModalLoading = false;
                });

        } else if (actionType === 'highpri') {
            this.suggestedActionModalTitle = 'High-Priority Cases Across Portfolio';
            this.suggestedActionModalType = 'case';
            this.suggestedActionModalLoading = true;
            this.showSuggestedActionModal = true;

            getHighPriorityCasesForPortfolio()
                .then(result => {
                    if (result && result.length === 1) {
                        this.showSuggestedActionModal = false;
                        this[NavigationMixin.Navigate]({
                            type: 'standard__recordPage',
                            attributes: { recordId: result[0].caseId, objectApiName: 'Case', actionName: 'view' }
                        });
                    } else {
                        this.suggestedActionModalItems = (result || []).map(c => ({
                            id: c.caseId,
                            accountName: c.accountName,
                            subject: `${c.caseNumber}: ${c.subject}`,
                            metric: c.priority,
                            metricClass: 'action-modal-item-metric action-modal-item-metric--danger'
                        }));
                    }
                    this.suggestedActionModalLoading = false;
                })
                .catch(err => {
                    this.handleError('Failed to load high-priority cases', err);
                    this.suggestedActionModalLoading = false;
                });

        } else if (actionType === 'renewals') {
            if (this.renewals && this.renewals.length === 1) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: this.renewals[0].opportunityId, objectApiName: 'Opportunity', actionName: 'view' }
                });
            } else {
                this.suggestedActionModalTitle = 'Upcoming Renewals';
                this.suggestedActionModalType = 'opportunity';
                this.suggestedActionModalItems = (this.renewals || []).map(r => ({
                    id: r.opportunityId,
                    accountName: r.accountName,
                    subject: r.opportunityName,
                    metric: this.formatCurrencyShort(r.amount || 0),
                    metricClass: 'action-modal-item-metric',
                    metricSub: this.getRenewalDaysText(r.daysUntilClose),
                    metricSubClass: 'action-modal-item-metric-sub ' + this.getRenewalDaysClass(r.daysUntilClose)
                }));
                this.suggestedActionModalLoading = false;
                this.showSuggestedActionModal = true;
            }

        } else if (actionType === 'inactive') {
            this.applyAccountFocus('inactive');
        }
    }

    handleSnapshotFilterClick(event) {
        const filter = event.currentTarget.dataset.filter;
        if (filter) {
            this.applyAccountFocus(filter);
        }
    }

    handleSnapshotActionClick(event) {
        const actionType = event.currentTarget.dataset.actionType;
        if (actionType) {
            this.openSuggestedAction(actionType);
        }
    }

    handleCloseSuggestedActionModal() {
        this.showSuggestedActionModal = false;
        this.suggestedActionModalItems = [];
    }

    handleActionModalItemClick(event) {
        const recordId = event.currentTarget.dataset.id;
        const type = event.currentTarget.dataset.type;
        if (!recordId) return;

        const objectMap = { task: 'Task', case: 'Case', opportunity: 'Opportunity', account: 'Account' };
        const objectApiName = objectMap[type] || 'Account';

        this.showSuggestedActionModal = false;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName, actionName: 'view' }
        });
    }

    // ── Sort Handlers ──

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (!field) return;
        if (this.sortField === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDirection = 'asc';
        }
        this.currentPage = 1;
        this.visibleCount = this.INITIAL_VISIBLE_COUNT;
        this.isAccountsLoading = true;
        this.loadAccounts().then(() => { this.isAccountsLoading = false; });
    }

    // ── Progressive reveal ("View more") ──

    /**
     * Reveals the next slice of accounts. If we already have unrevealed
     * rows in the local buffer (server returned more than we're showing),
     * just bump visibleCount — instant. Otherwise fetch the next server
     * page, append it, then bump. Idempotent and safe to spam-click.
     */
    handleViewMore() {
        if (this.isAccountsLoading) return;

        const totalLoaded = this.accounts ? this.accounts.length : 0;
        const room = totalLoaded - this.visibleCount;

        // Case 1: enough buffered to satisfy the click locally.
        if (room >= this.VIEW_MORE_INCREMENT) {
            this.visibleCount += this.VIEW_MORE_INCREMENT;
            return;
        }

        // Case 2: some buffered + we'll need to top up from the server.
        // Reveal what we have first so the user sees movement immediately.
        if (room > 0) {
            this.visibleCount = totalLoaded;
        }
        if (!this.serverHasMore) {
            // Buffer is empty, server has no more — nothing to do.
            return;
        }

        // Case 3: fetch next page, then reveal.
        this.currentPage += 1;
        this.isAccountsLoading = true;
        this.loadAccounts(true)
            .then(() => {
                const newTotal = this.accounts ? this.accounts.length : 0;
                this.visibleCount = Math.min(
                    newTotal,
                    this.visibleCount + this.VIEW_MORE_INCREMENT
                );
            })
            .finally(() => {
                this.isAccountsLoading = false;
            });
    }

    /** Collapse back to the initial reveal count after the user has expanded. */
    handleShowLess() {
        this.visibleCount = this.INITIAL_VISIBLE_COUNT;
    }

    // ── Expansion & Modal ──

    handleAccountRowClick(event) {
        const accountId = event.currentTarget.dataset.id;
        if (!accountId) return;
        // Prevent expansion when clicking the account name link
        if (event.target && event.target.classList.contains('account-name-link')) return;
        this.expandedAccountId = this.expandedAccountId === accountId ? null : accountId;
    }

    handleViewFullDashboard(event) {
        event.stopPropagation();
        const accountId = event.currentTarget.dataset.id;
        if (accountId) {
            const selectedAccount = this.accounts.find(account => account.accountId === accountId);
            this.selectedAccountId = accountId;
            this.selectedAccountName = selectedAccount?.accountName || '';
            this.showAccountModal = true;
        }
    }

    handleCloseAccountModal() {
        this.showAccountModal = false;
        this.selectedAccountId = null;
        this.selectedAccountName = '';
    }

    handleGoToAccount(event) {
        event.stopPropagation();
        const accountId = event.currentTarget.dataset.id;
        if (accountId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: accountId, objectApiName: 'Account', actionName: 'view' }
            });
        }
    }

    navigateToAccount(event) {
        event.preventDefault();
        event.stopPropagation();
        const accountId = event.currentTarget.dataset.id;
        if (accountId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: accountId, objectApiName: 'Account', actionName: 'view' }
            });
        }
    }

    // ── Expansion Row Click Handlers ──

    handleExpansionActivityClick(event) {
        event.stopPropagation();
        const recordId = event.currentTarget.dataset.id;
        if (recordId) {
            this.navigateToRecord(recordId);
        }
    }

    handleExpansionContactClick(event) {
        event.stopPropagation();
        const contactId = event.currentTarget.dataset.id;
        if (contactId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: contactId, objectApiName: 'Contact', actionName: 'view' }
            });
        }
    }

    handleHealthFactorClick(event) {
        event.stopPropagation();
        const factorType = event.currentTarget.dataset.factor;
        const accountId = event.currentTarget.dataset.account;
        const accountName = event.currentTarget.dataset.name;
        if (!factorType || !accountId) return;

        if (factorType === 'activity') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: accountId, objectApiName: 'Account', actionName: 'view' }
            });
            return;
        }

        if (factorType === 'overdueTasks') {
            this.kpiModalTitle = `Overdue Tasks — ${accountName}`;
            this.kpiModalType = 'tasks';
            this.kpiModalEmptyMessage = 'No overdue tasks for this account — all follow-ups are on track.';
            this.kpiModalData = [];
            this.showKpiModal = true;

            getOverdueTasksForPortfolio()
                .then(result => {
                    this.kpiModalData = this.sortPortfolioTasks(
                        (result || []).filter(t => t.accountId === accountId)
                    );
                })
                .catch(error => {
                    this.handleError('Failed to load overdue tasks', error);
                    this.showKpiModal = false;
                });
        } else if (factorType === 'highPriCases') {
            this.kpiModalTitle = `High-Priority Cases — ${accountName}`;
            this.kpiModalType = 'cases';
            this.kpiModalEmptyMessage = 'No high-priority cases for this account — no escalations right now.';
            this.kpiModalData = [];
            this.showKpiModal = true;

            getHighPriorityCasesForPortfolio()
                .then(result => {
                    const filtered = (result || []).filter(c => c.accountId === accountId);
                    this.kpiModalData = filtered.map(c => ({
                        ...c,
                        caseId: c.caseId,
                        subject: `${c.caseNumber}: ${c.subject}`,
                        priorityDotClass: c.priority === 'High' ? 'priority-dot priority-dot--high' :
                            (c.priority === 'Medium' ? 'priority-dot priority-dot--medium' : 'priority-dot priority-dot--low')
                    }));
                })
                .catch(error => {
                    this.handleError('Failed to load high-priority cases', error);
                    this.showKpiModal = false;
                });
        } else if (factorType === 'openCases') {
            this.kpiModalTitle = `Open Cases — ${accountName}`;
            this.kpiModalType = 'cases';
            this.kpiModalEmptyMessage = 'No open cases for this account.';
            this.kpiModalData = [];
            this.showKpiModal = true;

            getAllOpenCasesForPortfolio()
                .then(result => {
                    this.kpiModalData = this.sortPortfolioCases(
                        (result || []).filter(c => c.accountId === accountId)
                    );
                })
                .catch(error => {
                    this.handleError('Failed to load cases', error);
                    this.showKpiModal = false;
                });
        }
    }

    // ── Snapshot Toggle ──

    handleSnapshotToggle() {
        this.snapshotExpanded = !this.snapshotExpanded;
        this._persistSnapshotPreference();
    }

    handleBarMouseEnter(event) {
        this._activeTooltipKey = event.currentTarget.dataset.key;
    }

    handleBarMouseLeave() {
        this._activeTooltipKey = null;
    }

    handleBarTouchStart(event) {
        event.preventDefault();
        const key = event.currentTarget.dataset.key;
        this._touchTimer = setTimeout(() => {
            this._activeTooltipKey = key;
        }, 200);
    }

    handleBarTouchEnd() {
        clearTimeout(this._touchTimer);
        this._activeTooltipKey = null;
    }

    // ── Trend Bar Click Drill-Down ──

    _getMonthYearFromIndex(index) {
        const now = new Date();
        const d = new Date(now.getFullYear(), now.getMonth() - 11 + index, 1);
        return { month: d.getMonth() + 1, year: d.getFullYear() };
    }

    _formatMonthTitle(index) {
        const { month, year } = this._getMonthYearFromIndex(index);
        const abbrevs = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        return `${abbrevs[month - 1]} ${year}`;
    }

    handleCaseTrendBarClick(event) {
        const idx = parseInt(event.currentTarget.dataset.monthIndex, 10);
        const { month, year } = this._getMonthYearFromIndex(idx);
        const title = this._formatMonthTitle(idx);

        this.kpiModalTitle = `Cases \u2014 ${title}`;
        this.kpiModalType = 'monthCases';
        this.kpiModalEmptyMessage = `No cases opened in ${title}.`;
        this.kpiModalData = [];
        this.showKpiModal = true;

        getPortfolioCasesForMonth({ month, year })
            .then(result => { this.kpiModalData = result || []; })
            .catch(error => {
                this.handleError('Failed to load cases', error);
                this.showKpiModal = false;
            });
    }

    handleRevenueTrendBarClick(event) {
        const idx = parseInt(event.currentTarget.dataset.monthIndex, 10);
        const { month, year } = this._getMonthYearFromIndex(idx);
        const title = this._formatMonthTitle(idx);

        this.kpiModalTitle = `Closed Won \u2014 ${title}`;
        this.kpiModalType = 'monthOpportunities';
        this.kpiModalEmptyMessage = `No closed-won opportunities in ${title}.`;
        this.kpiModalData = [];
        this.showKpiModal = true;

        getPortfolioClosedWonForMonth({ month, year })
            .then(result => { this.kpiModalData = result || []; })
            .catch(error => {
                this.handleError('Failed to load opportunities', error);
                this.showKpiModal = false;
            });
    }

    // ── Health Breakdown Modal ──

    handleViewHealthBreakdown() {
        this.healthBreakdown = null;
        this.showHealthBreakdownModal = true;

        getPortfolioHealthBreakdown()
            .then(result => { this.healthBreakdown = result; })
            .catch(err => {
                this.handleError('Failed to load health breakdown', err);
                this.showHealthBreakdownModal = false;
            });
    }

    handleCloseHealthBreakdown() {
        this.showHealthBreakdownModal = false;
    }

    // ── Stat Bar Clicks ──

    handleStatClick(event) {
        const stat = event.currentTarget.dataset.stat;
        if (!stat) return;
        if (stat === 'cases') {
            this.handleOpenCasesClick();
        } else if (stat === 'tasks') {
            this.handleOpenTasksClick();
        } else if (stat === 'pipeline') {
            this.handleOpenPipelineClick();
        }
    }

    handleOpenCasesClick() {
        this.kpiModalTitle = 'Open Cases';
        this.kpiModalType = 'cases';
        this.kpiModalEmptyMessage = 'No open cases across your portfolio — support is clear.';
        this.kpiModalData = [];
        this.showKpiModal = true;

        getAllOpenCasesForPortfolio()
            .then(result => {
                this.kpiModalData = this.sortPortfolioCases(result || []);
            })
            .catch(error => {
                this.handleError('Failed to load cases', error);
                this.showKpiModal = false;
            });
    }

    handleOpenTasksClick() {
        this.kpiModalTitle = 'Overdue Tasks';
        this.kpiModalType = 'tasks';
        this.kpiModalEmptyMessage = 'No overdue tasks across your portfolio — nice work keeping up.';
        this.kpiModalData = [];
        this.showKpiModal = true;

        getOverdueTasksForPortfolio()
            .then(result => {
                this.kpiModalData = this.sortPortfolioTasks(result || []);
            })
            .catch(error => {
                this.handleError('Failed to load overdue tasks', error);
                this.showKpiModal = false;
            });
    }

    handleOpenPipelineClick() {
        this.kpiModalTitle = 'Open Pipeline';
        this.kpiModalType = 'opportunities';
        this.kpiModalEmptyMessage = 'No open opportunities across your portfolio — open an account to create one.';
        this.kpiModalData = [];
        this.showKpiModal = true;

        getAllOpenOpportunitiesForPortfolio()
            .then(result => {
                this.kpiModalData = this.sortPortfolioOpportunities(result || []);
            })
            .catch(error => {
                this.handleError('Failed to load opportunities', error);
                this.showKpiModal = false;
            });
    }

    handleCloseKpiModal() {
        this.showKpiModal = false;
        this.kpiModalData = [];
        this.kpiModalType = '';
    }

    handleKpiRecordClick(event) {
        const recordId = event.currentTarget.dataset.id;
        if (recordId) {
            this.navigateToRecord(recordId);
        }
    }

    // ── Renewal Click ──

    handleRenewalClick(event) {
        const oppId = event.currentTarget.dataset.id;
        if (oppId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: oppId, objectApiName: 'Opportunity', actionName: 'view' }
            });
        }
    }

    // ── Refresh & Error ──

    handleRefresh() {
        this.loadPortfolioData();
    }

    handleError(title, error) {
        this.error = error;
        const errorMessage = error.body ? error.body.message : error.message;
        this.dispatchEvent(
            new ShowToastEvent({ title, message: errorMessage, variant: 'error' })
        );
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    // ══════════════════════════════════════════════════════════
    // COMPUTED PROPERTIES
    // ══════════════════════════════════════════════════════════

    get hasSummary() { return this.summary !== null; }
    get currentYear() { return new Date().getFullYear(); }
    get hasAccounts() { return this.accounts && this.accounts.length > 0; }
    get hasRenewals() { return this.renewals && this.renewals.length > 0; }

    // ── Portfolio-level empty-state disambiguation ──
    // We distinguish three reasons the accounts list can be empty:
    //   1. Onboarding: the user is not Primary CSM on any account at all.
    //   2. Filter: the user has a portfolio, but the current filter hides everything.
    //   3. Generic: summary not yet loaded or data returned unexpectedly empty.
    // Each state needs a different message + CTA, so we gate them with explicit getters.

    /** True when the user has no accounts assigned as Primary CSM. */
    get isPortfolioEmpty() {
        return !!(this.summary && !this.summary.totalAccounts);
    }

    /** True when the user has a portfolio but the active filter is hiding it. */
    get isFilterHidingAccounts() {
        return !!(this.summary && this.summary.totalAccounts > 0 && !this.hasAccounts
            && this.currentFilter && this.currentFilter !== 'all');
    }

    /**
     * True when none of the more specific empty states apply - this is the catch-all
     * (e.g. summary hasn't loaded yet, or the accounts query unexpectedly returned zero
     * rows even though totalAccounts is > 0 with filter = all).
     */
    get isGenericAccountsEmpty() {
        return !this.hasAccounts && !this.isPortfolioEmpty && !this.isFilterHidingAccounts;
    }

    /**
     * When true we render the full Accounts table shell (header row +
     * columns + tbody). This keeps the table shape visible even when a
     * filter hides every account, so the filter-empty state feels like
     * "no matching rows in the table you already know" instead of a
     * generic card that replaces the whole section. The filter-empty
     * message itself is rendered as a single spanning row inside tbody.
     */
    get showAccountsTable() {
        return this.hasAccounts || this.isFilterHidingAccounts;
    }

    /**
     * Greeting used in the onboarding card title. We intentionally keep this
     * short and warm — the "empty portfolio" idea is already conveyed by the
     * lead sentence below the title, so repeating it here just makes the card
     * feel heavy. Falls back gracefully when we can't resolve a name.
     */
    get noPortfolioTitle() {
        const name = this.summary && this.summary.currentUserName;
        if (name) {
            const firstName = name.split(' ')[0];
            return `Welcome, ${firstName}`;
        }
        return 'Welcome';
    }

    /** Title shown when a filter is hiding the whole portfolio. */
    get filterEmptyTitle() {
        const label = this.filterDisplayLabel;
        if (label) {
            return `No accounts match "${label}"`;
        }
        return 'No accounts match the current filter';
    }

    /** User-friendly label for whichever filter is active. */
    get filterDisplayLabel() {
        const map = {
            'at-risk': 'At Risk',
            'needs-attention': 'Needs Attention',
            'healthy': 'Healthy',
            'inactive': 'Inactive',
            'overdue': 'Overdue tasks',
            'highpri': 'High priority cases'
        };
        return map[this.currentFilter] || '';
    }

    handleClearFilters() {
        if (this.currentFilter !== 'all') {
            this.applyAccountFocus('all');
        }
    }

    // ── Zero-tone helpers ──
    // When a snapshot tile's value is 0, we want it rendered in a muted tone so the user
    // doesn't misread it as an alert or a failure. Each getter returns the class list for
    // the <span class="commercial-kpi-value"> element of that specific tile.

    get lifetimeValueClass() {
        return this._valueClassForNumber(this.summary && this.summary.totalClosedWonAmount);
    }
    get wonYtdValueClass() {
        return this._valueClassForNumber(this.summary && this.summary.totalYtdClosedWon);
    }
    get openPipelineValueClass() {
        return this._valueClassForNumber(this.summary && this.summary.totalOpenPipeline);
    }
    get ytdCasesValueClass() {
        return this._valueClassForNumber(this.summary && this.summary.ytdCaseCount, 'commercial-kpi-value commercial-kpi-value--num');
    }
    get cases90ValueClass() {
        return this._valueClassForNumber(this.summary && this.summary.casesOpenedLast90Days, 'commercial-kpi-value commercial-kpi-value--num');
    }
    get escalated90ValueClass() {
        return this._valueClassForNumber(this.summary && this.summary.escalatedCasesLast90Days, 'commercial-kpi-value commercial-kpi-value--num');
    }

    _valueClassForNumber(value, base = 'commercial-kpi-value') {
        const numeric = Number(value) || 0;
        if (numeric === 0) {
            return `${base} commercial-kpi-value--zero`;
        }
        return base;
    }

    // ── Top-level error / permission state ──

    get isPermissionError() {
        return this._errorLooksLikePermission(this.error);
    }

    get showTopLevelPermissionState() {
        return !!this.error && !this.summary && this.isPermissionError;
    }

    get showTopLevelErrorState() {
        return !!this.error && !this.summary && !this.isPermissionError;
    }

    /**
     * True when we should hide the entire dashboard and show only a full-page
     * empty state. Covers:
     *   - user's portfolio is empty (no accounts where they are Primary CSM)
     *   - permission error on initial load
     *   - fatal load error on initial load
     */
    get showFullPageEmpty() {
        return (
            this.showTopLevelPermissionState ||
            this.showTopLevelErrorState ||
            this.isPortfolioEmpty
        );
    }

    /** Inverse of showFullPageEmpty, used to gate the normal dashboard sections. */
    get showDashboardContent() {
        return !this.showFullPageEmpty;
    }

    /**
     * Permission set that unlocks this dashboard. We surface the LABEL
     * (what admins see in the Permission Sets list and Quick Find
     * search), not the API name — this screen is for non-technical
     * users who are pasting a name into a message to their admin.
     * Sourced from the label in force-app/.../permissionsets/
     * CSD_CS_Dashboard_Full_Access.permissionset-meta.xml so the value
     * stays in sync across any org this project is deployed to.
     */
    get permissionSetName() {
        return 'CS Dashboard Full Access';
    }

    /**
     * Supporting line on the permission card. Intentionally short and
     * non-technical — the primary CTA below carries the "copy the
     * permission set name" detail, so this line doesn't need to
     * repeat it.
     */
    get permissionErrorBody() {
        return 'Ask your admin to give you access.';
    }

    /**
     * Secondary CTA on the permission error. Copies the permission-set name
     * to the clipboard so the user can paste it into a Slack/email to their
     * admin. Falls back to a toast if the Clipboard API isn't available.
     */
    handleCopyPermissionSetName() {
        const name = this.permissionSetName;
        const showSuccess = () => this.dispatchEvent(new ShowToastEvent({
            title: 'Copied',
            message: `"${name}" is on your clipboard — paste it in a message to your admin.`,
            variant: 'success'
        }));
        const showFallback = () => this.dispatchEvent(new ShowToastEvent({
            title: 'Permission set name',
            message: name,
            variant: 'info',
            mode: 'sticky'
        }));
        try {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(name).then(showSuccess, showFallback);
            } else {
                showFallback();
            }
        } catch (_) {
            showFallback();
        }
    }

    get topLevelErrorDetail() {
        const e = this.error;
        if (!e) return '';
        if (e.body && e.body.message) return e.body.message;
        if (e.message) return e.message;
        try { return JSON.stringify(e); } catch (_) { return String(e); }
    }

    _errorLooksLikePermission(e) {
        if (!e) return false;
        const msg =
            (e.body && e.body.message) ||
            (e.body && e.body.stackTrace) ||
            e.message || '';
        const s = String(msg || '').toUpperCase();
        return s.indexOf('INSUFFICIENT_ACCESS') !== -1
            || s.indexOf('INSUFFICIENT_OBJECT_ACCESS') !== -1
            || s.indexOf('FIELD_CUSTOM_VALIDATION_EXCEPTION: ACCESS') !== -1
            || s.indexOf('NOT AUTHORIZED') !== -1
            || s.indexOf('NO ACCESS') !== -1;
    }

    /**
     * True only when the user has a portfolio AND none of their accounts have a real
     * health score yet. Surfaces a one-click "Recalculate all" banner. We don't show
     * the banner on a partially-assessed portfolio because per-account recalculation
     * already lives on the account dashboard.
     */
    get showAllNotAssessedBanner() {
        if (!this.summary) return false;
        const total = this.summary.totalAccounts || 0;
        const unassessed = this.summary.notAssessedAccounts || 0;
        return total > 0 && unassessed === total;
    }

    /**
     * Trigger recalculation for every account in the user's portfolio and refresh
     * the dashboard. Safe to click multiple times - the button is disabled while in flight.
     */
    /**
     * Kicks off the server-side batch recalculation and starts polling for
     * progress. The batch scales to portfolios of any size (50k+) because
     * the work happens asynchronously inside Batch Apex chunks instead of
     * a single synchronous transaction, so we stay well under the SOQL/DML/
     * CPU governor limits no matter how big the portfolio.
     *
     * UX contract:
     *   - Button stays disabled while isRecalculatingAll is true.
     *   - recalcProgress exposes live "processed of total chunks" to the UI.
     *   - On completion, we refresh dashboard data and show a success toast.
     *   - On failure, we clear the progress + show an error toast.
     */
    handleRecalculateAll() {
        if (this.isRecalculatingAll) return;
        this.isRecalculatingAll = true;
        this.recalcError = null;
        this.recalcAdminCopied = false;
        this.recalcProgress = { status: 'Queued', processedChunks: 0, totalChunks: 0, done: false };
        startPortfolioRecalc()
            .then((jobId) => {
                this._recalcJobId = jobId;
                this._startRecalcPolling();
            })
            .catch((error) => {
                // start failure: no job id yet, so fall back to a generic payload.
                this._failRecalc({
                    status: 'Failed',
                    extendedStatus: this._extractErrorMessage(error),
                    processedChunks: 0,
                    totalChunks: 0,
                    numberOfErrors: 1
                });
            });
    }

    /**
     * Polls AsyncApexJob every second while the batch runs. One second is
     * snappy enough that a small portfolio (a handful of accounts, typically
     * one batch chunk) feels near-instant, and gentle enough that a large
     * portfolio (hundreds of chunks over many minutes) doesn't hammer the
     * server. Stops automatically when the job hits a terminal state.
     */
    _startRecalcPolling() {
        this._stopRecalcPolling();
        const tick = () => {
            if (!this._recalcJobId) return;
            getRecalcJobStatus({ jobId: this._recalcJobId })
                .then((status) => {
                    if (!status) return;
                    this.recalcProgress = status;
                    if (status.done) {
                        this._stopRecalcPolling();
                        const hadErrors =
                            status.status !== 'Completed' ||
                            (status.numberOfErrors && status.numberOfErrors > 0);
                        if (hadErrors) {
                            this._failRecalc(status);
                        } else {
                            this._succeedRecalc();
                        }
                    }
                })
                .catch((error) => {
                    // Polling failure is itself a failure we should surface —
                    // the backend job may still be running, but from the UI's
                    // perspective we can no longer trust the progress state.
                    this._stopRecalcPolling();
                    this._failRecalc({
                        jobId: this._recalcJobId,
                        status: 'Failed',
                        extendedStatus: this._extractErrorMessage(error),
                        processedChunks: (this.recalcProgress && this.recalcProgress.processedChunks) || 0,
                        totalChunks: (this.recalcProgress && this.recalcProgress.totalChunks) || 0,
                        numberOfErrors: 1
                    });
                });
        };
        // Fire one tick immediately so the user sees progress ASAP, then poll.
        tick();
        this._recalcPollTimer = setInterval(tick, 1000);
    }

    _stopRecalcPolling() {
        if (this._recalcPollTimer) {
            clearInterval(this._recalcPollTimer);
            this._recalcPollTimer = null;
        }
    }

    /**
     * Success path: clear state, toast, refresh dashboard.
     */
    _succeedRecalc() {
        this.isRecalculatingAll = false;
        this._recalcJobId = null;
        this.recalcProgress = null;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Portfolio recalculated',
            message: 'Health scores refreshed from the latest data.',
            variant: 'success'
        }));
        this.handleRefresh();
    }

    /**
     * Failure path: stash the structured error so the error modal can
     * render a clear "what went wrong + copy-for-admin" screen. We do
     * NOT toast here — a toast disappears, and the point of this flow
     * is giving the user a paste-ready message they can send to their
     * admin without re-triggering the failure.
     */
    _failRecalc(status) {
        this.isRecalculatingAll = false;
        this._recalcJobId = null;
        this.recalcProgress = null;
        this.recalcAdminCopied = false;
        this.recalcError = status || { status: 'Failed' };
    }

    _extractErrorMessage(error) {
        return (error && error.body && error.body.message) ||
            (error && error.message) ||
            'Unknown error';
    }

    // ── Recalc error modal ─────────────────────────────────────

    get showRecalcErrorModal() {
        return !!this.recalcError;
    }

    /**
     * Short, human-readable explanation of the failure shown in the
     * modal body. We prefer the Salesforce-provided extendedStatus when
     * we have it (that's the real cause); otherwise we fall back to a
     * neutral message so the modal never shows an empty paragraph.
     */
    get recalcErrorReason() {
        const err = this.recalcError || {};
        if (err.extendedStatus) {
            return err.extendedStatus;
        }
        return 'The recalculation job stopped before it could finish.';
    }

    /**
     * Rendered inside a monospace block in the modal — this is the part
     * the user copies.
     */
    get recalcAdminMessage() {
        const err = this.recalcError || {};
        const jobLine = err.jobId
            ? `• Job ID: ${err.jobId} (AsyncApexJob, class CSD_PortfolioRecalcBatch)`
            : '• Job: CSD_PortfolioRecalcBatch (did not start — see reason below)';
        const progressLine =
            err.totalChunks
                ? `• Progress at failure: ${err.processedChunks || 0} of ${err.totalChunks} chunks processed`
                : '• Progress at failure: job did not start processing chunks';
        const errorCount = err.numberOfErrors || 0;
        const errorsLine = `• Error count: ${errorCount}`;
        const reasonLine = `• Salesforce reason: ${err.extendedStatus || '(no detail returned by Salesforce)'}`;
        const user = (this.summary && this.summary.currentUserName) || 'the running CSM';
        return [
            'Hi,',
            '',
            `The Customer Success Dashboard's "Recalculate all" job failed while refreshing health scores for ${user}'s portfolio.`,
            '',
            jobLine,
            progressLine,
            errorsLine,
            reasonLine,
            '',
            'The job runs as Batch Apex in chunks of 200 accounts to stay within Salesforce governor limits, but one of the chunks still hit a limit — usually SOQL row count, DML row count, or CPU time. That normally means this org has accounts with a very high volume of activity records (tasks, events, or cases) that the current architecture can\'t process in a single chunk.',
            '',
            'Please edit the architecture in Tribal so CSD_PortfolioRecalcBatch can support the number of records in this org. A smaller batch size on Database.executeBatch, or sub-batched activity queries inside CSD_AccountHealthScoreHandler, would most likely fix it.',
            '',
            'Thanks!'
        ].join('\n');
    }

    get recalcCopyButtonLabel() {
        return this.recalcAdminCopied ? 'Copied!' : 'Copy message for your admin';
    }

    handleCloseRecalcError() {
        this.recalcError = null;
        this.recalcAdminCopied = false;
    }

    handleCopyRecalcAdminMessage() {
        const text = this.recalcAdminMessage;
        const finish = () => {
            this.recalcAdminCopied = true;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Message copied',
                message: 'Paste it into Slack, email, or anywhere your admin will see it.',
                variant: 'success'
            }));
        };
        if (navigator && navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).then(finish).catch(() => {
                this._fallbackCopyToClipboard(text);
                finish();
            });
        } else {
            this._fallbackCopyToClipboard(text);
            finish();
        }
    }

    _fallbackCopyToClipboard(text) {
        try {
            const textarea = document.createElement('textarea');
            textarea.value = text;
            textarea.setAttribute('readonly', '');
            textarea.style.position = 'absolute';
            textarea.style.left = '-9999px';
            document.body.appendChild(textarea);
            textarea.select();
            document.execCommand && document.execCommand('copy');
            document.body.removeChild(textarea);
        } catch (e) {
            // Best-effort; the toast will still have fired so the user
            // at least knows the intent succeeded at the UI layer.
        }
    }

    handleRetryRecalcFromError() {
        this.recalcError = null;
        this.recalcAdminCopied = false;
        this.handleRecalculateAll();
    }

    /**
     * Text shown on the "Recalculate all" button. While a batch is in
     * flight we surface live progress so the user knows work is happening
     * — long-running async jobs with a silent UI are a known trust killer.
     */
    get recalcButtonText() {
        if (!this.isRecalculatingAll) {
            return 'Recalculate all';
        }
        const p = this.recalcProgress;
        if (p && p.totalChunks && p.totalChunks > 0) {
            return `Recalculating… ${p.processedChunks || 0} / ${p.totalChunks}`;
        }
        return 'Recalculating…';
    }

    /**
     * Primary CTA on the empty-portfolio onboarding state. Takes the user
     * straight to the Accounts list view where they can open an account and
     * set themselves as Primary CSM — which is the action that actually
     * populates this dashboard.
     */
    handleBrowseAccounts() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Account',
                actionName: 'list'
            }
        });
    }

    // ── Health Distribution ──

    get healthyPercent() {
        if (!this.summary || !this.summary.totalAccounts) return 0;
        return Math.round((this.summary.healthyAccounts / this.summary.totalAccounts) * 100);
    }

    get needsAttentionPercent() {
        if (!this.summary || !this.summary.totalAccounts) return 0;
        return Math.round((this.summary.needsAttentionAccounts / this.summary.totalAccounts) * 100);
    }

    get atRiskPercent() {
        if (!this.summary || !this.summary.totalAccounts) return 0;
        return Math.round((this.summary.atRiskAccounts / this.summary.totalAccounts) * 100);
    }

    get unassessedCount() {
        if (!this.summary) return 0;
        return this.summary.totalAccounts -
            (this.summary.healthyAccounts + this.summary.needsAttentionAccounts + this.summary.atRiskAccounts);
    }

    get unassessedPercent() {
        if (!this.summary || !this.summary.totalAccounts) return 0;
        return Math.round((this.unassessedCount / this.summary.totalAccounts) * 100);
    }

    get greenBarStyle() { return `width: ${this.healthyPercent}%`; }
    get yellowBarStyle() { return `width: ${this.needsAttentionPercent}%`; }
    get redBarStyle() { return `width: ${this.atRiskPercent}%`; }
    get grayBarStyle() { return `width: ${this.unassessedPercent}%`; }

    get heroCardClass() {
        if (!this.summary) return 'hero-card hero-card--gray';
        const h = this.summary.healthyAccounts || 0;
        const y = this.summary.needsAttentionAccounts || 0;
        const r = this.summary.atRiskAccounts || 0;
        if (r > 0 && r >= h) return 'hero-card hero-card--red';
        if (y > h) return 'hero-card hero-card--yellow';
        if (h > 0) return 'hero-card hero-card--green';
        return 'hero-card hero-card--gray';
    }

    get heroScoreValue() {
        return this.healthyPercent;
    }

    // ── Portfolio Health Trend ──
    // Mirrors the per-account trend display on the account dashboard.
    // The trend value comes from Apex (PortfolioSummary.portfolioHealthTrend)
    // — see CSD_CSMPortfolioController.populatePortfolioHealthTrend for
    // how it's computed (single GROUP BY query that scales to 50k+
    // accounts). When the value is null, we hide the trend chip rather
    // than show a misleading "Stable" — that signals "no historical
    // baseline yet" (e.g., first run after deploy).

    get hasPortfolioTrend() {
        return !!(this.summary && this.summary.portfolioHealthTrend);
    }

    get portfolioTrendIcon() {
        if (!this.hasPortfolioTrend) return '→';
        const t = this.summary.portfolioHealthTrend;
        if (t === 'improving') return '↑';
        if (t === 'declining') return '↓';
        return '→';
    }

    get portfolioTrendText() {
        if (!this.hasPortfolioTrend) return '';
        const t = this.summary.portfolioHealthTrend;
        if (t === 'improving') return 'Improving';
        if (t === 'declining') return 'Declining';
        return 'Stable';
    }

    get portfolioTrendValueClass() {
        if (!this.hasPortfolioTrend) return 'trend-value';
        const t = this.summary.portfolioHealthTrend;
        if (t === 'improving') return 'trend-value trend-value--improving';
        if (t === 'declining') return 'trend-value trend-value--declining';
        return 'trend-value trend-value--stable';
    }

    /**
     * Human-readable subtext for the trend chip — e.g. "5 improved · 2 declined"
     * — so the CSM can see the underlying movement at a glance, not just the
     * direction. Hidden when there are no movements (pure stable, all
     * unchanged) since "0 improved · 0 declined" is noise.
     */
    get portfolioTrendDetail() {
        if (!this.hasPortfolioTrend || !this.summary) return '';
        const improved = this.summary.accountsImproved || 0;
        const declined = this.summary.accountsDeclined || 0;
        if (improved === 0 && declined === 0) return '';
        const parts = [];
        if (improved > 0) parts.push(`${improved} improved`);
        if (declined > 0) parts.push(`${declined} declined`);
        return parts.join(' · ');
    }

    /** ARIA label for the trend chip — gives screen readers the full picture. */
    get portfolioTrendAriaLabel() {
        if (!this.hasPortfolioTrend) return '';
        const direction = this.portfolioTrendText.toLowerCase();
        const detail = this.portfolioTrendDetail;
        return detail
            ? `Portfolio health trend: ${direction}. ${detail}.`
            : `Portfolio health trend: ${direction}.`;
    }

    get heroHealthBadgeClass() {
        if (!this.summary) return 'health-badge health-badge--gray';
        const h = this.summary.healthyAccounts || 0;
        const y = this.summary.needsAttentionAccounts || 0;
        const r = this.summary.atRiskAccounts || 0;
        if (r > 0 && r >= h) return 'health-badge health-badge--red';
        if (y > h) return 'health-badge health-badge--yellow';
        if (h > 0) return 'health-badge health-badge--green';
        return 'health-badge health-badge--gray';
    }

    get heroSubText() {
        if (!this.summary) return '';
        return `${this.summary.totalAccounts} account${this.summary.totalAccounts !== 1 ? 's' : ''} in portfolio`;
    }

    get portfolioStatusSummary() {
        if (!this.summary) return [];

        const items = [
            {
                key: 'healthy',
                label: 'Healthy',
                value: this.summary.healthyAccounts || 0,
                valueClass: 'portfolio-summary-value portfolio-summary-value--good'
            },
            {
                key: 'needs-attention',
                label: 'Needs Attention',
                value: this.summary.needsAttentionAccounts || 0,
                valueClass: 'portfolio-summary-value portfolio-summary-value--warning'
            },
            {
                key: 'at-risk',
                label: 'At Risk',
                value: this.summary.atRiskAccounts || 0,
                valueClass: 'portfolio-summary-value portfolio-summary-value--danger'
            }
        ];

        if (this.unassessedCount > 0) {
            items.push({
                key: 'unassessed',
                label: 'Unassessed',
                value: this.unassessedCount,
                valueClass: 'portfolio-summary-value portfolio-summary-value--muted'
            });
        }

        return items;
    }

    get portfolioBreakdownFactors() {
        if (!this.healthBreakdown) return [];

        return [
            this.buildPortfolioBreakdownFactor(
                'activity',
                'Activity Recency',
                this.healthBreakdown.accountsInactiveGreen,
                this.healthBreakdown.accountsInactiveYellow,
                this.healthBreakdown.accountsInactiveRed,
                '<15d healthy, 15-29d warning, 30+d at risk'
            ),
            this.buildPortfolioBreakdownFactor(
                'overdue',
                'Overdue Tasks',
                this.healthBreakdown.accountsOverdueGreen,
                this.healthBreakdown.accountsOverdueYellow,
                this.healthBreakdown.accountsOverdueRed,
                '0 healthy, 1-2 warning, 3+ at risk'
            ),
            this.buildPortfolioBreakdownFactor(
                'highpri',
                'High-Priority Cases',
                this.healthBreakdown.accountsHighPriGreen,
                this.healthBreakdown.accountsHighPriYellow,
                this.healthBreakdown.accountsHighPriRed,
                '0 healthy, 1 warning, 2+ at risk'
            ),
            this.buildPortfolioBreakdownFactor(
                'cases',
                'Total Open Cases',
                this.healthBreakdown.accountsCasesGreen,
                this.healthBreakdown.accountsCasesYellow,
                this.healthBreakdown.accountsCasesRed,
                '0-2 healthy, 3-4 warning, 5+ at risk'
            )
        ];
    }

    // ── Suggested Actions ──

    get suggestedActions() {
        if (!this.summary) return [];
        const actions = [];
        const overdueAccts = this.summary.accountsWithOverdueTasks || 0;
        const highPriAccts = this.summary.accountsWithHighPriCases || 0;
        const inactiveAccts = this.summary.inactiveAccounts || 0;
        const renewalCount = this.summary.upcomingRenewalsCount || 0;

        if (overdueAccts > 0) {
            actions.push({
                id: 'overdue',
                text: `${overdueAccts} account${overdueAccts > 1 ? 's' : ''} with overdue tasks`,
                severity: 'danger',
                actionFilter: 'all',
                dotClass: 'suggested-action-dot suggested-action-dot--danger',
                actionClass: 'suggested-action suggested-action--danger',
                badge: 'Urgent'
            });
        }
        if (highPriAccts > 0) {
            actions.push({
                id: 'highpri',
                text: `${highPriAccts} account${highPriAccts > 1 ? 's' : ''} with high-priority cases`,
                severity: 'danger',
                actionFilter: 'all',
                dotClass: 'suggested-action-dot suggested-action-dot--danger',
                actionClass: 'suggested-action suggested-action--danger',
                badge: 'Urgent'
            });
        }
        if (inactiveAccts > 0) {
            actions.push({
                id: 'inactive',
                text: `${inactiveAccts} account${inactiveAccts > 1 ? 's' : ''} inactive for 30+ days`,
                severity: 'warning',
                actionFilter: 'inactive',
                dotClass: 'suggested-action-dot suggested-action-dot--warning',
                actionClass: 'suggested-action suggested-action--warning',
                badge: 'Attention'
            });
        }
        if (renewalCount > 0) {
            actions.push({
                id: 'renewals',
                text: `${renewalCount} renewal${renewalCount > 1 ? 's' : ''} closing in next 90 days`,
                severity: 'info',
                actionFilter: 'all',
                dotClass: 'suggested-action-dot suggested-action-dot--info',
                actionClass: 'suggested-action suggested-action--info',
                badge: 'Info'
            });
        }
        return actions;
    }

    get hasSuggestedActions() { return this.suggestedActions.length > 0; }
    get hasSuggestedActionModalItems() { return this.suggestedActionModalItems && this.suggestedActionModalItems.length > 0; }
    get hasKpiModalData() { return this.kpiModalData && this.kpiModalData.length > 0; }
    get showCasesModal() { return this.showKpiModal && (this.kpiModalType === 'cases' || this.kpiModalType === 'recentCases'); }
    get showTasksModal() { return this.showKpiModal && this.kpiModalType === 'tasks'; }
    get showOpportunitiesModal() { return this.showKpiModal && (this.kpiModalType === 'opportunities' || this.kpiModalType === 'closedWon'); }
    get showMonthCasesModal() { return this.showKpiModal && this.kpiModalType === 'monthCases'; }
    get showMonthOpportunitiesModal() { return this.showKpiModal && this.kpiModalType === 'monthOpportunities'; }

    get groupedKpiModalData() {
        if (!this.kpiModalData || this.kpiModalData.length === 0) return [];
        const groups = {};
        const order = [];
        for (const item of this.kpiModalData) {
            const name = item.accountName || 'Unknown';
            if (!groups[name]) {
                groups[name] = { accountName: name, accountId: item.accountId, items: [] };
                order.push(name);
            }
            groups[name].items.push(item);
        }
        return order.map(name => groups[name]);
    }

    // ── Stat Bar ──

    get openCasesStatClass() {
        const highPri = this.summary?.accountsWithHighPriCases || 0;
        if (highPri > 0) return 'stat-value stat-value--warning';
        return 'stat-value';
    }

    get overdueTasksStatClass() {
        const overdue = this.summary?.totalOverdueTasks || 0;
        if (overdue > 0) return 'stat-value stat-value--danger';
        return 'stat-value';
    }

    get casesHint() {
        const highPri = this.summary?.accountsWithHighPriCases || 0;
        if (highPri > 0) return `${highPri} high priority`;
        return 'across portfolio';
    }

    get tasksHint() {
        const accts = this.summary?.accountsWithOverdueTasks || 0;
        if (accts > 0) return `across ${accts} account${accts > 1 ? 's' : ''}`;
        return 'none overdue';
    }

    get pipelineFormatted() {
        return this.formatCurrencyShort(this.summary?.totalOpenPipeline || 0);
    }

    // ── Commercial Snapshot ──

    get snapshotClass() {
        return this.snapshotExpanded
            ? 'commercial-snapshot commercial-snapshot--expanded'
            : 'commercial-snapshot commercial-snapshot--collapsed';
    }

    get weightedPipelineFormatted() { return this.formatCurrencyShort(this.summary?.totalWeightedPipeline || 0); }
    get ytdWonFormatted() { return this.formatCurrencyShort(this.summary?.totalYtdClosedWon || 0); }
    get openPipelineFormatted() { return this.formatCurrencyShort(this.summary?.totalOpenPipeline || 0); }

    get atRiskSnapshotClass() {
        return this.getSnapshotCardClass((this.summary?.atRiskAccounts || 0) > 0 ? 'danger' : 'good', true);
    }

    get needsAttentionSnapshotClass() {
        return this.getSnapshotCardClass((this.summary?.needsAttentionAccounts || 0) > 0 ? 'warning' : 'good', true);
    }

    get inactiveSnapshotClass() {
        return this.getSnapshotCardClass((this.summary?.inactiveAccounts || 0) > 0 ? 'warning' : 'good', true);
    }

    get atRiskSnapshotSubtitle() {
        const count = this.summary?.atRiskAccounts || 0;
        return count > 0 ? 'Filter to the accounts needing immediate attention' : 'No at-risk accounts right now';
    }

    get needsAttentionSnapshotSubtitle() {
        const count = this.summary?.needsAttentionAccounts || 0;
        return count > 0 ? 'Filter to accounts showing early risk signals' : 'No accounts in caution status';
    }

    get inactiveSnapshotSubtitle() {
        const count = this.summary?.inactiveAccounts || 0;
        return count > 0 ? 'Filter to accounts without activity in 30+ days' : 'No inactive accounts right now';
    }

    get openCasesSnapshotClass() {
        const highPri = this.summary?.accountsWithHighPriCases || 0;
        const openCases = this.summary?.totalOpenCases || 0;
        if (highPri > 0) {
            return this.getSnapshotCardClass('danger');
        }
        if (openCases > 0) {
            return this.getSnapshotCardClass('warning');
        }
        return this.getSnapshotCardClass('good');
    }

    get highPriorityAccountsSnapshotClass() {
        return this.getSnapshotCardClass((this.summary?.accountsWithHighPriCases || 0) > 0 ? 'danger' : 'good', true);
    }

    get overdueTasksSnapshotClass() {
        return this.getSnapshotCardClass((this.summary?.totalOverdueTasks || 0) > 0 ? 'danger' : 'good');
    }

    get overdueAccountsSnapshotClass() {
        return this.getSnapshotCardClass((this.summary?.accountsWithOverdueTasks || 0) > 0 ? 'danger' : 'good', true);
    }

    get openCasesSnapshotSubtitle() {
        const highPri = this.summary?.accountsWithHighPriCases || 0;
        const openCases = this.summary?.totalOpenCases || 0;
        if (highPri > 0) {
            return `${highPri} account${highPri !== 1 ? 's' : ''} ${highPri === 1 ? 'has' : 'have'} priority cases`;
        }
        return openCases > 0 ? 'Across the full portfolio' : 'No active cases right now';
    }

    get highPriorityAccountsSnapshotSubtitle() {
        const count = this.summary?.accountsWithHighPriCases || 0;
        return count > 0 ? 'Open the priority-case list' : 'No high-priority case hotspots';
    }

    get overdueTasksSnapshotSubtitle() {
        const overdueTasks = this.summary?.totalOverdueTasks || 0;
        const overdueAccounts = this.summary?.accountsWithOverdueTasks || 0;
        if (overdueTasks > 0) {
            return `Across ${overdueAccounts} account${overdueAccounts !== 1 ? 's' : ''}`;
        }
        return 'Nothing is overdue right now';
    }

    get overdueAccountsSnapshotSubtitle() {
        const count = this.summary?.accountsWithOverdueTasks || 0;
        return count > 0 ? 'Open the overdue-task list' : 'No overdue-task hotspots';
    }

    get hasSupportRisk() {
        return (this.summary?.totalOpenCases || 0) > 0 ||
            (this.summary?.accountsWithHighPriCases || 0) > 0 ||
            (this.summary?.totalOverdueTasks || 0) > 0 ||
            (this.summary?.accountsWithOverdueTasks || 0) > 0;
    }

    get supportCasesYearSubtitle() {
        return `Prior year: ${this.summary?.priorYearCaseCount || 0}`;
    }

    get supportCasesYearCardClass() {
        return 'commercial-kpi';
    }

    get supportCasesYearClickClass() {
        return 'commercial-kpi commercial-kpi--click';
    }

    get caseTrendBars() {
        if (!this.summary) return [];
        const s = this.summary;
        const raw = [];
        for (let i = 1; i <= 12; i++) {
            raw.push({
                label: s[`caseMonth${i}Label`] || '',
                current: Number(s[`caseMonth${i}`] || 0),
                avgClose: s[`caseMonth${i}AvgClose`],
                prev: Number(s[`caseMonth${i}Prev`] || 0)
            });
        }
        const max = Math.max(...raw.map((r) => r.current), 1);
        return raw.map((r, index) => {
            const curPct = r.current === 0 ? 0 : Math.max(6, Math.round((r.current / max) * 100));
            const displayLabel = r.label;
            const avgCloseText = r.avgClose != null ? `${r.avgClose} days` : '\u2014';
            return {
                key: `pcm-${index}`,
                monthIndex: index,
                label: displayLabel,
                fullLabel: this._formatMonthTitle(index),
                currentCount: r.current,
                avgCloseTime: avgCloseText,
                currentBarStyle: `height: ${curPct}%;`,
                hasCurrentBar: r.current > 0,
                isTooltipActive: this._activeTooltipKey === `pcm-${index}`,
                tooltipCaseCount: `${r.current} case${r.current !== 1 ? 's' : ''}`,
                tooltipAvgClose: r.current === 0 ? 'No closes' : `Avg close: ${r.avgClose != null ? r.avgClose + 'd' : '\u2014'}`,
                ariaLabel: `${r.label || ''}: ${r.current} cases, avg close ${avgCloseText}`
            };
        });
    }

    get hasCaseMonthData() {
        if (!this.summary) return false;
        for (let i = 1; i <= 12; i++) {
            if (Number(this.summary[`caseMonth${i}`] || 0) > 0) return true;
        }
        return false;
    }

    // ── Revenue Snapshot ──

    get hasUpcomingRenewal() {
        return this.renewals && this.renewals.length > 0;
    }

    get nearestRenewalAmount() {
        if (!this.renewals || this.renewals.length === 0) return 0;
        return this.renewals.reduce((sum, r) => sum + (r.amount || 0), 0);
    }

    get renewalSubtitle() {
        if (!this.renewals || this.renewals.length === 0) return 'No renewals in next 90 days';
        const count = this.renewals.length;
        return `${count} renewal${count !== 1 ? 's' : ''} in next 90 days`;
    }

    get renewalCardClass() {
        if (!this.renewals || this.renewals.length === 0) return 'commercial-kpi';
        const days = this.renewals[0].daysUntilClose;
        if (days <= 14) return 'commercial-kpi commercial-kpi--click commercial-kpi--danger';
        if (days <= 30) return 'commercial-kpi commercial-kpi--click commercial-kpi--warning';
        return 'commercial-kpi commercial-kpi--click';
    }

    get renewalDaysClass() {
        if (!this.renewals || this.renewals.length === 0) return 'commercial-kpi-sub';
        const days = this.renewals[0].daysUntilClose;
        if (days <= 14) return 'commercial-kpi-sub commercial-kpi-sub--danger';
        if (days <= 30) return 'commercial-kpi-sub commercial-kpi-sub--warning';
        return 'commercial-kpi-sub';
    }

    get revenueMonthBars() {
        if (!this.summary) return [];
        const s = this.summary;
        const raw = [];
        for (let i = 1; i <= 12; i++) {
            raw.push({
                label: s[`wonMonth${i}Label`] || '',
                current: Number(s[`wonMonth${i}`] || 0),
                prev: Number(s[`prevWonMonth${i}`] || 0)
            });
        }
        const max = Math.max(...raw.map((r) => r.current), 1);
        return raw.map((r, index) => {
            const curPct = r.current === 0 ? 0 : Math.max(6, Math.round((r.current / max) * 100));
            const displayLabel = r.label;
            return {
                key: `prm-${index}`,
                monthIndex: index,
                label: displayLabel,
                fullLabel: this._formatMonthTitle(index),
                currentAmount: r.current,
                prevAmount: r.prev,
                currentBarStyle: `height: ${curPct}%;`,
                hasCurrentBar: r.current > 0,
                isTooltipActive: this._activeTooltipKey === `prm-${index}`,
                tooltipAmount: this.formatCurrencyShort(r.current),
                tooltipPrevAmount: `Last year: ${this.formatCurrencyShort(r.prev)}`,
                ariaLabel: `${r.label || ''}: ${this.formatCurrencyShort(r.current)}, last year ${this.formatCurrencyShort(r.prev)}`
            };
        });
    }

    get hasRevenueMonthData() {
        if (!this.summary) return false;
        for (let i = 1; i <= 12; i++) {
            if (Number(this.summary[`wonMonth${i}`] || 0) > 0) return true;
        }
        return false;
    }

    handleCommercialRenewalsClick() {
        if (this.renewals && this.renewals.length === 1) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: this.renewals[0].opportunityId, objectApiName: 'Opportunity', actionName: 'view' }
            });
        } else {
            this.openSuggestedAction('renewals');
        }
    }

    handleSnapshotPipelineClick() {
        this.handleOpenPipelineClick();
    }

    handleSnapshotLifetimeValueClick() {
        this.openPortfolioClosedWonModal('ALL_TIME', 'Lifetime value (all closed-won)');
    }

    handleSnapshotWonYtdClick() {
        this.openPortfolioClosedWonModal('YTD', 'Won this year');
    }

    openPortfolioClosedWonModal(scope, title) {
        this.kpiModalTitle = title;
        this.kpiModalType = 'closedWon';
        this.kpiModalEmptyMessage = 'No closed-won opportunities in this period.';
        this.kpiModalData = [];
        this.showKpiModal = true;

        getClosedWonOpportunitiesForPortfolio({ scopeFilter: scope })
            .then(result => {
                this.kpiModalData = this.sortPortfolioOpportunities(result || []);
            })
            .catch(error => {
                this.handleError('Failed to load closed-won opportunities', error);
                this.showKpiModal = false;
            });
    }

    handleSnapshotYtdCasesClick() {
        this.kpiModalTitle = 'Cases opened this year';
        this.kpiModalType = 'recentCases';
        this.kpiModalEmptyMessage = 'No cases opened this year.';
        this.kpiModalData = [];
        this.showKpiModal = true;

        getCasesOpenedYtdForPortfolio()
            .then(result => {
                this.kpiModalData = this.sortPortfolioCases(result || []);
            })
            .catch(error => {
                this.handleError('Failed to load YTD cases', error);
                this.showKpiModal = false;
            });
    }

    handleSnapshotRecentCasesClick() {
        this.kpiModalTitle = 'Cases opened (last 90 days)';
        this.kpiModalType = 'recentCases';
        this.kpiModalEmptyMessage = 'No cases opened in the last 90 days.';
        this.kpiModalData = [];
        this.showKpiModal = true;

        getCasesOpenedInLastDaysForPortfolio({ days: 90 })
            .then(result => {
                this.kpiModalData = this.sortPortfolioCases(result || []);
            })
            .catch(error => {
                this.handleError('Failed to load recent cases', error);
                this.showKpiModal = false;
            });
    }

    // ── Support Snapshot ──

    get hasCaseResolutionData() {
        return Boolean(this.summary && (this.summary.closedCasesAllTimeCount || 0) > 0);
    }

    get formattedAverageResolution() {
        if (!this.summary) {
            return '\u2014';
        }
        return formatAverageResolutionHours(this.summary.averageCaseResolutionHours);
    }

    get averageResolutionCountSubtext() {
        const n = this.summary ? this.summary.closedCasesAllTimeCount || 0 : 0;
        if (n === 0) {
            return '';
        }
        return `Avg of all ${n} closed case${n !== 1 ? 's' : ''}`;
    }

    // ── Detail Accordion Sections ──

    get openTasksAccordionClass() {
        return this.secOpenTasks ? 'section-accordion section-accordion--expanded' : 'section-accordion';
    }

    get casesAccordionClass() {
        return this.secCases ? 'section-accordion section-accordion--expanded' : 'section-accordion';
    }

    get opportunitiesAccordionClass() {
        return this.secOpportunities ? 'section-accordion section-accordion--expanded' : 'section-accordion';
    }

    get upcomingEventsAccordionClass() {
        return this.secUpcomingEvents ? 'section-accordion section-accordion--expanded' : 'section-accordion';
    }

    get hasUpcomingEvents() {
        return this.upcomingEventsList && this.upcomingEventsList.length > 0;
    }

    get upcomingEventsCount() {
        return this.upcomingEventsList ? this.upcomingEventsList.length : 0;
    }

    get upcomingEventsDecorated() {
        if (!this.upcomingEventsList || !this.upcomingEventsList.length) return [];
        return this.upcomingEventsList.map(ev => ({
            ...ev,
            rowClass: 'activity-item'
        }));
    }

    get hasOpenTasksList() {
        return this.openTasksList && this.openTasksList.length > 0;
    }

    get hasOpenCasesList() {
        return this.openCasesList && this.openCasesList.length > 0;
    }

    get hasOpenOpportunitiesList() {
        return this.openOpportunitiesList && this.openOpportunitiesList.length > 0;
    }

    get openTasksCount() {
        return this.summary?.openTasksCount || 0;
    }

    get openCasesCountDisplay() {
        return this.summary?.totalOpenCases || 0;
    }

    get openOpportunitiesCount() {
        return this.openOpportunitiesList ? this.openOpportunitiesList.length : 0;
    }

    get hasOverdueTasks() {
        return (this.summary?.totalOverdueTasks || 0) > 0;
    }

    get openTasksDecorated() {
        if (!this.openTasksList) return [];
        return this.openTasksList.slice(0, 10).map(task => {
            const isOverdue = task.isOverdue;
            const isDueToday = task.dueDate && !isOverdue &&
                new Date(task.dueDate).toDateString() === new Date().toDateString();
            let rowClass = 'activity-item';
            if (isOverdue) rowClass = 'activity-item activity-item--overdue';
            else if (isDueToday) rowClass = 'activity-item activity-item--due-today';

            let urgencyLabel = '';
            if (isOverdue && task.daysOverdue > 0) urgencyLabel = `${task.daysOverdue}d overdue`;
            else if (isDueToday) urgencyLabel = 'Due today';

            return {
                ...task,
                rowClass,
                urgencyLabel,
                showUrgencyIndicator: isOverdue || isDueToday,
                dateMeta: task.dueDate || 'No due date',
                dateMetaClass: isOverdue ? 'activity-meta-date activity-meta-date--overdue' : 'activity-meta-date'
            };
        });
    }

    get openCasesDecorated() {
        if (!this.openCasesList) return [];
        return this.openCasesList.slice(0, 10).map(c => ({
            ...c,
            priorityDotClass: c.priority === 'High' ? 'priority-dot priority-dot--high' :
                (c.priority === 'Medium' ? 'priority-dot priority-dot--medium' : 'priority-dot priority-dot--low')
        }));
    }

    get openOpportunitiesDecorated() {
        if (!this.openOpportunitiesList) return [];
        return this.openOpportunitiesList.slice(0, 10);
    }

    get upcomingRenewalsSnapshotClass() {
        return this.getSnapshotCardClass((this.summary?.upcomingRenewalsCount || 0) > 0 ? 'brand' : 'neutral', this.hasRenewals);
    }

    get commercialPipelineSnapshotClass() {
        return this.getSnapshotCardClass('brand');
    }

    get commercialWeightedPipelineSnapshotClass() {
        return this.getSnapshotCardClass('neutral');
    }

    get commercialYtdWonSnapshotClass() {
        return this.getSnapshotCardClass('good');
    }

    get upcomingRenewalsSnapshotSubtitle() {
        const count = this.summary?.upcomingRenewalsCount || 0;
        return count > 0 ? 'Open renewals closing in the next 90 days' : 'No renewals due in the next 90 days';
    }

    get renewalsDecorated() {
        if (!this.renewals) return [];
        return this.renewals.map(r => ({
            ...r,
            amountFormatted: this.formatCurrencyShort(r.amount || 0),
            daysText: this.getRenewalDaysText(r.daysUntilClose),
            daysClass: this.getRenewalDaysClass(r.daysUntilClose)
        }));
    }

    // ── Filter Pills ──

    get filterPills() {
        return [
            { label: 'All', value: 'all', class: this.pillClass('all') },
            { label: 'At Risk', value: 'at-risk', class: this.pillClass('at-risk') },
            { label: 'Needs Attention', value: 'needs-attention', class: this.pillClass('needs-attention') },
            { label: 'Healthy', value: 'healthy', class: this.pillClass('healthy') },
            { label: 'Inactive', value: 'inactive', class: this.pillClass('inactive') }
        ];
    }

    pillClass(value) {
        return value === this.currentFilter ? 'filter-pill filter-pill--active' : 'filter-pill';
    }

    // ── Account Table ──

    get accountsDecorated() {
        if (!this.accounts || this.accounts.length === 0) return [];
        return this.accounts.map(acc => {
            const isExpanded = acc.accountId === this.expandedAccountId;
            return {
                ...acc,
                expansionKey: acc.accountId + '-expand',
                healthBadgeClass: `health-badge health-badge--${acc.healthScoreColor || 'gray'}`,
                pipelineFormatted: this.formatCurrencyShort(acc.openPipelineAmount),
                daysSinceActivityText: this.getDaysSinceActivityText(acc.daysSinceLastActivity),
                daysSinceActivityClass: this.getDaysSinceActivityClass(acc.daysSinceLastActivity),
                nextActivityText: this.getNextActivityText(acc.daysUntilNextActivity, acc.nextActivityDate),
                casesDisplay: this.getCasesDisplay(acc),
                casesClass: acc.highPriorityCasesCount > 0 ? 'cell-danger' : '',
                tasksDisplay: this.getTasksDisplay(acc),
                tasksClass: acc.overdueTasksCount > 0 ? 'cell-danger' : 'cell-muted',
                renewalDisplay: this.getRenewalDisplay(acc),
                renewalClass: this.getRenewalCellClass(acc),
                isExpanded,
                rowClass: isExpanded ? 'account-row account-row--expanded' : 'account-row',
                chevronClass: isExpanded ? 'row-chevron row-chevron--expanded' : 'row-chevron',
                healthFactors: this.getHealthFactors(acc),
                hasRecentActivities: acc.recentActivities && acc.recentActivities.length > 0
            };
        });
    }

    get selectedAccountModalTitle() {
        return this.selectedAccountName || 'Account Dashboard';
    }

    get sortIndicatorName() {
        return this.sortDirection === 'asc' ? '▲' : '▼';
    }

    getSortIndicator(field) {
        return this.sortField === field ? (this.sortDirection === 'asc' ? ' ▲' : ' ▼') : '';
    }

    get sortIndicatorAccountName() { return this.getSortIndicator('accountName'); }
    get sortIndicatorHealthScore() { return this.getSortIndicator('healthScore'); }

    // ── Progressive reveal ("View more") ──

    get tableSectionClass() {
        return this.isAccountsLoading ? 'table-section table-section--loading' : 'table-section';
    }

    /**
     * The slice of decorated accounts actually shown to the user. Caps
     * at visibleCount so we never render the entire local buffer at once
     * — the whole point of progressive reveal.
     */
    get visibleAccountsDecorated() {
        const all = this.accountsDecorated;
        return all.slice(0, this.visibleCount);
    }

    /**
     * True when there's at least one more account we could surface,
     * either already in the local buffer or fetchable from the server.
     */
    get hasMoreAccountsToReveal() {
        const totalLoaded = this.accounts ? this.accounts.length : 0;
        return this.visibleCount < totalLoaded || this.serverHasMore;
    }

    /** True once the user has expanded past the initial 5. */
    get isExpandedBeyondInitial() {
        return this.visibleCount > this.INITIAL_VISIBLE_COUNT
            && (this.accounts && this.accounts.length > this.INITIAL_VISIBLE_COUNT);
    }

    /**
     * Text for the "View more" CTA. We show the exact count we'd reveal
     * on the next click, so users know what they're getting:
     *   - "View 5 more" when buffer has ≥5 unrevealed
     *   - "View 3 more" when buffer is the limiting factor (last partial)
     *   - "Load 5 more" when we'll have to round-trip to the server
     *   - "Loading…" while a server fetch is in flight
     */
    get viewMoreLabel() {
        if (this.isAccountsLoading) {
            return 'Loading more…';
        }
        const totalLoaded = this.accounts ? this.accounts.length : 0;
        const room = totalLoaded - this.visibleCount;
        if (room >= this.VIEW_MORE_INCREMENT) {
            return `View ${this.VIEW_MORE_INCREMENT} more`;
        }
        if (room > 0) {
            // Local buffer is small; we'll reveal what's there + a server
            // fetch in the same click. Communicate the local part — the
            // user sees movement either way.
            return this.serverHasMore
                ? `View ${this.VIEW_MORE_INCREMENT} more`
                : `View ${room} more`;
        }
        return `Load ${this.VIEW_MORE_INCREMENT} more`;
    }

    /**
     * Friendly count copy shown next to the section title. Avoids the
     * old "1–25" pagination range, which forced users to do mental math
     * to know the total.
     */
    get accountCountLabel() {
        const visible = Math.min(
            this.visibleCount,
            this.accounts ? this.accounts.length : 0
        );
        const known = this.accounts ? this.accounts.length : 0;
        if (known === 0) {
            return '';
        }
        const allRevealedAndKnown = visible >= known && !this.serverHasMore;
        if (allRevealedAndKnown) {
            return known === 1 ? '1 account' : `${known} accounts`;
        }
        const suffix = this.serverHasMore ? '+' : '';
        return `Showing ${visible} of ${known}${suffix}`;
    }

    /*
     * Backwards-compat alias — older code paths still reference
     * paginationInfo. Returning the new label keeps any straggling
     * callers working without a behavior change.
     */
    get paginationInfo() {
        return this.accountCountLabel;
    }

    // ══════════════════════════════════════════════════════════
    // HELPER METHODS
    // ══════════════════════════════════════════════════════════

    applyAccountFocus(filter, sortField = this.sortField, sortDirection = this.sortDirection) {
        this.currentFilter = filter;
        this.sortField = sortField;
        this.sortDirection = sortDirection;
        this.currentPage = 1;
        this.visibleCount = this.INITIAL_VISIBLE_COUNT;
        this.isAccountsLoading = true;
        this.loadAccounts().then(() => { this.isAccountsLoading = false; });
    }

    formatCurrencyShort(value) {
        if (value == null || value === 0) return '$0';
        if (value >= 1000000) return `$${(value / 1000000).toFixed(1)}M`;
        if (value >= 1000) return `$${(value / 1000).toFixed(0)}K`;
        return `$${value.toFixed(0)}`;
    }

    compareText(left, right) {
        return (left || '').localeCompare(right || '', undefined, { sensitivity: 'base' });
    }

    getCaseSeverityRank(record) {
        if (record?.isEscalated) return 0;

        const priority = (record?.priority || '').toLowerCase();
        if (priority === 'critical') return 1;
        if (priority === 'high') return 2;
        if (priority === 'medium') return 3;
        if (priority === 'low') return 4;
        return 5;
    }

    sortPortfolioCases(records) {
        return [...records].sort((left, right) => {
            const accountCompare = this.compareText(left.accountName, right.accountName);
            if (accountCompare !== 0) return accountCompare;

            const severityCompare = this.getCaseSeverityRank(left) - this.getCaseSeverityRank(right);
            if (severityCompare !== 0) return severityCompare;

            const ageCompare = (right.age || 0) - (left.age || 0);
            if (ageCompare !== 0) return ageCompare;

            return this.compareText(left.caseNumber, right.caseNumber);
        });
    }

    sortPortfolioTasks(records) {
        return [...records].sort((left, right) => {
            const accountCompare = this.compareText(left.accountName, right.accountName);
            if (accountCompare !== 0) return accountCompare;

            const overdueCompare = (right.daysOverdue || 0) - (left.daysOverdue || 0);
            if (overdueCompare !== 0) return overdueCompare;

            return this.compareText(left.subject, right.subject);
        });
    }

    sortPortfolioOpportunities(records) {
        return [...records].sort((left, right) => {
            const accountCompare = this.compareText(left.accountName, right.accountName);
            if (accountCompare !== 0) return accountCompare;

            const amountCompare = (right.amount || 0) - (left.amount || 0);
            if (amountCompare !== 0) return amountCompare;

            const probabilityCompare = (right.probability || 0) - (left.probability || 0);
            if (probabilityCompare !== 0) return probabilityCompare;

            return this.compareText(left.name, right.name);
        });
    }

    getSnapshotCardClass(tone, clickable = false) {
        return `commercial-kpi commercial-kpi--${tone}${clickable ? ' commercial-kpi--click' : ''}`;
    }

    buildPortfolioBreakdownFactor(key, label, healthy, warning, danger, thresholds) {
        const headlineCount = danger > 0 ? danger : (warning > 0 ? warning : healthy);
        const headlineClass = danger > 0
            ? 'factor-value factor-value--danger'
            : (warning > 0 ? 'factor-value factor-value--warning' : 'factor-value factor-value--good');
        const headlineText = danger > 0
            ? `${danger} account${danger !== 1 ? 's' : ''} at risk`
            : (warning > 0
                ? `${warning} account${warning !== 1 ? 's' : ''} ${warning === 1 ? 'needs' : 'need'} attention`
                : `${healthy} account${healthy !== 1 ? 's' : ''} healthy`);

        return {
            key,
            label,
            headlineCount,
            headlineClass,
            headlineText,
            thresholds,
            stats: [
                {
                    key: `${key}-healthy`,
                    label: 'Healthy',
                    value: healthy,
                    className: 'portfolio-factor-pill portfolio-factor-pill--good'
                },
                {
                    key: `${key}-warning`,
                    label: 'Needs Attention',
                    value: warning,
                    className: 'portfolio-factor-pill portfolio-factor-pill--warning'
                },
                {
                    key: `${key}-danger`,
                    label: 'At Risk',
                    value: danger,
                    className: 'portfolio-factor-pill portfolio-factor-pill--danger'
                }
            ]
        };
    }

    getDaysSinceActivityText(days) {
        if (days == null) return 'No activity';
        if (days === 0) return 'Today';
        if (days === 1) return '1 day ago';
        return `${days} days ago`;
    }

    getDaysSinceActivityClass(days) {
        if (days == null) return 'cell-muted';
        if (days > 30) return 'cell-danger';
        if (days > 14) return 'cell-warning';
        return '';
    }

    getNextActivityText(daysUntil, dateStr) {
        if (daysUntil == null || !dateStr) return 'None scheduled';
        if (daysUntil === 0) return 'Today';
        if (daysUntil === 1) return 'Tomorrow';
        return dateStr;
    }

    getCasesDisplay(acc) {
        if (!acc.openCasesCount) return '0';
        if (acc.highPriorityCasesCount > 0) {
            return `${acc.openCasesCount} (${acc.highPriorityCasesCount} high)`;
        }
        return `${acc.openCasesCount}`;
    }

    getTasksDisplay(acc) {
        if (acc.overdueTasksCount > 0) return `${acc.overdueTasksCount} overdue`;
        return '0 overdue';
    }

    getRenewalDisplay(acc) {
        if (!acc.nearestRenewalDate) return '—';
        if (acc.daysUntilRenewal <= 0) return 'Past due';
        if (acc.daysUntilRenewal <= 30) return `${acc.daysUntilRenewal}d`;
        return acc.nearestRenewalDate;
    }

    getRenewalCellClass(acc) {
        if (!acc.nearestRenewalDate) return 'cell-muted';
        if (acc.daysUntilRenewal <= 14) return 'cell-danger';
        if (acc.daysUntilRenewal <= 30) return 'cell-warning';
        return '';
    }

    getRenewalDaysText(days) {
        if (days == null) return '';
        if (days === 0) return 'Today';
        if (days === 1) return 'Tomorrow';
        return `in ${days} days`;
    }

    getRenewalDaysClass(days) {
        if (days <= 14) return 'renewal-days renewal-days--critical';
        if (days <= 30) return 'renewal-days renewal-days--urgent';
        return 'renewal-days';
    }

    getHealthFactors(acc) {
        const days = acc.daysSinceActivityForHealth;
        const overdue = acc.overdueTasksForHealth || 0;
        const highPri = acc.highPriorityCasesForHealth || 0;
        const totalCases = acc.totalOpenCasesForHealth || 0;

        return [
            {
                label: 'Activity Recency',
                factorType: 'activity',
                value: this.getDaysSinceActivityText(days),
                valueClass: this.getFactorValueClass('activity', days),
                status: this.getFactorStatusLabel('activity', days),
                statusClass: this.getFactorStatusClass('activity', days)
            },
            {
                label: 'Overdue Tasks',
                factorType: 'overdueTasks',
                value: String(overdue),
                valueClass: this.getFactorValueClass('overdue', overdue),
                status: this.getFactorStatusLabel('overdue', overdue),
                statusClass: this.getFactorStatusClass('overdue', overdue)
            },
            {
                label: 'High-Priority Cases',
                factorType: 'highPriCases',
                value: String(highPri),
                valueClass: this.getFactorValueClass('highpri', highPri),
                status: this.getFactorStatusLabel('highpri', highPri),
                statusClass: this.getFactorStatusClass('highpri', highPri)
            },
            {
                label: 'Open Cases',
                factorType: 'openCases',
                value: String(totalCases),
                valueClass: this.getFactorValueClass('cases', totalCases),
                status: this.getFactorStatusLabel('cases', totalCases),
                statusClass: this.getFactorStatusClass('cases', totalCases)
            }
        ];
    }

    getFactorStatusLabel(type, value) {
        if (value == null && type === 'activity') return 'No data';
        if (type === 'activity') {
            if (value >= 30) return 'At Risk';
            if (value >= 15) return 'Warning';
            return 'Healthy';
        }
        if (type === 'overdue') {
            if (value >= 3) return 'At Risk';
            if (value >= 1) return 'Warning';
            return 'Healthy';
        }
        if (type === 'highpri') {
            if (value >= 2) return 'At Risk';
            if (value >= 1) return 'Warning';
            return 'Healthy';
        }
        if (type === 'cases') {
            if (value >= 5) return 'At Risk';
            if (value >= 3) return 'Warning';
            return 'Healthy';
        }
        return 'Healthy';
    }

    getFactorStatusClass(type, value) {
        const label = this.getFactorStatusLabel(type, value);
        if (label === 'At Risk') return 'health-factor-status health-factor-status--red';
        if (label === 'Warning') return 'health-factor-status health-factor-status--yellow';
        if (label === 'No data') return 'health-factor-status health-factor-status--gray';
        return 'health-factor-status health-factor-status--green';
    }

    getFactorValueClass(type, value) {
        const label = this.getFactorStatusLabel(type, value);
        if (label === 'At Risk') return 'health-factor-value health-factor-value--red';
        if (label === 'Warning') return 'health-factor-value health-factor-value--yellow';
        return 'health-factor-value';
    }

    // ══════════════════════════════════════════════════════════
    // QUICK ACTIONS & ACTIVITY MODAL
    // ══════════════════════════════════════════════════════════

    get isTaskModal() {
        return this.activityModalObjectApiName === 'Task';
    }

    get isEventModal() {
        return this.activityModalObjectApiName === 'Event';
    }

    get taskStatusOptions() {
        return this.taskPicklistValues?.statusValues?.map(v => ({ label: v.label, value: v.value })) || [];
    }

    get taskPriorityOptions() {
        return this.taskPicklistValues?.priorityValues?.map(v => ({ label: v.label, value: v.value })) || [];
    }

    get taskTypeOptions() {
        return this.taskPicklistValues?.typeValues?.map(v => ({ label: v.label, value: v.value })) || [];
    }

    get whoIdObjectOptions() {
        return [
            { label: 'Contact', value: 'Contact', iconName: 'standard:contact' },
            { label: 'Lead', value: 'Lead', iconName: 'standard:lead' }
        ];
    }

    get whatIdObjectOptions() {
        return [
            { label: 'Account', value: 'Account', iconName: 'standard:account' },
            { label: 'Opportunity', value: 'Opportunity', iconName: 'standard:opportunity' },
            { label: 'Case', value: 'Case', iconName: 'standard:case' }
        ];
    }

    get whoIdIconName() {
        return this.whoIdObjectType === 'Contact' ? 'standard:contact' : 'standard:lead';
    }

    get whatIdIconName() {
        const iconMap = { Account: 'standard:account', Opportunity: 'standard:opportunity', Case: 'standard:case' };
        return iconMap[this.whatIdObjectType] || 'standard:account';
    }

    get activitySaveDisabled() {
        return this.activityModalSaving;
    }

    resetActivityForm(defaults = {}) {
        this.activityForm = {
            Subject: '', WhoId: null, WhatId: null,
            ActivityDate: null, Status: defaults.Status || '', Priority: defaults.Priority || 'Normal',
            Type: defaults.Type || '', OwnerId: currentUserId, Description: '',
            StartDateTime: null, EndDateTime: null,
            IsAllDayEvent: false, Location: ''
        };
        this.whoIdObjectType = 'Contact';
        this.whatIdObjectType = 'Account';
        this.activityModalSaving = false;
    }

    loadPicklistValuesIfNeeded() {
        if (this.taskPicklistValues) return;
        getTaskPicklistValues()
            .then(result => { this.taskPicklistValues = result; })
            .catch(() => { this.taskPicklistValues = { statusValues: [], priorityValues: [], typeValues: [] }; });
    }

    handleCreateTask() {
        this.activityModalObjectApiName = 'Task';
        this.activityModalTitle = 'New Task';
        this.activityModalIsLogCall = false;
        this.resetActivityForm();
        this.loadPicklistValuesIfNeeded();
        this.showActivityModal = true;
    }

    handleCreateEvent() {
        this.activityModalObjectApiName = 'Event';
        this.activityModalTitle = 'New Event';
        this.activityModalIsLogCall = false;
        this.resetActivityForm();
        this.showActivityModal = true;
    }

    handleLogCall() {
        this.activityModalObjectApiName = 'Task';
        this.activityModalTitle = 'Log a Call';
        this.activityModalIsLogCall = true;
        this.resetActivityForm({ Status: 'Completed', Type: 'Call' });
        this.loadPicklistValuesIfNeeded();
        this.showActivityModal = true;
    }

    handleCreateCase() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'new'
            }
        });
    }

    handleActivityModalCancel() {
        this.showActivityModal = false;
    }

    handleActivityModalSubmit() {
        if (!this.activityForm.Subject) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Subject is required.', variant: 'error' }));
            return;
        }
        if (this.activityModalObjectApiName === 'Event' && !this.activityForm.IsAllDayEvent) {
            if (!this.activityForm.StartDateTime || !this.activityForm.EndDateTime) {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Start and End date/time are required.', variant: 'error' }));
                return;
            }
        }

        this.activityModalSaving = true;
        const fields = { ...this.activityForm };

        Object.keys(fields).forEach(k => {
            if (fields[k] === null || fields[k] === '' || fields[k] === undefined) {
                delete fields[k];
            }
        });

        const apexCall = this.activityModalObjectApiName === 'Event'
            ? createEvent({ fieldsJson: JSON.stringify(fields) })
            : createTask({ fieldsJson: JSON.stringify(fields) });

        const objectLabel = this.activityModalIsLogCall ? 'Call' : this.activityModalObjectApiName;

        apexCall
            .then(() => {
                this.showActivityModal = false;
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: `${objectLabel} created successfully.`, variant: 'success' }));
                this.handleRefresh();
            })
            .catch(error => {
                const msg = error.body ? error.body.message : error.message;
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
            })
            .finally(() => { this.activityModalSaving = false; });
    }

    handleActivityFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        const val = event.target.type === 'checkbox' ? event.target.checked : event.detail.value;
        this.activityForm = { ...this.activityForm, [field]: val };
    }

    handleWhoIdChange(event) {
        this.activityForm = { ...this.activityForm, WhoId: event.detail.recordId || null };
    }

    handleWhatIdChange(event) {
        this.activityForm = { ...this.activityForm, WhatId: event.detail.recordId || null };
    }

    handleOwnerIdChange(event) {
        this.activityForm = { ...this.activityForm, OwnerId: event.detail.recordId || null };
    }

    toggleWhoIdEntityMenu() {
        this.showWhoIdEntityMenu = !this.showWhoIdEntityMenu;
        this.showWhatIdEntityMenu = false;
    }

    toggleWhatIdEntityMenu() {
        this.showWhatIdEntityMenu = !this.showWhatIdEntityMenu;
        this.showWhoIdEntityMenu = false;
    }

    selectWhoIdObject(event) {
        this.whoIdObjectType = event.currentTarget.dataset.value;
        this.activityForm = { ...this.activityForm, WhoId: null };
        this.showWhoIdEntityMenu = false;
    }

    selectWhatIdObject(event) {
        this.whatIdObjectType = event.currentTarget.dataset.value;
        this.activityForm = { ...this.activityForm, WhatId: null };
        this.showWhatIdEntityMenu = false;
    }
}
