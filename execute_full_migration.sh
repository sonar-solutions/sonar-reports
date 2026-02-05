#!/bin/bash

################################################################################
# SonarQube to SonarCloud Migration Script
#
# This script automates the complete migration process from SonarQube Server
# to SonarCloud, including extraction, structure generation, mappings, and
# the final migration.
################################################################################

set -e  # Exit on any error

# =============================================================================
# CONFIGURATION - Edit these variables before running
# =============================================================================

# SonarQube Server Configuration
SONARQUBE_URL="http://localhost:9000"              # Your SonarQube Server URL
SONARQUBE_TOKEN="your-sonarqube-token-here"        # Admin token for SonarQube

# SonarCloud Configuration
SONARCLOUD_URL="https://sonarcloud.io/"            # SonarCloud URL
SONARCLOUD_TOKEN="your-sonarcloud-token-here"      # Admin token for SonarCloud
SONARCLOUD_ENTERPRISE_KEY="your-enterprise-key"    # Your SonarCloud Enterprise key
SONARCLOUD_ORG_KEY="your-target-org"               # Target organization in SonarCloud

# Migration Settings
EXPORT_DIR="./files"                               # Local directory for exported data
CONCURRENCY=10                                     # Number of concurrent API requests
TIMEOUT=60                                         # Request timeout in seconds

# =============================================================================
# DO NOT EDIT BELOW THIS LINE (unless you know what you're doing)
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
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

# Validate required variables
if [ "$SONARQUBE_TOKEN" = "your-sonarqube-token-here" ]; then
    print_error "Please set SONARQUBE_TOKEN in the script"
    exit 1
fi

if [ "$SONARCLOUD_TOKEN" = "your-sonarcloud-token-here" ]; then
    print_error "Please set SONARCLOUD_TOKEN in the script"
    exit 1
fi

if [ "$SONARCLOUD_ENTERPRISE_KEY" = "your-enterprise-key" ]; then
    print_error "Please set SONARCLOUD_ENTERPRISE_KEY in the script"
    exit 1
fi

if [ "$SONARCLOUD_ORG_KEY" = "your-target-org" ]; then
    print_error "Please set SONARCLOUD_ORG_KEY in the script"
    exit 1
fi

# Create export directory if it doesn't exist
mkdir -p "$EXPORT_DIR"

# Get absolute path for export directory
EXPORT_DIR_ABS=$(cd "$EXPORT_DIR" && pwd)

# Convert localhost URLs to host.docker.internal for Docker
# This allows containers to access the host's localhost
SONARQUBE_URL_DOCKER="${SONARQUBE_URL/localhost/host.docker.internal}"

print_step "Migration Configuration"
echo "SonarQube URL: $SONARQUBE_URL"
echo "SonarCloud URL: $SONARCLOUD_URL"
echo "SonarCloud Enterprise: $SONARCLOUD_ENTERPRISE_KEY"
echo "SonarCloud Organization: $SONARCLOUD_ORG_KEY"
echo "Export Directory: $EXPORT_DIR_ABS"
echo "Concurrency: $CONCURRENCY"
echo "Timeout: ${TIMEOUT}s"

# =============================================================================
# Step 1: Build Docker Image
# =============================================================================
print_step "Step 1: Building Docker Image"

if ! docker build -t sonar-reports:local .; then
    print_error "Failed to build Docker image"
    exit 1
fi

echo -e "${GREEN}✓ Docker image built successfully${NC}"

# =============================================================================
# Step 2: Extract Data from SonarQube
# =============================================================================
print_step "Step 2: Extracting Data from SonarQube"

if ! docker run --rm \
    -v "${EXPORT_DIR_ABS}:/app/files" \
    sonar-reports:local extract \
    "$SONARQUBE_URL_DOCKER" \
    "$SONARQUBE_TOKEN" \
    --export_directory=/app/files \
    --concurrency=$CONCURRENCY \
    --timeout=$TIMEOUT; then
    print_error "Failed to extract data from SonarQube"
    exit 1
fi

echo -e "${GREEN}✓ Data extracted successfully${NC}"

# =============================================================================
# Step 3: Generate Organization Structure
# =============================================================================
print_step "Step 3: Generating Organization Structure"

if ! docker run --rm \
    -v "${EXPORT_DIR_ABS}:/app/files" \
    sonar-reports:local structure \
    --export_directory=/app/files; then
    print_error "Failed to generate organization structure"
    exit 1
fi

echo -e "${GREEN}✓ Organization structure generated${NC}"

# =============================================================================
# Step 4: Update organizations.csv with SonarCloud Org Key
# =============================================================================
print_step "Step 4: Updating organizations.csv"

ORGS_FILE="${EXPORT_DIR_ABS}/organizations.csv"

if [ ! -f "$ORGS_FILE" ]; then
    print_error "organizations.csv not found at $ORGS_FILE"
    exit 1
fi

# Backup the original file
cp "$ORGS_FILE" "${ORGS_FILE}.backup"

# Update the sonarcloud_org_key column (second column) in all data rows
# This uses awk to replace the empty second field with the org key
awk -v org_key="$SONARCLOUD_ORG_KEY" 'BEGIN {FS=OFS=","}
    NR==1 {print; next}  # Print header as-is
    {$2=org_key; print}   # Update second column and print
' "${ORGS_FILE}.backup" > "$ORGS_FILE"

echo "Updated organizations.csv:"
cat "$ORGS_FILE"
echo -e "${GREEN}✓ organizations.csv updated with SonarCloud org key${NC}"

# =============================================================================
# Step 5: Generate Mappings
# =============================================================================
print_step "Step 5: Generating Mappings"

if ! docker run --rm \
    -v "${EXPORT_DIR_ABS}:/app/files" \
    sonar-reports:local mappings \
    --export_directory=/app/files; then
    print_error "Failed to generate mappings"
    exit 1
fi

echo -e "${GREEN}✓ Mappings generated successfully${NC}"
echo "Generated mapping files:"
ls -lh "${EXPORT_DIR_ABS}"/*.csv

# =============================================================================
# Step 6: Run Migration to SonarCloud
# =============================================================================
print_step "Step 6: Migrating to SonarCloud"

print_warning "This step may take several minutes depending on the number of projects..."

if ! docker run --rm \
    -v "${EXPORT_DIR_ABS}:/app/files" \
    sonar-reports:local migrate \
    "$SONARCLOUD_TOKEN" \
    "$SONARCLOUD_ENTERPRISE_KEY" \
    --url="$SONARCLOUD_URL" \
    --export_directory=/app/files \
    --concurrency=$CONCURRENCY; then
    print_error "Migration failed"
    exit 1
fi

echo -e "${GREEN}✓ Migration completed successfully${NC}"

# =============================================================================
# Step 7: Verify Migration
# =============================================================================
print_step "Step 7: Verifying Migration"

# Extract the base URL for sc-staging.io or sonarcloud.io
SONARCLOUD_BASE_URL="${SONARCLOUD_URL%/}"

echo "Fetching projects from SonarCloud..."
PROJECT_COUNT=$(curl -s -H "Authorization: Bearer $SONARCLOUD_TOKEN" \
    "${SONARCLOUD_BASE_URL}/api/projects/search?organization=${SONARCLOUD_ORG_KEY}&ps=500" | \
    jq -r '.components | length' 2>/dev/null || echo "0")

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
