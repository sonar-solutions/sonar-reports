#!/bin/bash

################################################################################
# SonarQube to SonarCloud Migration Script (Using Binary Executable)
#
# This script automates the complete migration process from SonarQube Server
# to SonarCloud using the standalone binary executable.
#
# Usage:
#   1. Build the binary: ./scripts/build.sh
#   2. Create migration-config.json from examples/migration-config.example.json
#   3. Run: ./scripts/execute_migration_with_binary.sh migration-config.json
################################################################################

set -e  # Exit on any error

# =============================================================================
# Configuration
# =============================================================================

# Detect platform and set binary name
OS=$(uname -s)
ARCH=$(uname -m)

if [[ "$OS" == "Darwin" ]]; then
    if [[ "$ARCH" == "arm64" ]]; then
        BINARY="./dist/sonar-reports-macos-arm64"
    else
        BINARY="./dist/sonar-reports-macos-x86_64"
    fi
elif [[ "$OS" == "Linux" ]]; then
    if [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
        BINARY="./dist/sonar-reports-linux-arm64"
    else
        BINARY="./dist/sonar-reports-linux-x86_64"
    fi
else
    echo "Error: Unsupported operating system: $OS"
    exit 1
fi

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    echo "Please build the binary first using: ./scripts/build.sh"
    exit 1
fi

# Get config file from argument or use default
CONFIG_FILE="${1:-migration-config.json}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    echo ""
    echo "Usage: $0 [config-file.json]"
    echo ""
    echo "Example:"
    echo "  1. Copy the example: cp examples/migration-config.example.json migration-config.json"
    echo "  2. Edit migration-config.json with your values"
    echo "  3. Run: $0 migration-config.json"
    exit 1
fi

# =============================================================================
# Colors and helper functions
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "\n${GREEN}===================================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}===================================================${NC}\n"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# =============================================================================
# Load configuration from JSON
# =============================================================================

print_step "Loading Configuration"

# Extract values from JSON using built-in tools (python3 or jq)
if command -v jq &> /dev/null; then
    # Use jq if available
    SONARQUBE_URL=$(jq -r '.sonarqube.url' "$CONFIG_FILE")
    SONARQUBE_TOKEN=$(jq -r '.sonarqube.token' "$CONFIG_FILE")
    SONARCLOUD_URL=$(jq -r '.sonarcloud.url' "$CONFIG_FILE")
    SONARCLOUD_TOKEN=$(jq -r '.sonarcloud.token' "$CONFIG_FILE")
    SONARCLOUD_ENTERPRISE_KEY=$(jq -r '.sonarcloud.enterprise_key' "$CONFIG_FILE")
    SONARCLOUD_ORG_KEY=$(jq -r '.sonarcloud.org_key' "$CONFIG_FILE")
    EXPORT_DIR=$(jq -r '.settings.export_directory' "$CONFIG_FILE")
    CONCURRENCY=$(jq -r '.settings.concurrency' "$CONFIG_FILE")
    TIMEOUT=$(jq -r '.settings.timeout' "$CONFIG_FILE")
elif command -v python3 &> /dev/null; then
    # Fallback to python3
    read -r SONARQUBE_URL SONARQUBE_TOKEN SONARCLOUD_URL SONARCLOUD_TOKEN SONARCLOUD_ENTERPRISE_KEY SONARCLOUD_ORG_KEY EXPORT_DIR CONCURRENCY TIMEOUT <<< $(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    config = json.load(f)
print(config['sonarqube']['url'],
      config['sonarqube']['token'],
      config['sonarcloud']['url'],
      config['sonarcloud']['token'],
      config['sonarcloud']['enterprise_key'],
      config['sonarcloud']['org_key'],
      config['settings']['export_directory'],
      config['settings']['concurrency'],
      config['settings']['timeout'])
")
else
    print_error "Neither jq nor python3 is available. Please install one of them."
    exit 1
fi

# Create export directory if it doesn't exist
mkdir -p "$EXPORT_DIR"

# Get absolute path for export directory
EXPORT_DIR_ABS=$(cd "$EXPORT_DIR" && pwd)

print_step "Migration Configuration"
echo "Binary: $BINARY"
echo "Config File: $CONFIG_FILE"
echo "SonarQube URL: $SONARQUBE_URL"
echo "SonarCloud URL: $SONARCLOUD_URL"
echo "SonarCloud Enterprise: $SONARCLOUD_ENTERPRISE_KEY"
echo "SonarCloud Organization: $SONARCLOUD_ORG_KEY"
echo "Export Directory: $EXPORT_DIR_ABS"
echo "Concurrency: $CONCURRENCY"
echo "Timeout: ${TIMEOUT}s"

# =============================================================================
# Step 1: Extract Data from SonarQube
# =============================================================================
print_step "Step 1: Extracting Data from SonarQube"

if ! "$BINARY" extract \
    "$SONARQUBE_URL" \
    "$SONARQUBE_TOKEN" \
    --export_directory="$EXPORT_DIR_ABS" \
    --concurrency="$CONCURRENCY" \
    --timeout="$TIMEOUT"; then
    print_error "Failed to extract data from SonarQube"
    exit 1
fi

echo -e "${GREEN}✓ Data extracted successfully${NC}"

# =============================================================================
# Step 2: Generate Organization Structure
# =============================================================================
print_step "Step 2: Generating Organization Structure"

if ! "$BINARY" structure --export_directory="$EXPORT_DIR_ABS"; then
    print_error "Failed to generate organization structure"
    exit 1
fi

echo -e "${GREEN}✓ Organization structure generated${NC}"

# =============================================================================
# Step 3: Update organizations.csv with SonarCloud Org Key
# =============================================================================
print_step "Step 3: Updating organizations.csv"

ORGS_FILE="${EXPORT_DIR_ABS}/organizations.csv"

if [ ! -f "$ORGS_FILE" ]; then
    print_error "organizations.csv not found at $ORGS_FILE"
    exit 1
fi

# Backup the original file
cp "$ORGS_FILE" "${ORGS_FILE}.backup"

# Update the sonarcloud_org_key column (second column) in all data rows
awk -v org_key="$SONARCLOUD_ORG_KEY" 'BEGIN {FS=OFS=","}
    NR==1 {print; next}  # Print header as-is
    {$2=org_key; print}   # Update second column and print
' "${ORGS_FILE}.backup" > "$ORGS_FILE"

echo "Updated organizations.csv:"
cat "$ORGS_FILE"
echo -e "${GREEN}✓ organizations.csv updated with SonarCloud org key${NC}"

# =============================================================================
# Step 4: Generate Mappings
# =============================================================================
print_step "Step 4: Generating Mappings"

if ! "$BINARY" mappings --export_directory="$EXPORT_DIR_ABS"; then
    print_error "Failed to generate mappings"
    exit 1
fi

echo -e "${GREEN}✓ Mappings generated successfully${NC}"
echo "Generated mapping files:"
ls -lh "${EXPORT_DIR_ABS}"/*.csv

# =============================================================================
# Step 5: Run Migration to SonarCloud
# =============================================================================
print_step "Step 5: Migrating to SonarCloud"

print_warning "This step may take several minutes depending on the number of projects..."

if ! "$BINARY" migrate \
    "$SONARCLOUD_TOKEN" \
    "$SONARCLOUD_ENTERPRISE_KEY" \
    --url="$SONARCLOUD_URL" \
    --export_directory="$EXPORT_DIR_ABS" \
    --concurrency="$CONCURRENCY"; then
    print_error "Migration failed"
    exit 1
fi

echo -e "${GREEN}✓ Migration completed successfully${NC}"

# =============================================================================
# Step 6: Verify Migration
# =============================================================================
print_step "Step 6: Verifying Migration"

SONARCLOUD_BASE_URL="${SONARCLOUD_URL%/}"

echo "Fetching projects from SonarCloud..."
PROJECT_COUNT=$(curl -s -H "Authorization: Bearer $SONARCLOUD_TOKEN" \
    "${SONARCLOUD_BASE_URL}/api/projects/search?organization=${SONARCLOUD_ORG_KEY}&ps=500" | \
    python3 -c "import sys, json; print(len(json.load(sys.stdin).get('components', [])))" 2>/dev/null || echo "0")

echo -e "${GREEN}✓ Found $PROJECT_COUNT projects in SonarCloud${NC}"

# =============================================================================
# Migration Complete
# =============================================================================
print_step "Migration Complete!"

echo "Summary:"
echo "  • Projects migrated: $PROJECT_COUNT"
echo "  • Export data location: $EXPORT_DIR_ABS"
echo "  • Migration logs: $EXPORT_DIR_ABS/*/requests.log"
echo ""
echo "View your projects at:"
echo "  ${SONARCLOUD_BASE_URL}/organizations/${SONARCLOUD_ORG_KEY}/projects"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC}"
echo "  • Historical analysis data, issues, and code coverage were NOT migrated"
echo "  • You need to re-scan your projects to populate code and issues"
echo "  • Configure DevOps integrations (GitHub, Azure DevOps, etc.) for automatic analysis"
echo ""
echo -e "${GREEN}Migration completed successfully!${NC}"
