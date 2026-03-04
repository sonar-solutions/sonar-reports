def get_config_file_name():
    return 'build.gradle.kts', 'build.gradle'


def update_content(content, projects, project_mappings):
    return dict(updated_content=content, is_updated=False)
