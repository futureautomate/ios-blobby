# Synthesizes Blobby's short cartoon sound effects as 16-bit mono WAVs (no downloads, no licences).
import math, random, struct, wave, sys, os
SR = 44100
out = sys.argv[1] if len(sys.argv) > 1 else "Blobby/Sounds"
os.makedirs(out, exist_ok=True)

def write(name, samples):
    peak = max(1e-9, max(abs(x) for x in samples))
    with wave.open(os.path.join(out, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(x / peak * 0.8 * 32767)) for x in samples))

def env(i, n, attack=0.005, decay=6.0):
    t = i / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-decay * t / (n / SR))

# pop: quick upward bloop (logging a step)
n = int(SR * 0.11); ph = 0.0; s = []
for i in range(n):
    f = 420 + 700 * (i / n) ** 0.6
    ph += 2 * math.pi * f / SR
    s.append(math.sin(ph) * env(i, n, 0.003, 5.0))
write("pop.wav", s)

# chime: sparkly arpeggio C6 E6 G6 C7 (goal reached)
notes = [1046.5, 1318.5, 1568.0, 2093.0]; n = int(SR * 0.9); s = [0.0] * n
for k, f in enumerate(notes):
    start = int(k * 0.08 * SR)
    for i in range(start, n):
        j = i - start
        s[i] += (math.sin(2 * math.pi * f * j / SR) + 0.3 * math.sin(2 * math.pi * 2 * f * j / SR)) * math.exp(-4.0 * j / SR)
write("chime.wav", s)

# fanfare: bouncy level-up C5 E5 G5 C6-hold, soft square-ish wave
seq = [(523.3, 0.11), (659.3, 0.11), (784.0, 0.11), (1046.5, 0.45)]; s = []
for f, d in seq:
    m = int(SR * d)
    for i in range(m):
        x = sum(math.sin(2 * math.pi * f * h * i / SR) / h for h in (1, 3, 5))
        s.append(x * min(1, i / (SR * 0.004)) * math.exp(-2.5 * i / m))
write("fanfare.wav", s)

# poof: filtered noise puff (delete)
random.seed(7); n = int(SR * 0.28); s = []; y = 0.0
for i in range(n):
    cutoff = 0.25 * (1 - i / n) + 0.02
    y += cutoff * (random.uniform(-1, 1) - y)
    s.append(y * env(i, n, 0.01, 4.0))
write("poof.wav", s)
print("ok")
