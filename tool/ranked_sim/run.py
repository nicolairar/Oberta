"""Runs the ranked load simulation against the real database, rolled back.

    python3 tool/ranked_sim/run.py [--with supabase/migrations/<file>.sql ...]

Reads SUPABASE_ACCESS_TOKEN from fastlane/.env and the project ref from
config/supabase.json (never printed). The simulation is one DO block that
always ends by raising an exception, so everything it did (and every
--with migration sent before it in the same request) is rolled back.
"""
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

root = pathlib.Path(__file__).resolve().parents[2]
secrets = pathlib.Path('/Users/nicolai/code/Lupus') if not (root / 'fastlane/.env').exists() else root
token = next(l.split('=', 1)[1].strip().strip('"') for l in (secrets / 'fastlane/.env').read_text().splitlines()
             if l.startswith('SUPABASE_ACCESS_TOKEN='))
url = json.loads((secrets / 'config/supabase.json').read_text())['SUPABASE_URL']
ref = re.match(r'https://([a-z0-9]+)\.', url).group(1)

extra = [pathlib.Path(p) for i, p in enumerate(sys.argv) if i > 0 and sys.argv[i - 1] == '--with']
sql = 'begin;\n' + ''.join(p.read_text() + '\n' for p in extra) + (root / 'tool/ranked_sim/load_sim.sql').read_text()

req = urllib.request.Request(
    f'https://api.supabase.com/v1/projects/{ref}/database/query',
    data=json.dumps({'query': sql}).encode(),
    headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json', 'User-Agent': 'oberta-ranked-sim'},
)
try:
    body = urllib.request.urlopen(req, timeout=300).read().decode()
    print('UNEXPECTED: the simulation did not raise (nothing should be committed, check!)', body[:500])
    sys.exit(2)
except urllib.error.HTTPError as e:
    body = e.read().decode()
try:
    message = json.loads(body).get('message', body)
except ValueError:
    message = body
at = message.find('SIM_RESULT ')
if at < 0:
    print(message[:4000])
    sys.exit(1)
result, _ = json.JSONDecoder().raw_decode(message[at + len('SIM_RESULT '):])
for entry in result['log']:
    print(json.dumps(entry))
print('games:', json.dumps(result['games']))
print('online_counts:', json.dumps(result.get('online_counts')))
print('still waiting:', json.dumps(result['still_waiting']))
