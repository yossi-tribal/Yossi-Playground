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
    '@salesforce/apex/CSD_CSMPortfolioController.recalculatePortfolioHealthScores',
    () => ({ default: jest.fn(() => Promise.resolve(0)) }),
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

    test('renders the filter-empty state when a filter is hiding accounts', async () => {
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

        const filterEmpty = [...el.shadowRoot.querySelectorAll('c-csd-empty-state')]
            .find((node) => node.primaryLabel === 'Clear filters');
        expect(filterEmpty).toBeTruthy();
        expect(filterEmpty.titleText).toMatch(/At Risk/);
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
