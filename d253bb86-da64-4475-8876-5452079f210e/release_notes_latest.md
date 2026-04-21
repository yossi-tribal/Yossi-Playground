## 1. Post-Deployment Setup

### A. Permission Set Assignment

Assign the right permission set based on user role:

- **LQW_Lead_Qualification_Access** — internal sales reps who use the wizard on Lead records.
- **LQW_Lead_Qualification_Full_Access** — sales managers and admins who manage question lists.
- **LQW_Lead_Qualification_Portal_Access** — Experience Cloud (portal/community) users.

**Steps:** 

In Tribal:
Press the Manage Permission Set button → Select a permission set → Select users to assign the permission set → Press the Assign button 

OR 

In Salesforce:
Go to Salesforce → Setup → Permission Sets → click the permission set → Manage Assignments → Add Assignments → select users.

### B. Lead Page Layout (Recommended)

Add these fields to your Lead page layouts and list views so users and reports can see qualification results:

1. **Lead Quality** (`LQW_Lead_Quality__c`) — picklist showing the calculated quality tier (`High_Quality`, `Medium_Quality`, `Low_Quality`, `DISQUALIFIED`).
2. **Question List** (`LQW_Question_List__c`) — lookup to the Question List automatically assigned to this lead.

Steps: Setup → Object Manager → Lead → Page Layouts → edit the layouts your sales team uses → drag both fields into a section.

### C. Verify the Lead Qualification Wizard is on the Page

For each Lead page (Lightning record page **and** any Experience Cloud site like Partner Sales):

1. Open a Lead record.
2. Confirm the **Lead Qualification Wizard** appears on the page.
3. If missing on a new layout: edit the page in Lightning App Builder, drag the **Lead Qualification Wizard** component into a region, save and activate.

### D. Question List Configuration

If this is a fresh install (no question lists yet), the system auto-creates a starter list called **General Qualification** with 9 sample questions on the first lead insert/update.

If you're upgrading and already have questions, your existing data is preserved.

To customize:

1. Open the **Lead Qualification Admin** app from the App Launcher.
2. Click the **Question List Manager** tab.
3. Edit the default list, or use **Clone List** to create variations for different lead types (Enterprise, SMB, Partner, etc.).
4. For each list set:
   - **Is Active** — turn on/off the list.
   - **Is Default** — only one list should be the fallback when no other criteria match.
   - **High Quality Threshold** / **Medium Quality Threshold** — points required to reach each tier.
   - **Quality Labels** — customize the friendly tier names (e.g., "Hot Lead" instead of "High Quality").
   - **Recommended Actions** — the guidance text shown to reps for each tier.

### E. Auto-Assignment Rules

The system automatically assigns a Question List to each new or updated lead based on rules in your codebase. The current rules use Lead Source, Industry, and other lead attributes.

**To change the rules:** ask your Tribal developer to edit `LQW_LeadAssignmentTriggerHandler.evaluateLeadCriteria()`. The Question List Manager will display the current rules in plain English under each list's **Assignment Rules** section.

### F. One-Time Org Configuration

The deploy assumes the **Question Order** field on Qualification Question allows duplicates (so different lists can each have a question #1, #2, etc.). If you ever re-add the unique constraint, the wizard's clone and multi-list features will break. Leave it unchecked.

### G. Smoke Test (do this right after deploy)

Walk through this 5-minute check to confirm everything works:

1. Open any Lead record. The wizard should display the assigned question list.
2. Click **Yes** or **No** on a question. The response should save instantly.
3. Watch the **Lead Quality** indicator change as you answer. Confirm the **Recommended Action** text updates.
4. Find a question with the warning badge (a dealbreaker). Answer it with the trigger response and confirm the lead's standard **Status** field flips to **Disqualified**.
5. Click the same dealbreaker answer again to remove it. Confirm the Status restores to its previous value.
6. Open the **Lead Qualification Admin** → **Question List Manager** tab. Confirm you can see your lists and edit a question.
7. If you use Experience Cloud: log in as a portal user and confirm the wizard renders correctly there too.

### H. Optional: Bypass Auto-Assignment for Data Loads

Most customers can skip this section. It only matters if you plan to run **Data Loader** jobs or integrations that insert/update many Leads at a time and you want to skip the Question List auto-assignment trigger for those specific users.

The trigger handler already checks a custom permission called `LQW_Bypass_Lead_Assignment` on every Lead DML. If the permission doesn't exist in your org, nothing happens — the trigger runs normally for every user. To opt a specific user (like a Data Loader service account) out, create the permission and grant it:

1. **Setup → Custom Permissions → New**
   - Label: `LQW Bypass Lead Assignment`
   - Name: `LQW_Bypass_Lead_Assignment` *(must match exactly)*
   - Save.
2. **Setup → Permission Sets → New**
   - Label: `LQW Bypass Auto Assignment` (or whatever you prefer)
   - Under **Custom Permissions**, enable `LQW_Bypass_Lead_Assignment`.
   - Save.
3. **Setup → Permission Sets → [your new permission set] → Manage Assignments → Add Assignments** — assign it to your Data Loader / integration user(s).

Any user with that permission set will now bypass auto-assignment on Lead insert/update. Regular sales users continue to get automatic assignment as before.

### Note on Reports & List Views

The **Lead Quality** picklist stores values in all-caps `DISQUALIFIED` format and friendly `High_Quality` / `Medium_Quality` / `Low_Quality` API codes. The wizard displays these as "Disqualified" / "High Quality" / etc. Use the API codes (with underscores) in report filters, list view filters, and any automation. The friendly labels are for display only.

---

## 2. How to Use the Solution

### For Sales Representatives

**Answering Questions**

1. Open a Lead record. The **Lead Qualification Wizard** appears on the page.
2. For each question, click **Yes** (green) or **No** (red). Your answer saves automatically.
3. Click the same button again to remove your answer.
4. You can answer in any order. Come back later — the wizard remembers your progress.

**Reading the Results**

- **Lead Quality** (top-left) — the current tier based on your answers (e.g., High Quality, Medium Quality, Low Quality, or Disqualified).
- **Recommended Action** (top-right) — what to do next based on the lead's quality tier.
- **Progress bar** — how many questions you've answered.
- Each question card shows the points it's worth (e.g., "+1 pt").

**Dealbreaker Questions (the ⚠ warning badge)**

- Hover over the badge to see which answer auto-disqualifies the lead.
- A confirmation dialog appears before saving a dealbreaker response.
- If triggered, the standard Lead **Status** flips to **Disqualified** and the lead's previous status is saved.
- Clear the dealbreaker answer to restore the lead to its previous status.

### For Sales Managers and Admins

**Managing Question Lists**

1. App Launcher → **Lead Qualification Admin** → **Question List Manager**.
2. Left panel: all your question lists. Click any list to view it.
3. Right panel: edit list settings, add/edit/delete questions, and reorder them.
4. **List Actions menu** (top right of each list) — Edit, Clone, Delete, Activate/Deactivate all questions.
5. **Assignment Rules** section — shows the rules that automatically route leads to this list.

**Editing Questions**

- Add a new question with the **Add Question** row at the bottom of the questions table.
- Edit text, order number, point value, point-earning answer (Yes / No / Both), and dealbreaker setting inline.
- Toggle **Active** to show/hide a question without deleting it.

**Customizing Quality Tiers per List**

Each list can have its own tier thresholds and labels. Example: an Enterprise list might require 7 points for "High Quality" with a "Convert to Opportunity" recommendation, while an SMB list requires only 3 points with a "Schedule Demo" recommendation.

Edit a list to set thresholds, labels, and recommendations. Changes apply only to leads assigned to that list.

**Reviewing Lead Responses**

App Launcher → **Lead Qualification Admin** → **Lead Responses** tab. Filter and report on all responses across all leads.

---

## 3. What This Solution Does (Plain English)

This release upgrades the Lead Qualification Wizard from a single-list tool to a flexible, multi-list system that adapts to different lead types. Here's what's new and how it works.

**For sales reps:** A guided question-and-answer wizard on every Lead page. Answer Yes/No, get a quality tier and recommended action in real time. Dealbreaker questions can auto-disqualify obviously-unfit leads while preserving the option to undo.

**For admins:** A drag-and-drop admin app (**Question List Manager**) where you build different question lists for different lead types — Enterprise vs. SMB, Partner vs. Direct, etc. — each with its own scoring thresholds, tier labels, and recommended actions. No code required for day-to-day list management.

**For your developer:** Lead-to-list assignment rules live in code (`LQW_LeadAssignmentTriggerHandler`) so you can route leads based on any combination of fields. The rules are auto-displayed in plain English in the admin UI for transparency.

**Built-in safety:**

- Dealbreaker confirmations prevent accidental disqualification.
- Auto-disqualification stores the lead's prior status so you can roll back.
- Multiple-dealbreaker logic prevents premature restoration.
- The page refreshes automatically when the wizard updates the lead — no manual reload needed.

**Components added:**

- 1 new custom object (**Question List**) plus new fields on existing objects.
- 1 new admin Lightning component (**Question List Manager**) and updates to the existing wizard.
- 1 new app (**Lead Qualification Admin**) with 4 tabs.
- 1 new permission grant per existing permission set for the new components.
- 1 lead trigger that auto-routes new and updated leads to the right question list.
- Apex test coverage above 79% on every deployed class.