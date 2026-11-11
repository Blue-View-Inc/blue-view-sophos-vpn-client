#!/usr/bin/env python3
"""Inspect an Arch package and run the packaged binaries without installing it."""
import json
import os
import pathlib
import subprocess
import sys
import tempfile

package = pathlib.Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='blueview-package-test-') as folder:
    root = pathlib.Path(folder)
    subprocess.run(['bsdtar', '-xf', str(package), '-C', str(root)], check=True)
    binary = root / 'usr/bin/sophosvpn'
    backend = root / 'usr/bin/sophosvpn-backend'
    desktop = root / 'usr/share/applications/sophosvpn.desktop'
    icon = root / 'usr/share/icons/hicolor/scalable/apps/sophosvpn.svg'
    license_dir = root / 'usr/share/licenses/blue-view-sophos-vpn-client'
    for path in (binary, backend, desktop, icon, license_dir / 'LICENSE', license_dir / 'NOTICE'):
        assert path.is_file(), f'missing {path}'
    assert os.access(binary, os.X_OK) and os.access(backend, os.X_OK)
    assert 'Exec=sophosvpn' in desktop.read_text()
    result = subprocess.run([str(backend)], input='{"action":"invalid"}\n', text=True, capture_output=True, check=True)
    assert json.loads(result.stdout)['ok'] is False
    env = {**os.environ, 'QT_QPA_PLATFORM': 'offscreen', 'QT_FORCE_STDERR_LOGGING': '1', 'XDG_CONFIG_HOME': str(root / 'config')}
    try:
        result = subprocess.run([str(binary)], capture_output=True, text=True, env=env, timeout=3)
    except subprocess.TimeoutExpired as error:
        assert not error.stderr or b'failed to load' not in error.stderr.lower()
    else:
        raise AssertionError(f'Application exited prematurely: {result.returncode} {result.stderr}')
print('Package contents and offscreen startup passed.')
