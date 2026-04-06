# Business Problem Patterns

> Source: kumo-ai-engineering (system-prompt) | Last synced: 2026-03-24

## Overview

Read this document when you need to translate a user's business question into a
concrete SQL + PQL workflow. These 10 patterns cover the most common business
prediction scenarios. Each pattern combines SQL (for data retrieval and
aggregation) with PQL (for predictions). Recognizing which pattern applies is
the first step in building the right workflow.

---

## Decision Framework

| Signal in the question | Tool | Example |
|------------------------|------|---------|
| Historical data lookup, aggregation, filtering | **SQL only** | "What were last quarter's sales by region?" |
| Future outcome, probability, prediction | **PQL only** | "Will customer X churn?" |
| Prediction + ranking, comparison, or aggregation | **SQL + PQL** | "Which region will have the highest predicted revenue?" |

If a question is purely historical, use SQL. If it requires a forward-looking
prediction, PQL is needed. Most real business questions require both.

---

## Pattern Summary

| # | Pattern | Recognition Heuristic | Workflow Skeleton |
|---|---------|----------------------|-------------------|
| 1 | Simple Prediction | Single entity, single metric | PQL |
| 2 | Ranked Predictions | "top", "bottom", "highest", "lowest" | PQL -> SQL ORDER BY + LIMIT |
| 3 | Two-Step Aggregation | Group-level prediction (region, segment) | SQL -> PQL -> SQL GROUP BY |
| 4 | Counterfactual Comparison | "what if", "impact of", "compared to" | Baseline PQL + ASSUMING PQL -> SQL diff |
| 5 | Multi-Metric Scoring | Multiple prediction targets | Multiple PQL -> SQL combine |
| 6 | Segment Comparison | Compare predictions across groups | SQL entities + segments -> PQL -> SQL GROUP BY |
| 7 | Filtered Prediction | Predict for a subset matching criteria | SQL filter -> PQL -> SQL |
| 8 | Threshold Analysis | "what percentage", "how many will" | PQL -> SQL percentage calc |
| 9 | Opportunity Scoring | Business value + probability | SQL value -> PQL probability -> SQL weighted rank |
| 10 | Forecasting | Time-series future projection | Multiple PQL windows -> SQL combine |

---

## Pattern 1: Simple Prediction

**Recognize:** Single entity, single predicted metric, no ranking or comparison.

**Workflow:** Execute one PQL query. Return the result directly.

**Example:** "What is the probability that customer C-1042 churns in 30 days?"
- PQL: `PREDICT LAST(orders.order_date, 0, 30, days) FOR EACH customers.customer_id`
- Entity SQL: `SELECT 'C-1042' AS CUSTOMER_ID`

---

## Pattern 2: Ranked Predictions

**Recognize:** "top N", "bottom N", "highest", "lowest", "most/least likely".

**Workflow:** PQL for all entities, then SQL `ORDER BY` + `LIMIT`.

**Example:** "Which 10 customers are most likely to churn?"
- PQL: `PREDICT LAST(orders.order_date, 0, 30, days) FOR EACH customers.customer_id`
- Entity SQL: `SELECT CUSTOMER_ID FROM CUSTOMERS`
- Post-SQL: `SELECT * FROM pql_results ORDER BY prediction DESC LIMIT 10`

---

## Pattern 3: Two-Step Aggregation

**Recognize:** Group-level prediction (region, segment, category). This is the
multi-hop workaround: PQL predicts per entity, SQL aggregates to the group.

**Workflow:** SQL (entities + group) -> PQL (per entity) -> SQL GROUP BY.

**Example:** "Predicted average order value by customer segment?"
- Entity SQL: `SELECT c.CUSTOMER_ID, c.SEGMENT FROM CUSTOMERS c`
- PQL: `PREDICT AVG(orders.amount, 0, 30, days) FOR EACH customers.customer_id`
- Post-SQL: `SELECT SEGMENT, AVG(prediction) FROM results GROUP BY SEGMENT`

---

## Pattern 4: Counterfactual Comparison

**Recognize:** "what if", "impact of", "compared to baseline", "with vs without".

**Workflow:** Baseline PQL + ASSUMING PQL -> SQL diff.

**Critical:** Both PQL queries must use the **same ANCHOR_TIME**.

**Example — Executive Engagement Lift:**
- Baseline PQL:
  ```
  PREDICT SUM(opportunities.amount, 0, 90, days) FOR EACH accounts.account_id
  ```
- ASSUMING PQL:
  ```
  PREDICT SUM(opportunities.amount, 0, 90, days) FOR EACH accounts.account_id
  ASSUMING activities.has_exec_engagement = 1
  ```
- Post-SQL:
  ```sql
  SELECT b.ACCOUNT_ID,
      a.prediction - b.prediction AS lift
  FROM assuming_results a
  JOIN baseline_results b ON a.ACCOUNT_ID = b.ACCOUNT_ID
  ORDER BY lift DESC
  ```

---

## Pattern 5: Multi-Metric Scoring

**Recognize:** Multiple prediction targets for the same entities (churn AND
spend AND support tickets).

**Workflow:** Multiple PQL queries (one per metric) -> SQL JOIN on entity key.

**Example:** "Score each customer on churn risk, revenue, and support tickets."
- PQL 1: `PREDICT LAST(orders.order_date, 0, 30, days) FOR EACH customers.customer_id`
- PQL 2: `PREDICT SUM(orders.amount, 0, 30, days) FOR EACH customers.customer_id`
- PQL 3: `PREDICT COUNT(tickets.ticket_id, 0, 30, days) FOR EACH customers.customer_id`
- Post-SQL: Join all three on `CUSTOMER_ID`.

---

## Pattern 6: Segment Comparison

**Recognize:** "compare across", "by region", "per segment", "broken down by".

**Workflow:** SQL (entities + segment) -> PQL -> SQL GROUP BY segment.

**Example — Revenue by Region:**
- Entity SQL: `SELECT a.ACCOUNT_ID, a.REGION FROM ACCOUNTS a`
- PQL: `PREDICT SUM(orders.amount, 0, 30, days) FOR EACH accounts.account_id`
- Post-SQL:
  ```sql
  SELECT REGION, AVG(prediction) AS avg_predicted_revenue, COUNT(*) AS n
  FROM results GROUP BY REGION ORDER BY avg_predicted_revenue DESC
  ```

---

## Pattern 7: Filtered Prediction

**Recognize:** Predictions for a subset: "stalled deals", "high-value
customers", "accounts in California".

**Workflow:** SQL filter -> PQL -> SQL (optional post-processing).

**Example — Stalled Deals with Discount:**
- Entity SQL:
  ```sql
  SELECT o.OPPORTUNITY_ID FROM OPPORTUNITIES o
  WHERE o.DAYS_IN_STAGE > 60 AND o.IS_CLOSED = FALSE
  ```
- PQL:
  ```
  PREDICT LAST(opportunities.is_won, 0, 90, days)
  FOR EACH opportunities.opportunity_id
  ASSUMING opportunities.discount_pct = 0.10
  ```

---

## Pattern 8: Threshold Analysis

**Recognize:** "what percentage will", "how many are likely to", "what fraction".

**Workflow:** PQL for full population -> SQL percentage calculation.

**Example:** "What percentage of customers will churn in 30 days?"
- PQL: `PREDICT LAST(orders.order_date, 0, 30, days) FOR EACH customers.customer_id`
- Entity SQL: `SELECT CUSTOMER_ID FROM CUSTOMERS`
- Post-SQL:
  ```sql
  SELECT COUNT(CASE WHEN prediction > 0.5 THEN 1 END) * 100.0 / COUNT(*) AS churn_pct
  FROM results
  ```

---

## Pattern 9: Opportunity Scoring

**Recognize:** Combines business value (deal size) with predicted probability
for a weighted or risk-adjusted ranking.

**Workflow:** SQL (business value) -> PQL (probability) -> SQL (weighted rank).

**Example:** "Rank open deals by risk-adjusted expected value."
- Entity SQL: `SELECT o.OPPORTUNITY_ID, o.AMOUNT FROM OPPORTUNITIES o WHERE o.IS_CLOSED = FALSE`
- PQL: `PREDICT LAST(opportunities.is_won, 0, 90, days) FOR EACH opportunities.opportunity_id`
- Post-SQL:
  ```sql
  SELECT OPPORTUNITY_ID, AMOUNT, prediction AS close_prob,
      AMOUNT * prediction AS expected_value
  FROM results ORDER BY expected_value DESC
  ```

---

## Pattern 10: Forecasting

**Recognize:** "forecast", "project", "next N weeks/months", "time series".

**Workflow:** Multiple PQL queries with consecutive non-overlapping windows ->
SQL combine.

**Critical notes:**
- Time windows are **right-exclusive**: `(start, end]` — start excluded, end included.
- Windows must be **non-overlapping and contiguous** to avoid double-counting.
- All windows share the same **ANCHOR_TIME**.

**Example — Weekly Order Volume (4 weeks):**
- PQL Week 1: `PREDICT COUNT(orders.order_id, 0, 7, days) FOR EACH stores.store_id`
- PQL Week 2: `PREDICT COUNT(orders.order_id, 7, 14, days) FOR EACH stores.store_id`
- PQL Week 3: `PREDICT COUNT(orders.order_id, 14, 21, days) FOR EACH stores.store_id`
- PQL Week 4: `PREDICT COUNT(orders.order_id, 21, 28, days) FOR EACH stores.store_id`
- Post-SQL:
  ```sql
  SELECT w1.STORE_ID, w1.prediction AS week_1, w2.prediction AS week_2,
      w3.prediction AS week_3, w4.prediction AS week_4,
      w1.prediction + w2.prediction + w3.prediction + w4.prediction AS total_28d
  FROM week1_results w1
  JOIN week2_results w2 ON w1.STORE_ID = w2.STORE_ID
  JOIN week3_results w3 ON w1.STORE_ID = w3.STORE_ID
  JOIN week4_results w4 ON w1.STORE_ID = w4.STORE_ID
  ```

---

## Chain-of-Thought Examples

### Lift Analysis (Pattern 4)

**Question:** "If we add executive engagement to our top 50 accounts, how much
incremental revenue can we expect over the next quarter?"

**Reasoning:**
1. "If we add" signals a counterfactual -> ASSUMING clause.
2. Need baseline (current state) and scenario (with exec engagement).
3. Both queries must share the same ANCHOR_TIME for fair comparison.
4. Entity SQL selects top 50 accounts by current pipeline value.

**Steps:**
1. `SELECT ACCOUNT_ID FROM ACCOUNTS ORDER BY PIPELINE_VALUE DESC LIMIT 50`
2. Baseline: `PREDICT SUM(opportunities.amount, 0, 90, days) FOR EACH accounts.account_id`
3. Scenario: same, plus `ASSUMING activities.has_exec_engagement = 1`
4. SQL: `SELECT SUM(scenario.prediction - baseline.prediction) AS total_lift`

### Segment Comparison (Pattern 6)

**Question:** "How does predicted 30-day revenue compare across our three
customer tiers?"

**Reasoning:**
1. "Compare across tiers" -> segment comparison.
2. Need entities tagged with tier, PQL per entity, SQL aggregation by tier.

**Steps:**
1. `SELECT CUSTOMER_ID, TIER FROM CUSTOMERS`
2. PQL: `PREDICT SUM(orders.amount, 0, 30, days) FOR EACH customers.customer_id`
3. SQL: `SELECT TIER, AVG(prediction), MEDIAN(prediction), COUNT(*) FROM results GROUP BY TIER`

### Forecasting (Pattern 10)

**Question:** "Project weekly order volume for the next month."

**Reasoning:**
1. "Weekly" + "next month" = 4 consecutive non-overlapping 7-day windows.
2. Windows: (0,7], (7,14], (14,21], (21,28] — right-exclusive boundaries.
3. All four PQL calls use the same ANCHOR_TIME.

**Steps:**
1. Four PQL calls: windows `(0,7)`, `(7,14)`, `(14,21)`, `(21,28)`.
2. SQL: Join all four on STORE_ID, present as week_1 through week_4.

---

## How to Handle Unsupported Requests

When a prediction type is not supported by PQL:
1. **Acknowledge** the user's intent clearly.
2. **Explain** why PQL cannot express the request.
3. **Suggest an alternative** pattern or recommend SQL alone.

### Unsupported Scenarios

| Scenario | Why Unsupported | Alternative |
|----------|----------------|-------------|
| **Link prediction** ("Will X buy product Y?") | PQL cannot predict new relationships | Collaborative filtering outside PQL |
| **Multi-hop prediction** ("Predict revenue for a region") | PQL predicts per-entity only | Pattern 3: predict per entity, aggregate with SQL |
| **RANK syntax** | Not a PQL keyword | SQL `ORDER BY` + `LIMIT` on PQL results |
| **Temporal ordering** ("In which month will X happen?") | PQL predicts aggregates, not event timing | Consecutive windows (Pattern 10) |
| **COUNT_DISTINCT** | Not supported in PQL | Use `COUNT` or handle in SQL |
| **Timestamp predictions** | PQL cannot predict a date/time value | Predict binary outcome over a window |
| **String pattern matching** | No LIKE/REGEX in PQL | Filter with SQL first (Pattern 7) |
| **Nested aggregations** | One aggregation level only | Break into multiple SQL+PQL steps |

When in doubt, decompose: SQL for filtering/joining/aggregating historical data,
PQL for predicting future outcomes for individual entities.
