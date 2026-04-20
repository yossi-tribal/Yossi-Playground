import { LightningElement, api, track } from 'lwc';

const DEFAULT_ICONS = {
    empty: 'utility:search',
    degraded: 'utility:info',
    error: 'utility:error',
    onboarding: 'utility:success'
};

export default class CsdEmptyState extends LightningElement {
    @api variant = 'empty';
    @api titleText = '';
    @api bodyText = '';
    /** Overrides icon for this variant */
    @api icon = '';
    @api primaryLabel = '';
    @api primaryVariant = 'brand';
    @api secondaryLabel = '';
    @api errorDetail = '';
    @api compact = false;
    @track _hasMeta = false;

    @api
    get title() {
        return this.titleText;
    }
    set title(v) {
        this.titleText = v;
    }

    @api
    get body() {
        return this.bodyText;
    }
    set body(v) {
        this.bodyText = v;
    }

    get isErrorVariant() {
        return this.variant === 'error';
    }

    get resolvedIconName() {
        if (this.icon) {
            return this.icon;
        }
        return DEFAULT_ICONS[this.variant] || DEFAULT_ICONS.empty;
    }

    get containerClass() {
        return [
            'csd-empty',
            `csd-empty--${this.variant}`,
            this.compact ? 'csd-empty--compact' : ''
        ]
            .filter(Boolean)
            .join(' ');
    }

    get hasActions() {
        return (this.showPrimary) || (this.showSecondary);
    }

    get showPrimary() {
        return !!this.primaryLabel;
    }

    get showSecondary() {
        return !!this.secondaryLabel;
    }

    get metaContainerClass() {
        const base = 'csd-empty__meta';
        return this._hasMeta ? base : `${base} slds-hide`;
    }

    handleMetaSlotChange(event) {
        const slot = event.target;
        const el = slot.assignedElements
            ? slot.assignedElements({ flatten: true })
            : [];
        const hasEl = el && el.length > 0;
        const nodes = slot.assignedNodes ? slot.assignedNodes({ flatten: true }) : [];
        const TEXT_NODE = 3;
        const hasText = nodes.some(
            n => n.nodeType === TEXT_NODE && n.textContent && n.textContent.trim().length
        );
        this._hasMeta = hasEl || hasText;
    }

    handlePrimary() {
        this.dispatchEvent(
            new CustomEvent('primaryclick', {
                bubbles: true,
                composed: true
            })
        );
    }

    handleSecondary() {
        this.dispatchEvent(
            new CustomEvent('secondaryclick', {
                bubbles: true,
                composed: true
            })
        );
    }

    handleDetailsClick(event) {
        event.stopPropagation();
    }
}
