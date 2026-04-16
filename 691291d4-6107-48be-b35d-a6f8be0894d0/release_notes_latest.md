## 1. Manual Configuration Steps

### Permission Set Assignment
- Assign the **OHT_Opportunity_Health_Full_Access** permission set to users who need access to the Opportunity Health Thermostat component
- This permission set grants read/write access to the three custom health fields (Health Score, Risk Level, Health Score Last Updated) and access to the Apex controller and batch class

### Batch Job Scheduling (Optional)
- To enable automatic nightly health score recalculation for all open opportunities, schedule the **OHT_OpportunityHealthBatch** class via Setup > Scheduled Jobs
- Recommended schedule: Daily at off-peak hours (e.g., 2:00 AM)
- The batch processes opportunities in groups of 200 and updates health score fields for reporting and list views

### Record Page Configuration
- The Opportunity Health Thermostat LWC is ready to be added to Opportunity record pages
- Add the component to your Opportunity record page layout for visibility in the highlights panel or top section
- No additional configuration is required; the component automatically displays health data for the current opportunity

### Data Validation
- Verify that the three custom fields are visible on Opportunity page layouts: Health Score, Risk Level, and Health Score Last Updated
- Test the component on a sample opportunity to confirm health scores are calculating correctly

## 2. How to Use This Solution

### Viewing Opportunity Health
1. Open any Opportunity record page
2. Locate the **Opportunity Health Thermostat** component (displays as a thermometer visualization)
3. The component shows:
   - **Health Score**: A numerical value from 0-100
   - **Risk Level**: Color-coded status (Green = On Track, Orange = Needs Attention, Red = At-Risk)
   - **Last Updated**: Timestamp of the most recent calculation

### Understanding the Health Score Breakdown
The health score is calculated from four criteria, each with a visual progress bar:
- **Overdue Tasks (30% weight)**: Checks for open tasks with past due dates. Score is 100 if no overdue tasks exist, 0 if any are overdue
- **Last Activity (20% weight)**: Measures days since last activity. Score is 100 if ≤7 days, 50 if 8-14 days, 0 if >14 days
- **Close Date Proximity (25% weight)**: Measures days until close date. Score is 100 if >30 days away, 50 if 15-30 days, 0 if <15 days
- **Stage Aging (25% weight)**: Measures days in current stage. Score is 100 if ≤30 days, 50 if 31-60 days, 0 if >60 days

### Monitoring Opportunities
- Use the **Opportunities by Health** list view to see all opportunities sorted by health score and risk level
- Filter by Risk Level to focus on opportunities that need attention
- Refresh the health score manually by clicking the refresh button on the component

### Maintaining Data Quality
- Keep opportunity records updated with accurate Close Dates and Stage information
- Log activities and tasks regularly to maintain current Last Activity dates
- Complete or close overdue tasks to improve health scores

## 3. Technical Summary

This deployment includes a comprehensive Opportunity Health Thermostat solution consisting of three custom fields on the Opportunity object (Health Score, Risk Level, Health Score Last Updated), an Apex controller class that calculates health scores using standard Salesforce fields, a Lightning Web Component that displays the health data as a thermometer visualization with color-coded risk levels, and a batch class for scheduled recalculation of health scores across all open opportunities.

The solution uses a weighted scoring algorithm that analyzes four key criteria: overdue tasks (30%), last activity recency (20%), close date proximity (25%), and stage aging (25%). The component automatically refreshes when opportunity fields change via Lightning Data Service, and includes comprehensive error handling and accessibility features. All Apex code enforces field-level security and is bulkified for efficient processing of multiple opportunities.
