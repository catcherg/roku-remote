#!/usr/bin/env python3
"""Compose the App Store screenshots: a caption above a raw simulator capture.

    python3 AppStore/compose_screenshots.py

Reads   AppStore/raw/<name>.png            1320 x 2868 captures, dark mode
Writes  AppStore/screenshots/<locale>/NN-<name>.png   1320 x 2868

1320 x 2868 is the 6.9" iPhone size App Store Connect asks for. Capture the
raw files on the iPhone 17 Pro Max simulator:

    xcrun simctl ui <udid> appearance dark
    xcrun simctl status_bar <udid> override --time "9:41" \
        --batteryState charged --batteryLevel 100 --wifiBars 3
    xcrun simctl io <udid> screenshot AppStore/raw/<name>.png

A shot whose raw file is missing is skipped, so the channel grid (which
needs a real Roku for its icons) can be added later and this re-run.
Rendering uses headless Google Chrome and the fonts in website/public/fonts.
"""
import html
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent
FONTS = ROOT.parent / "website" / "public" / "fonts"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
WIDTH, HEIGHT = 1320, 2868

# name of the raw capture, then one caption per locale. "|" breaks the line
# and [square brackets] set a word as a teal key, like the site's headline.
SHOTS = [
    ("remote", {
        "en-US": "Swipe to move.|[Tap] to select.",
        "es-MX": "Desliza para moverte.|[Toca] para elegir.",
    }),
    ("keyboard", {
        "en-US": "Type with your|phone's [keyboard].",
        "es-MX": "Escribe con el|[teclado] de tu iPhone.",
    }),
    ("channels", {
        "en-US": "Every channel,|one [tap] away.",
        "es-MX": "Todos tus canales,|a un [toque].",
    }),
    ("privacy", {
        "en-US": "No ads. No account.|[No tracking].",
        "es-MX": "Sin anuncios. Sin cuenta.|[Sin rastreo].",
    }),
]

PAGE = """<!doctype html>
<html lang="{lang}">
<meta charset="utf-8">
<style>
  @font-face {{
    font-family: "Archivo";
    font-weight: 100 900;
    font-stretch: 62% 125%;
    src: url("{font}") format("woff2-variations");
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  html, body {{ width: {w}px; height: {h}px; overflow: hidden; }}
  body {{
    position: relative;
    background: radial-gradient(120% 70% at 50% 0%, #12332D 0%, #0A1413 45%, #050707 100%);
    -webkit-font-smoothing: antialiased;
  }}
  h1 {{
    position: absolute; left: 80px; right: 80px; top: 170px; height: 330px;
    display: flex; flex-direction: column; justify-content: center;
    text-align: center; white-space: nowrap; overflow: hidden;
    font-family: "Archivo", sans-serif;
    font-stretch: 116%; font-weight: 680;
    font-size: 112px; line-height: 1.16; letter-spacing: -0.012em;
    color: #F2F2F7;
  }}
  .key {{
    display: inline-block;
    background: #14B89A; color: #06100E;
    border-radius: 0.22em;
    padding: 0 0.16em 0.04em;
    line-height: 1.02;
  }}
  .phone {{
    position: absolute; left: 50%; top: 590px;
    width: 1030px; height: 2238px; margin-left: -515px;
    border-radius: 104px; overflow: hidden;
    border: 4px solid #2A3336;
    box-shadow: 0 50px 140px rgba(0, 0, 0, 0.65);
    background: #000;
  }}
  .phone img {{ display: block; width: 100%; height: 100%; }}
</style>
<body>
  <h1 id="caption">{caption}</h1>
  <div class="phone"><img src="{image}" alt=""></div>
  <script>
    // Shrink the caption until its longest line fits the canvas.
    document.fonts.ready.then(() => {{
      const caption = document.getElementById("caption");
      let size = 112;
      while (caption.scrollWidth > caption.clientWidth && size > 56) {{
        size -= 2;
        caption.style.fontSize = size + "px";
      }}
    }});
  </script>
</body>
</html>
"""


def caption_html(text):
    lines = []
    for line in text.split("|"):
        escaped = html.escape(line)
        escaped = escaped.replace("[", '<span class="key">').replace("]", "</span>")
        lines.append("<span>%s</span>" % escaped)
    return "".join(lines)


def main():
    if not pathlib.Path(CHROME).exists():
        sys.exit("Google Chrome is needed to render the screenshots.")
    font = (FONTS / "archivo-latin-wdth.woff2").as_uri()
    made = 0
    with tempfile.TemporaryDirectory() as scratch:
        for number, (name, captions) in enumerate(SHOTS, start=1):
            raw = ROOT / "raw" / (name + ".png")
            if not raw.exists():
                print("skipped %s (no AppStore/raw/%s.png yet)" % (name, name))
                continue
            for locale, caption in captions.items():
                out = ROOT / "screenshots" / locale / ("%02d-%s.png" % (number, name))
                out.parent.mkdir(parents=True, exist_ok=True)
                page = pathlib.Path(scratch) / ("%s-%s.html" % (locale, name))
                page.write_text(PAGE.format(lang=locale[:2], font=font, w=WIDTH, h=HEIGHT,
                                            caption=caption_html(caption), image=raw.as_uri()),
                                encoding="utf-8")
                subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                                "--force-device-scale-factor=1",
                                "--window-size=%d,%d" % (WIDTH, HEIGHT),
                                "--virtual-time-budget=4000",
                                "--user-data-dir=%s/chrome" % scratch,
                                "--screenshot=%s" % out, page.as_uri()],
                               check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                print("wrote", out.relative_to(ROOT.parent))
                made += 1
    print("%d screenshots written" % made)


if __name__ == "__main__":
    main()
