# Docker Build Files

This directory contains Dockerfiles for building and testing the SonarQube to SonarCloud migration tool.

> **Note:** Docker is optional for most platforms. GitHub Actions uses native Python builds for Windows (x86_64/ARM64), Linux x86_64, and macOS (x86_64/ARM64). Docker is only required for Linux ARM64 cross-compilation.

## Available Dockerfiles

### Dockerfile.linux-build

Builds Linux binaries (x86_64 or ARM64) using PyInstaller in a containerized environment.

**When to use:**
- Building Linux ARM64 binaries (required - used in CI)
- Optional local builds if you prefer Docker over native Python
- Building Linux binaries on non-Linux systems

**Usage (x86_64):**
```bash
# Build the builder image
docker buildx build --platform linux/amd64 -f docker/Dockerfile.linux-build -t sonar-reports-linux-builder --load .

# Extract the binary
docker run --rm -v "$(pwd)/dist:/output" sonar-reports-linux-builder cp /app/dist/sonar-reports-linux-x86_64 /output/
```

**Usage (ARM64):**
```bash
# Build the ARM64 builder image (requires QEMU)
docker buildx build --platform linux/arm64 -f docker/Dockerfile.linux-build -t sonar-reports-linux-arm-builder --load .

# Extract the binary
docker run --rm --platform linux/arm64 -v "$(pwd)/dist:/output" sonar-reports-linux-arm-builder sh -c "cp /app/dist/sonar-reports-linux-x86_64 /output/sonar-reports-linux-arm64"
```

**Output:**
- Binary: `dist/sonar-reports-linux-{x86_64,arm64}`
- Size: ~19MB
- Architecture: Linux ELF 64-bit

### Dockerfile.test-linux

Tests the Linux binary in a clean Debian environment to verify it works correctly.

**Usage:**
```bash
# Build the test image
docker build -f docker/Dockerfile.test-linux -t sonar-reports-test .

# Run a test migration
docker run --rm \
  -v "$(pwd):/app" \
  -w /app \
  --add-host=host.docker.internal:host-gateway \
  sonar-reports-test
```

**Notes:**
- Use `host.docker.internal` in your config file to access services on the host machine (like SonarQube running on localhost:9000)
- The test container includes a sample `migration-config.json` for testing

## CI/CD Usage

GitHub Actions (`.github/workflows/release.yml`) build strategy:

| Platform | Build Method | Uses Docker? |
|----------|-------------|--------------|
| Windows x86_64 | Native Python on `windows-latest` | ❌ No |
| Windows ARM64 | Native Python on `windows-latest` with `--target-arch arm64` | ❌ No |
| Linux x86_64 | Native Python on `ubuntu-latest` | ❌ No |
| **Linux ARM64** | Docker + QEMU on `ubuntu-latest` | ✅ **Yes** (required) |
| macOS x86_64 | Native Python on `macos-13` | ❌ No |
| macOS ARM64 | Native Python on `macos-latest` | ❌ No |

**Why Docker for Linux ARM64?**
- GitHub Actions doesn't provide native ARM64 Linux runners
- Docker with QEMU emulation enables cross-compilation
- All other platforms use native builds for speed and simplicity

## Development Tips

### Build Locally for Testing

```bash
# Build Linux binary
cd /path/to/sonar-reports
docker buildx build --platform linux/amd64 -f docker/Dockerfile.linux-build -t sonar-reports-linux-builder --load .
docker run --rm -v "$(pwd)/dist:/output" sonar-reports-linux-builder cp /app/dist/sonar-reports-linux-x86_64 /output/

# Test the binary
chmod +x dist/sonar-reports-linux-x86_64
./dist/sonar-reports-linux-x86_64 --help
```

### Test in Clean Environment

```bash
# Test that the binary has all dependencies bundled
docker run --rm --platform linux/amd64 \
  -v "$(pwd)/dist:/app" \
  -w /app \
  debian:stable-slim \
  /app/sonar-reports-linux-x86_64 --help
```

### Configuration for Docker

When running migrations inside Docker, your config file needs to use `host.docker.internal`:

```json
{
  "sonarqube": {
    "url": "http://host.docker.internal:9000",
    "token": "your-token"
  },
  "sonarcloud": {
    "url": "https://sonarcloud.io/",
    "token": "your-token",
    "enterprise_key": "your-enterprise-key",
    "org_key": "your-org"
  },
  "settings": {
    "export_directory": "./files",
    "concurrency": 10,
    "timeout": 60
  }
}
```

## Platform Support

All platforms are fully supported in the GitHub Actions release workflow:

- ✅ **Windows x86_64** - Native build (no Docker)
- ✅ **Windows ARM64** - Native build (no Docker)
- ✅ **Linux x86_64** - Native build (no Docker)
- ✅ **Linux ARM64** - Docker build with QEMU (Docker required)
- ✅ **macOS x86_64** (Intel) - Native build (no Docker)
- ✅ **macOS ARM64** (Apple Silicon) - Native build (no Docker)

## When to Use Docker

**Required:**
- Building Linux ARM64 binaries (GitHub Actions uses this for releases)

**Optional:**
- Local Linux x86_64 builds if you prefer Docker
- Testing binaries in clean environments
- Building Linux binaries on Windows/macOS

**Not needed:**
- Most GitHub Actions builds (use native Python)
- Local builds on Linux/macOS/Windows with Python installed

## Maintenance

When updating these Dockerfiles:

1. Test the build locally first
2. Verify the binary works in a clean container
3. Update this README if usage changes
4. Update `.github/workflows/release.yml` if needed
5. Ensure Linux ARM64 builds still work in CI
