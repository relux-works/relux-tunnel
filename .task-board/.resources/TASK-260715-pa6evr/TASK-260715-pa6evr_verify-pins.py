from pathlib import Path
import hashlib,json,subprocess
root=Path.cwd()
s=json.loads(Path('relay/supply-chain-source-v1.json').read_text())
t=json.loads(Path('relay/toolchain-manifest-v1.json').read_text())
a=json.loads(Path('relay/asset-bundle-source-v1.json').read_text())
doc=Path('docs/TASK-260715-pa6evr_relay-release-input-contract.md').read_text()
for section,rev,files in [('source',s['source']['revision'],s['source']['byteAffectingFiles']),('recipe',s['build']['recipeRevision'],s['build']['recipeFiles'])]:
    for f in files:
        data=subprocess.check_output(['git','show',f'{rev}:{f["path"]}'])
        assert hashlib.sha256(data).hexdigest()==f['sha256'],f['path']
    print(f'{section}: {len(files)}/{len(files)} historical file hashes match {rev}')
for row in t['hostToolArchives']+t['buildOnlyTools'][0]['hostArchives']:
    assert row['sha256'] in doc
print('8/8 Go/Syft archive hashes match document')
assert len(a['assets'])==len(t['targets'])==4
for row in t['targets']:
    assert row['canonicalTarget'] in doc and row['goTarget'] in doc
for row in a['assets']:
    assert row['fileName'] in doc
print('4/4 target triples and names match document')
assert hashlib.sha256(Path('relay/go.mod').read_bytes()).hexdigest()==s['dependencyLock']['sha256']
for p in ['relay/manifest-v1.schema.json','relay/asset-manifest-v1.schema.json']:
    json.loads(Path(p).read_text())
print('go.mod pin matches; both existing JSON schemas parse')
for p in ['relay/go.sum','relay/vendor','.gitmodules']:
    print(f'{p}: {"present" if Path(p).exists() else "absent"} in current tree only')
for p in ['README.md','UNRESOLVED_QUESTIONS.md','docs/TASK-260715-pa6evr_relay-release-input-contract.md']:
    print(f'{p} sha256={hashlib.sha256(Path(p).read_bytes()).hexdigest()}')
print('No actual build, native runtime, scanner, signing or VPN evidence produced.')
