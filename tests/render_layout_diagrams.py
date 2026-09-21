import json
import os
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np

# Load pad layout JSON
json_path = r"d:\game\explore-sun\tests\pad_layout.json"
with open(json_path, "r", encoding="utf-8") as f:
    pads = json.load(f)

# Output directories
out_dirs = [
    r"d:\game\explore-sun\docs\layouts",
    r"C:\Users\aruvi\.gemini\antigravity-ide\brain\e5629d16-f182-4f59-86e8-f0e5d30137e6"
]
for d in out_dirs:
    os.makedirs(d, exist_ok=True)

# Motif integer to string mapping from SolarTerrainGenerator.FormationType
MOTIF_NAMES = {
    0: "VALLEY_SHELF",
    1: "MESA",
    2: "CLIFF_LEFT",
    3: "CLIFF_RIGHT",
    4: "CRATER_RIM",
    5: "MOUNTAIN_PEAK"
}

def get_motif_name(m):
    if isinstance(m, int):
        return MOTIF_NAMES.get(m, f"MOTIF_{m}")
    return str(m)

# Classify difficulty tier
def get_pad_tier(p):
    if p.get("idx") == 0:
        return "SPAWN", "#FFFFFF"
    pattern = p.get("pattern", "")
    width = p.get("width", 160.0)
    dx = p.get("dx", 1000.0)
    dy = abs(p.get("dy", 0.0))

    if "RECOVERY" in pattern or (width >= 200.0 and pattern != "SHORT_TECHNICAL_HOP"):
        return "RECOVERY", "#00E5FF"
    if "MILESTONE" in pattern or "LONG" in pattern or dx >= 1800.0:
        return "LONG GLIDE", "#D500F9"
    if width < 148.0 or dy >= 130.0:
        return "HARD", "#FF3D00"
    if width >= 185.0:
        return "EASY", "#00E676"
    return "MEDIUM", "#FFB300"

# ─────────────────────────────────────────────────────────────────────────────
# 1. Macro Overview (Pads 0 to 100)
# ─────────────────────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(24, 8), dpi=200, facecolor="#0B0D19")
ax.set_facecolor("#0F1426")

xs = [p["x"] for p in pads]
alts = [-p["y"] for p in pads]

zones = [
    ("Zone 0: Solar Valley (Pads 1–20)", 0, 20, "#FF6D0022", "#FF9100"),
    ("Zone 1: Solar Basin (Pads 21–40)", 20, 40, "#00E5FF22", "#00E5FF"),
    ("Zone 2: Solar Mountain (Pads 41–60)", 40, 60, "#FFD60022", "#FFD600"),
    ("Zone 3: Solar Ruins (Pads 61–80)", 60, 80, "#E040FB22", "#E040FB"),
    ("Zone 4: Solar Core (Pads 81–100)", 80, 100, "#FF174422", "#FF1744"),
]

for name, start_idx, end_idx, bg_col, edge_col in zones:
    zx_start = pads[start_idx]["x"] - 200
    zx_end = pads[end_idx]["x"] + 200
    ax.axvspan(zx_start, zx_end, color=bg_col, zorder=1)
    center_x = (pads[start_idx]["x"] + pads[end_idx]["x"]) / 2.0
    ax.text(center_x, max(alts) + 140, name, color=edge_col,
            fontsize=12, fontweight="bold", ha="center", va="bottom",
            bbox=dict(boxstyle="round,pad=0.35", facecolor="#0B0D19", edgecolor=edge_col, alpha=0.9))

# Terrain silhouette baseline
tx_fine = np.linspace(min(xs) - 400, max(xs) + 400, 800)
ty_fine = np.interp(tx_fine, xs, [a - 90 for a in alts])
ax.fill_between(tx_fine, ty_fine, min(alts) - 350, color="#121727", alpha=0.95, zorder=2)
ax.plot(tx_fine, ty_fine, color="#37474F", linewidth=2.0, zorder=2)

# Jump route connection
ax.plot(xs, alts, color="#546E7A", linewidth=1.5, linestyle="--", zorder=3, alpha=0.7)

# Scatter pads
for p in pads:
    tier_name, col = get_pad_tier(p)
    sz = 90 if tier_name in ["RECOVERY", "LONG GLIDE"] or p.get("is_milestone") else 45
    ax.scatter(p["x"], -p["y"], color=col, s=sz, zorder=5, edgecolors="#FFFFFF", linewidths=0.6)
    
    # Milestone & recovery labels
    if p["idx"] % 10 == 0 or tier_name == "RECOVERY" or p["idx"] in [1, 5, 20]:
        ax.annotate(f"P{p['idx']}", (p["x"], -p["y"]),
                    textcoords="offset points", xytext=(0, 12),
                    ha="center", fontsize=8.5, color="#FFFFFF", fontweight="bold",
                    bbox=dict(boxstyle="round,pad=0.2", facecolor="#1A237E", edgecolor=col, alpha=0.9))

ax.set_title("EXPLORE SUN — COMPLETE 100-PAD EXPEDITION ROUTE (BIRD'S-EYE ELEVATION VIEW)",
             fontsize=16, fontweight="bold", color="#FFE082", pad=35)
ax.set_xlabel("Horizontal Distance X (Pixels across 134,000 px world)", color="#B0BEC5", fontsize=12, labelpad=10)
ax.set_ylabel("World Altitude (Inverted Y: Higher = Higher Elevation)", color="#B0BEC5", fontsize=12, labelpad=10)
ax.tick_params(colors="#78909C", labelsize=10)
for spine in ax.spines.values():
    spine.set_color("#263238")
ax.grid(True, linestyle=":", alpha=0.25, color="#546E7A")

legend_elements = [
    patches.Patch(facecolor="#00E676", label="Easy / Relief"),
    patches.Patch(facecolor="#FFB300", label="Medium Challenge"),
    patches.Patch(facecolor="#FF3D00", label="Hard / Technical Spike"),
    patches.Patch(facecolor="#00E5FF", label="Recovery Safe Haven (200px)"),
    patches.Patch(facecolor="#D500F9", label="Long Milestone Glide"),
]
ax.legend(handles=legend_elements, loc="lower right", facecolor="#101827", edgecolor="#37474F",
          labelcolor="#ECEFF1", fontsize=10)

plt.tight_layout()
for d in out_dirs:
    fig.savefig(os.path.join(d, "layout_overview_1_to_100.png"))
plt.close(fig)
print("Saved refreshed layout_overview_1_to_100.png")


# ─────────────────────────────────────────────────────────────────────────────
# 2. Detailed 20-Pad Zone Renderers with Non-Overlapping Badges
# ─────────────────────────────────────────────────────────────────────────────
def render_zone_detail(start_idx, end_idx, zone_title, filename):
    sub_pads = [p for p in pads if start_idx <= p["idx"] <= end_idx]
    if not sub_pads:
        return
    
    prev_pad = pads[start_idx - 1] if start_idx > 0 else None

    fig, ax = plt.subplots(figsize=(24, 10), dpi=200, facecolor="#090B14")
    ax.set_facecolor("#0F1426")

    xs = [p["x"] for p in sub_pads]
    alts = [-p["y"] for p in sub_pads]
    all_draw_pads = [prev_pad] + sub_pads if prev_pad else sub_pads
    all_xs = [p["x"] for p in all_draw_pads]
    all_alts = [-p["y"] for p in all_draw_pads]

    y_min = min(all_alts) - 220
    y_max = max(all_alts) + 280

    # Ground terrain silhouette
    tx_fine = np.linspace(min(all_xs) - 400, max(all_xs) + 500, 500)
    ty_fine = np.interp(tx_fine, all_xs, [a - 95 for a in all_alts])
    ty_fine += 18 * np.sin(tx_fine * 0.004) + 12 * np.cos(tx_fine * 0.01)
    ax.fill_between(tx_fine, ty_fine, y_min - 150, color="#151A2C", alpha=0.95, zorder=2)
    ax.plot(tx_fine, ty_fine, color="#37474F", linewidth=2.2, zorder=2)

    # Flight arcs between consecutive pads
    for i in range(len(all_draw_pads) - 1):
        p1 = all_draw_pads[i]
        p2 = all_draw_pads[i+1]
        x1, y1 = p1["x"], -p1["y"]
        x2, y2 = p2["x"], -p2["y"]

        mid_x = (x1 + x2) / 2.0
        peak_y = max(y1, y2) + 60.0 + (p2["dx"] * 0.035)

        t = np.linspace(0, 1, 50)
        arc_x = (1-t)**2 * x1 + 2*(1-t)*t * mid_x + t**2 * x2
        arc_y = (1-t)**2 * y1 + 2*(1-t)*t * peak_y + t**2 * y2

        tier_name, p_col = get_pad_tier(p2)
        ax.plot(arc_x, arc_y, color=p_col, linestyle="--", linewidth=2.0, alpha=0.8, zorder=3)

        # Mid-flight delta info badge
        ax.text(mid_x, peak_y + 14, f"Δx+{int(p2['dx'])}\nΔy{int(p2['dy']):+d}",
                ha="center", va="bottom", fontsize=7.5, color="#ECEFF1",
                bbox=dict(boxstyle="round,pad=0.2", facecolor="#0A0E1A", edgecolor="#455A64", alpha=0.85))

    # Render each platform
    for i, p in enumerate(sub_pads):
        px = p["x"]
        py = -p["y"]
        pw = p["width"]
        tier_name, p_col = get_pad_tier(p)
        motif_str = get_motif_name(p["motif"])

        # Platform slab
        plat_rect = patches.Rectangle((px - pw/2.0, py - 6), pw, 12,
                                      linewidth=2, edgecolor=p_col, facecolor="#212738", zorder=4)
        ax.add_patch(plat_rect)

        # Platform glowing top strip
        ax.plot([px - pw/2.0, px + pw/2.0], [py + 6, py + 6], color=p_col, linewidth=4.0, zorder=5)

        # Support pillar rooted into ground
        ax.plot([px, px], [py - 6, py - 95], color="#37474F", linewidth=4.5, zorder=1)

        # Central position dot
        ax.scatter(px, py, color="#FFFFFF", s=30, zorder=6)

        # Alternate badge height (even vs odd index) to guarantee ZERO text overlap!
        is_even = (p["idx"] % 2 == 0)
        badge_y_offset = 115 if is_even else 42

        # Connecting guideline from platform to badge
        ax.plot([px, px], [py + 10, py + badge_y_offset], color=p_col, linestyle=":", linewidth=1.2, alpha=0.6, zorder=4)

        badge_text = f"PAD {p['idx']}: {tier_name}\n{p['chapter']}\n[{motif_str}]  W:{int(pw)}px"
        ax.text(px, py + badge_y_offset, badge_text,
                ha="center", va="bottom", fontsize=8.0, fontweight="bold",
                color="#FFFFFF", zorder=7,
                bbox=dict(boxstyle="round,pad=0.35", facecolor="#0E1626", edgecolor=p_col, linewidth=1.6, alpha=0.94))

    ax.set_xlim(min(all_xs) - 450, max(all_xs) + 650)
    ax.set_ylim(y_min, y_max)

    ax.set_title(f"EXPLORE SUN — {zone_title.upper()}",
                 fontsize=16, fontweight="bold", color="#FFE082", pad=25)
    ax.set_xlabel("Horizontal Position X (px)", color="#B0BEC5", fontsize=12, labelpad=10)
    ax.set_ylabel("World Altitude (Higher = Higher Platform)", color="#B0BEC5", fontsize=12, labelpad=10)
    ax.tick_params(colors="#78909C", labelsize=10)
    for spine in ax.spines.values():
        spine.set_color("#263238")
    ax.grid(True, linestyle=":", alpha=0.25, color="#546E7A")

    legend_elements = [
        patches.Patch(facecolor="#00E676", label="Easy / Relief (Wide Landing)"),
        patches.Patch(facecolor="#FFB300", label="Medium Technical Challenge"),
        patches.Patch(facecolor="#FF3D00", label="Hard / Narrow Technical Spike"),
        patches.Patch(facecolor="#00E5FF", label="Recovery Safe Haven (200px Pad)"),
        patches.Patch(facecolor="#D500F9", label="Long Distance Milestone (>1800px)"),
    ]
    ax.legend(handles=legend_elements, loc="upper right", facecolor="#101827", edgecolor="#37474F",
              labelcolor="#ECEFF1", fontsize=9.5)

    plt.tight_layout()
    for d in out_dirs:
        fig.savefig(os.path.join(d, filename))
    plt.close(fig)
    print(f"Saved {filename}")

# Generate diagrams for all 5 zones
render_zone_detail(1, 20, "Zone 0: Solar Valley (Pads 1 to 20)", "layout_zone0_pads_1_to_20.png")
render_zone_detail(21, 40, "Zone 1: Solar Basin / Craters (Pads 21 to 40)", "layout_zone1_pads_21_to_40.png")
render_zone_detail(41, 60, "Zone 2: Solar Mountain Summit (Pads 41 to 60)", "layout_zone2_pads_41_to_60.png")
render_zone_detail(61, 80, "Zone 3: Solar Ancient Ruins (Pads 61 to 80)", "layout_zone3_pads_61_to_80.png")
render_zone_detail(81, 100, "Zone 4: Solar Core Apex (Pads 81 to 100)", "layout_zone4_pads_81_to_100.png")

print("All enhanced layout diagrams generated successfully!")
