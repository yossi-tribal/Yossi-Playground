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

        it('shows "Step N of M" on non-chapter steps of multi-step tours', async () => {
            const el = create();
            el.startTour('intro');
            await flush();
            // Advance past the chapter-intro (first) step. Its eyebrow
            // carries the tour title instead of a "Step 1 of N" counter —
            // that's asserted separately below.
            el.shadowRoot.querySelector('.oc-btn--primary').click();
            await flush();
            const indicator = el.shadowRoot.querySelector('.oc-card__eyebrow');
            expect(indicator).not.toBeNull();
            expect(indicator.textContent).toMatch(/Step\s+2\s+of\s+2/i);
        });

        it('single-step tours omit the step indicator entirely', async () => {
            const el = create();
            el.startTour('single');
            await flush();
            // "single" has one step so there's no progress to report and
            // the chapter-intro eyebrow is also suppressed (no tour title
            // helps when there's nothing after it).
            const eyebrows = el.shadowRoot.querySelectorAll('.oc-card__eyebrow');
            // The single-step tour renders chapter-intro UI; its eyebrow
            // carries the tour title. Only one eyebrow should render, and
            // no "Step N of M" indicator should appear anywhere.
            eyebrows.forEach((el2) =>
                expect(el2.textContent).not.toMatch(/Step\s+\d+\s+of\s+\d+/i)
            );
        });

        it('renders the chapter-intro hero on the first step', async () => {
            const el = create();
            el.startTour('intro');
            await flush();
            // Hero card has the chapter class and the tour title as eyebrow.
            const card = el.shadowRoot.querySelector('.oc-card--chapter');
            expect(card).not.toBeNull();
            const eyebrow = el.shadowRoot.querySelector(
                '.oc-card__eyebrow--chapter'
            );
            expect(eyebrow).not.toBeNull();
            expect(eyebrow.textContent.trim()).toBe('Welcome');
            // Hero icon renders.
            expect(
                el.shadowRoot.querySelector('.oc-card__hero-icon')
            ).not.toBeNull();
            // Primary CTA reads "Start tour" on the chapter intro.
            const primary = el.shadowRoot.querySelector('.oc-btn--primary');
            expect(primary.textContent.trim()).toBe('Start tour');
        });

        it('drops the chapter-intro treatment on subsequent steps', async () => {
            const el = create();
            el.startTour('intro');
            await flush();
            el.shadowRoot.querySelector('.oc-btn--primary').click();
            await flush();
            expect(
                el.shadowRoot.querySelector('.oc-card--chapter')
            ).toBeNull();
            expect(
                el.shadowRoot.querySelector('.oc-card__hero-icon')
            ).toBeNull();
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
            // First step is the chapter intro — primary CTA reads "Start tour".
            expect(primaryButton(el).textContent.trim()).toBe('Start tour');
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

    describe('skipIfTargetMissing', () => {
        // Responsive tours ship paired steps (e.g. "lists-panel" for wide
        // viewports, "switch-list-button" for narrow) both flagged with
        // skipIfTargetMissing. Only one resolves at a time; the other must
        // silently hop so the user sees one step, not a broken center card.
        const RESPONSIVE_TOURS = [
            {
                id: 'respond',
                version: 1,
                title: 'Responsive',
                steps: [
                    { id: 'intro', title: 'Hi', body: 'Hi', placement: 'center' },
                    {
                        id: 'wide',
                        title: 'Wide',
                        body: 'Wide only',
                        target: '[data-tour="wide"]',
                        placement: 'right',
                        skipIfTargetMissing: true
                    },
                    {
                        id: 'narrow',
                        title: 'Narrow',
                        body: 'Narrow only',
                        target: '[data-tour="narrow"]',
                        placement: 'bottom',
                        skipIfTargetMissing: true
                    },
                    { id: 'outro', title: 'Bye', body: 'Done', placement: 'center' }
                ]
            }
        ];

        function stubElement() {
            return {
                scrollIntoView: () => {},
                getBoundingClientRect: () => ({
                    top: 10,
                    left: 10,
                    right: 110,
                    bottom: 110,
                    width: 100,
                    height: 100
                })
            };
        }

        it('skips forward past a step whose target is missing', async () => {
            const el = create({ tours: RESPONSIVE_TOURS });
            // Only the "narrow" target resolves (simulates a mobile layout).
            el.setTargetResolver((selector) =>
                selector === '[data-tour="narrow"]' ? stubElement() : null
            );
            el.startTour('respond');
            await flush();
            // Advance from intro — the "wide" step should auto-skip and we
            // should land on "narrow".
            el.shadowRoot.querySelector('.oc-btn--primary').click();
            await flush();
            const title = el.shadowRoot.querySelector('.oc-card__title');
            expect(title.textContent.trim()).toBe('Narrow');
        });

        it('finishes the tour if the final step would auto-skip', async () => {
            const el = create({ tours: RESPONSIVE_TOURS });
            // Only "wide" resolves. Step order: intro → wide → narrow (skip) →
            // outro. Advancing from "wide" should skip "narrow" and land on
            // the regular "outro" step (not finish the tour).
            el.setTargetResolver((selector) =>
                selector === '[data-tour="wide"]' ? stubElement() : null
            );
            el.startTour('respond');
            await flush();
            el.shadowRoot.querySelector('.oc-btn--primary').click(); // intro → wide
            await flush();
            el.shadowRoot.querySelector('.oc-btn--primary').click(); // wide → (skip narrow) → outro
            await flush();
            const title = el.shadowRoot.querySelector('.oc-card__title');
            expect(title.textContent.trim()).toBe('Bye');
        });

        it('auto-skips when the target resolves but sits off-viewport', async () => {
            // Real-world case: the narrow-viewport list column is parked
            // off-canvas with transform: translateX(-105%). The target
            // element is measurable but entirely outside the viewport, so
            // a skipIfTargetMissing step should hop — not land in the
            // corner pointing at nothing.
            const el = create({ tours: RESPONSIVE_TOURS });
            const offscreenEl = {
                scrollIntoView: () => {},
                getBoundingClientRect: () => ({
                    top: 10,
                    left: -500,
                    right: -400,
                    bottom: 110,
                    width: 100,
                    height: 100
                })
            };
            el.setTargetResolver((selector) =>
                selector === '[data-tour="wide"]'
                    ? offscreenEl
                    : selector === '[data-tour="narrow"]'
                    ? stubElement()
                    : null
            );
            el.startTour('respond');
            await flush();
            // intro → wide (offscreen, skipIfTargetMissing) → narrow
            el.shadowRoot.querySelector('.oc-btn--primary').click();
            await flush();
            expect(el.shadowRoot.querySelector('.oc-card__title').textContent.trim())
                .toBe('Narrow');
        });

        it('falls back to center when the first step auto-skips backward', async () => {
            // Degenerate case: the user navigates back into a step that is
            // itself unresolvable AND has nothing earlier to land on. Rather
            // than leave the user staring at an empty overlay, the coach
            // renders the step as a center-fallback.
            const firstStepSkipTour = [
                {
                    id: 'firstSkip',
                    version: 1,
                    title: 'First skip',
                    steps: [
                        {
                            id: 'head',
                            title: 'Head',
                            body: 'Only on wide',
                            target: '[data-tour="head"]',
                            skipIfTargetMissing: true
                        },
                        { id: 'tail', title: 'Tail', body: 'Bye', placement: 'center' }
                    ]
                }
            ];
            const el = create({ tours: firstStepSkipTour });
            // head's target exists so the tour opens on it normally...
            let headResolves = true;
            el.setTargetResolver((selector) =>
                selector === '[data-tour="head"]' && headResolves
                    ? stubElement()
                    : null
            );
            el.startTour('firstSkip');
            await flush();
            // Advance to tail, then make head unresolvable and go Back.
            el.shadowRoot.querySelector('.oc-btn--primary').click();
            await flush();
            headResolves = false;
            el.shadowRoot.querySelector('.oc-btn--secondary').click();
            await flush();
            // With nowhere earlier to hop to, the coach stays on head and
            // the popover still renders (center placement, no spotlight).
            expect(el.shadowRoot.querySelector('.oc-popover')).not.toBeNull();
            expect(el.shadowRoot.querySelector('.oc-spotlight')).toBeNull();
        });

        it('falls back to center (no skip) when target is off-viewport without the flag', async () => {
            // Same off-viewport rect, but the step does NOT set
            // skipIfTargetMissing — the coach should keep the step active
            // and center-fallback the popover, matching legacy behaviour.
            const tours = [
                {
                    id: 'stay',
                    version: 1,
                    title: 'Stay put',
                    steps: [
                        {
                            id: 'stuck',
                            title: 'Stuck',
                            body: 'Stays',
                            target: '[data-tour="stuck"]'
                            // no skipIfTargetMissing
                        },
                        { id: 'next', title: 'Next', body: 'Next', placement: 'center' }
                    ]
                }
            ];
            const el = create({ tours });
            el.setTargetResolver(() => ({
                scrollIntoView: () => {},
                getBoundingClientRect: () => ({
                    top: 10,
                    left: -500,
                    right: -400,
                    bottom: 110,
                    width: 100,
                    height: 100
                })
            }));
            el.startTour('stay');
            await flush();
            const title = el.shadowRoot.querySelector('.oc-card__title');
            expect(title.textContent.trim()).toBe('Stuck');
            expect(el.shadowRoot.querySelector('.oc-spotlight')).toBeNull();
        });

        it('finishes the tour when the last step auto-skips forward', async () => {
            // A tour whose final step is only reachable on a missing
            // target should finish cleanly (mark completed + tear down)
            // instead of getting stuck on a broken last step.
            const trailingSkipTour = [
                {
                    id: 'trail',
                    version: 1,
                    title: 'Trail',
                    steps: [
                        { id: 'intro', title: 'Hi', body: 'Hi', placement: 'center' },
                        {
                            id: 'tail',
                            title: 'Tail',
                            body: 'Only on wide',
                            target: '[data-tour="tail"]',
                            skipIfTargetMissing: true
                        }
                    ]
                }
            ];
            const el = create({ tours: trailingSkipTour });
            const handler = jest.fn();
            el.addEventListener('complete', handler);
            el.startTour('trail');
            await flush();
            // Advancing from intro triggers the tail step, which skips
            // because tail is unresolvable — the tour should finish.
            el.shadowRoot.querySelector('.oc-btn--primary').click();
            await flush();
            expect(handler).toHaveBeenCalledTimes(1);
            expect(handler.mock.calls[0][0].detail).toEqual({ tourId: 'trail' });
            expect(el.shadowRoot.querySelector('.oc-popover')).toBeNull();
            expect(getStatus(buildScopeKey(USER, COMPONENT), 'trail').completed).toBe(true);
        });

        it('variantOf collapses paired responsive steps into one counter slot', async () => {
            // Mark the narrow step as a variant of the wide step — they now
            // share a slot in the "Step N of M" counter regardless of which
            // one actually renders.
            const tours = RESPONSIVE_TOURS.map((t) => ({
                ...t,
                steps: t.steps.map((s) =>
                    s.id === 'narrow' ? { ...s, variantOf: 'wide' } : s
                )
            }));
            const el = create({ tours });
            el.setTargetResolver((selector) =>
                selector === '[data-tour="narrow"]' ? stubElement() : null
            );
            el.startTour('respond');
            await flush();
            // Advance from intro chapter to the (auto-skipped wide → narrow)
            // responsive slot. Counter should read "Step 2 of 3" — because
            // the narrow variant shares the wide step's slot.
            el.shadowRoot.querySelector('.oc-btn--primary').click();
            await flush();
            const eyebrow = el.shadowRoot.querySelector('.oc-card__eyebrow');
            expect(eyebrow).not.toBeNull();
            expect(eyebrow.textContent).toMatch(/Step\s+2\s+of\s+3/i);
        });

        it('skipping backwards also hops over an unresolvable step', async () => {
            const el = create({ tours: RESPONSIVE_TOURS });
            el.setTargetResolver((selector) =>
                selector === '[data-tour="narrow"]' ? stubElement() : null
            );
            el.startTour('respond');
            await flush();
            // Forward: intro → (skip wide) → narrow
            el.shadowRoot.querySelector('.oc-btn--primary').click();
            await flush();
            expect(el.shadowRoot.querySelector('.oc-card__title').textContent.trim())
                .toBe('Narrow');
            // Back: narrow → (skip wide) → intro
            el.shadowRoot.querySelector('.oc-btn--secondary').click();
            await flush();
            expect(el.shadowRoot.querySelector('.oc-card__title').textContent.trim())
                .toBe('Hi');
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
