# Plan: Fuse README_1.md, README_2.md, README_3.md into a Final README.md

## Source Analysis

### README_1.md — "The Docker-First Reference Manual"
- Strengths: Detailed phase-by-phase CLI reference, migration workflow diagram, comprehensive options tables, troubleshooting, output files reference, multi-server migration, Docker Compose, best practices, version support
- Weakness: Only covers Docker as the run method. Long and dense.

### README_2.md — "The Quick Start Guide"
- Strengths: Leads with executable binary (easiest path), multiple alternative methods (binary, Docker, Python, shell scripts), post-migration steps, security section, "What Gets Migrated" summary
- Weakness: Repetitive (shows same commands 3x for binary/Docker/Python). References docs that may not exist yet.

### README_3.md — "The Codebase-Verified Fact Sheet"
- Strengths: Verified against actual code, complete command list (10 commands), project structure, architecture details, task engine explanation, CI/CD workflows, dependency list
- Weakness: Too technical/internal for end users. No step-by-step guide.

## Design Principles for Final README.md

1. **Tech-noob friendly** — lead with the simplest path, explain jargon, keep it short
2. **Progressive disclosure** — README.md is the entry point; link to docs/ for deep dives
3. **No repetition** — show each concept once, link to details
4. **Verified accuracy** — use README_3.md as the source of truth for facts

## Final Structure

### README.md (concise, ~200 lines)
1. **Title + one-liner** — what this tool does
2. **What Gets Migrated** — quick table (from README_2)
3. **Quick Start** — fastest path using executable binary + `full-migrate` (from README_2)
4. **Alternative Run Methods** — brief list with links to docs/ (Docker, Python, shell scripts)
5. **Interactive Wizard** — brief mention + command (from README_1)
6. **Step-by-Step Manual Migration** — brief overview + link to docs/MANUAL-MIGRATION.md
7. **Troubleshooting** — top 3 issues only, link to docs/TROUBLESHOOTING.md
8. **Additional Resources** — links to all docs/

### docs/ folder (new files to create)
| File | Content Source | Purpose |
|------|---------------|---------|
| `docs/MANUAL-MIGRATION.md` | README_1 phases + README_2 manual commands | Full step-by-step for binary, Docker, and Python |
| `docs/TROUBLESHOOTING.md` | README_1 troubleshooting + README_2 troubleshooting | All error scenarios and solutions |
| `docs/DOCKER.md` | README_1 Docker deployment + README_2 Docker commands | Docker-specific usage guide |
| `docs/ARCHITECTURE.md` | README_3 project structure + task engine | Internal architecture for contributors |
| `docs/SECURITY.md` | README_2 security section | Token handling, secrets, best practices |
| `docs/BUILD.md` | Already exists — keep as-is | Build instructions |
| `docs/CONFIG.md` | Already exists — keep as-is | Config file reference |

## Execution Plan

1. Create `docs/MANUAL-MIGRATION.md`
2. Create `docs/TROUBLESHOOTING.md`
3. Create `docs/DOCKER.md`
4. Create `docs/ARCHITECTURE.md`
5. Create `docs/SECURITY.md`
6. Create final `README.md`
7. Delete `README_1.md`, `README_2.md`, `README_3.md`, `PLAN.md` (cleanup)
