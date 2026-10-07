"""Build a side-by-side app font and exhaustive lookup from the installed font.

Requires fontTools. The original sketchybar-app-font is never modified.
"""
import json
import shlex
from pathlib import Path
from xml.etree import ElementTree

from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path
from fontTools.ttLib import TTFont

directory = Path(__file__).resolve().parent
source = Path.home() / "Library/Fonts/sketchybar-app-font.ttf"
font = TTFont(source)
metadata = json.loads(font["meta"].data["APPM"])
codepoint = 0xE900
glyph_name = ":incy:"
assert codepoint not in font.getBestCmap()

pen = TTGlyphPen(font.getGlyphSet())
quadratics = Cu2QuPen(pen, max_err=1.0)
units = font["head"].unitsPerEm
scale = units / 1000
transform = TransformPen(quadratics, (scale, 0, 0, -scale, 0, units))
for path in ElementTree.parse(directory / "incy.svg").getroot():
    parse_path(path.attrib["d"], transform)
glyph_order = list(font.getGlyphOrder())
font["glyf"][glyph_name] = pen.glyph()
font.setGlyphOrder(glyph_order + [glyph_name])
font["hmtx"].metrics[glyph_name] = (units, 50)
for table in font["cmap"].tables:
    if table.isUnicode():
        table.cmap[codepoint] = glyph_name
for record in font["name"].names:
    if record.nameID in (1, 4, 16):
        value = "Rice App Icons"
    elif record.nameID in (2, 17):
        value = "Regular"
    elif record.nameID == 6:
        value = "RiceAppIcons-Regular"
    elif record.nameID == 3:
        value = "Rice App Icons 1.0"
    else:
        continue
    record.string = value.encode(record.getEncoding())
font.save(directory / "rice-app-icons.ttf")

# Mechanical lookup generation: reuse the exact aliases shipped with the font.
# Known overrides stay in plugins/icon_map.sh, ahead of this generated lookup.
lines = ["#!/usr/bin/env sh", "# Generated from sketchybar-app-font's APPM metadata.", 'case "$1" in']
aliases = set()
cmap = font.getBestCmap()
for ligature, point, names in metadata["icons"]:
    if point not in cmap or not names:
        continue
    patterns = []
    for name in names:
        if not name or name in aliases:
            continue
        aliases.add(name)
        patterns.append("*".join(shlex.quote(part) for part in name.split("*")))
    if patterns:
        lines.append("  " + "|".join(patterns) + " ) printf %s " + shlex.quote(ligature) + " ;;")
lines.extend(["  *) printf %s ':default:' ;;", "esac", ""])
(directory / "app_glyphs.sh").write_text("\n".join(lines))
print(f"Built Rice App Icons with {len(aliases)} app aliases and the Incy outline.")
