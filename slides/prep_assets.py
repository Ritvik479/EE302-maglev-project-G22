"""Crop report figures to the panel each slide needs. Run from slides/: python -I prep_assets.py"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
FIGS = ROOT / "figs"
OUT = Path(__file__).resolve().parent / "assets"
OUT.mkdir(exist_ok=True)

# name: (source, crop box (left, top, right, bottom) in pixels or None for the whole image)
CROPS = {
    "rig_photo": (ROOT / "data/lab_2026-11-16/screenshots/01_rig_front_panel_photo.jpeg", None),
    "force_fit": (FIGS / "p5_force_fit_all.png", (0, 42, 1666, 1056)),
    "plant_bode_mag": (FIGS / "p7_plant_bode.png", (0, 42, 1593, 600)),
    "pd_vs_cascade": (FIGS / "p17_pd_gain_grid.png", (1325, 108, 2512, 1115)),
    "sens_grid": (FIGS / "p8_margins.png", (0, 0, 990, 752)),
    "cases_corners": (FIGS / "p6_cases_corners.png", (0, 0, 2033, 742)),
    "sweep_39g": (FIGS / "p5_sweeps_lab_vs_sim.png", (0, 0, 1990, 482)),
    "stand_runs": (FIGS / "p14_stand_proximity.png", (0, 36, 1891, 592)),
    "variantD_lift": (FIGS / "p15_variantD_ramp.png", (0, 36, 618, 747)),
    "delay": (FIGS / "p9_delay.png", None),
    "wt_options": (FIGS / "p8_WT_options.png", None),
    "sine_loop": (FIGS / "p13_sine_loop.png", (0, 30, 1880, 1171)),
    "kg_test": (FIGS / "p4_kg_test.png", None),
}

for name, (src, box) in CROPS.items():
    im = Image.open(src).convert("RGB")
    if box:
        im = im.crop(box)
    ext = ".jpg" if src.suffix.lower() in (".jpg", ".jpeg") else ".png"
    dst = OUT / (name + ext)
    im.save(dst, quality=92) if ext == ".jpg" else im.save(dst)
    print(f"{name}: {im.size[0]}x{im.size[1]} ratio {im.size[0]/im.size[1]:.3f}")
