"""Fingerprint the actual export, including the playable pack and engine."""
import hashlib, json, pathlib, sys
folder = pathlib.Path(sys.argv[1])
files = ["index.html", "index.js", "index.pck", "index.wasm", "developer.html", "asset-generator.html"]
result = {"commit": sys.argv[2], "build": "nightshift-v22", "files": {}}
for name in files:
    data = (folder / name).read_bytes()
    result["files"][name] = {"sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
(folder / "build-info.json").write_text(json.dumps(result, indent=2))
