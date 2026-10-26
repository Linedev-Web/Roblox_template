# Genere les icones du jeu (assets/icones/*.png, 256 x 256) dans un style cartoon brillant :
# contour sombre epais, degrade vertical, reflet et ombre portee.
# Usage : python tools/icones/generer_icones.py
# Les icones sont ensuite envoyees sur Roblox ; leurs identifiants vont dans src/shared/Icons.luau.
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

N = 256  # taille finale
S = 4  # sur-echantillonnage pour l'anticrenelage
W = N * S
OUTLINE = (30, 20, 50)
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "icones"))
FONT_BOLD = "C:/Windows/Fonts/ariblk.ttf"


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def lighter(c, t=0.35):
    return lerp(c, (255, 255, 255), t)


def darker(c, t=0.35):
    return lerp(c, (0, 0, 0), t)


def sc(v):
    return v * S


def pts(points):
    return [(sc(x), sc(y)) for x, y in points]


# --- Masques -------------------------------------------------------------------------

def mask():
    return Image.new("L", (W, W), 0)


def ellipse(box):
    m = mask()
    ImageDraw.Draw(m).ellipse([sc(v) for v in box], fill=255)
    return m


def poly(points):
    m = mask()
    ImageDraw.Draw(m).polygon(pts(points), fill=255)
    return m


def rect(box, radius=0):
    m = mask()
    ImageDraw.Draw(m).rounded_rectangle([sc(v) for v in box], radius=sc(radius), fill=255)
    return m


def thick_line(points, width):
    m = mask()
    d = ImageDraw.Draw(m)
    d.line(pts(points), fill=255, width=sc(width), joint="curve")
    r = sc(width) / 2
    for x, y in pts([points[0], points[-1]]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return m


def arc(box, start, end, width):
    m = mask()
    ImageDraw.Draw(m).arc([sc(v) for v in box], start, end, fill=255, width=sc(width))
    return m


def union(*masks):
    out = masks[0]
    for m in masks[1:]:
        out = ImageChops.lighter(out, m)
    return out


def minus(a, b):
    return ImageChops.subtract(a, b)


def inter(a, b):
    return ImageChops.multiply(a, b)


def star_points(cx, cy, outer, inner, count=5, rotation=-90):
    result = []
    for i in range(count * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rotation + i * 180 / count)
        result.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return result


def dilate(m, pixels):
    # Elargit un masque de "pixels" (en pixels finaux) par passes successives
    out = m
    remaining = sc(pixels)
    while remaining > 0:
        step = min(remaining, 6)
        out = out.filter(ImageFilter.MaxFilter(step * 2 + 1))
        remaining -= step
    return out


# --- Rendu ---------------------------------------------------------------------------

def gradient(m, top, bottom):
    box = m.getbbox() or (0, 0, W, W)
    y0, y1 = box[1], max(box[3], box[1] + 1)
    column = Image.new("RGBA", (1, W))
    for y in range(W):
        t = min(1, max(0, (y - y0) / (y1 - y0)))
        column.putpixel((0, y), lerp(top, bottom, t) + (255,))
    layer = column.resize((W, W))
    layer.putalpha(m)
    return layer


def solid(m, color, alpha=255):
    layer = Image.new("RGBA", (W, W), color + (0,))
    layer.putalpha(m.point(lambda v: v * alpha // 255))
    return layer


class Icon:
    def __init__(self):
        self.parts = []

    def part(self, m, top, bottom=None, gloss=True, line=4):
        self.parts.append(("part", m, top, bottom or darker(top, 0.3), gloss, line))
        return self

    def decal(self, m, color, alpha=255, clip=None):
        self.parts.append(("decal", m if clip is None else inter(m, clip), color, alpha))
        return self

    def render(self, outline=9, rotate=0):
        canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        shapes = [p[1] for p in self.parts if p[0] == "part"]
        whole = union(*shapes)
        border = dilate(whole, outline)
        # Ombre portee
        shadow = solid(border, (10, 5, 25), 110).transform((W, W), Image.AFFINE, (1, 0, 0, 0, 1, -sc(7)))
        canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(sc(4))))
        canvas.alpha_composite(solid(border, OUTLINE))
        for entry in self.parts:
            if entry[0] == "part":
                _, m, top, bottom, gloss, line = entry
                if line > 0:
                    canvas.alpha_composite(solid(dilate(m, line), OUTLINE))
                canvas.alpha_composite(gradient(m, top, bottom))
                # Ombre interne en bas, reflet en haut
                box = m.getbbox()
                if box:
                    x0, y0, x1, y1 = box
                    h = y1 - y0
                    shade = mask()
                    ImageDraw.Draw(shade).rectangle([x0, y0 + h * 0.72, x1, y1], fill=255)
                    canvas.alpha_composite(solid(inter(m, shade.filter(ImageFilter.GaussianBlur(sc(6)))), (0, 0, 0), 40))
                    if gloss:
                        shine = mask()
                        w = x1 - x0
                        ImageDraw.Draw(shine).ellipse([x0 + w * 0.12, y0 + h * 0.04, x1 - w * 0.12, y0 + h * 0.46], fill=255)
                        shine = inter(shine.filter(ImageFilter.GaussianBlur(sc(3))), m.filter(ImageFilter.MinFilter(sc(2) * 2 + 1)))
                        canvas.alpha_composite(solid(shine, (255, 255, 255), 70))
            else:
                _, m, color, alpha = entry
                canvas.alpha_composite(solid(m, color, alpha))
        if rotate:
            canvas = canvas.rotate(rotate, resample=Image.BICUBIC, center=(W / 2, W / 2))
        return canvas.resize((N, N), Image.LANCZOS)


def text_mask(text, size, center, font=FONT_BOLD):
    m = mask()
    f = ImageFont.truetype(font, sc(size))
    d = ImageDraw.Draw(m)
    x, y = center
    d.text((sc(x), sc(y)), text, font=f, fill=255, anchor="mm")
    return m


# --- Icones --------------------------------------------------------------------------

GOLD = ((255, 232, 110), (232, 150, 20))
SILVER = ((245, 248, 255), (150, 160, 195))


def coin():
    icon = Icon()
    icon.part(ellipse((18, 18, 238, 238)), *GOLD)
    icon.part(ellipse((54, 54, 202, 202)), (236, 168, 30), (255, 220, 90), gloss=False, line=3)
    icon.decal(poly(star_points(128, 132, 56, 24)), (255, 246, 190))
    return icon.render()


def gem(color):
    icon = Icon()
    outline = [(70, 34), (186, 34), (234, 98), (128, 234), (22, 98)]
    icon.part(poly(outline), lighter(color, 0.3), darker(color, 0.25), gloss=False)
    icon.decal(poly([(70, 34), (186, 34), (160, 98), (96, 98)]), lighter(color, 0.55))
    icon.decal(poly([(22, 98), (96, 98), (128, 234)]), darker(color, 0.15))
    icon.decal(poly([(234, 98), (160, 98), (128, 234)]), darker(color, 0.35))
    icon.decal(poly([(96, 98), (160, 98), (128, 234)]), lighter(color, 0.15))
    icon.decal(poly([(70, 34), (96, 98), (22, 98)]), lighter(color, 0.35))
    icon.decal(poly([(186, 34), (234, 98), (160, 98)]), color)
    icon.decal(poly(star_points(84, 64, 18, 5, 4, -90)), (255, 255, 255), 230)
    return icon.render()


def key():
    icon = Icon()
    ring = minus(ellipse((14, 70, 118, 174)), ellipse((44, 100, 88, 144)))
    icon.part(union(ring, rect((108, 108, 240, 136), 6), rect((188, 128, 210, 172), 4), rect((220, 128, 240, 160), 4)), *GOLD)
    return icon.render(rotate=30)


def egg_points(cx, cy, rx, ry):
    result = []
    for i in range(72):
        t = i / 72 * 2 * math.pi
        # Le haut de l'oeuf (sinus negatif) est plus etroit que le bas
        width = rx * (1 + 0.16 * math.sin(t))
        result.append((cx + math.cos(t) * width, cy + math.sin(t) * ry))
    return result


def egg(spots=(165, 95, 255)):
    icon = Icon()
    shell = poly(egg_points(128, 136, 92, 112))
    icon.part(shell, (255, 255, 255), (205, 195, 235))
    for box in [(70, 70, 112, 104), (150, 110, 196, 150), (86, 160, 128, 196), (160, 186, 190, 212), (132, 46, 156, 66)]:
        icon.decal(ellipse(box), spots, 235, clip=shell)
    return icon.render()


def paw():
    icon = Icon()
    color = ((255, 175, 205), (225, 95, 150))
    icon.part(union(ellipse((60, 120, 196, 226)), ellipse((84, 108, 172, 170))), *color)
    for box in [(22, 92, 76, 152), (66, 34, 120, 100), (136, 34, 190, 100), (180, 92, 234, 152)]:
        icon.part(ellipse(box), *color)
    return icon.render()


def portal():
    icon = Icon()
    icon.part(minus(ellipse((16, 16, 240, 240)), ellipse((58, 58, 198, 198))), (205, 140, 255), (110, 50, 210))
    inner = ellipse((58, 58, 198, 198))
    icon.part(inner, (120, 245, 255), (70, 110, 250), gloss=False, line=2)
    for i, box in enumerate([(70, 70, 186, 186), (88, 88, 168, 168), (106, 106, 150, 150)]):
        icon.decal(arc(box, 200 + i * 60, 360 + i * 60, 7), (255, 255, 255), 200, clip=inner)
    return icon.render()


def tower():
    icon = Icon()
    stone = ((215, 205, 240), (130, 115, 175))
    icon.part(rect((70, 96, 186, 240), 6), *stone)
    battlement = union(rect((54, 70, 202, 108), 6), rect((54, 44, 82, 80), 4), rect((114, 44, 142, 80), 4), rect((174, 44, 202, 80), 4))
    icon.part(battlement, *stone)
    icon.decal(union(rect((104, 176, 152, 240), 0), ellipse((104, 152, 152, 200))), (60, 40, 90))
    icon.decal(union(rect((118, 120, 138, 146)), ellipse((118, 110, 138, 130))), (255, 210, 90))
    icon.part(rect((124, 6, 132, 50)), (120, 90, 60), (90, 60, 40), gloss=False, line=3)
    icon.part(poly([(132, 8), (186, 22), (132, 38)]), (255, 110, 120), (210, 40, 70), gloss=False, line=3)
    return icon.render()


def gift():
    icon = Icon()
    red = ((255, 110, 130), (200, 35, 70))
    icon.part(rect((38, 116, 218, 238), 10), *red)
    icon.part(rect((24, 82, 232, 126), 10), lighter(red[0], 0.1), red[0])
    icon.decal(rect((112, 82, 144, 238)), (255, 215, 80))
    icon.decal(rect((112, 82, 144, 238)), (255, 240, 160), 90, clip=rect((112, 82, 126, 238)))
    bow = ((255, 230, 110), (235, 160, 30))
    icon.part(poly([(128, 84), (66, 30), (54, 70), (90, 88)]), *bow, line=3)
    icon.part(poly([(128, 84), (190, 30), (202, 70), (166, 88)]), *bow, line=3)
    icon.part(ellipse((112, 66, 144, 98)), *bow, gloss=False, line=3)
    return icon.render()


def shop():
    icon = Icon()
    handle = inter(minus(ellipse((80, 22, 176, 118)), ellipse((98, 40, 158, 100))), rect((0, 0, 256, 92)))
    icon.part(handle, (255, 200, 120), (200, 120, 40), gloss=False, line=3)
    bag = poly([(40, 86), (216, 86), (234, 236), (22, 236)])
    icon.part(bag, (255, 185, 70), (232, 105, 25))
    icon.decal(poly(star_points(128, 162, 46, 20)), (255, 245, 200))
    return icon.render()


def power():
    icon = Icon()
    bolt = poly([(156, 8), (46, 144), (118, 144), (92, 248), (212, 100), (138, 100), (176, 8)])
    icon.part(bolt, (255, 248, 140), (255, 160, 10))
    return icon.render()


def shield():
    icon = Icon()
    outline = [(128, 14), (222, 46), (214, 138), (128, 242), (42, 138), (34, 46)]
    icon.part(poly(outline), (130, 210, 255), (35, 100, 225))
    inner = [(128, 44), (194, 66), (188, 134), (128, 208), (68, 134), (62, 66)]
    icon.part(poly(inner), (90, 160, 250), (160, 220, 255), gloss=False, line=3)
    icon.decal(poly(star_points(128, 124, 44, 19)), (255, 255, 255), 240)
    return icon.render()


def lock():
    icon = Icon()
    shackle = inter(minus(ellipse((62, 14, 194, 146)), ellipse((90, 42, 166, 118))), rect((0, 0, 256, 112)))
    shackle = union(shackle, rect((62, 78, 90, 112)), rect((166, 78, 194, 112)))
    icon.part(shackle, *SILVER, gloss=False)
    icon.part(rect((36, 102, 220, 240), 22), *GOLD)
    icon.decal(union(ellipse((110, 140, 146, 176)), poly([(118, 168), (138, 168), (144, 210), (112, 210)])), (70, 45, 20))
    return icon.render()


def sword():
    icon = Icon()
    icon.part(poly([(128, 4), (146, 28), (146, 166), (110, 166), (110, 28)]), *SILVER)
    icon.decal(rect((124, 30, 132, 160)), (255, 255, 255), 160)
    icon.part(rect((76, 160, 180, 184), 10), *GOLD, gloss=False, line=3)
    icon.part(rect((116, 184, 140, 228), 4), (160, 100, 60), (100, 60, 30), gloss=False, line=3)
    icon.part(ellipse((108, 218, 148, 254)), *GOLD, line=3)
    return icon.render(rotate=-45)


def chest():
    icon = Icon()
    wood = ((205, 135, 70), (125, 70, 30))
    icon.part(rect((26, 124, 230, 236), 10), *wood)
    lid = union(inter(ellipse((26, 46, 230, 170)), rect((0, 0, 256, 128))), rect((26, 96, 230, 128)))
    icon.part(lid, lighter(wood[0], 0.1), wood[1])
    for x in (58, 178):
        icon.decal(rect((x, 46, x + 22, 236)), (255, 205, 70), clip=union(lid, rect((26, 124, 230, 236))))
    icon.part(rect((108, 104, 148, 158), 8), *GOLD, gloss=False, line=3)
    icon.decal(ellipse((121, 118, 135, 132)), (70, 45, 20))
    return icon.render()


def trophy():
    icon = Icon()
    bowl = inter(ellipse((52, -60, 204, 150)), rect((0, 26, 256, 256)))
    bowl = union(bowl, rect((52, 22, 204, 40), 6))
    handles = union(minus(ellipse((14, 40, 86, 120)), ellipse((32, 58, 68, 102))), minus(ellipse((170, 40, 242, 120)), ellipse((188, 58, 224, 102))))
    icon.part(handles, *GOLD, gloss=False)
    icon.part(bowl, *GOLD)
    icon.part(rect((114, 146, 142, 190)), *GOLD, gloss=False, line=3)
    icon.part(rect((72, 186, 184, 236), 10), (150, 100, 220), (90, 50, 160))
    icon.decal(poly(star_points(128, 82, 34, 15)), (255, 248, 200))
    return icon.render()


def star():
    icon = Icon()
    icon.part(poly(star_points(128, 136, 120, 52)), (255, 240, 120), (245, 160, 20))
    return icon.render()


def crown():
    icon = Icon()
    body = poly([(22, 204), (30, 64), (82, 126), (128, 34), (174, 126), (226, 64), (234, 204)])
    icon.part(body, *GOLD)
    icon.part(rect((20, 184, 236, 230), 8), (255, 215, 80), (215, 130, 15), gloss=False, line=3)
    for box, color in [((114, 194, 142, 222), (255, 80, 110)), ((54, 196, 76, 218), (90, 200, 255)), ((180, 196, 202, 218), (90, 220, 120))]:
        icon.decal(ellipse(box), color)
    for cx, cy in [(30, 60), (128, 30), (226, 60)]:
        icon.part(ellipse((cx - 14, cy - 14, cx + 14, cy + 14)), (255, 240, 170), (255, 190, 40), gloss=False, line=3)
    return icon.render()


def gear():
    icon = Icon()
    teeth = []
    for i in range(16):
        a = math.radians(i * 22.5)
        r = 118 if i % 2 == 0 else 92
        a1, a2 = a - math.radians(9), a + math.radians(9)
        teeth += [(128 + r * math.cos(a1), 128 + r * math.sin(a1)), (128 + r * math.cos(a2), 128 + r * math.sin(a2))]
    icon.part(minus(union(poly(teeth), ellipse((30, 30, 226, 226))), ellipse((90, 90, 166, 166))), (215, 225, 245), (110, 125, 160))
    return icon.render()


def close():
    icon = Icon()
    icon.part(union(thick_line([(56, 56), (200, 200)], 44), thick_line([(200, 56), (56, 200)], 44)), (255, 255, 255), (220, 215, 235), gloss=False)
    return icon.render(outline=7)


def check():
    icon = Icon()
    icon.part(thick_line([(36, 132), (100, 196), (222, 66)], 46), (150, 255, 160), (40, 185, 80), gloss=False)
    return icon.render()


def plus():
    icon = Icon()
    icon.part(union(rect((102, 24, 154, 232), 14), rect((24, 102, 232, 154), 14)), (150, 255, 160), (40, 185, 80), gloss=False)
    return icon.render()


def arrow_up():
    icon = Icon()
    icon.part(poly([(128, 16), (232, 124), (168, 124), (168, 240), (88, 240), (88, 124), (24, 124)]), (150, 255, 160), (40, 185, 80))
    return icon.render()


def heart():
    icon = Icon()
    shape = union(ellipse((16, 34, 136, 154)), ellipse((120, 34, 240, 154)), poly([(22, 118), (234, 118), (128, 238)]))
    icon.part(shape, (255, 120, 140), (215, 30, 70))
    return icon.render()


def scroll():
    icon = Icon()
    paper = ((255, 245, 210), (232, 200, 140))
    icon.part(rect((52, 40, 204, 220), 4), *paper, gloss=False)
    for y in (78, 108, 138, 168):
        icon.decal(rect((76, y, 180 if y != 168 else 140, y + 10), 5), (170, 120, 70))
    icon.part(rect((36, 22, 220, 58), 18), (225, 175, 110), (170, 110, 55), gloss=False, line=3)
    icon.part(rect((36, 204, 220, 240), 18), (225, 175, 110), (170, 110, 55), gloss=False, line=3)
    return icon.render()


def clock():
    icon = Icon()
    icon.part(ellipse((16, 16, 240, 240)), (120, 200, 255), (40, 110, 220))
    face = ellipse((44, 44, 212, 212))
    icon.part(face, (255, 255, 255), (220, 228, 245), gloss=False, line=3)
    icon.decal(union(thick_line([(128, 128), (128, 70)], 16), thick_line([(128, 128), (172, 150)], 14)), (40, 30, 70))
    icon.decal(ellipse((116, 116, 140, 140)), (255, 90, 110))
    return icon.render()


def sparkles():
    icon = Icon()
    color = ((255, 170, 255), (170, 80, 255))
    icon.part(poly(star_points(104, 140, 100, 30, 4)), *color)
    icon.part(poly(star_points(196, 60, 50, 15, 4)), *color, line=3)
    icon.part(poly(star_points(200, 196, 36, 11, 4)), *color, line=3)
    return icon.render()


def sack():
    icon = Icon()
    cloth = ((240, 205, 130), (175, 120, 55))
    icon.part(poly([(92, 40), (164, 40), (152, 96), (104, 96)]), *cloth, gloss=False, line=3)
    body = union(ellipse((30, 84, 226, 244)), poly([(98, 92), (158, 92), (210, 150), (46, 150)]))
    icon.part(body, *cloth)
    icon.part(rect((88, 86, 168, 106), 8), (200, 80, 70), (150, 40, 40), gloss=False, line=3)
    coin_shape = ellipse((92, 132, 164, 204))
    icon.part(coin_shape, *GOLD, gloss=False, line=3)
    icon.decal(poly(star_points(128, 170, 22, 9)), (255, 246, 190))
    return icon.render()


def skull():
    icon = Icon()
    bone = ((250, 248, 240), (190, 185, 200))
    icon.part(union(ellipse((32, 18, 224, 190)), rect((72, 150, 184, 232), 18)), *bone)
    icon.decal(ellipse((62, 92, 118, 148)), (45, 30, 65))
    icon.decal(ellipse((138, 92, 194, 148)), (45, 30, 65))
    icon.decal(poly([(128, 150), (114, 176), (142, 176)]), (45, 30, 65))
    for x in (98, 122, 146):
        icon.decal(rect((x, 196, x + 12, 232)), (45, 30, 65))
    return icon.render()


def potion():
    icon = Icon()
    glass = ((235, 245, 255), (170, 190, 230))
    icon.part(rect((100, 32, 156, 104), 6), *glass, gloss=False, line=3)
    bottle = ellipse((34, 82, 222, 250))
    icon.part(bottle, *glass)
    liquid = inter(bottle, rect((0, 150, 256, 256)))
    icon.decal(liquid, (255, 90, 190))
    icon.decal(inter(bottle, rect((0, 150, 256, 166))), (255, 170, 230))
    icon.decal(ellipse((80, 186, 104, 210)), (255, 255, 255), 160)
    icon.part(rect((92, 12, 164, 42), 8), (200, 140, 90), (140, 90, 50), gloss=False, line=3)
    return icon.render()


def music():
    icon = Icon()
    color = ((120, 230, 255), (60, 120, 240))
    icon.part(union(rect((96, 30, 118, 196)), rect((196, 14, 218, 172)), poly([(96, 30), (218, 6), (218, 52), (96, 76)])), *color, gloss=False)
    icon.part(ellipse((40, 166, 120, 226)), *color)
    icon.part(ellipse((140, 142, 220, 202)), *color)
    return icon.render()


def rocket_boost():
    return potion()


def mythic_egg():
    return egg((255, 80, 140))


ICONS = {
    "Or": coin,
    "Neant": lambda: gem((165, 95, 255)),
    "Seve": lambda: gem((80, 220, 120)),
    "Braise": lambda: gem((255, 90, 60)),
    "Givre": lambda: gem((90, 200, 255)),
    "Solaire": lambda: gem((255, 205, 70)),
    "Cle": key,
    "Oeuf": egg,
    "OeufMythique": mythic_egg,
    "Familiers": paw,
    "Teleport": portal,
    "Tour": tower,
    "Cadeau": gift,
    "Boutique": shop,
    "Puissance": power,
    "Bouclier": shield,
    "Verrou": lock,
    "Epee": sword,
    "Coffre": chest,
    "Trophee": trophy,
    "Etoile": star,
    "Couronne": crown,
    "Auto": gear,
    "Fermer": close,
    "Valider": check,
    "Plus": plus,
    "Ameliorer": arrow_up,
    "Vie": heart,
    "Quete": scroll,
    "Horloge": clock,
    "Fusion": sparkles,
    "Butin": sack,
    "Donjon": skull,
    "Boost": potion,
    "Musique": music,
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, build in ICONS.items():
        image = build()
        image.save(os.path.join(OUT_DIR, name + ".png"))
        print("icone", name)
    # Planche de controle
    columns = 8
    rows = math.ceil(len(ICONS) / columns)
    sheet = Image.new("RGBA", (columns * 136, rows * 150), (40, 32, 64, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 13)
    for index, name in enumerate(ICONS):
        image = Image.open(os.path.join(OUT_DIR, name + ".png")).resize((112, 112), Image.LANCZOS)
        x, y = (index % columns) * 136 + 12, (index // columns) * 150 + 8
        sheet.alpha_composite(image, (x, y))
        draw.text((x + 56, y + 126), name, font=font, fill=(235, 230, 255), anchor="mm")
    sheet.save(os.path.join(OUT_DIR, "..", "planche_icones.png"))


if __name__ == "__main__":
    main()
