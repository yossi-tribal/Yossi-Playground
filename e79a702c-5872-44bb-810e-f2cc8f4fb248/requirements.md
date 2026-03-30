# Customer Success Dashboard - Requirements Document

## Introduction

The **Customer Success Dashboard** is a Lightning Web Component designed to provide Customer Success Managers (CSMs) with a comprehensive, actionable view of customer health and engagement directly on the Account record page. This component serves as an operational cockpit, consolidating critical customer information from multiple related objects into a single, easy-to-scan interface.

The primary goal is to help CSMs quickly answer key questions: Is this account healthy? Are there urgent issues? When was the last touchpoint? What needs follow-up? Is a renewal coming? What should I do next?

This requirements document outlines an MVP-first approach, prioritizing the most essential features for immediate business value while establishing a foundation for future enhancements. The component will leverage standard Salesforce objects (Account, Case, Task, Event, Opportunity, Contact) and extend the Account object with custom fields to support health scoring, renewal tracking, and engagement metrics.

The solution includes both an **account-level dashboard** (for viewing individual account details) and a **portfolio-level dashboard** (for CSMs to view and manage all their assigned accounts).

---

## 1. Data Model Setup

**User Story:**
As a Salesforce administrator, I want the Account object extended with custom fields that support customer success tracking so that the Customer Success Dashboard has the data foundation it needs to display health scores, renewal information, and engagement metrics.

**Acceptance Criteria:**
- A custom picklist field **Account_Health_Score__c** is created on the Account object with values: Green, Yellow, Red, Not Assessed
- A custom date field **Renewal_Date__c** is created on the Account object to track contract renewal dates
- A custom date field **Last_Engagement_Date__c** is created on the Account object to track the most recent customer interaction
- A custom date field **Next_Planned_Activity_Date__c** is created on the Account object to track upcoming scheduled activities
- A custom number field **Days_Since_Last_Activity__c** is created on the Account object to calculate engagement recency
- A custom checkbox field **At_Risk__c** is created on the Account object to flag accounts requiring immediate attention
- A custom text field **Primary_CSM__c** (lookup to User) is created on the Account object to identify the assigned Customer Success Manager
- All custom fields have appropriate field-level security and are visible to Customer Success Manager profiles
- All custom fields are added to the Account page layout for manual data entry when needed

---

## 2. Summary Strip - At-a-Glance KPIs

**User Story:**
As a Customer Success Manager, I want to see a top summary strip with key performance indicators for the current account so that I can instantly assess the account's health and identify urgent issues without scrolling or navigating away from the page.

**Acceptance Criteria:**
- The summary strip displays horizontally at the top of the Customer Success Dashboard component
- The summary strip shows the following KPIs for the current Account:
  - **Open Cases Count**: Total number of open cases (Status ≠ Closed)
  - **High Priority Cases Count**: Number of open cases with Priority = High or Escalated = True
  - **Overdue Tasks Count**: Number of tasks where Status ≠ Completed and ActivityDate < Today
  - **Last Activity Date**: Most recent completed Task or Event date (or "No recent activity" if none)
  - **Next Planned Activity**: Earliest upcoming Task or Event date (or "No upcoming activity" if none)
  - **Renewal Status**: Display Renewal_Date__c with days until renewal (or "No renewal date set" if blank)
  - **Account Health Score**: Display Account_Health_Score__c with color-coded visual indicator (Green = healthy, Yellow = caution, Red = at risk)
- Each KPI is displayed with a clear label, value, and appropriate icon
- KPIs with critical values (e.g., overdue tasks > 0, high priority cases > 0, health score = Red) are visually highlighted with warning colors
- The summary strip is responsive and adapts to different screen sizes
- Data refreshes automatically when the component loads and when the user manually refreshes

---

## 3. Support Cases Section

**User Story:**
As a Customer Success Manager, I want to see a prioritized list of open support cases for the current account so that I can quickly identify urgent issues, understand case status, and take action on critical support matters without navigating to the Cases related list.

**Acceptance Criteria:**
- The Cases section displays a table of open cases related to the current Account (AccountId = current Account)
- Cases are filtered to show only open cases (Status ≠ Closed)
- Cases are sorted by priority: Escalated cases first, then High priority, then Medium, then Low
- Within each priority level, cases are sorted by age (oldest first)
- The table displays the following columns for each case:
  - **Case Number**: Clickable link to the Case record
  - **Subject**: Case subject line (truncated if too long)
  - **Status**: Current case status
  - **Priority**: Case priority (High, Medium, Low)
  - **Owner**: Case owner name
  - **Age**: Number of days since case was created
  - **Escalated**: Visual indicator (icon or badge) if case is escalated
- The table displays a maximum of 10 cases by default
- If there are more than 10 open cases, a "View All Cases" link is displayed at the bottom of the section
- If there are no open cases, the section displays a message: "No open cases for this account"
- Cases with Priority = High or Escalated = True are visually highlighted (e.g., bold text or colored row)
- Cases older than 30 days are visually flagged as aging cases
- The section includes a "Create New Case" quick action button

---

## 4. Activities & Engagement Section

**User Story:**
As a Customer Success Manager, I want to see a clear view of overdue tasks, upcoming activities, and recent engagement for the current account so that I can ensure follow-up is on track and identify accounts that have gone too long without outreach.

**Acceptance Criteria:**
- The Activities section is divided into three subsections:
  - **Overdue Tasks**: Tasks where Status ≠ Completed and ActivityDate < Today
  - **Upcoming Activities**: Tasks and Events where ActivityDate >= Today, sorted by date (earliest first)
  - **Last Completed Activity**: Most recent completed Task or Event
- The **Overdue Tasks** subsection displays:
  - Task Subject (clickable link to Task record)
  - Due Date
  - Owner
  - Number of days overdue
  - Maximum of 5 overdue tasks displayed; "View All Tasks" link if more exist
  - If no overdue tasks, display: "No overdue tasks"
- The **Upcoming Activities** subsection displays:
  - Activity Subject (clickable link to Task or Event record)
  - Activity Type (Task or Event)
  - Due Date / Event Date
  - Owner
  - Maximum of 5 upcoming activities displayed; "View All Activities" link if more exist
  - If no upcoming activities, display: "No upcoming activities scheduled"
- The **Last Completed Activity** subsection displays:
  - Activity Subject
  - Activity Type (Task or Event)
  - Completion Date
  - Owner
  - If no completed activities exist, display: "No recent activity recorded"
- Overdue tasks are visually highlighted with warning colors (e.g., red text or icon)
- If the account has no activity in the last 30 days, a warning message is displayed: "⚠️ No activity in 30+ days"
- The section includes quick action buttons: "Log a Call", "Create Task", "Schedule Event"

---

## 5. Quick Actions

**User Story:**
As a Customer Success Manager, I want to quickly perform common actions directly from the Customer Success Dashboard so that I can respond to customer needs immediately without navigating away from the Account page.

**Acceptance Criteria:**
- The Quick Actions section is displayed prominently (e.g., as a button bar at the top or bottom of the component)
- The following quick actions are available:
  - **Create Task**: Opens a modal or standard Salesforce action to create a new Task related to the current Account
  - **Log a Call**: Opens a modal or standard Salesforce action to log a completed call (Task with Type = Call, Status = Completed)
  - **Schedule Event**: Opens a modal or standard Salesforce action to create a new Event related to the current Account
  - **Create Case**: Opens a modal or standard Salesforce action to create a new Case related to the current Account
  - **View All Cases**: Navigates to the Cases related list for the current Account
  - **View All Activities**: Navigates to the Activity History and Open Activities related lists for the current Account
- Each action button is clearly labeled with an icon and text
- Actions that open modals pre-populate the Account relationship field with the current Account
- Actions that navigate to related lists open in the same tab (or new tab based on user preference)
- Quick actions are accessible and functional on both desktop and mobile devices

---

## 6. Alerts & Risk Indicators (Future Enhancement)

**User Story:**
As a Customer Success Manager, I want to see automated alerts and risk indicators for the current account so that I can proactively identify accounts that need attention and take corrective action before issues escalate.

**Acceptance Criteria:**
- The Alerts section displays a list of warning indicators for the current Account
- The following risk rules are evaluated and displayed if triggered:
  - **No Recent Activity**: Account has no completed Tasks or Events in the last 30 days
  - **Overdue Tasks**: Account has one or more overdue tasks
  - **High Priority Cases**: Account has one or more open cases with Priority = High or Escalated = True
  - **Renewal Approaching**: Renewal_Date__c is within 60 days and no open Opportunity exists
  - **At Risk Flag**: Account has At_Risk__c = True
  - **Too Many Open Cases**: Account has more than 5 open cases
- Each alert displays:
  - Alert title (e.g., "⚠️ No Recent Activity")
  - Brief description (e.g., "No activity recorded in the last 30 days")
  - Severity indicator (e.g., High, Medium, Low)
- Alerts are sorted by severity (High first)
- If no alerts are triggered, the section displays: "✅ No active alerts for this account"
- Alerts are color-coded by severity (Red = High, Yellow = Medium, Green = Low)
- The section is collapsible to save space when not needed

---

## 7. Renewal & Revenue Section (Future Enhancement)

**User Story:**
As a Customer Success Manager, I want to see renewal and revenue information for the current account so that I can understand the financial relationship, track renewal progress, and identify revenue opportunities.

**Acceptance Criteria:**
- The Renewal & Revenue section displays key financial metrics for the current Account
- The section shows:
  - **Renewal Date**: Display Renewal_Date__c with days until renewal
  - **Open Opportunities**: Count of open Opportunities (Stage ≠ Closed Won, Closed Lost) related to the Account
  - **Renewal Opportunity**: Display the most recent Opportunity with Type = Renewal (if exists)
  - **Total Opportunity Value**: Sum of Amount for all open Opportunities
  - **Last Closed Won Opportunity**: Display the most recent Opportunity with Stage = Closed Won
- For the Renewal Opportunity, display:
  - Opportunity Name (clickable link)
  - Stage
  - Amount
  - Close Date
  - Owner
- If Renewal_Date__c is within 90 days and no open Opportunity with Type = Renewal exists, display a warning: "⚠️ Renewal approaching with no active renewal opportunity"
- If no Renewal_Date__c is set, display: "No renewal date configured"
- If no open Opportunities exist, display: "No open opportunities"
- The section includes a "Create Opportunity" quick action button
- The section is collapsible to save space when not needed

---

## 8. Stakeholder Coverage Section (Future Enhancement)

**User Story:**
As a Customer Success Manager, I want to see key contacts and stakeholder coverage for the current account so that I can assess relationship breadth, identify important decision-makers, and ensure we have strong multi-threaded relationships.

**Acceptance Criteria:**
- The Stakeholder Coverage section displays key contacts related to the current Account
- The section shows:
  - **Primary Contact**: Contact with Primary_Contact__c = True (if custom field exists) or the first Contact related to the Account
  - **Executive Sponsor**: Contact with Title containing "VP", "Director", "Chief", or "Executive" (if exists)
  - **Recently Engaged Contacts**: Contacts with recent Tasks or Events (last 30 days)
  - **Total Contacts**: Count of all Contacts related to the Account
- For each key contact, display:
  - Contact Name (clickable link)
  - Title
  - Email
  - Phone
  - Last Activity Date (most recent Task or Event)
- If no Primary Contact is identified, display: "No primary contact set"
- If no Executive Sponsor is identified, display a warning: "⚠️ No executive-level contact identified"
- If only one Contact exists, display a warning: "⚠️ Single-threaded relationship - consider expanding stakeholder coverage"
- The section displays a maximum of 5 contacts; "View All Contacts" link if more exist
- The section includes a "Create Contact" quick action button
- The section is collapsible to save space when not needed

---

## 9. Portfolio-Level Customer Success Dashboard

**User Story:**
As a Customer Success Manager, I want a portfolio-level dashboard that shows all accounts I manage so that I can prioritize my workload, identify at-risk accounts across my entire book of business, and drill down into individual account details without losing portfolio context.

**Acceptance Criteria:**

### Portfolio Summary KPIs
- The portfolio dashboard displays a summary strip at the top with aggregated KPIs across all accounts where Primary_CSM__c = current user:
  - **Total Accounts**: Count of all assigned accounts
  - **At-Risk Accounts**: Count of accounts with Account_Health_Score__c = Red
  - **Needs Attention Accounts**: Count of accounts with Account_Health_Score__c = Yellow
  - **Healthy Accounts**: Count of accounts with Account_Health_Score__c = Green
  - **Total Open Cases**: Sum of open cases across all assigned accounts
  - **Total Overdue Tasks**: Sum of overdue tasks across all assigned accounts
  - **Inactive Accounts**: Count of accounts with no activity in 30+ days
  - **Total Open Pipeline**: Sum of open opportunity amounts across all assigned accounts
- Each KPI is displayed as a card with clear label, value, and appropriate icon
- KPIs with critical values (e.g., at-risk accounts > 0, overdue tasks > 0) are visually highlighted with warning colors
- The summary strip is responsive and adapts to different screen sizes

### Accounts Table
- The portfolio dashboard displays a sortable, filterable table of all accounts where Primary_CSM__c = current user
- The table displays the following columns for each account:
  - **Account Name**: Clickable link that opens account drill-down modal
  - **Health Score**: Visual indicator (🟢 Green, 🟡 Yellow, 🔴 Red) with color-coded badge
  - **Days Since Last Activity**: Number of days since last completed Task or Event
  - **Open Cases**: Count of open cases with breakdown of high priority cases
  - **Overdue Tasks**: Count of overdue tasks
  - **Next Activity**: Date of next planned Task or Event (or "No upcoming activity")
  - **Open Pipeline**: Total amount of open Opportunities
  - **Renewal Date**: Upcoming renewal date with days until renewal
  - **Risk Indicators**: Visual badges/icons for risk factors (⚠️ no activity, overdue tasks, high priority cases)
- Each column is sortable (ascending/descending)
- The Account Name column is searchable with real-time filtering
- The table implements pagination with configurable page size (default 25 records per page)
- The table displays total record count and current page range (e.g., "Showing 1-25 of 87 accounts")

### Quick Filters
- The portfolio dashboard provides pre-configured filter buttons above the accounts table:
  - **All Accounts**: Shows all assigned accounts (default view)
  - **At Risk**: Filters to accounts with Health Score = Red
  - **Needs Attention**: Filters to accounts with Health Score = Yellow OR overdue tasks > 0 OR no activity in 30+ days
  - **Healthy**: Filters to accounts with Health Score = Green
  - **Renewals This Quarter**: Filters to accounts with Renewal_Date__c within 90 days
  - **Inactive**: Filters to accounts with no activity in 30+ days
- Active filter button is visually highlighted
- Filter selection updates the accounts table immediately
- Filter selection persists during the user session

### Suggested Actions Panel
- The portfolio dashboard displays a collapsible "Suggested Actions" panel with dynamic recommendations:
  - "X accounts need immediate attention" (Red health score)
  - "X overdue tasks across Y accounts"
  - "X renewals closing in 30 days with no activity"
  - "X accounts with no touchpoint scheduled"
- Each suggestion is clickable and applies the appropriate filter to the accounts table
- The panel is collapsible to save space
- The panel displays a count badge indicating total action items

### Account Drill-Down Modal
- Clicking an account row in the table opens a modal overlay displaying the account-level dashboard
- The modal contains the existing `customerSuccessDashboard` Lightning Web Component with recordId set to the selected account
- The modal displays the account name in the header
- The modal includes "Previous" and "Next" navigation buttons to move between accounts in the current filtered list
- The modal includes a "Close" button (X icon) to return to portfolio view
- The modal is responsive and adapts to different screen sizes
- On mobile devices, the modal may navigate to the Account record page instead of displaying an overlay
- Closing the modal returns the user to the portfolio view with the same filter and scroll position preserved

### Portfolio Trends (Optional/Future Enhancement)
- The portfolio dashboard includes a collapsible "Portfolio Trends" section with visual charts:
  - **Health Score Distribution**: Pie chart showing percentage of Green/Yellow/Red accounts
  - **Activity Trend**: Line chart showing activities logged over last 6 months
  - **Case Volume Trend**: Bar chart showing cases opened per month
  - **Pipeline Trend**: Bar chart showing pipeline value by stage
- Charts are interactive and clickable to filter the accounts table
- The section is collapsible to save space

### Navigation & Access
- The portfolio dashboard is deployed as a Lightning App Page named "CSM Portfolio Dashboard"
- A custom tab named "My Portfolio" or "CSM Portfolio" is created to access the app page
- The custom tab uses an appropriate icon (e.g., `standard:work_capacity_usage` or `standard:dashboard`)
- The custom tab is added to a custom application named "Customer Success Hub" (or existing app)
- The portfolio dashboard is accessible from the App Launcher
- Users with the `CSD_CS_Dashboard_Full_Access` permission set have access to the portfolio dashboard

### Performance & Scalability
- The portfolio dashboard loads within 3 seconds on standard network conditions
- Apex controller methods use efficient aggregate SOQL queries (COUNT, SUM, MAX) for portfolio summary
- Apex controller methods implement pagination with LIMIT/OFFSET for accounts table
- Apex controller methods use selective filters (WHERE Primary_CSM__c = :userId) to minimize record retrieval
- The portfolio dashboard handles CSMs with large portfolios (100+ accounts) without performance degradation
- Data queries respect SOQL query limits (maximum 5 queries per component load)

### User Experience & Design
- The portfolio dashboard follows the same Apple/Airbnb-inspired premium design aesthetic as the account-level dashboard
- The portfolio dashboard uses Salesforce Lightning Design System (SLDS) guidelines for consistent styling
- The portfolio dashboard is responsive and functional on desktop, tablet, and mobile devices
- Visual hierarchy clearly distinguishes between critical information (at-risk accounts, overdue items) and standard information
- Color coding is consistent: Red = urgent/at risk, Yellow = caution, Green = healthy/on track
- The portfolio dashboard includes loading spinners during data retrieval
- Error messages are user-friendly and actionable (e.g., "Unable to load accounts. Please refresh the page.")

### Security & Access Control
- The portfolio dashboard respects Salesforce object-level security (OLS) and field-level security (FLS)
- Users only see accounts where Primary_CSM__c = current user
- Apex controller methods use `with sharing` to enforce record-level security
- The portfolio dashboard respects sharing rules and role hierarchy
- Users without appropriate permissions see a friendly error message

---

## Special Requirements

### Performance & Scalability
- The Customer Success Dashboard component must load within 3 seconds on standard network conditions
- Apex controller methods must use SOQL query limits efficiently (maximum 5 queries per component load)
- Data queries must use selective filters (e.g., AccountId, Status, Date ranges) to minimize record retrieval
- The component must handle accounts with large data volumes (e.g., 100+ cases, 500+ activities) without performance degradation
- Use pagination or "Load More" patterns for sections that may contain many records

### User Experience & Design
- The component must follow Salesforce Lightning Design System (SLDS) guidelines for consistent styling
- The component must be responsive and functional on desktop, tablet, and mobile devices
- Visual hierarchy must clearly distinguish between critical information (e.g., alerts, overdue items) and standard information
- Color coding must be consistent: Red = urgent/at risk, Yellow = caution, Green = healthy/on track
- The component must include loading spinners during data retrieval
- Error messages must be user-friendly and actionable (e.g., "Unable to load cases. Please refresh the page.")

### Security & Access Control
- The component must respect Salesforce object-level security (OLS) and field-level security (FLS)
- Users must only see data they have access to based on their profile and sharing rules
- Apex controller methods must use `with sharing` to enforce record-level security
- Quick actions must respect user permissions (e.g., users without Case create permission cannot see "Create Case" button)

### Configuration & Maintenance
- The MVP version uses fixed configuration (no custom metadata types or custom settings required)
- Future versions may introduce admin-configurable thresholds (e.g., "at risk" days since last activity, aging case threshold)
- The component must be deployable via change sets or Salesforce DX
- The component must include comprehensive unit tests with at least 75% code coverage

---

## Glossary

- **CSM**: Customer Success Manager - the primary user persona for this component
- **Account Health Score**: A picklist field indicating the overall health of the customer relationship (Green, Yellow, Red, Not Assessed)
- **At Risk**: A flag indicating that an account requires immediate attention due to identified risk factors
- **Aging Case**: A support case that has been open for an extended period (e.g., 30+ days)
- **Overdue Task**: A task with a due date in the past that has not been marked as completed
- **Engagement Recency**: The number of days since the last completed activity (Task or Event) for an account
- **Renewal Date**: The date when the customer's contract or subscription is up for renewal
- **Quick Actions**: One-click buttons that allow users to perform common tasks directly from the dashboard
- **MVP**: Minimum Viable Product - the initial version of the component with core features only
- **Portfolio Dashboard**: A dashboard view that shows all accounts assigned to a CSM, with aggregated metrics and drill-down capabilities
- **Account-Level Dashboard**: A dashboard view that shows detailed information for a single account
- **Drill-Down**: The ability to navigate from a summary view (portfolio) to a detailed view (individual account)

---

## Existing Salesforce Elements

### Account Object

The standard Account object will be extended with custom fields to support customer success tracking, health scoring, and renewal management.

**Metadata ID:** Account

**Details:**
- Standard object used to store customer and company information
- Will be extended with custom fields: Account_Health_Score__c, Renewal_Date__c, Last_Engagement_Date__c, Next_Planned_Activity_Date__c, Days_Since_Last_Activity__c, At_Risk__c, Primary_CSM__c
- Serves as the primary context for the Customer Success Dashboard component
- Related to Case, Task, Event, Opportunity, and Contact objects

### Case Object

The standard Case object will be queried to display open support cases and prioritize urgent issues.

**Metadata ID:** Case

**Details:**
- Standard object used to track customer support issues and inquiries
- Key fields: CaseNumber, Subject, Status, Priority, OwnerId, CreatedDate, AccountId, IsEscalated
- Used in the Support Cases section to display open cases sorted by priority and age
- Filtered by AccountId to show cases related to the current Account

### Task Object

The standard Task object will be queried to display overdue tasks, upcoming activities, and last completed activities.

**Metadata ID:** Task

**Details:**
- Standard object used to track to-do items and completed activities
- Key fields: Subject, Status, ActivityDate, OwnerId, WhatId (AccountId), Type
- Used in the Activities & Engagement section to display overdue tasks and upcoming tasks
- Filtered by WhatId (AccountId) and Status to show relevant activities

### Event Object

The standard Event object will be queried to display upcoming meetings and calendar events.

**Metadata ID:** Event

**Details:**
- Standard object used to track calendar events and meetings
- Key fields: Subject, ActivityDate, ActivityDateTime, OwnerId, WhatId (AccountId), Type
- Used in the Activities & Engagement section to display upcoming events
- Filtered by WhatId (AccountId) to show events related to the current Account

### Opportunity Object

The standard Opportunity object will be queried to display renewal opportunities and revenue information (future enhancement).

**Metadata ID:** Opportunity

**Details:**
- Standard object used to track sales deals and revenue opportunities
- Key fields: Name, StageName, Amount, CloseDate, OwnerId, AccountId, Type
- Used in the Renewal & Revenue section (future enhancement) to display open opportunities and renewal status
- Filtered by AccountId to show opportunities related to the current Account

### Contact Object

The standard Contact object will be queried to display key stakeholders and relationship coverage (future enhancement).

**Metadata ID:** Contact

**Details:**
- Standard object used to track individual people associated with accounts
- Key fields: Name, Title, Email, Phone, AccountId
- Used in the Stakeholder Coverage section (future enhancement) to display key contacts and assess relationship breadth
- Filtered by AccountId to show contacts related to the current Account