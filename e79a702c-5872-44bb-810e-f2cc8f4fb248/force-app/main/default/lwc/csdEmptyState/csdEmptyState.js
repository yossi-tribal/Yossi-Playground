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
    /** Primary supporting sentence rendered directly under the title. */
    @api bodyText = '';
    /**
     * Optional second line of copy rendered under the body in a smaller,
     * muted tone. Use this to split a long explanation into a lead +
     * supporting sentence so the visual hierarchy is readable at a glance.
     */
    @api supportingText = '';
    /** Overrides icon for this variant */
    @api icon = '';
    @api primaryLabel = '';
    /** Controls the primary button style. 'brand' (default) | 'neutral' */
    @api primaryVariant = 'brand';
    @api secondaryLabel = '';
    @api errorDetail = '';
    @api compact = false;
    /**
     * Visual size. 'default' shows a normal inline empty-state card.
     * 'full' renders the card as a full-page takeover (big padding, centered
     * in the viewport, large icon + title). Use 'full' when the rest of the
     * surrounding dashboard should not render.
     */
    @api size = 'default';
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
            this.compact ? 'csd-empty--compact' : '',
            this.size === 'full' ? 'csd-empty--full' : ''
        ]
            .filter(Boolean)
            .join(' ');
    }

    get iconSize() {
        return this.size === 'full' ? 'large' : 'small';
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

    get primaryButtonClass() {
        const base = 'csd-empty__btn';
        const variantClass =
            this.primaryVariant === 'neutral'
                ? 'csd-empty__btn--secondary'
                : 'csd-empty__btn--primary';
        return `${base} ${variantClass}`;
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
