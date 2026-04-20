# Customer Success Dashboard — Release Notes

## 1. Manual configuration steps

### Lightning record page (Account) — required
The account-level dashboard **does not** appear on its own. After deployment, add it in **Lightning App Builder**:

1. Open **Setup → Object Manager → Account → Lightning Record Pages** (or edit the active Account record page from an Account).
2. Edit the **record page** your CSMs use (often **Account Record Page** for the right app/profile).
3. In the **main region**, add a **new tab** (for example **“Success”**) so the standard **Details / Related** experience stays intact.
4. Drag the **`customerSuccessDashboard`** Lightning web component onto that new tab and save.
5. **Activate** the page (and assign it to the right app, form factor, and profile as needed).

*Recommended layout:* one dedicated tab in the **main column** for the dashboard (same pattern as a “Success” tab next to Details/Related).

### Permission set assignment
- Assign **`CSD_CS_Dashboard_Full_Access`** (label: **CS Dashboard Full Access**) to every user who should use the Customer Success Management experience and dashboards.
- This permission set provides:
  - **Application & tab:** **Customer Success Management** app and **CSM Portfolio Dashboard** tab
  - **Apex classes:** dashboard and health-score classes (including portfolio and handler/controller classes shipped with the package)
  - **Account fields:** readable + editable on **`CSD_Account_Health_Score__c`** and **`CSD_Primary_CSM__c`**
  - **Related records:** **Read** on **Account, Case, Task, Event, Opportunity, and Contact** (subject to sharing; no broad View All)
- **Creating** tasks, cases, events, or opportunities from quick actions still requires appropriate **object create/edit** rights from the user’s **profile** (or another permission set). This package’s permission set is intentionally read-focused on those standard objects.

### Account field configuration
- Set **`CSD_Primary_CSM__c`** (Primary CSM) on each Account so portfolio views and ownership line up to the right CSM.
- **`CSD_Account_Health_Score__c`** (Account Health Score) is normally **maintained by automation** (triggers). You may set it manually if needed; calculated values overwrite when rules fire.
- Picklist values (API): **`Healthy`**, **`Needs Attention`**, **`At Risk`**, **`Not Assessed`** (default). If you use **Account record types**, ensure all four values are enabled for **each** record type that uses this field (restricted picklist + record type can otherwise block saves).

### Data quality checks
- **Cases:** `AccountId` populated; **`Priority`** and **`IsEscalated`** meaningful for health logic.
- **Tasks / events:** linked with **`WhatId`** (or appropriate Who/What); **`ActivityDate`** set where the product logic depends on dates.
- **Opportunities / contacts:** linked to the Account as usual for pipeline and relationship views.

### Post-deployment smoke tests
- Open an Account on the **tab where you placed `customerSuccessDashboard`** — confirm KPIs, snapshot, and accordions load.
- Open **Customer Success Management** → **CSM Portfolio Dashboard** — confirm assigned accounts, filters, and drill-down.
- Change a **Case / Task / Event** that should move health — confirm **`CSD_Account_Health_Score__c`** updates.
- Exercise **Log call / New task / Event / Case** — confirm they succeed given the user’s **profile** permissions.

---

## 2. How to use this solution

### Account-level dashboard
1. Go to an **Account** record.
2. Open the **tab** where **`customerSuccessDashboard`** was placed (e.g. **Success**).
3. Use the sections:
   - **Health score (hero):** Healthy / Needs Attention / At Risk / Not Assessed, with breakdown where implemented.
   - **Suggested actions:** prioritized recommendations from current metrics.
   - **Quick actions:** log call, task, event, case (requires sufficient **user profile** permissions to create those records).
   - **Stat bar / snapshot:** cases, tasks, opportunities, revenue/support KPIs and trends where shown in your build.
   - **Detail accordions:** tasks, events, cases, opportunities, contacts as implemented.

### Portfolio dashboard
1. App Launcher → **Customer Success Management**.
2. **CSM Portfolio Dashboard** tab.
3. Use summary KPIs, filters, sorting, and row drill-down to **modal** account detail / navigation as designed in your org.

### Practical workflows (high level)
- **Triage health:** hero + breakdown; **At Risk** first, then **Needs Attention**.
- **Work the queue:** tasks and events; overdue styling where present.
- **Support load:** open cases; high priority / escalated emphasis where present.
- **Portfolio sweep:** filters (e.g. At Risk, Needs Attention, Healthy, renewals/inactive if enabled in your build).

### Ongoing data hygiene
- Keep activities and cases tied to the right Account with consistent dates and priorities so scores stay trustworthy.
- Keep **`CSD_Primary_CSM__c`** current for portfolio membership.

---

## 3. Technical summary

**Primary metadata / code**
- **LWCs:** `customerSuccessDashboard`, `csmPortfolioDashboard`, `csdResolutionFormat`
- **Apex:** `CSD_CSDashboardController`, `CSD_CSMPortfolioController`, health handlers; **triggers** on Account, Case, Task, Event (recalculate **`CSD_Account_Health_Score__c`** from activity, cases, tasks).
- **Custom fields (Account):** `CSD_Account_Health_Score__c` (restricted picklist: Healthy, Needs Attention, At Risk, Not Assessed), `CSD_Primary_CSM__c` (User lookup).
- **UX shell:** Custom app **Customer Success Management**, Lightning page/tab for **CSM Portfolio Dashboard**, permission set **`CSD_CS_Dashboard_Full_Access`**.

**Patterns**
- **Health scoring:** trigger-driven recalculation from related activity and case/task signals.
- **Query design:** controllers aggregate and filter for portfolio scale; account health aggregation is **bulk-safe** (no per-account SOQL fan-out in handler paths shipped in recent versions).
- **Security:** Apex uses **`with sharing`**; FLS + sharing enforced; permission set scopes dashboard features without granting blanket modify-all.

**Deployment note (standard object overrides)**
- **Account** and **Opportunity** record **View** action overrides ship as **Default** Lightning experience so deployment does not depend on org-specific FlexiPages (e.g. no missing `Account_Record_Page1` in the package).