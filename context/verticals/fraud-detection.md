# Fraud Detection with Kumo

> **PLACEHOLDER** — This document is a structural scaffold. Sections contain
> guiding questions and expected content outlines, not verified guidance.
> Fill in with real data, validated PQL examples, and tested recommendations
> before relying on this in production.

> Read this when: the prediction task involves fraud detection, anomaly
> scoring, suspicious activity flagging, or chargeback prediction.

---

## Typical Prediction Tasks

<!-- Fill in: common fraud-related PQL queries with concrete examples -->

| Business Question | PQL Pattern | Notes |
|---|---|---|
| Will this transaction be flagged as fraud? | `PREDICT COUNT(fraud_alerts.*, 0, ?, days) > 0 FOR EACH accounts.account_id` | TODO: validate time window |
| How many chargebacks in the next N days? | `PREDICT COUNT(chargebacks.*, 0, ?, days) FOR EACH accounts.account_id` | TODO: determine typical window |
| What is the expected fraud loss amount? | `PREDICT SUM(transactions.amount, 0, ?, days) WHERE transactions.is_fraud = 1 FOR EACH accounts.account_id` | TODO: verify filter-inside-agg syntax |

---

## Data Characteristics

<!-- Fill in: what makes fraud data different from typical e-commerce or CRM data -->

- **Extreme class imbalance** — fraud rates are typically 0.1–2% of transactions.
  Impact on modeling: TODO
- **Adversarial drift** — fraud patterns change as fraudsters adapt.
  Impact on time windows: TODO
- **Label reliability** — fraud labels may be delayed (chargebacks arrive
  weeks after the transaction) or incomplete (unreported fraud).
  Impact on training data: TODO
- **High-cardinality features** — merchant IDs, device fingerprints, IP addresses.
  Impact on graph construction: TODO

---

## Time Window Guidance

<!-- Fill in: why fraud typically needs shorter windows, typical ranges by sub-task -->

| Sub-task | Suggested Window | Rationale |
|----------|------------------|-----------|
| Real-time fraud scoring | TODO | TODO |
| Chargeback prediction | TODO | TODO |
| Account takeover | TODO | TODO |
| Merchant fraud ring | TODO | TODO |

---

## Graph Construction Tips

<!-- Fill in: which tables typically add signal, which are noise, common FK pitfalls -->

**Tables that typically add signal:**
- TODO (e.g., transaction history, device/session tables, merchant tables)

**Tables to be cautious with:**
- TODO (e.g., aggregated summary tables that leak future info)

**Common FK pitfalls:**
- TODO (e.g., many-to-many relationships through intermediate tables)

---

## Common Mistakes

<!-- Fill in: domain-specific mistakes that go beyond generic PQL errors -->

| Mistake | Why It Happens | Fix |
|---------|----------------|-----|
| Using fraud labels that include future information | Chargeback flags are backfilled after investigation | TODO |
| Predicting on all transactions instead of filtering | Population includes already-blocked transactions | TODO |
| Ignoring temporal ordering | Training data includes post-fraud account restrictions as features | TODO |
| Wrong entity grain | Predicting per-transaction when per-account is more actionable | TODO |

---

## Evaluation Guidance

<!-- Fill in: which metrics to trust, which are misleading for fraud -->

- **AUC-ROC** — TODO: explain why it can be misleading with extreme imbalance
- **Precision-Recall AUC** — TODO: explain why this is often more informative
- **Precision at top-K** — TODO: explain operational relevance (review queue capacity)
- **Cost-weighted metrics** — TODO: false negatives cost much more than false positives

---

## References

<!-- Fill in: links to relevant datasets, semantic views, or internal examples -->

- Sentinel Banking dataset: `testdata/raw/sentinel_banking/` (fraud alerts, chargebacks, transactions)
- Semantic view: `snowflake-intelligence-integration/semantic_views/SENTINEL_BANKING_SEMANTIC_VIEW.yaml`
