# Building Executables

This document explains how to build standalone executables for the sonar-reports tool.

## Supported Platforms

The tool can be built for the following platforms:

- **Windows**
  - x86_64 (Intel/AMD 64-bit)
  - ARM64

- **Linux**
  - x86_64 (Intel/AMD 64-bit)
  - ARM64 (aarch64)

- **macOS**
  - x86_64 (Intel)
  - ARM64 (Apple Silicon)

## Automated Builds (GitHub Actions)

The easiest way to get executables is through automated builds:

1. Push a tag to trigger a release build:
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

2. GitHub Actions will automatically build executables for all platforms

3. Download the executables from the GitHub Releases page

Alternatively, you can manually trigger a build from the Actions tab in GitHub.

## Local Builds

### Prerequisites

- Python 3.11 or higher
- pip package manager

### Building on Unix-like Systems (Linux, macOS)

```bash
# Run the build script
./scripts/build.sh
```

The script will:
1. Install all required dependencies
2. Detect your OS and architecture
3. Build the executable using PyInstaller
4. Place the binary in the `dist/` directory

The output binary will be named according to your platform:
- macOS ARM64: `sonar-reports-macos-arm64`
- macOS Intel: `sonar-reports-macos-x86_64`
- Linux ARM64: `sonar-reports-linux-arm64`
- Linux x86_64: `sonar-reports-linux-x86_64`

### Building on Windows

```cmd
# Run the build script
scripts\build.bat
```

The script will:
1. Install all required dependencies
2. Detect your architecture
3. Build the executable using PyInstaller
4. Place the binary in the `dist\` directory

The output binary will be named according to your platform:
- Windows x86_64: `sonar-reports-windows-x86_64.exe`
- Windows ARM64: `sonar-reports-windows-arm64.exe`

## Manual Build

If you prefer to build manually:

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   pip install -r requirements-dev.txt
   ```

2. Build with PyInstaller:
   ```bash
   pyinstaller sonar-reports.spec
   ```

3. The executable will be in the `dist/` directory

### Cross-compilation Notes

- **Windows ARM64**: Can be built on x86_64 Windows using `pyinstaller --target-arch arm64`
- **macOS Universal**: Can be built on macOS using `pyinstaller --target-arch universal2`
- **Linux ARM64**: Requires ARM64 Linux or QEMU user-mode emulation

## Using the Executable

Once built, you can use the executable just like the Python script:

```bash
# Extract from SonarQube
./dist/sonar-reports-macos-arm64 extract http://localhost:9000 YOUR_TOKEN

# Using config file (see below)
./dist/sonar-reports-macos-arm64 extract --config config.json
```

## Configuration File Support

Instead of passing command-line arguments, you can use a JSON configuration file:

```json
{
  "url": "http://localhost:9000",
  "token": "YOUR_SONARQUBE_TOKEN",
  "export_directory": "./files",
  "concurrency": 10,
  "timeout": 60
}
```

Then run:
```bash
./dist/sonar-reports-macos-arm64 extract --config config.json
```

See [CONFIG.md](CONFIG.md) for detailed configuration file documentation.

## Troubleshooting

### Build Fails with Missing Modules

If the build fails due to missing modules, you may need to update the `hiddenimports` list in [sonar-reports.spec](../sonar-reports.spec:21).

### Executable is Too Large

The executable size can be reduced by:
- Removing UPX compression (change `upx=True` to `upx=False` in the spec file)
- Excluding unnecessary modules in the spec file
- Using `--onefile` mode (default)

### Executable Doesn't Run

- Ensure you're running the correct version for your platform
- On macOS/Linux, make sure the file is executable: `chmod +x sonar-reports-*`
- On macOS, you may need to allow the app in System Preferences > Security & Privacy
- Check antivirus software - it may be blocking the executable

### macOS "Unverified Developer" Warning

macOS may show a warning about unverified developers. To run the executable:

1. Right-click the executable and select "Open"
2. Click "Open" in the dialog

Or from the command line:
```bash
xattr -d com.apple.quarantine sonar-reports-macos-arm64
```

## Distribution

The executables are standalone and don't require Python or any dependencies to be installed. You can distribute them to users who can run them directly.

**Important**: Always include configuration documentation with distributed executables so users know how to set up their credentials and endpoints.
