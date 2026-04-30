# HHAI-5103 — Weaver tooling spike

This document captures the three decisions HHAI-5103 was scoped to make:
the **package layout** for `honeyhiveai/semantic-conventions`, the
**publish target** for the public site, and the **pinned weaver
version** the repo runs against. Downstream tickets (HHAI-5104,
HHAI-5105, HHAI-5106, HHAI-5108, HHAI-5109) inherit these decisions;
reopen this file before changing any of them.

Parent plan: HHAI-5102 — *Publish HoneyHive semantic conventions via
weaver*.

> **Pivot note (post-spike):** the original layout decision placed
> `semconv/` at the root of the `hive-kube` monorepo. After the
> first-pass scaffold was reviewed, Dhruv decided to move the work to
> a standalone repo (`honeyhiveai/semantic-conventions`) so the
> registry has its own commit history, its own visibility setting, and
> a direct path from `git push` to GitHub Pages without any cross-repo
> sync workflow. Section 2 below records the new layout; Section 3
> records the simplified publish pipeline that drops out of the pivot.

---

## 1. Pinned weaver version + install path

**Pinned: `v0.23.0`** (released 2026-04-22, latest as of HHAI-5103).

Pinned in [`install.sh`](install.sh) via `WEAVER_VERSION=v0.23.0`.
Override the env var if you need to bump the pin locally; CI (HHAI-5104)
will respect the same variable.

**Install path:** prebuilt binary download from
[`open-telemetry/weaver` releases](https://github.com/open-telemetry/weaver/releases/tag/v0.23.0),
SHA-256 checksum verified, extracted to `bin/weaver`.

Rationale for prebuilt binary over `cargo install`:

- No Rust toolchain on developer laptops or CI runners. `cargo install`
  on a clean macOS box pulls down rustup + a multi-minute build.
- Reproducibility — the SHA-256 file published alongside each release
  asset gives us a content-addressed pin. `cargo install` resolves
  against crates.io and is not byte-identical run to run.
- The aarch64-apple-darwin asset works on Apple Silicon out of the box
  (validated locally on Dhruv's M-series laptop, weaver-v0.23.0,
  `weaver --version` reports `weaver 0.23.0`).

**Reproducibility notes:**

- `bin/` is gitignored. `install.sh` is the only path to a working
  binary; it is idempotent — re-runs no-op when the pinned version is
  already present.
- The installer detects platform via `uname -s`/`uname -m` and selects
  among Darwin arm64/x86_64 and Linux x86_64/aarch64. Other platforms
  fail loudly with a pointer to the releases page.
- `dist/` is gitignored. Generated artifacts are produced on every
  push by the GitHub Pages build workflow (HHAI-5108), not committed
  to source.

---

## 2. Package layout decision

```
honeyhiveai/semantic-conventions/
├── install.sh                          # pinned weaver installer
├── Makefile                            # check / build / serve / update-docs / stats / clean
├── README.md                           # engineer quickstart
├── SPIKE.md                            # this file
├── .gitignore                          # bin/, dist/
├── model/
│   ├── manifest.yaml                   # registry name + schema_url
│   └── honeyhive_session.yaml          # one file per logical bucket
└── templates/
    └── markdown/                       # vendored from OTel semconv v1.36.0
        ├── weaver.yaml
        ├── snippet.md.j2               # used by `weaver registry update-markdown`
        ├── attribute_namespace.md.j2   # one page per namespace
        ├── attributes_readme.md.j2     # namespace index page
        ├── attribute_table.j2          # table macro
        ├── attribute_macros.j2
        ├── enum_macros.j2 / stability.j2 / requirement.j2 / …
        └── (full set, 22 files)
```

### Why this structure

**Standalone repo, files at the root.** This repo *is* the semconv
project — there is no parent application code, no shared workspace, no
`packages/` to share with. Putting files at the root removes one level
of path from every command and lets GitHub Pages publish directly from
the build output without `peter-evans/create-pull-request` round-trips
to a sibling project.

**`model/` directory holds the registry, with `manifest.yaml` at its
root.** Weaver v0.23.0 emits
`ℹ Found registry manifest: model/manifest.yaml` on every run; the file
name is part of the weaver contract. The HHAI-5103 task brief said
`registry_manifest.yaml (or equivalent — follow weaver conventions)`,
so we use the canonical name.

**File-per-bucket, NOT file-per-stability tier.** `honeyhive_session.yaml`
covers the session-related attributes regardless of whether they are
stable or development. Splitting by tier would mean an attribute
graduating from development to stable migrates files — git blame would
say "moved" instead of "stability changed". File-per-bucket also keeps
each YAML ≤ ~100 attributes long for a typical bucket, well within
review-friendly sizes.

**`templates/markdown/` is vendored verbatim from
[open-telemetry/semantic-conventions@v1.36.0](https://github.com/open-telemetry/semantic-conventions/tree/v1.36.0/templates/registry/markdown).**
This is the same template set that drives
[opentelemetry.io/docs/specs/semconv/](https://opentelemetry.io/docs/specs/semconv/),
so `make build` produces output structurally identical to upstream
(stability badges, namespace pages, anchor links, enum tables). HHAI-5106
will fork only the templates we need to diverge on; the rest stay tracking
upstream so we get template improvements for free. Keeping `templates/`
separate from `model/` prevents `weaver registry check` from accidentally
parsing template metadata as model files.

**The pipeline is two-step, matching what OTel uses for its own site.**
Both modes share `templates/markdown/` and the registry:

1. `weaver registry generate markdown dist/` (wired into `make build`)
   — renders the full attribute reference: one page per namespace under
   `dist/attributes/`, plus a `dist/README.md` index. This is the
   auto-generated half of a semconv docs site.
2. `weaver registry update-markdown --target markdown docs/` (wired
   into `make update-docs`) — walks hand-authored markdown for
   `<!-- semconv <group_id> -->` markers and regenerates the marked
   regions in-place via `templates/markdown/snippet.md.j2`. This is
   how OTel keeps narrative pages (e.g. its AWS SDK spans page) in
   sync with the registry while preserving editorial prose around
   the auto-generated tables.

`make build` is what CI (HHAI-5104) and the Pages-deploy workflow
(HHAI-5108) actually run. `make update-docs` is the editor's local
loop for HHAI-5106 — it runs against curated docs as the public-site
templates evolve.

**`.gitignore` covers `bin/` and `dist/`.** The binary is per-machine;
the rendered artifacts are produced fresh by the deploy workflow, not
committed.

### Open questions for downstream tickets

These were deliberately deferred — they don't block the spike but the
next worker on each ticket must pick a position before merging:

| Question | Owner | Notes |
|---|---|---|
| Attribute group naming convention (`registry.honeyhive.<bucket>` vs `honeyhive.<bucket>`) | HHAI-5105 | Spike uses `registry.honeyhive.session`, mirroring the otel-canonical `registry.cloud` pattern. |
| File granularity once the attribute count grows (file-per-bucket vs file-per-bucket-and-tier) | HHAI-5105 | Defaults to file-per-bucket. Revisit only if a bucket file crosses ~150 attributes. |
| Template divergence from upstream OTel | HHAI-5106 | Vendored verbatim today; fork only when we need branding/structural changes. Track upstream version pin in `templates/markdown/.upstream-version` (proposal — not yet added). |
| SDK code generation from the registry | HHAI-5102 follow-up | Out of scope for the published-docs golden path. |
| `semconv.honeyhive.ai` custom domain | HHAI-5108 follow-up | Default GitHub Pages URL is fine for v1; CNAME is a one-step flip later. |
| Stability-tier policy enforcement (Rego policy that blocks demoting `stable` → `development` without a major bump) | HHAI-5107 | Weaver supports `--policy <rego>`; not wired in this spike. |
| **Internal-vs-Public repo visibility for GitHub Pages** | HHAI-5108 | Repo is currently **Internal**. GitHub Pages on Internal repos requires GitHub Enterprise Cloud; on a Free/Team org Pages publishes only from Public repos. HHAI-5108 must verify the org's plan and either flip the repo to Public at launch or document the Enterprise dependency. |

---

## 3. Publish target decision

**Decision: this repo (`honeyhiveai/semantic-conventions`) IS the public
site. GitHub Pages deploys from `main` on every push via a single-job
workflow. No cross-repo sync, no Propolis token, no
`peter-evans/create-pull-request`.**

### What this replaces

The original spike proposed mirroring the
`release-sync-python-sdk-to-public.yaml` pattern: hive-kube emits
artifacts, a workflow rsyncs them into a sibling public repo, and a
PR is opened for human approval before publication. That made sense
when the registry source lived inside `hive-kube` and the public repo
held only rendered output.

After the pivot, the registry source and the rendered output live in
the same repo, so the cross-repo machinery is unnecessary. Drop it.

### Workflow shape (HHAI-5108 owns the implementation)

A single GitHub Actions workflow on push to `main`:

1. Trigger: `on: { push: { branches: [main] } }` (plus `workflow_dispatch`
   for manual re-runs).
2. Run `bash install.sh && make check && make build`.
3. Upload `dist/` to GitHub Pages via `actions/upload-pages-artifact@v3`
   + `actions/deploy-pages@v4`.
4. Concurrency group `pages` (one deploy at a time; latest commit wins).

Branch protection on `main` is the human gate: no direct pushes; all
changes land via PR with review (per `feedback_prs_only` and
`feedback_never_automerge_public_prs`). The deploy workflow only fires
*after* a PR has been merged, so the human approval is upstream of any
publication. Auto-merge is disabled at the repo level.

### Backward-compat constraints respected

- No reuse of any existing hive-kube workflow files. The deploy
  workflow lives in this repo only — there is nothing for in-flight
  hive-kube PRs to collide with.
- `make check` is callable from CI without weaver pre-installed
  (HHAI-5104's CI workflow runs `bash install.sh && make check`). No
  global state, no external services touched.

### Why not stay inside hive-kube

`hive-kube` is private and contains application code, infra, and
release machinery the public has no business seeing. Even publishing
only the rendered output cleanly would require either:
(a) a sibling public repo with a sync workflow (the original plan), or
(b) Pages on a private repo (Enterprise-only, paid seat per viewer).

A standalone repo is structurally simpler than (a) and avoids (b)
entirely once the repo flips to Public. It also gives the registry
its own license boundary, its own issue tracker, and a clean URL
(`https://honeyhiveai.github.io/semantic-conventions/`) that
Mintlify's "Semantic Conventions" link (HHAI-5109, Phase 4 of the
golden path) can target.

---

## Surprises encountered

- **Weaver v0.23.0 expects `manifest.yaml`, not `registry_manifest.yaml`.**
  The task brief had a parenthetical "or equivalent — follow weaver
  conventions" so we tracked the canonical name. Note for the supervisor:
  do not rename the file in downstream tickets.
- **The default `--registry` is the public OTel registry, not the local
  directory.** Every `weaver registry <subcommand>` call needs an
  explicit `--registry model` flag. The Makefile centralises this.
- **`--future` flag on `weaver registry check` is recommended for new
  registries.** It enables the strictest validation rules. The Makefile
  passes it; CI should pass it too.
- **OTel runs weaver in two modes, not one.** First-pass spike used a
  hand-rolled trivial template through `weaver registry generate`,
  which works but is not how the official OTel site is built. The
  upstream `templates/registry/markdown/` set is the canonical
  renderer and is shared between `registry generate` (full reference)
  and `registry update-markdown` (snippet injection into curated docs).
  Vendored that set verbatim from v1.36.0; both `make build` and
  `make update-docs` now use it.
- **`dist/README.md` links to `entities/README.md` even though we don't
  emit entities yet.** The vendored `registry_readme.md.j2` hardcodes
  both attribute and entity sections. Cosmetic only — `make check`
  still passes. HHAI-5106 should either add a stub entity, patch the
  template, or strip the section before publishing.
- **GitHub Pages + Internal repo visibility tradeoff.** This repo was
  initialised as Internal. GitHub Pages on Internal repos is
  Enterprise-only; on Free/Team orgs Pages serves only from Public
  repos. HHAI-5108 must either flip the repo to Public at launch (most
  likely path — the registry is meant to be a public reference) or
  budget for the Enterprise tier. Logged as an open question on the
  table above.

No blockers found. M-series compatibility is clean — `aarch64-apple-darwin`
prebuilt runs without `xattr -d` or `codesign --force` workarounds.

---

## Verification log

Run from the repo root:

```sh
$ bash install.sh
downloading weaver-aarch64-apple-darwin.tar.xz (v0.23.0)...
installed weaver v0.23.0 at ./bin/weaver

$ make check
./bin/weaver registry check --registry model --future
✔ No `after_resolution` policy violation
Total execution time: 0.030s

$ make build
✔ Generated file "dist/README.md"
✔ Generated file "dist/attributes/README.md"
✔ Generated file "dist/attributes/honeyhive.md"
✔ Artifacts generated successfully

$ make stats
Total number of attributes: 5
Stability breakdown (100%):
  - stable: 5

$ make serve
serving dist/ on http://localhost:8765/
```

All commands exit 0. `dist/attributes/honeyhive.md` renders the 5
attributes with stability badges, anchor links, examples, and an
enum-values table for `honeyhive.event_type` — the same output shape
as opentelemetry.io's own attribute reference.
