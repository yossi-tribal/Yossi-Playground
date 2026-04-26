import { LightningElement, api, track } from 'lwc';
import { buildScopeKey, getStatus, reset } from 'c/onboardingStorage';

/**
 * onboardingMenu — round "i" trigger + dropdown of this LWC's feature tours.
 *
 * Surfaces:
 *   - tourselect  detail: { tourId }
 *   - resetall    detail: { scopeKey }
 *
 * The dropdown closes on outside click. Inside clicks stopPropagation so they
 * don't pop the window handler. Menu items render a subtle "unseen" dot
 * (no blinking, no "NEW" badge — quiet tone).
 */
export default class OnboardingMenu extends LightningElement {
    @api componentName;
    @api userId;
    @api label = 'Help & walkthroughs';

    @track _tours = [];
    @track isOpen = false;

    _windowClick = null;

    @api
    get tours() {
        return this._tours;
    }
    set tours(value) {
        this._tours = Array.isArray(value) ? value : [];
    }

    get scopeKey() {
        return buildScopeKey(this.userId, this.componentName);
    }

    get triggerAriaExpanded() {
        return this.isOpen ? 'true' : 'false';
    }

    get triggerClass() {
        return this.isOpen
            ? 'oc-menu__trigger oc-menu__trigger--open'
            : 'oc-menu__trigger';
    }

    get decoratedTours() {
        return this._tours.map((t) => {
            const status = getStatus(this.scopeKey, t.id);
            const seen = !!(status && status.completed);
            return {
                ...t,
                _key: t.id,
                _statusClass: seen
                    ? 'oc-menu__status oc-menu__status--seen'
                    : 'oc-menu__status oc-menu__status--unseen',
                _statusLabel: seen ? 'Viewed' : 'New'
            };
        });
    }

    get hasTours() {
        return this._tours.length > 0;
    }

    get noTours() {
        return this._tours.length === 0;
    }

    connectedCallback() {
        this._windowClick = () => {
            if (this.isOpen) this.isOpen = false;
        };
        window.addEventListener('click', this._windowClick);
    }

    disconnectedCallback() {
        if (this._windowClick) {
            window.removeEventListener('click', this._windowClick);
            this._windowClick = null;
        }
    }

    handleRootClick(event) {
        // Swallow clicks inside the menu so the window handler doesn't close it.
        event.stopPropagation();
    }

    handleToggle() {
        if (!this.hasTours) return;
        this.isOpen = !this.isOpen;
    }

    handleKeydown(event) {
        if (event.key === 'Escape' && this.isOpen) {
            event.preventDefault();
            this.isOpen = false;
            const trigger = this.template.querySelector('.oc-menu__trigger');
            if (trigger) trigger.focus();
        }
    }

    handleSelect(event) {
        const tourId = event.currentTarget.dataset.tourId;
        if (!tourId) return;
        this.isOpen = false;
        this.dispatchEvent(
            new CustomEvent('tourselect', {
                detail: { tourId },
                bubbles: true,
                composed: true
            })
        );
    }

    handleResetAll() {
        reset(this.scopeKey);
        this.isOpen = false;
        this._tours = [...this._tours]; // force re-decoration
        this.dispatchEvent(
            new CustomEvent('resetall', {
                detail: { scopeKey: this.scopeKey },
                bubbles: true,
                composed: true
            })
        );
    }
}