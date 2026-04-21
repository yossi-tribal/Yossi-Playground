/**
 * Tests for the Question List Manager "admin handoff" helpers.
 *
 * Two public functions under test:
 *   - buildAdminRequestText(context): pure string builder
 *   - copyTextToClipboard(text, deps): async copy w/ fallback
 */
import { buildAdminRequestText, copyTextToClipboard } from '../questionListManager';

// Canonical happy-path list used in most cases. Tests override fields
// as needed. The admin handoff text should surface identity + state.
const BASE_LIST = {
    listId: 'a0Ca50000AZwQxNEQV',
    listName: 'UK SaaS Leads',
    description: 'Inbound SaaS leads from the UK',
    isActive: true,
    isDefault: false,
    activeQuestions: 6,
    totalQuestions: 9,
    totalPossiblePoints: 18,
    dealbreakerCount: 2
};

const BASE_TIERS = [
    { label: 'High Quality', threshold: 5, recommendation: 'Convert to Opportunity' },
    { label: 'Medium Quality', threshold: 3, recommendation: 'Convert with Review' },
    { label: 'Low Quality', threshold: 0, recommendation: 'Nurture' }
];

describe('buildAdminRequestText', () => {
    describe('identity + status block', () => {
        it('includes list name, id, and description', () => {
            const out = buildAdminRequestText({ list: BASE_LIST });
            expect(out).toContain('List Name:   UK SaaS Leads');
            expect(out).toContain('List ID:     a0Ca50000AZwQxNEQV');
            expect(out).toContain('Description: Inbound SaaS leads from the UK');
        });

        it('omits the Description line when the list has no description', () => {
            const out = buildAdminRequestText({
                list: { ...BASE_LIST, description: '' }
            });
            expect(out).not.toContain('Description:');
        });

        it('shows "Active" when the list is live', () => {
            const out = buildAdminRequestText({ list: BASE_LIST });
            expect(out).toMatch(/Status:\s+Active/);
        });

        it('shows "Inactive" when the list is off', () => {
            const out = buildAdminRequestText({
                list: { ...BASE_LIST, isActive: false }
            });
            expect(out).toMatch(/Status:\s+Inactive/);
        });

        it('adds the "Default Fallback" status pill when applicable', () => {
            const out = buildAdminRequestText({
                list: { ...BASE_LIST, isDefault: true }
            });
            expect(out).toMatch(/Status:\s+Active\s+•\s+Default Fallback/);
        });
    });

    describe('current-assignment descriptor', () => {
        it('calls out the default fallback case explicitly', () => {
            const out = buildAdminRequestText({
                list: { ...BASE_LIST, isDefault: true }
            });
            expect(out).toContain(
                'Current Assignment: Default fallback list (assigned when no other list matches)'
            );
        });

        it('points the admin at the criteria section when criteria exist', () => {
            const out = buildAdminRequestText({
                list: BASE_LIST,
                hasCriteria: true,
                parsedCriteriaRules: [
                    {
                        label: 'Industry',
                        displayOperator: 'equals',
                        displayValue: '"SaaS"'
                    }
                ]
            });
            expect(out).toContain(
                'Current Assignment: Criteria-based (see existing rules below)'
            );
        });

        it('tells the admin "None configured yet" when no criteria exist', () => {
            const out = buildAdminRequestText({
                list: BASE_LIST,
                hasCriteria: false
            });
            expect(out).toContain('Current Assignment: None configured yet');
        });
    });

    describe('questions & scoring block', () => {
        it('summarises question counts and total points', () => {
            const out = buildAdminRequestText({ list: BASE_LIST });
            expect(out).toContain('Active questions:      6 of 9');
            expect(out).toContain('Total possible points: 18');
            expect(out).toContain('Dealbreakers:          2');
        });

        it('falls back to 0 when counts are missing', () => {
            const out = buildAdminRequestText({ list: { listId: 'abc' } });
            expect(out).toContain('Active questions:      0 of 0');
            expect(out).toContain('Total possible points: 0');
            expect(out).toContain('Dealbreakers:          0');
        });

        it('lists each scoring tier with threshold and recommendation', () => {
            const out = buildAdminRequestText({
                list: BASE_LIST,
                scoringTiers: BASE_TIERS
            });
            expect(out).toContain('• High Quality: 5+ pts → Convert to Opportunity');
            expect(out).toContain('• Medium Quality: 3+ pts → Convert with Review');
            expect(out).toContain('• Low Quality: 0+ pts → Nurture');
        });

        it('skips the Scoring tiers section when none are provided', () => {
            const out = buildAdminRequestText({ list: BASE_LIST });
            expect(out).not.toContain('Scoring tiers:');
        });

        it('silently skips nullish tier entries without crashing', () => {
            const out = buildAdminRequestText({
                list: BASE_LIST,
                scoringTiers: [null, BASE_TIERS[0], undefined]
            });
            expect(out).toContain('• High Quality');
        });
    });

    describe('existing-criteria block', () => {
        it('renders each parsed rule as a bullet', () => {
            const out = buildAdminRequestText({
                list: BASE_LIST,
                hasCriteria: true,
                parsedCriteriaRules: [
                    {
                        label: 'Industry',
                        displayOperator: 'equals',
                        displayValue: '"SaaS"'
                    },
                    {
                        label: 'Country',
                        displayOperator: 'equals',
                        displayValue: '"UK"'
                    }
                ]
            });
            expect(out).toContain('Existing Assignment Criteria');
            expect(out).toContain('• Industry equals "SaaS"');
            expect(out).toContain('• Country equals "UK"');
        });

        it('falls back to the raw formatted criteria when parsing yielded nothing', () => {
            const out = buildAdminRequestText({
                list: BASE_LIST,
                hasCriteria: true,
                parsedCriteriaRules: [],
                formattedCriteria: '{"raw":"json"}'
            });
            expect(out).toContain('Existing Assignment Criteria');
            expect(out).toContain('{"raw":"json"}');
        });

        it('silently skips nullish rule entries in parsedCriteriaRules', () => {
            const out = buildAdminRequestText({
                list: BASE_LIST,
                hasCriteria: true,
                parsedCriteriaRules: [
                    null,
                    {
                        label: 'Industry',
                        displayOperator: 'equals',
                        displayValue: '"SaaS"'
                    },
                    undefined
                ]
            });
            expect(out).toContain('• Industry equals "SaaS"');
        });

        it('shows an "(unparseable)" marker when neither parsed rules nor formatted text exist', () => {
            const out = buildAdminRequestText({
                list: BASE_LIST,
                hasCriteria: true,
                parsedCriteriaRules: []
            });
            expect(out).toContain('(unparseable)');
        });

        it('omits the existing-criteria section entirely when there are no criteria', () => {
            const out = buildAdminRequestText({
                list: BASE_LIST,
                hasCriteria: false
            });
            expect(out).not.toContain('Existing Assignment Criteria');
        });
    });

    describe('proposed-criteria placeholder', () => {
        it('always includes a clearly-marked placeholder for the user to fill in', () => {
            const out = buildAdminRequestText({ list: BASE_LIST });
            expect(out).toContain('Proposed Assignment Criteria');
            expect(out).toContain('[Replace this line with the criteria you want');
        });

        it('includes an Additional Notes section for extra context', () => {
            const out = buildAdminRequestText({ list: BASE_LIST });
            expect(out).toContain('Additional Notes');
        });
    });

    describe('defensive handling', () => {
        it('does not throw when called with no arguments', () => {
            expect(() => buildAdminRequestText()).not.toThrow();
        });

        it('does not throw when called with a null list', () => {
            expect(() => buildAdminRequestText({ list: null })).not.toThrow();
        });

        it('substitutes "(unnamed)" and "(unknown)" for missing identity fields', () => {
            const out = buildAdminRequestText({ list: {} });
            expect(out).toContain('List Name:   (unnamed)');
            expect(out).toContain('List ID:     (unknown)');
        });

        it('tolerates a non-array scoringTiers without throwing', () => {
            expect(() =>
                buildAdminRequestText({ list: BASE_LIST, scoringTiers: 'not-an-array' })
            ).not.toThrow();
        });

        it('tolerates a non-array parsedCriteriaRules without throwing', () => {
            const out = buildAdminRequestText({
                list: BASE_LIST,
                hasCriteria: true,
                parsedCriteriaRules: 'nope',
                formattedCriteria: 'raw'
            });
            expect(out).toContain('raw');
        });
    });
});

describe('copyTextToClipboard', () => {
    it('uses the async Clipboard API when available and returns true on success', async () => {
        const write = jest.fn().mockResolvedValue(undefined);
        const fallback = jest.fn();

        const ok = await copyTextToClipboard('hello', {
            clipboardWrite: write,
            fallbackCopy: fallback
        });

        expect(ok).toBe(true);
        expect(write).toHaveBeenCalledWith('hello');
        expect(fallback).not.toHaveBeenCalled();
    });

    it('falls back to the sync copy path when the async Clipboard API throws', async () => {
        const write = jest.fn().mockRejectedValue(new Error('blocked'));
        const fallback = jest.fn().mockReturnValue(true);

        const ok = await copyTextToClipboard('hi', {
            clipboardWrite: write,
            fallbackCopy: fallback
        });

        expect(ok).toBe(true);
        expect(write).toHaveBeenCalledTimes(1);
        expect(fallback).toHaveBeenCalledWith('hi');
    });

    it('uses the fallback exclusively when no async Clipboard API is injected', async () => {
        const fallback = jest.fn().mockReturnValue(true);

        const ok = await copyTextToClipboard('hi', {
            clipboardWrite: null,
            fallbackCopy: fallback
        });

        expect(ok).toBe(true);
        expect(fallback).toHaveBeenCalledWith('hi');
    });

    it('returns false when both the async API and the fallback fail', async () => {
        const write = jest.fn().mockRejectedValue(new Error('blocked'));
        const fallback = jest.fn().mockReturnValue(false);

        const ok = await copyTextToClipboard('hi', {
            clipboardWrite: write,
            fallbackCopy: fallback
        });

        expect(ok).toBe(false);
    });

    it('returns false when the fallback itself throws', async () => {
        const fallback = jest.fn(() => {
            throw new Error('no execCommand');
        });

        const ok = await copyTextToClipboard('hi', {
            clipboardWrite: null,
            fallbackCopy: fallback
        });

        expect(ok).toBe(false);
    });

    describe('default clipboardWrite (navigator.clipboard)', () => {
        const originalClipboard = global.navigator.clipboard;

        afterEach(() => {
            if (originalClipboard === undefined) {
                delete global.navigator.clipboard;
            } else {
                Object.defineProperty(global.navigator, 'clipboard', {
                    value: originalClipboard,
                    configurable: true,
                    writable: true
                });
            }
        });

        it('uses navigator.clipboard.writeText when no deps are injected', async () => {
            const writeText = jest.fn().mockResolvedValue(undefined);
            Object.defineProperty(global.navigator, 'clipboard', {
                value: { writeText },
                configurable: true,
                writable: true
            });

            const ok = await copyTextToClipboard('hello');

            expect(ok).toBe(true);
            expect(writeText).toHaveBeenCalledWith('hello');
        });

        it('falls back to the default textarea path when navigator.clipboard rejects', async () => {
            const writeText = jest.fn().mockRejectedValue(new Error('blocked'));
            Object.defineProperty(global.navigator, 'clipboard', {
                value: { writeText },
                configurable: true,
                writable: true
            });

            const originalExecCommand = document.execCommand;
            document.execCommand = jest.fn().mockReturnValue(true);

            try {
                const ok = await copyTextToClipboard('hi');
                expect(ok).toBe(true);
                expect(writeText).toHaveBeenCalledTimes(1);
                expect(document.execCommand).toHaveBeenCalledWith('copy');
            } finally {
                document.execCommand = originalExecCommand;
            }
        });
    });

    describe('default _execCommandCopyFallback (textarea)', () => {
        const originalClipboard = global.navigator.clipboard;

        beforeEach(() => {
            Object.defineProperty(global.navigator, 'clipboard', {
                value: undefined,
                configurable: true,
                writable: true
            });
        });

        afterEach(() => {
            if (originalClipboard === undefined) {
                delete global.navigator.clipboard;
            } else {
                Object.defineProperty(global.navigator, 'clipboard', {
                    value: originalClipboard,
                    configurable: true,
                    writable: true
                });
            }
        });

        it('creates, selects, and removes a hidden textarea, returning execCommand result', async () => {
            const originalExecCommand = document.execCommand;
            const originalCreate = document.createElement.bind(document);
            const originalAppend = document.body.appendChild.bind(document.body);
            const originalRemove = document.body.removeChild.bind(document.body);

            let capturedTextarea = null;
            const execCommand = jest.fn().mockReturnValue(true);
            const appendSpy = jest.fn((node) => {
                capturedTextarea = node;
                return originalAppend(node);
            });
            const removeSpy = jest.fn(originalRemove);

            document.execCommand = execCommand;
            document.body.appendChild = appendSpy;
            document.body.removeChild = removeSpy;

            try {
                const ok = await copyTextToClipboard('paste-me');
                expect(ok).toBe(true);
                expect(capturedTextarea).not.toBeNull();
                expect(capturedTextarea.tagName).toBe('TEXTAREA');
                expect(capturedTextarea.value).toBe('paste-me');
                expect(capturedTextarea.getAttribute('readonly')).toBe('');
                expect(execCommand).toHaveBeenCalledWith('copy');
                expect(appendSpy).toHaveBeenCalled();
                expect(removeSpy).toHaveBeenCalled();
            } finally {
                document.execCommand = originalExecCommand;
                document.createElement = originalCreate;
                document.body.appendChild = originalAppend;
                document.body.removeChild = originalRemove;
            }
        });

        it('returns false when execCommand is missing', async () => {
            const originalExecCommand = document.execCommand;
            document.execCommand = undefined;

            try {
                const ok = await copyTextToClipboard('x');
                expect(ok).toBe(false);
            } finally {
                document.execCommand = originalExecCommand;
            }
        });

        it('returns false when execCommand throws', async () => {
            const originalExecCommand = document.execCommand;
            document.execCommand = jest.fn(() => {
                throw new Error('denied');
            });

            try {
                const ok = await copyTextToClipboard('x');
                expect(ok).toBe(false);
            } finally {
                document.execCommand = originalExecCommand;
            }
        });
    });
});
