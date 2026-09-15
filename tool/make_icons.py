"""Erzeugt Web- und Android-Icons aus dem App-Icon der Web-App (512x512 PNG).

Zwischenloesung bis zum eigenen Icon aus AP 3.4: Das bisherige Icon ersetzt das
Flutter-Standardlogo.

Usage: python tool/make_icons.py [pfad-zur-web-app]
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
WEB_APP = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT.parent / "bachmann_jass_game"
SOURCE = WEB_APP / "public" / "app-icon.png"

WEB_ICONS = {
    "web/favicon.png": 32,
    "web/icons/Icon-192.png": 192,
    "web/icons/Icon-512.png": 512,
    "web/icons/Icon-maskable-192.png": 192,
    "web/icons/Icon-maskable-512.png": 512,
}
ANDROID_ICONS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def save(image: Image.Image, target: Path, size: int) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.LANCZOS).save(target, "PNG", optimize=True)


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    for relative, size in WEB_ICONS.items():
        save(image, ROOT / relative, size)
    for folder, size in ANDROID_ICONS.items():
        save(image, ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png", size)
    print(f"{len(WEB_ICONS) + len(ANDROID_ICONS)} Icons geschrieben")


if __name__ == "__main__":
    main()
