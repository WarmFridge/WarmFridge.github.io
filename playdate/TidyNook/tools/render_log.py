#!/usr/bin/env python3
"""Replay draw commands recorded by mock_playdate.lua into a 1-bit PNG.

An approximation of the Playdate renderer (system font is swapped for
DejaVu Sans), good enough to check layout and art without the simulator.
Usage: render_log.py frame.log out.png [scale]
"""
import sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 12)
FONTB = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 12)


def parse(line):
    out, i, n = [], 0, len(line)
    while i < n:
        if line[i] == '"':
            j, buf = i + 1, []
            while j < n and line[j] != '"':
                if line[j] == '\\' and j + 1 < n:
                    nxt = line[j + 1]
                    buf.append({'n': '\n', 't': '\t'}.get(nxt, nxt))
                    j += 2
                else:
                    buf.append(line[j]); j += 1
            out.append(''.join(buf)); i = j + 2
        else:
            j = line.find('\t', i)
            if j < 0: j = n
            tok = line[i:j]
            try: out.append(float(tok))
            except ValueError: out.append(tok)
            i = j + 1
    return out


class Canvas:
    def __init__(self, w, h, bg):
        self.w, self.h = int(w), int(h)
        self.px = np.full((self.h, self.w), 255 if bg == 1 else 0, np.uint8)
        self.alpha = np.full((self.h, self.w), 0 if bg == 2 else 255, np.uint8)


class R:
    def __init__(self):
        self.screen = Canvas(400, 240, 1)
        self.images = {}
        self.stack = [self.screen]
        self.color = 0
        self.pattern = None
        self.lw = 1
        self.off = (0, 0)
        self.mode = 0

    @property
    def cv(self): return self.stack[-1]

    def mask(self, fn):
        img = Image.new('1', (self.cv.w, self.cv.h), 0)
        fn(ImageDraw.Draw(img))
        return np.array(img, dtype=bool)

    def paint(self, m):
        cv = self.cv
        if self.pattern is not None:
            p = self.pattern
            ys, xs = np.nonzero(m)
            if len(ys) == 0: return
            rows = np.array(p[:8], dtype=np.uint8)
            bits = (rows[ys % 8] >> (7 - (xs % 8))) & 1
            if len(p) == 16:
                mrows = np.array(p[8:], dtype=np.uint8)
                keep = ((mrows[ys % 8] >> (7 - (xs % 8))) & 1).astype(bool)
                ys, xs, bits = ys[keep], xs[keep], bits[keep]
            cv.px[ys, xs] = bits * 255
            cv.alpha[ys, xs] = 255
        else:
            if self.color == 2: return
            if self.color == 3:
                cv.px[m] = 255 - cv.px[m]; return
            cv.px[m] = 255 if self.color == 1 else 0
            cv.alpha[m] = 255

    def O(self, x, y): return x + self.off[0], y + self.off[1]

    def run(self, c):
        op, a = c[0], c[1:]
        if op == 'setColor': self.color, self.pattern = int(a[0]), None
        elif op == 'setPattern': self.pattern = [int(v) for v in a[0].split(',')]
        elif op == 'setLineWidth': self.lw = max(1, int(a[0]))
        elif op == 'setDrawOffset': self.off = (a[0], a[1])
        elif op == 'setImageDrawMode': self.mode = int(a[0])
        elif op == 'clear':
            self.cv.px[:] = 255 if int(a[0]) == 1 else 0; self.cv.alpha[:] = 255
        elif op == 'imageNew': self.images[int(a[0])] = Canvas(a[1], a[2], int(a[3]))
        elif op == 'pushContext':
            self.saved = getattr(self, 'saved', [])
            self.saved.append(self.off)
            self.off = (0, 0)
            self.stack.append(self.images.get(int(a[0]), self.screen))
        elif op == 'popContext':
            self.stack.pop(); self.off = self.saved.pop()
        elif op == 'imageDraw':
            src = self.images.get(int(a[0]))
            if not src: return
            x, y = self.O(a[1], a[2]); s = a[3]
            px, al = src.px, src.alpha
            if s != 1:
                px = np.kron(px, np.ones((int(s), int(s)), np.uint8)); al = np.kron(al, np.ones((int(s), int(s)), np.uint8))
            x, y = int(math.floor(x)), int(math.floor(y))
            h, w = px.shape
            cv = self.cv
            x0, y0 = max(0, x), max(0, y)
            x1, y1 = min(cv.w, x + w), min(cv.h, y + h)
            if x1 <= x0 or y1 <= y0: return
            sp = px[y0 - y:y1 - y, x0 - x:x1 - x]; sa = al[y0 - y:y1 - y, x0 - x:x1 - x] > 0
            region = cv.px[y0:y1, x0:x1]
            region[sa] = sp[sa]
            cv.alpha[y0:y1, x0:x1][sa] = 255
        elif op == 'drawText':
            s, x, y = a[0], *self.O(a[1], a[2])
            bold = s.startswith('*') and s.endswith('*')
            s = s.replace('*', '').replace('_', '')
            img = Image.new('1', (self.cv.w, self.cv.h), 0)
            ImageDraw.Draw(img).text((x, y + 1), s, font=FONTB if bold else FONT, fill=1)
            m = np.array(img, dtype=bool)
            cv = self.cv
            cv.px[m] = 255 if self.mode == 1 else 0
            cv.alpha[m] = 255
        else:
            self.shape(op, a)

    def shape(self, op, a):
        lw = self.lw
        if op == 'fillRect':
            x, y = self.O(a[0], a[1]); w, h = a[2], a[3]
            if w <= 0 or h <= 0: return
            m = self.mask(lambda d: d.rectangle([math.floor(x), math.floor(y), math.floor(x + w) - 1, math.floor(y + h) - 1], fill=1))
        elif op == 'drawRect':
            x, y = self.O(a[0], a[1]); w, h = a[2], a[3]
            m = self.mask(lambda d: d.rectangle([math.floor(x), math.floor(y), math.floor(x + w) - 1, math.floor(y + h) - 1], outline=1, width=lw))
        elif op in ('fillRoundRect', 'drawRoundRect'):
            x, y = self.O(a[0], a[1]); w, h, r = a[2], a[3], a[4]
            if w <= 1 or h <= 1: return
            r = max(0, min(r, w / 2 - 0.5, h / 2 - 0.5))
            box = [math.floor(x), math.floor(y), math.floor(x + w) - 1, math.floor(y + h) - 1]
            if op == 'fillRoundRect': m = self.mask(lambda d: d.rounded_rectangle(box, r, fill=1))
            else: m = self.mask(lambda d: d.rounded_rectangle(box, r, outline=1, width=lw))
        elif op in ('fillEllipseInRect', 'drawEllipseInRect'):
            x, y = self.O(a[0], a[1]); w, h = a[2], a[3]
            if w < 1 or h < 1: return
            box = [x, y, x + w - 1, y + h - 1]
            if op.startswith('fill'): m = self.mask(lambda d: d.ellipse(box, fill=1))
            else: m = self.mask(lambda d: d.ellipse(box, outline=1, width=lw))
        elif op in ('fillCircleAtPoint', 'drawCircleAtPoint'):
            x, y = self.O(a[0], a[1]); r = a[2]
            box = [x - r, y - r, x + r, y + r]
            if op.startswith('fill'): m = self.mask(lambda d: d.ellipse(box, fill=1))
            else: m = self.mask(lambda d: d.ellipse(box, outline=1, width=lw))
        elif op == 'drawLine':
            x1, y1 = self.O(a[0], a[1]); x2, y2 = self.O(a[2], a[3])
            m = self.mask(lambda d: d.line([x1, y1, x2, y2], fill=1, width=lw))
        elif op in ('fillTriangle', 'drawTriangle'):
            pts = [self.O(a[0], a[1]), self.O(a[2], a[3]), self.O(a[4], a[5])]
            if op.startswith('fill'): m = self.mask(lambda d: d.polygon(pts, fill=1))
            else: m = self.mask(lambda d: d.polygon(pts, outline=1))
        elif op == 'drawArc':
            x, y = self.O(a[0], a[1]); r, s, e = a[2], a[3], a[4]
            m = self.mask(lambda d: d.arc([x - r, y - r, x + r, y + r], s - 90, e - 90, fill=1, width=lw))
        elif op == 'drawPixel':
            x, y = self.O(a[0], a[1])
            m = self.mask(lambda d: d.point([x, y], fill=1))
        else:
            return
        self.paint(m)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    scale = int(sys.argv[3]) if len(sys.argv) > 3 else 2
    r = R()
    with open(src, encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.rstrip('\n')
            if line: r.run(parse(line))
    img = Image.fromarray(r.screen.px, 'L').convert('1')
    img = img.resize((400 * scale, 240 * scale), Image.NEAREST)
    img.save(dst)


if __name__ == '__main__':
    main()
