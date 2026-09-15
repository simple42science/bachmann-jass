"""Konvertiert die Kartenbilder der Web-App (PNG, 1348x2104) in kleine WebP-Dateien.

Angezeigt werden Karten hoechstens etwa 180 logische Pixel breit, auf einem
3x-Display also 540 physische Pixel. 720 Pixel Breite reichen darum aus; die
App dekodiert zusaetzlich nur in der jeweils gebrauchten Groesse (cacheWidth).

Usage: python tool/convert_cards.py [pfad-zur-web-app]
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
WEB_APP = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT.parent / "bachmann_jass_game"
SOURCE = WEB_APP / "public" / "assets" / "jasskarten_deck_png_sharper"
TARGET = ROOT / "assets" / "cards"
WIDTH = 720
QUALITY = 88


def main() -> None:
    sources = sorted(SOURCE.glob("*.png"))
    if len(sources) != 36:
        raise SystemExit(f"Erwartet 36 Karten in {SOURCE}, gefunden {len(sources)}")

    TARGET.mkdir(parents=True, exist_ok=True)
    total = 0
    for source in sources:
        image = Image.open(source).convert("RGB")
        height = round(image.height * WIDTH / image.width)
        target = TARGET / f"{source.stem}.webp"
        image.resize((WIDTH, height), Image.LANCZOS).save(target, "WEBP", quality=QUALITY, method=6)
        total += target.stat().st_size

    print(f"{len(sources)} Karten nach {TARGET.relative_to(ROOT)} geschrieben ({total / 1024 / 1024:.2f} MB)")


if __name__ == "__main__":
    main()
