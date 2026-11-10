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
elif 'connection up' in a: pathlib.Path(os.environ['MOCK_AUTH']).write_text(sys.stdin.read()); print('connected')
elif 'vpn.user-name' in a: print('')
''')
    nm.chmod(0o755)
    ip = base / 'bin/ip'; ip.write_text('#!/bin/sh\necho "[]"\n'); ip.chmod(0o755)
    secret = base / 'bin/secret-tool'
    secret.write_text("#!/usr/bin/env python3\nimport os, pathlib, sys\np=pathlib.Path(os.environ['MOCK_SECRET'])\nif sys.argv[1]=='store': p.write_text(sys.stdin.read())\nelif sys.argv[1]=='lookup': print(p.read_text())\nelif sys.argv[1]=='clear': p.unlink(missing_ok=True)\n")
    secret.chmod(0o755)
    notify = base / 'bin/notify-send'; notify.write_text('#!/bin/sh\nexit 0\n'); notify.chmod(0o755)
    env = {**os.environ, 'HOME': str(base), 'PATH': str(base / 'bin') + ':' + os.environ['PATH'], 'MOCK_CAPTURE': str(base / 'capture'), 'MOCK_AUTH': str(base / 'auth'), 'MOCK_SECRET': str(base / 'secret')}
    def call(req):
        p = subprocess.run([str(exe)], input=json.dumps(req)+'\n', text=True, capture_output=True, check=True, env=env)
        return json.loads(p.stdout)
    status = call({'action':'status'})
    assert status['ok'] and [p['name'] for p in status['result']['profiles']] == ['Office', 'Remote']
    assert call({'action':'select','uuid':u2})['ok']
    assert (base / '.local/share/work-vpn/selected-uuid').read_text() == u2
    assert not call({'action':'select','uuid':'not-a-profile'})['ok']
    config = base / 'work.ovpn'; config.write_text('client\n<ca>\ntest-ca\n</ca>\nremote-cert-tls server\nroute remote_host 255.255.255.255 net_gateway\nremote vpn.example.test 8443\n')
    assert call({'action':'import','file':str(config)})['ok']
    assert (base / '.local/share/work-vpn/selected-uuid').read_text() == u3
    normalized = (base / 'capture').read_text()
    assert 'route remote_host' not in normalized and 'remote vpn.example.test 8443' in normalized
    assert 'route remote_host' in config.read_text()
    bad = base / 'unsafe.ovpn'; bad.write_text('client\nup /tmp/evil\n')
    assert not call({'action':'import','file':str(bad)})['ok']
    unverified = base / 'unverified.ovpn'; unverified.write_text('client\nremote vpn.example.test 8443\n')
    assert not call({'action':'import','file':str(unverified)})['ok']
    hidden = base / 'hidden.ovpn'; hidden.write_text('client\n<connection>\nup /tmp/evil\n</connection>\n')
    assert not call({'action':'import','file':str(hidden)})['ok']
    result = call({'action':'connect','username':'tester','password':'private-pass','otp':'123456','save':True})
    assert result['ok'], result
    assert (base / 'auth').read_text() == 'vpn.secrets.password:private-pass123456\n'
    assert (base / 'secret').read_text() == 'private-pass'
    assert not call({'action':'connect','password':'private-pass','otp':'abc','save':True})['ok']
    assert call({'action':'forget'})['ok'] and not (base / 'secret').exists()
print('Backend profile, import, and credential tests passed.')
