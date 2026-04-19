# Lead Qualification Wizard — Release Notes

## 1. Manual configuration steps

1. **Assign permission sets**
   - `LQW_Lead_Qualification_Access` — internal sales users who use the wizard on Leads.
   - `LQW_Lead_Qualification_Full_Access` — admins who manage lists, questions, and related setup.
   - `LQW_Lead_Qualification_Portal_Access` — Experience Cloud / external users who qualify Leads in the portal (ensure sharing and page access are correct for your org).

2. **Place the Lightning components**
   - Add **`leadQualificationWizard`** to the **Lead record page** (Lightning App Builder) where reps should qualify.
   - For portal users, add the same component to the **appropriate Lead (or equivalent) record** experience page, with the portal permission set and sharing in place.
   - Admins use the **Lead Qualification Admin** app → **Question List Manager** tab (Flexipage) for **`questionListManager`** (no separate page assembly required beyond the app tab).

3. **Question lists and questions**
   - Open **Lead Qualification Admin** → **Question List Manager**.
   - **Starter content:** If the org has **no** `LQW_Question_List__c` rows yet, the **Lead assignment trigger** path can auto-create a default list named **“General Qualification”** with **nine** sample questions the first time that logic runs (for example on Lead insert/update). Treat this as a **starting point**; review wording, scoring, dealbreakers, and thresholds, then add lists for segments (Enterprise, SMB, Partner, etc.) as needed.
   - Mark **one** list as the **default** (`Is Default`) for assignment fallback.
   - Configure **High / Medium / Low** thresholds, **labels**, and **recommendation** text per list. The **Scoring Guide** in Question List Manager is where admins preview tier logic—not an end-user screen on the Lead.

4. **Lead assignment (optional but recommended)**
   - Keep **`LQW_LeadAssignmentTrigger`** **active** so Leads can receive a **`LQW_Question_List__c`** automatically from **assignment criteria** stored on each list (evaluated in `LQW_LeadAssignmentTriggerHandler`).
   - When no rule matches, the handler assigns the **default** list when one is defined.
   - Criteria and JSON sync are maintained through your **Question List Manager / Tribal** configuration workflow—not by editing the trigger file.

5. **Validate in a sandbox first**
   - Open a Lead with the wizard on the page: confirm **permission** gating (users without access should not see or use the wizard).
   - With **no question list** on the Lead, confirm the **guided empty state** (assign list / contact admin) appears instead of a blank panel.
   - With a list assigned, answer questions: confirm **progress**, **tier / recommended action**, **dealbreaker** confirmation and **Disqualified** status, and **restore** behavior when changing answers.
   - Use **Response history** from the wizard where applicable.

---

## 2. How to use this solution

### For sales representatives

1. **Open the wizard**  
   On a Lead record, scroll to **Lead Qualification Wizard** (after your admin has placed the component on the page).

2. **If nothing loads yet**  
   If the Lead has **no question list**, you’ll see a short **setup message** (assign a list on the Lead, save, refresh). This is expected configuration, not a personal error.

3. **Answer questions**  
   Use **Yes** / **No**. Answers save as you go. Click the **same** answer again to **clear** that response. **Progress** shows answered vs. unanswered.

4. **Read the outcome**  
   **Lead quality** shows the current **tier** (labels come from the assigned list). **Recommended action** reflects that tier. Use the **info** help next to **Lead quality** for how scoring relates to tiers.

5. **Dealbreakers**  
   Questions marked **Dealbreaker** explain the risk inline. A **browser confirmation** runs before a disqualifying answer is saved. Disqualification can set the Lead to **Disqualified**; changing or removing the answer can **restore** the prior status when the product rules allow.

6. **Partial completion**  
   You can stop and return later; saved answers and progress remain.

### For administrators

1. **Question List Manager**  
   Create lists, set **default**, thresholds, tier labels, recommendations, and **assignment criteria**. Add/reorder questions, **points**, **point-earning answer** (Yes / No / Both), **dealbreakers**, and **active** flags. Use the **Scoring Guide** section here to explain tiers to your team—it is **not** shown on the Lead wizard.

2. **Lead Responses tab**  
   Use **Lead Qualification Admin** → **Lead Responses** (`LQW_Lead_Question_Response__c`) to review stored responses and timestamps.

3. **Portal**  
   Same wizard behavior for permitted portal users; you must still deploy **pages**, **sharing**, and **membership** appropriate to your Experience Cloud site.

---

## 3. Technical summary

This package adds **three custom objects** — `LQW_Question_List__c`, `LQW_Qualification_Question__c`, and `LQW_Lead_Question_Response__c` — plus a **Lead** lookup **`LQW_Question_List__c`**. Two **LWCs** ship with the package: **`leadQualificationWizard`** (Lead / portal qualification UX with progress, tier, recommendations, dealbreaker flows, response history, and **empty states** when no list or no active questions) and **`questionListManager`** (admin master–detail for lists and questions). **Apex** includes **`LQW_LeadQualificationController`**, **`LQW_QuestionListManagerCtrl`**, and **`LQW_LeadAssignmentTriggerHandler`** (with **`LQW_LeadAssignmentTrigger`**), supporting per-list **dynamic thresholds and labels**, **dealbreaker-driven status** updates with **Description marker** storage for restore paths, and **portal-facing** permission sets.

The **Lead** LWC uses **Lightning Data Service** (`getRecord` on Lead fields and **`notifyRecordUpdateAvailable`** after saves) so the **record layout** can refresh when status changes, while **qualification payloads** are loaded via **Apex**. The assignment handler can **seed** a **default list and nine sample questions** when the org has no lists, then **evaluate JSON criteria**, assign **`LQW_Question_List__c`** on Leads, and **sync** criteria representation on lists. The UI uses **SLDS-style** styling (CSS custom properties), **responsive** layouts, and **ARIA** on key controls (for example the progress region). **Automated Apex tests** cover controllers and the assignment handler/trigger paths for regression safety.

---

*Optional footer:* After go-live, remove or archive sample questions if they are not on-brand, and replace assignment criteria with production rules before broad rollout.