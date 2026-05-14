# Agentic Development Collaboration Plan: MBTA Alerts UI

*Synthesized from five perspectives: Senior Gnar, Junior Gnar, Gnarstrodamus, Karl Marx, and Senior MBTA Developer.*

---

## Documentation

**1. Create `docs/SLICES.md` — the definitive Slice protocol reference**
Document the Slice protocol's callback semantics (`mount/extract/transform/validate/assigns`), execution order and invariants, what state mutations are safe in each callback, and a step-by-step walkthrough of implementing a new slice. This single document was independently called out by all five agents as the biggest gap. *(All five agents)*

**2. Document the `combination` field as a decision matrix**
Create a table showing which combinations (`:R`, `:RDS`, `:RDTS`, `:SR`, `:ACCESS`) activate which slices, what fields are required for each, and what validation rules apply per combination. The shorthands are completely opaque without this. *(Senior Gnar, Junior Gnar, Gnarstrodamus)*

**3. Expand CLAUDE.md with an "Architecture Decisions & Why" section**
Add explanations for: why two parallel alert flows exist, why the Slice protocol was chosen over a state machine, why feature flags use both Laboratory and `/feature_flags`, and what the boundary is between `db_contexts/` and `models/`. An AI agent shouldn't have to infer rationale from code archaeology. *(Karl Marx, Junior Gnar)*

**4. Add `docs/DATA_FLOW.md` tracing an alert end-to-end**
Walk through: form submission → `AlertData` → slice callbacks → `AlertBuilder` → DB persistence → Oban job → GTFS-RT protobuf → S3. Show concretely how `:R` vs `:RDTS` combinations diverge in this pipeline. *(Karl Marx, Junior Gnar)*

**5. Document the `AlertBuilder` transformation pipeline**
Add a `@moduledoc` to `alert_builder.ex` explaining the input-to-output mapping, timezone conventions (all incoming times are naive Eastern, converted to UTC), transformation sequence, and which fields are conditionally mapped. At 1,215 lines, this module is a trap for agents without a map. *(Senior Gnar, Karl Marx)*

**6. Document socket assigns and LiveView event handlers**
Create a registry of socket assigns (purpose, owner, what resets them) and a decision tree for handle_event dispatch — which events mutate form state vs. navigate, which trigger background tasks. *(Junior Gnar, Senior Gnar)*

---

## Type Safety & Contracts

**7. Add `@moduledoc` to all Slice implementations**
Each of the 11 slice files should have a 2–3 sentence docstring explaining its business purpose and which `AlertData` fields it manages. Currently most are completely undocumented. *(Junior Gnar, Karl Marx)*

**8. Add comprehensive `@spec` annotations across slice callbacks and helpers**
Cover all public functions in slice implementations, `AlertData` helpers, and form helpers — then run Dialyzer in strict mode as a CI gate. Agents make fewer type errors when they can see the contracts. *(Senior Gnar, Karl Marx, Senior MBTA)*

**9. Add doctests to feed output modules**
Each feed builder (`json_feed.ex`, `enhanced_json_feed.ex`, `protobuf_feed.ex`) should have doctest examples showing edge cases: empty active periods, nil end times, activities arrays. Doctests execute during `mix test` and catch regressions instantly. *(Senior MBTA)*

**10. Document and consolidate effect/cause/service mappings**
Unify `Effect.effects_tuples()`, `ServiceEffectCombinations`, and `ModeEffect` into a readable single source of truth — a table of Route Type → Valid Effects → Service Combinations → Special Cases. Include a reverse lookup doctest. *(Karl Marx, Senior MBTA)*

---

## Validation & Safety

**11. Create a `GTFSValidation` module with pure guard functions**
Build `AlertsUI.GTFSValidation` with functions like `valid_effect_for_route_type?/2` and `valid_informed_entity?/1` that are pure, testable, and reusable as guards throughout the pipeline. This externalizes domain correctness so agents don't need to internalize it. *(Senior MBTA)*

**12. Enforce informed entity validation at the model layer**
Move `InformedEntity` validation to an explicit `validate_at_least_one_field/1` validator with a clear error message. GTFS-RT requires at least one of route/stop/facility/trip — this constraint should be impossible to violate silently. *(Senior MBTA)*

**13. Extract shared alert validation rules into a single module**
Consolidate constraints scattered across slices and `AlertData.sync/3` (e.g., "access service requires stop IDs", "direction is optional for route-based alerts") into an inspectable `AlertValidationRules` module. *(Senior Gnar)*

**14. Add timezone conversion helpers with boundary tests**
Expose explicit `to_utc_from_eastern/1`, `from_utc_to_eastern/1`, and `service_day_boundary?/1` functions with property-based tests across DST transitions. The implicit "service day ends at 3 AM UTC" rule is a silent landmine for agents unfamiliar with MBTA scheduling conventions. *(Senior MBTA)*

---

## Testing

**15. Add happy-path integration tests for `create_alert_mono_live`**
At minimum: one test walking through mount → select route type → set effect → enter details → preview → submit, asserting alert creation with correct field values. There are no tests at all for the new mono flow. *(Senior Gnar, Junior Gnar, Gnarstrodamus)*

**16. Add property-based tests for feed output correctness**
Use `stream_data` to generate random valid alert data, run it through the full feed pipeline, and verify the GTFS-RT output has required fields, valid entity IDs, and consistent active periods. Catches the edge cases agents most commonly introduce. *(Senior MBTA, Gnarstrodamus)*

**17. Add contract tests per feed flavor**
Write separate test suites verifying the structure of standard JSON, enhanced JSON, and protobuf feeds with known input fixtures. Makes it immediately obvious when an agent breaks a specific feed variant. *(Senior MBTA)*

---

## Architecture & Observability

**18. Document slice dependencies and execution ordering**
Add comments (or a doc section) explaining why slices are ordered as they are in the `slices(socket)` function — what depends on what, what can be reordered safely. *(Gnarstrodamus)*

**19. Add structured slice execution logging**
Inject logging in `AlertData.sync/3` that captures which slice made which validation decision and why. Store as structured logs tied to the alert. Helps both humans and agents understand what happened during a failed form submission. *(Gnarstrodamus)*

**20. Document the form helpers architecture**
Add a `README.md` or `@moduledoc` in `live/form_components/helpers/` mapping the 2,500+ lines of helper modules — what each does, which helpers drive which form fields, and the dependency graph between them. *(Karl Marx)*

---

## Key Themes

Consistent findings across all five voices:

- The **Slice protocol** is the single biggest documentation gap — it's elegant but completely implicit
- **Type specs** are universally thin across the codebase
- There are **no integration tests** for the newer `create_alert_mono_live` flow
- **Domain knowledge** (GTFS, timezone conventions, combination semantics) is entirely implicit and must be inferred from code

**Highest return per effort:** Items 1–8.
