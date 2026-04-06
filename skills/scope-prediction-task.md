# Scope a Prediction Task

Translate a vague business request into a concrete, runnable prediction task.
This is the bridge between "I want to predict churn" and a validated PQL query
with the right tables, target, and time window.

---

## Prerequisites

- Data already explored (follow `skills/explore-data.md` first)
- Table list, column names, and time ranges known
- **Read first**: `context/patterns/prediction-patterns.md`, `context/platform/pql-syntax.md`

---

## Workflow

### Step 1: Clarify the Business Question

The user's request is almost never PQL-ready. Ask these questions:

**What to predict:**

| User Says | Clarify | Why |
|-----------|---------|-----|
| "predict churn" | What event defines churn? No order in 30 days? Canceled subscription? Flag column? | "Churn" has no universal definition — it depends on the data |
| "predict revenue" | Total revenue per customer? Per product? Over what time period? | Need entity + aggregation + window |
| "predict which customers will buy" | Buy anything? Buy a specific product? Buy above a threshold? | Need to define the binary condition |
| "predict fraud" | Is there a fraud_flag column? Or define as: amount > 3x average? | Need a measurable target |
| "segment customers" | By what metric? Churn risk? Spend? Engagement? | Clustering without a target is not PQL — reframe as prediction |

**Key questions to ask the user:**
1. **Who** are you predicting for? (Which entity — customers, accounts, products?)
2. **What** are you predicting? (A number? A yes/no outcome? A category?)
3. **When** — over what time horizon? (Next 7 days? 30 days? 90 days?)
4. **Why** — what action will you take based on the prediction?
5. **Where** in the data does this live? (Which table has the target signal?)

### Step 2: Identify the Task Type

Map the clarified question to a PQL task family:

| Task Type | Pattern | Example Business Question |
|-----------|---------|---------------------------|
| **Temporal regression** | `PREDICT SUM/AVG/MIN/MAX(col, 0, N, days)` | "How much will customer X spend next month?" |
| **Temporal binary classification** | `PREDICT COUNT(events.*, 0, N, days) > 0` | "Will customer X make a purchase next week?" |
| **Temporal count** | `PREDICT COUNT(events.*, 0, N, days)` | "How many orders will customer X place next quarter?" |
| **Static classification** | `PREDICT table.category_column` | "What tier will this customer fall into?" |
| **Static regression** | `PREDICT table.numeric_column` | "What is this property's value?" |

**Decision tree:**

```
Is the target about the future (a time window)?
├── YES → Temporal prediction
│   ├── Predict a number (revenue, count, amount)?
│   │   ├── YES → Temporal regression (SUM/AVG/MIN/MAX)
│   │   └── Will it happen or not?
│   │       └── YES → Binary classification (COUNT > 0 or AGG > threshold)
│   └── How many times?
│       └── Temporal count (COUNT)
└── NO → Static prediction
    ├── Predict a number? → Static regression
    └── Predict a category? → Static classification
```

### Step 3: Select Relevant Tables

Not all tables in the schema contribute to the prediction. Select based on:

**Include if:**
- The table contains the **entity** you're predicting for (e.g., CUSTOMERS)
- The table contains the **target signal** (e.g., ORDERS for purchase prediction)
- The table is **directly related** via FK to the entity or target table
- The table contains **features** that could influence the prediction (e.g., PRODUCTS adds context to orders)

**Exclude if:**
- The table has no FK path to the entity table (unreachable)
- The table is a staging, archive, or system table
- The table duplicates information already in another included table
- The table has fewer than 100 rows (unlikely to add signal)

**Rule of thumb**: Start with the minimum set (entity table + target table +
their direct FK neighbors). Add more only if early results are weak.

### Step 4: Choose the Time Window

The time window is how far into the future you're predicting.

**Business-driven heuristics:**

| Business Cycle | Suggested Window | Rationale |
|----------------|------------------|-----------|
| Daily operations | 1–7 days | Staffing, inventory |
| Weekly reviews | 7–14 days | Campaign targeting |
| Monthly planning | 30 days | Churn prevention, revenue forecasting |
| Quarterly forecasting | 90 days | Sales pipeline, financial planning |
| Annual planning | 365 days | Customer lifetime value |

**Data-driven constraints:**
- Window must be **shorter** than the data's temporal span (can't predict 90 days with 60 days of history)
- Shorter windows are easier to predict (less uncertainty)
- Longer windows capture more signal but are noisier
- Match the **action cadence** — if teams review monthly, predict 30 days

**When in doubt:** Start with 30 days. It's the most common and works for
most business questions. Iterate if results are weak.

### Step 5: Construct the PQL Query

Assemble the components:

```
PREDICT <aggregation>(<target_table>.<target_column>, 0, <window>, days)
  FOR EACH <entity_table>.<primary_key>
  [WHERE <entity_filter>]
```

**Examples:**

| Business Question | PQL Query |
|-------------------|-----------|
| "Will customer X churn (no orders in 30d)?" | `PREDICT COUNT(orders.*, 0, 30, days) = 0 FOR EACH customers.customer_id` |
| "How much will each customer spend next month?" | `PREDICT SUM(orders.amount, 0, 30, days) FOR EACH customers.customer_id` |
| "Will this deal close in 90 days?" | `PREDICT COUNT(won_events.*, 0, 90, days) > 0 FOR EACH deals.deal_id` |
| "What is the expected claim amount per policy?" | `PREDICT SUM(claims.amount, 0, 90, days) FOR EACH policies.policy_id` |
| "Which customers will make a high-value order?" | `PREDICT SUM(orders.amount, 0, 30, days) > 500 FOR EACH customers.customer_id` |

### Step 6: Validate the Task Definition

Before running, verify:

- [ ] **Entity table exists** in the graph and has the PK column
- [ ] **Target table exists** and is reachable from entity via FK path
- [ ] **Target column** has the right stype (numerical for SUM/AVG, any for COUNT)
- [ ] **Time window** is shorter than the data's temporal span
- [ ] **Time column** is set on the target table
- [ ] **The task is answerable** — the data contains the signal needed
- [ ] **The task is not circular** — you're not predicting using the answer

**Circular task example (BAD):**
- Predicting `PREDICT customers.churn_flag FOR EACH customers.customer_id`
  where `churn_flag` is a label derived from future behavior already in the data.
  This is data leakage, not prediction.

### Step 7: Confirm with User

Before executing, present the scoped task:

```markdown
## Proposed Prediction Task

**Business question**: Will each customer make a purchase in the next 30 days?
**Task type**: Temporal binary classification
**PQL**: PREDICT COUNT(orders.*, 0, 30, days) > 0 FOR EACH customers.customer_id
**Tables**: CUSTOMERS (entity), ORDERS (target), PRODUCTS (feature)
**Time window**: 30 days
**Output**: Probability score (0.0–1.0) per customer

Does this match your intent? Should I adjust the time window or target?
```

---

## Quick Reference: Common Business Questions → PQL

| Business Question | Task Type | PQL Pattern |
|-------------------|-----------|-------------|
| Will customer churn? | Binary classification | `COUNT(events.*, 0, N, days) = 0` |
| How much will they spend? | Regression | `SUM(orders.amount, 0, N, days)` |
| How many orders? | Count | `COUNT(orders.*, 0, N, days)` |
| Will they buy product X? | Binary classification | `COUNT(orders.* WHERE orders.product = 'X', 0, N, days) > 0` |
| What will their tier be? | Static classification | `PREDICT customers.tier` |
| Will the deal close? | Binary classification | `COUNT(won.*, 0, N, days) > 0` |
| What's the claim amount? | Regression | `SUM(claims.amount, 0, N, days)` |

## What PQL Cannot Do

| Request | Why Not | Alternative |
|---------|---------|-------------|
| "Segment customers into groups" | No unsupervised clustering | Predict a metric, then segment by score in SQL |
| "Detect anomalies" | No anomaly detection target | Predict amount, flag outliers (actual vs predicted) in SQL |
| "When will this happen?" | Cannot predict timestamps | Predict probability across windows (7d, 30d, 90d) to bracket timing |
| "Recommend top products" | Link prediction not in RFM_SDK_V2 | Predict purchase probability per category |
| "Count unique products they'll buy" | COUNT_DISTINCT not in RFM_SDK_V2 | Use COUNT for total purchases |

---

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Target column has stype=ID | Trying to predict an identifier | Choose a numerical or categorical column |
| "Missing foreign key" | Entity and target tables not connected | Check graph edges — may need multi-hop pattern |
| Time window > data span | Predicting farther ahead than history allows | Shorten window or get more data |
| All predictions are ~0.5 | Task has no signal in the data | Re-examine task definition — is this truly predictable? |
| Class imbalance (99% one class) | Target is too rare or too common | Adjust time window or redefine target threshold |

---

## Checklist

- [ ] Business question clarified with user (who, what, when, why)
- [ ] Task type identified (temporal regression/classification, static, count)
- [ ] Relevant tables selected (entity + target + feature tables)
- [ ] Time window chosen (business-driven + data-constrained)
- [ ] PQL query constructed
- [ ] Task definition validated (no circular logic, column types correct)
- [ ] User confirmed the scoped task before execution
