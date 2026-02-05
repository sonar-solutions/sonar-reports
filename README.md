# SonarQube to SonarCloud Migration Guide

This guide explains how to use the automated migration script to migrate your SonarQube Server projects to SonarCloud.

## Prerequisites

1. **Docker** installed and running
2. **SonarQube Server** access with admin token
3. **SonarCloud** account with:
   - Enterprise subscription
   - Admin token with enterprise-level permissions
   - Target organization created and added to your enterprise

## Quick Start

### 1. Configure the Script

Edit `execute_full_migration.sh` and update these variables at the top:

```bash
SONARQUBE_URL="http://localhost:9000"                      # Your SonarQube Server URL
SONARQUBE_TOKEN="your-sonarqube-token-here"                # Admin token for SonarQube
SONARCLOUD_URL="https://sonarcloud.io/"                    # SonarCloud URL
SONARCLOUD_TOKEN="your-sonarcloud-token-here"              # Admin token for SonarCloud
SONARCLOUD_ENTERPRISE_KEY="your-enterprise-key"            # Your SonarCloud Enterprise key
SONARCLOUD_ORG_KEY="your-target-org"                       # Target organization in SonarCloud
EXPORT_DIR="./files"                                       # Directory for exported data
CONCURRENCY=10                                             # Number of concurrent API requests
TIMEOUT=60                                                 # Request timeout in seconds
```

### 2. Run the Migration

```bash
chmod +x execute_full_migration.sh
./execute_full_migration.sh
```

The script will:
1. ✅ Validate configuration
2. ✅ Build the Docker image
3. ✅ Extract all data from SonarQube Server
4. ✅ Analyze and structure projects into organizations
5. ✅ Automatically update organizations.csv with your SonarCloud org key
6. ✅ Generate mappings for groups, profiles, gates, etc.
7. ✅ Migrate everything to SonarCloud
8. ✅ Verify the migration was successful

## What Gets Migrated?

### ✅ Projects
- Project configurations
- Project settings
- Quality profiles
- Quality gates
- New code definitions
- Tags

### ✅ Users & Permissions
- User groups
- User permissions
- Group permissions
- Permission templates

### ✅ Quality Configuration
- Quality profiles (with custom rules)
- Quality gates (with conditions)
- Rule customizations

### ✅ Portfolios
- Portfolio structure
- Portfolio projects
- Portfolio permissions

### ⚠️ What Is NOT Migrated?
- Historical analysis data
- Issues and their history
- Code coverage history
- Security hotspots
- Source code (you'll need to re-scan)

## Manual Steps (Alternative)

If you prefer to run commands manually:

### Step 1: Build Docker Image
```bash
docker build -t sonar-reports:local .
```

### Step 2: Extract from SonarQube
```bash
# Note: Use host.docker.internal instead of localhost for Docker to access host
docker run --rm \
  -v "$(pwd)/files:/app/files" \
  sonar-reports:local extract \
  http://host.docker.internal:9000 \
  <SONARQUBE_TOKEN> \
  --export_directory=/app/files \
  --concurrency=10 \
  --timeout=60
```

### Step 3: Generate Structure
```bash
docker run --rm \
  -v "$(pwd)/files:/app/files" \
  sonar-reports:local structure \
  --export_directory=/app/files
```

### Step 4: Edit organizations.csv
Open `files/organizations.csv` and add your SonarCloud organization key in the `sonarcloud_org_key` column (second column).

Example:
```csv
sonarqube_org_key,sonarcloud_org_key,server_url,alm,url,is_cloud,project_count
http://host.docker.internal:9000/,your-org-key,http://host.docker.internal:9000/,,,false,28
```

### Step 5: Generate Mappings
```bash
docker run --rm \
  -v "$(pwd)/files:/app/files" \
  sonar-reports:local mappings \
  --export_directory=/app/files
```

### Step 6: Run Migration
```bash
docker run --rm \
  -v "$(pwd)/files:/app/files" \
  sonar-reports:local migrate \
  <SONARCLOUD_TOKEN> \
  <ENTERPRISE_KEY> \
  --url=https://sonarcloud.io/ \
  --export_directory=/app/files \
  --concurrency=10
```

## Troubleshooting

### Migration Fails or Errors Occur

1. **Check the migration requests log**:
   ```bash
   ls -lah files/*/requests.log
   tail -100 files/*/requests.log
   ```

2. **Check extract data**:
   ```bash
   ls -lah files/
   cat files/organizations.csv
   cat files/projects.csv
   ```

3. **Resume a failed migration**:
   If migration fails partway through, you can resume it:
   ```bash
   docker run --rm \
     -v "$(pwd)/files:/app/files" \
     sonar-reports:local migrate \
     <SONARCLOUD_TOKEN> \
     <ENTERPRISE_KEY> \
     --url=https://sonarcloud.io/ \
     --export_directory=/app/files \
     --run_id=<MIGRATION_RUN_ID>
   ```

   Find the run ID from the directory names in `files/` (e.g., `1770304645`)

### No Projects Extracted

If the extraction completes but no projects are found:
- Verify your SonarQube token has admin permissions
- Check that projects exist in your SonarQube instance
- Review the requests.log file in `files/<extract-id>/requests.log` for API errors
- Ensure you're using `host.docker.internal` instead of `localhost` in Docker commands

### Authentication Errors

- Verify tokens are valid and haven't expired
- Ensure tokens have the required permissions:
  - SonarQube: Admin or global analysis permissions
  - SonarCloud: Enterprise-level admin permissions

### API Rate Limiting

If you hit rate limits:
- Reduce `CONCURRENCY` to 5 or lower
- Increase `TIMEOUT` to 120 seconds

## Post-Migration Steps

### 1. Verify Projects
Visit your SonarCloud organization and verify all projects are present:
```
https://sonarcloud.io/organizations/<YOUR_ORG>/projects
```

You can also verify via API:
```bash
curl -H "Authorization: Bearer <TOKEN>" \
  "https://sonarcloud.io/api/projects/search?organization=<YOUR_ORG>&ps=500" | jq
```

### 2. Check Quality Gates
Verify quality gates were migrated correctly:
```
https://sonarcloud.io/organizations/<YOUR_ORG>/quality_gates
```

### 3. Verify Quality Profiles
Check that quality profiles and custom rules were migrated:
```
https://sonarcloud.io/organizations/<YOUR_ORG>/quality_profiles
```

### 4. Re-scan Projects
After migration, you'll need to run new analyses to populate code and issues:
```bash
# Example for a Maven project
mvn sonar:sonar \
  -Dsonar.projectKey=<project-key> \
  -Dsonar.organization=<your-org> \
  -Dsonar.host.url=https://sonarcloud.io \
  -Dsonar.token=<your-token>
```

### 5. Configure DevOps Integration
Set up ALM (GitHub, Azure DevOps, GitLab, Bitbucket) integrations for automatic analysis.

## Advanced Usage

### Migrate Specific Organizations Only
Edit the `organizations.csv` file after Step 3 and remove rows for organizations you don't want to migrate.

### Migrate Specific Tasks Only
Use the `--target_task` option:
```bash
docker run --rm \
  -v $(pwd)/sonarqube-export:/app/files \
  sonar-reports:local migrate \
  <TOKEN> <ENTERPRISE_KEY> \
  --url=https://sonarcloud.io/ \
  --export_directory=/app/files \
  --target_task=createProjects
```

### Extract Specific Data Only
```bash
docker run --rm \
  -v $(pwd)/sonarqube-export:/app/files \
  sonar-reports:local extract \
  <URL> <TOKEN> \
  --export_directory=/app/files \
  --target_task=getProjects
```

## Support

For issues or questions:
1. Check the log files in `files/*/requests.log`
2. Review the [README.rst](README.rst) for detailed CLI command documentation
3. Use `execute_full_migration.sh` for a fully automated migration
4. Open an issue on the project repository

## Script Files

- **execute_full_migration.sh** - Automated migration script (recommended)
- **README.rst** - Technical documentation for manual CLI usage
- **MIGRATION_GUIDE.md** - Detailed migration guide (deprecated - use this README instead)

## Security Notes

⚠️ **Important Security Considerations:**

- Never commit tokens or credentials to version control
- Store tokens securely (e.g., environment variables, secret managers)
- Tokens have full admin access - protect them accordingly
- Consider using temporary tokens that expire after migration
- Review and audit what data is being migrated
