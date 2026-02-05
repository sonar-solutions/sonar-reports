=================
Sonarqube Reports
=================

ETL tool to extract data from SonarQube Server instances and migrate them to SonarQube Cloud. Commands should be run
with a mounted volume in order to store data locally.

`docker run -v ./{LOCAL_DIRECTORY}:/app/files ghcr.io/sonar-solutions/sonar-reports:latest {COMMAND}`

Process
-------
1. Extract data with "extract" command
2. Generate organization <> project structure with "structure" command
3. Add SonarQube Cloud organization to generated organizations.csv in the sonarcloud_org_key column
4. Map groups, quality profiles, quality gates, etc. with the "mappings" command
5. Run the migration with "migrate" command

========
Commands
========

EXTRACT
-------

Usage: sonar-reports extract [OPTIONS] URL TOKEN

  Extracts data from a SonarQube Server instance and stores it in the export
  directory as new line delimited json files

  URL is the url of the SonarQube instance

  TOKEN is an admin user token to the SonarQube instance

Options:
  --pem_file_path TEXT     Path to client certificate pem file
  --key_file_path TEXT     Path to client certificate key file
  --cert_password TEXT     Password for client certificate
  --export_directory TEXT  Root Directory to output the export
  --extract_type TEXT      Type of Extract to run
  --concurrency INTEGER    Maximum number of concurrent requests
  --timeout INTEGER        Number of seconds before a request will timeout
  --extract_id TEXT        ID of an extract to resume in case of failures.
                           Extract will start by retrying last completed task

REPORT
------

Usage: sonar-reports report [OPTIONS]

  Generates a markdown report based on data extracted from one or more
  SonarQube Server instances

Options:
  --export_directory TEXT  Root Directory containing all of the SonarQube
                           exports

STRUCTURE
---------

Usage: sonar-reports structure [OPTIONS]

  Groups projects into organizations based on DevOps Bindings and Server Urls.
  Outputs organizations and projects as CSVs

Options:
  --export_directory TEXT  Root Directory containing all of the SonarQube
                           exports

MAPPINGS
--------

Usage: sonar-reports mappings [OPTIONS]

  Maps groups, permission templates, quality profiles, quality gates, and
  portfolios to relevant organizations. Outputs CSVs for each entity type

Options:
  --export_directory TEXT  Root Directory containing all of the SonarQube
                           exports

MIGRATE
-------

Usage: sonar-reports migrate [OPTIONS] TOKEN ENTERPRISE_KEY

  Migrate SonarQube Server configurations to SonarQube Cloud. User must run
  the structure and mappings command and add the SonarQube Cloud organization
  keys to the organizations.csv in order to start the migration

  TOKEN is a user token that has admin permissions at the enterprise level and
  all organizations ENTERPRISE_KEY is the key of the SonarQube Cloud
  enterprise. All migrating organizations must be added to the enterprise

Options:
  --edition TEXT
  --url TEXT
  --run_id TEXT            ID of a run to resume in case of failures.
                           Migration will resume by retrying the last
                           completed task
  --concurrency INTEGER    Maximum number of concurrent requests
  --export_directory TEXT  Root Directory containing all of the SonarQube
                           exports
  --target_task TEXT       Name of a specific migration task to complete. All
                           dependent tasks will be be included


RESET
-----

Usage: sonar-reports reset [OPTIONS] TOKEN ENTERPRISE_KEY

  Resets a SonarQube cloud Enterprise back to its original state. Warning,
  this will delete everything in every organization within the enterprise.

  TOKEN is a user token that has admin permissions at the enterprise level and
  all organizations

  ENTERPRISE_KEY is the key of the SonarQube Cloud enterprise that will be
  reset.

Options:
  --edition TEXT           SonarQube Cloud License Edition
  --url TEXT               Url of the SonarQube Cloud
  --concurrency INTEGER    Maximum number of concurrent requests
  --export_directory TEXT  Directory to place all interim files
