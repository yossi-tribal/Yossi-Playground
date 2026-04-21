/**
 * Tests for onboardingMenu — the "i" trigger + dropdown that lists this LWC's tours.
 *
 * We lean on the real onboardingStorage here (not a mock) because it's a thin
 * pure-JS module and behaviour like "Viewed" vs "New" is the exact contract
 * we want to verify across module boundaries.
 */
import { createElement } from 'lwc';
import OnboardingMenu from 'c/onboardingMenu';
import {
    buildScopeKey,
    markCompleted
} from 'c/onboardingStorage';

const USER = '005TEST000001';
const COMPONENT = 'someWidget';

const TOURS = [
    { id: 'intro', title: 'Welcome tour', summary: 'Short overview.', icon: 'utility:magicwand' },
    { id: 'scoring', title: 'Scoring', summary: 'How points work.', icon: 'utility:ribbon' },
    { id: 'dealbreakers', title: 'Dealbreakers', summary: 'Hard-no questions.' }
];

function flush() {
    return Promise.resolve();
}

function create(props = {}) {
    const el = createElement('c-onboarding-menu', { is: OnboardingMenu });
    Object.assign(el, {
        componentName: COMPONENT,
        userId: USER,
        tours: TOURS,
        ...props
    });
    document.body.appendChild(el);
    return el;
}

describe('c-onboarding-menu', () => {
    beforeEach(() => {
        window.localStorage.clear();
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders the trigger button in a collapsed state by default', () => {
        const el = create();
        const trigger = el.shadowRoot.querySelector('.oc-menu__trigger');
        expect(trigger).not.toBeNull();
        expect(trigger.getAttribute('aria-expanded')).toBe('false');
        expect(el.shadowRoot.querySelector('.oc-menu__panel')).toBeNull();
    });

    it('disables the trigger when no tours are provided', () => {
        const el = create({ tours: [] });
        const trigger = el.shadowRoot.querySelector('.oc-menu__trigger');
        expect(trigger.disabled).toBe(true);
    });

    it('opens the dropdown when the trigger is clicked', async () => {
        const el = create();
        const trigger = el.shadowRoot.querySelector('.oc-menu__trigger');
        trigger.click();
        await flush();
        const panel = el.shadowRoot.querySelector('.oc-menu__panel');
        expect(panel).not.toBeNull();
        expect(trigger.getAttribute('aria-expanded')).toBe('true');
    });

    it('renders one menu item per tour', async () => {
        const el = create();
        el.shadowRoot.querySelector('.oc-menu__trigger').click();
        await flush();
        const items = el.shadowRoot.querySelectorAll('.oc-menu__item');
        expect(items.length).toBe(TOURS.length);
    });

    it('marks unseen tours with the unseen status class', async () => {
        const el = create();
        el.shadowRoot.querySelector('.oc-menu__trigger').click();
        await flush();
        const statusDots = el.shadowRoot.querySelectorAll('.oc-menu__status');
        statusDots.forEach((dot) => {
            expect(dot.classList.contains('oc-menu__status--unseen')).toBe(true);
        });
    });

    it('marks completed tours with the seen status class', async () => {
        const scope = buildScopeKey(USER, COMPONENT);
        markCompleted(scope, 'intro', 1);
        const el = create();
        el.shadowRoot.querySelector('.oc-menu__trigger').click();
        await flush();
        const firstStatus = el.shadowRoot.querySelector(
            '.oc-menu__item[data-tour-id="intro"] .oc-menu__status'
        );
        expect(firstStatus.classList.contains('oc-menu__status--seen')).toBe(true);
        // Other tours remain "unseen".
        const secondStatus = el.shadowRoot.querySelector(
            '.oc-menu__item[data-tour-id="scoring"] .oc-menu__status'
        );
        expect(secondStatus.classList.contains('oc-menu__status--unseen')).toBe(true);
    });

    it('fires a tourselect event with the tour id when an item is clicked', async () => {
        const el = create();
        const handler = jest.fn();
        el.addEventListener('tourselect', handler);
        el.shadowRoot.querySelector('.oc-menu__trigger').click();
        await flush();
        const scoring = el.shadowRoot.querySelector(
            '.oc-menu__item[data-tour-id="scoring"]'
        );
        scoring.click();
        expect(handler).toHaveBeenCalledTimes(1);
        expect(handler.mock.calls[0][0].detail).toEqual({ tourId: 'scoring' });
    });

    it('closes the dropdown after selecting a tour', async () => {
        const el = create();
        el.shadowRoot.querySelector('.oc-menu__trigger').click();
        await flush();
        el.shadowRoot.querySelector('.oc-menu__item').click();
        await flush();
        expect(el.shadowRoot.querySelector('.oc-menu__panel')).toBeNull();
    });

    it('fires resetall and clears status when "Restart all introductions" is clicked', async () => {
        const scope = buildScopeKey(USER, COMPONENT);
        markCompleted(scope, 'intro', 1);
        markCompleted(scope, 'scoring', 1);
        const el = create();
        const handler = jest.fn();
        el.addEventListener('resetall', handler);
        el.shadowRoot.querySelector('.oc-menu__trigger').click();
        await flush();
        el.shadowRoot.querySelector('.oc-menu__reset').click();
        await flush();
        expect(handler).toHaveBeenCalledTimes(1);
        // Re-open to re-render decorated tours.
        el.shadowRoot.querySelector('.oc-menu__trigger').click();
        await flush();
        const statusDots = el.shadowRoot.querySelectorAll('.oc-menu__status');
        statusDots.forEach((dot) => {
            expect(dot.classList.contains('oc-menu__status--unseen')).toBe(true);
        });
    });

    it('closes the dropdown on Escape keydown', async () => {
        const el = create();
        el.shadowRoot.querySelector('.oc-menu__trigger').click();
        await flush();
        const root = el.shadowRoot.querySelector('.oc-menu');
        root.dispatchEvent(
            new KeyboardEvent('keydown', { key: 'Escape', bubbles: true })
        );
        await flush();
        expect(el.shadowRoot.querySelector('.oc-menu__panel')).toBeNull();
    });
});
