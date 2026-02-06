# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_data_files, collect_submodules

# Collect all submodules from src directory
hiddenimports = collect_submodules('src')
hiddenimports += [
    'httpx',
    'click',
    'markdown',
    'tenacity',
    'nacl',
    'ruamel.yaml',
    'bashlex',
    'lxml',
    # Explicitly include operations modules that are dynamically imported
    'operations.set_key',
    'operations.apply_filter',
    'operations.expand_list',
    'operations.extend_list',
    'operations.get_date',
    'operations.join_string',
    'operations.match_devops_platform',
    'operations.process_array',
    'operations.http_request',
    'operations.http_request.base',
    'operations.http_request.get',
]

# Collect data files (if any)
# Include the tasks directory with all JSON configuration files
import os
tasks_dir = os.path.join('src', 'tasks')
datas = [(tasks_dir, 'tasks')]

a = Analysis(
    ['src/main.py'],
    pathex=[],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='sonar-reports',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
