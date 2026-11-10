"""Iteration 1.7: original combat sound effects, synthesised from scratch.

python -I tools/audio/make_combat_sfx.py [out_dir]   (default assets/audio/sfx)

No samples or third-party recordings are used: every sound is built from sine
partials, filtered noise and envelopes with a fixed random seed, so the output is
reproducible and the project owns it outright (released with the game's assets).
Requires numpy and scipy. Writes 16-bit mono 44.1 kHz WAV files.
"""
import pathlib
import sys
import wave

import numpy as np
from scipy import signal

SR = 44100
rng = np.random.default_rng(1707)


# ---------------------------------------------------------------- primitives
def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def env(seconds, attack=0.005, decay=0.2, hold=0.0, curve=1.0):
    """Linear attack, optional hold, exponential decay (time constant `decay`)."""
    t = t_axis(seconds)
    e = np.clip(t / max(attack, 1e-4), 0, 1)
    tail = np.clip(t - attack - hold, 0, None)
    e = e * np.exp(-tail / max(decay, 1e-4)) ** curve
    return e


def noise(seconds):
    return rng.standard_normal(int(seconds * SR))


def sine_sweep(seconds, f0, f1, exp=True):
    t = t_axis(seconds)
    if exp:
        freq = f0 * (f1 / f0) ** (t / seconds)
    else:
        freq = f0 + (f1 - f0) * t / seconds
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(phase)


def tone(seconds, freq, partials=((1, 1.0),), attack=0.004, decay=0.4, detune=0.0):
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for mult, amp in partials:
        f = freq * mult * (1 + detune * rng.uniform(-1, 1))
        out += amp * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
    return out * env(seconds, attack, decay)


def lowpass(x, cutoff, order=2):
    sos = signal.butter(order, min(cutoff, SR * 0.45), "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x, low, high, order=2):
    sos = signal.butter(order, [low, min(high, SR * 0.45)], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def swept_band(x, f_start, f_end, q=1.4, exp=True):
    """State-variable band-pass whose centre moves from f_start to f_end."""
    n = len(x)
    pos = np.arange(n) / max(n - 1, 1)
    centre = f_start * (f_end / f_start) ** pos if exp else f_start + (f_end - f_start) * pos
    f = 2 * np.sin(np.pi * np.minimum(centre, SR * 0.2) / SR)
    damp = 1.0 / q
    low = band = 0.0
    out = np.empty(n)
    for i in range(n):
        high = x[i] - low - damp * band
        band += f[i] * high
        low += f[i] * band
        out[i] = band
    return out


def swept_low(x, f_start, f_end):
    """One-pole low-pass with a moving cutoff (exponential)."""
    n = len(x)
    pos = np.arange(n) / max(n - 1, 1)
    cutoff = f_start * (f_end / f_start) ** pos
    a = np.exp(-2 * np.pi * cutoff / SR)
    out = np.empty(n)
    y = 0.0
    for i in range(n):
        y = (1 - a[i]) * x[i] + a[i] * y
        out[i] = y
    return out


def crackle(seconds, density, low=1800, high=7000, decay=0.25, seed_shift=0):
    """Sparse random clicks (embers, gravel, ice grains), band-limited."""
    n = int(seconds * SR)
    out = np.zeros(n)
    t = t_axis(seconds)
    probability = density / SR * np.exp(-t / decay)
    hits = rng.random(n) < probability
    out[hits] = rng.uniform(-1, 1, hits.sum())
    return bandpass(out, low, high)


def grains(seconds, count, f_low, f_high, length=(0.02, 0.09), spread=0.35, start=0.0):
    """Short decaying sine pings (glass, crystal, sparkle)."""
    out = np.zeros(int(seconds * SR))
    for _ in range(count):
        at = start + spread * rng.random() ** 1.6
        f = np.exp(rng.uniform(np.log(f_low), np.log(f_high)))
        dur = rng.uniform(*length)
        g = tone(dur * 5, f, ((1, 1.0), (2.76, 0.25)), attack=0.001, decay=dur) * rng.uniform(0.3, 1.0)
        i = int(at * SR)
        j = min(len(out), i + len(g))
        if i < len(out):
            out[i:j] += g[: j - i]
    return out


def knock(seconds, freq=320, decay=0.05, noise_band=(400, 2200), amount=1.0):
    """Mid-range body of an impact, audible on small phone speakers."""
    body = sine_sweep(seconds, freq * 1.25, freq * 0.8) * env(seconds, 0.001, decay)
    grit = bandpass(noise(seconds), *noise_band) * env(seconds, 0.001, decay * 0.8)
    return (body * 0.8 + grit * 0.7) * amount


def pad(x, seconds):
    n = int(seconds * SR)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def at(x, offset, total):
    out = np.zeros(int(total * SR))
    i = int(offset * SR)
    j = min(len(out), i + len(x))
    out[i:j] += x[: j - i]
    return out


def reverb(x, size=0.4, wet=0.2, bright=5000):
    """Short synthetic room: decaying filtered noise impulse response."""
    ir_t = t_axis(size)
    ir = lowpass(rng.standard_normal(len(ir_t)), bright) * np.exp(-ir_t / (size / 4.5))
    ir /= np.sqrt(np.sum(ir ** 2))
    tail = signal.fftconvolve(x, ir)[: len(x) + len(ir_t)]
    dry = np.concatenate([x, np.zeros(len(tail) - len(x))])
    return dry * (1 - wet * 0.5) + tail * wet


def finish(x, peak_db=-1.0, fade=0.012, drive=0.0):
    if drive > 0:
        x = np.tanh(x * (1 + drive)) / np.tanh(1 + drive)
    x = x - np.mean(x)
    # Trim the inaudible reverb tail (below -60 dB of the peak).
    loud = np.nonzero(np.abs(x) > np.max(np.abs(x)) * 0.001)[0]
    if len(loud):
        x = x[: loud[-1] + 1]
    fade_n = int(fade * SR)
    if fade_n and len(x) > 2 * fade_n:
        x[-fade_n:] *= np.linspace(1, 0, fade_n) ** 2
        x[:16] *= np.linspace(0, 1, 16)
    peak = np.max(np.abs(x)) or 1.0
    return x / peak * 10 ** (peak_db / 20)


def mix(*parts):
    length = max(len(p) for p in parts)
    return sum(pad(p, length / SR) for p in parts)


# ---------------------------------------------------------------- sounds
def swing():
    s = 0.3
    w = swept_band(noise(s), 380, 2600, q=1.3) * np.sin(np.pi * np.clip(t_axis(s) / s, 0, 1)) ** 1.6
    return finish(reverb(w * 2.2, 0.25, 0.12), -4)


def enemy_swing():
    s = 0.42
    w = swept_band(noise(s), 140, 820, q=1.1) * np.sin(np.pi * np.clip(t_axis(s) / s, 0, 1)) ** 1.4
    grind = bandpass(noise(s), 200, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 28 * t_axis(s))) * env(s, 0.12, 0.2)
    return finish(reverb(w * 2.0 + grind * 0.5, 0.3, 0.15), -3)


def hit(heavy=False):
    s = 0.85 if heavy else 0.45
    click = highpass(noise(0.006), 2500) * 0.9
    body = sine_sweep(s, 150 if not heavy else 120, 48 if not heavy else 36) * env(s, 0.002, 0.10 if not heavy else 0.17)
    crunch = lowpass(noise(s), 3200) * env(s, 0.001, 0.05 if not heavy else 0.08)
    gravel = crackle(s, 900 if not heavy else 1500, 900, 5200, 0.09 if not heavy else 0.2) * 2.2
    metal = sum(tone(s, f, attack=0.001, decay=0.12 if not heavy else 0.2) for f in (2390, 3870, 5610)) * 0.12
    x = mix(click, body * (1.0 if heavy else 0.8), crunch * 0.55, gravel * 0.8, metal,
            knock(s, 260 if heavy else 340, 0.08 if heavy else 0.05, amount=1.4 if heavy else 1.2))
    if heavy:
        x = mix(x, lowpass(noise(s), 400) * env(s, 0.004, 0.25) * 0.6)
    return finish(reverb(x, 0.45 if heavy else 0.3, 0.18), -1, drive=1.2 if heavy else 0.6)


def hit_hero():
    s = 0.42
    thump = sine_sweep(s, 110, 52) * env(s, 0.002, 0.09)
    cloth = lowpass(noise(s), 1300) * env(s, 0.001, 0.07)
    snap = highpass(noise(0.01), 3000) * 0.4
    return finish(reverb(mix(thump * 0.9, cloth * 0.8, snap, knock(s, 300, 0.045, (500, 1800), 1.1)), 0.3, 0.15), -2, drive=0.8)


def fire_cast():
    s = 0.7
    swell = env(s, 0.42, 0.18, curve=1.0)
    rumble = lowpass(noise(s), 520) * swell * 1.6
    air = swept_band(noise(s), 300, 1900, q=1.2) * swell
    embers = crackle(s, 220, 2200, 7500, 5.0) * np.clip(t_axis(s) / s, 0, 1) ** 1.5 * 3
    return finish(reverb(mix(rumble, air, embers), 0.35, 0.18), -4)


def fire_impact():
    s = 1.1
    burst = swept_low(noise(s), 5200, 260) * env(s, 0.003, 0.28)
    sub = sine_sweep(s, 78, 34) * env(s, 0.004, 0.22)
    roar = bandpass(noise(s), 180, 1400) * env(s, 0.02, 0.35) * 0.6
    embers = crackle(s, 700, 2000, 8000, 0.45) * 2.6
    return finish(reverb(mix(burst * 1.4, sub * 0.7, roar * 1.4, embers, knock(s, 240, 0.09, (300, 1600), 0.9)), 0.6, 0.2), -1, drive=1.0)


def ice_cast():
    s = 0.8
    shimmer = grains(s, 26, 2100, 7200, (0.08, 0.28), 0.55)
    air = highpass(noise(s), 6000) * env(s, 0.35, 0.18) * 0.25
    tone_bed = sum(tone(s, f, attack=0.25, decay=0.35, detune=0.003) for f in (1318.5, 1975.5)) * 0.12
    return finish(reverb(mix(shimmer, air, tone_bed), 0.6, 0.3, bright=9000), -5)


def ice_impact():
    s = 1.0
    crack = highpass(noise(0.012), 3500) * 1.2
    thud = sine_sweep(s, 96, 44) * env(s, 0.002, 0.07)
    shatter = grains(s, 70, 2800, 9500, (0.012, 0.06), 0.3, 0.01) * 1.4
    tail = sum(tone(s, f, attack=0.03, decay=0.32, detune=0.004) for f in (1567.98, 2349.3, 3135.9)) * 0.10
    tail = tail * (0.75 + 0.25 * np.sin(2 * np.pi * 11 * t_axis(s)))
    return finish(reverb(mix(crack, thud * 0.9, shatter, at(tail, 0.05, s)), 0.55, 0.28, bright=10000), -1, drive=0.4)


def heal():
    s = 1.5
    notes = (659.25, 830.61, 987.77, 1318.51)
    bells = sum(at(tone(s, f, ((1, 1.0), (2, 0.28), (3, 0.08)), attack=0.012, decay=0.55), i * 0.075, s) for i, f in enumerate(notes))
    pad_ = sum(tone(s, f, attack=0.3, decay=0.5, detune=0.004) for f in (329.63, 493.88)) * 0.25
    sparkle = grains(s, 14, 3000, 7000, (0.05, 0.16), 0.6, 0.15) * 0.35
    return finish(reverb(mix(bells * 0.6, pad_, sparkle), 0.9, 0.35, bright=7000), -5)


def protect():
    s = 0.95
    hum = sum(tone(s, f, attack=0.12, decay=0.3) for f in (110, 165, 220.5)) * 0.45
    shing = at(sum(tone(s, f, attack=0.002, decay=0.35) for f in (1830, 2915, 4620, 6080)) * 0.22, 0.1, s)
    sweep = swept_band(noise(0.35), 2400, 500, q=1.5) * np.sin(np.pi * t_axis(0.35) / 0.35) ** 2 * 0.6
    return finish(reverb(mix(hum, shing, sweep), 0.55, 0.25), -4)


def haste():
    s = 0.7
    t = t_axis(0.42)
    freq = 220 * (4.0 ** (t / 0.42))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    saw = sum(np.sin(k * phase) / k for k in range(1, 7)) * env(0.42, 0.01, 0.3)
    saw = lowpass(saw, 3000)
    whoosh = swept_band(noise(0.45), 500, 4200, q=1.6) * np.sin(np.pi * t_axis(0.45) / 0.45) ** 1.5
    ping = at(tone(0.4, 1760, ((1, 1.0), (2, 0.2)), attack=0.002, decay=0.12), 0.36, s) * 0.5
    return finish(reverb(mix(saw * 0.45, whoosh, ping), 0.35, 0.18), -4)


def guard():
    s = 0.45
    clank = sum(tone(s, f, attack=0.001, decay=0.11) for f in (930, 1720, 2610, 3480)) * 0.35
    thump = sine_sweep(s, 130, 70) * env(s, 0.002, 0.06)
    tick = highpass(noise(0.008), 3000) * 0.6
    return finish(reverb(mix(clank, thump * 0.7, tick), 0.3, 0.2), -3)


def knockout():
    s = 1.1
    fall = sine_sweep(s, 92, 38) * env(s, 0.004, 0.16)
    dust = lowpass(noise(s), 900) * env(s, 0.01, 0.18) * 0.5
    sigh = sine_sweep(0.7, 440, 196) * env(0.7, 0.02, 0.28) * 0.22
    return finish(reverb(mix(at(fall, 0.05, s), at(dust, 0.05, s), sigh, at(knock(0.4, 230, 0.07, (300, 1400), 0.9), 0.05, s)), 0.5, 0.22), -3, drive=0.5)


def ui_select():
    s = 0.09
    return finish(mix(tone(s, 1480, ((1, 1.0), (2, 0.15)), attack=0.001, decay=0.018), highpass(noise(0.003), 4000) * 0.2), -9)


def ui_confirm():
    s = 0.24
    a = tone(0.12, 880, ((1, 1.0), (3, 0.12)), attack=0.002, decay=0.045)
    b = tone(0.16, 1318.5, ((1, 1.0), (3, 0.12)), attack=0.002, decay=0.06)
    return finish(reverb(mix(a, at(b, 0.06, s)), 0.2, 0.12), -8)


def ui_cancel():
    s = 0.24
    a = tone(0.12, 740, ((1, 1.0), (3, 0.1)), attack=0.002, decay=0.045)
    b = tone(0.16, 493.9, ((1, 1.0), (3, 0.1)), attack=0.002, decay=0.06)
    return finish(reverb(mix(a, at(b, 0.06, s)), 0.2, 0.12), -9)


def resonance_ready():
    s = 1.4
    chord = sum(tone(s, f, ((1, 1.0), (2, 0.2)), attack=0.18, decay=0.45, detune=0.003) for f in (440, 554.37, 659.25, 880))
    chord *= 0.8 + 0.2 * np.sin(2 * np.pi * 6 * t_axis(s))
    sparkle = grains(s, 18, 2500, 7500, (0.05, 0.14), 0.8, 0.1) * 0.4
    return finish(reverb(mix(chord * 0.35, sparkle), 0.8, 0.3, bright=8000), -6)


def summon():
    s = 1.6
    rumble = lowpass(noise(s), 240) * env(s, 0.35, 0.5) * 1.8
    sub = sine_sweep(s, 55, 30) * env(s, 0.25, 0.6)
    roar = bandpass(noise(s), 150, 900) * env(s, 0.4, 0.4) * (0.7 + 0.3 * np.sin(2 * np.pi * 7 * t_axis(s)))
    embers = crackle(s, 400, 2000, 7500, 1.2) * 2.0
    return finish(reverb(mix(rumble, sub * 0.7, roar * 1.6, embers), 0.8, 0.25), -1, drive=0.8)


SOUNDS = {
    "swing": swing, "enemy_swing": enemy_swing,
    "hit": hit, "hit_heavy": lambda: hit(True), "hit_hero": hit_hero,
    "fire_cast": fire_cast, "fire_impact": fire_impact,
    "ice_cast": ice_cast, "ice_impact": ice_impact,
    "heal": heal, "protect": protect, "haste": haste, "guard": guard,
    "knockout": knockout, "summon": summon, "resonance_ready": resonance_ready,
    "ui_select": ui_select, "ui_confirm": ui_confirm, "ui_cancel": ui_cancel,
}


def write(path, data):
    pcm = np.clip(data * 32767, -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())


def main():
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "assets/audio/sfx")
    out.mkdir(parents=True, exist_ok=True)
    for name, build in SOUNDS.items():
        data = build()
        write(out / f"{name}.wav", data)
        print(f"{name}: {len(data) / SR:.2f} s")


if __name__ == "__main__":
    main()
