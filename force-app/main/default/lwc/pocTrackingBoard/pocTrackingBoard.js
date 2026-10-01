import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPocs from '@salesforce/apex/POC_TrackingBoardController.getPocs';

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

export default class PocTrackingBoard extends NavigationMixin(LightningElement) {
    records = [];
    currencyCode;
    truncated = false;
    errorMessage;
    isLoading = true;
    activeView = 'board';
    selectedId;
    pendingFocus = false;

    connectedCallback() {
        this.handleWindowKeydown = (event) => {
            if (event.key === 'Escape' && this.selectedId) {
                this.selectedId = undefined;
            }
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
    wiredPocs({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.currencyCode = data.currencyCode;
            this.truncated = data.truncated === true;
            this.records = (data.pocs || []).map((row) => this.decorate(row));
            this.errorMessage = undefined;
            if (this.selectedId && !this.records.some((row) => row.id === this.selectedId)) {
                this.selectedId = undefined;
            }
        } else if (error) {
            this.records = [];
            this.selectedId = undefined;
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
        this.selectedId = undefined;
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
        this.selectedId = id;
        this.pendingFocus = true;
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
            dateLabel: dateRange(row.startDate, row.endDate),
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

function dateRange(start, end) {
    const startLabel = formatDate(start);
    const endLabel = formatDate(end);
    if (startLabel && endLabel) {
        return `${startLabel} – ${endLabel}`;
    }
    if (startLabel) {
        return `Starts ${startLabel}`;
    }
    if (endLabel) {
        return `Ends ${endLabel}`;
    }
    return 'No dates';
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
