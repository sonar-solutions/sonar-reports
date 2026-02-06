# GitHub Actions Workflows

This directory contains automated workflows for the sonar-reports project.

## Active Workflows

### 1. `test.yml` - Pull Request Testing
**Trigger:** Pull requests to `main` branch
**Purpose:** Run automated tests using Docker Compose
**What it does:**
- Checks out the PR code
- Runs the test suite in Docker containers
- Validates code quality before merging

### 2. `build.yml` - Docker Image Publishing
**Trigger:** Push to `main` branch
**Purpose:** Build and publish the Docker image to GitHub Container Registry
**What it does:**
- Builds the Docker image from the repository
- Pushes to `ghcr.io/sonar-solutions/sonar-reports:latest`
- Requires `CR_PAT` secret for authentication

### 3. `release.yml` - Build and Release Executables
**Trigger:**
- Push to tags matching `v*` (e.g., `v1.0.0`)
- Manual workflow dispatch

**Purpose:** Build standalone executables for all supported platforms and create GitHub releases

**What it does:**
Builds 6 platform-specific executables:
1. **Windows x86_64** - Native build on Windows runners
2. **Windows ARM64** - Cross-compiled using Docker + QEMU
3. **Linux x86_64** - Native build on Ubuntu runners
4. **Linux ARM64** - Cross-compiled using Docker + QEMU
5. **macOS x86_64** - Native build on macOS 15 (Intel)
6. **macOS ARM64** - Native build on macOS latest (Apple Silicon)

Each build:
- Compiles a standalone executable using PyInstaller
- Tests the executable with `--help`
- Generates SHA256 checksum
- Uploads artifacts

Finally:
- Collects all 6 executables + checksums
- Generates release notes with download instructions
- Creates a GitHub Release with all assets

## How to Create a Release

### Method 1: Tag-based Release (Recommended)
```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

### Method 2: Manual Workflow Dispatch
1. Go to Actions tab on GitHub
2. Select "Build and Release Executables"
3. Click "Run workflow"
4. Optionally specify a version tag (e.g., `v1.0.0`)
5. Click "Run workflow"

## Build Architecture

### Native Builds (Fast, Reliable)
- **Windows x86_64**: `windows-latest` runner
- **Linux x86_64**: `ubuntu-latest` runner
- **macOS x86_64**: `macos-15` runner (Intel)
- **macOS ARM64**: `macos-latest` runner (M1/M2)

### Cross-Platform Builds (Slower, using QEMU emulation)
- **Linux ARM64**: Docker with `--platform linux/arm64`
- **Windows ARM64**: Docker with `--platform linux/arm64` + PyInstaller

## Notes

- ARM64 cross-compilation uses QEMU emulation and may take longer
- All builds include SHA256 checksums for verification
- The Windows ARM64 build creates a Linux-ARM64 executable with `.exe` extension (experimental)
- macOS 15 runners are used for Intel builds (macOS 13 is retired)

## Troubleshooting

### Build failures
- Check that all dependencies in `requirements.txt` are compatible with the target platform
- For ARM64 builds, QEMU emulation can be slow or unstable
- Ensure `sonar-reports.spec` is properly configured

### Release not created
- Ensure you have proper permissions set in the workflow (see `permissions: contents: write`)
- Check that `GITHUB_TOKEN` has access to create releases
- Verify tag format matches `v*` pattern

### Missing executables
- Check individual build job logs in GitHub Actions
- Verify artifacts were uploaded successfully
- Ensure all 6 build jobs completed before release job runs
