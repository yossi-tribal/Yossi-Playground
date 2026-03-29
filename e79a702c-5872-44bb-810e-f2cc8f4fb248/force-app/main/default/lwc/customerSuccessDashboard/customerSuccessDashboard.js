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
import createTask from '@salesforce/apex/CSD_CSDashboardController.createTask';
import createEvent from '@salesforce/apex/CSD_CSDashboardController.createEvent';
import getTaskPicklistValues from '@salesforce/apex/CSD_CSDashboardController.getTaskPicklistValues';
import currentUserId from '@salesforce/user/Id';

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
        this.kpiModalTitle = 'Open Cases';
        this.kpiModalType = 'cases';
        this.kpiModalScope = '';
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
        this.kpiModalScope = '';
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
        this.kpiModalTitle = 'Open opportunities';
        this.kpiModalType = 'opportunities';
        this.kpiModalScope = '';
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

    handleCommercialAllTimeClick() {
        this.openClosedWonModal('ALL_TIME', 'All-time won revenue (closed won)');
    }

    handleCommercialYtdClick() {
        this.openClosedWonModal('YTD', 'Won revenue (this year)');
    }

    openClosedWonModal(scope, title) {
        this.kpiModalTitle = title;
        this.kpiModalType = 'closedWon';
        this.kpiModalScope = scope;
        this.kpiModalEmptyMessage = 'No closed-won opportunities in this period.';
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



    handleCommercialRecentCasesClick() {
        this.kpiModalTitle = 'Cases opened (last 90 days)';
        this.kpiModalType = 'recentCases';
        this.kpiModalScope = '';
        this.kpiModalEmptyMessage = 'No cases opened in the last 90 days.';
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

    resetActivityForm(defaults = {}) {
        this.activityForm = {
            Subject: '', WhoId: null, WhatId: this.recordId,
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
        return this.showKpiModal && (this.kpiModalType === 'cases' || this.kpiModalType === 'recentCases');
    }

    get showTasksModal() {
        return this.showKpiModal && this.kpiModalType === 'tasks';
    }

    get showOpportunitiesModal() {
        return this.showKpiModal && (this.kpiModalType === 'opportunities' || this.kpiModalType === 'closedWon');
    }

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

    /** ISO currency for formatted-number (org default from Apex) */
    get currencyCode() {
        if (this.summary && this.summary.currencyCode) {
            return this.summary.currencyCode;
        }
        return 'USD';
    }

    /** Case resolution: median close time formatted to 1 decimal */
    get caseResolutionMedianDays() {
        if (!this.summary) return '0';
        const v = Number(this.summary.medianCaseCloseTimeDays || 0);
        return v % 1 === 0 ? String(v) : v.toFixed(1);
    }

    get caseResolutionMinDays() {
        if (!this.summary) return 0;
        return Math.round(Number(this.summary.minCaseCloseTimeDays || 0));
    }

    get caseResolutionMaxDays() {
        if (!this.summary) return 0;
        return Math.round(Number(this.summary.maxCaseCloseTimeDays || 0));
    }

    get closedCasesLast90Days() {
        return this.summary ? (this.summary.closedCasesLast90Days || 0) : 0;
    }

    get hasCaseResolutionData() {
        return this.closedCasesLast90Days > 0;
    }

    get closedCasesSubtitle() {
        const n = this.closedCasesLast90Days;
        return `Based on ${n} closed case${n !== 1 ? 's' : ''}`;
    }

    get resolutionTrendIcon() {
        if (!this.summary || !this.summary.caseResolutionTrend) return '→';
        if (this.summary.caseResolutionTrend === 'improving') return '↑';
        if (this.summary.caseResolutionTrend === 'declining') return '↓';
        return '→';
    }

    get resolutionTrendText() {
        if (!this.summary || !this.summary.caseResolutionTrend) return 'Stable';
        if (this.summary.caseResolutionTrend === 'improving') return 'Improving';
        if (this.summary.caseResolutionTrend === 'declining') return 'Declining';
        return 'Stable';
    }

    get resolutionTrendClass() {
        const trend = this.summary ? this.summary.caseResolutionTrend : 'stable';
        return `case-resolution-trend case-resolution-trend--${trend || 'stable'}`;
    }

    get resolutionTrendAriaLabel() {
        return `Resolution time ${this.resolutionTrendText.toLowerCase()}`;
    }

    get showCaseResolutionRange() {
        return this.hasCaseResolutionData && this.caseResolutionMinDays !== this.caseResolutionMaxDays;
    }

    get caseResolutionRangeText() {
        return `Fastest ${this.caseResolutionMinDays}d · Slowest ${this.caseResolutionMaxDays}d`;
    }

    /** Monthly case volume: 6-month bar array */
    get caseTrendBars() {
        if (!this.summary) return [];
        const raw = [
            { label: this.summary.caseMonth1Label, count: Number(this.summary.caseMonth1 || 0) },
            { label: this.summary.caseMonth2Label, count: Number(this.summary.caseMonth2 || 0) },
            { label: this.summary.caseMonth3Label, count: Number(this.summary.caseMonth3 || 0) },
            { label: this.summary.caseMonth4Label, count: Number(this.summary.caseMonth4 || 0) },
            { label: this.summary.caseMonth5Label, count: Number(this.summary.caseMonth5 || 0) },
            { label: this.summary.caseMonth6Label, count: Number(this.summary.caseMonth6 || 0) }
        ];
        const max = Math.max(...raw.map((r) => r.count), 1);
        return raw.map((r, index) => {
            const pct = r.count === 0 ? 0 : Math.max(6, Math.round((r.count / max) * 100));
            return {
                key: `cm-${index}`,
                label: r.label || '—',
                count: r.count,
                barStyle: `height: ${pct}%;`,
                ariaLabel: `${r.count} case${r.count !== 1 ? 's' : ''} opened in ${r.label || ''}`
            };
        });
    }

    handleCaseTrendBarClick(event) {
        const label = event.currentTarget.dataset.label;
        this.kpiModalTitle = `Cases opened in ${label}`;
        this.kpiModalType = 'recentCases';
        this.kpiModalScope = '';
        this.kpiModalEmptyMessage = `No cases opened in ${label}.`;
        this.kpiModalData = [];
        this.showKpiModal = true;

        getCasesOpenedInLastDays({ accountId: this.recordId, days: 180 })
            .then(result => {
                this.kpiModalData = result || [];
            })
            .catch(error => {
                this.handleError('Failed to load cases', error);
                this.showKpiModal = false;
            });
    }

    /** Nearest renewal KPI */
    get hasUpcomingRenewal() {
        return this.summary ? Boolean(this.summary.hasUpcomingRenewal) : false;
    }

    get nearestRenewalDays() {
        return this.summary ? (this.summary.nearestRenewalDays || 0) : 0;
    }

    get nearestRenewalAmount() {
        return this.summary ? (this.summary.nearestRenewalAmount || 0) : 0;
    }

    get renewalDaysClass() {
        const days = this.nearestRenewalDays;
        if (days <= 7) return 'commercial-kpi-sub renewal-days--critical';
        if (days <= 30) return 'commercial-kpi-sub renewal-days--urgent';
        return 'commercial-kpi-sub';
    }

    get renewalCardClass() {
        return this.hasUpcomingRenewal
            ? 'commercial-kpi commercial-kpi--click'
            : 'commercial-kpi';
    }

    get renewalSubtitle() {
        if (!this.hasUpcomingRenewal) return 'No open renewal opportunities';
        const days = this.nearestRenewalDays;
        return `${days} day${days !== 1 ? 's' : ''}`;
    }

    handleCommercialRenewalClick() {
        if (this.summary && this.summary.nearestRenewalId) {
            this.navigateToRecord(this.summary.nearestRenewalId);
        }
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
