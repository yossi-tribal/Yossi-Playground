/**
 * onboardingStorage — thin, swappable storage seam for the onboarding utility.
 *
 * Why this exists:
 *   Today "has the user seen this tour?" lives in browser localStorage, keyed by
 *   userId so multiple users on the same device don't collide. If we later want
 *   a server-side version (Custom Setting, Apex, etc.), every host LWC can stay
 *   the same — we just change this module.
 *
 * Key layout: oc.v1.<scopeKey>.<tourId>
 *   scopeKey = "<userId>::<componentName>" (e.g. "005xx0000001AbC::leadQualificationWizard")
 *
 * Fails soft: if localStorage throws (private mode, quota, SSR), falls back to
 * an in-memory Map. The tour still works; it just re-shows next visit.
 */

const NS = 'oc.v1';
const SKIP_LIMIT_FOR_AUTO_COMPLETE = 2;

const memoryStore = new Map();

function safeLocalStorage() {
    try {
        if (typeof window === 'undefined' || !window.localStorage) return null;
        const probe = '__oc_probe__';
        window.localStorage.setItem(probe, '1');
        window.localStorage.removeItem(probe);
        return window.localStorage;
    } catch (e) {
        return null;
    }
}

function buildKey(scopeKey, tourId) {
    return `${NS}.${scopeKey}.${tourId}`;
}

function readEntry(key) {
    const ls = safeLocalStorage();
    if (ls) {
        try {
            const raw = ls.getItem(key);
            return raw ? JSON.parse(raw) : null;
        } catch (e) {
            return null;
        }
    }
    return memoryStore.get(key) || null;
}

function writeEntry(key, value) {
    const ls = safeLocalStorage();
    if (ls) {
        try {
            ls.setItem(key, JSON.stringify(value));
            return;
        } catch (e) {
            // quota or serialization — fall through to memory
        }
    }
    memoryStore.set(key, value);
}

function removeEntry(key) {
    const ls = safeLocalStorage();
    if (ls) {
        try {
            ls.removeItem(key);
        } catch (e) {
            // ignore
        }
    }
    memoryStore.delete(key);
}

/**
 * Build the scope key used to partition storage by user + component.
 */
export function buildScopeKey(userId, componentName) {
    const safeUser = userId || '__anon__';
    const safeComp = componentName || '__unknown__';
    return `${safeUser}::${safeComp}`;
}

/**
 * Has this (user, component, tour) been marked completed?
 * expectedVersion lets you force a re-prompt when you bump a tour.
 */
export function isCompleted(scopeKey, tourId, expectedVersion) {
    const entry = readEntry(buildKey(scopeKey, tourId));
    if (!entry || !entry.completed) return false;
    if (expectedVersion && entry.version !== expectedVersion) return false;
    return true;
}

/**
 * Mark a tour as completed. Call this when the user reaches "Finish".
 */
export function markCompleted(scopeKey, tourId, version) {
    writeEntry(buildKey(scopeKey, tourId), {
        completed: true,
        version: version || 1,
        at: Date.now()
    });
}

/**
 * Record a skip. After SKIP_LIMIT_FOR_AUTO_COMPLETE skips, auto-marks complete
 * so we stop nagging. The user can always replay via the 'i' menu.
 */
export function recordSkip(scopeKey, tourId, version) {
    const key = buildKey(scopeKey, tourId);
    const entry = readEntry(key) || {
        completed: false,
        version: version || 1,
        skips: 0,
        firstSkipAt: null
    };
    entry.skips = (entry.skips || 0) + 1;
    entry.lastSkipAt = Date.now();
    if (!entry.firstSkipAt) entry.firstSkipAt = entry.lastSkipAt;
    if (entry.skips >= SKIP_LIMIT_FOR_AUTO_COMPLETE) {
        entry.completed = true;
        entry.autoCompletedFromSkips = true;
    }
    entry.version = version || entry.version || 1;
    writeEntry(key, entry);
    return entry;
}

/**
 * Reset a single tour (if tourId supplied) or every tour in a scope.
 * Used for "Restart all introductions" and dev/debugging.
 */
export function reset(scopeKey, tourId) {
    if (tourId) {
        removeEntry(buildKey(scopeKey, tourId));
        return;
    }
    const prefix = `${NS}.${scopeKey}.`;
    const ls = safeLocalStorage();
    if (ls) {
        const keysToDrop = [];
        for (let i = 0; i < ls.length; i++) {
            const k = ls.key(i);
            if (k && k.startsWith(prefix)) keysToDrop.push(k);
        }
        keysToDrop.forEach((k) => {
            try {
                ls.removeItem(k);
            } catch (e) {
                // ignore
            }
        });
    }
    for (const k of Array.from(memoryStore.keys())) {
        if (k.startsWith(prefix)) memoryStore.delete(k);
    }
}

/**
 * Raw status entry for a tour, or null. Used by the menu to render state markers.
 */
export function getStatus(scopeKey, tourId) {
    return readEntry(buildKey(scopeKey, tourId));
}
