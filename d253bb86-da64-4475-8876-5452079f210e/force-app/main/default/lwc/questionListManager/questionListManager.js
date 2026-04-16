import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
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

export default class QuestionListManager extends LightningElement {
    @track questionLists = [];
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
        isActive: true,
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

    connectedCallback() {
        this.loadPicklistValues();
        this.loadConflictDetection();
    }

    @wire(getAllQuestionLists)
    wiredQuestionLists(result) {
        this.wiredQuestionListsResult = result;
        if (result.data) {
            this.questionLists = result.data;
            this.error = null;
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
    }

    handleNewList() {
        this.listFormData = {
            listId: null,
            listName: '',
            description: '',
            isActive: true,
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

    handleConfigureInTribal() {
        // This is a placeholder URL - in production, this would navigate to Tribal's configuration panel
        // Since we don't have the actual Tribal URL, we'll show a message
        this.showToast('Info', 'Please contact your administrator to configure assignment rules in Tribal.', 'info');

        // In a real implementation, you would use:
        // window.open('https://tribal-config-url.com/assignment-rules', '_blank');
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
