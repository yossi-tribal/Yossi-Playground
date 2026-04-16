# Lead Qualification Wizard - Complete Requirements Document

## Introduction

This project involves developing a Lead Qualification Wizard that integrates into the Lead record page as a Lightning Web Component (LWC). The wizard presents configurable Yes/No questions to help sales teams qualify leads effectively, calculates quality scores, applies dealbreaker rules for auto-disqualification, and provides clear visual indicators for lead ranking and next steps. The solution includes sophisticated UI/UX features, real-time data synchronization, comprehensive accessibility support, enterprise-grade security controls, and portal access for external partners.

## Requirements

### REQ-001: Advanced Lead Qualification Wizard Component
**User Story:** As a sales representative with proper permissions, I want to see a comprehensive qualification wizard on the Lead record page that provides real-time scoring, visual indicators, and interactive question management.

**Acceptance Criteria:**
- LWC component displays on Lead record page for users with custom permission set
- Professional header with Lightning icon and "Lead Qualification Wizard" title
- Shows qualification questions in a clean, organized interface with responsive design
- Displays current lead rank prominently at the top with color-coded visual indicators
- Provides clear visual indicators for dealbreaker questions with warning badges (⚠)
- Shows auto-disqualification reasons when applicable with warning icons
- Updates in real-time as questions are answered with immediate UI refresh
- Supports partial completion with automatic progress saving
- Shows detailed completion progress indicator with answered/unanswered counts
- Includes interactive tooltips for dealbreaker questions explaining consequences
- Provides toast notifications for saving states and success messages
- Automatically refreshes Lead record page when status changes (disqualified/restored)
- Professional loading states with spinners and descriptive text
- Comprehensive error handling with user-friendly error cards and messages
- Smooth animations and transitions (200-400ms) for enhanced user experience

### REQ-002: Question Configuration Data Model
**User Story:** As a system administrator, I want to configure qualification questions so that I can customize the qualification process for our business needs.

**Acceptance Criteria:**
- Custom object "LQW_Qualification_Question__c" with fields:
  - LQW_Question_Text__c (Text, 255)
  - LQW_Is_Active__c (Checkbox)
  - LQW_Question_Order__c (Number)
  - LQW_Is_Dealbreaker__c (Checkbox)
  - LQW_Dealbreaker_Value__c (Picklist: Yes, No)
  - LQW_Score_Value__c (Number, default 1)
  - LQW_Point_Earning_Answer__c (Picklist: Yes, No, Both)
- Questions can be activated/deactivated
- Question order can be customized
- Dealbreaker logic can be configured per question
- Point values can be customized per question
- Point-earning answer can be configured (Yes, No, or Both)
- Only System Administrators can modify question configuration
- Custom tab for question management
- Page layout with proper field organization

### REQ-003: Lead Response Tracking Data Model
**User Story:** As a sales manager, I want to track responses to qualification questions so that I can analyze lead qualification patterns and coach my team.

**Acceptance Criteria:**
- Junction object "LQW_Lead_Question_Response__c" with fields:
  - LQW_Lead__c (Lookup to Lead)
  - LQW_Question__c (Lookup to Qualification_Question__c)
  - LQW_Response__c (Picklist: Yes, No)
  - LQW_Response_Date__c (DateTime)
  - LQW_Last_Modified_Date__c (DateTime)
- Unique constraint on Lead + Question combination
- Responses are automatically saved when answered
- Supports partial completion - responses saved individually
- Tracks when responses were first created and last modified
- Automatic timestamp tracking for all response changes
- Custom tab for response management
- Page layout with proper field organization

### REQ-004: Advanced Scoring and Progress Tracking
**User Story:** As a sales representative, I want to see detailed scoring metrics and progress tracking so I can understand lead qualification status at a glance.

**Acceptance Criteria:**
- Real-time total score calculation displayed prominently in metric cards
- Score calculation respects Point_Earning_Answer__c field:
  - If Point_Earning_Answer__c = "Yes": award points only when response is "Yes"
  - If Point_Earning_Answer__c = "No": award points only when response is "No"
  - If Point_Earning_Answer__c = "Both": award points for either "Yes" or "No" response
- Animated progress bar with smooth width transitions (400ms cubic-bezier)
- Color-coded progress legend with visual dots distinguishing answered/unanswered states
- Separate counters for answered vs unanswered questions
- Real-time progress percentage calculation and display
- Lead ranking based on total score with visual styling:
  - 5+ points = "High Quality" → Convert to Opportunity (Green styling)
  - 3-4 points = "Medium Quality" → Convert to Opportunity with Manager Review (Yellow/orange styling)
  - 0-2 points = "Low Quality" → Nurture Lead (Do Not Convert) (Red styling)
  - DISQUALIFIED: Special red styling with warning indicators
- Score and rank display prominently in quality grid layout
- Real-time score updates as questions are answered
- Recommendation text updates based on current score and status
- Accessibility attributes (role="progressbar", aria-* attributes)
- Professional metrics section with gradient backgrounds and shadows

### REQ-005: Interactive Response Management with Toggle Functionality
**User Story:** As a sales representative, I want to easily answer questions with toggle functionality and visual feedback.

**Acceptance Criteria:**
- Yes/No buttons with distinct styling (green for Yes, red for No)
- Toggle functionality - clicking selected response deselects it (removes response)
- Visual state indicators showing selected vs unselected buttons
- Hover effects on buttons for better user experience
- Disabled state during saving operations with loading indicators
- Separate mobile and desktop button layouts for responsive design
- Touch-friendly button sizes (minimum 44px touch targets)
- ARIA accessibility attributes for screen readers
- Loading spinners during save operations
- Question numbering badges for easy reference
- Smooth button state transitions and animations
- Professional button styling with custom CSS properties

### REQ-006: Advanced Dealbreaker Management with Confirmation System
**User Story:** As a sales representative, I want clear warnings about dealbreaker questions and confirmation dialogs to prevent accidental disqualification.

**Acceptance Criteria:**
- Visual dealbreaker badges (⚠) on applicable questions
- Interactive tooltips explaining dealbreaker consequences on hover/focus
- Custom tooltip implementation with dynamic positioning and smooth fade-in/fade-out animations (300ms)
- Browser-based confirmation dialog before saving dealbreaker responses
- Clear warning message explaining disqualification consequences in confirmation dialog
- "OK" and "Cancel" options in confirmation dialog
- Prevention of accidental clicks through confirmation step
- Keyboard navigation support (ESC to cancel)
- Focus management and accessibility compliance
- Automatic lead status update to "Disqualified" when dealbreaker triggered
- Clear disqualification reason display in the UI with warning icons
- Toast notification when lead is auto-disqualified
- Immediate UI refresh showing updated lead status on record page

### REQ-007: Lead Status Restoration System
**User Story:** As a sales representative, I want leads to return to their previous status when dealbreaker responses are removed or changed.

**Acceptance Criteria:**
- System stores previous lead status before disqualification in Lead Description field with markers
- Automatic status restoration when dealbreaker response is:
  - Toggled off (deselected)
  - Changed to non-dealbreaker value
- Toast notification when lead status is restored
- Immediate UI refresh showing restored status on record page
- Fallback to "Open - Not Contacted" if previous status cannot be determined
- Automatic cleanup of status markers from Lead Description after restoration
- Data integrity validation and error recovery
- Transaction safety with proper exception handling
- Status marker format: [PREV_STATUS:StatusValue]

### REQ-008: Pre-configured Questions
**User Story:** As a system administrator, I want the system to come with pre-configured qualification questions so that we can start using the wizard immediately.

**Acceptance Criteria:**
- System includes 9 pre-configured questions:
  1. "Is the customer purchasing volume lower than $25K annually?" (Dealbreaker: Yes, Points: 1, Earning Answer: No)
  2. "Are they under any contracts that would prevent them from doing business with us?" (Dealbreaker: Yes, Points: 1, Earning Answer: No)
  3. "Is the customer using a competitive product or a product we can upgrade?" (Dealbreaker: No, Points: 1, Earning Answer: Yes)
  4. "Does the customer purchases across more than one of our categories?" (Points: 1, Earning Answer: Yes)
  5. "Is there a compelling event or reason to act within a reasonable window (e.g., 3–6 months)?" (Points: 1, Earning Answer: Yes)
  6. "Does our solution address the core need without significant gaps?" (Points: 1, Earning Answer: Yes)
  7. "Can we deliver within their required timeframe and scope?" (Points: 1, Earning Answer: Yes)
  8. "Does the lead have budget already allocated OR a viable path to obtain budget?" (Points: 1, Earning Answer: Yes)
  9. "Have you identified the decision maker or someone directly involved in the decision?" (Points: 1, Earning Answer: Yes)
- All questions are active by default
- Proper question ordering (1-9)
- Dealbreaker settings configured as specified
- Score value of 1 for all questions
- Point-earning answer configured appropriately for each question

### REQ-009: Advanced Permission and Security Model
**User Story:** As a system administrator, I want granular security controls and proper access management.

**Acceptance Criteria:**
- Custom permission sets: "LQW_Lead_Qualification_Access" and "LQW_Lead_Qualification_Full_Access"
- Only users assigned permission set can view and use the wizard
- Users without permission set see no wizard component on Lead record page
- Permission set includes necessary object and field permissions:
  - Read/Edit access to Lead object
  - Read access to LQW_Qualification_Question__c
  - Create/Read/Edit access to LQW_Lead_Question_Response__c
- Respect existing Lead object sharing rules
- Custom tabs for question and response management
- Field-level security for all custom fields
- Lead access validation and security checks in Apex controller
- Proper error handling for access denied scenarios

### REQ-010: Advanced CSS Design System
**User Story:** As a user, I want a polished, professional interface with consistent design patterns and smooth animations.

**Acceptance Criteria:**
- Comprehensive CSS custom properties system for theming:
  - Primary colors (--lqw-primary, --lqw-primary-dark)
  - Success colors (--lqw-success, --lqw-success-light, --lqw-success-dark)
  - Warning colors (--lqw-warning, --lqw-warning-light, --lqw-warning-dark)
  - Error colors (--lqw-error, --lqw-error-light)
  - Neutral color palette (--lqw-neutral-100 through --lqw-neutral-900)
  - Shadow system (--lqw-shadow-sm, --lqw-shadow-md, --lqw-shadow-lg)
  - Border radius system (--lqw-radius-sm, --lqw-radius-md, --lqw-radius-lg, --lqw-radius-full)
  - Transition timing (--lqw-transition: 200ms cubic-bezier)
- Gradient backgrounds and sophisticated color palette
- Smooth transitions and animations (200-400ms cubic-bezier)
- Box shadows with multiple layers for depth
- Responsive typography with proper font weights and spacing
- Professional loading states with branded spinners
- Error states with styled cards and appropriate iconography
- Consistent visual hierarchy and information architecture
- Smooth animations and transitions that don't block UI interactions

### REQ-011: Advanced Responsive Design System
**User Story:** As a user, I want the interface to adapt seamlessly across all device sizes with optimized layouts.

**Acceptance Criteria:**
- Breakpoint-based responsive design:
  - Desktop (901px+): 5-column grid (badge, text, dealbreaker, yes, no)
  - Mobile (900px and below): 2-column grid with stacked buttons
  - Small mobile (600px and below): Single column with adjusted sizing
- Touch-friendly button sizes and spacing
- Responsive grid layouts that adapt to screen size
- Mobile-optimized question display with proper text wrapping
- Consistent functionality across all device types
- CSS media queries for different screen sizes and densities
- Flexible grid systems with proper gap spacing
- Mobile-specific button layouts with larger touch targets
- Responsive metrics grid (single column on small screens)

### REQ-012: Real-time UI Synchronization
**User Story:** As a sales representative, I want the Lead record page to automatically update when qualification status changes without manual refresh.

**Acceptance Criteria:**
- Integration with Lightning Data Service `notifyRecordUpdateAvailable`
- Automatic record page refresh when lead is disqualified
- Automatic record page refresh when lead status is restored
- Real-time updates to all Lead record components
- No manual page refresh required for status changes
- Efficient data synchronization without full component re-renders
- Toast notifications for status changes
- Immediate UI state updates reflecting server changes

### REQ-013: Comprehensive Apex Backend Logic
**User Story:** As a system administrator, I want robust backend logic that handles complex scoring, status management, and data integrity.

**Acceptance Criteria:**
- Apex controller "LQW_LeadQualificationController" with comprehensive methods:
  - `getLeadQualificationData()` - retrieves complete qualification state
  - `saveQuestionResponse()` - handles response saving/deletion with status management
  - `getLeadResponses()` - retrieves all responses for a lead
- Wrapper classes for structured data transfer:
  - `QuestionData` - individual question with response state
  - `QualificationSummary` - complete qualification overview
  - `ResponseSaveResult` - save operation results
- Efficient SOQL queries with proper field selection
- Cacheable=false for real-time data accuracy (except for read-only wire methods)
- Comprehensive state management for complex UI interactions
- Dynamic CSS class generation based on component state
- Input validation and sanitization
- Exception handling without exposing sensitive data
- Lead access validation and security checks
- Transaction safety with proper rollback handling
- Scoring logic respects Point_Earning_Answer__c field configuration

### REQ-014: Accessibility and Inclusive Design
**User Story:** As a user with accessibility needs, I want full keyboard navigation and screen reader support.

**Acceptance Criteria:**
- ARIA labels and attributes throughout the interface
- Keyboard navigation support for all interactive elements
- Focus management and visible focus indicators
- Screen reader announcements for state changes
- High contrast mode support with increased border widths
- Reduced motion preferences respect (animations disabled)
- Semantic HTML structure with proper heading hierarchy
- Touch-friendly interaction for mobile devices
- Proper z-index layering and positioning for overlays
- Assistive text for progress bars and visual elements
- Role attributes for complex UI components

### REQ-015: Advanced Toast Notification System
**User Story:** As a user, I want clear feedback through toast notifications for all important actions and state changes.

**Acceptance Criteria:**
- Toast notifications for successful response saves
- Warning toasts for lead auto-disqualification with detailed reasons
- Success toasts for lead status restoration
- Error toasts for save failures with descriptive messages
- Custom toast positioning (bottom center with slide-up animation)
- Toast animations with 300ms ease-out transitions
- Automatic toast dismissal after 3 seconds for success messages
- Professional toast styling consistent with design system
- Accessibility support for toast announcements

### REQ-016: Advanced Error Handling and Loading States
**User Story:** As a user, I want clear feedback when the system is loading or when errors occur.

**Acceptance Criteria:**
- Professional loading states with Lightning spinners
- Descriptive loading text ("Loading qualification data...")
- Error cards with icons and clear error messages
- Graceful error recovery and user guidance
- Loading indicators during save operations
- Button disabled states during processing
- Error boundary handling for component failures
- User-friendly error messages without technical details
- Retry mechanisms for failed operations

### REQ-017: Portal Access for External Partners
**User Story:** As a partner/external sales representative, I want to access the Lead Qualification Wizard through the Salesforce portal so that I can qualify leads using the same process as internal users.

**Acceptance Criteria:**
- LWC component displays on portal pages for users with portal permission set
- Component targets include `lightningCommunity__Page` and `lightningCommunity__Default`
- Portal users see the same qualification questions as internal users
- Portal users can update lead status through the qualification process
- All existing functionality (scoring, dealbreakers, status updates) works in portal environment
- Portal-specific permission set "LQW_Lead_Qualification_Portal_Access" created
- Portal users respect Lead object sharing rules and field-level security
- Component adapts to portal themes and responsive design requirements
- Same real-time synchronization and UI features available in portal
- Toast notifications and error handling work correctly in portal context

### REQ-018: Portal-Specific Security Model
**User Story:** As a system administrator, I want granular security controls for portal users accessing the Lead Qualification Wizard.

**Acceptance Criteria:**
- Custom permission set "LQW_Lead_Qualification_Portal_Access" for portal users
- Permission set includes necessary object and field permissions for portal context:
  - Read/Edit access to Lead object (respecting portal sharing rules)
  - Read access to LQW_Qualification_Question__c
  - Create/Read/Edit access to LQW_Lead_Question_Response__c
- Portal users without permission set cannot access the wizard
- Proper error handling for portal-specific access scenarios
- Lead access validation works correctly in portal sharing context
- Portal permission set separate from internal user permission sets
- Apex controller handles both internal and portal user contexts seamlessly
- Security validation respects portal user limitations and sharing rules

### REQ-019: Point System Transparency and User Clarity
**User Story:** As a sales representative, I want to clearly understand how points are earned and calculated so that I can make informed decisions when qualifying leads.

**Acceptance Criteria:**
- Display point value badge on each question card (e.g., "+1 pt", "+2 pts", "+5 pts")
- Show which answer earns points with visual indicator:
  - "✓ Yes earns points" when Point_Earning_Answer = "Yes"
  - "✓ No earns points" when Point_Earning_Answer = "No"
  - "✓ Either answer earns points" when Point_Earning_Answer = "Both"
- Display real-time point feedback when user answers a question (e.g., "+1 point added!" animation)
- Add scoring guide card showing:
  - Current score / Total possible points (e.g., "6 / 9 points")
  - High Quality threshold: 5+ points → Convert to Opportunity
  - Medium Quality threshold: 3-4 points → Manager Review Required
  - Low Quality threshold: 0-2 points → Nurture Lead
- In Question List Manager, display per-list summary:
  - Total Possible Points for the list
  - Number of active questions
  - Average points per question
- Point value badge styling consistent with design system
- Point indicators visible on both desktop and mobile layouts
- Accessibility support for point value announcements
- Clear visual hierarchy distinguishing point values from other question metadata

## Special Requirements

### Performance Requirements
- Component must load within 2 seconds
- Real-time updates with minimal latency (<500ms)
- Efficient data retrieval for large numbers of questions
- Automatic save functionality with minimal performance impact
- Optimized CSS with custom properties for consistent theming
- Minimal DOM manipulation through computed properties
- Efficient event handling without unnecessary re-renders
- Smooth animations that don't impact performance
- Portal performance equivalent to internal Salesforce performance

### Security Requirements
- Access controlled by custom permission sets (internal and portal)
- Respect Lead object sharing rules and field-level security
- Question configuration restricted to System Administrators
- Audit trail maintained for all response changes
- Input validation and sanitization in Apex
- Exception handling without exposing sensitive data
- Proper field-level and object-level security
- Lead access validation before data operations
- Portal-specific security validation and sharing rule compliance

### User Experience Requirements
- Mobile-responsive design working on all device types
- Clear visual hierarchy and professional design
- Intuitive Yes/No button interface with toggle functionality
- Progress indicator showing completion status with animations
- Confirmation dialogs for dealbreaker responses
- Clear indication of saving states and success feedback
- Auto-save functionality with visual confirmation
- Ability to resume partial completion from any point
- Comprehensive error handling and user feedback
- Professional visual design with consistent branding
- Smooth animations that enhance rather than distract from functionality
- Accessibility compliance for inclusive design
- Consistent experience between internal Salesforce and portal environments
- **Transparent point system with clear visual indicators**
- **Real-time point feedback and scoring guidance**

### Data Management Requirements
- Automatic Lead Status field update to "Disqualified" for auto-disqualified leads
- Previous status storage and restoration using Lead Description field
- Preserve response history and timestamps
- Handle concurrent user access gracefully
- Data validation to prevent invalid responses
- Automatic cleanup of temporary data markers
- Transaction integrity with proper exception handling
- Efficient SOQL queries with proper indexing considerations
- Data consistency across internal and portal user interactions

## Glossary

**Auto-Disqualification:** The automatic process of marking a lead as disqualified when dealbreaker conditions are met, including updating the Lead Status field to "Disqualified".

**Custom Permission Set:** A Salesforce security feature that grants specific permissions to users, in this case "LQW_Lead_Qualification_Access" for internal users and "LQW_Lead_Qualification_Portal_Access" for portal users.

**Dealbreaker Question:** A qualification question where a specific answer (Yes or No) automatically disqualifies the lead from conversion.

**Junction Object:** A custom object that creates a many-to-many relationship between Leads and Qualification Questions to store individual responses.

**Lead Quality Score:** The sum of points from all answered qualification questions, calculated based on the Point_Earning_Answer__c configuration for each question.

**Lead Rank:** A categorization (High/Medium/Low Quality) based on the lead quality score that determines recommended next actions.

**Partial Completion:** The ability to answer some questions, save progress, and return later to complete the remaining questions.

**Point Earning Answer:** A configurable field (Yes, No, or Both) that determines which answer(s) to a question will award points to the lead's total score.

**Portal Access:** The ability for external users (partners/external sales reps) to access the Lead Qualification Wizard through Salesforce Experience Cloud portals.

**Progress Indicator:** A visual element showing the percentage of questions completed and overall qualification status with animated progress bars.

**Status Restoration:** The automatic process of returning a lead to its previous status when dealbreaker conditions are no longer met.

**Toggle Functionality:** The ability to select and deselect responses by clicking the same button, allowing users to remove answers.

**Tooltip System:** Interactive help text that appears on hover or focus to provide additional context and guidance for dealbreaker questions.

**Real-time Synchronization:** The automatic updating of the Lead record page when qualification status changes, using Lightning Data Service notifications.