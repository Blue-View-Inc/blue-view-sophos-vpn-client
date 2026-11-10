#!/usr/bin/env python3
import json, os, pathlib, subprocess, tempfile

root = pathlib.Path(__file__).resolve().parents[1]
exe = root / 'build/sophosvpn-backend'
u1 = '11111111-1111-4111-8111-111111111111'
u2 = '22222222-2222-4222-8222-222222222222'
u3 = '33333333-3333-4333-8333-333333333333'
with tempfile.TemporaryDirectory() as d:
    base = pathlib.Path(d)
    (base / 'bin').mkdir()
    nm = base / 'bin/nmcli'
    nm.write_text('''#!/usr/bin/env python3
import os, pathlib, sys
args=sys.argv[1:]
a=' '.join(args)
u1='11111111-1111-4111-8111-111111111111'
u2='22222222-2222-4222-8222-222222222222'
u3='33333333-3333-4333-8333-333333333333'
if 'UUID,TYPE connection show --active' in a: print('')
elif 'UUID,TYPE connection show' in a: print(u1+':vpn\\n'+u2+':vpn')
elif 'vpn.service-type' in a: print('org.freedesktop.NetworkManager.openvpn')
elif 'connection.id' in a and 'connection show' in a: print('Office' if u1 in args else 'Remote')
elif 'connection import' in a:
 p=pathlib.Path(args[-1]); pathlib.Path(os.environ['MOCK_CAPTURE']).write_text(p.read_text()); print("Connection 'test' ("+u3+") successfully added.")
elif 'vpn.user-name' in a: print('')
''')
    nm.chmod(0o755)
    ip = base / 'bin/ip'; ip.write_text('#!/bin/sh\necho "[]"\n'); ip.chmod(0o755)
    env = {**os.environ, 'HOME': str(base), 'PATH': str(base / 'bin') + ':' + os.environ['PATH'], 'MOCK_CAPTURE': str(base / 'capture')}
    def call(req):
        p = subprocess.run([str(exe)], input=json.dumps(req)+'\n', text=True, capture_output=True, check=True, env=env)
        return json.loads(p.stdout)
    status = call({'action':'status'})
    assert status['ok'] and [p['name'] for p in status['result']['profiles']] == ['Office', 'Remote']
    assert call({'action':'select','uuid':u2})['ok']
    assert (base / '.local/share/work-vpn/selected-uuid').read_text() == u2
    assert not call({'action':'select','uuid':'not-a-profile'})['ok']
    config = base / 'work.ovpn'; config.write_text('client\nroute remote_host 255.255.255.255 net_gateway\nremote vpn.example.test 8443\n')
    assert call({'action':'import','file':str(config)})['ok']
    assert (base / '.local/share/work-vpn/selected-uuid').read_text() == u3
    normalized = (base / 'capture').read_text()
    assert 'route remote_host' not in normalized and 'remote vpn.example.test 8443' in normalized
    assert 'route remote_host' in config.read_text()
print('Backend profile selection and import smoke test passed.')
