import { LightningElement, api, track } from 'lwc';
import {
    buildScopeKey,
    isCompleted,
    markCompleted,
    recordSkip
} from 'c/onboardingStorage';

/**
 * onboardingCoach — overlay + step-by-step walkthrough for an LWC.
 *
 * Design constraints honored here:
 *   - Theming via CSS custom properties (--oc-*). The host maps its own tokens
 *     onto ours so we look native (LQW gradient headers, CSD warm neutrals, etc).
 *   - No pulsing / glow / "NEW" badges — quiet visual tone, matches existing
 *     empty-state cards.
 *   - Shadow-DOM-respecting: hosts supply a resolver via setTargetResolver()
 *     so we never reach into their shadow tree from the outside.
 *
 * Public API (call via lwc:ref):
 *   setTargetResolver(fn)               host-supplied (selector) => Element | null
 *   startTour(tourId, opts?)            opts: { force?: boolean }
 *   autoStartIfUnseen(tourId)           starts only if not completed in storage
 *   stop()                              tears down the overlay
 */
export default class OnboardingCoach extends LightningElement {
    @api componentName;
    @api userId;
    @api disableAutoStart = false;

    @track _tours = [];
    @track activeTour = null;
    @track currentStepIndex = 0;
    @track targetRect = null;
    @track viewport = { w: 0, h: 0 };
    @track placement = 'center';
    @track popoverPos = null; // { top, left } in viewport coords
    @track popoverDims = null; // { width, height } actually measured after render
    @track arrowOffset = null; // { x, y } in px from popover top-left; one axis used per placement

    _resolver = null;
    _rafHandle = null;
    _resizeHandler = null;
    _scrollHandler = null;
    _keyHandler = null;

    // --------------------------------------------------------------
    // Public API
    // --------------------------------------------------------------
    @api
    get tours() {
        return this._tours;
    }
    set tours(value) {
        this._tours = Array.isArray(value) ? value : [];
    }

    @api
    setTargetResolver(fn) {
        if (typeof fn === 'function') this._resolver = fn;
    }

    @api
    startTour(tourId, opts = {}) {
        const tour = this._tours.find((t) => t.id === tourId);
        if (!tour) {
            // eslint-disable-next-line no-console
            console.warn(`[onboardingCoach] Tour not found: ${tourId}`);
            return;
        }
        if (!opts.force && isCompleted(this._scopeKey, tour.id, tour.version)) return;
        this.activeTour = tour;
        this.currentStepIndex = 0;
        this._attachEnvListeners();
        this._layoutCurrentStep();
    }

    @api
    autoStartIfUnseen(tourId) {
        if (this.disableAutoStart) return;
        const tour = this._tours.find((t) => t.id === tourId);
        if (!tour) return;
        if (isCompleted(this._scopeKey, tour.id, tour.version)) return;
        // Defer one frame so the host's DOM is settled.
        window.requestAnimationFrame(() => this.startTour(tourId));
    }

    @api
    stop() {
        this._teardown();
        this.activeTour = null;
        this.currentStepIndex = 0;
        this.targetRect = null;
    }

    // --------------------------------------------------------------
    // Derived state
    // --------------------------------------------------------------
    get active() {
        return !!this.activeTour;
    }

    get currentStep() {
        if (!this.activeTour) return null;
        return this.activeTour.steps[this.currentStepIndex] || null;
    }

    get currentStepNumber() {
        return this.currentStepIndex + 1;
    }

    get totalSteps() {
        return this.activeTour ? this.activeTour.steps.length : 0;
    }

    get showStepIndicator() {
        return this.totalSteps > 1;
    }

    get canGoBack() {
        return this.currentStepIndex > 0;
    }

    get isLastStep() {
        return this.currentStepIndex === this.totalSteps - 1;
    }

    get nextButtonLabel() {
        return this.isLastStep ? 'Finish' : 'Next';
    }

    get stepIcon() {
        return this.currentStep?.icon;
    }

    get hasTargetRect() {
        // Spotlight follows the target whenever we have one — even when the
        // popover itself fell back to center placement (e.g. the target is
        // huge or there's no room beside it). Hiding the spotlight in those
        // cases leaves the user wondering what we're pointing at.
        return !!this.targetRect;
    }

    get isCenterPlacement() {
        return this.placement === 'center';
    }

    get spotlightStyle() {
        if (!this.targetRect) return '';
        const pad = 6;
        const { top, left, width, height } = this.targetRect;
        return [
            `top: ${top - pad}px`,
            `left: ${left - pad}px`,
            `width: ${width + pad * 2}px`,
            `height: ${height + pad * 2}px`
        ].join('; ');
    }

    get popoverStyle() {
        if (this.placement === 'center' || !this.targetRect) {
            return 'top: 50%; left: 50%; transform: translate(-50%, -50%)';
        }
        if (!this.popoverPos) {
            // Hide off-screen until measured so we never flash at the wrong spot.
            return 'top: -9999px; left: -9999px; visibility: hidden';
        }
        return `top: ${this.popoverPos.top}px; left: ${this.popoverPos.left}px`;
    }

    get arrowStyle() {
        if (!this.arrowOffset) return '';
        if (this.placement === 'top' || this.placement === 'bottom') {
            return `left: ${this.arrowOffset.x}px; margin-left: -6px`;
        }
        return `top: ${this.arrowOffset.y}px; margin-top: -6px`;
    }

    get popoverClass() {
        const base = 'oc-popover';
        const width = this.currentStep?.width || 'standard';
        return `${base} oc-popover--${width} oc-popover--${this.placement}`;
    }

    get showArrow() {
        // Only show the arrow when the popover is anchored to a side of the
        // target. In center fallback (huge target / no room beside it) the
        // popover floats free, so an arrow would point at nothing.
        return !!this.targetRect && !!this.popoverPos && this.placement !== 'center';
    }

    get arrowClass() {
        return `oc-arrow oc-arrow--${this.placement}`;
    }

    // --------------------------------------------------------------
    // Event handlers
    // --------------------------------------------------------------
    handleNext() {
        if (this.isLastStep) {
            markCompleted(this._scopeKey, this.activeTour.id, this.activeTour.version || 1);
            this._emit('complete', { tourId: this.activeTour.id });
            this.stop();
            return;
        }
        this.currentStepIndex += 1;
        this._layoutCurrentStep();
    }

    handleBack() {
        if (!this.canGoBack) return;
        this.currentStepIndex -= 1;
        this._layoutCurrentStep();
    }

    handleSkip() {
        if (!this.activeTour) return;
        const tourId = this.activeTour.id;
        recordSkip(this._scopeKey, tourId, this.activeTour.version || 1);
        this._emit('skip', { tourId });
        this.stop();
    }

    handleBackdropClick() {
        // Escape-hatch; same as skip. Keeps the interaction honest — no accidental traps.
        this.handleSkip();
    }

    handleCardClick(event) {
        // Prevent card clicks from triggering backdrop dismissal.
        event.stopPropagation();
    }

    // --------------------------------------------------------------
    // Internals
    // --------------------------------------------------------------
    get _scopeKey() {
        return buildScopeKey(this.userId, this.componentName);
    }

    _popoverWidth() {
        const width = this.currentStep?.width || 'standard';
        if (width === 'narrow') return 320;
        if (width === 'wide') return 460;
        return 380;
    }

    _layoutCurrentStep() {
        const step = this.currentStep;
        if (!step) return;
        // Reset popover dimensions so the next step measures its own card and
        // doesn't inherit the previous step's height (which would mis-center
        // the popover and the arrow).
        this.popoverDims = null;
        this.popoverPos = null;
        this.arrowOffset = null;
        const hasEnter = typeof step.onEnter === 'function';
        let enterResult;
        if (hasEnter) {
            try {
                enterResult = step.onEnter({ stepIndex: this.currentStepIndex });
            } catch (e) {
                // swallow host-side errors so we never break the flow
            }
        }
        // If onEnter mutated host state (e.g., opened a modal), the new DOM
        // isn't rendered yet. Defer layout two rAFs so we measure the fresh
        // target. If onEnter returned a Promise, await it first.
        const deferAndLayout = () => {
            window.requestAnimationFrame(() => {
                window.requestAnimationFrame(() => {
                    if (!this.activeTour || this.currentStep !== step) return;
                    this._resolveAndMeasure();
                    window.requestAnimationFrame(() => {
                        this._measurePopoverAndAdjust();
                        this._focusPrimary();
                    });
                });
            });
        };
        if (enterResult && typeof enterResult.then === 'function') {
            enterResult.then(deferAndLayout).catch(deferAndLayout);
            return;
        }
        if (hasEnter) {
            deferAndLayout();
            return;
        }
        this._resolveAndMeasure();
        window.requestAnimationFrame(() => {
            this._measurePopoverAndAdjust();
            this._focusPrimary();
        });
    }

    _resolveAndMeasure(attempt = 0) {
        const step = this.currentStep;
        if (!step) return;
        if (!step.target || step.placement === 'center') {
            this.placement = 'center';
            this.targetRect = null;
            return;
        }
        const el = this._resolver ? this._resolver(step.target) : null;
        if (!el) {
            // Target may not be in the DOM yet (e.g., a modal is still
            // animating in). Retry a few times before giving up so tours
            // that open overlays land cleanly.
            const MAX_RETRIES = 6;
            const DELAY_MS = 80;
            if (attempt < MAX_RETRIES) {
                setTimeout(() => {
                    if (!this.activeTour || this.currentStep !== step) return;
                    this._resolveAndMeasure(attempt + 1);
                }, DELAY_MS);
                return;
            }
            // eslint-disable-next-line no-console
            console.warn(
                `[onboardingCoach] target not found for step "${step.id}": ${step.target}. Falling back to center.`
            );
            this.placement = 'center';
            this.targetRect = null;
            return;
        }
        // Use instant scroll (behavior: 'auto'). With smooth scrolling, the
        // scroll is queued asynchronously and getBoundingClientRect() returns
        // the *pre-scroll* rect, so the spotlight lands on whatever element
        // happens to occupy that position (often a sibling card). Instant
        // scroll keeps the rect honest at the cost of a snap.
        try {
            el.scrollIntoView({ block: 'center', inline: 'center', behavior: 'auto' });
        } catch (e) {
            // older browsers may not support options
        }
        const rect = el.getBoundingClientRect();
        this.targetRect = {
            top: rect.top,
            left: rect.left,
            width: rect.width,
            height: rect.height
        };
        this.viewport = { w: window.innerWidth, h: window.innerHeight };
        this.placement = this._resolveBestPlacement(step.placement || 'auto', rect);
        this._computePopoverPosition();
    }

    /**
     * Compute popover top/left and arrow offset from the current target rect,
     * placement, and (if available) the actually-measured popover dimensions.
     *
     * The arrow offset is derived from the *target* center, not the popover
     * center, so when viewport-clamping shifts the popover sideways the arrow
     * still lands on the thing we're pointing at.
     */
    _computePopoverPosition() {
        if (!this.targetRect || this.placement === 'center') {
            this.popoverPos = null;
            this.arrowOffset = null;
            return;
        }
        const gap = 14;
        const pw = (this.popoverDims && this.popoverDims.width) || this._popoverWidth();
        const ph = (this.popoverDims && this.popoverDims.height) || 180;
        const t = this.targetRect;
        let top;
        let left;
        switch (this.placement) {
            case 'top':
                top = t.top - ph - gap;
                left = t.left + t.width / 2 - pw / 2;
                break;
            case 'bottom':
                top = t.top + t.height + gap;
                left = t.left + t.width / 2 - pw / 2;
                break;
            case 'left':
                top = t.top + t.height / 2 - ph / 2;
                left = t.left - pw - gap;
                break;
            case 'right':
            default:
                top = t.top + t.height / 2 - ph / 2;
                left = t.left + t.width + gap;
                break;
        }
        const margin = 12;
        const vw = this.viewport.w || window.innerWidth;
        const vh = this.viewport.h || window.innerHeight;
        if (left < margin) left = margin;
        if (left + pw > vw - margin) left = Math.max(margin, vw - pw - margin);
        if (top < margin) top = margin;
        if (top + ph > vh - margin) top = Math.max(margin, vh - ph - margin);
        this.popoverPos = { top, left };

        // Anchor the arrow on the target's center, then keep it inside the
        // popover by 18px so the arrow visually stays "attached" to the card.
        const arrowMin = 18;
        const targetCenterX = t.left + t.width / 2;
        const targetCenterY = t.top + t.height / 2;
        if (this.placement === 'top' || this.placement === 'bottom') {
            let x = targetCenterX - left;
            x = Math.max(arrowMin, Math.min(pw - arrowMin, x));
            this.arrowOffset = { x, y: null };
        } else {
            let y = targetCenterY - top;
            y = Math.max(arrowMin, Math.min(ph - arrowMin, y));
            this.arrowOffset = { x: null, y };
        }
    }

    _measurePopoverAndAdjust() {
        if (!this.activeTour || !this.targetRect || this.placement === 'center') return;
        const pop = this.template.querySelector('.oc-popover');
        if (!pop) return;
        const rect = pop.getBoundingClientRect();
        const next = { width: rect.width, height: rect.height };
        const prev = this.popoverDims;
        if (prev && Math.abs(prev.width - next.width) < 0.5 && Math.abs(prev.height - next.height) < 0.5) {
            return;
        }
        this.popoverDims = next;
        // Recompute placement using the real height — the auto-fallback may
        // change now that we know the popover doesn't actually need 200px.
        this.placement = this._resolveBestPlacement(
            this.currentStep?.placement || 'auto',
            this.targetRect
        );
        this._computePopoverPosition();
    }

    _resolveBestPlacement(requested, rect) {
        const vw = window.innerWidth;
        const vh = window.innerHeight;
        const margin = 24;
        const popW = (this.popoverDims && this.popoverDims.width) || this._popoverWidth();
        const popH = (this.popoverDims && this.popoverDims.height) || 200;
        const fits = {
            top: rect.top >= popH + margin,
            bottom: vh - (rect.top + rect.height) >= popH + margin,
            left: rect.left >= popW + margin,
            right: vw - (rect.left + rect.width) >= popW + margin
        };
        if (requested !== 'auto' && fits[requested]) return requested;
        // Prefer bottom > top > right > left when auto or requested doesn't fit.
        if (fits.bottom) return 'bottom';
        if (fits.top) return 'top';
        if (fits.right) return 'right';
        if (fits.left) return 'left';
        return 'center';
    }

    _attachEnvListeners() {
        if (this._resizeHandler) return;
        this._resizeHandler = () => this._scheduleRelayout();
        this._scrollHandler = () => this._scheduleRelayout();
        this._keyHandler = (e) => this._handleKey(e);
        window.addEventListener('resize', this._resizeHandler);
        window.addEventListener('scroll', this._scrollHandler, true);
        window.addEventListener('keydown', this._keyHandler);
    }

    _teardown() {
        if (this._resizeHandler) {
            window.removeEventListener('resize', this._resizeHandler);
            this._resizeHandler = null;
        }
        if (this._scrollHandler) {
            window.removeEventListener('scroll', this._scrollHandler, true);
            this._scrollHandler = null;
        }
        if (this._keyHandler) {
            window.removeEventListener('keydown', this._keyHandler);
            this._keyHandler = null;
        }
        if (this._rafHandle) {
            cancelAnimationFrame(this._rafHandle);
            this._rafHandle = null;
        }
    }

    _scheduleRelayout() {
        if (this._rafHandle) return;
        this._rafHandle = window.requestAnimationFrame(() => {
            this._rafHandle = null;
            this._resolveAndMeasure();
            window.requestAnimationFrame(() => this._measurePopoverAndAdjust());
        });
    }

    _handleKey(event) {
        if (!this.active) return;
        const key = event.key;
        if (key === 'Escape') {
            event.preventDefault();
            this.handleSkip();
        } else if (key === 'Enter') {
            event.preventDefault();
            this.handleNext();
        } else if (key === 'ArrowRight') {
            event.preventDefault();
            this.handleNext();
        } else if (key === 'ArrowLeft') {
            event.preventDefault();
            this.handleBack();
        }
    }

    _focusPrimary() {
        const btn = this.template.querySelector('.oc-btn--primary');
        if (btn && typeof btn.focus === 'function') btn.focus();
    }

    _emit(type, detail) {
        this.dispatchEvent(
            new CustomEvent(type, { detail, bubbles: true, composed: true })
        );
    }

    disconnectedCallback() {
        this._teardown();
    }
}
