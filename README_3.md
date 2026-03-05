# SonarQube to SonarCloud Migration Tool — Codebase-Verified Reference

This document captures verified facts about the `sonar-reports` project based on direct codebase analysis.

## Project Overview

A Python CLI tool (built with [Click](https://click.palletsprojects.com/)) for migrating SonarQube Server configurations to SonarQube Cloud. It can be run as a standalone executable (built via PyInstaller), a Docker container, or directly with Python.

## 10 CLI Commands

| Command | Description |
|---------|-------------|
| `extract` | Pull configuration data from a SonarQube Server instance via its REST API. Stores results as NDJSON files. |
| `structure` | Group projects into organizations based on DevOps platform bindings and server URLs. Outputs `organizations.csv` and `projects.csv`. |
| `mappings` | Generate mapping CSVs for quality gates, quality profiles, groups, permission templates, and portfolios. |
| `migrate` | Push mapped configurations to SonarQube Cloud. Executes tasks in dependency order. |
| `full_migrate` | End-to-end migration from a single JSON config file (extract → structure → org mapping → mappings → migrate). |
| `wizard` | Interactive guided migration — walks you through all phases with prompts and resume support. |
| `pipelines` | Update CI/CD pipeline files to use SonarQube Cloud (supports GitHub, GitLab, Azure DevOps, Bitbucket). |
| `report` | Generate markdown reports from extracted data (`migration` or `maturity` type). |
| `analysis_report` | Parse a migration run's `requests.log` into a CSV summary of API calls. |
| `reset` | Reset a SonarQube Cloud enterprise to original state. **Destructive — deletes everything.** |

## Run Methods (4 Ways)

1. **Standalone executable** — download a pre-built binary from the Releases page (no dependencies needed)
2. **Docker** — `ghcr.io/sonar-solutions/sonar-reports:latest` (no local Python needed)
3. **Python** — `pip install -r requirements.txt && python src/main.py <command>`
4. **Shell script wrappers** — `scripts/execute_full_migration.sh` (Docker) or `scripts/execute_migration_with_binary.sh` (binary)

## Supported Platforms (Executables)

| Platform | Architecture | Binary Name |
|----------|-------------|-------------|
| macOS | Apple Silicon (M1–M4) | `sonar-reports-macos-arm64` |
| macOS | Intel | `sonar-reports-macos-x86_64` |
| Linux | x86_64 | `sonar-reports-linux-x86_64` |
| Linux | ARM64 | `sonar-reports-linux-arm64` |
| Windows | x86_64 | `sonar-reports-windows-x86_64.exe` |
| Windows | ARM64 | `sonar-reports-windows-arm64.exe` |

## Project Structure

```
sonar-reports/
├── src/
│   ├── main.py                # CLI entry point (Click commands)
│   ├── config.py              # JSON config file loader
│   ├── plan.py                # Task plan generation (DAG)
│   ├── execute.py             # Task execution engine
│   ├── dependencies.py        # Dependency loading strategies
│   ├── constants.py           # Built-in repos, task lists
│   ├── validate.py            # Pre-migration validation
│   ├── utils.py               # CSV/JSON utilities
│   ├── parser.py              # Field/value parsing
│   ├── analysis_report.py     # Migration analysis report
│   ├── operations/            # Data transformation operations
│   ├── structure/             # Org/project structure mapping
│   ├── wizard/                # Interactive wizard
│   ├── pipelines/             # CI/CD pipeline updater
│   ├── report/                # Report generators
│   └── tasks/                 # JSON task definitions
│       ├── export/            # 72+ extraction tasks
│       ├── migrate/           # 46+ migration tasks
│       └── delete/            # Cleanup/reset tasks
├── scripts/
│   ├── build.sh               # macOS/Linux build
│   ├── build.bat              # Windows build
│   ├── execute_full_migration.sh
│   └── execute_migration_with_binary.sh
├── docker/
│   ├── Dockerfile.linux-build # Linux binary builder
│   └── Dockerfile.test-linux  # Linux binary tester
├── docs/
│   ├── BUILD.md               # Build instructions
│   └── CONFIG.md              # Config file reference
├── examples/
│   ├── migration-config.example.json
│   ├── config.example.json
│   ├── config-extract.example.json
│   └── config-migrate.example.json
├── tests/                     # pytest suite
├── Dockerfile                 # Production Docker image (Python 3.14-slim)
├── test.Dockerfile            # Test Docker image
├── docker-compose.yaml
├── requirements.txt           # 8 runtime dependencies
├── requirements-dev.txt       # Dev/test dependencies
├── sonar-reports.spec         # PyInstaller spec
└── sonar-project.properties   # SonarQube analysis config
```

## Runtime Dependencies

| Package | Purpose |
|---------|---------|
| httpx | HTTP client for API calls |
| click | CLI framework |
| markdown | Markdown processing |
| tenacity | Retry logic |
| PyNaCl | Cryptography (for DevOps platform secrets) |
| ruamel.yaml | YAML parsing (pipeline files) |
| bashlex | Bash parsing (pipeline scripts) |
| lxml | XML processing (Maven/Gradle files) |

## Task Engine Architecture

Tasks are defined as JSON files in `src/tasks/` organized by SonarQube version (e.g., `4.3.json`, `10.4.json`, `cloud.json`). Each task specifies:

- **dependencies** — prerequisite tasks with loading strategies (`each`, `chunk`, `all`, `map`, `none`)
- **editions** — which SonarQube editions support this task
- **operations** — ordered pipeline of data transformations (`http_request`, `apply_filter`, `set_key`, etc.)

The engine builds a DAG, resolves dependencies, plans execution phases, and runs tasks with configurable concurrency.

## Configuration File Format

```json
{
  "sonarqube": {
    "url": "https://your-sonarqube-server.com",
    "token": "YOUR_SQS_ADMIN_TOKEN"
  },
  "sonarcloud": {
    "url": "https://sonarcloud.io/",
    "token": "YOUR_SQC_TOKEN",
    "enterprise_key": "your-enterprise",
    "org_key": "your-org-key"
  },
  "settings": {
    "export_directory": "./files",
    "concurrency": 10,
    "timeout": 60,
    "skip_profiles": false
  }
}
```

## Migration Data Flow

```
SonarQube Server → extract → NDJSON files
    → structure → organizations.csv + projects.csv
    → (user edits organizations.csv with cloud org keys)
    → mappings → gates.csv, profiles.csv, groups.csv, templates.csv, portfolios.csv
    → migrate → SonarQube Cloud
    → pipelines (optional) → Updated CI/CD files with PRs
```

## What Gets Migrated

- Quality Gates (with conditions, defaults)
- Quality Profiles (backup/restore with rules, inheritance, defaults)
- Groups (with descriptions, permissions)
- Permission Templates (with user/group assignments)
- Projects (creation/linking, gate/profile assignment, tags)
- Portfolios (structure, project assignments)

## What Does NOT Get Migrated

- Historical analysis data
- Issues and their history
- Code coverage history
- Security hotspots
- Source code (must re-scan)

## Key Features

- **Resumable** — both extract and migrate track progress and can resume via `--extract_id` / `--run_id`
- **Concurrent** — configurable concurrency for API requests (default: 25)
- **Multi-server** — extract from multiple SonarQube instances, aggregate in one migration
- **Version-aware** — auto-detects SonarQube version, uses appropriate API endpoints (6.3+)
- **Edition-aware** — handles Community, Developer, Enterprise, Data Center editions
- **Client certificate support** — mTLS via PEM/key file options
- **Interactive wizard** — guided migration with state persistence
- **CI/CD integration** — auto-updates pipeline files and creates PRs

## CI/CD (GitHub Actions)

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `test.yml` | Push to main, PRs | Run pytest + SonarQube scan |
| `build.yml` | Manual dispatch | Build & push Docker image to GHCR |
| `release.yml` | Tag push (`v*`) or manual | Build 6 platform executables + create GitHub Release |

## Version Support

- SonarQube Server 6.3+
- Authentication: Basic (< v10) or Bearer token (>= v10)
- SonarQube Cloud editions: Enterprise, Teams
