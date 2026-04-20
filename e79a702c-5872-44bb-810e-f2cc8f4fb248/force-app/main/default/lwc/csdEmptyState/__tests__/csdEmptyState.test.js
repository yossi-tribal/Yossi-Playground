import { createElement } from 'lwc';
import CsdEmptyState from 'c/csdEmptyState';

function flush() {
    return Promise.resolve();
}

function create(props = {}) {
    const el = createElement('c-csd-empty-state', { is: CsdEmptyState });
    Object.assign(el, props);
    document.body.appendChild(el);
    return el;
}

describe('c-csd-empty-state', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders the title and body text', () => {
        const el = create({
            variant: 'empty',
            titleText: 'No cases yet',
            bodyText: 'Create one when a customer reports an issue.'
        });
        const title = el.shadowRoot.querySelector('.csd-empty__title');
        const body = el.shadowRoot.querySelector('.csd-empty__body');
        expect(title.textContent).toBe('No cases yet');
        expect(body.textContent).toBe('Create one when a customer reports an issue.');
    });

    it('defaults the icon based on variant', async () => {
        const el = create({ variant: 'onboarding', titleText: 't' });
        await flush();
        const icon = el.shadowRoot.querySelector('lightning-icon');
        expect(icon.iconName).toBe('utility:success');
    });

    it('uses explicit icon override when provided', async () => {
        const el = create({
            variant: 'onboarding',
            titleText: 't',
            icon: 'utility:lock'
        });
        await flush();
        const icon = el.shadowRoot.querySelector('lightning-icon');
        expect(icon.iconName).toBe('utility:lock');
    });

    it('applies a variant-specific container class', () => {
        const el = create({ variant: 'error', titleText: 't' });
        const root = el.shadowRoot.querySelector('.csd-empty');
        expect(root.classList.contains('csd-empty--error')).toBe(true);
    });

    it('only renders the primary button when primaryLabel is set', async () => {
        const el = create({
            variant: 'empty',
            titleText: 't',
            primaryLabel: 'Do it'
        });
        await flush();
        const buttons = el.shadowRoot.querySelectorAll('lightning-button');
        expect(buttons.length).toBe(1);
        expect(buttons[0].label).toBe('Do it');
    });

    it('fires primaryclick when the primary button is clicked', async () => {
        const el = create({
            variant: 'empty',
            titleText: 't',
            primaryLabel: 'Do it'
        });
        await flush();
        const handler = jest.fn();
        el.addEventListener('primaryclick', handler);
        const btn = el.shadowRoot.querySelector('lightning-button');
        btn.click();
        expect(handler).toHaveBeenCalledTimes(1);
    });

    it('fires secondaryclick from the secondary button', async () => {
        const el = create({
            variant: 'empty',
            titleText: 't',
            primaryLabel: 'Primary',
            secondaryLabel: 'Cancel'
        });
        await flush();
        const handler = jest.fn();
        el.addEventListener('secondaryclick', handler);
        const buttons = el.shadowRoot.querySelectorAll('lightning-button');
        // Second button is the secondary
        buttons[1].click();
        expect(handler).toHaveBeenCalledTimes(1);
    });

    it('renders the technical details block only for the error variant', async () => {
        const errorEl = create({
            variant: 'error',
            titleText: 't',
            errorDetail: 'Boom'
        });
        await flush();
        expect(errorEl.shadowRoot.querySelector('details.csd-empty__details')).not.toBeNull();

        const emptyEl = create({
            variant: 'empty',
            titleText: 't',
            errorDetail: 'Should be ignored'
        });
        await flush();
        expect(emptyEl.shadowRoot.querySelector('details.csd-empty__details')).toBeNull();
    });
});
