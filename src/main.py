import json
from datetime import datetime, UTC

from constants import REPORT_TASKS, MIGRATION_TASKS
import click
import os
import asyncio
from execute import execute_plan
from logs import configure_logger
from operations.http_request import configure_client, configure_client_cert, get_server_details
from plan import generate_task_plan, get_available_task_configs
from utils import get_unique_extracts, export_csv, load_csv, filter_completed, get_latest_extract_id
from validate import validate_migration
from importlib import import_module
from pipelines.process import update_pipelines


@click.group()
def cli():
    pass


@cli.command()
@click.argument('url')
@click.argument('token')
@click.option('--pem_file_path', help="Path to client certificate pem file")
@click.option('--key_file_path', help="Path to client certificate key file")
@click.option('--cert_password', help="Password for client certificate")
@click.option('--export_directory', default='/app/files/', help="Root Directory to output the export")
@click.option('--extract_type', default='all', help='Type of Extract to run')
@click.option('--concurrency', default=25, help='Maximum number of concurrent requests')
@click.option('--timeout', default=60, help='Number of seconds before a request will timeout')
@click.option('--extract_id',
              help='ID of an extract to resume in case of failures. Extract will start by retrying last completed task')
@click.option('--target_task', help='Target Task to complete. All dependent tasks will be included')
def extract(url, token, export_directory: str, extract_type, pem_file_path, key_file_path, cert_password, target_task,
            concurrency, timeout, extract_id):
    """Extracts data from a SonarQube Server instance and stores it in the export directory as new line delimited json files

    URL is the url of the SonarQube instance

    TOKEN is an admin user token to the SonarQube instance

    """
    if not url.endswith('/'):
        url = f"{url}/"
    if extract_id is None:
        extract_id = str(int(datetime.now(UTC).timestamp()))
    cert = configure_client_cert(key_file_path, pem_file_path, cert_password)
    server_version, edition = get_server_details(url=url, cert=cert, token=token)
    extract_directory = os.path.join(export_directory, extract_id + '/')
    os.makedirs(extract_directory, exist_ok=True)
    configure_logger(name='http_request', level='INFO', output_file=os.path.join(extract_directory, 'requests.log'))
    configure_client(url=url, cert=cert, server_version=server_version, token=token, concurrency=concurrency,
                     timeout=timeout)
    configs = get_available_task_configs(client_version=server_version, edition=edition)
    if target_task is not None:
        target_tasks = [target_task]
    elif extract_type == 'all':
        target_tasks = list([k for k in configs.keys() if k.startswith('get')])
    else:
        try:
            module = import_module(f'report.{extract_type}')
        except ImportError:
            click.echo(f"Report Type {extract_type} Not Found")
            return
        else:
            target_tasks = module.REQUIRED

    plan = generate_task_plan(target_tasks=target_tasks, task_configs=configs)
    with open(os.path.join(extract_directory, 'extract.json'), 'wt') as f:
        json.dump(
            dict(
                plan=plan,
                version=server_version,
                edition=edition,
                url=url,
                target_tasks=target_tasks,
                available_configs=list(configs.keys()),
                run_id=extract_id,
            ), f
        )
    execute_plan(execution_plan=plan, inputs=dict(url=url), concurrency=concurrency, task_configs=configs,
                 output_directory=export_directory, current_run_id=extract_id, run_ids={extract_id})
    click.echo(f"Extract Complete: {extract_id}")


@cli.command()
@click.option('--export_directory', default='/app/files/',
              help="Root Directory containing all of the SonarQube exports")
@click.option('--report_type', default='migration', help='Type of report to generate')
@click.option('--filename', default=None, help='Filename for the report')
def report(export_directory, report_type, filename):
    """Generates a markdown report based on data extracted from one or more SonarQube Server instances"""
    from importlib import import_module
    try:
        module = import_module(f'report.{report_type}.generate')
    except ImportError:
        click.echo(f"Report Type {report_type} Not Found")
        return
    extract_mapping = get_unique_extracts(directory=export_directory)
    if not extract_mapping:
        click.echo("No Extracts Found")
        return
    md = module.generate_markdown(extract_directory=export_directory, extract_mapping=extract_mapping)
    filename = filename if filename else report_type
    with open(os.path.join(export_directory, f'{filename}.md'), 'wt') as f:
        f.write(md)
    return md


@cli.command()
@click.option('--export_directory', default='/app/files/',
              help="Root Directory containing all of the SonarQube exports")
def structure(export_directory):
    """Groups projects into organizations based on DevOps Bindings and Server Urls. Outputs organizations and projects as CSVs"""
    from structure import map_organization_structure, map_project_structure
    extract_mapping = get_unique_extracts(directory=export_directory)
    bindings, projects = map_project_structure(export_directory=export_directory, extract_mapping=extract_mapping)
    organizations = map_organization_structure(bindings)
    export_csv(directory=export_directory, name='organizations', data=organizations)
    export_csv(directory=export_directory, name='projects', data=projects)


@cli.command()
@click.option('--export_directory', default='/app/files/',
              help="Root Directory containing all of the SonarQube exports")
def mappings(export_directory):
    """Maps groups, permission templates, quality profiles, quality gates, and portfolios to relevant organizations. Outputs CSVs for each entity type"""
    from structure import map_templates, map_groups, map_profiles, map_gates, map_portfolios
    extract_mapping = get_unique_extracts(directory=export_directory)
    projects = load_csv(directory=export_directory, filename='projects.csv')
    project_org_mapping = {p['server_url'] + p['key']: p['sonarqube_org_key'] for p in projects}
    mapping = dict(
        templates=map_templates(project_org_mapping=project_org_mapping, extract_mapping=extract_mapping,
                                export_directory=export_directory),
        profiles=map_profiles(extract_mapping=extract_mapping, project_org_mapping=project_org_mapping,
                              export_directory=export_directory),
        gates=map_gates(project_org_mapping=project_org_mapping, extract_mapping=extract_mapping,
                        export_directory=export_directory),
        portfolios=map_portfolios(export_directory=export_directory, extract_mapping=extract_mapping)
    )
    mapping['groups'] = map_groups(project_org_mapping=project_org_mapping, profiles=mapping['profiles'],
                                   extract_mapping=extract_mapping, export_directory=export_directory,
                                   templates=mapping['templates'])
    for k, v in mapping.items():
        export_csv(directory=export_directory, name=k, data=v)


@cli.command()
@click.argument('token')
@click.argument('enterprise_key')
@click.option('--edition', default='enterprise')
@click.option('--url', default='https://sonarcloud.io/')
@click.option('--run_id', default=None,
              help='ID of a run to resume in case of failures. Migration will resume by retrying the last completed task')
@click.option('--concurrency', default=25, help='Maximum number of concurrent requests')
@click.option('--export_directory', default='/app/files/',
              help="Root Directory containing all of the SonarQube exports")
@click.option('--target_task',
              help='Name of a specific migration task to complete. All dependent tasks will be be included')
def migrate(token, edition, url, enterprise_key, concurrency, run_id, export_directory, target_task):
    """Migrate SonarQube Server configurations to SonarQube Cloud. User must run the structure and mappings command and add the SonarQube Cloud organization keys to the organizations.csv in order to start the migration

    TOKEN is a user token that has admin permissions at the enterprise level and all organizations
    ENTERPRISE_KEY is the key of the SonarQube Cloud enterprise. All migrating organizations must be added to the enterprise
    """
    create_plan = False
    configure_client(url=url, cert=None, server_version="cloud", token=token)
    api_url = url.replace('https://', 'https://api.')
    configure_client(url=api_url, cert=None, server_version="cloud", token=token)
    configs = get_available_task_configs(client_version='cloud', edition=edition)
    if run_id is None:
        run_id = str(int(datetime.now(UTC).timestamp()))
        create_plan = True
    run_dir, completed = validate_migration(directory=export_directory, run_id=run_id)
    extract_mapping = get_unique_extracts(directory=export_directory)
    configure_logger(name='http_request', level='INFO', output_file=os.path.join(run_dir, 'requests.log'))
    if target_task is not None:
        target_tasks = [target_task]
    else:
        target_tasks = list(
            [k for k in configs.keys() if not any([k.startswith(i) for i in ['get', 'delete', 'reset']]) ])
    completed = completed.union(MIGRATION_TASKS)
    plan = None
    if create_plan:
        plan = generate_task_plan(
            target_tasks=target_tasks,
            task_configs=configs, completed=completed)
        with open(os.path.join(run_dir, 'migrate.json'), 'wt') as f:
            json.dump(
                dict(
                    plan=plan,
                    version='cloud',
                    edition=edition,
                    completed=list(completed),
                    url=url,
                    target_tasks=target_tasks,
                    available_configs=list(configs.keys()),
                    run_id=run_id,
                ), f
            )
    else:
        with open(os.path.join(run_dir, 'migrate.json'), 'rt') as f:
            plan = json.load(f)['plan']
    plan = filter_completed(plan=plan, directory=run_dir)
    execute_plan(execution_plan=plan, inputs=dict(url=url, api_url=api_url, enterprise_key=enterprise_key),
                 concurrency=concurrency,
                 task_configs=configs,
                 output_directory=export_directory, current_run_id=run_id,
                 run_ids=set(extract_mapping.values()).union({run_id}))


@cli.command()
@click.argument('token')
@click.argument('enterprise_key')
@click.option('--edition', default='enterprise', help="SonarQube Cloud License Edition")
@click.option('--url', default='https://sonarcloud.io/', help="Url of the SonarQube Cloud")
@click.option('--concurrency', default=25, help="Maximum number of concurrent requests")
@click.option('--export_directory', default='/app/files/', help="Directory to place all interim files")
def reset(token, edition, url, enterprise_key, concurrency, export_directory):
    """Resets a SonarQube cloud Enterprise back to its original state. Warning, this will delete everything in every organization within the enterprise.

    TOKEN is a user token that has admin permissions at the enterprise level and all organizations

    ENTERPRISE_KEY is the key of the SonarQube Cloud enterprise that will be reset.

    """

    configs = get_available_task_configs(client_version='cloud', edition=edition)
    if not url.endswith('/'):
        url = f"{url}/"
    configure_client(url=url, cert=None, server_version="cloud", token=token)
    api_url = url.replace('https://', 'https://api.')
    configure_client(url=api_url, cert=None, server_version="cloud", token=token)
    run_id = str(int(datetime.now(UTC).timestamp()))
    run_dir = os.path.join(export_directory, run_id)
    os.makedirs(run_dir, exist_ok=True)

    configure_logger(name='http_request', level='INFO', output_file=os.path.join(run_dir, 'requests.log'))
    target_tasks = list([k for k in configs.keys() if k.startswith('delete')])
    plan = generate_task_plan(
        target_tasks=target_tasks,
        task_configs=configs)
    with open(os.path.join(run_dir, 'clear.json'), 'wt') as f:
        json.dump(
            dict(
                plan=plan,
                version='cloud',
                edition=edition,
                enterprise_key=enterprise_key,
                url=url,
                target_tasks=target_tasks,
                available_configs=list(configs.keys()),
                run_id=run_id,
            ), f
        )
    execute_plan(execution_plan=plan, inputs=dict(url=url, api_url=api_url, enterprise_key=enterprise_key),
                 concurrency=concurrency,
                 task_configs=configs,
                 output_directory=export_directory, current_run_id=run_id,
                 run_ids={run_id})

@cli.command()
@click.argument('token')
@click.argument('enterprise_key')
@click.option('--edition', default='enterprise', help="SonarQube Cloud License Edition")
@click.option('--url', default='https://sonarcloud.io/', help="Url of the SonarQube Cloud")
@click.option('--concurrency', default=25, help="Maximum number of concurrent requests")
@click.option('--export_directory', default='/app/files/', help="Directory to place all interim files")
@click.option('--latest_only', default=True, is_flag=True, help="Only process latest scan for each project")
def history(token, edition, url, enterprise_key, concurrency, export_directory, latest_only):
    """Migrate latest scan data for migrated projects to SonarQube Cloud.
    
    Generates scan data using real source code, issues, and measures from extracted data,
    then uploads to SonarQube Cloud.
    
    TOKEN is a user token that has admin permissions at the enterprise level and all organizations
    ENTERPRISE_KEY is the key of the SonarQube Cloud enterprise
    """
    if not url.endswith('/'):
        url = f"{url}/"
    
    # Load migration and extract mappings
    migration_mapping = get_unique_extracts(directory=export_directory, key='migrate.json')
    extract_mapping = get_unique_extracts(directory=export_directory)
    
    if not migration_mapping:
        click.echo("No migration data found. Please run 'migrate' command first.")
        return
    
    if not extract_mapping:
        click.echo("No extract data found. Please run 'extract' command first.")
        return
    
    # Get migrated projects
    from history.projects import get_new_projects
    from history.generate_latest import generate_latest_scan
    from history.upload import upload_scan
    
    projects = get_new_projects(export_directory, migration_mapping)
    
    if not projects:
        click.echo("No migrated projects found.")
        return
    
    # Create output directory for scans
    run_id = str(int(datetime.now(UTC).timestamp()))
    output_dir = os.path.join(export_directory, run_id)
    os.makedirs(output_dir, exist_ok=True)
    
    # Configure logging
    configure_logger(name='http_request', level='INFO', output_file=os.path.join(output_dir, 'requests.log'))
    
    # Process each project
    loop = asyncio.get_event_loop()
    results = []
    
    for source_project_key, project in projects.items():
        try:
            click.echo(f"Processing project: {project['key']} (source: {source_project_key})")
            
            # Generate latest scan
            scan_dir = generate_latest_scan(
                extract_directory=export_directory,
                extract_mapping=extract_mapping,
                migration_mapping=migration_mapping,
                project_key=source_project_key,
                output_dir=output_dir
            )
            
            # Upload scan
            organization = project['sonarCloudOrgKey']
            resp = loop.run_until_complete(
                upload_scan(
                    scan_dir=scan_dir,
                    project_key=project['key'],
                    organization=organization,
                    token=token,
                    base_url=url,
                    timeout=300
                )
            )
            
            results.append({
                'project_key': project['key'],
                'source_project_key': source_project_key,
                'status': 'success',
                'scan_dir': scan_dir
            })
            click.echo(f"Successfully uploaded scan for {project['key']}")
            
        except Exception as e:
            click.echo(f"Error processing {project.get('key', source_project_key)}: {str(e)}", err=True)
            results.append({
                'project_key': project.get('key', 'unknown'),
                'source_project_key': source_project_key,
                'status': 'error',
                'error': str(e)
            })
    
    # Summary
    successful = sum(1 for r in results if r['status'] == 'success')
    failed = len(results) - successful
    click.echo(f"\nSummary: {successful} successful, {failed} failed")
    
    return results




@cli.command()
@click.argument('secrets_file')
@click.argument('sonar_token')
@click.argument('sonar_url')
@click.option('--input_directory', default='/app/files/', help="Directory to find all migration files")
@click.option('--output_directory', default=None, help="Directory to place all interim files")
def pipelines(secrets_file, sonar_token, sonar_url, input_directory, output_directory):
    with open(os.path.join(input_directory, secrets_file), 'rt') as f:
        secrets = json.load(f)
    extract_mapping = get_unique_extracts(directory=input_directory, key='plan.json')

    if output_directory is None:
        output_directory = input_directory
    if extract_mapping:
        pipeline_dir = os.path.join(input_directory, str(max(extract_mapping.values())))
    elif os.path.exists(os.path.join(input_directory, 'generateOrganizationMappings')):
        pipeline_dir = input_directory
    else:
        click.echo("No Migrations Found")
        return
    run_id = str(int(datetime.now(UTC).timestamp()))
    run_dir = os.path.join(output_directory, run_id)
    os.makedirs(run_dir, exist_ok=True)
    loop = asyncio.get_event_loop()
    configure_logger(name='http_request', level='INFO', output_file=os.path.join(pipeline_dir, 'requests.log'))
    results = loop.run_until_complete(
        update_pipelines(
            input_directory=pipeline_dir, output_directory=run_dir, org_secret_mapping=secrets, sonar_token=sonar_token,
            sonar_url=sonar_url
        )
    )
    click.echo(f"Repositories Updated: {list(results.keys())}")


if __name__ == '__main__':
    cli()
