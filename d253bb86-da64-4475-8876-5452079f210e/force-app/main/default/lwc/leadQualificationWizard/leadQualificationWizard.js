import { LightningElement, api, wire } from 'lwc';
import { getRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLeadQualificationData from '@salesforce/apex/LQW_LeadQualificationController.getLeadQualificationData';
import saveQuestionResponse from '@salesforce/apex/LQW_LeadQualificationController.saveQuestionResponse';
import getResponseHistory from '@salesforce/apex/LQW_LeadQualificationController.getResponseHistory';

const LEAD_FIELDS = ['Lead.Id', 'Lead.Status'];

export default class LeadQualificationWizard extends LightningElement {
    @api recordId; // Lead record ID from the page

    // State properties
    qualificationData = null;
    isLoading = true;
    error = null;
    savingQuestionId = null;

    // Animation state for point feedback
    animatingButtons = new Map(); // Maps questionId+response to animation state

    // Previous lead rank tracking (for confetti celebration)
    previousLeadRank = null;

    // Change detection modal properties
    showChangeModal = false;
    previousListName = '';
    currentListName = '';
    previousResponseCount = 0;

    // Response history modal properties
    showHistoryModal = false;
    responseHistory = [];
    isLoadingHistory = false;
    expandedSections = new Set();

    // Computed properties
    get hasError() {
        return this.error !== null;
    }

    get hasData() {
        return this.qualificationData !== null && this.qualificationData.questions.length > 0;
    }

    /** True when the Lead has a Question List (explicit assignment or default fallback). */
    get hasQuestionListAssigned() {
        const id = this.qualificationData?.questionListId;
        return id !== null && id !== undefined && String(id).trim() !== '';
    }

    /**
     * Lead has no question list assigned and no default list exists — show setup guidance.
     * This should be rare since the trigger auto-creates a default list.
     */
    get showNoQuestionListEmptyState() {
        return (
            !this.isLoading &&
            !this.hasError &&
            this.qualificationData !== null &&
            !this.hasQuestionListAssigned
        );
    }

    /**
     * A list is assigned but there are no active questions to display.
     */
    get showNoQuestionsInListEmptyState() {
        const data = this.qualificationData;
        if (this.isLoading || this.hasError || data === null || !this.hasQuestionListAssigned) {
            return false;
        }
        const count = data.totalQuestions ?? data.questions?.length ?? 0;
        return count === 0;
    }

    get questions() {
        const rawQuestions = this.qualificationData?.questions || [];
        // Enhance each question with computed properties for the template
        return rawQuestions.map(q => ({
            ...q,
            isYesSelected: q.currentResponse === 'Yes',
            isNoSelected: q.currentResponse === 'No',
            isSaving: this.isSaving(q.questionId),
            dealbreakerTooltip: q.isDealbreaker
                ? `Answering "${q.dealbreakerValue}" will automatically disqualify this lead.`
                : '',
            dealbreakerExplanation: q.isDealbreaker
                ? `"${q.dealbreakerValue}" will disqualify this lead`
                : '',
            yesButtonLabel: this.getButtonLabel('Yes', q),
            noButtonLabel: this.getButtonLabel('No', q),
            yesButtonClass: this.getButtonClass('Yes', q),
            noButtonClass: this.getButtonClass('No', q)
        }));
    }

    get totalScore() {
        return this.qualificationData?.totalScore || 0;
    }

    get leadRank() {
        return this.qualificationData?.leadRank || 'Low Quality';
    }

    get leadStatus() {
        return this.qualificationData?.leadStatus || '';
    }

    get isDisqualified() {
        return this.qualificationData?.isDisqualified || false;
    }

    get disqualificationReason() {
        return this.qualificationData?.disqualificationReason || '';
    }

    get answeredCount() {
        return this.qualificationData?.answeredCount || 0;
    }

    get totalQuestions() {
        return this.qualificationData?.totalQuestions || 0;
    }

    get unansweredCount() {
        return this.totalQuestions - this.answeredCount;
    }

    get progressPercentage() {
        if (this.totalQuestions === 0) return 0;
        return Math.round((this.answeredCount / this.totalQuestions) * 100);
    }

    get progressBarStyle() {
        return `width: ${this.progressPercentage}%`;
    }

    get rankClass() {
        const rank = this.leadRank;
        const data = this.qualificationData;

        if (rank === 'Disqualified') return 'rank-disqualified';

        // Check against dynamic labels
        const highLabel = data?.highQualityLabel || 'High Quality';
        const mediumLabel = data?.mediumQualityLabel || 'Medium Quality';

        if (rank === highLabel || rank === 'High Quality') return 'rank-high';
        if (rank === mediumLabel || rank === 'Medium Quality') return 'rank-medium';
        return 'rank-low';
    }

    get rankValueClass() {
        const rank = this.leadRank;
        const data = this.qualificationData;
        let baseClass = 'rank-value';

        if (rank === 'Disqualified') return baseClass + ' rank-value-disqualified';

        // Check against dynamic labels
        const highLabel = data?.highQualityLabel || 'High Quality';
        const mediumLabel = data?.mediumQualityLabel || 'Medium Quality';

        if (rank === highLabel || rank === 'High Quality') return baseClass + ' rank-value-high';
        if (rank === mediumLabel || rank === 'Medium Quality') return baseClass + ' rank-value-medium';
        return baseClass + ' rank-value-low';
    }

    get infoLeftClass() {
        const rank = this.leadRank;
        const data = this.qualificationData;
        let baseClass = 'info-left';

        if (rank === 'Disqualified') return baseClass + ' info-left-disqualified';

        // Check against dynamic labels
        const highLabel = data?.highQualityLabel || 'High Quality';
        const mediumLabel = data?.mediumQualityLabel || 'Medium Quality';

        if (rank === highLabel || rank === 'High Quality') return baseClass + ' info-left-high';
        if (rank === mediumLabel || rank === 'Medium Quality') return baseClass + ' info-left-medium';
        return baseClass + ' info-left-low';
    }

    get rankIcon() {
        const rank = this.leadRank;
        const data = this.qualificationData;

        if (rank === 'Disqualified') return 'utility:error';

        // Check against dynamic labels
        const highLabel = data?.highQualityLabel || 'High Quality';
        const mediumLabel = data?.mediumQualityLabel || 'Medium Quality';

        if (rank === highLabel || rank === 'High Quality') return 'utility:success';
        if (rank === mediumLabel || rank === 'Medium Quality') return 'utility:warning';
        return 'utility:info';
    }

    get recommendationText() {
        const rank = this.leadRank;
        const data = this.qualificationData;

        if (rank === 'Disqualified') {
            return 'Lead is Disqualified';
        }

        // Use dynamic recommendations from question list
        const highLabel = data?.highQualityLabel || 'High Quality';
        const mediumLabel = data?.mediumQualityLabel || 'Medium Quality';
        const lowLabel = data?.lowQualityLabel || 'Low Quality';

        if (rank === highLabel) {
            return data?.highQualityRecommendation || 'Convert to Opportunity';
        } else if (rank === mediumLabel) {
            return data?.mediumQualityRecommendation || 'Convert to Opportunity with Manager Review';
        } else if (rank === lowLabel) {
            return data?.lowQualityRecommendation || 'Nurture Lead (Do Not Convert)';
        }

        // Fallback for backwards compatibility
        if (rank === 'High Quality') {
            return 'Convert to Opportunity';
        } else if (rank === 'Medium Quality') {
            return 'Convert to Opportunity with Manager Review';
        } else {
            return 'Nurture Lead (Do Not Convert)';
        }
    }

    get changeModalMessage() {
        return `The list of questions in the Qualification Wizard for this Lead was updated to ${this.currentListName}. Your previous ${this.previousResponseCount} response(s) are safely stored and available in the response history.`;
    }

    get hasResponseHistory() {
        return this.responseHistory && this.responseHistory.length > 0;
    }

    get formattedResponseHistory() {
        if (!this.responseHistory) return [];

        return this.responseHistory.map(group => {
            const isExpanded = this.expandedSections.has(group.questionListId || 'no_list');
            return {
                ...group,
                isExpanded: isExpanded,
                sectionKey: group.questionListId || 'no_list',
                iconName: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                dateRange: `${group.earliestDate} - ${group.latestDate}`,
                formattedResponses: group.responses?.map((resp, index) => ({
                    ...resp,
                    questionNumber: index + 1
                })) || []
            };
        });
    }

    // Wire to get lead record changes
    @wire(getRecord, { recordId: '$recordId', fields: LEAD_FIELDS })
    leadRecord;

    // Lifecycle hooks
    connectedCallback() {
        this.loadQualificationData();
    }

    // Load qualification data from Apex
    loadQualificationData() {
        this.isLoading = true;
        this.error = null;

        getLeadQualificationData({ leadId: this.recordId })
            .then(result => {
                // Store previous rank before updating
                if (this.qualificationData) {
                    this.previousLeadRank = this.qualificationData.leadRank;
                }

                this.qualificationData = result;
                this.isLoading = false;

                // Check for question list changes
                this.checkForQuestionListChange(result);
            })
            .catch(error => {
                this.error = this.extractErrorMessage(error);
                this.isLoading = false;
            });
    }

    // Check if question list has changed and show modal if needed
    checkForQuestionListChange(data) {
        if (!data.questionListId) return;

        const storageKey = `lqw_lastSeenQuestionList_${this.recordId}`;
        const lastSeenListId = localStorage.getItem(storageKey);

        if (lastSeenListId && lastSeenListId !== data.questionListId && data.previousResponseCount > 0) {
            // Question list has changed - show modal
            this.currentListName = data.questionListName || 'New Question List';
            this.previousResponseCount = data.previousResponseCount;
            this.showChangeModal = true;
        }
    }

    // Handle "Got It" button on change detection modal
    handleGotIt() {
        if (this.qualificationData?.questionListId) {
            const storageKey = `lqw_lastSeenQuestionList_${this.recordId}`;
            localStorage.setItem(storageKey, this.qualificationData.questionListId);
        }
        this.showChangeModal = false;
    }

    // Handle question response (Yes/No button click)
    handleResponseClick(event) {
        const questionId = event.currentTarget.dataset.questionId;
        const response = event.currentTarget.dataset.response;
        const isDealbreaker = event.currentTarget.dataset.isDealbreaker === 'true';
        const dealbreakerValue = event.currentTarget.dataset.dealbreakerValue;
        const currentResponse = event.currentTarget.dataset.currentResponse;

        // Check if this is a toggle off (clicking same response again)
        const isToggleOff = (currentResponse === response);
        const finalResponse = isToggleOff ? null : response;

        // Check if this triggers dealbreaker
        const triggersDisqualification = !isToggleOff && isDealbreaker && response === dealbreakerValue;

        // Show confirmation for dealbreaker responses
        if (triggersDisqualification) {
            const confirmed = confirm(
                '⚠️ WARNING: This response will automatically disqualify the lead.\n\n' +
                'The lead status will be changed to "Disqualified".\n\n' +
                'Do you want to proceed?'
            );

            if (!confirmed) {
                return; // User cancelled
            }
        }

        // Show point animation if this is the point-earning answer (and not toggling off)
        if (!isToggleOff) {
            this.showPointAnimation(questionId, response);
        }

        this.saveResponse(questionId, finalResponse);
    }

    // Save response to Apex
    saveResponse(questionId, response) {
        this.savingQuestionId = questionId;

        saveQuestionResponse({
            leadId: this.recordId,
            questionId: questionId,
            response: response
        })
            .then(result => {
                this.savingQuestionId = null;

                if (result.success) {
                    // Store previous rank before updating
                    const oldRank = this.qualificationData?.leadRank;

                    // Update qualification data with the returned summary
                    this.qualificationData = result.updatedSummary;

                    // Check if lead just became high quality and trigger confetti!
                    this.checkForHighQualityTransition(oldRank, result.updatedSummary.leadRank);

                    // Show appropriate toast message
                    if (result.wasDisqualified) {
                        this.showToast('Warning', result.message, 'warning');
                        // Refresh the record page
                        this.refreshRecordPage();
                    } else if (result.wasRestored) {
                        this.showToast('Success', result.message, 'success');
                        // Refresh the record page
                        this.refreshRecordPage();
                    } else {
                        this.showToast('Success', 'Response saved successfully', 'success');
                    }
                } else {
                    this.showToast('Error', result.message, 'error');
                }
            })
            .catch(error => {
                this.savingQuestionId = null;
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    // Refresh the record page
    refreshRecordPage() {
        // Notify Lightning Data Service that the record has been updated
        notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
    }

    // Check if question is currently being saved
    isSaving(questionId) {
        return this.savingQuestionId === questionId;
    }

    // Helper to show toast notification
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        });
        this.dispatchEvent(event);
    }

    // Helper to extract error message from error object
    extractErrorMessage(error) {
        if (!error) return 'An unknown error occurred';

        if (error.body) {
            if (error.body.message) {
                return error.body.message;
            }
            if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                return error.body.pageErrors[0].message;
            }
            if (error.body.fieldErrors) {
                const fieldErrors = Object.values(error.body.fieldErrors);
                if (fieldErrors.length > 0 && fieldErrors[0].length > 0) {
                    return fieldErrors[0][0].message;
                }
            }
        }

        if (error.message) {
            return error.message;
        }

        return 'An error occurred while processing your request';
    }

    // Get button label based on dealbreaker state and animation state
    getButtonLabel(response, question) {
        // Check if this button is animating
        const animationKey = `${question.questionId}-${response}`;
        const animationState = this.animatingButtons.get(animationKey);

        if (animationState) {
            return animationState.text;
        }

        return response;
    }

    // Get button class based on response state
    getButtonClass(response, question) {
        const baseClass = 'response-button';
        const responseClass = response === 'Yes' ? 'response-button-yes' : 'response-button-no';
        const selectedClass = question.currentResponse === response ? 'selected' : '';

        return `${baseClass} ${responseClass} ${selectedClass}`.trim();
    }

    // Show point animation on button
    showPointAnimation(questionId, response) {
        // Find the question to get the point value and point-earning answer
        const question = this.qualificationData?.questions.find(q => q.questionId === questionId);
        if (!question) return;

        const scoreValue = question.scoreValue || 0;
        const pointEarningAnswer = question.pointEarningAnswer;

        // Only animate if this response is the point-earning answer and has points
        if (scoreValue > 0 && response === pointEarningAnswer) {
            const animationKey = `${questionId}-${response}`;
            const pointText = scoreValue === 1 ? 'pt' : 'pts';
            const animationText = `+${scoreValue} ${pointText}`;

            // Set animation state
            this.animatingButtons.set(animationKey, { text: animationText });

            // Force re-render
            this.animatingButtons = new Map(this.animatingButtons);

            // Clear animation after 800ms (beat duration for moment of delight)
            setTimeout(() => {
                this.animatingButtons.delete(animationKey);
                this.animatingButtons = new Map(this.animatingButtons);
            }, 800);
        }
    }

    // Handle response history button click
    handleShowHistory() {
        this.showHistoryModal = true;
        this.loadResponseHistory();
    }

    // Load response history from Apex
    loadResponseHistory() {
        this.isLoadingHistory = true;

        getResponseHistory({ leadId: this.recordId })
            .then(result => {
                this.responseHistory = result || [];
                this.isLoadingHistory = false;

                // Expand first section by default
                if (this.responseHistory.length > 0) {
                    const firstKey = this.responseHistory[0].questionListId || 'no_list';
                    this.expandedSections.add(firstKey);
                }
            })
            .catch(error => {
                this.isLoadingHistory = false;
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    // Handle closing history modal
    handleCloseHistory() {
        this.showHistoryModal = false;
        this.responseHistory = [];
        this.expandedSections.clear();
    }

    // Handle section toggle in history modal
    handleToggleSection(event) {
        const sectionKey = event.currentTarget.dataset.sectionKey;

        if (this.expandedSections.has(sectionKey)) {
            this.expandedSections.delete(sectionKey);
        } else {
            this.expandedSections.add(sectionKey);
        }

        // Force re-render by creating new Set
        this.expandedSections = new Set(this.expandedSections);
    }

    // Check if lead just became high quality and trigger confetti celebration!
    checkForHighQualityTransition(oldRank, newRank) {
        if (!oldRank || !newRank) return;

        const data = this.qualificationData;
        const highLabel = data?.highQualityLabel || 'High Quality';

        // Check if the lead just transitioned to high quality
        const isNowHighQuality = newRank === highLabel || newRank === 'High Quality';
        const wasNotHighQuality = oldRank !== highLabel && oldRank !== 'High Quality';

        if (isNowHighQuality && wasNotHighQuality) {
            // 🎉 CELEBRATE! The lead just became high quality!
            this.triggerConfetti();
        }
    }

    // Trigger confetti animation - moment of celebration!
    // Injects confetti into document.body to escape Shadow DOM containment
    triggerConfetti() {
        // Create confetti container and inject into document.body to escape Shadow DOM
        const confettiContainer = document.createElement('div');

        // Apply all styles inline (no CSS classes will work outside Shadow DOM)
        confettiContainer.style.position = 'fixed';
        confettiContainer.style.top = '0';
        confettiContainer.style.left = '0';
        confettiContainer.style.width = '100vw';
        confettiContainer.style.height = '100vh';
        confettiContainer.style.pointerEvents = 'none'; // Allow clicks to pass through
        confettiContainer.style.zIndex = '9999'; // Above everything
        confettiContainer.style.overflow = 'hidden';

        // Append to body (escapes Shadow DOM!)
        document.body.appendChild(confettiContainer);

        // Generate 60 confetti pieces with random colors, positions, and delays
        const colors = ['#ff6b6b', '#4ecdc4', '#45b7d1', '#f7b731', '#5f27cd', '#00d2d3', '#ff9ff3', '#54a0ff', '#48dbfb', '#feca57'];
        const confettiCount = 60;

        for (let i = 0; i < confettiCount; i++) {
            const confetti = document.createElement('div');

            // Random properties for each confetti piece
            const color = colors[Math.floor(Math.random() * colors.length)];

            // Distribute confetti evenly across the full width with some randomness
            const basePosition = (i / confettiCount) * 100; // Evenly distributed base
            const randomOffset = (Math.random() - 0.5) * 20; // Random offset ±10%
            const left = Math.max(0, Math.min(100, basePosition + randomOffset)); // Clamp to 0-100%

            const delay = Math.random() * 0.8; // Random delay (0-0.8s) for staggered start
            const duration = 3 + Math.random() * 1.5; // Random fall duration (3-4.5s)
            const rotation = Math.random() * 360; // Random initial rotation
            const size = 8 + Math.random() * 8; // Random size (8-16px) for variety

            // Set all base styles inline
            confetti.style.position = 'absolute';
            confetti.style.left = `${left}%`;
            confetti.style.backgroundColor = color;
            confetti.style.width = `${size}px`;
            confetti.style.height = `${size}px`;
            confetti.style.borderRadius = Math.random() > 0.5 ? '50%' : '2px'; // Mix circles and squares
            confetti.style.willChange = 'transform, opacity';

            // Use Web Animations API for the falling animation (works outside Shadow DOM)
            confetti.animate([
                { top: '-10%', opacity: 0, offset: 0 },
                { opacity: 1, offset: 0.1 },
                { opacity: 1, offset: 0.9 },
                { top: '110%', opacity: 0, offset: 1 }
            ], {
                duration: duration * 1000, // Convert to milliseconds
                delay: delay * 1000,
                easing: 'ease-in',
                fill: 'forwards'
            });

            // Use Web Animations API for the rotation animation
            confetti.animate([
                { transform: `rotate(${rotation}deg)` },
                { transform: `rotate(${rotation + 360}deg)` }
            ], {
                duration: 1000,
                iterations: Infinity,
                easing: 'linear'
            });

            confettiContainer.appendChild(confetti);
        }

        // Clean up confetti after all animations complete (5.5 seconds)
        setTimeout(() => {
            // Remove the entire container from document.body
            if (confettiContainer.parentNode) {
                document.body.removeChild(confettiContainer);
            }
        }, 5500);
    }
}
