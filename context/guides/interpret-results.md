# Interpreting Prediction Results

> Source: Authored from first principles + Kumo platform knowledge | Last synced: 2026-03-30

## Overview

Read this document after predictions have been generated and evaluated. It
covers how to make sense of the output, validate that predictions are
reasonable, set actionable thresholds, and communicate findings to stakeholders.

---

## Understanding Prediction Output

### Binary Classification

Output: a probability score between 0.0 and 1.0 for each entity.

```
CUSTOMER_ID   | PREDICTION
C-1042        | 0.82        ← 82% probability of the predicted event
C-2001        | 0.15        ← 15% probability
C-3456        | 0.67        ← 67% probability
```

**What the score means**: The model estimates that customer C-1042 has an 82%
chance of the target event occurring within the specified time window (e.g.,
making a purchase in the next 30 days).

**What it does NOT mean**: It's not a certainty. A score of 0.82 means "in
similar situations, about 82 out of 100 entities had this outcome."

### Regression

Output: a predicted numeric value for each entity.

```
CUSTOMER_ID   | PREDICTION
C-1042        | 1,245.50    ← Predicted $1,245.50
C-2001        |    32.00    ← Predicted $32.00
C-3456        |   890.75    ← Predicted $890.75
```

### Multi-class Classification

Output: predicted class and/or class probabilities.

```
CUSTOMER_ID   | PREDICTION
C-1042        | premium     ← Most likely class
C-2001        | basic
C-3456        | premium
```

---

## Validating Predictions

Before sharing results, run sanity checks.

### Check 1: Distribution Shape

```python
import pandas as pd

predictions_df = result.predictions_df()  # or pred_df from RFM

# Basic stats
print(predictions_df['prediction'].describe())

# Distribution
print(predictions_df['prediction'].quantile([0.1, 0.25, 0.5, 0.75, 0.9]))
```

| Red Flag | What It Means | Action |
|----------|---------------|--------|
| All predictions are ~0.5 | Model has no signal | Revisit task definition (see `skills/iterate-model.md`) |
| All predictions are 0.0 or 1.0 | Model is overconfident or data is trivial | Check for data leakage |
| Extremely narrow range (e.g., 0.48–0.52) | Very weak signal | Consider if the task is predictable |
| Heavy skew (99% < 0.1) | Most entities have low probability — may be fine | Check if this matches the base rate in the data |

### Check 2: Known Entities

If you know some outcomes, spot-check the predictions:

```python
# Check a known churner
known_churner = predictions_df[predictions_df['CUSTOMER_ID'] == 'C-1042']
print(f"Known churner prediction: {known_churner['prediction'].values[0]}")
# Should be high (> 0.5) if the model is working

# Check a known loyal customer
loyal = predictions_df[predictions_df['CUSTOMER_ID'] == 'C-2001']
print(f"Loyal customer prediction: {loyal['prediction'].values[0]}")
# Should be low (< 0.5)
```

### Check 3: Top and Bottom Entities

```python
# Top 10 highest predictions
print("Top 10 (most likely):")
print(predictions_df.nlargest(10, 'prediction'))

# Bottom 10 lowest predictions
print("\nBottom 10 (least likely):")
print(predictions_df.nsmallest(10, 'prediction'))
```

**Ask**: Do the top-ranked entities make intuitive sense? If the user
recognizes specific entities, check whether the predictions match their
expectations.

### Check 4: Prediction vs. Base Rate

For binary classification, compare the prediction distribution to the
actual base rate in the data:

```python
# Average prediction
avg_prediction = predictions_df['prediction'].mean()
print(f"Average prediction: {avg_prediction:.3f}")

# If you have historical data, compare:
# Historical churn rate: ~15%
# Average prediction should be roughly similar
```

If the average prediction is 0.80 but the historical rate is 0.15, something
is wrong (likely data leakage or a bad task definition).

---

## Setting Actionable Thresholds

For binary classification, you need a threshold to convert probabilities into
decisions. The right threshold depends on the business context, not the model.

### Common Threshold Strategies

| Strategy | When to Use | How |
|----------|-------------|-----|
| **Default (0.5)** | Quick start, no domain knowledge | Classify as positive if prediction > 0.5 |
| **Base-rate matched** | Want alerts proportional to historical rate | Set threshold so predicted positive rate ≈ historical rate |
| **Action-capacity** | Limited resources (e.g., can only call 100 customers) | Sort by score, take top N |
| **Cost-sensitive** | Different costs for false positives vs. false negatives | Optimize threshold for minimum total cost |

### Threshold Selection Example

```python
# Strategy: Action-capacity (sales team can reach out to 200 customers)
top_200 = predictions_df.nlargest(200, 'prediction')
threshold = top_200['prediction'].min()
print(f"Threshold for top 200: {threshold:.3f}")

# Strategy: Base-rate matched (historical churn rate is 15%)
threshold = predictions_df['prediction'].quantile(1 - 0.15)
print(f"Threshold to match 15% rate: {threshold:.3f}")
```

### Threshold Impact

Show the user how different thresholds change the outcome:

```python
for threshold in [0.3, 0.4, 0.5, 0.6, 0.7, 0.8]:
    n_flagged = (predictions_df['prediction'] > threshold).sum()
    pct_flagged = n_flagged / len(predictions_df) * 100
    print(f"Threshold {threshold:.1f}: {n_flagged:,} flagged ({pct_flagged:.1f}%)")
```

---

## Communicating Results

### To Technical Stakeholders

Focus on metrics, methodology, and limitations:

```markdown
## Model Performance

- **Task**: Predict customer churn (no purchase in next 30 days)
- **Method**: KumoRFM zero-shot prediction
- **AUC-ROC**: 0.74 (usable — model distinguishes churners from non-churners)
- **Entity count**: 50,000 customers scored

## Key Findings
- Top 500 customers by churn risk represent 8x the base churn rate
- Average churn probability: 0.18 (matches historical ~15% churn rate)
- Model is weakest for customers with < 3 months of history

## Limitations
- Predictions are based on data through 2025-12-15
- Customers with no order history receive unreliable scores
```

### To Business Stakeholders

Focus on actions and impact:

```markdown
## Churn Risk Report

We identified **500 customers at high risk of churning** (not purchasing
in the next 30 days). These customers are 8x more likely to churn than
the average customer.

### Recommended Actions
1. **Immediate outreach** to top 100 highest-risk customers
2. **Targeted offer** to next 400 high-risk customers
3. **Monitor** remaining customers — re-score monthly

### Expected Impact
If outreach prevents churn for 20% of flagged customers:
- ~100 customers retained
- Estimated revenue preserved: $X (based on avg customer value)
```

---

## Regression-Specific Interpretation

For numeric predictions (revenue, count, amount):

### Check Prediction Range

```python
print(predictions_df['prediction'].describe())
# min should be ≥ 0 (if predicting revenue, negatives don't make sense)
# max should be plausible (if max predicted revenue is $10M for one customer, investigate)
```

### Compare to Historical

```python
# If you have historical values, compare
# Historical average order value: $85
# Predicted average: $92 — reasonable
# Predicted average: $8,500 — something is wrong
```

### Present as Ranges

For regression, consider presenting confidence ranges rather than point
predictions:

```markdown
Customer C-1042:
- Predicted 30-day revenue: $1,245
- Typical range for similar customers: $800–$1,600
- Action: High-value customer — prioritize retention
```

---

## Using Explainability

RFM supports feature importance to help explain individual predictions:

```python
result = model.predict(
    query,
    explain=rfm.ExplainConfig(),
    run_mode="fast"
)
# Returns prediction + feature importance per entity
```

**When to use explainability:**
- User asks "why is this customer flagged as high risk?"
- Stakeholders need to trust the model before acting
- Debugging unexpected predictions

**Caveat**: Explainability works best with single-entity predictions in fast
mode. It adds latency to batch predictions.

---

## Quick Reference

| Task | What to Check | What to Tell the User |
|------|---------------|----------------------|
| Binary classification | AUC, prediction distribution, top/bottom entities | "X% of flagged entities match known positives" |
| Regression | Prediction range, comparison to historical, outliers | "Average predicted value is $Y, consistent with history" |
| Weak predictions (AUC < 0.6) | Run `skills/iterate-model.md` | "Signal is limited — here's what we tried and what might help" |
| Strong predictions (AUC > 0.8) | Validate against known entities | "Model performs well — here's how to operationalize" |

---

## Common Pitfalls

1. **Presenting raw probabilities to business users** — Convert to actions
   ("top 100 at-risk customers") not scores ("probability 0.73").
2. **Using 0.5 as threshold without thinking** — The optimal threshold depends
   on the cost of false positives vs. false negatives.
3. **Not comparing to base rate** — If 15% of customers churn historically
   and the model flags 15%, it's calibrated. If it flags 80%, something is wrong.
4. **Ignoring uncertainty** — A prediction of 0.51 is not meaningfully different
   from 0.49. Don't over-interpret small differences.
5. **Not validating against known outcomes** — Always spot-check predictions
   against entities whose outcomes you already know.
