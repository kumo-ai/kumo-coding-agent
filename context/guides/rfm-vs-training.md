# RFM Zero-Shot vs. Enterprise SDK Training

> Source: Authored from first principles + Kumo platform knowledge | Last synced: 2026-03-30

## Overview

Read this document when you need to decide between two paths:
- **RFM (zero-shot)**: Instant predictions using a pre-trained relational foundation model. No training step.
- **Enterprise SDK (training)**: Train a GNN model on the user's specific data. Higher accuracy ceiling, higher cost.

---

## Decision Framework

```
Is the user exploring or prototyping?
├── YES → Start with RFM
│         (fast iteration, zero training cost, validate the task definition first)
│
└── NO → Is accuracy critical for production?
    ├── NO → RFM may be sufficient
    └── YES → Does the user have:
        ├── Enough data? (>10K rows in entity table, >100K events)
        │   ├── NO → Stick with RFM (training won't help with tiny data)
        │   └── YES → Has Kumo API access + compute budget?
        │       ├── NO → Stick with RFM
        │       └── YES → Train with Enterprise SDK
        └── Time to wait for training? (hours to days)
            ├── NO → Use RFM for now, train in background
            └── YES → Train with Enterprise SDK
```

---

## Comparison

| Dimension | RFM Zero-Shot | Enterprise SDK Training |
|-----------|---------------|------------------------|
| **Setup time** | Minutes | Hours (first run), faster with templates |
| **Prediction latency** | Seconds to minutes | Minutes (batch), ms (online endpoint) |
| **Accuracy** | Good baseline (~0.6–0.75 AUC typical) | Higher ceiling (~0.75–0.95 AUC with good data) |
| **Data requirement** | Works with small datasets | Needs sufficient history (>10K entity rows, >100K events) |
| **Iteration speed** | Instant — change query, re-predict | Slow — retrain per change (hours) |
| **Cost** | Low (API call) | Higher (compute for training + prediction) |
| **Customization** | Limited to PQL query + graph structure | Full control: hyperparameters, encoders, sampling |
| **Explainability** | Feature importance via `ExplainConfig` | Holdout analysis, training curves, embeddings |
| **Online serving** | Not available | Deploy as real-time endpoint |
| **Python package** | `kumoai.experimental.rfm` | `kumoai` (full SDK) |

---

## When to Use RFM

- **Prototyping**: Validate the task definition before investing in training
- **Quick answers**: User needs predictions today, not next week
- **Small data**: < 10K entities or < 100K events — training won't have enough signal
- **Many tasks**: Exploring multiple prediction targets to find what's valuable
- **Demo/POC**: Showing stakeholders what's possible before committing resources
- **Counterfactuals**: Quick what-if analysis using ASSUMING clause

**RFM is NOT enough when:**
- Zero-shot AUC is < 0.6 and the task should be predictable
- The user needs > 0.85 AUC for production deployment
- Online serving (real-time endpoint) is required
- Custom feature engineering or text encoding is needed

## When to Use Enterprise SDK Training

- **Production models**: Accuracy matters and you have compute budget
- **Sufficient data**: > 10K entities, > 100K events, > 6 months of history
- **Custom requirements**: Specific encoders, sampling strategies, or architectures
- **Online serving**: Need real-time predictions via API endpoint
- **Embeddings**: Need learned entity embeddings for downstream tasks

**Training is NOT worth it when:**
- Data is too small (training will overfit)
- The task is exploratory and may change tomorrow
- RFM already gives good results (> 0.75 AUC)
- Time-to-insight is more important than accuracy

---

## The Recommended Path: Start RFM, Graduate to Training

For most tasks, the best approach is:

1. **Start with RFM** — validate the task definition, graph structure, and
   baseline signal in minutes
2. **Evaluate** — if AUC > 0.7 and user is satisfied, stop. RFM is enough.
3. **If weak** — check if the issue is task definition or data quality (see
   `skills/iterate-model.md`). Fix those first, still using RFM.
4. **Graduate to training** only after confirming:
   - The task is well-defined (RFM gives signal, just not enough)
   - Data quality is good (explored and validated)
   - The user is willing to wait for training
   - There's a clear accuracy target that RFM can't meet

This avoids the common mistake of spending hours training a model on a
poorly-defined task.

---

## Cost and Time Estimates

| Operation | RFM | Enterprise SDK |
|-----------|-----|----------------|
| Graph construction | 1–5 minutes | 5–15 minutes |
| Prediction (10K entities) | 1–5 minutes | N/A (need training first) |
| Training table generation | N/A | 10–60 minutes |
| Model training (FAST) | N/A | 30 min–2 hours |
| Model training (BEST) | N/A | 2–8 hours |
| Batch prediction | N/A | 10–60 minutes |
| Total time to first prediction | **5–15 minutes** | **1–10 hours** |

---

## Quick Reference

| User Says | Recommendation | Reasoning |
|-----------|---------------|-----------|
| "Just see if this is predictable" | RFM | Exploration — don't invest in training yet |
| "I need this in production next week" | Enterprise SDK | Production needs trained model |
| "I have 500 rows of data" | RFM | Too small for training |
| "Our current model gets 0.7 AUC, can we do better?" | Enterprise SDK | Incremental improvement needs custom training |
| "Run predictions for all 1M customers" | Either | RFM for speed, training for accuracy |
| "I need real-time predictions" | Enterprise SDK | Online serving requires trained model |
| "Which of these 5 tasks is most promising?" | RFM for all 5 | Screen tasks quickly before committing |

---

## Common Pitfalls

1. **Training on a bad task definition** — If the business question is vague
   or the target is wrong, training will just overfit to noise. Always validate
   with RFM first.
2. **Training with too little data** — Under ~10K entities, the model will
   overfit. RFM handles small data better because it doesn't train on your data.
3. **Over-investing in accuracy** — If the user's action threshold is "churn
   probability > 0.5" and RFM gives 0.68 AUC, that's probably good enough.
   Training to get 0.75 AUC may not change any business decisions.
4. **Ignoring data quality** — Training amplifies data problems. Bad data +
   training = confidently wrong predictions. Clean data + RFM > dirty data + training.
