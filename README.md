# Centipede

Ein Centipede-Arcade-Klon, gebaut mit **Godot 4.6** und GDScript.

Inspiriert vom Klassiker auf dem IBM PC — eine Schlange schlängelt sich von oben nach unten, der Spieler schiesst von unten dagegen.

## Spielen

1. Projekt in **Godot 4.6+** oeffnen (`godot/` Ordner importieren)
2. **F5** druecken
3. **Enter** zum Starten

## Steuerung

| Taste | Aktion |
|-------|--------|
| Pfeiltasten | Schiff bewegen |
| Leertaste | Schiessen |
| Enter | Starten / Naechstes Level / Neustarten |

## Features

**Gameplay**
- Schlange bewegt sich serpentinenartig, teilt sich bei Treffern
- Segmente koennen geschuetzt sein (Schild — braucht 2 Treffer)
- Schlangen die unten entkommen, kommen oben mit Verstaerkung zurueck
- 4 verschiedene Wurm-Farben (gruen, rot, lila, orange)
- Bloecke mit 1–3 HP entstehen bei Treffern und blockieren den Weg
- Steigende Schwierigkeit ueber 10+ Level

**Power-Ups** (fallen bei Segment-Treffern, 8s Dauer)
- **2x** Doppelschuss — zwei Schuesse hintereinander
- **3x** Dreifachschuss — Faecherschuss
- **RF** Schnellfeuer — bis zu 4 Schuesse gleichzeitig
- **SH** Schild — absorbiert einen Treffer
- **PI** Durchschlag — Schuesse fliegen durch Ziele

**Extras**
- Persistente Highscore-Liste (Top 5)
- Prozedural generierte Sound-Effekte (keine externen Dateien)
- Partikeleffekte, Screen-Shake, animierte Visuals
- Power-Up Timer-Balken mit Ablauf-Warnung

## Projektstruktur

```
godot/
  project.godot   — Godot-Projektkonfiguration
  main.tscn       — Hauptszene
  main.gd         — Gesamte Spiellogik (~1200 Zeilen)
```

Keine externen Assets, Sprites oder Audio-Dateien — alles wird zur Laufzeit generiert.

## Screenshots

*Kommt bald*

## Lizenz

MIT
