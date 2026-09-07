"""Reject stale Pages deployments, even when their HTML loads successfully."""
import hashlib, json, sys, time, urllib.request
base, expected = sys.argv[1].rstrip("/"), sys.argv[2]
for attempt in range(12):
    try:
        def fetch(name):
            with urllib.request.urlopen(base + "/" + name + "?release=" + expected, timeout=120) as response:
                return response.read()
        manifest = json.loads(fetch("build-info.json"))
        assert manifest["commit"] == expected, "Pages serves another commit"
        for name, item in manifest["files"].items():
            payload = fetch(name)
            assert hashlib.sha256(payload).hexdigest() == item["sha256"], "stale or altered " + name
        print("PUBLIC_RELEASE_PASS", expected, "pack, wasm, game, editor and generator match")
        break
    except Exception as error:
        if attempt == 11:
            raise
        print("Waiting for Pages cache:", error, flush=True)
        time.sleep(5)
