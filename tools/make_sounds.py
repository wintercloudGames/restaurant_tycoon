"""Generates the game's custom sounds (music, customer voices, cooking and restaurant effects)
into assets/sounds/ as .ogg files. Everything is synthesized here, so there are no licences to
worry about. Run from the project folder:  python tools/make_sounds.py
Needs numpy, scipy and ffmpeg (with libvorbis) on the PATH. Re-running overwrites the files.
"""
import os
import subprocess
import tempfile
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sounds")
rng = np.random.default_rng(7)


# ---- helpers -------------------------------------------------------------

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_ad(n, attack=0.005, decay=0.2):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-4))


def lowpass(x, hz, order=2):
    b, a = butter(order, min(hz / (SR / 2), 0.99), "low")
    return lfilter(b, a, x)


def highpass(x, hz, order=2):
    b, a = butter(order, min(hz / (SR / 2), 0.99), "high")
    return lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return lfilter(b, a, x)


def noise(n):
    return rng.uniform(-1, 1, n)


def place(buf, clip, start, gain=1.0, wrap=False):
    """Adds `clip` into `buf` at sample `start` (wrapping round the end for seamless loops)."""
    for i in range(len(clip)):
        j = start + i
        if j >= len(buf):
            if not wrap:
                break
            j %= len(buf)
        buf[j] += clip[i] * gain


def place_fast(buf, clip, start, gain=1.0, wrap=False):
    end = start + len(clip)
    if end <= len(buf):
        buf[start:end] += clip * gain
        return
    head = len(buf) - start
    buf[start:] += clip[:head] * gain
    if wrap:
        rest = clip[head:]
        while len(rest) > 0:
            k = min(len(rest), len(buf))
            buf[:k] += rest[:k] * gain
            rest = rest[k:]


def save(name, x, peak=0.89, quality=4):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    fd, wav = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    wavfile.write(wav, SR, (x * 32767).astype(np.int16))
    out = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(quality), out], check=True)
    os.remove(wav)
    print("wrote", out, "%.2fs" % (len(x) / SR))


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# ---- instruments ---------------------------------------------------------

def epiano(freq, dur, vel=1.0):
    t = t_axis(dur)
    mod = 1.2 * np.exp(-t * 6) * np.sin(2 * np.pi * freq * t)
    x = np.sin(2 * np.pi * freq * t + mod) + 0.25 * np.sin(2 * np.pi * 2 * freq * t) * np.exp(-t * 3)
    return x * env_ad(len(t), 0.004, 0.9) * vel


def vibes(freq, dur, vel=1.0):
    t = t_axis(dur)
    trem = 1 + 0.15 * np.sin(2 * np.pi * 5.5 * t)
    x = np.sin(2 * np.pi * freq * t) + 0.18 * np.sin(2 * np.pi * 4 * freq * t) * np.exp(-t * 8)
    return x * env_ad(len(t), 0.003, 0.7) * trem * vel


def bass(freq, dur, vel=1.0):
    t = t_axis(dur)
    x = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * 2 * freq * t) + 0.1 * np.sin(2 * np.pi * 3 * freq * t)
    e = np.clip(t / 0.01, 0, 1) * np.exp(-t / 0.5)
    return lowpass(x * e, 900) * vel


def kick():
    t = t_axis(0.3)
    f = 50 + 90 * np.exp(-t * 25)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 12)


def brush(dur=0.18):
    n = int(dur * SR)
    return bandpass(noise(n), 1800, 7000) * env_ad(n, 0.01, 0.07)


def hat():
    n = int(0.05 * SR)
    return highpass(noise(n), 7000) * env_ad(n, 0.001, 0.015)


def bell(freq, dur=1.4, partials=((1, 1.0), (2.0, 0.5), (2.76, 0.35), (5.4, 0.15)), decay=0.6):
    t = t_axis(dur)
    x = np.zeros_like(t)
    for ratio, amp in partials:
        x += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / (decay / ratio ** 0.5))
    return x * np.clip(t / 0.002, 0, 1)


# ---- music ---------------------------------------------------------------

def music():
    bpm = 96
    beat = 60.0 / bpm
    bars = 16
    total = int(bars * 4 * beat * SR)
    buf = np.zeros(total)
    # Chords as MIDI notes (a relaxed cafe progression in F).
    F, Dm, Gm, C7, Am, Bb = [53, 57, 60, 64], [50, 53, 57, 60], [55, 58, 62, 65], [48, 52, 55, 58], [57, 60, 64, 67], [58, 62, 65, 69]
    prog = [F, Dm, Gm, C7, F, Am, Bb, C7, Dm, Gm, C7, F, Bb, Am, Gm, C7]
    roots = [41, 38, 43, 36, 41, 45, 46, 36, 38, 43, 36, 41, 46, 45, 43, 36]
    scale = [65, 67, 69, 72, 74, 76, 77, 79]  # melody notes (F major pentatonic-ish, upper)
    swing = 0.62
    mel_rng = np.random.default_rng(3)
    for bar in range(bars):
        b0 = bar * 4 * beat
        chord = prog[bar]
        # Electric piano: chord on 1 and on the "and" of 2.
        for when, vel in ((0.0, 0.55), (1.0 + swing, 0.4)):
            for k, n in enumerate(chord):
                place_fast(buf, epiano(midi(n), 1.6, vel), int((b0 + when * beat + 0.008 * k) * SR), 0.16, wrap=True)
        # Bass: root, fifth, walk up into the next bar.
        r = roots[bar]
        nxt = roots[(bar + 1) % bars]
        for when, note in ((0, r), (2, r + 7), (3 + swing - 0.5, nxt - 1 if nxt > r else nxt + 1)):
            place_fast(buf, bass(midi(note), beat * 1.1), int((b0 + when * beat) * SR), 0.5, wrap=True)
        # Drums.
        for bt in range(4):
            if bt in (0, 2):
                place_fast(buf, kick(), int((b0 + bt * beat) * SR), 0.55, wrap=True)
            if bt in (1, 3):
                place_fast(buf, brush(), int((b0 + bt * beat) * SR), 0.18, wrap=True)
            for half, v in ((0.0, 0.07), (swing, 0.045)):
                place_fast(buf, hat(), int((b0 + (bt + half) * beat) * SR), v, wrap=True)
        # Melody: short phrases on vibes, resting every other half bar sometimes.
        if bar % 4 != 3:
            pos = 0.0
            while pos < 4.0:
                step = mel_rng.choice([0.5, 0.5, 1.0, 1.5])
                if mel_rng.random() < 0.72:
                    tones = [n + 12 for n in chord if n + 12 >= 62] + scale
                    note = int(mel_rng.choice(tones))
                    when = pos + (swing - 0.5 if (pos * 2) % 2 == 1 else 0)
                    place_fast(buf, vibes(midi(note), 1.2, 0.8), int((b0 + when * beat) * SR), 0.22, wrap=True)
                pos += step
    buf = lowpass(buf, 7000)
    save("music_cafe", buf, peak=0.8, quality=5)


# ---- customer voices (cute gibberish) -------------------------------------

VOWELS = {"a": (800, 1200), "e": (420, 2000), "i": (300, 2300), "o": (470, 850), "u": (330, 750)}


def formant(src, f1, f2):
    return bandpass(src, f1 * 0.7, f1 * 1.3) + 0.6 * bandpass(src, f2 * 0.8, f2 * 1.2)


def syllable(f0_start, f0_end, dur, vowel, breath=0.05):
    t = t_axis(dur)
    f0 = np.linspace(f0_start, f0_end, len(t)) * (1 + 0.02 * np.sin(2 * np.pi * 6 * t))
    phase = np.cumsum(f0) / SR
    saw = 2 * (phase % 1.0) - 1
    src = saw + breath * noise(len(t))
    f1, f2 = VOWELS[vowel]
    x = formant(src, f1, f2) + 0.15 * lowpass(saw, 600)
    e = np.clip(t / 0.015, 0, 1) * np.clip((dur - t) / 0.03, 0, 1)
    return x * e


def phrase(base, contour, count, vowels=None, gap=0.03, speed=1.0):
    parts = []
    for i in range(count):
        v = vowels[i] if vowels else rng.choice(list(VOWELS))
        d = rng.uniform(0.08, 0.13) / speed
        a = base * (1 + contour * (i / max(count - 1, 1) - 0.5)) * rng.uniform(0.94, 1.06)
        b = a * (1 + contour * 0.15)
        parts.append(syllable(a, b, d, v))
        parts.append(np.zeros(int(gap * SR)))
    return np.concatenate(parts)


def voices():
    pitches = [170, 210, 250, 300]
    for i, p in enumerate(pitches):
        save("voice_ask_%d" % i, phrase(p, 0.25, int(rng.integers(3, 6))))          # "a burger please!"
        save("voice_ok_%d" % i, phrase(p, 0.5, 2, ["u", "o"], speed=1.3))           # "mm-hm!"
        save("voice_happy_%d" % i, phrase(p * 1.1, 0.7, 3, ["a", "e", "i"]))       # pleased, rising
        save("voice_angry_%d" % i, phrase(p * 0.65, -0.6, 3, ["o", "a", "u"], speed=0.8))  # grumble, falling
    # "Mmm!" while eating: a hummed rise and fall.
    for i, p in enumerate((180, 240, 290)):
        t = t_axis(0.55)
        f0 = p * (1 + 0.25 * np.sin(np.pi * t / 0.55))
        saw = 2 * ((np.cumsum(f0) / SR) % 1.0) - 1
        x = lowpass(saw, 500) * np.clip(t / 0.05, 0, 1) * np.clip((0.55 - t) / 0.1, 0, 1)
        save("voice_yum_%d" % i, x)


def ambience():
    dur = 24.0
    buf = np.zeros(int(dur * SR))
    for _ in range(70):  # lots of quiet overlapping chatter
        p = rng.choice([140, 170, 200, 230, 260, 300])
        clip = phrase(p, rng.uniform(-0.3, 0.4), int(rng.integers(3, 8)), speed=rng.uniform(0.9, 1.2))
        place_fast(buf, lowpass(clip, 1800), int(rng.uniform(0, dur) * SR), rng.uniform(0.15, 0.35), wrap=True)
    for _ in range(10):  # cutlery and glasses
        place_fast(buf, bell(rng.uniform(2500, 4200), 0.3, ((1, 1), (1.5, 0.5), (2.3, 0.3)), 0.06), int(rng.uniform(0, dur) * SR), 0.25, wrap=True)
    buf += 0.02 * lowpass(noise(len(buf)), 600)
    save("ambience_restaurant", buf, peak=0.7)


# ---- effects -------------------------------------------------------------

def effects():
    # Footsteps: soft thumps (4 variants).
    for i in range(4):
        n = int(0.09 * SR)
        x = lowpass(noise(n), rng.uniform(250, 420)) * env_ad(n, 0.004, 0.025)
        x += 0.5 * np.sin(2 * np.pi * rng.uniform(70, 95) * np.arange(n) / SR) * env_ad(n, 0.002, 0.03)
        save("step_%d" % i, x, peak=0.7)
    # Door chime when a customer walks in: ding-dong.
    x = np.zeros(int(1.4 * SR))
    place_fast(x, bell(midi(76), 1.2, decay=0.5), 0)
    place_fast(x, bell(midi(72), 1.0, decay=0.5), int(0.32 * SR))
    save("door_chime", x, peak=0.6)
    # Order-up bell: a bright service-desk ding.
    save("order_up_bell", bell(1650, 1.6, ((1, 1), (2.4, 0.5), (3.9, 0.3), (5.8, 0.15)), 0.9), peak=0.75)
    # Cash register "ka-ching".
    x = np.zeros(int(1.0 * SR))
    n = int(0.12 * SR)
    place_fast(x, bandpass(noise(n), 1500, 6000) * env_ad(n, 0.002, 0.04), 0, 0.8)
    place_fast(x, bell(2350, 0.9, ((1, 1), (1.5, 0.6), (2.0, 0.4)), 0.35), int(0.1 * SR), 0.9)
    place_fast(x, bell(3150, 0.8, ((1, 1), (1.5, 0.5)), 0.3), int(0.16 * SR), 0.6)
    save("cash_register", x, peak=0.75)
    # Plate down on the table.
    save("plate_clink", bell(2900, 0.35, ((1, 1), (1.47, 0.6), (2.31, 0.4)), 0.07) + 0.3 * bandpass(noise(int(0.35 * SR)), 2000, 6000) * env_ad(int(0.35 * SR), 0.001, 0.02), peak=0.6)
    # Eating: a few crunchy munches.
    x = np.zeros(int(0.9 * SR))
    pos = 0.0
    for _ in range(4):
        n = int(rng.uniform(0.05, 0.08) * SR)
        place_fast(x, bandpass(noise(n), 900, 3500) * env_ad(n, 0.003, 0.03), int(pos * SR))
        pos += rng.uniform(0.15, 0.22)
    save("munch", x, peak=0.55)
    # Pan onto the stove: metallic clank.
    x = bell(420, 0.6, ((1, 1), (2.3, 0.7), (3.7, 0.5), (5.1, 0.3)), 0.12)
    n = len(x)
    x += 0.6 * bandpass(noise(n), 1500, 5000) * env_ad(n, 0.001, 0.03)
    save("pan_clank", x, peak=0.6)
    # New ticket: paper rip / rustle.
    n = int(0.25 * SR)
    save("paper", highpass(noise(n), 2500) * env_ad(n, 0.02, 0.07) * (1 + 0.5 * np.sin(np.arange(n) / SR * 2 * np.pi * 40)), peak=0.45)
    # Picking up a plate: a soft whoosh-pop.
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    save("pickup", np.sin(2 * np.pi * (300 + 900 * t) * t) * env_ad(n, 0.005, 0.06) + 0.2 * bandpass(noise(n), 800, 3000) * env_ad(n, 0.01, 0.05), peak=0.5)
    # Chop: knife on a board.
    for i in range(3):
        n = int(0.14 * SR)
        x = 0.8 * np.sin(2 * np.pi * rng.uniform(110, 150) * np.arange(n) / SR) * env_ad(n, 0.001, 0.035)
        x += bandpass(noise(n), 2500, 8000) * env_ad(n, 0.0005, 0.008)
        save("chop_%d" % i, x, peak=0.7)
    # Stir: a couple of bubbles.
    for i in range(3):
        x = np.zeros(int(0.3 * SR))
        for k in range(3):
            n = int(0.06 * SR)
            t = np.arange(n) / SR
            f = rng.uniform(300, 700) * (1 + 3 * t / 0.06)
            place_fast(x, np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(n, 0.002, 0.02), int(k * 0.07 * SR))
        save("stir_%d" % i, x, peak=0.5)
    # Rank up: a happy arpeggio. Expansion: a bigger one.
    def fanfare(notes, step, dur):
        x = np.zeros(int(dur * SR))
        for k, n in enumerate(notes):
            place_fast(x, vibes(midi(n), 1.4, 1.0) + 0.5 * epiano(midi(n - 12), 1.4, 0.6), int(k * step * SR))
        return x
    save("rank_up", fanfare([72, 76, 79, 84, 88], 0.09, 2.0), peak=0.75)
    save("expand", fanfare([60, 64, 67, 72, 76, 79, 84, 88, 91], 0.08, 2.6), peak=0.75)


# ---- menu sounds -----------------------------------------------------------

def pluck(freq, dur=0.35, bright=0.4):
    t = t_axis(dur)
    x = np.sin(2 * np.pi * freq * t) + bright * np.sin(2 * np.pi * 2 * freq * t) * np.exp(-t * 20)
    return x * env_ad(len(t), 0.002, 0.09)


def ui():
    # Open a menu: two soft rising plucks. Close: the same, falling.
    x = np.zeros(int(0.35 * SR))
    place_fast(x, pluck(midi(72)), 0)
    place_fast(x, pluck(midi(79)), int(0.06 * SR))
    save("ui_open", lowpass(x, 5000), peak=0.6)
    x = np.zeros(int(0.35 * SR))
    place_fast(x, pluck(midi(79)), 0)
    place_fast(x, pluck(midi(72)), int(0.06 * SR))
    save("ui_close", lowpass(x, 5000), peak=0.55)
    # Start the game: a warm, bright little chord that rises.
    x = np.zeros(int(1.6 * SR))
    for k, n in enumerate([67, 72, 76, 79, 84]):
        place_fast(x, vibes(midi(n), 1.3, 1.0) + 0.4 * epiano(midi(n - 12), 1.3, 0.7), int(k * 0.055 * SR))
    save("ui_start", lowpass(x, 6000), peak=0.7)
    # Buy something: a soft coin "bling".
    x = np.zeros(int(0.7 * SR))
    place_fast(x, bell(midi(88), 0.6, ((1, 1), (2.0, 0.3)), 0.18), 0)
    place_fast(x, bell(midi(93), 0.6, ((1, 1), (2.0, 0.3)), 0.25), int(0.07 * SR))
    save("ui_buy", x, peak=0.6)
    # A button click: a tiny soft tap.
    save("ui_click", pluck(midi(84), 0.12, 0.2), peak=0.45)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    effects()
    voices()
    ambience()
    music()
    ui()
