#!/usr/bin/env python3
"""Inject a visible WebGL2 preflight into Godot's generated Web shell."""

from __future__ import annotations

import sys
from pathlib import Path

MARKER = "BLACKOUT_WEBGL_PREFLIGHT_V15"

STYLE_AND_SCRIPT = r'''
<!-- BLACKOUT_WEBGL_PREFLIGHT_V15 -->
<style>
  #blackout-webgl-error {
    position: fixed;
    inset: 0;
    z-index: 2147483647;
    display: none;
    align-items: center;
    justify-content: center;
    padding: 24px;
    box-sizing: border-box;
    background:
      linear-gradient(rgba(0, 19, 31, .95), rgba(0, 8, 15, .985)),
      repeating-linear-gradient(0deg, transparent 0 3px, rgba(91, 202, 255, .035) 3px 4px);
    color: #b9e9ff;
    font-family: ui-monospace, "Cascadia Mono", Consolas, monospace;
  }
  #blackout-webgl-error .bp-card {
    width: min(760px, 96vw);
    border: 1px solid #2c91bd;
    box-shadow: 0 0 32px rgba(0, 151, 215, .22), inset 0 0 28px rgba(0, 77, 112, .16);
    padding: 28px 30px;
    background: rgba(2, 18, 29, .96);
  }
  #blackout-webgl-error h1 {
    margin: 0 0 8px;
    color: #72d8ff;
    font-size: clamp(24px, 4vw, 38px);
    letter-spacing: .06em;
  }
  #blackout-webgl-error .bp-alert {
    color: #ffc343;
    font-weight: 700;
    letter-spacing: .05em;
  }
  #blackout-webgl-error p,
  #blackout-webgl-error li {
    line-height: 1.55;
  }
  #blackout-webgl-error button {
    margin-top: 14px;
    padding: 11px 18px;
    border: 1px solid #5bd3ff;
    background: #052739;
    color: #d5f5ff;
    font: inherit;
    cursor: pointer;
  }
</style>
<script>
(() => {
  "use strict";
  const showCompatibilityError = () => {
    let panel = document.getElementById("blackout-webgl-error");
    if (!panel) {
      panel = document.createElement("section");
      panel.id = "blackout-webgl-error";
      panel.setAttribute("role", "alert");
      panel.innerHTML = `
        <div class="bp-card">
          <div class="bp-alert">TOYGUARD S-01 // ERREUR GRAPHIQUE</div>
          <h1>WEBGL2 INDISPONIBLE</h1>
          <p>Le moteur Godot 4 ne peut pas créer le rendu 3D dans ce navigateur. Le jeu n'est pas bloqué par le chargement : l'accélération graphique WebGL2 est absente ou désactivée.</p>
          <ol>
            <li>Dans Firefox : <strong>Paramètres → Général → Performances</strong>, activez l'accélération graphique matérielle.</li>
            <li>Redémarrez Firefox puis rechargez cette page avec <strong>Ctrl+F5</strong>.</li>
            <li>Si le problème persiste, ouvrez <strong>about:config</strong> et vérifiez que <strong>webgl.disabled</strong> vaut <strong>false</strong>.</li>
            <li>Vous pouvez aussi tester une version récente de Firefox, Chrome ou Edge.</li>
          </ol>
          <button type="button" onclick="location.reload()">RELANCER LE PROTOCOLE</button>
        </div>`;
      document.body.appendChild(panel);
    }
    panel.style.display = "flex";
    document.documentElement.dataset.blackoutWebgl2 = "unavailable";
  };

  const checkWebGL2 = () => {
    try {
      const probe = document.createElement("canvas");
      const context = probe.getContext("webgl2", {
        alpha: false,
        antialias: false,
        depth: false,
        stencil: false,
        failIfMajorPerformanceCaveat: false,
      });
      if (!context) {
        showCompatibilityError();
        return;
      }
      document.documentElement.dataset.blackoutWebgl2 = "available";
    } catch (error) {
      console.error("BLACKOUT_WEBGL_PREFLIGHT", error);
      showCompatibilityError();
    }
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", checkWebGL2, { once: true });
  } else {
    checkWebGL2();
  }
})();
</script>
'''


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: patch_web_shell.py <index.html>", file=sys.stderr)
        return 2

    html_path = Path(sys.argv[1])
    if not html_path.is_file():
        print(f"Web shell not found: {html_path}", file=sys.stderr)
        return 2

    html = html_path.read_text(encoding="utf-8")
    if MARKER in html:
        print("WebGL2 preflight already present")
        return 0
    if "</head>" not in html:
        print("Generated Web shell has no </head> tag", file=sys.stderr)
        return 1

    html = html.replace("</head>", f"{STYLE_AND_SCRIPT}\n</head>", 1)
    html_path.write_text(html, encoding="utf-8")
    print(f"Injected {MARKER} into {html_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
