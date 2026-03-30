# Customer Success Dashboard - Test Data for Salesforce Inspector

## Import Order (IMPORTANT)
Import in this exact order:
1. **Contacts** (`contacts.csv`)
2. **Cases** (`cases.csv`)
3. **Opportunities** (`opportunities.csv`)
4. **Tasks** (`tasks.csv`)
5. **Events** (`events.csv`)

## How to Import
1. Open Salesforce Inspector → Data Import
2. Set **Action** to `Insert`
3. Set **Object** to the object name (e.g. `Contact`)
4. Paste the CSV contents into the text area
5. Click **Import**

## Account Profiles

| Account ID | Health Target | Contacts | Open Cases | Overdue Tasks | Last Activity |
|---|---|---|---|---|---|
| `001a5000027fDM2AAM` | Healthy | 11 (Strong) | 2 (Low/Med) | 0 | 3 days ago |
| `001a5000027fDM6AAM` | Needs Attention | 6 (Moderate) | 4 (1 High) | 2 | 20 days ago |
| `001a5000027fDM4AAM` | At Risk | 2 (Weak) | 6 (2 High + escalated) | 4 | 40 days ago |
| `001a5000027fDMBAA2` | Healthy/Improving | 8 (Moderate) | 3 (1 High) | 1 | 2 days ago |

## What Each CSV Tests

- **Contacts**: Relationship depth (None/Weak/Moderate/Strong based on 0/1-4/5-9/10+ contacts)
- **Cases**: Open case count, high-priority count, escalation flag, case resolution metrics, monthly case volume chart, YTD vs prior year comparison (paired bars)
- **Tasks**: Overdue tasks, last activity date, upcoming activities, open task count
- **Events**: Activity timeline, upcoming events, next touchpoint details
- **Opportunities**: Revenue charts (quarterly + monthly), pipeline metrics, renewal indicator, YTD vs prior year comparison
