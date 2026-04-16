# Opportunity Health Thermostat Requirements

## Introduction
The Opportunity Health Thermostat is a Lightning Web Component (LWC) designed to provide sales representatives with a visual representation of an opportunity's health status. This component will analyze various standard Salesforce data points related to an opportunity and calculate a health score, which will be displayed as a thermometer visualization. The component is designed to work in any Salesforce org without requiring custom fields or specific configurations, making it universally applicable across different sales processes.

## Requirements

### 1. Data Model Setup

**User Story:**
As a system administrator, I want custom fields added to the Opportunity object to store health score data so that the information is available for reporting and can be displayed in the UI component.

**Acceptance Criteria:**
- A custom field `Health_Score__c` (Number, 0-100) must be created on the Opportunity object to store the calculated health score
- A custom field `Risk_Level__c` (Text, 20 characters) must be created to store the risk level (On Track, Needs Attention, At-Risk)
- A custom field `Health_Score_Last_Updated__c` (DateTime) must be created to track when the score was last calculated
- All fields must have appropriate field-level security settings
- Fields must be included in relevant page layouts for visibility
- Fields must be available for reporting and list views

### 2. Opportunity Health Thermostat Component

**User Story:**
As a sales representative, I want to see a visual thermometer-style representation of an opportunity's health status so that I can quickly identify which opportunities need attention and understand the factors affecting their health.

**Acceptance Criteria:**
- The component must display a thermometer visualization that represents the health score from 0-100
- The thermometer must use color coding based on Risk Level:
  - Green for "On Track" (scores 75-100)
  - Orange for "Needs Attention" (scores 50-74)
  - Red for "At-Risk" (scores 0-49)
- The component must display the numerical health score prominently
- The component must display the risk level (On Track/Needs Attention/At-Risk)
- The component must show a breakdown of the four health criteria with individual scores:
  - Overdue Tasks (30% weight)
  - Last Activity (20% weight)
  - Close Date Proximity (25% weight)
  - Stage Aging (25% weight)
- Each criterion must have a visual indicator (progress bar or similar) showing its contribution to the overall score
- The component must include tooltips or help text explaining how each criterion is calculated
- The component must be responsive and work on both desktop and mobile devices
- The component must refresh automatically when opportunity data changes

### 3. Health Score Calculation Logic

**User Story:**
As a sales manager, I want the opportunity health score to be calculated based on standard Salesforce data points so that I have an objective measure of opportunity health that works across different orgs without custom field dependencies.

**Acceptance Criteria:**
- The health score must be calculated using only standard Salesforce fields and objects
- **Overdue Tasks Criterion (30% weight):**
  - Query open Tasks related to the Opportunity (WHERE IsClosed = false AND WhatId = OpportunityId)
  - Check if any tasks have ActivityDate < TODAY
  - Score: 100 if no overdue tasks, 0 if any overdue tasks exist
  - Weighted contribution: Score × 0.30
- **Last Activity Criterion (20% weight):**
  - Use standard LastActivityDate field on Opportunity
  - Calculate days since last activity: TODAY - LastActivityDate
  - Score: 100 if ≤7 days, 50 if 8-14 days, 0 if >14 days
  - Weighted contribution: Score × 0.20
- **Close Date Proximity Criterion (25% weight):**
  - Use standard CloseDate field on Opportunity
  - Calculate days until close: CloseDate - TODAY
  - Score: 100 if >30 days, 50 if 15-30 days, 0 if <15 days
  - Weighted contribution: Score × 0.25
- **Stage Aging Criterion (25% weight):**
  - Query OpportunityHistory to determine when opportunity entered current stage
  - Calculate days in current stage: TODAY - (date of last stage change)
  - Score: 100 if ≤30 days, 50 if 31-60 days, 0 if >60 days
  - Weighted contribution: Score × 0.25
- **Final Health Score:** Sum of all weighted contributions (0-100)
- **Risk Level Mapping:**
  - 75-100: On Track
  - 50-74: Needs Attention
  - 0-49: At-Risk

### 4. Closed Opportunity Handling

**User Story:**
As a sales representative, I want closed opportunities (won or lost) to have appropriate health scores that reflect their final status so that the health indicator remains meaningful across all opportunity stages.

**Acceptance Criteria:**
- If Opportunity.IsClosed = true AND Opportunity.IsWon = true:
  - Health Score = 100
  - Risk Level = On Track
  - All criteria show maximum scores
- If Opportunity.IsClosed = true AND Opportunity.IsWon = false:
  - Health Score = 0
  - Risk Level = At-Risk
  - All criteria show minimum scores
- Closed opportunity logic must override all other scoring calculations
- The UI must clearly indicate when an opportunity is closed

### 5. Real-Time Data Integration

**User Story:**
As a sales representative, I want the health score to update automatically when I make changes to the opportunity or related tasks so that I always see current information without manual refresh.

**Acceptance Criteria:**
- The component must use Lightning Data Service or @wire adapters to detect changes to opportunity fields
- The component must monitor changes to:
  - Opportunity.StageName
  - Opportunity.CloseDate
  - Opportunity.LastActivityDate
  - Opportunity.IsClosed
  - Opportunity.IsWon
- The component must refresh health data when related Tasks are created, updated, or deleted
- The component must show loading indicators during data refresh
- Error handling must provide user-friendly messages if data cannot be loaded

### 6. Display Component on Opportunity Pages

**User Story:**
As a sales representative, I want the Opportunity Health Thermostat to be visible on opportunity record pages so that I can see the health status while viewing opportunity details.

**Acceptance Criteria:**
- A Lightning Record Page must be created for the Opportunity object
- The Opportunity Health Thermostat LWC must be added to the record page layout
- The component must be positioned prominently (e.g., in the highlights panel or top of the page)
- The record page must be set as the default for all users or assigned to appropriate profiles
- The component must only display on Opportunity record pages (not on list views or other objects)

### 7. Apex Controller for Data Access

**User Story:**
As a developer, I want an Apex class to handle server-side data queries and calculations so that the LWC can efficiently retrieve opportunity health data with proper security and bulkification.

**Acceptance Criteria:**
- An Apex class must be created to serve as the LWC controller
- The Apex class must include methods to:
  - Query opportunity data with related tasks
  - Query OpportunityHistory for stage aging calculations
  - Calculate health scores based on the defined criteria
  - Update health score fields on the Opportunity record
- All Apex methods must be @AuraEnabled and cacheable where appropriate
- The Apex class must enforce field-level security (with USER_MODE or Security.stripInaccessible)
- The Apex class must handle bulk operations efficiently
- The Apex class must include comprehensive error handling
- A corresponding test class must be created with at least 75% code coverage

### 8. Permission Set for Access Control

**User Story:**
As a system administrator, I want a permission set that grants access to the Opportunity Health Thermostat component and related fields so that I can easily assign permissions to users who need this functionality.

**Acceptance Criteria:**
- A permission set must be created that includes:
  - Read/Write access to all custom health fields on Opportunity (Health_Score__c, Risk_Level__c, Health_Score_Last_Updated__c)
  - Access to the Apex controller class
  - Access to the Lightning Web Component
  - Read access to Opportunity, Task, and OpportunityHistory objects
- The permission set must be assignable to users without requiring profile changes
- The permission set must have a clear name and description indicating its purpose

## Special Requirements

### Performance Requirements
- The component must load within 2 seconds on standard network connections
- Health score calculations must complete within 1 second for opportunities with up to 100 related tasks
- The component must use efficient SOQL queries to minimize governor limit consumption
- Apex methods must be bulkified to handle multiple opportunities if needed in future enhancements

### Accessibility Requirements
- The component must be accessible to users with disabilities (WCAG 2.1 Level AA compliance)
- Color coding must be supplemented with text labels for users with color blindness
- The component must be navigable using keyboard controls
- Screen readers must be able to interpret all component content

### Error Handling and Resilience
- The component must handle missing or null data gracefully (e.g., opportunities with no tasks, no LastActivityDate)
- Network errors must be caught and displayed with user-friendly messages
- The component must continue functioning even if some data is unavailable (e.g., show partial health score)
- All exceptions in Apex must be properly logged and returned to the LWC for user notification

## Glossary

- **Health Score**: A numerical value between 0-100 that represents the overall health of an opportunity based on multiple criteria
- **Risk Level**: A categorical representation of the risk associated with an opportunity (On Track: 75-100, Needs Attention: 50-74, At-Risk: 0-49)
- **Thermostat**: The visual representation of the health score as a thermometer-style gauge
- **Overdue Tasks**: Open tasks related to the opportunity with an ActivityDate in the past
- **Last Activity**: The most recent date when a task or event was logged against the opportunity (standard LastActivityDate field)
- **Close Date Proximity**: The number of days remaining until the opportunity's CloseDate
- **Stage Aging**: The number of days the opportunity has spent in its current stage, calculated from OpportunityHistory
- **Weighted Scoring**: Each criterion contributes a percentage of the total health score based on its assigned weight (30%, 20%, 25%, 25%)