# Demand Forecasting with Kumo

> **PLACEHOLDER** — This document is a structural scaffold. Sections contain
> guiding questions and expected content outlines, not verified guidance.
> Fill in with real data, validated PQL examples, and tested recommendations
> before relying on this in production.

> Read this when: the prediction task involves forecasting demand, sales
> volume, inventory needs, revenue projections, or any time-series quantity
> over future periods.

---

## Typical Prediction Tasks

<!-- Fill in: common forecasting PQL queries with concrete examples -->

| Business Question | PQL Pattern | Notes |
|---|---|---|
| How many units will sell next week? | `PREDICT SUM(orders.quantity, 0, 7, days) FOR EACH products.product_id` | TODO: validate |
| What revenue per store next month? | `PREDICT SUM(sales.amount, 0, 30, days) FOR EACH stores.store_id` | TODO: validate |
| Will this SKU stock out in 14 days? | `PREDICT SUM(orders.quantity, 0, 14, days) > ? FOR EACH products.product_id` | TODO: threshold = current stock level |
| Multi-period forecast (weekly buckets) | Multiple queries with `(0,7)`, `(7,14)`, `(14,21)`, `(21,28)` windows | TODO: validate consecutive windows |

---

## Data Characteristics

<!-- Fill in: what makes forecasting data different -->

- **Seasonality** — weekly, monthly, and annual cycles affect demand.
  Impact on time windows: TODO
- **External drivers** — promotions, holidays, weather, economic conditions.
  Impact on features: TODO
- **Intermittent demand** — many SKUs have sparse sales (zero-inflated).
  Impact on aggregation choice: TODO
- **Hierarchy** — demand can be predicted at SKU, category, store, or region level.
  Impact on entity grain: TODO
- **Censored demand** — stockouts mean observed sales undercount true demand.
  Impact on labels: TODO

---

## Time Window Guidance

<!-- Fill in: typical forecasting horizons by use case -->

| Sub-task | Suggested Window | Rationale |
|----------|------------------|-----------|
| Daily replenishment | TODO | TODO |
| Weekly planning | TODO | TODO |
| Monthly budgeting | TODO | TODO |
| Quarterly forecasting | TODO | TODO |
| Multi-period rolling forecast | TODO | TODO |

**Consecutive-window pattern** for multi-step forecasts:

```
PREDICT SUM(sales.amount, 0, 7, days) FOR EACH stores.store_id
PREDICT SUM(sales.amount, 7, 14, days) FOR EACH stores.store_id
PREDICT SUM(sales.amount, 14, 21, days) FOR EACH stores.store_id
PREDICT SUM(sales.amount, 21, 28, days) FOR EACH stores.store_id
```

<!-- TODO: document how to stitch these together, anchor_time considerations -->

---

## Graph Construction Tips

<!-- Fill in: which tables matter for forecasting, common pitfalls -->

**Tables that typically add signal:**
- TODO (e.g., historical sales/orders, product attributes, store/location metadata)

**Tables to be cautious with:**
- TODO (e.g., promotional calendars — powerful but can leak if not time-aligned)

**Entity grain considerations:**
- TODO (e.g., product-level vs. product-store-level vs. category-level)

---

## Common Mistakes

<!-- Fill in: forecasting-specific mistakes -->

| Mistake | Why It Happens | Fix |
|---------|----------------|-----|
| Ignoring stockout periods | Zero sales during stockouts treated as zero demand | TODO |
| Predicting too far ahead with short history | 90-day forecast with 60 days of data | TODO |
| Wrong aggregation for intermittent demand | SUM on a sparse SKU produces mostly-zero labels | TODO |
| Ignoring seasonality in anchor_time | Evaluation anchored at a seasonal peak/trough | TODO |
| Mixing historical and future features | Promotional flags for future periods included in training | TODO |

---

## Evaluation Guidance

<!-- Fill in: which metrics matter for forecasting -->

- **RMSE** — TODO: standard but penalizes large errors heavily
- **MAE** — TODO: more robust to outliers
- **MAPE** — TODO: percentage-based, but undefined at zero
- **R²** — TODO: useful for relative comparison
- **Bias** — TODO: systematic over/under-prediction matters for inventory decisions
- **Forecast value added (FVA)** — TODO: compare against naive baselines (last week, same week last year)

---

## References

<!-- Fill in: links to relevant datasets, semantic views, or internal examples -->

- Global Supply Network dataset: `testdata/raw/global_supply_network/` (inventory, shipments, warehouses)
- Apex Manufacturing dataset: `testdata/raw/apex_manufacturing/` (production runs, quality inspections)
- Semantic views: `snowflake-intelligence-integration/semantic_views/GLOBAL_SUPPLY_NETWORK_SEMANTIC_VIEW.yaml`
