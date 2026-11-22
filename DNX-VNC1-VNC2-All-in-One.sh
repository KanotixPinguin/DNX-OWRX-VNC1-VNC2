#!/usr/bin/env bash
# DNX VNC1/VNC2 Module – private, unofficial hobby customization.
# Not an OpenWebRX/OpenWebRX+ or noVNC project and not an official plugin.
# No affiliation, endorsement or warranty. Use entirely at your own risk.
# License: MIT
set -Eeuo pipefail

VERSION="1.0.1"
MODULE="dnx-vnc-module"
START_JS="/* DNX_VNC_PUBLIC_MODULE_START */"
END_JS="/* DNX_VNC_PUBLIC_MODULE_END */"
MODE="auto"; SCOPE="frontend"; CONTAINER="owrx-8013"; PLUGIN_INIT=""
VNC1_HOST="192.0.2.20"; VNC1_PORT=5900; VNC2_HOST="192.0.2.72"; VNC2_PORT=5900
BRIDGE1=6082; BRIDGE2=6083; LABEL1="VNC1"; LABEL2="VNC2"; INSTALL_DEPS=0; DRY_RUN=0; YES=0
PREFIX="/opt/dnx-vnc-module"; SERVICE="dnx-vnc-module.service"
EXTRA_ARGS=()

log(){ printf '\033[1;36m[DNX-VNC]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[WARNUNG]\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31m[FEHLER]\033[0m %s\n' "$*" >&2; exit 1; }
run(){ if ((DRY_RUN)); then printf '[DRY-RUN] '; printf '%q ' "$@"; printf '\n'; else "$@"; fi; }
need_root(){ [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Bitte als root oder mit sudo ausführen."; }
stamp(){ date +%F-%H%M%S; }

usage(){ cat <<'EOF'
DNX VNC1/VNC2 Module – private, inoffizielle Hobby-Anpassung

WICHTIGER HINWEIS:
  Rein privates, unabhängiges Hobbyprojekt. Kein Projekt, Produkt oder offizielles
  Plugin von OpenWebRX, OpenWebRX+, noVNC, websockify oder TightVNC. Keine
  Verbindung, Beauftragung, Unterstützung, Prüfung oder Empfehlung durch deren
  Entwickler oder Rechteinhaber. Der Autor handelt nur als privater Hobby-
  Anwender beziehungsweise unabhängiger Moderator. Nutzung und Änderungen
  vollständig auf eigene Gefahr. Soweit gesetzlich zulässig keine Haftung für
  Schäden, Ausfälle, Datenverlust, Sicherheitsprobleme oder Rechtsfolgen.
  Vorher Backups erstellen und zunächst auf einem Testsystem prüfen.

Aufruf:
  sudo ./dnx-vnc-module.sh BEFEHL [OPTIONEN]

Befehle:
  install       Anzeige oder Komplettsystem installieren
  update        Frontend/Service mit aktuellen Optionen neu erzeugen
  uninstall     Modul entfernen
  status        Dateien, Service, Ports und Ziele prüfen
  backup        betroffene Frontenddatei sichern
  restore DATEI Frontend-Backup wiederherstellen
  help          ausführliche Kurzreferenz

Installationsumfang:
  --scope frontend   nur OpenWebRX-Anzeige; vorhandene Bridges vorausgesetzt
  --scope full       Anzeige plus systemd-websockify-Bridges

Zielsystem:
  --mode auto|docker|native
  --container NAME               Standard: owrx-8013
  --plugin-init DATEI            expliziter Pfad zu receiver/init.js

VNC-Ziele und Bridge-Ports:
  --vnc1-host IP/NAME            Standard: 192.0.2.20
  --vnc1-port PORT               Standard: 5900
  --vnc2-host IP/NAME            Standard: 192.0.2.72
  --vnc2-port PORT               Standard: 5900
  --bridge1 PORT                 Standard: 6082
  --bridge2 PORT                 Standard: 6083
  --label1 TEXT                  Standard: VNC1
  --label2 TEXT                  Standard: VNC2
  --install-deps                 apt install websockify novnc erlauben
  --yes                          Rückfragen bestätigen
  --dry-run                      nur Aktionen anzeigen

Beispiele:
  sudo ./dnx-vnc-module.sh install --mode docker --scope frontend --container owrx-8013
  sudo ./dnx-vnc-module.sh install --mode docker --scope full --container owrx-8013 \
    --vnc1-host 192.0.2.20 --vnc1-port 5900 \
    --vnc2-host 192.0.2.72 --vnc2-port 5900
  sudo ./dnx-vnc-module.sh status --scope full
  sudo ./dnx-vnc-module.sh uninstall --mode docker --scope full

Funktionen der Anzeige:
  VNC1/VNC2 AN/AUS, automatische große Einzelansicht, Zwei-Spalten-Raster,
  echte Neuverbindung beim Wiedereinschalten, noVNC-Reconnect, responsive Höhe,
  verschiebbare Schalter, Vollbild-Links und lokale Speicherung der Schalter.
EOF
}

parse(){
  COMMAND="${1:-help}"; [[ $# -gt 0 ]] && shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode) MODE="${2:?}"; shift 2;; --scope) SCOPE="${2:?}"; shift 2;;
      --container) CONTAINER="${2:?}"; shift 2;; --plugin-init) PLUGIN_INIT="${2:?}"; shift 2;;
      --vnc1-host) VNC1_HOST="${2:?}"; shift 2;; --vnc1-port) VNC1_PORT="${2:?}"; shift 2;;
      --vnc2-host) VNC2_HOST="${2:?}"; shift 2;; --vnc2-port) VNC2_PORT="${2:?}"; shift 2;;
      --bridge1) BRIDGE1="${2:?}"; shift 2;; --bridge2) BRIDGE2="${2:?}"; shift 2;;
      --label1) LABEL1="${2:?}"; shift 2;; --label2) LABEL2="${2:?}"; shift 2;;
      --install-deps) INSTALL_DEPS=1; shift;; --yes|-y) YES=1; shift;; --dry-run) DRY_RUN=1; shift;;
      --version) echo "$VERSION"; exit 0;; -h|--help) usage; exit 0;;
      *) EXTRA_ARGS+=("$1"); shift;;
    esac
  done
  [[ "$MODE" =~ ^(auto|docker|native)$ ]] || die "Ungültiger Modus: $MODE"
  [[ "$SCOPE" =~ ^(frontend|full)$ ]] || die "Ungültiger Umfang: $SCOPE"
  for p in "$VNC1_PORT" "$VNC2_PORT" "$BRIDGE1" "$BRIDGE2"; do [[ "$p" =~ ^[0-9]+$ ]] && ((p>0&&p<65536)) || die "Ungültiger Port: $p"; done
  [[ "$BRIDGE1" != "$BRIDGE2" ]] || die "Bridge-Ports müssen verschieden sein."
}

detect(){
  if [[ "$MODE" == auto ]]; then
    if command -v docker >/dev/null 2>&1 && docker inspect "$CONTAINER" >/dev/null 2>&1; then MODE=docker; else MODE=native; fi
  fi
  if [[ "$MODE" == docker ]]; then
    docker inspect "$CONTAINER" >/dev/null 2>&1 || die "Container '$CONTAINER' nicht gefunden."
    if [[ -z "$PLUGIN_INIT" ]]; then
      local src; src="$(docker inspect "$CONTAINER" --format '{{range .Mounts}}{{if eq .Destination "/usr/lib/python3/dist-packages/htdocs/plugins"}}{{.Source}}{{end}}{{end}}')"
      [[ -n "$src" ]] || die "Plugin-Bind-Mount nicht erkannt; --plugin-init angeben."
      PLUGIN_INIT="$src/receiver/init.js"
    fi
  else
    if [[ -z "$PLUGIN_INIT" ]]; then
      for p in /usr/lib/python3/dist-packages/htdocs/plugins/receiver/init.js /usr/local/lib/python*/dist-packages/htdocs/plugins/receiver/init.js /opt/openwebrx/htdocs/plugins/receiver/init.js; do [[ -f $p ]] && { PLUGIN_INIT="$p"; break; }; done
    fi
  fi
  [[ -n "$PLUGIN_INIT" && -f "$PLUGIN_INIT" ]] || die "receiver/init.js nicht gefunden; --plugin-init angeben."
  log "Modus: $MODE"; log "Frontend: $PLUGIN_INIT"
}

backup(){ local f="$1"; [[ -e $f ]] || return 0; local b="${f}.backup-${MODULE}-$(stamp)"; run cp -a "$f" "$b"; log "Backup: $b"; }

remove_block(){
  local f="$1"; python3 - "$f" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);t=p.read_text();a="/* DNX_VNC_PUBLIC_MODULE_START */";b="/* DNX_VNC_PUBLIC_MODULE_END */"
if a in t and b in t:
 x,y=t.split(a,1);_,z=y.split(b,1);p.write_text(x+z)
PY
}

js_escape(){ python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }

write_frontend(){
  local out="$1" l1 l2; l1=$(js_escape "$LABEL1"); l2=$(js_escape "$LABEL2")
  cat >"$out" <<JS
/* DNX_VNC_PUBLIC_MODULE_START */
(function(){"use strict";
if(window.__dnxVncPublicModule)return;window.__dnxVncPublicModule=true;
var P1=$BRIDGE1,P2=$BRIDGE2,L1=$l1,L2=$l2,STORE="dnx.vnc.public.v1";
var state={one:true,two:true};try{Object.assign(state,JSON.parse(localStorage.getItem(STORE)||"{}"));}catch(e){}
function save(){try{localStorage.setItem(STORE,JSON.stringify(state));}catch(e){}}
function url(p){return location.protocol+"//"+location.hostname+":"+p+"/vnc_lite.html?autoconnect=1&resize=scale&view_only=1&reconnect=1&reconnect_delay=2000&quality=7&compression=2"}
function style(){if(document.getElementById("dnx-vnc-public-style"))return;var s=document.createElement("style");s.id="dnx-vnc-public-style";s.textContent=`
#dnx-vnc-public{width:100%;box-sizing:border-box;margin:10px 0;background:transparent}.dvp-vnc-controls{display:flex;justify-content:center;gap:12px;flex-wrap:wrap;margin:5px 0 10px}.dvp-vnc-btn{min-width:160px;height:36px;border:1px solid #ffffff77;border-radius:9px;color:#fff;font-weight:900;cursor:grab;position:relative;z-index:20;touch-action:none}.dvp-vnc-on{background:linear-gradient(90deg,#16964a,#39d175)}.dvp-vnc-off{background:linear-gradient(90deg,#8b2020,#d74646)}.dvp-vnc-links{text-align:center;margin-bottom:7px}.dvp-vnc-links a{color:#c8f5ff;margin:0 9px;font-weight:700}.dvp-vnc-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}.dvp-vnc-grid.single{grid-template-columns:minmax(0,1400px);justify-content:center}.dvp-vnc-box{height:clamp(360px,34vw,620px);position:relative;overflow:hidden;background:#111}.dvp-vnc-grid.single .dvp-vnc-box{height:clamp(520px,68vh,850px)}.dvp-vnc-box iframe{position:absolute;inset:0;width:100%;height:100%;border:0;background:#111}.dvp-vnc-hidden{display:none!important}.dvp-vnc-empty{text-align:center;padding:25px;background:#0006;color:#fff;border-radius:9px}@media(max-width:1100px){.dvp-vnc-grid{grid-template-columns:1fr}.dvp-vnc-box,.dvp-vnc-grid.single .dvp-vnc-box{height:clamp(420px,65vh,760px)}}
`;document.head.appendChild(s)}
function reload(box){var f=box.querySelector("iframe"),src=f.dataset.src||f.getAttribute("src");f.dataset.src=src;f.src="about:blank";setTimeout(function(){f.src=src},150)}
function draggable(btn){var POS_K="dnx.vnc.btn.pos.v1",x=0,y=0,sx,sy,bx,by,drag=false,moved=false;btn.title="Klick = VNC ein/aus · Ziehen = Button verschieben · Doppelklick = Zurücksetzen";function saveP(){try{var m=JSON.parse(localStorage.getItem(POS_K)||"{}");m[btn.dataset.n]={x:x,y:y};localStorage.setItem(POS_K,JSON.stringify(m))}catch(e){}}try{var pm=JSON.parse(localStorage.getItem(POS_K)||"{}")[btn.dataset.n];if(pm&&isFinite(pm.x)&&isFinite(pm.y)){x=pm.x;y=pm.y;btn.style.transform="translate("+x+"px,"+y+"px)"}}catch(e){}btn.addEventListener("pointerdown",function(e){if(e.button!==undefined&&e.button!==0)return;drag=true;moved=false;sx=e.clientX;sy=e.clientY;bx=x;by=y;btn.style.cursor="grabbing";btn.setPointerCapture&&btn.setPointerCapture(e.pointerId);e.preventDefault()});btn.addEventListener("pointermove",function(e){if(!drag)return;var dx=e.clientX-sx,dy=e.clientY-sy;if(Math.abs(dx)>4||Math.abs(dy)>4)moved=true;if(moved){x=bx+dx;y=by+dy;btn.style.transform="translate("+x+"px,"+y+"px)"}e.preventDefault()});btn.addEventListener("pointerup",function(e){drag=false;btn.style.cursor="grab";if(moved){saveP();btn.dataset.suppress="1";setTimeout(function(){delete btn.dataset.suppress},250)}e.preventDefault()});btn.addEventListener("dblclick",function(e){e.preventDefault();e.stopPropagation();x=0;y=0;btn.style.transform="";saveP()});btn.addEventListener("click",function(e){if(btn.dataset.suppress){e.preventDefault();e.stopImmediatePropagation()}},true)}
function build(){style();var host=document.querySelector(".webrx-rx-photo-desc")||document.querySelector(".openwebrx-description-container")||document.body;if(document.getElementById("dnx-vnc-public"))return;var w=document.createElement("div");w.id="dnx-vnc-public";w.innerHTML='<div class="dvp-vnc-controls"><button class="dvp-vnc-btn" data-n="1"></button><button class="dvp-vnc-btn" data-n="2"></button></div><div class="dvp-vnc-links"><a target="_blank" rel="noopener">'+L1+' Vollbild</a><a target="_blank" rel="noopener">'+L2+' Vollbild</a></div><div class="dvp-vnc-grid"><div class="dvp-vnc-box" data-box="1"><iframe allowfullscreen></iframe></div><div class="dvp-vnc-box" data-box="2"><iframe allowfullscreen></iframe></div></div><div class="dvp-vnc-empty" style="display:none">VNC1 und VNC2 sind ausgeschaltet.</div>';host.appendChild(w);var boxes=w.querySelectorAll(".dvp-vnc-box"),buttons=w.querySelectorAll("button"),links=w.querySelectorAll("a"),grid=w.querySelector(".dvp-vnc-grid"),empty=w.querySelector(".dvp-vnc-empty");boxes[0].querySelector("iframe").dataset.src=url(P1);boxes[1].querySelector("iframe").dataset.src=url(P2);links[0].href=url(P1);links[1].href=url(P2);
function update(first){var vals=[state.one,state.two];buttons.forEach(function(b,i){b.textContent=(i?L2:L1)+": "+(vals[i]?"AN":"AUS");b.classList.toggle("dvp-vnc-on",vals[i]);b.classList.toggle("dvp-vnc-off",!vals[i]);boxes[i].classList.toggle("dvp-vnc-hidden",!vals[i]);if(vals[i]&&first)reload(boxes[i])});var n=(state.one?1:0)+(state.two?1:0);grid.classList.toggle("single",n===1);grid.style.display=n?"grid":"none";empty.style.display=n?"none":"block";save()}
buttons.forEach(function(b,i){draggable(b);b.addEventListener("click",function(){if(b.dataset.suppress)return;if(i)state.two=!state.two;else state.one=!state.one;update(false);if((i?state.two:state.one))reload(boxes[i])})});update(true)}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",function(){setTimeout(build,300)},{once:true});else setTimeout(build,300);window.addEventListener("load",function(){setTimeout(build,500)})})();
/* DNX_VNC_PUBLIC_MODULE_END */
JS
}

install_frontend(){ local tmp; tmp=$(mktemp); write_frontend "$tmp"; backup "$PLUGIN_INIT"; remove_block "$PLUGIN_INIT"; run sh -c 'cat "$1" >> "$2"' sh "$tmp" "$PLUGIN_INIT"; rm -f "$tmp"; command -v node >/dev/null 2>&1 && node --check "$PLUGIN_INIT"; }

ensure_deps(){
  command -v websockify >/dev/null 2>&1 && [[ -d /usr/share/novnc ]] && return
  ((INSTALL_DEPS)) || die "websockify/noVNC fehlen. Erneut mit --install-deps oder Pakete manuell installieren."
  command -v apt-get >/dev/null 2>&1 || die "Automatische Paketinstallation unterstützt nur apt."
  run apt-get update; run apt-get install -y websockify novnc
}

write_bridge_files(){
  run mkdir -p "$PREFIX"
  backup "$PREFIX/bridges.json"
  cat >"$PREFIX/bridges.json" <<JSON
{"bridges":[{"label":$(js_escape "$LABEL1"),"host":$(js_escape "$VNC1_HOST"),"port":$VNC1_PORT,"bridge_port":$BRIDGE1},{"label":$(js_escape "$LABEL2"),"host":$(js_escape "$VNC2_HOST"),"port":$VNC2_PORT,"bridge_port":$BRIDGE2}]}
JSON
  cat >"$PREFIX/bridge.py" <<'PY'
#!/usr/bin/env python3
import json,subprocess,signal,time,sys
from pathlib import Path
cfg=json.loads(Path('/opt/dnx-vnc-module/bridges.json').read_text())
children=[]
def stop(*_):
 for p in children:
  try:p.terminate()
  except:pass
 for p in children:
  try:p.wait(timeout=3)
  except:pass
 raise SystemExit
signal.signal(signal.SIGTERM,stop);signal.signal(signal.SIGINT,stop)
for b in cfg.get('bridges',[]):
 cmd=['websockify','--web=/usr/share/novnc/',f"0.0.0.0:{int(b['bridge_port'])}",f"{b['host']}:{int(b['port'])}"]
 print('Starting',' '.join(cmd),flush=True);children.append(subprocess.Popen(cmd))
while True:
 for p in children:
  if p.poll() is not None: print('Bridge exited',p.returncode,flush=True); stop()
 time.sleep(2)
PY
  run chmod 0755 "$PREFIX/bridge.py"
  cat >"/etc/systemd/system/$SERVICE" <<EOF
[Unit]
Description=DNX private VNC1/VNC2 websockify bridges
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $PREFIX/bridge.py
Restart=on-failure
RestartSec=3
KillMode=control-group

[Install]
WantedBy=multi-user.target
EOF
  run systemctl daemon-reload; run systemctl enable --now "$SERVICE"
}

restart_owrx(){ if [[ "$MODE" == docker ]]; then run docker restart "$CONTAINER"; warn "OpenWebRX kann 60–90 Sekunden bis healthy benötigen."; elif command -v systemctl >/dev/null&&systemctl list-unit-files|grep -q '^openwebrx'; then run systemctl restart openwebrx; else warn "OpenWebRX bitte manuell neu starten."; fi; }

install_cmd(){ need_root; detect; install_frontend; if [[ "$SCOPE" == full ]]; then ensure_deps; write_bridge_files; fi; restart_owrx; log "Installation abgeschlossen (Version $VERSION, Umfang $SCOPE)."; }
uninstall_cmd(){ need_root; detect; backup "$PLUGIN_INIT"; remove_block "$PLUGIN_INIT"; if [[ "$SCOPE" == full || -f "/etc/systemd/system/$SERVICE" ]]; then run systemctl disable --now "$SERVICE" 2>/dev/null||true; run rm -f "/etc/systemd/system/$SERVICE"; run systemctl daemon-reload; run rm -rf "$PREFIX"; fi; restart_owrx; log "Modul entfernt; Backups bleiben erhalten."; }
status_cmd(){ detect; grep -qF "$START_JS" "$PLUGIN_INIT"&&echo "Frontend: installiert"||echo "Frontend: nicht installiert"; if command -v systemctl >/dev/null;then systemctl --no-pager --full status "$SERVICE" 2>/dev/null||true;fi; echo "Bridge $BRIDGE1 -> $VNC1_HOST:$VNC1_PORT"; echo "Bridge $BRIDGE2 -> $VNC2_HOST:$VNC2_PORT"; command -v ss>/dev/null&&ss -ltnp|grep -E ":($BRIDGE1|$BRIDGE2)\\b"||true; for target in "$VNC1_HOST:$VNC1_PORT" "$VNC2_HOST:$VNC2_PORT";do h=${target%:*};p=${target#*:};timeout 3 bash -c "</dev/tcp/$h/$p" 2>/dev/null&&echo "$target erreichbar"||echo "$target NICHT erreichbar";done; }
backup_cmd(){ need_root; detect; backup "$PLUGIN_INIT"; [[ -f $PREFIX/bridges.json ]]&&backup "$PREFIX/bridges.json"||true; }
restore_cmd(){ need_root; detect; [[ ${#EXTRA_ARGS[@]} -ge 1&& -f ${EXTRA_ARGS[0]} ]]||die "restore benötigt eine vorhandene Backup-Datei.";backup "$PLUGIN_INIT";run cp -a "${EXTRA_ARGS[0]}" "$PLUGIN_INIT";restart_owrx; }

parse "$@"
case "$COMMAND" in install|update) install_cmd;; uninstall) uninstall_cmd;; status) status_cmd;; backup) backup_cmd;; restore) restore_cmd;; help) usage;; *) usage;die "Unbekannter Befehl: $COMMAND";; esac
