import json
import os
import uuid
from constants import PLUGINS
from collections import defaultdict
from utils import multi_extract_object_reader, get_unique_extracts
from parser import extract_path_value
from google.protobuf.internal.encoder import _VarintBytes
from datetime import datetime, UTC
from google.protobuf import json_format
from protobufs.scanner_report_pb2 import Metadata, Component, Measure, ActiveRule, Changesets, LineCoverage, Issue, \
    Duplication, LineCoverage
import itertools

component_measures = ['classes', 'functions', 'complexity', 'comment_lines', 'statements', 'ncloc',
                      'cognitive_complexity', 'executable_lines_data', 'ncloc_data']
directory = '../files/'

extract_mapping = get_unique_extracts(directory=directory)
migration_mapping = get_unique_extracts(directory=directory, key='migration.json')

server_projects = defaultdict(lambda: defaultdict(lambda: defaultdict(list)))
run_id = int(datetime.now(UTC).timestamp())
result_dir = os.path.join(directory, str(run_id))
os.makedirs(result_dir, exist_ok=True)

def get_new_projects(extract_directory, mapping):
    for url, analysis in multi_extract_object_reader(directory=extract_directory, mapping=mapping,
                                                     key='getProjectAnalyses'):


def extract_project_scans(*, project_orgs, project_quality_profiles, result_dir, extract_directory, mapping, ):
    projects = defaultdict(list)
    for url, analysis in multi_extract_object_reader(directory=extract_directory, mapping=mapping,
                                                     key='getProjectAnalyses'):
        key = analysis['projectKey']
        new_key = key
        project_dir = str(os.path.join(result_dir, new_key))
        os.makedirs(project_dir, exist_ok=True)
        new_analysis = dict(revision=analysis.get('revision'), version=analysis.get('projectVersion'), date=datetime.fromisoformat(analysis['date']))
        projects[key].append(new_analysis)
        os.makedirs(os.path.join(project_dir, str(int(new_analysis['date'].timestamp()))), exist_ok=True)
        metadata = Metadata()
        metadata_json = {
            "analysisDate": int(new_analysis['date'].timestamp() * 1000),
            "organizationKey": project_orgs[analysis['projectKey']],
            "projectKey": new_key,
            "rootComponentRef": 1,
            "modulesProjectRelativePathByKey": {
                new_key: ""
            },
            "qprofilesPerLanguage": project_quality_profiles[new_key],
            "pluginsByKey": {i['key']: i for i in PLUGINS},
            "projectVersion": new_analysis['revision'],
            "scmRevisionId": new_analysis['revision'] if new_analysis['revision'] else "",
            "analysisUuid": str(uuid.uuid4()),
            "analysisStartedTimestamp": int(new_analysis['date'].timestamp() * 1000) - 1000
        }
        with open(os.path.join(project_dir, str(int(new_analysis['date'].timestamp())), 'metadata.pb'), 'w') as f:
            json_format.Parse(json.dumps(metadata_json), metadata)
            f.write(metadata.SerializeToString())
    return projects

extract_project_scans(result_dir=result_dir, extract_directory=directory, mapping=extract_mapping)