"""Before/after still comparisons from the Movie Maker captures (iteration 1.7).

python tools/combat_fx_stills.py <before.avi> <before_log> <after.avi> <after_log> <out_dir>

For each clip, picks the frame with the most new vivid pixels (bright or saturated)
against the clip's first frame (the moment of impact, usually) within its first 2 s, in both
captures, and writes compare-<name>.jpg (before left, after right) plus
after-<name>.jpg. The selection is automatic, so neither side is cherry-picked.
"""
import pathlib
import re
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FPS = 30


def clips(log):
    return {m[0]: (int(m[1]), int(m[2])) for m in re.findall(r"^CLIP (\S+) (\d+) (\d+)", pathlib.Path(log).read_text(errors="ignore"), re.M)}


def frames(avi, first, count, folder, width=None):
    scale = [] if width is None else ["-vf", f"scale={width}:-1"]
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", f"{first / FPS:.3f}", "-i", avi, "-frames:v", str(count), *scale,
                    str(folder / "f%04d.png")], check=True)
    return sorted(folder.glob("f*.png"))


def best_frame(avi, first, last):
    count = min(last - first, 60)
    with tempfile.TemporaryDirectory() as tmp:
        small = frames(avi, first, count, pathlib.Path(tmp), 240)
        # Effects add very bright or strongly coloured pixels; a camera zoom only
        # moves existing ones, so counting such pixels ignores framing changes.
        def vivid(path):
            hsv = np.asarray(Image.open(path).convert("HSV"), float) / 255
            sat, val = hsv[..., 1], hsv[..., 2]
            return np.count_nonzero(val > 0.93) + np.count_nonzero((sat > 0.55) & (val > 0.6))
        base = vivid(small[0])
        scores = [vivid(f) - base for f in small]
        return int(np.argmax(scores))


def grab(avi, frame):
    with tempfile.TemporaryDirectory() as tmp:
        path = frames(avi, frame, 1, pathlib.Path(tmp))[0]
        return Image.open(path).convert("RGB")


def label(image, text):
    draw = ImageDraw.Draw(image)
    try:
        font = ImageFont.truetype("assets/ui/fonts/AlegreyaSans-Bold.ttf", 30)
    except OSError:
        font = ImageFont.load_default()
    draw.rectangle([0, 0, 190, 44], fill=(13, 23, 32))
    draw.text((12, 5), text, fill=(236, 208, 138), font=font)


def main():
    before_avi, before_log, after_avi, after_log, out = sys.argv[1:6]
    out = pathlib.Path(out)
    before, after = clips(before_log), clips(after_log)
    for name in after:
        if name not in before:
            continue
        b = grab(before_avi, before[name][0] + best_frame(before_avi, *before[name]))
        a = grab(after_avi, after[name][0] + best_frame(after_avi, *after[name]))
        a.save(out / f"after-{name}.jpg", quality=88)
        label(b, "Antes · 1.6")
        label(a, "Después · 1.7")
        sheet = Image.new("RGB", (b.width + a.width + 8, max(b.height, a.height)), (13, 23, 32))
        sheet.paste(b, (0, 0))
        sheet.paste(a, (b.width + 8, 0))
        sheet.save(out / f"compare-{name}.jpg", quality=86)
        print(name)


if __name__ == "__main__":
    main()
