#!/usr/bin/env python3
"""Run after `flutter build web`: writes the file list and a build id into
build/web/sw.js so the service worker caches the whole app for offline use.

    python3 tool/offline.py build/web
"""
import hashlib
import json
import os
import sys

root = sys.argv[1] if len(sys.argv) > 1 else 'build/web'
skip_names = {'sw.js', 'flutter_service_worker.js', 'version.json', '.last_build_id', 'NOTICES'}
files = []
digest = hashlib.sha256()
for dirpath, _, names in os.walk(root):
    for name in sorted(names):
        path = os.path.join(dirpath, name)
        rel = os.path.relpath(path, root).replace(os.sep, '/')
        if name in skip_names or rel.endswith('.map') or rel.endswith('.symbols'):
            continue
        # The renderer (.wasm, 4-7 MB each) differs per browser: the worker
        # caches the one this device actually loaded instead of all of them.
        if rel.startswith('canvaskit/') and (rel.endswith('.wasm') or 'skwasm' in rel or 'wimp' in rel
                                             or 'webparagraph' in rel):
            continue
        if rel == 'assets/NOTICES':
            continue
        files.append(rel)
for rel in sorted(files):
    with open(os.path.join(root, rel), 'rb') as f:
        digest.update(rel.encode())
        digest.update(f.read())

sw_path = os.path.join(root, 'sw.js')
with open(sw_path, encoding='utf-8') as f:
    sw = f.read()
build = digest.hexdigest()[:12]
sw = sw.replace("const BUILD = 'dev';", "const BUILD = '%s';" % build, 1)
sw = sw.replace('const PRECACHE = [];', 'const PRECACHE = %s;' % json.dumps(sorted(files)), 1)
with open(sw_path, 'w', encoding='utf-8') as f:
    f.write(sw)
size = sum(os.path.getsize(os.path.join(root, r)) for r in files)
print('sw.js: build %s, %d files, %.1f MB precached' % (build, len(files), size / 1e6))
