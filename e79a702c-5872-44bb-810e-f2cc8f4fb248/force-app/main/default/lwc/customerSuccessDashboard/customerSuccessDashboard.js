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
    @track kpiModalType = ''; // 'cases', 'tasks', 'opportunities'
    @track kpiModalEmptyMessage = '';

    /** Accordion: which detail sections are expanded */
    @track sectionExpanded = {
        overdueTasks: false,
        cases: false,
        opportunities: false,
        activities: false,
        contacts: false
    };

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
        this.kpiModalTitle = 'Open Cases';
        this.kpiModalType = 'cases';
        this.kpiModalEmptyMessage = 'Great job! No open cases.';
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
        this.kpiModalEmptyMessage = 'Great job! No overdue tasks.';
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
        this.kpiModalTitle = 'Opportunities';
        this.kpiModalType = 'opportunities';
        this.kpiModalEmptyMessage = 'No open opportunities.';
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

    /**
     * Handle close KPI modal
     */
    handleCloseKpiModal() {
        this.showKpiModal = false;
        this.kpiModalData = [];
        this.kpiModalType = '';
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
     * Create new task
     */
    handleCreateTask() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Task',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: `WhatId=${this.recordId}`
            }
        });
    }

    /**
     * Create new event
     */
    handleCreateEvent() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Event',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: `WhatId=${this.recordId}`
            }
        });
    }

    /**
     * Log a call (create completed task)
     */
    handleLogCall() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Task',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: `WhatId=${this.recordId},Status=Completed,Type=Call`
            }
        });
    }

    /**
     * Handle suggested action click
     */
    handleSuggestedAction(event) {
        const actionHandler = event.currentTarget.dataset.action;

        // Route to appropriate handler based on action type
        if (actionHandler === 'overdue-tasks') {
            this.handleOverdueTasksClick();
        } else if (actionHandler === 'high-priority-cases') {
            this.handleOpenCasesClick();
        } else if (actionHandler === 'schedule-checkin') {
            this.handleCreateEvent();
        } else if (actionHandler === 'plan-touchpoint') {
            this.handleCreateTask();
        } else if (actionHandler === 'log-call') {
            this.handleLogCall();
        } else {
            // Fallback: determine which action to take based on priority
            if (this.summary && this.summary.overdueTasks > 0) {
                this.handleOverdueTasksClick();
            } else if (this.summary && this.summary.highPriorityCasesCount > 0) {
                this.handleOpenCasesClick();
            } else if (this.summary && this.summary.daysSinceLastActivity > 30) {
                this.handleCreateEvent();
            } else if (this.summary && !this.summary.daysUntilNextActivity) {
                this.handleCreateTask();
            } else {
                this.handleLogCall();
            }
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
     * Get all available suggested actions in priority order
     */
    getSuggestedActionsList() {
        if (!this.summary) return [];

        const actions = [];

        // Priority 1: Overdue Tasks
        if (this.summary.overdueTasks > 0) {
            actions.push({
                text: 'Complete overdue tasks',
                badge: 'Urgent',
                urgency: 'danger',
                handler: 'overdue-tasks',
                showBadge: true
            });
        }

        // Priority 2: High Priority Cases
        if (this.summary.highPriorityCasesCount > 0) {
            actions.push({
                text: 'Review priority cases',
                badge: 'Urgent',
                urgency: 'warning',
                handler: 'high-priority-cases',
                showBadge: true
            });
        }

        // Priority 3: Long inactivity
        if (this.summary.daysSinceLastActivity && this.summary.daysSinceLastActivity > 30) {
            actions.push({
                text: 'Schedule check-in',
                badge: 'Important',
                urgency: 'warning',
                handler: 'schedule-checkin',
                showBadge: true
            });
        }

        // Priority 4: No upcoming activity
        if (!this.summary.daysUntilNextActivity) {
            actions.push({
                text: 'Plan touchpoint',
                badge: '',
                urgency: 'info',
                handler: 'plan-touchpoint',
                showBadge: false
            });
        }

        // Priority 5: Log activity (always available)
        actions.push({
            text: 'Log activity',
            badge: '',
            urgency: 'info',
            handler: 'log-call',
            showBadge: false
        });

        return actions;
    }

    get suggestedAction1() {
        const actions = this.getSuggestedActionsList();
        return actions.length > 0 ? actions[0] : null;
    }

    get suggestedAction2() {
        const actions = this.getSuggestedActionsList();
        return actions.length > 1 ? actions[1] : null;
    }

    get suggestedAction3() {
        const actions = this.getSuggestedActionsList();
        return actions.length > 2 ? actions[2] : null;
    }

    get suggestedAction4() {
        const actions = this.getSuggestedActionsList();
        return actions.length > 3 ? actions[3] : null;
    }

    get hasSuggestedAction1() {
        return this.suggestedAction1 !== null;
    }

    get hasSuggestedAction2() {
        return this.suggestedAction2 !== null;
    }

    get hasSuggestedAction3() {
        return this.suggestedAction3 !== null;
    }

    get hasSuggestedAction4() {
        return this.suggestedAction4 !== null;
    }

    get suggestedAction1Class() {
        const action = this.suggestedAction1;
        if (!action) return 'suggested-action';
        return `suggested-action suggested-action--${action.urgency}`;
    }

    get suggestedAction2Class() {
        const action = this.suggestedAction2;
        if (!action) return 'suggested-action';
        return `suggested-action suggested-action--${action.urgency}`;
    }

    get suggestedAction3Class() {
        const action = this.suggestedAction3;
        if (!action) return 'suggested-action';
        return `suggested-action suggested-action--${action.urgency}`;
    }

    get suggestedAction4Class() {
        const action = this.suggestedAction4;
        if (!action) return 'suggested-action';
        return `suggested-action suggested-action--${action.urgency}`;
    }

    get suggestedAction1DotClass() {
        const action = this.suggestedAction1;
        if (!action) return 'suggested-action-dot';
        return `suggested-action-dot suggested-action-dot--${action.urgency}`;
    }

    get suggestedAction2DotClass() {
        const action = this.suggestedAction2;
        if (!action) return 'suggested-action-dot';
        return `suggested-action-dot suggested-action-dot--${action.urgency}`;
    }

    get suggestedAction3DotClass() {
        const action = this.suggestedAction3;
        if (!action) return 'suggested-action-dot';
        return `suggested-action-dot suggested-action-dot--${action.urgency}`;
    }

    get suggestedAction4DotClass() {
        const action = this.suggestedAction4;
        if (!action) return 'suggested-action-dot';
        return `suggested-action-dot suggested-action-dot--${action.urgency}`;
    }

    // Legacy computed properties for backwards compatibility
    get suggestedActionClass() {
        return this.suggestedAction1Class;
    }

    get suggestedActionText() {
        const action = this.suggestedAction1;
        return action ? action.text : '';
    }

    get suggestedActionBadge() {
        const action = this.suggestedAction1;
        return action ? action.badge : '';
    }

    getSuggestedActionUrgency() {
        const action = this.suggestedAction1;
        return action ? action.urgency : 'info';
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
        return this.showKpiModal && this.kpiModalType === 'cases';
    }

    get showTasksModal() {
        return this.showKpiModal && this.kpiModalType === 'tasks';
    }

    get showOpportunitiesModal() {
        return this.showKpiModal && this.kpiModalType === 'opportunities';
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
        if (!this.summary) return 'None';
        return this.summary.relationshipDepth || 'None';
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
