#!/usr/bin/env python3
"""Publish Blackout Protocol web tools and inject the developer shortcut/WebGL preflight."""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

MARKER = "BLACKOUT_WEBGL_PREFLIGHT_V16"
ASSET_MENU_MARKER = "BLACKOUT_ASSET_GENERATOR_MENU_V2"
DEVELOPER_MENU_MARKER = "BLACKOUT_DEVELOPER_MENU_V1"
PUBLISHED_WEB_FILES = (
    "developer.html",
    "asset-generator.html",
    "asset-autodetect.js",
    "github-direct-submit.js",
)

STYLE_AND_SCRIPT = r'''
<!-- BLACKOUT_WEBGL_PREFLIGHT_V16 -->
<!-- BLACKOUT_ASSET_GENERATOR_MENU_V2 -->
<!-- BLACKOUT_DEVELOPER_MENU_V1 -->
<style>
#blackout-webgl-error{position:fixed;inset:0;z-index:2147483647;display:none;align-items:center;justify-content:center;padding:24px;box-sizing:border-box;background:linear-gradient(rgba(0,19,31,.95),rgba(0,8,15,.985));color:#b9e9ff;font-family:ui-monospace,"Cascadia Mono",Consolas,monospace}
#blackout-webgl-error .bp-card{width:min(760px,96vw);border:1px solid #2c91bd;box-shadow:0 0 32px rgba(0,151,215,.22);padding:28px 30px;background:rgba(2,18,29,.96)}
#blackout-webgl-error h1{margin:0 0 8px;color:#72d8ff;font-size:clamp(24px,4vw,38px)}
#blackout-webgl-error p,#blackout-webgl-error li{line-height:1.55}
#blackout-webgl-error button{margin-top:14px;padding:11px 18px;border:1px solid #5bd3ff;background:#052739;color:#d5f5ff;font:inherit;cursor:pointer}
#blackout-developer-menu-link{position:fixed;top:12px;right:12px;z-index:2147483000;display:inline-flex;align-items:center;gap:8px;padding:11px 14px;border:1px solid #58d1ff;border-radius:8px;color:#e2f8ff;background:rgba(4,27,41,.94);box-shadow:0 0 22px rgba(46,178,229,.22);text-decoration:none;font:800 12px/1 ui-monospace,"Cascadia Mono",Consolas,monospace}
#blackout-developer-menu-link:hover{background:rgba(11,66,91,.98);border-color:#ffb02e}@media(max-width:720px){#blackout-developer-menu-link{top:8px;right:8px;padding:9px 10px;font-size:10px}}
</style>
<script>
(()=>{"use strict";
 const params=new URLSearchParams(window.location.search);
 const developerMode=["1","true","worldforge"].includes(String(params.get("dev")||"").toLowerCase());
 const addDeveloperMenu=()=>{if(!developerMode||document.getElementById("blackout-developer-menu-link"))return;const link=document.createElement("a");link.id="blackout-developer-menu-link";link.href="./developer.html";link.textContent="☰ MENU DÉVELOPPEUR";link.title="Portail WorldForge, génération 3D, jeu normal et diagnostics";document.body.appendChild(link)};
 const showError=()=>{let panel=document.getElementById("blackout-webgl-error");if(!panel){panel=document.createElement("section");panel.id="blackout-webgl-error";panel.setAttribute("role","alert");panel.innerHTML='<div class="bp-card"><div style="color:#ffc343;font-weight:700">TOYGUARD S-01 // ERREUR GRAPHIQUE</div><h1>WEBGL2 INDISPONIBLE</h1><p>Le moteur Godot 4 ne peut pas créer le rendu 3D. Activez l’accélération graphique, redémarrez le navigateur puis rechargez avec Ctrl+F5.</p><button type="button" onclick="location.reload()">RELANCER LE PROTOCOLE</button></div>';document.body.appendChild(panel)}panel.style.display="flex"};
 const check=()=>{addDeveloperMenu();try{const canvas=document.createElement("canvas");const gl=canvas.getContext("webgl2",{alpha:false,antialias:false,depth:false,stencil:false});if(!gl)showError()}catch(error){console.error("BLACKOUT_WEBGL_PREFLIGHT",error);showError()}};
 document.readyState==="loading"?document.addEventListener("DOMContentLoaded",check,{once:true}):check();
})();
</script>
'''


def publish_web_tools(html_path: Path) -> None:
    root = Path(__file__).resolve().parent.parent
    web_root = root / "web"
    for filename in PUBLISHED_WEB_FILES:
        source = web_root / filename
        destination = html_path.parent / filename
        if not source.is_file():
            raise FileNotFoundError(f"Web tool source not found: {source}")
        shutil.copyfile(source, destination)
        minimum = 4096 if filename.endswith(".html") else 1024
        if destination.stat().st_size < minimum:
            raise RuntimeError(f"Published web tool is unexpectedly small: {destination}")
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
        publish_web_tools(html_path)
    except Exception as exc:
        print(f"Could not publish web tools: {exc}", file=sys.stderr)
        return 1
    html = html_path.read_text(encoding="utf-8")
    markers = (MARKER, ASSET_MENU_MARKER, DEVELOPER_MENU_MARKER)
    if any(marker not in html for marker in markers):
        if "</head>" not in html:
            print("Generated Web shell has no </head> tag", file=sys.stderr)
            return 1
        html = html.replace("</head>", f"{STYLE_AND_SCRIPT}\n</head>", 1)
        html_path.write_text(html, encoding="utf-8")
        print(f"Injected {', '.join(markers)} into {html_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
