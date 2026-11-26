#!/usr/bin/env python3
"""Generate minimal, compact vector-rendered Windows MSIX and Store PNG assets.

Renders crisp anti-aliased 8-bit RGBA PNGs from mathematically generated SVG
sources via `rsvg-convert` (librsvg/Cairo) and normalizes to RGBA via Pillow:
  - packaging/msix/Assets/Square44x44Logo.png         (44x44, transparent outer margin)
  - packaging/msix/Assets/StoreLogo.png               (50x50, transparent outer margin)
  - packaging/msix/Assets/Square150x150Logo.png       (150x150, #101828 tile + compact emblem)
  - packaging/msix/Assets/Wide310x150Logo.png         (310x150, #101828 wide tile + emblem + frdc)
  - packaging/msix/store-assets/StoreListing300x300.png (300x300, Store box-art icon)

Usage:
  python3 packaging/msix/generate_assets.py
"""

from __future__ import annotations

import math
import shutil
import subprocess
import tempfile
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent
ASSETS_DIR = ROOT / "Assets"
STORE_DIR = ROOT / "store-assets"


def irf_value(t: float) -> float:
    """Normalized damped macroeconomic impulse-response function on t in [0, 1].

    Smoothly rises from 0 at t=0 to a crisp peak near t~0.25, passes cleanly
    through a gentle damped undershoot around t~0.72, and settles tangentially
    (y(1) = 0, y'(1) = 0) onto the equilibrium baseline without any end-hook.
    """
    if t <= 0.0 or t >= 1.0:
        return 0.0
    envelope = (t ** 1.05) * math.exp(-3.15 * t) * ((1.0 - t) ** 2.15)
    oscillation = math.cos(2.72 * t - 0.08)
    return envelope * oscillation


def irf_points(
    x0: float,
    x1: float,
    y_zero: float,
    amp: float,
    n: int = 128,
) -> tuple[list[tuple[float, float]], tuple[float, float]]:
    """Sample IRF curve in SVG coordinates and return (points, peak_point)."""
    ts = [i / n for i in range(n + 1)]
    vals = [irf_value(t) for t in ts]
    max_val = max(vals)
    pts: list[tuple[float, float]] = []
    peak_pt = (x0, y_zero)
    best_v = -1e9
    for t, v in zip(ts, vals):
        nv = v / max_val
        x = x0 + (x1 - x0) * t
        y = y_zero - amp * nv
        pts.append((x, y))
        if nv > best_v:
            best_v = nv
            peak_pt = (x, y)
    return pts, peak_pt


def band_polygon(
    x0: float,
    x1: float,
    y_zero: float,
    amp: float,
    band_scale: float,
    n: int = 128,
) -> str:
    """Sample a clean symmetric econometric confidence ribbon around the IRF."""
    ts = [i / n for i in range(n + 1)]
    vals = [irf_value(t) for t in ts]
    max_val = max(vals)
    upper: list[tuple[float, float]] = []
    lower: list[tuple[float, float]] = []
    for t, v in zip(ts, vals):
        nv = v / max_val
        # Zero width at shock origin and horizon end; smooth confidence fan across hump
        half_w = band_scale * amp * (t ** 0.55) * ((1.0 - t) ** 1.35) * 2.4
        x = x0 + (x1 - x0) * t
        y = y_zero - amp * nv
        upper.append((x, y - half_w))
        lower.append((x, y + half_w))
    poly = upper + list(reversed(lower))
    return " ".join(f"{x:.2f},{y:.2f}" for x, y in poly)


def path_d(pts: list[tuple[float, float]]) -> str:
    head = f"M {pts[0][0]:.2f} {pts[0][1]:.2f}"
    body = " ".join(f"L {x:.2f} {y:.2f}" for x, y in pts[1:])
    return f"{head} {body}"


def emblem_group(
    x: float,
    y: float,
    size: float,
    rx: float,
    *,
    compact: bool = False,
    shadow: bool = False,
    uid: str = "e",
) -> tuple[str, str]:
    """Return (defs_svg, group_svg) for the compact econometric IRF emblem."""
    pad_l = size * (0.175 if compact else 0.185)
    pad_r = size * (0.155 if compact else 0.165)
    pad_t = size * (0.245 if compact else 0.255)
    y_zero = y + size * 0.675
    amp = (y_zero - (y + pad_t)) * 0.94

    px0 = x + pad_l
    px1 = x + size - pad_r

    pts, peak = irf_points(px0, px1, y_zero, amp, n=128)
    band_pts = band_polygon(px0, px1, y_zero, amp, band_scale=0.28 if not compact else 0.25, n=128)
    curve_d = path_d(pts)

    # Optically tuned stroke and node proportions
    curve_sw = size * (0.056 if compact else 0.042)
    axis_sw = max(0.9, size * (0.024 if compact else 0.013))
    rim_sw = max(0.95, size * (0.024 if compact else 0.012))
    peak_r = size * (0.052 if compact else 0.036)
    peak_cutout_r = peak_r + size * (0.022 if compact else 0.018)
    origin_r = size * (0.034 if compact else 0.021)

    shadow_def = ""
    shadow_attr = ""
    if shadow:
        shadow_def = f"""
    <filter id="{uid}_sh" x="-22%" y="-22%" width="144%" height="148%">
      <feDropShadow dx="0" dy="{size * 0.042:.2f}" stdDeviation="{size * 0.068:.2f}" flood-color="#020617" flood-opacity="0.50"/>
    </filter>"""
        shadow_attr = f' filter="url(#{uid}_sh)"'

    defs = f"""
    <linearGradient id="{uid}_plate" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#18243A"/>
      <stop offset="52%" stop-color="#10192B"/>
      <stop offset="100%" stop-color="#0A101D"/>
    </linearGradient>
    <linearGradient id="{uid}_rim" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#E2E8F0" stop-opacity="0.30"/>
      <stop offset="48%" stop-color="#94A3B8" stop-opacity="0.16"/>
      <stop offset="100%" stop-color="#64748B" stop-opacity="0.22"/>
    </linearGradient>
    <linearGradient id="{uid}_band" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#38BDF8" stop-opacity="0.06"/>
      <stop offset="28%" stop-color="#38BDF8" stop-opacity="0.22"/>
      <stop offset="66%" stop-color="#60A5FA" stop-opacity="0.11"/>
      <stop offset="100%" stop-color="#60A5FA" stop-opacity="0.02"/>
    </linearGradient>
    <linearGradient id="{uid}_line" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#E2E8F0"/>
      <stop offset="30%" stop-color="#FFFFFF"/>
      <stop offset="100%" stop-color="#CBD5E1"/>
    </linearGradient>
    <clipPath id="{uid}_clip">
      <rect x="{x:.2f}" y="{y:.2f}" width="{size:.2f}" height="{size:.2f}" rx="{rx:.2f}" ry="{rx:.2f}"/>
    </clipPath>{shadow_def}"""

    l_axis = ""
    if not compact:
        ax_x = px0
        ax_top = y + size * 0.21
        ax_bot = y + size * 0.775
        l_axis = (
            f'\n      <line x1="{ax_x:.2f}" y1="{ax_top:.2f}" x2="{ax_x:.2f}" y2="{ax_bot:.2f}" '
            f'stroke="#64748B" stroke-opacity="0.36" stroke-width="{axis_sw:.2f}" stroke-linecap="round"/>'
        )

    peak_inner = ""
    if not compact:
        peak_inner = (
            f'\n      <circle cx="{peak[0]:.2f}" cy="{peak[1]:.2f}" '
            f'r="{peak_r * 0.42:.2f}" fill="#F8FAFC"/>'
        )

    group = f"""
  <g{shadow_attr}>
    <rect x="{x:.2f}" y="{y:.2f}" width="{size:.2f}" height="{size:.2f}" rx="{rx:.2f}" ry="{rx:.2f}" fill="url(#{uid}_plate)"/>
    <g clip-path="url(#{uid}_clip)">{l_axis}
      <line x1="{px0:.2f}" y1="{y_zero:.2f}" x2="{px1 + size * 0.015:.2f}" y2="{y_zero:.2f}"
            stroke="#64748B" stroke-opacity="0.56" stroke-width="{axis_sw:.2f}" stroke-linecap="round"/>
      <polygon points="{band_pts}" fill="url(#{uid}_band)"/>
      <path d="{curve_d}" fill="none" stroke="url(#{uid}_line)" stroke-width="{curve_sw:.2f}"
            stroke-linecap="round" stroke-linejoin="round"/>
      <circle cx="{px0:.2f}" cy="{y_zero:.2f}" r="{origin_r:.2f}" fill="#38BDF8" fill-opacity="0.92"/>
      <circle cx="{peak[0]:.2f}" cy="{peak[1]:.2f}" r="{peak_cutout_r:.2f}" fill="#111A2C"/>
      <circle cx="{peak[0]:.2f}" cy="{peak[1]:.2f}" r="{peak_r:.2f}" fill="#38BDF8"/>{peak_inner}
    </g>
    <rect x="{x + rim_sw / 2:.2f}" y="{y + rim_sw / 2:.2f}" width="{size - rim_sw:.2f}" height="{size - rim_sw:.2f}"
          rx="{max(1.0, rx - rim_sw / 2):.2f}" ry="{max(1.0, rx - rim_sw / 2):.2f}"
          fill="none" stroke="url(#{uid}_rim)" stroke-width="{rim_sw:.2f}"/>
  </g>"""
    return defs, group


def frdc_wordmark_svg(x: float, y_center: float, scale: float = 1.0) -> str:
    """Pure geometric vector stroke wordmark 'frdc' (zero font dependency).

    Constructed on a refined Swiss geometric grid (ascender y=2.5, x-height top
    y=11.5, baseline y=33.5, uniform rounded stroke weight 3.85).
    Total unscaled width = 78.5 (from x=2.0 to x=80.5), height = 31.0.
    """
    sw = 3.85
    paths = [
        # 'f': balanced stem, clean top hook, compact crossbar
        "M 12.2 2.5 C 8.0 2.5 6.2 4.8 6.2 9.0 L 6.2 33.5",
        "M 2.0 13.0 L 11.8 13.0",
        # 'r': tight kerning to 'f', smooth compact shoulder
        "M 20.4 11.8 L 20.4 33.5",
        "M 20.4 18.8 C 21.3 13.8 24.4 11.6 29.0 11.6",
        # 'd': clean geometric bowl + full ascender
        "M 53.0 2.5 L 53.0 33.5",
        "M 53.0 17.4 C 51.2 13.4 47.9 11.6 43.9 11.6 C 37.8 11.6 33.8 16.0 33.8 22.6 C 33.8 29.2 37.8 33.5 43.9 33.5 C 47.9 33.5 51.2 31.7 53.0 27.7",
        # 'c': matching open geometric bowl
        "M 79.6 16.3 C 77.9 13.2 74.7 11.6 70.9 11.6 C 64.9 11.6 60.9 16.0 60.9 22.6 C 60.9 29.2 64.9 33.5 70.9 33.5 C 74.7 33.5 77.9 31.9 79.6 28.8",
    ]
    path_tags = "\n      ".join(
        f'<path d="{d}" fill="none" stroke="#F1F5F9" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>'
        for d in paths
    )
    # Visual vertical center of 'frdc' (weighted slightly toward x-height center y=22.5)
    ty = y_center - 20.2 * scale
    return f"""
  <g transform="translate({x - 2.0 * scale:.2f},{ty:.2f}) scale({scale:.4f})">
      {path_tags}
  </g>"""


def make_compact_icon_svg(dim: int, margin: float, rx: float) -> str:
    size = dim - 2 * margin
    defs, grp = emblem_group(margin, margin, size, rx, compact=True, shadow=False, uid=f"c{dim}")
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{dim}" height="{dim}" viewBox="0 0 {dim} {dim}">
  <defs>{defs}
  </defs>{grp}
</svg>
"""


def make_tile_square_svg(dim: int, emblem_ratio: float, rx_ratio: float) -> str:
    size = dim * emblem_ratio
    offset = (dim - size) / 2.0
    rx = size * rx_ratio
    defs, grp = emblem_group(offset, offset, size, rx, compact=False, shadow=True, uid=f"sq{dim}")
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{dim}" height="{dim}" viewBox="0 0 {dim} {dim}">
  <defs>
    <radialGradient id="bg{dim}" cx="35%" cy="25%" r="85%">
      <stop offset="0%" stop-color="#152036"/>
      <stop offset="60%" stop-color="#101828"/>
      <stop offset="100%" stop-color="#0B111E"/>
    </radialGradient>{defs}
  </defs>
  <rect width="{dim}" height="{dim}" fill="url(#bg{dim})"/>{grp}
</svg>
"""


def make_wide_tile_svg() -> str:
    w, h = 310, 150
    emblem_sz = 72.0
    wm_scale = 1.08
    wm_w = 78.5 * wm_scale
    gap = 24.0
    total_w = emblem_sz + gap + wm_w
    start_x = (w - total_w) / 2.0
    emblem_y = (h - emblem_sz) / 2.0

    defs, grp = emblem_group(
        start_x, emblem_y, emblem_sz, emblem_sz * 0.23, compact=False, shadow=True, uid="wd"
    )
    wm = frdc_wordmark_svg(x=start_x + emblem_sz + gap, y_center=h / 2.0, scale=wm_scale)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <defs>
    <radialGradient id="bgw" cx="30%" cy="28%" r="85%">
      <stop offset="0%" stop-color="#152036"/>
      <stop offset="60%" stop-color="#101828"/>
      <stop offset="100%" stop-color="#0B111E"/>
    </radialGradient>{defs}
  </defs>
  <rect width="{w}" height="{h}" fill="url(#bgw)"/>{grp}{wm}
</svg>
"""


def render_svg(svg_text: str, out_png: Path, width: int, height: int) -> None:
    rsvg = shutil.which("rsvg-convert")
    if not rsvg:
        raise RuntimeError("rsvg-convert not found on PATH (install librsvg)")
    out_png.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", encoding="utf-8", delete=False) as tf:
        tf.write(svg_text)
        svg_path = Path(tf.name)
    try:
        subprocess.run(
            [rsvg, "-w", str(width), "-h", str(height), "-o", str(out_png), str(svg_path)],
            check=True,
        )
    finally:
        svg_path.unlink(missing_ok=True)

    # Normalize to consistent 8-bit RGBA PNG for Windows MSIX / Partner Center ingestion
    with Image.open(out_png) as im:
        rgba = im.convert("RGBA")
        assert rgba.size == (width, height), f"Unexpected size {rgba.size} != {(width, height)}"
        rgba.save(out_png, format="PNG", optimize=True)


def main() -> None:
    targets = [
        (ASSETS_DIR / "Square44x44Logo.png", 44, 44, make_compact_icon_svg(44, margin=2.5, rx=9.0)),
        (ASSETS_DIR / "StoreLogo.png", 50, 50, make_compact_icon_svg(50, margin=2.5, rx=10.5)),
        (ASSETS_DIR / "Square150x150Logo.png", 150, 150, make_tile_square_svg(150, emblem_ratio=0.58, rx_ratio=0.23)),
        (ASSETS_DIR / "Wide310x150Logo.png", 310, 150, make_wide_tile_svg()),
        (STORE_DIR / "StoreListing300x300.png", 300, 300, make_tile_square_svg(300, emblem_ratio=0.60, rx_ratio=0.23)),
    ]
    for out_path, w, h, svg_text in targets:
        render_svg(svg_text, out_path, w, h)
        print(f"Generated {out_path.relative_to(ROOT.parent.parent)} ({w}x{h}, {out_path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
