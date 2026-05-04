# Versioning and Breaking-Change Policy

This document is the contract between `honeyhiveai/semantic-conventions`
and its consumers (HoneyHive SDKs, the ingestion service, evaluator
configs, saved dashboards). It defines when a tagged release is cut,
what changes are allowed against each stability tier, how deprecations
are sequenced, and how consumers pin to a registry version.

The policy is written to be enforceable by hand today and by tooling
later. OTel enforces the equivalent rules via `compatibility.rego` run
against `--baseline-registry=archive/v$VERSION.zip[model]`; we adopt
the same shape of rules without yet wiring up the Rego policy or the
baseline-archive pipeline. See *Future automation* at the end.

## Tagging cadence

- **Cut a `v0.X.Y` tag on-demand**, when stable-attribute changes
  accumulate or when a downstream consumer (SDK, ingestion, public
  docs site) needs to bump its pin.
- A standing **monthly review** (first Monday) decides whether the
  delta on `main` warrants a new tag. If nothing stable changed,
  skip the cut.
- Pre-1.0 we use `0.MINOR.PATCH`. Stable-attribute additions bump
  MINOR. Stable-attribute deprecations or removals bump MINOR.
  `release_candidate` / `development` churn bumps PATCH.
- Tag from `main`. Every tag has a matching GitHub Release whose body
  is the diff summary, generated from `weaver registry diff
  --baseline-registry=…/v$LATEST.zip[model]`.

## What may change on `stable` attributes

Only **additive** changes are allowed on a stable attribute or group:

- Adding a new attribute to a stable group.
- Adding a new optional field on an existing attribute (extra
  `examples`, longer `brief`, additional `note`, new
  `requirement_level: opt_in`).
- Adding a new enum member with `stability: development` or
  `release_candidate`.
- Tightening prose (`brief`, `note`) without changing semantics.

The following are **forbidden** on a stable attribute. Any of them is
a breaking change and must be staged through the deprecation flow
below — never landed directly:

- Renaming an attribute, group, or enum member.
- Changing an attribute's `type` (e.g., `string` → `string[]`,
  `int` → `double`).
- Changing `requirement_level` in a way that tightens the contract
  (`opt_in` → `recommended` is OK; `recommended` → `required` is
  not, because consumers may not be emitting it).
- Removing an attribute, group, or enum member.
- Changing the meaning of an attribute while preserving its name
  (semantic renames are renames).

## Deprecation flow

To remove or rename a stable attribute, sequence the change across
**two minor releases**:

1. **Minor *N* (deprecate).** Mark the attribute with the orthogonal
   `deprecated:` block per T13's vocabulary:
   ```yaml
   deprecated:
     reason: renamed
     renamed_to: honeyhive.new_name
     note: >
       Replaced by `honeyhive.new_name` in v0.N. The old name will be
       removed in v0.(N+1). Update SDK pins and dashboards.
   ```
   The attribute keeps `stability: stable` and continues to render in
   the registry; the `deprecated` block surfaces a banner in the docs
   and is read by the ingestion service to fan-in dual writes.
2. **Minor *N+1* (remove).** Move the attribute file (or entry) into
   `model/{ns}/deprecated/*-deprecated.yaml`, mirroring OTel's
   layout. The attribute is no longer emitted by SDKs and the
   ingestion service stops accepting writes under the old name.

A deprecation cannot be removed in the same minor that introduces it.
That single-version gap is the entire point — it gives consumers one
release to update their pins.

## `release_candidate` and `development` attributes

- **`development`** — anything goes. Rename, retype, restructure,
  remove, with no migration window. Consumers should not reference
  development attributes from saved dashboards, evaluator configs, or
  customer-visible docs without an explicit "may break" warning.
- **`release_candidate`** — same freedom as `development`, but
  changes are noted in the release body so SDK authors who have
  opt-in support for an RC attribute know to update. Promotion
  `release_candidate → stable` is itself an additive change and
  follows the rules in *What may change on `stable`*.

Promoting a development attribute to stable does not require a
deprecation cycle — the attribute did not have a contract to begin
with. It does require a tagged release.

## Consumer pinning

Every consumer of this registry pins to a specific tag and bumps that
pin **deliberately** as part of a tracked change:

- **HoneyHive SDKs** (`typescript-sdk`, `python-sdk`, etc.) — pin via
  the constants module emitted by their own ref-doc build, sourced
  from a tagged `honeyhiveai/semantic-conventions` release. The pin
  is updated in a PR, not by an auto-floating `^0.x` range.
- **Ingestion service** — pins via the shared `@hive-kube/semconv`
  package generated from a tagged release. Bumping the pin is part
  of the PR that absorbs the new attributes; never auto-floating.
- **Public docs site** — see HHAI-5108 for the deploy mechanism. The
  site builds against the registry source-of-truth (post-T3 the
  monorepo path; pre-T3 this repo's `main`), but published builds
  are tied to tags so users see versioned content rather than
  whatever happened to be on `main` at build time.

No consumer should depend on `main` directly in production. If you
need an unreleased attribute, cut a tag and pin to it.

## Future automation

This policy is the human-readable contract. The following automations
codify it as code, and are deferred until specific incidents prove
them worth the maintenance cost:

- **`compatibility.rego`** — port OTel's policy file. Runs on every
  PR against `weaver registry check --baseline-registry=…/v$LATEST.zip
  [model]` and fails on any forbidden change.
- **Baseline archive** — publish a `v$VERSION.zip` of `model/` per
  tagged release so the policy has something to diff against.
- **Schema-diff in release body** — run `weaver registry diff` at tag
  time and include the structured diff in the GitHub Release body.

When a real breaking-change incident slips through human review, that
is the trigger to wire up the Rego policy. Until then, the human
review against this document is the gate.

---

*Status: draft. Cross-link follow-ups (out of scope for this PR):*

- *`honeyhive-ai-docs/v2/concepts.mdx` — link "stable attributes" to
  this policy.*
- *`honeyhive-ai-docs/v2/tracing/semconv-reference.mdx` — header note
  pointing to this policy for the contract that backs the listed
  attribute names.*
- *Each SDK's ref-doc landing page (`typescript-sdk`,
  `python-sdk`) — note which registry tag the SDK is pinned to and
  link to this policy for the stability contract.*
