/**
 * Focused tests for the empty-state disambiguation getters on csmPortfolioDashboard.
 * We drive state through the Apex mocks so the component's internal @track fields
 * are populated by its normal data-loading flow.
 */

import { createElement } from 'lwc';

jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioSummary',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioAccounts',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getUpcomingRenewals',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioHealthBreakdown',
    () => ({ default: jest.fn(() => Promise.resolve({})) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getOverdueTasksForPortfolio',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getHighPriorityCasesForPortfolio',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getAllOpenCasesForPortfolio',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getAllOpenOpportunitiesForPortfolio',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getAllOpenTasksForPortfolio',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioCasesForMonth',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioClosedWonForMonth',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getClosedWonOpportunitiesForPortfolio',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getCasesOpenedInLastDaysForPortfolio',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getCasesOpenedYtdForPortfolio',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getUpcomingEventsForPortfolio',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.startPortfolioRecalc',
    () => ({ default: jest.fn(() => Promise.resolve('707000000000001')) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSMPortfolioController.getRecalcJobStatus',
    () => ({
        default: jest.fn(() =>
            Promise.resolve({
                jobId: '707000000000001',
                status: 'Completed',
                totalChunks: 1,
                processedChunks: 1,
                numberOfErrors: 0,
                extendedStatus: null,
                done: true
            })
        )
    }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSDashboardController.createTask',
    () => ({ default: jest.fn(() => Promise.resolve('00T000000000001')) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSDashboardController.createEvent',
    () => ({ default: jest.fn(() => Promise.resolve('00U000000000001')) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CSD_CSDashboardController.getTaskPicklistValues',
    () => ({ default: jest.fn(() => Promise.resolve({})) }),
    { virtual: true }
);

import CsmPortfolioDashboard from 'c/csmPortfolioDashboard';
import getPortfolioSummary from '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioSummary';
import getPortfolioAccounts from '@salesforce/apex/CSD_CSMPortfolioController.getPortfolioAccounts';
import startPortfolioRecalc from '@salesforce/apex/CSD_CSMPortfolioController.startPortfolioRecalc';
import getRecalcJobStatus from '@salesforce/apex/CSD_CSMPortfolioController.getRecalcJobStatus';

async function flushPromises() {
    // Several promise hops need to settle for LWC to paint after mount.
    for (let i = 0; i < 10; i++) {
        // eslint-disable-next-line no-await-in-loop
        await Promise.resolve();
    }
    await new Promise((r) => setTimeout(r, 0));
}

async function mount({ summary, accounts = [] } = {}) {
    getPortfolioSummary.mockResolvedValue(summary);
    getPortfolioAccounts.mockResolvedValue(accounts);
    const el = createElement('c-csm-portfolio-dashboard', {
        is: CsmPortfolioDashboard
    });
    document.body.appendChild(el);
    await flushPromises();
    await flushPromises();
    return el;
}

afterEach(() => {
    while (document.body.firstChild) {
        document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
});

describe('csmPortfolioDashboard empty-state disambiguation', () => {
    test('renders onboarding state when the user is not Primary CSM on any account', async () => {
        const el = await mount({
            summary: { totalAccounts: 0, currentUserName: 'Alex Example' },
            accounts: []
        });

        const onboarding = [...el.shadowRoot.querySelectorAll('c-csd-empty-state')]
            .find((node) => node.variant === 'onboarding');
        expect(onboarding).toBeTruthy();
        expect(onboarding.titleText).toContain('Alex');
    });

    test('renders the filter-empty row inside the table when a filter hides accounts', async () => {
        const el = await mount({
            summary: { totalAccounts: 3, currentUserName: 'Alex Example' },
            accounts: []
        });
        // Trigger a filter change through the normal click path so the component's
        // reactive state actually updates. The legend item with data-filter="at-risk"
        // is wired to handleFilterClick.
        const atRiskChip = el.shadowRoot.querySelector(
            '.health-legend-item[data-filter="at-risk"]'
        );
        expect(atRiskChip).toBeTruthy();
        atRiskChip.click();
        await flushPromises();

        // The filter-empty message now lives inside the accounts table's tbody
        // so the table shape stays visible. Verify the row renders with the
        // expected title + clear-filters CTA.
        const filterRow = el.shadowRoot.querySelector('.filter-empty-row');
        expect(filterRow).toBeTruthy();
        const title = filterRow.querySelector('.filter-empty-title');
        expect(title.textContent).toMatch(/At Risk/);
        const clearBtn = filterRow.querySelector('.filter-empty-btn');
        expect(clearBtn).toBeTruthy();
        expect(clearBtn.textContent.trim()).toBe('Clear filters');

        // The full desktop table frame should still be present (header + tbody).
        const table = el.shadowRoot.querySelector('.data-table');
        expect(table).toBeTruthy();
        expect(table.querySelector('thead')).toBeTruthy();
    });

    test('does not show the Not Assessed banner when the portfolio is mixed', async () => {
        const el = await mount({
            summary: {
                totalAccounts: 3,
                notAssessedAccounts: 1,
                currentUserName: 'Alex Example'
            },
            accounts: [{ accountId: 'a1' }]
        });
        const banner = el.shadowRoot.querySelector(
            '.portfolio-banner--not-assessed'
        );
        expect(banner).toBeNull();
    });

    test('shows the Not Assessed banner when every account is Not Assessed', async () => {
        const el = await mount({
            summary: {
                totalAccounts: 3,
                notAssessedAccounts: 3,
                currentUserName: 'Alex Example'
            },
            accounts: [{ accountId: 'a1' }]
        });
        const banner = el.shadowRoot.querySelector(
            '.portfolio-banner--not-assessed'
        );
        expect(banner).not.toBeNull();
    });
});

describe('csmPortfolioDashboard recalc error modal', () => {
    test('opens the error modal with a copy-ready admin message when the batch reports a failed AsyncApexJob', async () => {
        startPortfolioRecalc.mockResolvedValueOnce('707000000000001');
        getRecalcJobStatus.mockResolvedValueOnce({
            jobId: '707000000000001',
            status: 'Failed',
            totalChunks: 42,
            processedChunks: 17,
            numberOfErrors: 3,
            extendedStatus: 'First error: Too many SOQL queries: 101',
            done: true
        });

        const el = await mount({
            summary: {
                totalAccounts: 3,
                notAssessedAccounts: 3,
                currentUserName: 'Alex Example'
            },
            accounts: [{ accountId: 'a1' }]
        });

        const recalcBtn = el.shadowRoot.querySelector(
            '.portfolio-banner--not-assessed .custom-btn--primary'
        );
        expect(recalcBtn).toBeTruthy();
        recalcBtn.click();
        await flushPromises();
        await flushPromises();

        const modal = el.shadowRoot.querySelector('.recalc-error-modal');
        expect(modal).toBeTruthy();

        const subtitle = modal.querySelector('.recalc-error-modal__subtitle');
        expect(subtitle.textContent).toContain('Too many SOQL queries');

        const adminMsg = modal.querySelector('.recalc-error-modal__admin-msg');
        const copy = adminMsg.textContent;
        expect(copy).toContain('707000000000001');
        expect(copy).toContain('17 of 42 chunks');
        expect(copy).toContain('Too many SOQL queries: 101');
        expect(copy).toContain('edit the architecture in Tribal');
        expect(copy).toContain('Alex Example');

        const copyBtn = modal.querySelector(
            '.recalc-error-modal__btn-primary'
        );
        expect(copyBtn.textContent).toContain('Copy message for your admin');
    });

    test('falls back to a generic admin message when startPortfolioRecalc rejects outright', async () => {
        startPortfolioRecalc.mockRejectedValueOnce({
            body: { message: 'Insufficient privileges' }
        });

        const el = await mount({
            summary: {
                totalAccounts: 3,
                notAssessedAccounts: 3,
                currentUserName: 'Alex Example'
            },
            accounts: [{ accountId: 'a1' }]
        });

        const recalcBtn = el.shadowRoot.querySelector(
            '.portfolio-banner--not-assessed .custom-btn--primary'
        );
        recalcBtn.click();
        await flushPromises();
        await flushPromises();

        const modal = el.shadowRoot.querySelector('.recalc-error-modal');
        expect(modal).toBeTruthy();
        const adminMsg = modal.querySelector('.recalc-error-modal__admin-msg');
        expect(adminMsg.textContent).toContain('Insufficient privileges');
        expect(adminMsg.textContent).toContain('did not start');
        expect(adminMsg.textContent).toContain('edit the architecture in Tribal');
    });
});
