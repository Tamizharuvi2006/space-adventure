# Explore Sun — Full 1→100 World Layout Reference

> **This document is the canonical design source of truth.**  
> Written from actual layout diagrams generated from the authored `world_generator.gd` data.  
> Every transition value here matches the current authored blueprint.

---

## Overall Journey

```
START
  ↓
SOLAR VALLEY       (Pads 1–20)
  ↓
SOLAR CRATERS      (Pads 21–40)
  ↓
SOLAR MOUNTAINS    (Pads 41–60)
  ↓
SOLAR RUINS        (Pads 61–80)
  ↓
SOLAR CORE         (Pads 81–100)
  ↓
PAD 100 — SOLAR CORE APEX
```

All 100 pads are reachable. Minimum fuel margin ≈ 30%.  
X always moves forward. Y moves freely up/down to create landscape rhythm.

---

## Core Design Philosophy

### Pad count is NOT the content. The transition is the content.

```
Pad 1  = "learn"
Pad 2  = "climb"
Pad 3  = "precision"
Pad 4  = "settle"
Pad 5  = "drop"
Pad 6  = "climb again"
Pad 7  = "rest"
Pad 8  = "traverse"
Pad 9  = "easy"
Pad 10 = "BIG GLIDE"
...
```

### The Success Criterion

> **"Does Pad 37 feel different from Pad 36 when I'm holding the phone?"**

This is the ONLY real test. Numerical variation in the graph is not proof of felt variety.

### The Next Design Goal

Every pad should be a **visual place**, not a coordinate:

```
Pad 41 = cliff edge
Pad 42 = narrow ledge
Pad 43 = open shelf
Pad 44 = deep cut
Pad 45 = isolated rock
Pad 46 = ridge shoulder
Pad 47 = peak
Pad 48 = rest shelf
```

---

## Difficulty Rhythm

### Tier Cycle Pattern
Not `easy → harder → hardest`. Instead:

```
EASY → MEDIUM → HARD → RELIEF → MEDIUM → HARD → RECOVERY → LONG → ...
```

Recovery pads at: **7, 18, 28, 36, 48, 56, 63, 69, 78, 88, 98**

### Width Language

| Tier         | Width (px)  | Feel                          |
|--------------|-------------|-------------------------------|
| Easy/Recovery| 195–210     | visually safe, welcoming      |
| Medium       | 155–180     | normal precision              |
| Hard         | 132–148     | deliberate landing required   |
| Hard+        | 118–135     | precision only                |

---

## ZONE 0 — SOLAR VALLEY (Pads 1–20)

**Teaching/intro region.** Introduces heights, braking patterns, first milestone.

```
Valley floor → Mesa rise → Spire → Gorge → Wall climb → Ridge → Valley crest
```

| Pad | Tier | dx   | dy    | Width | Motif          | Chapter                 |
|-----|------|------|-------|-------|----------------|-------------------------|
| 1   | E1   | 840  | +18   | 206   | Valley Shelf   | Valley Entry            |
| 2   | M1   | 1140 | −80   | 170   | Mountain Peak  | Mesa Rise               |
| 3   | H1   | 1020 | −148  | 143   | Cliff Right    | First Spire             |
| 4   | E2   | 940  | +52   | 194   | Mesa           | Gorge Settle            |
| 5   | M2   | 1310 | +100  | 158   | Cliff Left     | Canyon Descent          |
| 6   | H1   | 1060 | −152  | 140   | Mountain Peak  | Wall Assault            |
| 7   | R    | 870  | +28   | 207   | Mesa           | Mesa Rest ← RECOVERY    |
| 8   | M1   | 1180 | −72   | 172   | Valley Shelf   | Ridge Traverse          |
| 9   | E1   | 820  | +22   | 204   | Mesa           | Gentle Step             |
| 10  | L    | 2200 | −18   | 177   | Mesa           | Valley Milestone Glide  |
| 11  | E2   | 960  | +58   | 192   | Cliff Left     | Canyon Lip Drop         |
| 12  | H1   | 1040 | −142  | 141   | Cliff Right    | Cliff Face Ascent       |
| 13  | M2   | 1270 | +98   | 156   | Valley Shelf   | Shelf Recovery          |
| 14  | E1   | 855  | +18   | 205   | Mesa           | Pedestal Rest           |
| 15  | M1   | 1100 | −78   | 171   | Mountain Peak  | Ridge Step Up           |
| 16  | H2   | 1480 | −158  | 132   | Cliff Right    | High Wall Run           |
| 17  | M2   | 1320 | +112  | 153   | Cliff Left     | Deep Settle             |
| 18  | R    | 895  | +22   | 208   | Mesa           | Valley Rest ← RECOVERY  |
| 19  | H1   | 1130 | −128  | 143   | Mountain Peak  | Crest Climb             |
| 20  | L    | 2250 | +18   | 175   | Valley Shelf   | Solar Valley Milestone  |

---

## ZONE 1 — SOLAR CRATERS / BASIN (Pads 21–40)

**Bowl terrain.** Rim → outer wall → interior → basin → trench → far rim.

```
Rim → Outer bowl → Deep basin → Central peak → Trench → Far rim
```

| Pad | Tier | dx   | dy    | Width | Chapter               |
|-----|------|------|-------|-------|-----------------------|
| 21  | E2   | 950  | +48   | 193   | Rim Approach          |
| 22  | M1   | 1150 | +88   | 168   | Outer Wall Slope      |
| 23  | H1   | 1070 | +155  | 139   | Interior Drop         |
| 24  | E2   | 920  | −42   | 195   | Ledge Hop Back        |
| 25  | M2   | 1420 | +128  | 154   | Deep Bowl Entry       |
| 26  | H2   | 1620 | +168  | 128   | Basin Plunge          |
| 27  | L    | 2250 | +22   | 178   | Basin Long Glide      |
| 28  | R    | 900  | +12   | 208   | Basin Rest ← RECOVERY |
| 29  | H1   | 1080 | −145  | 140   | Peak Assault          |
| 30  | L    | 2300 | −48   | 174   | Spire Milestone       |
| 31  | E2   | 930  | +20   | 196   | Peak Plateau          |
| 32  | H2   | 1400 | +162  | 126   | Trench Plunge         |
| 33  | M1   | 1460 | −12   | 168   | Trench Sprint         |
| 34  | H1   | 960  | −135  | 141   | Trench Climb          |
| 35  | M2   | 1580 | −58   | 155   | Ejecta Traverse       |
| 36  | R    | 880  | +18   | 207   | Rim Rest ← RECOVERY   |
| 37  | M2   | 1200 | −108  | 157   | Wall Terraces         |
| 38  | H2   | 1380 | −148  | 129   | Escarpment Climb      |
| 39  | M1   | 1540 | −52   | 169   | Rampart Run           |
| 40  | L    | 2350 | −28   | 174   | Craters Milestone     |

---

## ZONE 2 — SOLAR MOUNTAINS (Pads 41–60)

**Strongest alpine region.** Base → sheer ascent → summit/couloir → mountain pass.

```
Foothills → Cliff → Glacier → Summit → Couloir descent → Mountain pass
```

| Pad | Tier | dx   | dy    | Width | Chapter               |
|-----|------|------|-------|-------|-----------------------|
| 41  | M1   | 1120 | −98   | 172   | Base Approach         |
| 42  | H2   | 1350 | −160  | 123   | Cliff Face Assault    |
| 43  | E2   | 1010 | +32   | 196   | Alpine Dip            |
| 44  | M2   | 1160 | −118  | 156   | Terrace Precision     |
| 45  | H1   | 920  | −138  | 138   | Crevasse Needle       |
| 46  | M1   | 1080 | −102  | 169   | Glacier Shelf         |
| 47  | H2   | 1480 | −162  | 120   | Summit Push           |
| 48  | R    | 930  | +42   | 206   | Summit Rest ← RECOVERY|
| 49  | H1   | 1680 | −78   | 140   | Apex Col              |
| 50  | L    | 2400 | −28   | 172   | Summit Milestone      |
| 51  | E2   | 890  | +12   | 197   | Summit Shelf          |
| 52  | H2   | 1380 | +182  | 121   | Couloir Plunge        |
| 53  | M1   | 1500 | −12   | 168   | Couloir Sprint        |
| 54  | H1   | 870  | −128  | 136   | Frost Spire           |
| 55  | H2   | 1450 | +170  | 122   | Gorge Step Drop       |
| 56  | R    | 940  | +12   | 207   | Mountain Haven ← RECOVERY |
| 57  | M2   | 1200 | −98   | 158   | Pass Ascent           |
| 58  | M1   | 1360 | +78   | 170   | Pass Mesa Fall        |
| 59  | H1   | 1560 | −48   | 139   | Pass Brake Run        |
| 60  | L    | 2450 | −28   | 173   | Mountains Milestone   |

---

## ZONE 3 — SOLAR ANCIENT RUINS (Pads 61–80)

**Environment-heavy.** Colonnades → sunken vaults → amphitheatre → monuments → pyramid terraces.

```
Colonnade → Sunken vault → Colosseum → Amphitheatre → Catacombs → Pyramid terraces → Ancient summit
```

| Pad | Tier | dx   | dy    | Width | Chapter               |
|-----|------|------|-------|-------|-----------------------|
| 61  | M1   | 1180 | +92   | 170   | Colonnade Entry       |
| 62  | H2   | 1540 | +178  | 122   | Sunken Vault Drop     |
| 63  | R    | 960  | +18   | 208   | Sanctum Rest ← RECOVERY |
| 64  | M2   | 1080 | −108  | 157   | Pillar Ascent         |
| 65  | H2   | 1460 | +168  | 124   | Colosseum Drop        |
| 66  | L    | 1920 | +32   | 178   | Arena Long Sprint     |
| 67  | M1   | 1080 | −22   | 170   | Amphitheatre Shelf    |
| 68  | H1   | 1020 | −148  | 136   | Pyramid Ascent        |
| 69  | R    | —    | —     | 208   | Forum Rest ← RECOVERY |
| 70  | L    | 2450 | −28   | 173   | Pyramid Milestone     |
| 71  | E2   | 950  | +18   | 196   | Bastion Drop          |
| 72  | H2   | 1400 | +145  | 122   | Catacomb Plunge       |
| 73  | M1   | 1520 | −12   | 170   | Vault Sprint          |
| 74  | H1   | 980  | −138  | 136   | Monolith Climb        |
| 75  | M2   | 1620 | −58   | 156   | Avenue Traverse       |
| 76  | M1   | 1120 | −98   | 172   | Terrace Step          |
| 77  | H2   | 1360 | −155  | 124   | Temple Spire          |
| 78  | R    | 950  | +12   | 208   | Altar Rest ← RECOVERY |
| 79  | H1   | 1580 | −52   | 138   | Threshold Run         |
| 80  | L    | 2450 | −28   | 173   | Ruins Milestone       |

---

## ZONE 4 — SOLAR CORE (Pads 81–100)

**Grand finale.** Caldera → plasma columns → corona steps → pinnacle assault → Pad 100.

```
Caldera rim → Plasma region → Corona → Final corridor → ◎ PAD 100
```

| Pad | Tier | dx   | dy    | Width | Chapter               |
|-----|------|------|-------|-------|-----------------------|
| 81  | M2   | 1200 | −102  | 157   | Caldera Rise          |
| 82  | H2   | 1280 | −158  | 122   | Plasma Column         |
| 83  | E2   | 980  | +62   | 194   | Shoulder Dip          |
| 84  | H1   | 1060 | −132  | 138   | Return Climb          |
| 85  | M2   | 1340 | −108  | 155   | Flare Pedestal        |
| 86  | H2   | 1660 | −52   | 124   | Molten Sprint         |
| 87  | L    | 2400 | −12   | 177   | Corona Glide          |
| 88  | R    | 940  | +38   | 207   | Plasma Rest ← RECOVERY |
| 89  | H2   | 1480 | −162  | 120   | Core Spire            |
| 90  | L    | 2450 | −28   | 173   | Core Milestone        |
| 91  | E2   | 920  | +12   | 196   | Corona Terrace        |
| 92  | H1   | 1120 | −142  | 136   | Corona Steps          |
| 93  | M2   | 1480 | −22   | 156   | Threshold Sprint      |
| 94  | H2   | 1380 | −138  | 121   | Threshold Monolith    |
| 95  | M1   | 1060 | −98   | 170   | Ascent Step           |
| 96  | H2   | 1520 | −145  | 120   | Pinnacle Assault      |
| 97  | M2   | 1300 | +42   | 157   | Apex Settle           |
| 98  | R    | 960  | −12   | 208   | Final Sanctum ← RECOVERY |
| 99  | H1   | 1420 | −52   | 140   | Final Corridor        |
| 100 | L    | 2450 | −28   | 173   | THE SOLAR CORE APEX   |

---

## Macro Route Visual Shape

```
SOLAR VALLEY
   ↗  ↘  ↗  (small local humps)

SOLAR CRATERS
   ↘
    ↓ deep basin
        ↑
         ↗

SOLAR MOUNTAINS
     ↗
      ↗ summit
         ↘ pass

SOLAR RUINS
      ↘ sunken region
            ↗ monuments
               ↗ pyramid terraces

SOLAR CORE
      ↗
       ↗ plasma
          ↗
           ↗
            ◎ PAD 100
```

---

## What Still Matters (Next Step)

The **route data is authored and verified**. What remains is whether the terrain renderer actually makes each pad feel like a visual place. The terrain silhouette is more valuable than difficulty colors — the player won't know "H2/M1/L", they'll see a cliff, basin, shelf, peak, ruins, etc.

**Current manual test required:**
> Play Pads 1→2→3→4→5→6→7→8→9→10 and record whether each transition required a different thrust combination/timing from the previous one.

**If any two consecutive transitions feel the same → that's the specific pair to fix next.**
