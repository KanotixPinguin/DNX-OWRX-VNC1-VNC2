# DNX VNC1/VNC2-Modul

Version 1.0.0 · MIT-Lizenz

> **Wichtiger Hinweis / Haftungsausschluss**
>
> Dieses VNC-Modul ist ein rein privates, unabhängiges Hobbyprojekt. Es ist **kein Projekt, Produkt oder offizielles Plugin von OpenWebRX, OpenWebRX+, noVNC, websockify oder TightVNC**. Es besteht keine Verbindung, Beauftragung, Partnerschaft, Unterstützung, Prüfung oder Empfehlung durch deren Entwickler oder Rechteinhaber. Der Autor handelt ausschließlich als privater Hobby-Anwender beziehungsweise unabhängiger Moderator.
>
> Installation, Nutzung, Veränderung und Weitergabe erfolgen vollständig auf eigene Gefahr und Verantwortung des jeweiligen Anwenders. Soweit gesetzlich zulässig, übernimmt der Autor keine Haftung für Schäden, Serverausfälle, Datenverlust, Sicherheitsprobleme, Fehlkonfigurationen, unbefugte Zugriffe oder technische beziehungsweise rechtliche Folgen. Vor jeder Installation müssen Backups erstellt und Änderungen zuerst auf einem Testsystem geprüft werden. Dieser Hinweis ist keine Rechtsberatung.

## Beschreibung

Private VNC1/VNC2-Anpassung für eine vorhandene OpenWebRX+-Installation. Das Modul kann nur die OpenWebRX-Anzeige einbauen oder zusätzlich zwei websockify/noVNC-Brücken als systemd-Dienst verwalten.

## Funktionen

- VNC1 und VNC2 AN/AUS
- zwei aktive Ansichten nebeneinander
- große, zentrierte Einzelansicht
- Hinweis, wenn beide Ansichten ausgeschaltet sind
- echte iframe-Neuverbindung beim Wiedereinschalten
- automatischer noVNC-Reconnect
- responsive Fensterhöhen
- verschiebbare Schalter
- Vollbild-Links
- noVNC-Qualität 7 und Kompression 2
- Browser speichert Schalterzustände lokal
- optionaler systemd-Dienst für zwei Bridges
- Status, Backup, Update, Restore und Uninstall

## Installationsvarianten

### `frontend`

Installiert nur die Anzeige. Vorhandene Bridges, zum Beispiel 6082 und 6083, werden vorausgesetzt.

### `full`

Installiert Anzeige und verwaltete websockify/noVNC-Brücken.

## Voraussetzungen

### Nur Anzeige

- OpenWebRX+ mit `htdocs/plugins/receiver/init.js`
- bestehende noVNC/websockify-Bridges

### Komplettinstallation

- Linux mit systemd
- Python 3
- websockify
- noVNC unter `/usr/share/novnc`
- erreichbare VNC-Server
- Root-Rechte

## Installation

Datei ausführbar machen:

```bash
chmod +x DNX-VNC1-VNC2-All-in-One.sh
```

### Docker mit vorhandenen Bridges

```bash
sudo ./DNX-VNC1-VNC2-All-in-One.sh install \
  --mode docker \
  --container owrx-8013 \
  --scope frontend \
  --bridge1 6082 \
  --bridge2 6083
```

### Komplettinstallation

```bash
sudo ./DNX-VNC1-VNC2-All-in-One.sh install \
  --mode docker \
  --container owrx-8013 \
  --scope full \
  --vnc1-host 192.0.2.20 \
  --vnc1-port 5900 \
  --vnc2-host 192.0.2.72 \
  --vnc2-port 5900 \
  --bridge1 6082 \
  --bridge2 6083 \
  --label1 "SDRangel 3D" \
  --label2 "SDRuno"
```

Falls Abhängigkeiten fehlen:

```bash
sudo ./DNX-VNC1-VNC2-All-in-One.sh install \
  --mode docker --container owrx-8013 \
  --scope full --install-deps
```

### Native Installation

```bash
sudo ./DNX-VNC1-VNC2-All-in-One.sh install \
  --mode native \
  --scope frontend
```

Eigener Pluginpfad:

```bash
sudo ./DNX-VNC1-VNC2-All-in-One.sh install \
  --mode native \
  --scope frontend \
  --plugin-init /PFAD/htdocs/plugins/receiver/init.js
```

## Bedienung

- `VNC1: AN/AUS`: erste Ansicht umschalten
- `VNC2: AN/AUS`: zweite Ansicht umschalten
- bei nur einer aktiven Ansicht wird diese automatisch vergrößert
- Schalter gedrückt halten und ziehen, um sie zu verschieben
- Vollbild-Link öffnet noVNC in einem eigenen Tab

## Statusprüfung

```bash
sudo ./DNX-VNC1-VNC2-All-in-One.sh status \
  --mode docker \
  --container owrx-8013 \
  --scope full \
  --vnc1-host 192.0.2.20 \
  --vnc2-host 192.0.2.72
```

Geprüft werden:

- Frontend-Markierung
- systemd-Dienst
- Bridge-Listener
- VNC-Zielports
- Erreichbarkeit

## Update

```bash
sudo ./DNX-VNC1-VNC2-All-in-One.sh update \
  --mode docker \
  --container owrx-8013 \
  --scope full \
  --vnc1-host 192.0.2.20 \
  --vnc2-host 192.0.2.72
```

## Entfernen

Nur Anzeige:

```bash
sudo ./DNX-VNC1-VNC2-All-in-One.sh uninstall \
  --mode docker --container owrx-8013 \
  --scope frontend
```

Anzeige und verwaltete Bridges:

```bash
sudo ./DNX-VNC1-VNC2-All-in-One.sh uninstall \
  --mode docker --container owrx-8013 \
  --scope full
```

Der Uninstaller entfernt nur eindeutig markierten Modulcode sowie den von diesem Modul verwalteten Dienst. Backups bleiben erhalten.

## Dateien

Frontend:

```text
htdocs/plugins/receiver/init.js
```

Markierungen:

```text
/* DNX_VNC_PUBLIC_MODULE_START */
/* DNX_VNC_PUBLIC_MODULE_END */
```

Bridge-Konfiguration:

```text
/opt/dnx-vnc-module/bridges.json
```

Bridge-Programm:

```text
/opt/dnx-vnc-module/bridge.py
```

Dienst:

```text
/etc/systemd/system/dnx-vnc-module.service
```

## Fehlerdiagnose

### noVNC-Seite funktioniert direkt, aber nicht eingebettet

- Browsercache und Websitedaten löschen
- privates Browserfenster testen
- Scriptblocker deaktivieren
- beide VNC-Schalter AUS und wieder AN schalten

### Schwarzes Bild

VNC-Ziel testen:

```bash
timeout 3 bash -c '</dev/tcp/VNC-IP/5900'
```

Bridge prüfen:

```bash
systemctl status dnx-vnc-module --no-pager -l
journalctl -u dnx-vnc-module -n 100 --no-pager
ss -ltnp | grep -E ':(6082|6083)\\b'
```

### HTTPS / Mixed Content

Bei einer HTTPS-OpenWebRX-Seite benötigt websockify TLS oder einen passenden HTTPS-/WebSocket-Reverse-Proxy. Eine unverschlüsselte HTTP-Einbettung wird sonst vom Browser blockiert.

## Sicherheit

- VNC-Ports nicht ungeschützt ins Internet weiterleiten
- Firewall oder Reverse-Proxy verwenden
- VNC-Authentifizierung aktivieren
- `view_only=1` ersetzt keine serverseitige Zugriffskontrolle
- nur vertrauenswürdige Zielrechner und Netze verwenden
- vor Updates Backups anlegen

## Unabhängigkeit

OpenWebRX, OpenWebRX+, noVNC, websockify und TightVNC sowie zugehörige Namen und Marken gehören den jeweiligen Rechteinhabern. Ihre Erwähnung dient ausschließlich zur Beschreibung der technischen Zielumgebung. Dieses Modul ist kein Bestandteil einer offiziellen Distribution.

## Lizenz

MIT-Lizenz. Nutzung, Änderung und Weitergabe sind erlaubt; ohne Gewährleistung oder Haftung.
