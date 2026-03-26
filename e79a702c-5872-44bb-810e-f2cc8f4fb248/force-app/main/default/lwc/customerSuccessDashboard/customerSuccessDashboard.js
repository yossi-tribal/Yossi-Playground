import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDashboardSummary from '@salesforce/apex/CSD_CSDashboardController.getDashboardSummary';
import getOpenCases from '@salesforce/apex/CSD_CSDashboardController.getOpenCases';
import getOverdueTasks from '@salesforce/apex/CSD_CSDashboardController.getOverdueTasks';
import getUpcomingActivities from '@salesforce/apex/CSD_CSDashboardController.getUpcomingActivities';
import getAllOpenCases from '@salesforce/apex/CSD_CSDashboardController.getAllOpenCases';
import getAllOverdueTasks from '@salesforce/apex/CSD_CSDashboardController.getAllOverdueTasks';
import getAllOpportunities from '@salesforce/apex/CSD_CSDashboardController.getAllOpportunities';
import getContacts from '@salesforce/apex/CSD_CSDashboardController.getContacts';
import getOpenOpportunities from '@salesforce/apex/CSD_CSDashboardController.getOpenOpportunities';
import getClosedWonOpportunities from '@salesforce/apex/CSD_CSDashboardController.getClosedWonOpportunities';
import getCasesOpenedInLastDays from '@salesforce/apex/CSD_CSDashboardController.getCasesOpenedInLastDays';

/** Shown suggested-action rows (template slots). Contextual actions + optional Log activity; fifth item is never dropped. */
const MAX_SUGGESTED_ACTION_ROWS = 4;

/**
 * Account Send Email quick action — change if your org uses a different API name (Setup → Quick Actions).
 * If navigation fails, users can still use quick actions in the row below.
 */
const ACCOUNT_EMAIL_QUICK_ACTION = 'Account.SendEmail';

export default class CustomerSuccessDashboard extends NavigationMixin(LightningElement) {
    @api recordId; // Account record ID from the page context

    @track summary = null;
    @track cases = [];
    @track overdueTasks = [];
    @track upcomingActivities = [];
    @track contacts = [];
    @track opportunities = [];
    @track isLoading = true;
    @track error = null;
    @track showHealthBreakdownModal = false;
    @track showKpiModal = false;
    @track kpiModalTitle = '';
    @track kpiModalData = [];
    @track kpiModalType = ''; // 'cases', 'tasks', 'opportunities', 'closedWon', 'recentCases'
    @track kpiModalScope = ''; // '' | 'ALL_TIME' | 'YTD' | 'PRIOR_YEAR' for closed-won drilldown
    @track kpiModalEmptyMessage = '';
    @track kpiModalHint = '';

    /** Inline create Task/Event — stay on dashboard after save */
    @track showActivityModal = false;
    /** 'task' | 'call' | 'event' */
    @track activityModalKind = 'task';
    @track activityFormKey = 0;
    @track showConfettiLayer = false;

    /** Accordion: which detail sections are expanded */
    @track sectionExpanded = {
        overdueTasks: false,
        cases: false,
        opportunities: false,
        activities: false,
        contacts: false
    };

    /** Commercial snapshot KPI block expanded (default open) */
    @track commercialSnapshotExpanded = true;

    // Loading states for different sections
    @track isSummaryLoaded = false;
    @track areCasesLoaded = false;
    @track areTasksLoaded = false;
    @track areActivitiesLoaded = false;
    @track areContactsLoaded = false;
    @track areOpportunitiesLoaded = false;

    connectedCallback() {
        this.loadDashboardData();
    }

    /**
     * Load all dashboard data
     */
    loadDashboardData() {
        this.isLoading = true;
        this.error = null;

        // Load summary
        this.loadSummary();

        // Load cases
        this.loadCases();

        // Load overdue tasks
        this.loadOverdueTasks();

        // Load upcoming activities
        this.loadUpcomingActivities();

        // Load contacts
        this.loadContacts();

        // Load opportunities
        this.loadOpportunities();
    }

    /**
     * Load dashboard summary
     */
    loadSummary() {
        getDashboardSummary({ accountId: this.recordId })
            .then(result => {
                this.summary = result;
                this.isSummaryLoaded = true;
                this.checkAllLoaded();
            })
            .catch(error => {
                this.handleError('Failed to load dashboard summary', error);
                this.isSummaryLoaded = true;
                this.checkAllLoaded();
            });
    }

    /**
     * Load open cases
     */
    loadCases() {
        getOpenCases({ accountId: this.recordId, recordLimit: 10 })
            .then(result => {
                this.cases = result;
                this.areCasesLoaded = true;
                this.checkAllLoaded();
            })
            .catch(error => {
                this.handleError('Failed to load cases', error);
                this.areCasesLoaded = true;
                this.checkAllLoaded();
            });
    }

    /**
     * Load overdue tasks
     */
    loadOverdueTasks() {
        getOverdueTasks({ accountId: this.recordId, recordLimit: 5 })
            .then(result => {
                this.overdueTasks = result;
                this.areTasksLoaded = true;
                this.checkAllLoaded();
            })
            .catch(error => {
                this.handleError('Failed to load overdue tasks', error);
                this.areTasksLoaded = true;
                this.checkAllLoaded();
            });
    }

    /**
     * Load upcoming activities
     */
    loadUpcomingActivities() {
        getUpcomingActivities({ accountId: this.recordId, recordLimit: 5 })
            .then(result => {
                this.upcomingActivities = result;
                this.areActivitiesLoaded = true;
                this.checkAllLoaded();
            })
            .catch(error => {
                this.handleError('Failed to load upcoming activities', error);
                this.areActivitiesLoaded = true;
                this.checkAllLoaded();
            });
    }

    /**
     * Check if all data is loaded
     */
    checkAllLoaded() {
        if (this.isSummaryLoaded && this.areCasesLoaded &&
            this.areTasksLoaded && this.areActivitiesLoaded &&
            this.areContactsLoaded && this.areOpportunitiesLoaded) {
            this.isLoading = false;
            this.applyDefaultSectionExpansion();
        }
    }

    /**
     * Auto-expand: overdue tasks first, else upcoming activities.
     */
    applyDefaultSectionExpansion() {
        const overdue =
            (this.summary && this.summary.overdueTasks > 0) ||
            (this.overdueTasks && this.overdueTasks.length > 0);
        const upcoming = this.upcomingActivities && this.upcomingActivities.length > 0;
        this.sectionExpanded = {
            overdueTasks: overdue,
            cases: false,
            opportunities: false,
            activities: !overdue && upcoming,
            contacts: false
        };
    }

    /**
     * Toggle accordion section
     */
    handleToggleSection(event) {
        const section = event.currentTarget.dataset.section;
        if (!section) return;
        this.sectionExpanded = {
            ...this.sectionExpanded,
            [section]: !this.sectionExpanded[section]
        };
    }

    handleToggleCommercialSnapshot() {
        this.commercialSnapshotExpanded = !this.commercialSnapshotExpanded;
    }

    /**
     * Load contacts
     */
    loadContacts() {
        getContacts({ accountId: this.recordId, recordLimit: 10 })
            .then(result => {
                this.contacts = result;
                this.areContactsLoaded = true;
                this.checkAllLoaded();
            })
            .catch(error => {
                this.handleError('Failed to load contacts', error);
                this.areContactsLoaded = true;
                this.checkAllLoaded();
            });
    }

    /**
     * Load opportunities
     */
    loadOpportunities() {
        getOpenOpportunities({ accountId: this.recordId, recordLimit: 10 })
            .then(result => {
                this.opportunities = result;
                this.areOpportunitiesLoaded = true;
                this.checkAllLoaded();
            })
            .catch(error => {
                this.handleError('Failed to load opportunities', error);
                this.areOpportunitiesLoaded = true;
                this.checkAllLoaded();
            });
    }

    /**
     * Handle refresh button click
     */
    handleRefresh() {
        this.isSummaryLoaded = false;
        this.areCasesLoaded = false;
        this.areTasksLoaded = false;
        this.areActivitiesLoaded = false;
        this.areContactsLoaded = false;
        this.areOpportunitiesLoaded = false;
        this.loadDashboardData();
    }

    /**
     * Handle error and show toast
     */
    handleError(title, error) {
        this.error = error;
        const errorMessage = error.body ? error.body.message : error.message;
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: errorMessage,
                variant: 'error'
            })
        );
    }

    /**
     * Navigate to a record
     */
    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    /**
     * Handle case row click
     */
    handleCaseClick(event) {
        const caseId = event.currentTarget.dataset.id;
        this.navigateToRecord(caseId);
    }

    /**
     * Handle activity row click
     */
    handleActivityClick(event) {
        const activityId = event.currentTarget.dataset.id;
        this.navigateToRecord(activityId);
    }

    /**
     * Handle metric card click (open modal with records)
     */
    handleMetricClick(event) {
        const metric = event.currentTarget.dataset.metric;

        if (metric === 'cases') {
            this.handleOpenCasesClick();
        } else if (metric === 'tasks') {
            this.handleOverdueTasksClick();
        } else if (metric === 'opportunities') {
            this.handleOpportunitiesClick();
        }
    }

    /**
     * Handle Open Cases KPI click
     */
    handleOpenCasesClick() {
        this.kpiModalTitle = 'Open cases';
        this.kpiModalType = 'cases';
        this.kpiModalScope = '';
        this.kpiModalEmptyMessage = 'Great job! No open cases.';
        this.kpiModalHint =
            'All open cases for this account, including high-priority items, sorted with escalated and higher priority first.';
        this.kpiModalData = [];
        this.showKpiModal = true;

        getAllOpenCases({ accountId: this.recordId })
            .then(result => {
                this.kpiModalData = result || [];
            })
            .catch(error => {
                this.handleError('Failed to load cases', error);
                this.showKpiModal = false;
            });
    }

    /**
     * Handle Overdue Tasks KPI click
     */
    handleOverdueTasksClick() {
        this.kpiModalTitle = 'Overdue Tasks';
        this.kpiModalType = 'tasks';
        this.kpiModalScope = '';
        this.kpiModalEmptyMessage = 'Great job! No overdue tasks.';
        this.kpiModalHint = '';
        this.kpiModalData = [];
        this.showKpiModal = true;

        getAllOverdueTasks({ accountId: this.recordId })
            .then(result => {
                this.kpiModalData = result || [];
            })
            .catch(error => {
                this.handleError('Failed to load overdue tasks', error);
                this.showKpiModal = false;
            });
    }

    /**
     * Handle Opportunities KPI click
     */
    handleOpportunitiesClick() {
        this.kpiModalTitle = 'Open opportunities';
        this.kpiModalType = 'opportunities';
        this.kpiModalScope = '';
        this.kpiModalEmptyMessage = 'No open opportunities.';
        this.kpiModalHint = '';
        this.kpiModalData = [];
        this.showKpiModal = true;

        getAllOpportunities({ accountId: this.recordId })
            .then(result => {
                this.kpiModalData = result || [];
            })
            .catch(error => {
                this.handleError('Failed to load opportunities', error);
                this.showKpiModal = false;
            });
    }

    handleCommercialAllTimeClick() {
        this.openClosedWonModal('ALL_TIME', 'All-time won revenue (closed won)');
    }

    handleCommercialYtdClick() {
        this.openClosedWonModal('YTD', 'Won revenue (this year)');
    }

    handleCommercialPriorYearClick() {
        this.openClosedWonModal('PRIOR_YEAR', 'Won revenue (prior calendar year)');
    }

    openClosedWonModal(scope, title) {
        this.kpiModalTitle = title;
        this.kpiModalType = 'closedWon';
        this.kpiModalScope = scope;
        this.kpiModalEmptyMessage = 'No closed-won opportunities in this period.';
        this.kpiModalHint = '';
        this.kpiModalData = [];
        this.showKpiModal = true;

        getClosedWonOpportunities({ accountId: this.recordId, scopeFilter: scope })
            .then(result => {
                this.kpiModalData = result || [];
            })
            .catch(error => {
                this.handleError('Failed to load closed-won opportunities', error);
                this.showKpiModal = false;
            });
    }

    handleCommercialPipelineClick() {
        this.handleOpportunitiesClick();
    }

    handleCommercialWeightedClick() {
        this.kpiModalTitle = 'Open pipeline (weighted breakdown)';
        this.kpiModalType = 'opportunities';
        this.kpiModalScope = '';
        this.kpiModalEmptyMessage = 'No open opportunities.';
        this.kpiModalHint = '';
        this.kpiModalData = [];
        this.showKpiModal = true;

        getAllOpportunities({ accountId: this.recordId })
            .then(result => {
                this.kpiModalData = result || [];
            })
            .catch(error => {
                this.handleError('Failed to load opportunities', error);
                this.showKpiModal = false;
            });
    }

    handleCommercialRecentCasesClick() {
        this.kpiModalTitle = 'Cases opened (last 90 days)';
        this.kpiModalType = 'recentCases';
        this.kpiModalScope = '';
        this.kpiModalEmptyMessage = 'No cases opened in the last 90 days.';
        this.kpiModalHint = '';
        this.kpiModalData = [];
        this.showKpiModal = true;

        getCasesOpenedInLastDays({ accountId: this.recordId, days: 90 })
            .then(result => {
                this.kpiModalData = result || [];
            })
            .catch(error => {
                this.handleError('Failed to load recent cases', error);
                this.showKpiModal = false;
            });
    }

    /**
     * Handle close KPI modal
     */
    handleCloseKpiModal() {
        this.showKpiModal = false;
        this.kpiModalData = [];
        this.kpiModalType = '';
        this.kpiModalScope = '';
        this.kpiModalHint = '';
    }

    /**
     * Handle KPI modal record click
     */
    handleKpiRecordClick(event) {
        const recordId = event.currentTarget.dataset.id;
        if (recordId) {
            this.navigateToRecord(recordId);
        }
    }

    /**
     * Navigate to all cases
     */
    handleViewAllCases() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Account',
                relationshipApiName: 'Cases',
                actionName: 'view'
            }
        });
    }

    /**
     * Navigate to all activities
     */
    handleViewAllActivities() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Account',
                relationshipApiName: 'ActivityHistories',
                actionName: 'view'
            }
        });
    }

    /**
     * Create new case
     */
    handleCreateCase() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: `AccountId=${this.recordId}`
            }
        });
    }

    /**
     * Create new task — modal on this page (no navigation)
     */
    handleCreateTask() {
        this.openActivityModal('task');
    }

    /**
     * Create new event — modal on this page
     */
    handleCreateEvent() {
        this.openActivityModal('event');
    }

    /**
     * Log a call — modal with Task defaults Type=Call, Status=Completed
     */
    handleLogCall() {
        this.openActivityModal('call');
    }

    openActivityModal(kind) {
        this.activityModalKind = kind;
        this.activityFormKey += 1;
        this.showActivityModal = true;
    }

    handleCloseActivityModal() {
        this.showActivityModal = false;
    }

    handleActivityRecordSuccess() {
        this.showActivityModal = false;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Activity created',
                message: 'Your activity was saved. You are still on this dashboard.',
                variant: 'success',
                mode: 'dismissable'
            })
        );
        this.refreshAfterActivityCreated();
        this.runConfetti();
    }

    handleActivityRecordError(event) {
        let msg = 'Could not save. Check required fields and try again.';
        const d = event.detail;
        if (d) {
            if (d.message) {
                msg = d.message;
            } else if (d.detail && d.detail.message) {
                msg = d.detail.message;
            }
        }
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Could not save activity',
                message: msg,
                variant: 'error',
                mode: 'sticky'
            })
        );
    }

    /**
     * Reload summary and activity-related lists without full-page loading spinner
     */
    refreshAfterActivityCreated() {
        this.loadSummary();
        this.loadOverdueTasks();
        this.loadUpcomingActivities();
    }

    /**
     * Decorative confetti from the top of the viewport (canvas overlay)
     */
    runConfetti() {
        this.showConfettiLayer = true;
        Promise.resolve()
            .then(() => Promise.resolve())
            .then(() => {
                const canvas = this.template.querySelector('.csd-confetti-canvas');
                if (!canvas) {
                    this.showConfettiLayer = false;
                    return;
                }
                const ctx = canvas.getContext('2d');
                const w = canvas.clientWidth;
                const h = canvas.clientHeight;
                if (w < 2 || h < 2) {
                    this.showConfettiLayer = false;
                    return;
                }
                canvas.width = w;
                canvas.height = h;
                const colors = ['#1589ee', '#4bca81', '#ffb75d', '#fe9339', '#8a2be2', '#ea001e'];
                const particles = [];
                const n = 110;
                for (let i = 0; i < n; i++) {
                    particles.push({
                        x: Math.random() * w,
                        y: -30 - Math.random() * (h * 0.35),
                        w: 5 + Math.random() * 7,
                        h: 6 + Math.random() * 9,
                        vx: -2.2 + Math.random() * 4.4,
                        vy: 1.8 + Math.random() * 4.5,
                        rot: Math.random() * Math.PI * 2,
                        vr: -0.18 + Math.random() * 0.36,
                        color: colors[Math.floor(Math.random() * colors.length)]
                    });
                }
                let frame = 0;
                const maxFrames = 200;
                const animate = () => {
                    frame++;
                    ctx.clearRect(0, 0, w, h);
                    let anyAbove = false;
                    particles.forEach((p) => {
                        p.x += p.vx;
                        p.y += p.vy;
                        p.vy += 0.09;
                        p.rot += p.vr;
                        if (p.y < h + 60) {
                            anyAbove = true;
                        }
                        ctx.save();
                        ctx.translate(p.x, p.y);
                        ctx.rotate(p.rot);
                        ctx.fillStyle = p.color;
                        ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
                        ctx.restore();
                    });
                    if (frame < maxFrames && anyAbove) {
                        requestAnimationFrame(animate);
                    } else {
                        this.showConfettiLayer = false;
                    }
                };
                requestAnimationFrame(animate);
            });
    }

    /**
     * Open Account email composer (org quick action). Adjust ACCOUNT_EMAIL_QUICK_ACTION if needed.
     */
    handleComposeEmail() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: ACCOUNT_EMAIL_QUICK_ACTION
            },
            state: {
                recordId: this.recordId
            }
        });
    }

    /**
     * Suggested-action row menus (separate handlers so we do not rely on data-* on base components).
     */
    handleScheduleCheckinMenuSelect(event) {
        this.applyScheduleOrTouchpointMenuChoice(event.detail.value);
    }

    handlePlanTouchpointMenuSelect(event) {
        this.applyScheduleOrTouchpointMenuChoice(event.detail.value);
    }

    handleLogActivityMenuSelect(event) {
        const value = event.detail.value;
        if (value === 'call') {
            this.handleLogCall();
        } else if (value === 'task') {
            this.handleCreateTask();
        } else if (value === 'event') {
            this.handleCreateEvent();
        }
    }

    applyScheduleOrTouchpointMenuChoice(value) {
        if (value === 'event') {
            this.handleCreateEvent();
        } else if (value === 'task') {
            this.handleCreateTask();
        } else if (value === 'email') {
            this.handleComposeEmail();
        }
    }

    /**
     * Handle suggested action click (single-action rows: overdue tasks, open cases list)
     */
    handleSuggestedAction(event) {
        const actionHandler = event.currentTarget.dataset.action;

        if (actionHandler === 'overdue-tasks') {
            this.handleOverdueTasksClick();
        } else if (actionHandler === 'high-priority-cases') {
            this.handleOpenCasesClick();
        }
    }

    /**
     * Handle more actions button click
     */
    handleMoreActions() {
        // Navigate to account detail page
        this.navigateToRecord(this.recordId);
    }

    /**
     * Handle view breakdown button click
     */
    handleViewBreakdown() {
        this.showHealthBreakdownModal = true;
    }

    /**
     * Handle close modal button click
     */
    handleCloseModal() {
        this.showHealthBreakdownModal = false;
    }

    // Computed properties for UI display

    get hasSummary() {
        return this.summary !== null;
    }

    get csmDisplayName() {
        if (!this.summary || !this.summary.csmName) {
            return 'Not assigned';
        }
        return this.summary.csmName;
    }

    get secOverdueTasks() {
        return this.sectionExpanded.overdueTasks;
    }

    get secCases() {
        return this.sectionExpanded.cases;
    }

    get secOpportunities() {
        return this.sectionExpanded.opportunities;
    }

    get secActivities() {
        return this.sectionExpanded.activities;
    }

    get secContacts() {
        return this.sectionExpanded.contacts;
    }

    get commercialSnapshotClass() {
        return `commercial-snapshot${this.commercialSnapshotExpanded ? ' commercial-snapshot--expanded' : ' commercial-snapshot--collapsed'}`;
    }

    /**
     * Upcoming activities with row class for next-touchpoint highlight
     */
    get upcomingActivitiesDecorated() {
        if (!this.upcomingActivities || !this.upcomingActivities.length) {
            return [];
        }
        return this.upcomingActivities.map((activity, index) => ({
            ...activity,
            isNextTouchpoint: index === 0 && this.hasNextTouchpoint,
            rowClass:
                index === 0 && this.hasNextTouchpoint
                    ? 'activity-item activity-item--next-touchpoint'
                    : 'activity-item'
        }));
    }

    get upcomingActivitiesCount() {
        return this.upcomingActivities ? this.upcomingActivities.length : 0;
    }

    /**
     * Cases with priority dot class for table
     */
    get casesDecorated() {
        if (!this.cases || !this.cases.length) {
            return [];
        }
        return this.cases.map((c) => ({
            ...c,
            priorityDotClass: this.computePriorityDotClass(c.priority)
        }));
    }

    computePriorityDotClass(priority) {
        const p = (priority || '').toString().toLowerCase();
        if (p.includes('high')) {
            return 'priority-dot priority-dot--high';
        }
        if (p.includes('medium')) {
            return 'priority-dot priority-dot--medium';
        }
        if (p.includes('low')) {
            return 'priority-dot priority-dot--low';
        }
        return 'priority-dot priority-dot--neutral';
    }

    get overdueAccordionClass() {
        return `section-accordion${this.sectionExpanded.overdueTasks ? ' section-accordion--expanded' : ''}`;
    }

    get casesAccordionClass() {
        return `section-accordion${this.sectionExpanded.cases ? ' section-accordion--expanded' : ''}`;
    }

    get opportunitiesAccordionClass() {
        return `section-accordion${this.sectionExpanded.opportunities ? ' section-accordion--expanded' : ''}`;
    }

    get activitiesAccordionClass() {
        return `section-accordion${this.sectionExpanded.activities ? ' section-accordion--expanded' : ''}`;
    }

    get contactsAccordionClass() {
        return `section-accordion${this.sectionExpanded.contacts ? ' section-accordion--expanded' : ''}`;
    }

    get hasCases() {
        return this.cases && this.cases.length > 0;
    }

    get hasOverdueTasks() {
        return this.summary && this.summary.overdueTasks > 0;
    }

    get hasOverdueTasksList() {
        return this.overdueTasks && this.overdueTasks.length > 0;
    }

    get hasUpcomingActivities() {
        return this.upcomingActivities && this.upcomingActivities.length > 0;
    }

    get showInactivityWarning() {
        return this.summary && this.summary.daysSinceLastActivity && this.summary.daysSinceLastActivity > 30;
    }

    // Hero Card Properties
    get heroCardClass() {
        if (!this.summary) return 'hero-card';
        const color = this.summary.accountHealthColor;
        return `hero-card hero-card--${color}`;
    }

    get trendIcon() {
        if (!this.summary || !this.summary.healthTrend) return '→';
        if (this.summary.healthTrend === 'improving') return '↑';
        if (this.summary.healthTrend === 'declining') return '↓';
        return '→';
    }

    get trendText() {
        if (!this.summary || !this.summary.healthTrend) return 'Stable';
        if (this.summary.healthTrend === 'improving') return 'Improving';
        if (this.summary.healthTrend === 'declining') return 'Declining';
        return 'Stable';
    }

    // Stat bar value styles (compact)
    get statCasesValueClass() {
        if (!this.summary) return 'stat-value';
        if (this.summary.highPriorityCasesCount > 0) {
            return 'stat-value stat-value--warning';
        }
        return 'stat-value';
    }

    get statTasksValueClass() {
        if (!this.summary) return 'stat-value';
        if (this.summary.overdueTasks > 0) {
            return 'stat-value stat-value--danger';
        }
        return 'stat-value';
    }

    get statOppsValueClass() {
        return 'stat-value';
    }

    get statCasesSubtext() {
        if (!this.summary) return '';
        if (this.summary.highPriorityCasesCount > 0) {
            return `${this.summary.highPriorityCasesCount} high priority`;
        }
        return 'All normal';
    }

    get statTasksSubtext() {
        if (!this.summary) return '';
        if (this.summary.overdueTasks > 0) {
            return 'Action required';
        }
        return 'On track';
    }

    get lastActivityValueClass() {
        if (!this.summary) return 'metric-value-text';
        if (this.summary.daysSinceLastActivity > 30) {
            return 'metric-value-text metric-value-text--danger';
        } else if (this.summary.daysSinceLastActivity > 7) {
            return 'metric-value-text metric-value-text--warning';
        }
        return 'metric-value-text metric-value-text--success';
    }

    get lastActivityText() {
        if (!this.summary || !this.summary.daysSinceLastActivity) return 'No activity';
        const days = this.summary.daysSinceLastActivity;
        if (days === 0) return 'Today';
        if (days === 1) return '1 day ago';
        return `${days} days ago`;
    }

    get nextActivityValueClass() {
        if (!this.summary) return 'metric-value-text';
        if (!this.summary.daysUntilNextActivity) {
            return 'metric-value-text metric-value-text--gray';
        } else if (this.summary.daysUntilNextActivity < 7) {
            return 'metric-value-text metric-value-text--success';
        }
        return 'metric-value-text';
    }

    get nextActivityText() {
        if (!this.summary || this.summary.daysUntilNextActivity === null) return 'No upcoming';
        const days = this.summary.daysUntilNextActivity;
        if (days === 0) return 'Today';
        if (days === 1) return 'Tomorrow';
        if (days < 0) return `${Math.abs(days)} days ago`;
        return `In ${days} days`;
    }

    get nextOppText() {
        if (!this.summary) return '';
        if (this.summary.nextOpportunityCloseDate && this.summary.nextOpportunityCloseDate !== 'None closing soon') {
            return `Next: ${this.summary.nextOpportunityCloseDate}`;
        }
        return this.summary.nextOpportunityCloseDate || 'None closing soon';
    }

    // Suggested Action Properties
    get hasSuggestedAction() {
        return this.summary !== null;
    }

    /**
     * Contextual suggested actions (priority order), then "Log activity" when a slot remains.
     * Capped at MAX_SUGGESTED_ACTION_ROWS so the last contextual row is never silently dropped.
     */
    getSuggestedActionsList() {
        if (!this.summary) return [];

        const s = this.summary;
        const contextual = [];

        if (s.overdueTasks > 0) {
            contextual.push({
                text: 'Complete overdue tasks',
                badge: 'Urgent',
                urgency: 'danger',
                handler: 'overdue-tasks',
                showBadge: true,
                isMenu: false,
                menuKind: '',
                menuSchedule: false,
                menuTouchpoint: false,
                menuLog: false,
                ariaLabel: 'Complete overdue tasks. Opens a list of overdue tasks for this account.',
                subtext: ''
            });
        }

        if (s.highPriorityCasesCount > 0) {
            contextual.push({
                text: 'Review open cases',
                badge: 'Urgent',
                urgency: 'warning',
                handler: 'high-priority-cases',
                showBadge: true,
                isMenu: false,
                menuKind: '',
                menuSchedule: false,
                menuTouchpoint: false,
                menuLog: false,
                ariaLabel:
                    'Review open cases. Opens all open cases for this account, including high-priority items.',
                subtext: ''
            });
        }

        if (s.daysSinceLastActivity && s.daysSinceLastActivity > 30) {
            const inactiveHint = `No activity in ${s.daysSinceLastActivity} days.`;
            let sub = inactiveHint;
            if (
                s.nextTouchpointSubject &&
                s.nextTouchpointSubject !== 'No upcoming touchpoint' &&
                s.daysUntilNextActivity !== null
            ) {
                sub = `${inactiveHint} Next scheduled: ${s.nextTouchpointSubject}.`;
            }
            contextual.push({
                text: 'Schedule check-in',
                badge: 'Important',
                urgency: 'warning',
                handler: 'menu-schedule-checkin',
                showBadge: true,
                isMenu: true,
                menuKind: 'schedule',
                menuSchedule: true,
                menuTouchpoint: false,
                menuLog: false,
                ariaLabel: 'Schedule check-in. Choose to create an event, task, or send an email.',
                subtext: sub
            });
        }

        if (!s.daysUntilNextActivity) {
            contextual.push({
                text: 'Plan touchpoint',
                badge: '',
                urgency: 'info',
                handler: 'menu-plan-touchpoint',
                showBadge: false,
                isMenu: true,
                menuKind: 'touchpoint',
                menuSchedule: false,
                menuTouchpoint: true,
                menuLog: false,
                ariaLabel: 'Plan touchpoint. Choose a task, event, or email to engage this account.',
                subtext: 'Nothing scheduled ahead on this account.'
            });
        }

        const logActivityRow = {
            text: 'Log activity',
            badge: '',
            urgency: 'info',
            handler: 'menu-log-activity',
            showBadge: false,
            isMenu: true,
            menuKind: 'log',
            menuSchedule: false,
            menuTouchpoint: false,
            menuLog: true,
            ariaLabel: 'Log activity. Choose to log a call, create a task, or schedule an event.',
            subtext: ''
        };

        if (contextual.length >= MAX_SUGGESTED_ACTION_ROWS) {
            return contextual.slice(0, MAX_SUGGESTED_ACTION_ROWS);
        }
        return [...contextual, logActivityRow].slice(0, MAX_SUGGESTED_ACTION_ROWS);
    }

    /**
     * Suggested actions for template (stable keys for for:each)
     */
    get suggestedActionsDisplay() {
        return this.getSuggestedActionsList().map((action, index) => ({
            ...action,
            key: `sa-${index}-${action.handler}-${action.menuKind || 'na'}`,
            rowClass: `suggested-action suggested-action--${action.urgency}`,
            buttonClass: `suggested-action suggested-action--${action.urgency} suggested-action-btn`,
            dotClass: `suggested-action-dot suggested-action-dot--${action.urgency}`
        }));
    }

    get activityModalTitle() {
        if (this.activityModalKind === 'call') {
            return 'Log a call';
        }
        if (this.activityModalKind === 'event') {
            return 'New event';
        }
        return 'New task';
    }

    get showActivityTaskForm() {
        return (
            this.showActivityModal &&
            (this.activityModalKind === 'task' || this.activityModalKind === 'call')
        );
    }

    get showActivityEventForm() {
        return this.showActivityModal && this.activityModalKind === 'event';
    }

    get isActivityModalCall() {
        return this.activityModalKind === 'call';
    }

    get activityTaskFormRows() {
        if (!this.showActivityTaskForm) {
            return [];
        }
        return [{ uid: `${this.activityFormKey}-task` }];
    }

    get activityEventFormRows() {
        if (!this.showActivityEventForm) {
            return [];
        }
        return [{ uid: `${this.activityFormKey}-event` }];
    }

    // Legacy computed properties for backwards compatibility
    get suggestedActionClass() {
        const list = this.getSuggestedActionsList();
        const action = list.length > 0 ? list[0] : null;
        if (!action) return 'suggested-action';
        return `suggested-action suggested-action--${action.urgency}`;
    }

    get suggestedActionText() {
        const list = this.getSuggestedActionsList();
        return list.length > 0 ? list[0].text : '';
    }

    get suggestedActionBadge() {
        const list = this.getSuggestedActionsList();
        return list.length > 0 ? list[0].badge : '';
    }

    getSuggestedActionUrgency() {
        const list = this.getSuggestedActionsList();
        return list.length > 0 ? list[0].urgency : 'info';
    }

    // Health Breakdown Modal Properties
    get trendValueClass() {
        if (!this.summary || !this.summary.healthTrend) return 'trend-value';
        if (this.summary.healthTrend === 'improving') return 'trend-value trend-value--improving';
        if (this.summary.healthTrend === 'declining') return 'trend-value trend-value--declining';
        return 'trend-value trend-value--stable';
    }

    get healthScoreBadgeClass() {
        if (!this.summary) return 'health-badge';
        const color = this.summary.accountHealthColor;
        return `health-badge health-badge--${color}`;
    }

    get trendIconClass() {
        if (!this.summary || !this.summary.healthTrend) return 'trend-icon-large';
        if (this.summary.healthTrend === 'improving') return 'trend-icon-large trend-icon--improving';
        if (this.summary.healthTrend === 'declining') return 'trend-icon-large trend-icon--declining';
        return 'trend-icon-large trend-icon--stable';
    }

    get trendLabelClass() {
        if (!this.summary || !this.summary.healthTrend) return 'trend-label';
        if (this.summary.healthTrend === 'improving') return 'trend-label trend-label--improving';
        if (this.summary.healthTrend === 'declining') return 'trend-label trend-label--declining';
        return 'trend-label trend-label--stable';
    }

    // KPI Modal Properties
    get hasKpiModalData() {
        return this.kpiModalData && this.kpiModalData.length > 0;
    }

    get showCasesModal() {
        return this.showKpiModal && (this.kpiModalType === 'cases' || this.kpiModalType === 'recentCases');
    }

    get showTasksModal() {
        return this.showKpiModal && this.kpiModalType === 'tasks';
    }

    get showOpportunitiesModal() {
        return this.showKpiModal && (this.kpiModalType === 'opportunities' || this.kpiModalType === 'closedWon');
    }

    /** ISO currency for formatted-number (org default from Apex) */
    get currencyCode() {
        if (this.summary && this.summary.currencyCode) {
            return this.summary.currencyCode;
        }
        return 'USD';
    }

    /** YoY bar: dollar ratio (grid fr units) — clearer than % of total width when segments differ greatly */
    get yoyTrackGridStyle() {
        const y = this.summary ? Number(this.summary.ytdWonRevenue || 0) : 0;
        const p = this.summary ? Number(this.summary.priorYearWonRevenue || 0) : 0;
        const t = y + p;
        if (t <= 0) {
            return 'grid-template-columns: 1fr 1fr;';
        }
        return `grid-template-columns: ${y}fr ${p}fr;`;
    }

    get yoyComparisonAriaLabel() {
        const y = this.summary ? Number(this.summary.ytdWonRevenue || 0) : 0;
        const p = this.summary ? Number(this.summary.priorYearWonRevenue || 0) : 0;
        const code = this.currencyCode;
        const fmt = (n) =>
            new Intl.NumberFormat(undefined, { style: 'currency', currency: code }).format(n);
        return `Won revenue comparison. This year year-to-date: ${fmt(y)}. Prior calendar year full year: ${fmt(
            p
        )}. Bar length is proportional to these amounts.`;
    }

    /** Last 4 quarters mini bars: height % vs max in quarter set */
    get commercialQuarterBars() {
        if (!this.summary) {
            return [];
        }
        const raw = [
            { label: this.summary.wonQuarter1Label, value: Number(this.summary.wonQuarter1 || 0) },
            { label: this.summary.wonQuarter2Label, value: Number(this.summary.wonQuarter2 || 0) },
            { label: this.summary.wonQuarter3Label, value: Number(this.summary.wonQuarter3 || 0) },
            { label: this.summary.wonQuarter4Label, value: Number(this.summary.wonQuarter4 || 0) }
        ];
        const max = Math.max(...raw.map((r) => r.value), 1);
        return raw.map((r, index) => {
            const pct = Math.max(6, Math.round((r.value / max) * 100));
            return {
                key: `wq-${index}`,
                label: r.label || '—',
                value: r.value,
                heightPct: pct,
                barStyle: `height: ${pct}%;`
            };
        });
    }

    get openCasesFactorClass() {
        if (!this.summary) return 'factor-value';
        if (this.summary.highPriorityCasesCount > 0) {
            return 'factor-value factor-value--warning';
        }
        return 'factor-value factor-value--good';
    }

    get overdueTasksFactorClass() {
        if (!this.summary) return 'factor-value';
        if (this.summary.overdueTasks > 0) {
            return 'factor-value factor-value--danger';
        }
        return 'factor-value factor-value--good';
    }

    get lastActivityFactorClass() {
        if (!this.summary) return 'factor-value';
        if (this.summary.daysSinceLastActivity > 30) {
            return 'factor-value factor-value--danger';
        } else if (this.summary.daysSinceLastActivity > 7) {
            return 'factor-value factor-value--warning';
        }
        return 'factor-value factor-value--good';
    }

    get daysSinceLastActivityText() {
        if (!this.summary || !this.summary.daysSinceLastActivity) return '0 days';
        const days = this.summary.daysSinceLastActivity;
        return `${days} ${days === 1 ? 'day' : 'days'}`;
    }

    // Relationship Depth Properties
    get relationshipDepthStars() {
        if (!this.summary) return '';
        const starCount = this.summary.relationshipDepthStars || 0;
        return '⭐'.repeat(starCount);
    }

    get relationshipDepthLabel() {
        if (!this.summary) return 'Relationship: None';
        const depth = this.summary.relationshipDepth || 'None';
        return `Relationship: ${depth}`;
    }

    get relationshipDepthTooltip() {
        if (!this.summary) return '';
        const count = this.summary.contactCount || 0;
        return `Relationship depth is based on contact coverage at this account (${count} contact${count !== 1 ? 's' : ''}). 1–4: Weak, 5–9: Moderate, 10+: Strong`;
    }

    get relationshipPillClass() {
        if (!this.summary) return 'relationship-pill';
        const depth = (this.summary.relationshipDepth || 'None').toLowerCase();
        return `relationship-pill relationship-pill--${depth}`;
    }

    get contactCountText() {
        if (!this.summary) return '0 contacts';
        const count = this.summary.contactCount || 0;
        return `${count} ${count === 1 ? 'contact' : 'contacts'}`;
    }

    // Next Touchpoint Properties
    get nextTouchpointDisplay() {
        if (!this.summary) return 'No upcoming';
        const days = this.summary.daysUntilNextActivity;
        if (days === null) return 'No upcoming';
        if (days === 0) return 'Today';
        if (days === 1) return 'Tomorrow';
        if (days < 7) return `In ${days} days`;
        return `In ${days} days`;
    }

    get nextTouchpointSubject() {
        if (!this.summary || !this.summary.nextTouchpointSubject) return 'No upcoming touchpoint';
        return this.summary.nextTouchpointSubject;
    }

    get nextTouchpointTime() {
        if (!this.summary || !this.summary.nextTouchpointTime) return '';
        return this.summary.nextTouchpointTime;
    }

    get hasNextTouchpoint() {
        return this.summary && this.summary.daysUntilNextActivity !== null;
    }

    // Contacts and Opportunities Properties
    get hasContacts() {
        return this.contacts && this.contacts.length > 0;
    }

    get hasOpportunities() {
        return this.opportunities && this.opportunities.length > 0;
    }

    /**
     * Handle contact row click
     */
    handleContactClick(event) {
        const contactId = event.currentTarget.dataset.id;
        this.navigateToRecord(contactId);
    }

    /**
     * Handle opportunity row click
     */
    handleOpportunityClick(event) {
        const opportunityId = event.currentTarget.dataset.id;
        this.navigateToRecord(opportunityId);
    }

    /**
     * Navigate to all contacts
     */
    handleViewAllContacts() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Account',
                relationshipApiName: 'Contacts',
                actionName: 'view'
            }
        });
    }

    /**
     * Navigate to all opportunities
     */
    handleViewAllOpportunities() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Account',
                relationshipApiName: 'Opportunities',
                actionName: 'view'
            }
        });
    }

    /**
     * Create new contact
     */
    handleCreateContact() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Contact',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: `AccountId=${this.recordId}`
            }
        });
    }

    /**
     * Create new opportunity
     */
    handleCreateOpportunity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Opportunity',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: `AccountId=${this.recordId}`
            }
        });
    }
}
