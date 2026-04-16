import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOpportunityHealthScore from '@salesforce/apex/OHT_OpportunityHealthController.getOpportunityHealthScore';

// Opportunity fields to monitor for changes
const FIELDS = [
    'Opportunity.StageName',
    'Opportunity.CloseDate',
    'Opportunity.LastActivityDate',
    'Opportunity.IsClosed',
    'Opportunity.IsWon'
];

export default class OpportunityHealthThermostat extends LightningElement {
    @api recordId;
    @track healthData;
    @track error;
    @track isLoading = true;
    @track isHelpExpanded = false;

    wiredHealthDataResult;

    // Wire to detect opportunity field changes
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    opportunityRecord({ error, data }) {
        if (data) {
            // Refresh health score when opportunity fields change
            this.refreshHealthScore();
        } else if (error) {
            this.handleError(error);
        }
    }

    // Load health score on component initialization
    connectedCallback() {
        this.refreshHealthScore();
    }

    // Refresh health score data
    refreshHealthScore() {
        this.isLoading = true;
        this.error = null;

        getOpportunityHealthScore({ opportunityId: this.recordId })
            .then(result => {
                this.healthData = result;
                this.error = null;
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isLoading = false;
            });
    }

    // Handle manual refresh button click
    handleRefresh() {
        this.refreshHealthScore();
        this.showToast('Success', 'Health score refreshed', 'success');
    }

    // Toggle help section visibility
    toggleHelp() {
        this.isHelpExpanded = !this.isHelpExpanded;
    }

    // Error handler
    handleError(error) {
        this.error = this.extractErrorMessage(error);
        this.healthData = null;
        this.showToast('Error', this.error, 'error');
    }

    // Extract error message from various error formats
    extractErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        } else if (error.message) {
            return error.message;
        } else if (typeof error === 'string') {
            return error;
        }
        return 'An unknown error occurred while loading health score data';
    }

    // Show toast notification
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    // Computed properties

    get hasHealthData() {
        return this.healthData != null;
    }

    get healthScore() {
        return this.healthData ? this.healthData.healthScore : 0;
    }

    get riskLevel() {
        return this.healthData ? this.healthData.riskLevel : '';
    }

    get lastUpdated() {
        if (!this.healthData || !this.healthData.lastUpdated) {
            return '';
        }
        const date = new Date(this.healthData.lastUpdated);
        return date.toLocaleString();
    }

    // Calculate days since last update
    get daysSinceLastUpdate() {
        if (!this.healthData || !this.healthData.lastUpdated) {
            return null;
        }
        const lastUpdateDate = new Date(this.healthData.lastUpdated);
        const now = new Date();
        const diffTime = Math.abs(now - lastUpdateDate);
        const diffDays = diffTime / (1000 * 60 * 60 * 24);
        return diffDays;
    }

    // Status indicator class based on freshness
    get statusIndicatorClass() {
        const days = this.daysSinceLastUpdate;

        if (days === null) {
            return 'status-indicator';
        }

        if (days < 1) {
            // Fresh: less than 24 hours
            return 'status-indicator green-dot';
        } else if (days < 7) {
            // Aging: 1-7 days
            return 'status-indicator orange-dot';
        } else {
            // Stale: more than 7 days
            return 'status-indicator red-dot';
        }
    }

    get isClosed() {
        return this.healthData ? this.healthData.isClosed : false;
    }

    get isWon() {
        return this.healthData ? this.healthData.isWon : false;
    }

    get closedStatus() {
        if (this.isClosed && this.isWon) {
            return 'Closed Won';
        } else if (this.isClosed && !this.isWon) {
            return 'Closed Lost';
        }
        return '';
    }

    // Thermometer fill height (percentage)
    get thermometerFillHeight() {
        const score = this.healthScore;
        // Always show the actual score percentage for accurate visual representation
        return 'height: ' + score + '%';
    }

    // Help section toggle icon
    get helpToggleIcon() {
        return this.isHelpExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    // Risk level styling
    get riskLevelClass() {
        if (!this.healthData) {
            return 'risk-badge';
        }
        if (this.riskLevel === 'On Track') {
            return 'risk-badge on-track';
        } else if (this.riskLevel === 'Needs Attention') {
            return 'risk-badge needs-attention';
        } else if (this.riskLevel === 'At-Risk') {
            return 'risk-badge at-risk';
        }
        return 'risk-badge';
    }

    // Thermometer color class
    get thermometerColorClass() {
        if (!this.healthData) {
            return 'thermometer-fill';
        }
        if (this.riskLevel === 'On Track') {
            return 'thermometer-fill green';
        } else if (this.riskLevel === 'Needs Attention') {
            return 'thermometer-fill orange';
        } else if (this.riskLevel === 'At-Risk') {
            return 'thermometer-fill red';
        }
        return 'thermometer-fill';
    }

    // Bulb fill class
    get bulbFillClass() {
        if (!this.healthData) {
            return 'bulb-fill';
        }
        if (this.riskLevel === 'On Track') {
            return 'bulb-fill green';
        } else if (this.riskLevel === 'Needs Attention') {
            return 'bulb-fill orange';
        } else if (this.riskLevel === 'At-Risk') {
            return 'bulb-fill red';
        }
        return 'bulb-fill';
    }

    // Breakdown data getters
    get breakdown() {
        return this.healthData ? this.healthData.breakdown : null;
    }

    get overdueTasksScore() {
        // Show 100 for Closed Won opportunities
        if (this.isClosed && this.isWon) {
            return 100;
        }
        return this.breakdown ? this.breakdown.overdueTasksScore : 0;
    }

    get lastActivityScore() {
        // Show 100 for Closed Won opportunities
        if (this.isClosed && this.isWon) {
            return 100;
        }
        return this.breakdown ? this.breakdown.lastActivityScore : 0;
    }

    get closeDateScore() {
        // Show 100 for Closed Won opportunities
        if (this.isClosed && this.isWon) {
            return 100;
        }
        return this.breakdown ? this.breakdown.closeDateScore : 0;
    }

    get stageAgingScore() {
        // Show 100 for Closed Won opportunities
        if (this.isClosed && this.isWon) {
            return 100;
        }
        return this.breakdown ? this.breakdown.stageAgingScore : 0;
    }

    get overdueTaskCount() {
        return this.breakdown ? this.breakdown.overdueTaskCount : 0;
    }

    get daysSinceLastActivity() {
        if (!this.breakdown || this.breakdown.daysSinceLastActivity == null) {
            return 'N/A';
        }
        return this.breakdown.daysSinceLastActivity;
    }

    get daysUntilClose() {
        if (!this.breakdown || this.breakdown.daysUntilClose == null) {
            return 'N/A';
        }
        return this.breakdown.daysUntilClose;
    }

    get daysInCurrentStage() {
        return this.breakdown ? this.breakdown.daysInCurrentStage : 0;
    }

    // Criteria bar widths (percentage)
    get overdueTasksBarWidth() {
        // Show 100% width for Closed Won opportunities
        if (this.isClosed && this.isWon) {
            return 'width: 100%';
        }
        return 'width: ' + this.overdueTasksScore + '%';
    }

    get lastActivityBarWidth() {
        // Show 100% width for Closed Won opportunities
        if (this.isClosed && this.isWon) {
            return 'width: 100%';
        }
        return 'width: ' + this.lastActivityScore + '%';
    }

    get closeDateBarWidth() {
        // Show 100% width for Closed Won opportunities
        if (this.isClosed && this.isWon) {
            return 'width: 100%';
        }
        return 'width: ' + this.closeDateScore + '%';
    }

    get stageAgingBarWidth() {
        // Show 100% width for Closed Won opportunities
        if (this.isClosed && this.isWon) {
            return 'width: 100%';
        }
        return 'width: ' + this.stageAgingScore + '%';
    }

    // Criteria score classes for color coding
    get overdueTasksBarClass() {
        return this.getScoreBarClass(this.overdueTasksScore);
    }

    get lastActivityBarClass() {
        return this.getScoreBarClass(this.lastActivityScore);
    }

    get closeDateBarClass() {
        return this.getScoreBarClass(this.closeDateScore);
    }

    get stageAgingBarClass() {
        return this.getScoreBarClass(this.stageAgingScore);
    }

    // Helper method to get score bar CSS class
    getScoreBarClass(score) {
        if (score >= 75) {
            return 'score-bar green';
        } else if (score >= 50) {
            return 'score-bar orange';
        } else {
            return 'score-bar red';
        }
    }

    // Helper method to get criteria card CSS class with tinted background
    getCriteriaCardClass(score) {
        const baseClass = 'criteria-item';
        if (score >= 75) {
            return baseClass + ' on-track';
        } else if (score >= 50) {
            return baseClass + ' needs-attention';
        } else {
            return baseClass + ' at-risk';
        }
    }

    // Criteria card classes for tinted backgrounds
    get overdueTasksCardClass() {
        return this.getCriteriaCardClass(this.overdueTasksScore);
    }

    get lastActivityCardClass() {
        return this.getCriteriaCardClass(this.lastActivityScore);
    }

    get closeDateCardClass() {
        return this.getCriteriaCardClass(this.closeDateScore);
    }

    get stageAgingCardClass() {
        return this.getCriteriaCardClass(this.stageAgingScore);
    }

    // Overdue tasks display text
    get overdueTasksText() {
        if (this.overdueTaskCount === 0) {
            return 'No overdue tasks';
        } else if (this.overdueTaskCount === 1) {
            return '1 overdue task';
        } else {
            return this.overdueTaskCount + ' overdue tasks';
        }
    }
}
