## 1. Executive Summary

POC Tracker V1 is a native Salesforce application that enables sales and solutions teams to centrally track proof-of-concept (POC) engagements with prospective and existing customers. The application introduces a custom POC__c object linked to Accounts and Opportunities, allowing teams to see every active and past POC in one place without hunting through disparate records. Each POC captures its type (paid/unpaid), intended duration, timeline, health status, and lifecycle stage, with support for standard Salesforce Tasks for day-to-day follow-up.

This deployment delivers immediate business value by providing visibility into POC pipeline coverage, enabling teams to identify engagements missing deal linkage, and surfacing at-risk POCs via a native Kanban board grouped by lifecycle status. Three tiered permission sets (Viewer, Member, Manager) ensure appropriate access control, while a validation rule keeps data clean by enforcing that linked Opportunities belong to the same Account as the POC. The application is production-ready and targets internal Salesforce users only.

## 2. Manual Configuration Steps

**Permission Set Assignments:**
- Assign the **POC_Viewer** permission set to stakeholders who need read-only visibility into POC engagements (e.g., executives, reporting teams).
- Assign the **POC_Member** permission set to team members who update existing POC records day-to-day (e.g., Solutions Engineers, Account Executives).
- Assign the **POC_Manager** permission set to managers who create and own new POC engagements (e.g., Solutions Engineering managers, Sales leaders).

**POCs tab:**
- The POC Tracker app now opens on **POCs**. This Lightning page hosts the `pocTrackingBoard` component.
- The board reads existing POC fields only. Sections from the target design that do not have fields yet (region, close date, team, tasks, contacts, meetings, channels, usage) display a **Coming soon** box.
- Assigning any of the three POC permission sets grants access to the tab and to `POC_TrackingBoardController`.

**Post-Deployment Validation:**
- Verify that the POC tab appears in the app launcher and that users assigned to each permission set can access it according to their tier.
- Test the validation rule by attempting to link a POC to an Opportunity on a different Account—the save should fail with the error message: "The selected Opportunity belongs to a different Account. Please select an Opportunity on the same Account as this POC."
- Confirm that the native Kanban board on the "All POCs" list view displays columns in the correct order: Pre-POC, Active, Extended, Paused, Complete.
- Verify that Tasks can be created and viewed directly from the POC record page via the Activities related list.
- Open **POCs** and confirm POCs land in the column that matches Lifecycle Status. Open a card and confirm Coming soon boxes for data that is not on the POC yet.

No manual configuration of Quick Actions, WebLinks, or Flows is required for this deployment.

## 3. How to Use This Solution

**Accessing POC Records:**
1. Click the POC Tracker app in the app launcher. The app opens on **POCs**.
2. Use **Board** to scan POCs by lifecycle status. Select a card to open the detail panel. **Open record** goes to the POC page.
3. **Overview**, **List**, and **Timeline** are placeholders. Native list views and the object Kanban stay on the POC object; the **POCs** item in this app is the tracking board.

**Creating a New POC (Managers Only):**
1. Click **New** on the POC list view.
2. Enter a meaningful POC Name and select the required Account.
3. Set the Lifecycle Status (defaults to Pre-POC).
4. Optionally link a Primary Opportunity (must belong to the same Account).
5. Fill in POC Type (Paid/Un-Paid), intended Length, Start and End Dates, Health status, and Next Steps as needed.
6. Click **Save**.

**Updating POC Status (Members and Managers):**
1. Open a POC record from any list view.
2. Edit the Lifecycle Status to reflect current progress (Pre-POC → Active → Extended/Paused → Complete).
3. Update Health status (Green/Yellow/Red) to flag at-risk engagements.
4. Add or update Next Steps with free-text notes on upcoming actions.
5. Click **Save**.

**Viewing POC Pipeline:**
- **My POCs:** Shows only POCs you own—your day-to-day working view.
- **All POCs:** Displays every POC in a native Kanban board grouped by Lifecycle Status, giving the team an at-a-glance view of where every engagement stands.
- **POCs Missing an Opportunity:** Filters POCs with no linked deal, helping identify pipeline coverage gaps.

**Logging Tasks Against a POC:**
1. Open a POC record.
2. Scroll to the Activities section.
3. Click **New Task** to create a follow-up item tied directly to the POC.
4. Tasks appear on the POC record and in your standard Salesforce task list.

**Key Data Maintenance:**
- Keep Lifecycle Status current as POCs progress through their lifecycle.
- Link POCs to Opportunities as soon as a deal is identified (the validation rule ensures data integrity).
- Use Next Steps to maintain running notes on actions and decisions.
- Update Health status regularly to surface at-risk engagements early.

## 4. Technical Summary

POC Tracker V1 deploys a complete, production-ready custom object with 10 custom fields, 3 list views, 1 record page, 1 custom tab, 1 Lightning application, 3 tiered permission sets, and 1 validation rule. The POC__c object is configured with Activities enabled, allowing standard Tasks to be related via the native activity relationship without requiring a custom junction object. The data model uses standard Salesforce patterns: required Account lookup for data anchoring, optional Opportunity lookup with same-Account validation, and a required Lifecycle_Status__c picklist that drives the native Kanban board column order.

Key technical decisions include using a standard Name field (not auto-number) for meaningful POC naming, leveraging the standard Owner field for POC ownership to enable the "My POCs" list view filter, and deliberately separating intended duration (Length__c) from actual dates (Start_Date__c, End_Date__c) to capture both planned and actual timelines. The validation rule uses a formula-based approach to enforce referential integrity without custom code, and the Kanban view is native Salesforce functionality with no custom card components. All three permission sets explicitly withhold Delete access, ensuring POC records cannot be removed by any user tier.

---

## Appendix — Requirements

## Introduction

POC Tracker V1 is a native Salesforce application for tracking proof-of-concept (POC) engagements with prospective or existing customers. It introduces a single custom object, POC__c, linked to the standard Account and Opportunity objects, so sales and solutions teams can see every active and past POC tied to a customer relationship in one place. Each POC record tracks its type, duration, timeline, health, next steps, and lifecycle stage, and supports standard Salesforce Tasks for day-to-day follow-up. The application targets internal Salesforce users only — no external portal or customer-facing component is in scope for this version.

The goal of this V1 build is a small, functional, production-ready tracker rather than a full-featured platform: a native Kanban board grouped by lifecycle status gives teams an at-a-glance view of where every POC stands, three tiered permission sets (Viewer, Member, Manager) control who can view versus edit versus create records, and a validation rule keeps Opportunity linkage data-clean by enforcing that a POC's linked Opportunity belongs to the same Account. The primary users are POC owners (typically Solutions Engineers or Account Executives) who manage day-to-day POC execution, POC Members who update status and details on existing POCs, and POC Managers who set up and own new POC engagements. This build is intended for direct deployment to the production org.

## Requirements

### 1. POC Data Model Setup
**Status:** approved

**User Story:** As an admin, I want a POC__c custom object with the core fields and relationships defined so that the application has a solid data foundation for tracking POC engagements.

**Acceptance Criteria:**
- A new custom object POC__c is created with Activities (Tasks) enabled, so Tasks can be related to POC records via the standard activity relationship.
- Account__c is a required Lookup field to Account — every POC must be tied to exactly one Account.
- Primary_Opportunity__c is an optional Lookup field to Opportunity.
- Lifecycle_Status__c is a required Picklist field with exactly five values: Pre-POC, Active, Extended, Paused, Complete — with Pre-POC set as the default value.
- Start_Date__c is an optional Date field representing when the POC begins.
- End_Date__c is an optional Date field representing when the POC is expected to end or ends.
- POC_Type__c is an optional Picklist field with values Paid and Un-Paid.
- Length__c is an optional field capturing the intended duration of the POC (e.g. 2 week, 1 month) as a Picklist.
- Health__c is an optional Picklist field with values Green, Yellow, Red representing overall POC health.
- Next_Steps__c is an optional Long Text Area field for free-text notes on next steps or actions.
- The object uses the standard Owner field to represent the POC owner.
- A validation rule on POC__c blocks save when Primary_Opportunity__c is populated and its Account does not match Account__c, with a clear error message directing the user to select an Opportunity on the same Account.

**Related Elements:** CO_POC, LF_Account, LF_PrimaryOpportunity, PF_LifecycleStatus, PF_POCType, PF_Length, PF_Health, DF_StartDate, DF_EndDate, LTAF_NextSteps, VR_OpportunityAccountMatch

### 2. Tiered Access via Permission Sets
**Status:** approved

**User Story:** As an admin, I want three tiered permission sets for POC__c so that different user groups get the right level of access — from read-only visibility up to full record creation — without any group being able to delete POC records.

**Acceptance Criteria:**
- POC_Viewer permission set grants Read access only on POC__c (no Create, Edit, or Delete) and Read access on all POC__c custom fields.
- POC_Member permission set grants Read and Edit access on POC__c (no Create, no Delete) and Edit access on all POC__c custom fields, so members can update existing POC records but not create new ones.
- POC_Manager permission set grants Create, Read, and Edit access on POC__c (no Delete) and Edit access on all POC__c custom fields, so managers can create and fully manage POC records.
- None of the three permission sets grant Delete access on POC__c.
- All three permission sets grant access to the POC custom tab so assigned users can navigate to POC records.

**Related Elements:** CT_POC, PS_POCViewer, PS_POCMember, PS_POCManager

### 3. POC Navigation, List Views, and Record Page
**Status:** approved

**User Story:** As a POC owner, I want a dedicated tab, list views, and a record page for POC__c so that I can easily find, review, and manage my POC records and their related Tasks.

**Acceptance Criteria:**
- A custom tab is created for POC__c so users can navigate to POC records from the app menu.
- A list view 'My POCs' filters POC__c records where Owner equals the current user.
- A list view 'All POCs' shows all POC__c records with no owner filter.
- A list view 'POCs Missing an Opportunity' filters POC__c records where Primary_Opportunity__c is blank.
- The POC__c record page displays Account__c and Primary_Opportunity__c prominently, along with all other POC fields.
- The POC__c record page includes the standard Activities/Tasks related list so users can view and log Tasks directly against the POC record.

**Related Elements:** LF_Account, LF_PrimaryOpportunity, LV_MyPOCs, LV_AllPOCs, LV_POCsMissingOpportunity, CT_POC, RP_POCRecordPage, CA_POCTracker

### 4. Native Kanban by Lifecycle Status
**Status:** approved

**User Story:** As a POC owner, I want a native Kanban board grouped by Lifecycle_Status__c so that my team can see at a glance where every POC stands without opening individual records.

**Acceptance Criteria:**
- The POC__c list view is configured with native Kanban view grouped by the Lifecycle_Status__c field.
- Kanban columns reflect the five Lifecycle_Status__c values in order: Pre-POC, Active, Extended, Paused, Complete.
- Users can open a POC record directly from its Kanban card to view or edit details and related Tasks — no custom card component is used.
Kanban cards on the All POCs list view display: POC Name, Health__c, POC_Type__c, a read-only Opportunity Amount value, Start_Date__c/End_Date__c, and Next_Steps__c — replacing the previous default card fields (Account name, POC name, Opportunity name), which were all clickable and confusing.
A new formula field Opportunity_Amount__c (Currency) is added to POC__c that returns Primary_Opportunity__c.Amount (blank when no Opportunity is linked), so the Opportunity's deal size can be shown on the Kanban card without a lookup field on the card itself.

**Related Elements:** PF_LifecycleStatus, LV_AllPOCs, FF_OpportunityAmount

## Glossary

POC (Proof of Concept): A time-bound evaluation engagement with a customer to validate a solution before a full purchase or rollout, tracked here as a POC__c record.
POC__c: The custom Salesforce object at the center of this application; one record represents one POC engagement, linked to an Account and optionally an Opportunity.
Account__c: Required lookup field on POC__c pointing to the standard Account object \u2014 identifies which customer the POC is for.
Primary_Opportunity__c: Optional lookup field on POC__c pointing to the standard Opportunity object; if set, its Account must match POC__c.Account__c.
Lifecycle_Status__c: Required picklist field on POC__c tracking where the engagement stands. Values: Pre-POC (default), Active, Extended, Paused, Complete.
POC_Type__c: Optional picklist on POC__c indicating whether the engagement is Paid or Un-Paid.
Length__c: Optional picklist on POC__c capturing the intended duration of the engagement (e.g. 2 week, 1 month).
Health__c: Optional picklist on POC__c indicating overall engagement health (Green, Yellow, Red).
Next_Steps__c: Optional long text field on POC__c for free-text notes on upcoming actions.
POC_Viewer: Permission set granting read-only access to POC__c records and fields.
POC_Member: Permission set granting read and edit access to POC__c records and fields, but not create or delete.
POC_Manager: Permission set granting create, read, and edit access to POC__c records and fields, but not delete.
Kanban View: A native Salesforce list view display mode that shows records as cards grouped into columns by a picklist field \u2014 here, grouped by Lifecycle_Status__c.
Validation Rule: Declarative Salesforce logic that blocks a record from saving unless a defined condition is met \u2014 used here to enforce that a linked Opportunity shares the same Account as the POC.
Activities (Tasks): Standard Salesforce Task records related to a POC__c record via the standard activity relationship, used for day-to-day follow-up items.
