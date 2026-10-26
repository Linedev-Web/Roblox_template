# Genere les visuels du jeu : rayons des annonces, logo, icone et miniatures de la page Roblox.
# Usage : python tools/icones/generer_visuels.py [NOM DU JEU]
# Sorties : assets/icones/Rayons.png, assets/icones/Logo.png, assets/marketing/*.png
# Les captures d'ecran eventuelles (assets/marketing/captures/*.png) servent de fond aux miniatures.
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

import generer_icones as icons

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ICON_DIR = os.path.join(ROOT, "assets", "icones")
MARKETING_DIR = os.path.join(ROOT, "assets", "marketing")
CAPTURES_DIR = os.path.join(MARKETING_DIR, "captures")
FONT_LOGO = "C:/Windows/Fonts/seguibl.ttf"
FONT_TEXT = "C:/Windows/Fonts/ariblk.ttf"
OUTLINE = (30, 20, 50)


def rays(size=512, count=18):
    """Rayons blancs qui s'estompent vers l'exterieur (teintes par ImageColor3 en jeu)."""
    big = size * 2
    shape = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(shape)
    c = big / 2
    for i in range(count):
        a = 2 * math.pi * i / count
        w = math.pi / count * 0.55
        draw.polygon([(c, c), (c + big * math.cos(a - w), c + big * math.sin(a - w)), (c + big * math.cos(a + w), c + big * math.sin(a + w))], fill=255)
    # Les rayons s'estompent du centre vers le bord
    fade = Image.radial_gradient("L").resize((big, big)).point(lambda v: max(0, 255 - int(v * 1.25)))
    beams = ImageChops.multiply(shape, fade)
    # Halo au centre
    glow = Image.new("L", (big, big), 0)
    ImageDraw.Draw(glow).ellipse([c - big * 0.16, c - big * 0.16, c + big * 0.16, c + big * 0.16], fill=200)
    glow = glow.filter(ImageFilter.GaussianBlur(big * 0.06))
    result = Image.new("RGBA", (big, big), (255, 255, 255, 0))
    result.putalpha(ImageChops.lighter(beams, glow))
    return result.resize((size, size), Image.LANCZOS)


def outlined_text(text, font_path, size, fill_top, fill_bottom, outline=OUTLINE, stroke=None, depth=None):
    """Texte facon logo : degrade, contour epais, relief et ombre."""
    font = ImageFont.truetype(font_path, size)
    stroke = stroke or max(4, size // 9)
    depth = depth if depth is not None else max(3, size // 14)
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    box = probe.textbbox((0, 0), text, font=font, stroke_width=stroke)
    w, h = box[2] - box[0] + stroke * 2 + depth * 2, box[3] - box[1] + stroke * 2 + depth * 3
    origin = (stroke - box[0] + depth, stroke - box[1])
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Ombre douce
    shadow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(shadow).text((origin[0], origin[1] + depth * 2), text, font=font, fill=150, stroke_width=stroke, stroke_fill=150)
    canvas.paste((10, 5, 25, 255), (0, 0), shadow.filter(ImageFilter.GaussianBlur(depth)))
    # Relief : copies sombres decalees vers le bas
    for d in range(depth, 0, -1):
        layer = Image.new("L", (w, h), 0)
        ImageDraw.Draw(layer).text((origin[0], origin[1] + d), text, font=font, fill=255, stroke_width=stroke, stroke_fill=255)
        canvas.paste(outline, (0, 0), layer)
    # Contour
    layer = Image.new("L", (w, h), 0)
    ImageDraw.Draw(layer).text(origin, text, font=font, fill=255, stroke_width=stroke, stroke_fill=255)
    canvas.paste(outline, (0, 0), layer)
    # Remplissage en degrade
    fill_mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(fill_mask).text(origin, text, font=font, fill=255)
    gradient = Image.new("RGBA", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        gradient.putpixel((0, y), icons.lerp(fill_top, fill_bottom, t) + (255,))
    canvas.paste(gradient.resize((w, h)), (0, 0), fill_mask)
    # Reflet sur la moitie haute des lettres
    shine = Image.new("L", (w, h), 0)
    ImageDraw.Draw(shine).rectangle([0, 0, w, origin[1] + (box[3] - box[1]) * 0.42], fill=90)
    shine = Image.composite(shine, Image.new("L", (w, h), 0), fill_mask)
    canvas.paste((255, 255, 255), (0, 0), shine)
    return canvas


def logo(name):
    title = outlined_text(name.upper(), FONT_LOGO, 220, (255, 245, 170), (255, 150, 20))
    w, h = title.size
    canvas = Image.new("RGBA", (w + 80, h + 60), (0, 0, 0, 0))
    canvas.alpha_composite(title, (40, 10))
    # Petites etoiles de decor
    for (x, y, s) in [(30, 40, 46), (w + 40, 30, 38), (w + 20, h + 10, 30)]:
        star_icon = icons.star().resize((s * 2, s * 2), Image.LANCZOS)
        canvas.alpha_composite(star_icon, (int(x - s), int(y - s + 20)))
    return canvas


def background(size, top, bottom, capture=None):
    w, h = size
    if capture and os.path.exists(capture):
        base = Image.open(capture).convert("RGBA")
        scale = max(w / base.width, h / base.height)
        base = base.resize((int(base.width * scale) + 1, int(base.height * scale) + 1), Image.LANCZOS)
        # Cadrage cale a gauche : le sujet, au centre de la capture, glisse vers la droite du titre
        left, upper = 0, (base.height - h) // 2
        base = base.crop((left, upper, left + w, upper + h))
        base = base.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
        base = ImageEnhance.Color(base).enhance(1.2)
        base = ImageEnhance.Contrast(base).enhance(1.08)
        # Voile colore, opaque a gauche (logo et titre) et transparent a droite (la scene)
        tint = Image.new("RGBA", (w, h), top + (0,))
        shade = Image.linear_gradient("L").rotate(90, expand=True).resize((w, h))
        tint.putalpha(shade.point(lambda v: int(max(0, 165 - v) * 0.95)))
        base.alpha_composite(tint)
        return base
    column = Image.new("RGBA", (1, h))
    for y in range(h):
        column.putpixel((0, y), icons.lerp(top, bottom, y / max(1, h - 1)) + (255,))
    base = column.resize((w, h))
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([w * 0.2, h * 0.05, w * 0.8, h * 0.95], fill=120)
    base.paste((255, 255, 255), (0, 0), glow.filter(ImageFilter.GaussianBlur(min(w, h) * 0.15)).point(lambda v: v // 3))
    return base


def place(canvas, image, center, size, rotation=0):
    image = image.resize((size, size), Image.LANCZOS)
    if rotation:
        image = image.rotate(rotation, resample=Image.BICUBIC, expand=True)
    canvas.alpha_composite(image, (int(center[0] - image.width / 2), int(center[1] - image.height / 2)))


def ray_layer(size, center, radius, color, alpha=0.55):
    r = rays(radius * 2).copy()
    tinted = Image.new("RGBA", r.size, color + (0,))
    tinted.putalpha(r.getchannel("A").point(lambda v: int(v * alpha)))
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    layer.alpha_composite(tinted, (int(center[0] - radius), int(center[1] - radius)))
    return layer


def banner_text(text, size, color_top, color_bottom):
    return outlined_text(text, FONT_TEXT, size, color_top, color_bottom)


def capture(name):
    path = os.path.join(CAPTURES_DIR, name)
    return path if os.path.exists(path) else None


def game_icon(name, logo_image):
    size = (512, 512)
    canvas = background(size, (120, 60, 230), (40, 20, 90), capture("icone.png"))
    canvas.alpha_composite(ray_layer(size, (256, 210), 300, (255, 230, 150), 0.5))
    place(canvas, icons.egg((255, 80, 140)), (256, 200), 300, -6)
    place(canvas, icons.paw(), (110, 120), 130, 18)
    place(canvas, icons.gem((90, 200, 255)), (410, 110), 120, -12)
    place(canvas, icons.coin(), (420, 300), 110, 10)
    place(canvas, icons.gem((165, 95, 255)), (90, 300), 100, 12)
    small_logo = logo_image.copy()
    small_logo.thumbnail((480, 170), Image.LANCZOS)
    canvas.alpha_composite(small_logo, ((512 - small_logo.width) // 2, 512 - small_logo.height - 18))
    return canvas.convert("RGB")


def thumbnail(name, logo_image, headline, color, pieces, capture_name, accents=()):
    size = (1920, 1080)
    shot = capture(capture_name)
    canvas = background(size, icons.darker(color, 0.6) if shot else color, (25, 15, 55), shot)
    # Sur une vraie capture, la scene du jeu reste visible : seulement quelques petites icones
    if not shot:
        canvas.alpha_composite(ray_layer(size, (1380, 560), 720, (255, 235, 170), 0.35))
    for build, center, s, rot in (accents if shot else pieces):
        place(canvas, build(), center, s, rot)
    big_logo = logo_image.copy()
    big_logo.thumbnail((900, 330), Image.LANCZOS)
    canvas.alpha_composite(big_logo, (70, 60))
    text = banner_text(headline, 96, (255, 255, 255), (200, 225, 255))
    max_width = 780 if shot else 960
    if text.width > max_width:
        text.thumbnail((max_width, 400), Image.LANCZOS)
    canvas.alpha_composite(text, (80, 1080 - text.height - 90))
    return canvas.convert("RGB")


# Images des passes et produits pour le Creator Hub (512 x 512)
SHOP_ITEMS = {
    "pass_DoublePower": (icons.power, (255, 190, 40), "x2"),
    "pass_AutoTap": (icons.gear, (90, 170, 255), "AUTO"),
    "pass_ExtraPets": (icons.paw, (70, 200, 110), "+2"),
    "pass_TripleHatch": (icons.egg, (150, 95, 255), "x3"),
    "pass_DoubleShards": (lambda: icons.gem((165, 95, 255)), (120, 70, 220), "x2"),
    "pass_RaidBag": (icons.sack, (230, 120, 40), "+50%"),
    "produit_MythicEgg": (lambda: icons.egg((255, 80, 140)), (230, 70, 150), None),
    "produit_MythicEgg3": (lambda: icons.egg((255, 80, 140)), (230, 70, 150), "x3"),
    "produit_BoostPower": (icons.potion, (230, 80, 170), "x2"),
    "produit_BoostLuck": (icons.star, (240, 170, 40), "x2"),
    "produit_GoldPack": (icons.coin, (240, 175, 30), None),
    "produit_ShardPack": (lambda: icons.gem((80, 220, 120)), (50, 170, 90), "+100"),
    "produit_Shield2": (icons.shield, (50, 120, 230), "2 h"),
    "produit_Shield8": (icons.shield, (40, 90, 200), "8 h"),
}


def shop_image(build, color, badge):
    size = (512, 512)
    canvas = background(size, icons.lighter(color, 0.25), icons.darker(color, 0.45))
    canvas.alpha_composite(ray_layer(size, (256, 240), 300, (255, 255, 255), 0.35))
    place(canvas, build(), (256, 250), 360, 0)
    if badge:
        text = banner_text(badge, 110, (255, 255, 255), (255, 225, 120))
        text.thumbnail((300, 160), Image.LANCZOS)
        canvas.alpha_composite(text, (512 - text.width - 20, 512 - text.height - 16))
    # Coins arrondis (Roblox affiche les passes dans un cercle ou un carre arrondi)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 511, 511], radius=70, fill=255)
    canvas.putalpha(mask)
    return canvas


def shop_images():
    folder = os.path.join(MARKETING_DIR, "boutique")
    os.makedirs(folder, exist_ok=True)
    for name, (build, color, badge) in SHOP_ITEMS.items():
        shop_image(build, color, badge).save(os.path.join(folder, name + ".png"))

def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "Rappelz"
    os.makedirs(ICON_DIR, exist_ok=True)
    os.makedirs(MARKETING_DIR, exist_ok=True)
    rays(512).save(os.path.join(ICON_DIR, "Rayons.png"))
    logo_image = logo(name)
    ui_logo = logo_image.copy()
    ui_logo.thumbnail((1024, 400), Image.LANCZOS)
    ui_logo.save(os.path.join(ICON_DIR, "Logo.png"))
    game_icon(name, logo_image).save(os.path.join(MARKETING_DIR, "icone_jeu_512.png"))
    thumbnail(name, logo_image, "FAIS ÉCLORE\nDES FAMILIERS !", (150, 70, 230), [
        (lambda: icons.egg((255, 80, 140)), (1400, 560), 560, -8),
        (icons.paw, (1720, 260), 260, 15),
        (lambda: icons.egg((80, 220, 120)), (1100, 820), 260, 10),
        (icons.sparkles, (1730, 860), 240, 0),
    ], "miniature_1.png", [
        (lambda: icons.egg((255, 80, 140)), (1780, 160), 210, 10),
        (icons.sparkles, (1620, 110), 130, 0),
    ]).save(os.path.join(MARKETING_DIR, "miniature_1_familiers.png"))
    thumbnail(name, logo_image, "PILLE LES TOURS\nDES AUTRES !", (220, 110, 40), [
        (icons.tower, (1420, 560), 560, 0),
        (icons.sack, (1760, 820), 300, 12),
        (icons.shield, (1100, 820), 240, -10),
        (icons.coin, (1720, 250), 200, 10),
    ], "miniature_2.png", [
        (icons.sack, (1770, 170), 220, 12),
        (icons.coin, (1610, 110), 120, -10),
    ]).save(os.path.join(MARKETING_DIR, "miniature_2_raids.png"))
    thumbnail(name, logo_image, "5 MONDES\nÀ CONQUÉRIR !", (40, 140, 220), [
        (icons.portal, (1400, 540), 520, 0),
        (lambda: icons.gem((80, 220, 120)), (1080, 820), 200, -10),
        (lambda: icons.gem((255, 90, 60)), (1300, 900), 180, 6),
        (lambda: icons.gem((90, 200, 255)), (1700, 880), 210, 12),
        (lambda: icons.gem((255, 205, 70)), (1740, 240), 190, -8),
        (icons.skull, (1080, 260), 200, -12),
    ], "miniature_3.png", [
        (lambda: icons.gem((255, 90, 60)), (1790, 150), 180, 8),
        (lambda: icons.gem((90, 200, 255)), (1650, 100), 110, -10),
    ]).save(os.path.join(MARKETING_DIR, "miniature_3_mondes.png"))
    shop_images()
    print("visuels generes pour", name)


if __name__ == "__main__":
    main()
