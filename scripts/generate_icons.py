#!/usr/bin/env python3
"""Generate crisp, anti-aliased PNG icons (16, 48, 128px) with zero external deps."""

import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "public", "icons")


def clamp(v: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return lo if v < lo else (hi if v > hi else v)


def smoothstep(edge0: float, edge1: float, x: float) -> float:
    t = clamp((x - edge0) / (edge1 - edge0))
    return t * t * (3.0 - 2.0 * t)


def sd_rounded_box(px: float, py: float, bx: float, by: float, r: float) -> float:
    qx = abs(px) - bx + r
    qy = abs(py) - by + r
    return (
        math.hypot(max(qx, 0.0), max(qy, 0.0))
        + min(max(qx, qy), 0.0)
        - r
    )


def sd_capsule(px: float, py: float, ax: float, ay: float, bx: float, by: float, r: float) -> float:
    pax, pay = px - ax, py - ay
    bax, bay = bx - ax, by - ay
    denom = bax * bax + bay * bay
    h = clamp((pax * bax + pay * bay) / denom) if denom > 0 else 0.0
    return math.hypot(pax - bax * h, pay - bay * h) - r


def blend(dst: tuple[float, float, float, float], src: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    sr, sg, sb, sa = src
    dr, dg, db, da = dst
    out_a = sa + da * (1.0 - sa)
    if out_a <= 1e-6:
        return (0.0, 0.0, 0.0, 0.0)
    out_r = (sr * sa + dr * da * (1.0 - sa)) / out_a
    out_g = (sg * sa + dg * da * (1.0 - sa)) / out_a
    out_b = (sb * sa + db * da * (1.0 - sa)) / out_a
    return (out_r, out_g, out_b, out_a)


def render_icon(size: int) -> bytes:
    ss = 4 if size <= 48 else 2  # supersampling for crisp anti-aliasing
    rows = bytearray()

    for y in range(size):
        rows.append(0)  # PNG filter type 0 (None)
        for x in range(size):
            acc_r = acc_g = acc_b = acc_a = 0.0
            for sy in range(ss):
                for sx in range(ss):
                    u = ((x + (sx + 0.5) / ss) / size) * 2.0 - 1.0
                    v = ((y + (sy + 0.5) / ss) / size) * 2.0 - 1.0

                    # Squircle dark-crimson to rose-magenta gradient badge
                    d_bg = sd_rounded_box(u, v, 0.88, 0.88, 0.42)
                    bg_alpha = 1.0 - smoothstep(-0.02, 0.02, d_bg)
                    if bg_alpha <= 0.0:
                        continue

                    t = clamp((u * 0.45 + v * 0.75 + 1.0) * 0.5)
                    r = 0.98 * (1.0 - t) + 0.42 * t  # vibrant coral-red -> deep magenta
                    g = 0.14 * (1.0 - t) + 0.07 * t
                    b = 0.28 * (1.0 - t) + 0.34 * t

                    # Subtle top sheen
                    sheen = (1.0 - smoothstep(-0.85, 0.15, v)) * 0.16
                    col = (clamp(r + sheen), clamp(g + sheen * 0.7), clamp(b + sheen * 0.8), bg_alpha)

                    # Floating karaoke bars + glowing active lyric line motif
                    # 3 horizontal stylized lyric lines with active middle pill glow
                    d_line1 = sd_capsule(u, v, -0.44, -0.34, 0.20, -0.34, 0.075)
                    a1 = (1.0 - smoothstep(-0.02, 0.02, d_line1)) * 0.48
                    if a1 > 0:
                        col = blend(col, (1.0, 1.0, 1.0, a1))

                    # Active karaoke line (bright white + warm highlight tip)
                    d_line2 = sd_capsule(u, v, -0.46, 0.0, 0.46, 0.0, 0.105)
                    a2 = 1.0 - smoothstep(-0.02, 0.02, d_line2)
                    if a2 > 0:
                        sweep = smoothstep(0.08, 0.22, u)
                        lr = 1.0
                        lg = 1.0 * (1.0 - sweep) + 0.86 * sweep
                        lb = 1.0 * (1.0 - sweep) + 0.90 * sweep
                        col = blend(col, (lr, lg, lb, a2 * (1.0 - 0.18 * sweep)))

                    # Third upcoming lyric line
                    d_line3 = sd_capsule(u, v, -0.44, 0.34, 0.10, 0.34, 0.075)
                    a3 = (1.0 - smoothstep(-0.02, 0.02, d_line3)) * 0.48
                    if a3 > 0:
                        col = blend(col, (1.0, 1.0, 1.0, a3))

                    # Floating PiP corner sparkle dot
                    d_dot = math.hypot(u - 0.40, v - 0.34) - 0.09
                    ad = (1.0 - smoothstep(-0.02, 0.02, d_dot)) * 0.92
                    if ad > 0:
                        col = blend(col, (1.0, 0.92, 0.65, ad))

                    acc_r += col[0] * col[3]
                    acc_g += col[1] * col[3]
                    acc_b += col[2] * col[3]
                    acc_a += col[3]

            samples = float(ss * ss)
            a = acc_a / samples
            if a > 1e-6:
                r = clamp((acc_r / samples) / a)
                g = clamp((acc_g / samples) / a)
                b = clamp((acc_b / samples) / a)
            else:
                r = g = b = 0.0

            rows.append(int(round(r * 255)))
            rows.append(int(round(g * 255)))
            rows.append(int(round(b * 255)))
            rows.append(int(round(clamp(a) * 255)))

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(rows), 9)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for size in (16, 48, 128):
        path = os.path.join(OUT_DIR, f"icon-{size}.png")
        with open(path, "wb") as f:
            f.write(render_icon(size))
        print(f"Generated {path} ({size}x{size})")


if __name__ == "__main__":
    main()
