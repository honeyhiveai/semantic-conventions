# HoneyHive Semantic Conventions

Canonical attribute schema for HoneyHive's AI observability platform.

**Live site:** https://honeyhiveai.github.io/semantic-conventions/

## Contributing
Edit YAML in `model/`, then run `make fix` (requires Docker for weaver). The generated docs commit alongside your YAML edit.

## Layout
- `model/` — source-of-truth YAML attribute definitions
- `templates/registry/markdown/` — weaver Jinja templates
- `docs-src/` — VitePress source: hand-written narrative + generated registry pages
- `docs/` — VitePress build output (committed; GitHub Pages serves this)
- `Makefile` — generation entrypoints (`make fix`, `make check`)

## Stack
weaver YAML → markdown (via `templates/registry/markdown/`) → VitePress build → GitHub Pages legacy `/docs`. Modeled on the OpenTelemetry semantic-conventions repo + the honeyhive-cli ref-docs pattern.
