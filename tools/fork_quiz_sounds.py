#!/usr/bin/env python3
"""Generates the sound effects of the « Qui chante ? » quiz (BirdyGo fork, J6e).

Original, synthesized from scratch with the standard library only (no sample,
no third-party sound): triangle-wave notes with a short attack and an
exponential decay, as in the Quiz v2 mockup (quiz-fx.js). Free to use, same
license as the fork's code (MIT).

    python tools/fork_quiz_sounds.py

writes assets/fork/sounds/quiz_success.wav, quiz_soft.wav and
quiz_fanfare.wav (16-bit PCM mono, 44.1 kHz, peak at -6 dBFS, no clipping).
"""

import math
import os
import struct
import wave

RATE = 44100
PEAK = 0.5  # -6 dBFS: gentle next to the bird songs.
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'fork', 'sounds')


def triangle(phase):
    """Triangle wave, -1..1, for a phase in cycles."""
    p = phase % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


def tone(buf, f0, f1, start, dur, vol):
    """Adds a note gliding from f0 to f1 (exponential), 15 ms attack, then
    an exponential decay to -60 dB at the end."""
    first = int(start * RATE)
    count = int(dur * RATE)
    need = first + count + 1
    if len(buf) < need:
        buf.extend([0.0] * (need - len(buf)))
    phase = 0.0
    attack = 0.015
    for i in range(count):
        t = i / RATE
        f = f0 * (f1 / f0) ** (t / dur)
        phase += f / RATE
        if t < attack:
            env = t / attack
        else:
            env = math.exp(math.log(0.001) * (t - attack) / (dur - attack))
        buf[first + i] += vol * env * triangle(phase)


def write(name, buf, tail=0.05):
    buf = buf + [0.0] * int(tail * RATE)
    peak = max(abs(s) for s in buf) or 1.0
    scale = PEAK / peak
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(
            b''.join(
                struct.pack('<h', int(round(s * scale * 32767))) for s in buf
            )
        )
    print(f'{path}: {len(buf) / RATE:.2f} s')


def success():
    """Right answer: C5 E5 G5 C6, rising, about 0.6 s."""
    buf = []
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        tone(buf, f, f * 1.01, i * 0.08, 0.28 if i < 3 else 0.36, 0.1)
    return buf


def soft():
    """Wrong answer: one soft falling note, 0.3 s."""
    buf = []
    tone(buf, 392.0, 329.63, 0, 0.3, 0.08)
    return buf


def fanfare():
    """End of a good round: C E G E G C, then a held C major chord, about
    1.5 s."""
    buf = []
    notes = [523.25, 659.25, 783.99, 659.25, 783.99]
    for i, f in enumerate(notes):
        tone(buf, f, f, i * 0.11, 0.3, 0.09)
    end = len(notes) * 0.11
    for f in (523.25, 659.25, 783.99, 1046.5):
        tone(buf, f, f, end, 0.9, 0.07)
    return buf


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    write('quiz_success.wav', success())
    write('quiz_soft.wav', soft())
    write('quiz_fanfare.wav', fanfare())
