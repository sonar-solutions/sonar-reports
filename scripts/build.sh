#!/bin/bash
# Build script for Unix-like systems (Linux, macOS)

set -e

echo "Building sonar-reports executable..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Detect architecture
ARCH=$(uname -m)
OS=$(uname -s)

echo "Detected OS: $OS"
echo "Detected Architecture: $ARCH"

# Build with PyInstaller
echo "Building with PyInstaller..."
pyinstaller sonar-reports.spec

# Determine output name based on platform
if [[ "$OS" == "Darwin" ]]; then
    # macOS
    if [[ "$ARCH" == "arm64" ]]; then
        OUTPUT_NAME="sonar-reports-macos-arm64"
    else
        OUTPUT_NAME="sonar-reports-macos-x86_64"
    fi
elif [[ "$OS" == "Linux" ]]; then
    # Linux
    if [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
        OUTPUT_NAME="sonar-reports-linux-arm64"
    else
        OUTPUT_NAME="sonar-reports-linux-x86_64"
    fi
else
    echo "Unsupported operating system: $OS"
    exit 1
fi

# Rename the binary
echo "Renaming binary to $OUTPUT_NAME..."
mv dist/sonar-reports "dist/$OUTPUT_NAME"

# Deactivate virtual environment
deactivate

echo "Build complete! Binary available at: dist/$OUTPUT_NAME"
echo ""
echo "You can now run: ./dist/$OUTPUT_NAME --help"
