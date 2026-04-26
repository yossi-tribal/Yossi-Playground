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

    // Target tracking: catches layout shifts that don't fire scroll/resize —
    // drawers animating in, modals settling, LEX reflows, font swaps, sibling
    // content loading async. Without this the spotlight/popover drifts out of
    // sync with the real target rect across screen sizes (see
    // questionListManager ≤768px off-canvas drawer).
    _trackedTarget = null;
    _targetResizeObserver = null;
    _targetPollTimer = null;

    // Direction of the last step transition. Used when a step with
    // step.skipIfTargetMissing resolves to a hidden/off-viewport target:
    // we auto-advance in the same direction the user was navigating so
    // responsive step pairs (wide vs narrow target) feel like one step.
    _navDirection = 'forward';

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
        this._navDirection = 'forward';
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

    /**
     * Number of user-visible groups for the active tour. Responsive step
     * variants (step.variantOf set) collapse into the group of their
     * anchor step, so the user sees one slot in the counter for the pair
     * regardless of which variant renders. Non-variant steps each form
     * their own group.
     */
    get displayTotalSteps() {
        if (!this.activeTour) return 0;
        return this.activeTour.steps.filter((s) => !s.variantOf).length;
    }

    /**
     * 1-based counter for the current step within displayTotalSteps.
     * If the current step is a variant, the counter reports its anchor's
     * position so the displayed "Step N of M" stays monotonic across a
     * responsive skip.
     */
    get displayStepNumber() {
        if (!this.activeTour) return 1;
        const steps = this.activeTour.steps;
        const current = steps[this.currentStepIndex];
        if (!current) return 1;
        const anchorId = current.variantOf || current.id;
        let position = 0;
        for (let i = 0; i < steps.length; i++) {
            const s = steps[i];
            if (!s.variantOf) {
                position += 1;
                if (s.id === anchorId) return position;
            }
        }
        return position || 1;
    }

    get showStepIndicator() {
        return this.displayTotalSteps > 1;
    }

    get canGoBack() {
        return this.currentStepIndex > 0;
    }

    get isLastStep() {
        return this.currentStepIndex === this.totalSteps - 1;
    }

    get isFirstStep() {
        return this.active && this.currentStepIndex === 0;
    }

    /**
     * Chapter-intro mode: the first card of any tour gets hero treatment so
     * it reads as "the start of a new chapter" and not just another step.
     * Applies regardless of placement — a chapter card that's anchored to a
     * real target (e.g. Scoring tour opens on the Scoring Guide) keeps its
     * spotlight + arrow; the intro framing is purely a card-level concern.
     */
    get isChapterIntro() {
        return this.isFirstStep;
    }

    /**
     * Icon shown on the chapter-intro hero. We prefer the tour-level icon
     * (matches the one rendered in onboardingMenu for this chapter) so the
     * card visually ties back to the menu entry the user clicked.
     */
    get chapterIntroIcon() {
        if (!this.isChapterIntro) return null;
        return this.currentStep?.icon || this.activeTour?.icon || 'utility:einstein';
    }

    get chapterIntroLabel() {
        if (!this.isChapterIntro) return null;
        return this.activeTour?.title || null;
    }

    get nextButtonLabel() {
        if (this.isLastStep) return 'Finish';
        if (this.isChapterIntro) return 'Start tour';
        return 'Next';
    }

    get stepIcon() {
        return this.currentStep?.icon;
    }

    get showStepHeaderIcon() {
        // The per-step icon (small circle next to the title) is suppressed
        // on the chapter intro because that card already has its own, much
        // larger hero icon up top. Rendering both would be visually noisy.
        return !this.isChapterIntro && !!this.stepIcon;
    }

    get titleClass() {
        return this.isChapterIntro
            ? 'oc-card__title oc-card__title--chapter'
            : 'oc-card__title';
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
        const chapter = this.isChapterIntro ? ' oc-popover--chapter' : '';
        return `${base} oc-popover--${width} oc-popover--${this.placement}${chapter}`;
    }

    get cardClass() {
        return this.isChapterIntro ? 'oc-card oc-card--chapter' : 'oc-card';
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
        this._navDirection = 'forward';
        this.currentStepIndex += 1;
        this._layoutCurrentStep();
    }

    handleBack() {
        if (!this.canGoBack) return;
        this._navDirection = 'back';
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
            this._detachTargetTracking();
            this.placement = 'center';
            this.targetRect = null;
            return;
        }
        const el = this._resolver ? this._resolver(step.target) : null;
        if (!el) {
            // Responsive step pairs (e.g. a wide-viewport "new list button"
            // step and its narrow-viewport "switch list button" sibling)
            // both set skipIfTargetMissing. The absent one is deterministic
            // — no amount of retrying will summon a DOM node that's simply
            // not rendered at this viewport — so skip fast and let the
            // resolvable sibling step take over.
            if (step.skipIfTargetMissing) {
                this._autoSkipCurrentStep();
                return;
            }
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
            this._detachTargetTracking();
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
        const vw = window.innerWidth;
        const vh = window.innerHeight;

        // Target is un-spotlightable if it has zero size (display:none,
        // detached subtree) or has been parked entirely outside the
        // viewport. The latter is the narrow-viewport case: the
        // questionListManager list column is transform:translateX(-105%)
        // off-canvas on ≤768px, so the new-list-button still has a real
        // rect but sits to the left of the viewport. Without this guard
        // the popover lands in the top-left corner pointing at nothing.
        const isOffscreen =
            rect.right <= 0 ||
            rect.bottom <= 0 ||
            rect.left >= vw ||
            rect.top >= vh;
        const isZeroSize = rect.width === 0 && rect.height === 0;
        if (isZeroSize || isOffscreen) {
            if (step.skipIfTargetMissing) {
                this._autoSkipCurrentStep();
                return;
            }
            this._detachTargetTracking();
            this.placement = 'center';
            this.targetRect = null;
            return;
        }

        this.targetRect = {
            top: rect.top,
            left: rect.left,
            width: rect.width,
            height: rect.height
        };
        this.viewport = { w: vw, h: vh };
        this.placement = this._resolveBestPlacement(step.placement || 'auto', rect);
        this._computePopoverPosition();
        this._attachTargetTracking(el);
    }

    /**
     * Auto-skip the current step when skipIfTargetMissing is set and the
     * target isn't showable. Travels in the user's current nav direction so
     * responsive step pairs (e.g. a wide-viewport "Click + to start" step
     * paired with a narrow-viewport "Tap Switch list to open the panel"
     * step) feel like a single step — one of them resolves, the other is
     * silently hopped over.
     *
     * If no showable step remains in the nav direction, we finish the tour
     * (on forward) or stay put on the first step (on back).
     */
    _autoSkipCurrentStep() {
        if (!this.activeTour) return;
        this._detachTargetTracking();
        if (this._navDirection === 'forward') {
            if (this.currentStepIndex >= this.totalSteps - 1) {
                markCompleted(
                    this._scopeKey,
                    this.activeTour.id,
                    this.activeTour.version || 1
                );
                this._emit('complete', { tourId: this.activeTour.id });
                this.stop();
                return;
            }
            this.currentStepIndex += 1;
            this._layoutCurrentStep();
            return;
        }
        // direction === 'back'
        if (this.currentStepIndex <= 0) {
            // Can't go further back; render the step as center-fallback so
            // the user isn't looking at an empty overlay.
            this.placement = 'center';
            this.targetRect = null;
            return;
        }
        this.currentStepIndex -= 1;
        this._layoutCurrentStep();
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

    /**
     * Tracks a spotlighted target for layout changes that don't fire
     * window resize or scroll events:
     *   - ResizeObserver on the target itself (its own size changed).
     *   - ResizeObserver on documentElement (content height changed,
     *     e.g. a modal opened, a drawer animated in).
     *   - Polling fallback (240ms) so that *position* shifts caused by
     *     siblings rearranging (no resize on the target or the root)
     *     are still caught. Cost: one getBoundingClientRect per tick,
     *     which is cheap, and we only run it while a tour is active.
     */
    _attachTargetTracking(el) {
        if (this._trackedTarget === el) return;
        this._detachTargetTracking();
        this._trackedTarget = el;

        if (typeof ResizeObserver !== 'undefined') {
            try {
                this._targetResizeObserver = new ResizeObserver(() =>
                    this._scheduleRelayout()
                );
                this._targetResizeObserver.observe(el);
                if (document.documentElement) {
                    this._targetResizeObserver.observe(document.documentElement);
                }
            } catch (e) {
                this._targetResizeObserver = null;
            }
        }

        this._targetPollTimer = setInterval(() => {
            if (!this.active || !this._trackedTarget) return;
            if (!document.contains(this._trackedTarget)) {
                // Target was removed (e.g. modal closed). Re-resolve from
                // the step's selector — may come back, may not.
                this._resolveAndMeasure();
                return;
            }
            const next = this._trackedTarget.getBoundingClientRect();
            const prev = this.targetRect;
            if (!prev) {
                this._scheduleRelayout();
                return;
            }
            const EPS = 0.5;
            if (
                Math.abs(next.left - prev.left) > EPS ||
                Math.abs(next.top - prev.top) > EPS ||
                Math.abs(next.width - prev.width) > EPS ||
                Math.abs(next.height - prev.height) > EPS
            ) {
                this._scheduleRelayout();
            }
        }, 240);
    }

    _detachTargetTracking() {
        if (this._targetResizeObserver) {
            try {
                this._targetResizeObserver.disconnect();
            } catch (e) {
                // ignore
            }
            this._targetResizeObserver = null;
        }
        if (this._targetPollTimer) {
            clearInterval(this._targetPollTimer);
            this._targetPollTimer = null;
        }
        this._trackedTarget = null;
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
        this._detachTargetTracking();
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