/**
 * Tests for onboardingCoach — focus on the public API contract (startTour,
 * autoStartIfUnseen, step navigation, skip/complete events). Layout math
 * (placement) is tested only at the "does it render" level; jsdom has no real
 * layout engine so exact coordinates are not meaningful here.
 */
import { createElement } from 'lwc';
import OnboardingCoach from 'c/onboardingCoach';
import {
    buildScopeKey,
    markCompleted,
    getStatus
} from 'c/onboardingStorage';

const USER = '005TEST000002';
const COMPONENT = 'someWidget';

const TOURS = [
    {
        id: 'intro',
        version: 1,
        title: 'Welcome',
        steps: [
            { id: 'welcome', title: 'Welcome', body: 'Hello', placement: 'center' },
            { id: 'panel', title: 'Panel', body: 'Side', target: '[data-tour="panel"]', placement: 'right' }
        ]
    },
    {
        id: 'single',
        version: 1,
        title: 'Single step tour',
        steps: [
            { id: 'only', title: 'Only', body: 'Just one', placement: 'center' }
        ]
    }
];

function flush() {
    return Promise.resolve();
}

function create(props = {}) {
    const el = createElement('c-onboarding-coach', { is: OnboardingCoach });
    Object.assign(el, {
        componentName: COMPONENT,
        userId: USER,
        tours: TOURS,
        ...props
    });
    document.body.appendChild(el);
    return el;
}

describe('c-onboarding-coach', () => {
    beforeEach(() => {
        window.localStorage.clear();
        // Force requestAnimationFrame to run synchronously so autoStartIfUnseen
        // doesn't defer past the test window.
        jest.spyOn(window, 'requestAnimationFrame').mockImplementation((cb) => {
            cb();
            return 0;
        });
        // Targeted steps that fall back to center emit an expected warning;
        // silence it so the test output stays readable. The fallback itself
        // is still asserted via the rendered state.
        jest.spyOn(console, 'warn').mockImplementation(() => {});
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.restoreAllMocks();
    });

    describe('rendering', () => {
        it('renders nothing when no tour is active', () => {
            const el = create();
            expect(el.shadowRoot.querySelector('.oc-backdrop')).toBeNull();
            expect(el.shadowRoot.querySelector('.oc-popover')).toBeNull();
        });

        it('renders the backdrop and popover after startTour', async () => {
            const el = create();
            el.startTour('intro');
            await flush();
            expect(el.shadowRoot.querySelector('.oc-backdrop')).not.toBeNull();
            expect(el.shadowRoot.querySelector('.oc-popover')).not.toBeNull();
        });

        it('renders the current step title and body', async () => {
            const el = create();
            el.startTour('intro');
            await flush();
            const title = el.shadowRoot.querySelector('.oc-card__title');
            expect(title.textContent.trim()).toBe('Welcome');
        });

        it('shows "Step N of M" only when the tour has more than one step', async () => {
            const el = create();
            el.startTour('intro');
            await flush();
            const indicator = el.shadowRoot.querySelector('.oc-card__eyebrow');
            expect(indicator).not.toBeNull();
            expect(indicator.textContent).toMatch(/Step\s+1\s+of\s+2/i);

            el.stop();
            await flush();

            el.startTour('single');
            await flush();
            expect(el.shadowRoot.querySelector('.oc-card__eyebrow')).toBeNull();
        });
    });

    describe('autoStartIfUnseen', () => {
        it('starts a tour the first time it is requested', async () => {
            const el = create();
            el.autoStartIfUnseen('intro');
            await flush();
            expect(el.shadowRoot.querySelector('.oc-popover')).not.toBeNull();
        });

        it('does not start a tour that has already been completed', async () => {
            const scope = buildScopeKey(USER, COMPONENT);
            markCompleted(scope, 'intro', 1);
            const el = create();
            el.autoStartIfUnseen('intro');
            await flush();
            expect(el.shadowRoot.querySelector('.oc-popover')).toBeNull();
        });

        it('respects disableAutoStart', async () => {
            const el = create({ disableAutoStart: true });
            el.autoStartIfUnseen('intro');
            await flush();
            expect(el.shadowRoot.querySelector('.oc-popover')).toBeNull();
        });

        it('does nothing when the tour id is not registered', async () => {
            const el = create();
            el.autoStartIfUnseen('nope');
            await flush();
            expect(el.shadowRoot.querySelector('.oc-popover')).toBeNull();
        });

        it('bumping the version makes a previously-seen tour start again', async () => {
            const scope = buildScopeKey(USER, COMPONENT);
            markCompleted(scope, 'intro', 1);
            // Caller registers a v2 tour under the same id.
            const el = create({
                tours: [{ ...TOURS[0], version: 2 }]
            });
            el.autoStartIfUnseen('intro');
            await flush();
            expect(el.shadowRoot.querySelector('.oc-popover')).not.toBeNull();
        });
    });

    describe('step navigation', () => {
        function primaryButton(el) {
            return el.shadowRoot.querySelector('.oc-btn--primary');
        }
        function backButton(el) {
            return el.shadowRoot.querySelector('.oc-btn--secondary');
        }
        function skipButton(el) {
            return el.shadowRoot.querySelector('.oc-btn--ghost');
        }

        it('advances through steps with Next, then Finish marks completed', async () => {
            const el = create();
            el.startTour('intro');
            await flush();
            expect(primaryButton(el).textContent.trim()).toBe('Next');
            primaryButton(el).click();
            await flush();
            // Now at the last step → primary reads "Finish"
            expect(primaryButton(el).textContent.trim()).toBe('Finish');
            primaryButton(el).click();
            await flush();
            // Tour tears down
            expect(el.shadowRoot.querySelector('.oc-popover')).toBeNull();
            // Persisted
            expect(getStatus(buildScopeKey(USER, COMPONENT), 'intro').completed).toBe(true);
        });

        it('Back returns to the previous step', async () => {
            const el = create();
            el.startTour('intro');
            await flush();
            primaryButton(el).click();
            await flush();
            const back = backButton(el);
            expect(back).not.toBeNull();
            back.click();
            await flush();
            const title = el.shadowRoot.querySelector('.oc-card__title');
            expect(title.textContent.trim()).toBe('Welcome');
        });

        it('emits a "complete" event on Finish', async () => {
            const el = create();
            const handler = jest.fn();
            el.addEventListener('complete', handler);
            el.startTour('single');
            await flush();
            primaryButton(el).click();
            await flush();
            expect(handler).toHaveBeenCalledTimes(1);
            expect(handler.mock.calls[0][0].detail).toEqual({ tourId: 'single' });
        });

        it('Skip records a skip, emits "skip", and tears down', async () => {
            const el = create();
            const handler = jest.fn();
            el.addEventListener('skip', handler);
            el.startTour('intro');
            await flush();
            skipButton(el).click();
            await flush();
            expect(handler).toHaveBeenCalledTimes(1);
            expect(handler.mock.calls[0][0].detail).toEqual({ tourId: 'intro' });
            expect(el.shadowRoot.querySelector('.oc-popover')).toBeNull();
            const status = getStatus(buildScopeKey(USER, COMPONENT), 'intro');
            expect(status.skips).toBe(1);
        });
    });

    describe('forced start', () => {
        it('startTour(id, { force: true }) runs even for a completed tour', async () => {
            const scope = buildScopeKey(USER, COMPONENT);
            markCompleted(scope, 'intro', 1);
            const el = create();
            el.startTour('intro');
            await flush();
            // Without force it should be blocked.
            expect(el.shadowRoot.querySelector('.oc-popover')).toBeNull();
            el.startTour('intro', { force: true });
            await flush();
            expect(el.shadowRoot.querySelector('.oc-popover')).not.toBeNull();
        });

        it('logs a warning when startTour is called with an unknown id', () => {
            const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
            const el = create();
            el.startTour('ghost-tour');
            expect(warn).toHaveBeenCalled();
        });
    });

    describe('target resolver', () => {
        it('invokes the resolver for targeted steps', async () => {
            const el = create();
            const resolver = jest.fn(() => null);
            el.setTargetResolver(resolver);
            el.startTour('intro');
            await flush();
            // First step is center-placement, resolver should NOT be called.
            expect(resolver).not.toHaveBeenCalled();
            // Advance to the targeted step.
            el.shadowRoot.querySelector('.oc-btn--primary').click();
            await flush();
            expect(resolver).toHaveBeenCalledWith('[data-tour="panel"]');
        });

        it('ignores non-function values passed to setTargetResolver', () => {
            const el = create();
            expect(() => el.setTargetResolver(null)).not.toThrow();
            expect(() => el.setTargetResolver('not a function')).not.toThrow();
        });
    });
});
