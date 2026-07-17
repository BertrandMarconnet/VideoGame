#!/usr/bin/env python3
"""Publish the asset-generator web app and inject the game-page shortcut/WebGL preflight."""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

MARKER = "BLACKOUT_WEBGL_PREFLIGHT_V16"
ASSET_MENU_MARKER = "BLACKOUT_ASSET_GENERATOR_MENU_V2"
ASSET_FILES = (
    "asset-generator.html",
    "asset-autodetect.js",
    "github-direct-submit.js",
)

STYLE_AND_SCRIPT = r'''
<!-- BLACKOUT_WEBGL_PREFLIGHT_V16 -->
<!-- BLACKOUT_ASSET_GENERATOR_MENU_V2 -->
<style>
#blackout-webgl-error{position:fixed;inset:0;z-index:2147483647;display:none;align-items:center;justify-content:center;padding:24px;box-sizing:border-box;background:linear-gradient(rgba(0,19,31,.95),rgba(0,8,15,.985));color:#b9e9ff;font-family:ui-monospace,"Cascadia Mono",Consolas,monospace}
#blackout-webgl-error .bp-card{width:min(760px,96vw);border:1px solid #2c91bd;box-shadow:0 0 32px rgba(0,151,215,.22);padding:28px 30px;background:rgba(2,18,29,.96)}
#blackout-webgl-error h1{margin:0 0 8px;color:#72d8ff;font-size:clamp(24px,4vw,38px)}
#blackout-webgl-error p,#blackout-webgl-error li{line-height:1.55}
#blackout-webgl-error button{margin-top:14px;padding:11px 18px;border:1px solid #5bd3ff;background:#052739;color:#d5f5ff;font:inherit;cursor:pointer}
#blackout-asset-generator-link{position:fixed;top:12px;right:12px;z-index:2147483000;display:inline-flex;align-items:center;gap:8px;padding:10px 13px;border:1px solid #58d1ff;border-radius:7px;color:#e2f8ff;background:rgba(4,27,41,.92);box-shadow:0 0 22px rgba(46,178,229,.22);text-decoration:none;font:700 12px/1 ui-monospace,"Cascadia Mono",Consolas,monospace}
#blackout-asset-generator-link:hover{background:rgba(11,66,91,.96);border-color:#ffb02e}@media(max-width:720px){#blackout-asset-generator-link{top:8px;right:8px;padding:9px 10px;font-size:10px}}
</style>
<script>
(()=>{"use strict";
 const addLink=()=>{if(document.getElementById("blackout-asset-generator-link"))return;const link=document.createElement("a");link.id="blackout-asset-generator-link";link.href="./asset-generator.html";link.target="_blank";link.rel="noopener";link.textContent="⚙ GÉNÉRER UN ASSET 3D";link.title="Analyser les images et lancer directement la génération GitHub";document.body.appendChild(link)};
 const showError=()=>{let panel=document.getElementById("blackout-webgl-error");if(!panel){panel=document.createElement("section");panel.id="blackout-webgl-error";panel.setAttribute("role","alert");panel.innerHTML='<div class="bp-card"><div style="color:#ffc343;font-weight:700">TOYGUARD S-01 // ERREUR GRAPHIQUE</div><h1>WEBGL2 INDISPONIBLE</h1><p>Le moteur Godot 4 ne peut pas créer le rendu 3D. Activez l’accélération graphique, redémarrez le navigateur puis rechargez avec Ctrl+F5.</p><button type="button" onclick="location.reload()">RELANCER LE PROTOCOLE</button></div>';document.body.appendChild(panel)}panel.style.display="flex"};
 const check=()=>{addLink();try{const canvas=document.createElement("canvas");const gl=canvas.getContext("webgl2",{alpha:false,antialias:false,depth:false,stencil:false});if(!gl)showError()}catch(error){console.error("BLACKOUT_WEBGL_PREFLIGHT",error);showError()}};
 document.readyState==="loading"?document.addEventListener("DOMContentLoaded",check,{once:true}):check();
})();
</script>
'''


def publish_asset_generator(html_path: Path) -> None:
    root = Path(__file__).resolve().parent.parent
    web_root = root / "web"
    for filename in ASSET_FILES:
        source = web_root / filename
        destination = html_path.parent / filename
        if not source.is_file():
            raise FileNotFoundError(f"Asset generator source not found: {source}")
        shutil.copyfile(source, destination)
        minimum = 4096 if filename.endswith(".html") else 1024
        if destination.stat().st_size < minimum:
            raise RuntimeError(f"Published asset generator file is unexpectedly small: {destination}")
        print(f"Published {filename} to {destination}")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: patch_web_shell.py <index.html>", file=sys.stderr)
        return 2
    html_path = Path(sys.argv[1])
    if not html_path.is_file():
        print(f"Web shell not found: {html_path}", file=sys.stderr)
        return 2
    try:
        publish_asset_generator(html_path)
    except Exception as exc:
        print(f"Could not publish asset generator: {exc}", file=sys.stderr)
        return 1
    html = html_path.read_text(encoding="utf-8")
    if MARKER not in html or ASSET_MENU_MARKER not in html:
        if "</head>" not in html:
            print("Generated Web shell has no </head> tag", file=sys.stderr)
            return 1
        html = html.replace("</head>", f"{STYLE_AND_SCRIPT}\n</head>", 1)
        html_path.write_text(html, encoding="utf-8")
        print(f"Injected {MARKER} and {ASSET_MENU_MARKER} into {html_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
