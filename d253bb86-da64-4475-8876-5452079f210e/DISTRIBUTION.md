# Distribution Strategy — v1.0

## Decision: Ship v1.0 as an **unmanaged source deployment**

Customers install by deploying the `force-app/main/default/` source directly
to their Salesforce org (via Tribal, the Salesforce CLI, or a change set
produced from a scratch org). No AppExchange listing and no managed package
at this stage.

## Why unmanaged for v1.0

- **Time to first customer is measured in days, not weeks.** A 1GP/2GP
  managed package requires a Dev Hub, a namespace, a Partner Business Org,
  Security Review (~4-8 weeks for AppExchange listing), and version
  versioning discipline. None of that is needed to onboard the first 5-50
  customers.
- **Iteration speed.** Bug fixes and small UX tweaks can ship to customers
  as incremental metadata deploys. No need to cut a new package version,
  bump an upload, and have customers click "Install Upgrade".
- **Customer extensibility.** Customers who want to adapt the wizard to
  their sales process (extra fields on `LQW_Question__c`, extra flows, a
  different theme) can freely modify the deployed metadata. Managed
  packages forbid most of this without explicit extension points.
- **No license gating.** The target audience is small SMB/mid-market
  Salesforce orgs. Licensing and entitlement tracking via the Licensing
  Management App is overkill and adds friction we don't need.

## Tradeoffs we accept

- **API-name collisions.** Unmanaged metadata lives in the customer's
  default namespace, so any object/field/class we deploy could clash with
  an existing one. We mitigate with consistent prefixes —
  `LQW_*` for lead qualification wizard and `CSD_*` for the CS dashboard.
  Before shipping a new component, grep the codebase to confirm the prefix
  is not used elsewhere in the customer's org domain.
- **IP exposure.** All Apex and LWC source is readable in the customer's
  org. Acceptable for v1.0 — there is no proprietary algorithm here, just
  CRUD and scoring logic — and transparency is a net positive for trust
  and for AI tools (Tribal, Cursor) that operate on the customer's org.
- **Upgrade UX.** Customers update by re-deploying source, not by
  clicking "Upgrade to version X" in the AppExchange. We will provide a
  short upgrade procedure in release notes for each version bump.
- **No formal versioning.** Version tracking is a git commit hash, not a
  Salesforce package version number. Customers who ask "what version am I
  on?" get a git commit SHA. If/when we move to managed we'll adopt
  semantic version numbers aligned with package versions.

## When to revisit (move to managed 2GP)

Pick the first of these that lands:

1. We cross ~50 active customer orgs and supporting incremental
   deployment upgrades per customer becomes the bottleneck.
2. An AppExchange listing is required for a specific sales motion (e.g.
   partnering with Salesforce AEs, AppExchange search visibility).
3. A customer asks to run the package on a production org with a strict
   change-management process that insists on "managed package"
   provenance.
4. We want per-org license entitlements (e.g. paid-vs-free features).

At that point, the migration path is:

- Register a namespace in a new Dev Hub.
- Convert the source to a 2GP unlocked package first (same code, still
  free to modify), then to a 2GP managed package for AppExchange
  listing. Salesforce's docs call this the "ISV evolution path".
- For customers already on unmanaged source, a one-time migration
  script renames metadata to the new namespace. We will plan this
  migration the first time we install a managed build alongside an
  existing unmanaged install, not speculatively now.

## Install / upgrade playbook (unmanaged)

Customers today install by cloning the repo and running

```bash
sf project deploy start \
    --source-dir force-app/main/default \
    --target-org <customer-org>
```

or by deploying through Tribal's UI. See `release_notes_latest.md`
for the post-deploy setup steps (permission sets, page layouts,
starter question list seeding).

Upgrades reuse the same command on the new revision; Salesforce performs
a metadata diff and applies only changes. Apex tests run automatically
during production deploys; we target ≥75% coverage on every
LQW_*/CSD_* class.
