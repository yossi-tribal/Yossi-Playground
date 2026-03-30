import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPortfolioSummary from '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioSummary';
import getPortfolioAccounts from '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioAccounts';

export default class CsmPortfolioDashboard extends NavigationMixin(LightningElement) {
    @track summary = null;
    @track accounts = [];
    @track isLoading = true;
    @track error = null;

    // Filter and pagination state
    @track currentFilter = 'all';
    @track currentPage = 1;
    @track pageSize = 25;

    // Modal state
    @track showAccountModal = false;
    @track selectedAccountId = null;

    connectedCallback() {
        this.loadPortfolioData();
    }

    /**
     * Load portfolio summary and accounts
     */
    loadPortfolioData() {
        this.isLoading = true;
        this.error = null;

        // Load summary
        getPortfolioSummary()
            .then(result => {
                this.summary = result;
            })
            .catch(error => {
                this.handleError('Failed to load portfolio summary', error);
            });

        // Load accounts
        this.loadAccounts();
    }

    /**
     * Load accounts based on current filter and pagination
     */
    loadAccounts() {
        getPortfolioAccounts({
            filterType: this.currentFilter,
            sortField: 'accountName',
            sortDirection: 'asc',
            pageSize: this.pageSize,
            pageNumber: this.currentPage
        })
            .then(result => {
                this.accounts = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError('Failed to load accounts', error);
                this.isLoading = false;
            });
    }

    /**
     * Handle filter button click
     */
    handleFilterClick(event) {
        const filter = event.currentTarget.dataset.filter;
        if (filter && filter !== this.currentFilter) {
            this.currentFilter = filter;
            this.currentPage = 1;
            this.loadAccounts();
        }
    }

    /**
     * Handle account row click - open account detail modal
     */
    handleAccountClick(event) {
        const accountId = event.currentTarget.dataset.id;
        if (accountId) {
            this.selectedAccountId = accountId;
            this.showAccountModal = true;
        }
    }

    /**
     * Handle close account modal
     */
    handleCloseAccountModal() {
        this.showAccountModal = false;
        this.selectedAccountId = null;
    }

    /**
     * Handle refresh button click
     */
    handleRefresh() {
        this.loadPortfolioData();
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
     * Navigate to account record page
     */
    navigateToAccount(event) {
        const accountId = event.currentTarget.dataset.id;
        if (accountId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: accountId,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });
        }
    }

    // Computed properties

    get hasSummary() {
        return this.summary !== null;
    }

    get hasAccounts() {
        return this.accounts && this.accounts.length > 0;
    }

    get isAllFilter() {
        return this.currentFilter === 'all';
    }

    get isAtRiskFilter() {
        return this.currentFilter === 'at-risk';
    }

    get isNeedsAttentionFilter() {
        return this.currentFilter === 'needs-attention';
    }

    get isHealthyFilter() {
        return this.currentFilter === 'healthy';
    }

    get isInactiveFilter() {
        return this.currentFilter === 'inactive';
    }

    get totalAccountsLabel() {
        if (!this.summary) return '0 Accounts';
        const count = this.summary.totalAccounts || 0;
        return `${count} ${count === 1 ? 'Account' : 'Accounts'}`;
    }

    get atRiskLabel() {
        if (!this.summary) return '0 At Risk';
        const count = this.summary.atRiskAccounts || 0;
        return `${count} At Risk`;
    }

    get needsAttentionLabel() {
        if (!this.summary) return '0 Needs Attention';
        const count = this.summary.needsAttentionAccounts || 0;
        return `${count} Needs Attention`;
    }

    get healthyLabel() {
        if (!this.summary) return '0 Healthy';
        const count = this.summary.healthyAccounts || 0;
        return `${count} Healthy`;
    }

    /**
     * Get health score badge class based on color
     */
    getHealthBadgeClass(healthScoreColor) {
        return `slds-badge health-badge health-badge--${healthScoreColor}`;
    }

    /**
     * Format currency for display
     */
    formatCurrency(value) {
        if (value == null) return '$0';
        if (value >= 1000000) return `$${(value / 1000000).toFixed(1)}M`;
        if (value >= 1000) return `$${(value / 1000).toFixed(0)}K`;
        return `$${value.toFixed(0)}`;
    }

    /**
     * Get accounts with computed properties for display
     */
    get accountsDecorated() {
        if (!this.accounts || this.accounts.length === 0) {
            return [];
        }

        return this.accounts.map(acc => ({
            ...acc,
            healthBadgeClass: this.getHealthBadgeClass(acc.healthScoreColor),
            pipelineFormatted: this.formatCurrency(acc.openPipelineAmount),
            daysSinceActivityText: this.getDaysSinceActivityText(acc.daysSinceLastActivity),
            hasRiskIndicators: acc.hasNoActivity || acc.hasOverdueTasks || acc.hasHighPriorityCases
        }));
    }

    getDaysSinceActivityText(days) {
        if (days == null) return 'No activity';
        if (days === 0) return 'Today';
        if (days === 1) return '1 day ago';
        return `${days} days ago`;
    }
}
