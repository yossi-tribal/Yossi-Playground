import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getPocs from '@salesforce/apex/POC_TrackingBoardController.getPocs';
import updatePoc from '@salesforce/apex/POC_TrackingBoardController.updatePoc';

const COLUMNS = [
    { value: 'Pre-POC', label: 'Pre-POC', dot: 'pre' },
    { value: 'Active', label: 'Active', dot: 'active' },
    { value: 'Extended', label: 'Extended', dot: 'extended' },
    { value: 'Paused', label: 'Paused', dot: 'paused' },
    { value: 'Complete', label: 'Complete', dot: 'complete' }
];

const VIEWS = [
    { id: 'overview', label: 'Overview' },
    { id: 'board', label: 'Board' },
    { id: 'list', label: 'List' },
    { id: 'timeline', label: 'Timeline' }
];

const VIEW_COPY = {
    overview: 'Portfolio summary for every POC you can see.',
    list: 'A table of every POC.',
    timeline: 'Engagements laid out by start and end date.'
};

const NONE = { label: '—', value: '' };

const LIFECYCLE_OPTIONS = [
    { label: 'Pre-POC', value: 'Pre-POC' },
    { label: 'Active', value: 'Active' },
    { label: 'Extended', value: 'Extended' },
    { label: 'Paused', value: 'Paused' },
    { label: 'Complete', value: 'Complete' }
];

const TYPE_OPTIONS = [NONE, { label: 'Paid', value: 'Paid' }, { label: 'Un-Paid', value: 'Un-Paid' }];

const LENGTH_OPTIONS = [
    NONE,
    { label: '2 Weeks', value: '2 Weeks' },
    { label: '1 Month', value: '1 Month' },
    { label: '6 Weeks', value: '6 Weeks' },
    { label: '2 Months', value: '2 Months' },
    { label: '3 Months', value: '3 Months' },
    { label: 'Other', value: 'Other' }
];

const HEALTH_OPTIONS = [
    NONE,
    { label: 'Green', value: 'Green' },
    { label: 'Yellow', value: 'Yellow' },
    { label: 'Red', value: 'Red' }
];

const EMPTY_ACCESS = {
    name: false,
    account: false,
    opportunity: false,
    lifecycleStatus: false,
    pocType: false,
    length: false,
    health: false,
    startDate: false,
    endDate: false,
    nextSteps: false
};

export default class PocTrackingBoard extends NavigationMixin(LightningElement) {
    records = [];
    currencyCode;
    truncated = false;
    errorMessage;
    isLoading = true;
    activeView = 'board';
    selectedId;
    pendingFocus = false;
    canCreate = false;
    canUpdate = false;
    fieldAccess = { ...EMPTY_ACCESS };
    isEditing = false;
    isSaving = false;
    saveError;
    draft;
    wiredResult;
    lifecycleOptions = LIFECYCLE_OPTIONS;
    typeOptions = TYPE_OPTIONS;
    lengthOptions = LENGTH_OPTIONS;
    healthOptions = HEALTH_OPTIONS;

    connectedCallback() {
        this.handleWindowKeydown = (event) => {
            if (event.key !== 'Escape' || !this.selectedId) {
                return;
            }
            if (this.isEditing) {
                this.resetEdit();
                return;
            }
            this.selectedId = undefined;
        };
        window.addEventListener('keydown', this.handleWindowKeydown);
    }

    disconnectedCallback() {
        window.removeEventListener('keydown', this.handleWindowKeydown);
    }

    renderedCallback() {
        if (!this.pendingFocus) {
            return;
        }
        const closeButton = this.template.querySelector('.drawer-close');
        if (closeButton) {
            closeButton.focus();
            this.pendingFocus = false;
        }
    }

    @wire(getPocs)
    wiredPocs(result) {
        this.wiredResult = result;
        this.isLoading = false;
        const { data, error } = result;
        if (data) {
            this.currencyCode = data.currencyCode;
            this.truncated = data.truncated === true;
            this.canCreate = data.canCreate === true;
            this.canUpdate = data.canUpdate === true;
            this.fieldAccess = { ...EMPTY_ACCESS, ...(data.fields || {}) };
            this.records = (data.pocs || []).map((row) => this.decorate(row));
            this.errorMessage = undefined;
            if (this.selectedId && !this.records.some((row) => row.id === this.selectedId)) {
                this.selectedId = undefined;
                this.resetEdit();
            }
        } else if (error) {
            this.records = [];
            this.selectedId = undefined;
            this.resetEdit();
            this.errorMessage = reduceError(error);
        }
    }

    get viewTabs() {
        return VIEWS.map((view) => ({
            ...view,
            className: view.id === this.activeView ? 'view-tab active' : 'view-tab',
            isActive: view.id === this.activeView,
            pressed: view.id === this.activeView ? 'true' : 'false',
            isOverview: view.id === 'overview',
            isBoard: view.id === 'board',
            isList: view.id === 'list',
            isTimeline: view.id === 'timeline'
        }));
    }

    get isComingSoonView() {
        return this.activeView !== 'board';
    }

    get comingSoonTitle() {
        const match = VIEWS.find((view) => view.id === this.activeView);
        return match ? match.label : 'Coming soon';
    }

    get comingSoonDetail() {
        return VIEW_COPY[this.activeView] || '';
    }

    get showBoard() {
        return this.activeView === 'board' && !this.isLoading && !this.errorMessage;
    }

    get isEmpty() {
        return this.records.length === 0;
    }

    get emptyMessage() {
        return this.canCreate
            ? 'No POC records yet. Managers can add one with the + on a column.'
            : 'No POC records yet.';
    }

    get showEdit() {
        return this.canUpdate && !this.isEditing;
    }

    get saveLabel() {
        return this.isSaving ? 'Saving…' : 'Save';
    }

    get statGridClass() {
        return this.isEditing ? 'stat-grid stat-grid-editing' : 'stat-grid';
    }

    get editFields() {
        const editing = this.isEditing;
        const access = this.fieldAccess;
        return {
            name: editing && access.name,
            account: editing && access.account,
            opportunity: editing && access.opportunity,
            lifecycleStatus: editing && access.lifecycleStatus,
            pocType: editing && access.pocType,
            length: editing && access.length,
            health: editing && access.health,
            startDate: editing && access.startDate,
            endDate: editing && access.endDate,
            nextSteps: editing && access.nextSteps
        };
    }

    get accountPickerValue() {
        return this.draft?.accountId || '';
    }

    get opportunityPickerValue() {
        return this.draft?.opportunityId || '';
    }

    get columns() {
        const groups = {};
        COLUMNS.forEach((column) => {
            groups[column.value] = [];
        });
        const extras = [];
        this.records.forEach((record) => {
            if (groups[record.lifecycleStatus]) {
                groups[record.lifecycleStatus].push(record);
            } else {
                extras.push(record);
            }
        });

        const columns = COLUMNS.map((column) => this.toColumn(column, groups[column.value]));
        if (extras.length) {
            columns.push(this.toColumn({ value: 'Other', label: 'Other', dot: 'other' }, extras));
        }
        return columns;
    }

    get owners() {
        const seen = new Map();
        this.records.forEach((record) => {
            if (record.ownerId && !seen.has(record.ownerId)) {
                seen.set(record.ownerId, record);
            }
        });
        const all = Array.from(seen.values());
        const shown = all.slice(0, 4);
        const extra = Math.max(0, all.length - shown.length);
        return {
            shown,
            extra,
            hasExtra: extra > 0,
            extraLabel: `+${extra}`
        };
    }

    get selected() {
        return this.records.find((record) => record.id === this.selectedId) || null;
    }

    handleView(event) {
        this.activeView = event.currentTarget.dataset.view;
        if (this.activeView !== 'board') {
            this.selectedId = undefined;
            this.resetEdit();
        }
    }

    handleOpen(event) {
        this.openRecord(event.currentTarget.dataset.id);
    }

    handleCardKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.openRecord(event.currentTarget.dataset.id);
        }
    }

    handleClose() {
        if (this.isSaving) {
            return;
        }
        this.resetEdit();
        this.selectedId = undefined;
    }

    handleEdit() {
        const selected = this.selected;
        if (!selected || !this.canUpdate) {
            return;
        }
        this.draft = {
            name: selected.name || '',
            accountId: selected.accountId || null,
            opportunityId: selected.opportunityId || null,
            lifecycleStatus: selected.lifecycleStatus || '',
            pocType: selected.pocType || '',
            length: selected.length || '',
            health: selected.health || '',
            startDate: selected.startDate || null,
            endDate: selected.endDate || null,
            nextSteps: selected.nextSteps || ''
        };
        this.saveError = undefined;
        this.isEditing = true;
    }

    handleCancel() {
        if (this.isSaving) {
            return;
        }
        this.resetEdit();
    }

    handleDraftChange(event) {
        const field = event.target.dataset.field;
        if (!field || !this.draft) {
            return;
        }
        this.draft = { ...this.draft, [field]: event.detail.value };
        this.saveError = undefined;
    }

    handleAccountPick(event) {
        this.draft = { ...this.draft, accountId: event.detail.recordId || null };
        this.saveError = undefined;
    }

    handleOpportunityPick(event) {
        this.draft = { ...this.draft, opportunityId: event.detail.recordId || null };
        this.saveError = undefined;
    }

    async handleSave() {
        if (this.isSaving || !this.isEditing || !this.draft) {
            return;
        }
        this.template.querySelectorAll('[data-field]').forEach((element) => {
            const field = element.dataset.field;
            if (field && 'value' in element) {
                this.draft = { ...this.draft, [field]: element.value };
            }
        });
        const draft = this.draft;
        if (this.fieldAccess.name && !String(draft.name || '').trim()) {
            this.saveError = 'POC Name is required.';
            return;
        }
        if (this.fieldAccess.account && !draft.accountId) {
            this.saveError = 'Account is required.';
            return;
        }
        if (this.fieldAccess.lifecycleStatus && !draft.lifecycleStatus) {
            this.saveError = 'Lifecycle Status is required.';
            return;
        }

        this.isSaving = true;
        this.saveError = undefined;
        try {
            await updatePoc({
                input: {
                    id: this.selectedId,
                    name: String(draft.name || '').trim(),
                    accountId: draft.accountId || null,
                    opportunityId: draft.opportunityId || null,
                    lifecycleStatus: draft.lifecycleStatus || null,
                    pocType: draft.pocType || null,
                    length: draft.length || null,
                    health: draft.health || null,
                    startDate: draft.startDate || null,
                    endDate: draft.endDate || null,
                    nextSteps: draft.nextSteps
                }
            });
            await refreshApex(this.wiredResult);
            this.resetEdit();
        } catch (error) {
            this.saveError = reduceError(error);
        } finally {
            this.isSaving = false;
        }
    }

    handleDrawerClick(event) {
        event.stopPropagation();
    }

    handleNew(event) {
        const status = event.currentTarget.dataset.status;
        const state = {};
        if (status && status !== 'Other') {
            state.defaultFieldValues = `Lifecycle_Status__c=${status}`;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'POC__c',
                actionName: 'new'
            },
            state
        });
    }

    handleOpenRecord() {
        this.openSalesforceRecord(this.selectedId, 'POC__c');
    }

    handleOpenRelated(event) {
        this.openSalesforceRecord(event.currentTarget.dataset.id, event.currentTarget.dataset.object);
    }

    openRecord(id) {
        if (id !== this.selectedId) {
            this.resetEdit();
        }
        this.selectedId = id;
        this.pendingFocus = true;
    }

    resetEdit() {
        this.isEditing = false;
        this.draft = undefined;
        this.saveError = undefined;
    }

    openSalesforceRecord(recordId, objectApiName) {
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName,
                actionName: 'view'
            }
        });
    }

    toColumn(column, cards) {
        return {
            ...column,
            dotClass: `dot dot-${column.dot}`,
            cards: cards.map((card) => ({
                ...card,
                cardClass: card.id === this.selectedId ? 'card selected' : 'card'
            })),
            count: cards.length,
            isEmpty: cards.length === 0,
            columnClass: cards.length === 0 ? 'column column-empty' : 'column',
            newLabel: `New ${column.label} POC`
        };
    }

    decorate(row) {
        const health = row.health || 'Not set';
        return {
            ...row,
            healthLabel: health,
            healthClass: healthClass(row.health),
            statusClass: statusClass(row.lifecycleStatus),
            statusLabel: row.lifecycleStatus || 'Not set',
            typeLabel: row.pocType || '—',
            typeClass: typeClass(row.pocType),
            hasType: Boolean(row.pocType),
            lengthLabel: row.length || '—',
            hasLength: Boolean(row.length),
            nextAction: firstLine(row.nextSteps),
            hasNextAction: Boolean(firstLine(row.nextSteps)),
            nextStepsText: row.nextSteps && row.nextSteps.trim() ? row.nextSteps : 'No next steps yet.',
            hasNextSteps: Boolean(row.nextSteps && row.nextSteps.trim()),
            notesClass: row.nextSteps && row.nextSteps.trim() ? 'notes' : 'notes-empty',
            amountLabel: formatMoney(row.opportunityAmount, this.currencyCode),
            milestoneLabel: cardMilestone(row.startDate, row.endDate),
            startLabel: formatDate(row.startDate) || '—',
            endLabel: formatDate(row.endDate) || '—',
            accountLabel: row.accountName || '—',
            opportunityLabel: row.opportunityName || '—',
            hasAccountLink: Boolean(row.accountId),
            hasOpportunityLink: Boolean(row.opportunityId),
            ownerInitials: initials(row.ownerName),
            ownerAvatarClass: avatarClass(row.ownerName),
            ownerAvatarSmClass: avatarClass(row.ownerName, 'sm'),
            ownerAvatarLgClass: avatarClass(row.ownerName, 'lg'),
            ownerLabel: row.ownerName || 'Unassigned'
        };
    }
}

function healthClass(health) {
    if (health === 'Green') {
        return 'pill health-green';
    }
    if (health === 'Yellow') {
        return 'pill health-yellow';
    }
    if (health === 'Red') {
        return 'pill health-red';
    }
    return 'pill health-none';
}

function statusClass(status) {
    const map = {
        'Pre-POC': 'pill status-pre',
        Active: 'pill status-active',
        Extended: 'pill status-extended',
        Paused: 'pill status-paused',
        Complete: 'pill status-complete'
    };
    return map[status] || 'pill status-other';
}

function typeClass(type) {
    if (type === 'Paid') {
        return 'badge badge-paid';
    }
    if (type === 'Un-Paid') {
        return 'badge badge-unpaid';
    }
    return 'badge';
}

function firstLine(text) {
    if (!text) {
        return null;
    }
    const line = text
        .split(/\r?\n/)
        .map((part) => part.trim())
        .find(Boolean);
    if (!line) {
        return null;
    }
    return line.length > 90 ? `${line.slice(0, 87)}…` : line;
}

function formatDate(value) {
    if (!value) {
        return null;
    }
    const parts = String(value).split('-');
    if (parts.length < 3) {
        return null;
    }
    const local = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    if (Number.isNaN(local.getTime())) {
        return null;
    }
    return new Intl.DateTimeFormat(undefined, {
        month: 'short',
        day: 'numeric',
        year: 'numeric'
    }).format(local);
}

function cardMilestone(start, end) {
    const endLabel = formatDate(end);
    if (endLabel) {
        return `POC end ${endLabel}`;
    }
    const startLabel = formatDate(start);
    return startLabel ? `Starts ${startLabel}` : 'No dates';
}

function formatMoney(amount, currencyCode) {
    if (amount === null || amount === undefined || amount === '') {
        return '—';
    }
    const code = currencyCode || 'USD';
    try {
        return new Intl.NumberFormat(undefined, {
            style: 'currency',
            currency: code,
            maximumFractionDigits: 0
        }).format(amount);
    } catch (e) {
        return `${code} ${amount}`;
    }
}

function initials(name) {
    if (!name) {
        return '?';
    }
    const parts = name.trim().split(/\s+/).filter(Boolean);
    const first = parts[0] ? parts[0][0] : '';
    const second = parts.length > 1 ? parts[parts.length - 1][0] : '';
    return `${first}${second}`.toUpperCase() || '?';
}

function avatarClass(name, size) {
    const text = name || '';
    let hash = 0;
    for (let i = 0; i < text.length; i += 1) {
        hash = (hash + text.charCodeAt(i) * (i + 1)) % 6;
    }
    return `avatar av-${hash}${size ? ` ${size}` : ''}`;
}

function reduceError(error) {
    if (Array.isArray(error?.body)) {
        return error.body.map((item) => item.message).join(', ');
    }
    if (typeof error?.body?.message === 'string') {
        return error.body.message;
    }
    return 'The tracking board could not load POC records.';
}
