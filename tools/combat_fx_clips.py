"""Cut the Movie Maker AVI from tools/capture_combat_fx.gd into per-action clips.

python tools/combat_fx_clips.py <combat.avi> <log.txt> <out_dir> <tag> [--gif] [--sheets]

For each "CLIP name first last" line: <tag>-<name>.mp4 (H.264 + AAC, 960 px),
optionally <tag>-<name>.gif (480 px, 15 fps, no audio) and a contact sheet
(<tag>-<name>-sheet.png, one frame every 4) used to pick representative stills.
Requires ffmpeg on PATH.
"""
import pathlib
import re
import subprocess
import sys

FPS = 30


def run(args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    avi, log, out, tag = sys.argv[1:5]
    flags = set(sys.argv[5:])
    out = pathlib.Path(out)
    out.mkdir(parents=True, exist_ok=True)
    clips = re.findall(r"^CLIP (\S+) (\d+) (\d+)", pathlib.Path(log).read_text(encoding="utf-8", errors="ignore"), re.M)
    for name, first, last in clips:
        start = int(first) / FPS
        length = (int(last) - int(first)) / FPS
        base = out / f"{tag}-{name}"
        run(["ffmpeg", "-y", "-ss", f"{start:.3f}", "-t", f"{length:.3f}", "-i", avi,
             "-vf", "scale=854:-2", "-c:v", "libx264", "-preset", "slow", "-crf", "31", "-pix_fmt", "yuv420p",
             "-c:a", "aac", "-b:a", "96k", "-movflags", "+faststart", str(base) + ".mp4"])
        if "--gif" in flags:
            run(["ffmpeg", "-y", "-ss", f"{start:.3f}", "-t", f"{length:.3f}", "-i", avi, "-vf",
                 "fps=12,scale=400:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=4",
                 str(base) + ".gif"])
        if "--sheets" in flags:
            run(["ffmpeg", "-y", "-ss", f"{start:.3f}", "-t", f"{length:.3f}", "-i", avi, "-vf",
                 "select='not(mod(n\\,4))',scale=320:-1,drawtext=text='%{n}':x=6:y=6:fontsize=20:fontcolor=white:box=1:boxcolor=black,tile=5x4",
                 "-frames:v", "1", str(base) + "-sheet.png"])
        print(name, first, last)


if __name__ == "__main__":
    main()
