import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPortfolioSummary from '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioSummary';
import getPortfolioAccounts from '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioAccounts';
import getUpcomingRenewals from '@salesforce/apex/CSD_CSMPortfolioController.getUpcomingRenewals';
import getPortfolioHealthBreakdown from '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioHealthBreakdown';
import getOverdueTasksForPortfolio from '@salesforce/apex/CSD_CSMPortfolioController.getOverdueTasksForPortfolio';
import getHighPriorityCasesForPortfolio from '@salesforce/apex/CSD_CSMPortfolioController.getHighPriorityCasesForPortfolio';
import createTask from '@salesforce/apex/CSD_CSDashboardController.createTask';
import createEvent from '@salesforce/apex/CSD_CSDashboardController.createEvent';
import getTaskPicklistValues from '@salesforce/apex/CSD_CSDashboardController.getTaskPicklistValues';
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
    @track currentPage = 1;
    @track pageSize = 25;
    @track totalAccountCount = 0;

    @track expandedAccountId = null;
    @track showAccountModal = false;
    @track selectedAccountId = null;
    @track snapshotExpanded = false;

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

    @track showSuggestedActionModal = false;
    @track suggestedActionModalTitle = '';
    @track suggestedActionModalItems = [];
    @track suggestedActionModalType = '';
    @track suggestedActionModalLoading = false;

    connectedCallback() {
        this.loadPortfolioData();
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
                .catch(err => this.handleError('Failed to load renewals', err))
        ];

        Promise.all(promises).then(() => { this.isLoading = false; });
    }

    loadAccounts() {
        return getPortfolioAccounts({
            filterType: this.currentFilter,
            sortField: this.sortField,
            sortDirection: this.sortDirection,
            pageSize: this.pageSize,
            pageNumber: this.currentPage
        })
            .then(result => {
                this.accounts = result || [];
                this.expandedAccountId = null;
            })
            .catch(err => {
                this.handleError('Failed to load accounts', err);
            });
    }

    // ── Filter Handlers ──

    handleFilterClick(event) {
        const filter = event.currentTarget.dataset.filter;
        if (filter && filter !== this.currentFilter) {
            this.currentFilter = filter;
            this.currentPage = 1;
            this.isLoading = true;
            this.loadAccounts().then(() => { this.isLoading = false; });
        }
    }

    handleHealthBarClick(event) {
        const segment = event.currentTarget.dataset.segment;
        if (!segment) return;
        const filterMap = { green: 'healthy', yellow: 'needs-attention', red: 'at-risk', gray: 'all' };
        const newFilter = filterMap[segment] || 'all';
        if (newFilter !== this.currentFilter) {
            this.currentFilter = newFilter;
            this.currentPage = 1;
            this.isLoading = true;
            this.loadAccounts().then(() => { this.isLoading = false; });
        }
    }

    handleSuggestedActionClick(event) {
        const actionType = event.currentTarget.dataset.actionType;
        if (!actionType) return;

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
                    metricClass: 'action-modal-item-metric'
                }));
                this.suggestedActionModalLoading = false;
                this.showSuggestedActionModal = true;
            }

        } else if (actionType === 'inactive') {
            this.currentFilter = 'inactive';
            this.currentPage = 1;
            this.isLoading = true;
            this.loadAccounts().then(() => { this.isLoading = false; });
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
        this.isLoading = true;
        this.loadAccounts().then(() => { this.isLoading = false; });
    }

    // ── Pagination ──

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.isLoading = true;
            this.loadAccounts().then(() => { this.isLoading = false; });
        }
    }

    handleNextPage() {
        if (this.hasNextPage) {
            this.currentPage++;
            this.isLoading = true;
            this.loadAccounts().then(() => { this.isLoading = false; });
        }
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
            this.selectedAccountId = accountId;
            this.showAccountModal = true;
        }
    }

    handleCloseAccountModal() {
        this.showAccountModal = false;
        this.selectedAccountId = null;
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

    // ── Snapshot Toggle ──

    handleSnapshotToggle() {
        this.snapshotExpanded = !this.snapshotExpanded;
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
        const filterMap = { cases: 'all', tasks: 'all', pipeline: 'all' };
        const sortMap = { cases: 'accountName', tasks: 'accountName', pipeline: 'accountName' };
        this.currentFilter = filterMap[stat];
        this.sortField = sortMap[stat];
        this.sortDirection = 'desc';
        this.currentPage = 1;
        this.isLoading = true;
        this.loadAccounts().then(() => { this.isLoading = false; });
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

    // ══════════════════════════════════════════════════════════
    // COMPUTED PROPERTIES
    // ══════════════════════════════════════════════════════════

    get hasSummary() { return this.summary !== null; }
    get hasAccounts() { return this.accounts && this.accounts.length > 0; }
    get hasRenewals() { return this.renewals && this.renewals.length > 0; }

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

    get ltvFormatted() { return this.formatCurrencyShort(this.summary?.totalClosedWonAmount || 0); }
    get weightedPipelineFormatted() { return this.formatCurrencyShort(this.summary?.totalWeightedPipeline || 0); }
    get ytdWonFormatted() { return this.formatCurrencyShort(this.summary?.totalYtdClosedWon || 0); }
    get openPipelineFormatted() { return this.formatCurrencyShort(this.summary?.totalOpenPipeline || 0); }

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

    get sortIndicatorName() {
        return this.sortDirection === 'asc' ? '▲' : '▼';
    }

    getSortIndicator(field) {
        return this.sortField === field ? (this.sortDirection === 'asc' ? ' ▲' : ' ▼') : '';
    }

    get sortIndicatorAccountName() { return this.getSortIndicator('accountName'); }
    get sortIndicatorHealthScore() { return this.getSortIndicator('healthScore'); }

    // ── Pagination ──

    get hasPrevPage() { return this.currentPage > 1; }
    get hasNextPage() { return this.accounts && this.accounts.length >= this.pageSize; }
    get noPrevPage() { return !this.hasPrevPage; }
    get noNextPage() { return !this.hasNextPage; }

    get paginationInfo() {
        const start = ((this.currentPage - 1) * this.pageSize) + 1;
        const end = start + (this.accounts ? this.accounts.length : 0) - 1;
        return `${start}–${end}`;
    }

    // ══════════════════════════════════════════════════════════
    // HELPER METHODS
    // ══════════════════════════════════════════════════════════

    formatCurrencyShort(value) {
        if (value == null || value === 0) return '$0';
        if (value >= 1000000) return `$${(value / 1000000).toFixed(1)}M`;
        if (value >= 1000) return `$${(value / 1000).toFixed(0)}K`;
        return `$${value.toFixed(0)}`;
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
                value: this.getDaysSinceActivityText(days),
                valueClass: this.getFactorValueClass('activity', days),
                status: this.getFactorStatusLabel('activity', days),
                statusClass: this.getFactorStatusClass('activity', days)
            },
            {
                label: 'Overdue Tasks',
                value: String(overdue),
                valueClass: this.getFactorValueClass('overdue', overdue),
                status: this.getFactorStatusLabel('overdue', overdue),
                statusClass: this.getFactorStatusClass('overdue', overdue)
            },
            {
                label: 'High-Priority Cases',
                value: String(highPri),
                valueClass: this.getFactorValueClass('highpri', highPri),
                status: this.getFactorStatusLabel('highpri', highPri),
                statusClass: this.getFactorStatusClass('highpri', highPri)
            },
            {
                label: 'Open Cases',
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
