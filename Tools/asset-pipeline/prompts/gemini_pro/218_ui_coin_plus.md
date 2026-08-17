# 218 — Moneda con mas (UI · rediseño)

- **archivo**: `ui_coin_plus.png`
- **estado**: pendiente
- **destino**: Tools/asset-pipeline/dropbox/

## Prompt

Moneda con mas is the HUD button icon that opens the coin store in Fisura Evolution, an Argentine merge-idle mobile game: the game's own coin with an "add coins" badge on it. Draw the same coin the game already uses: a fat circular gold coin seen face-on, filled sunny yellow #FFD93D with a thick ink #2C2C2C outline, an inner concentric ink rim line about one eighth of the radius in from the edge, and a bold embossed money glyph in the centre — a simple S-curve crossed by one vertical stroke, drawn as a raised icon shape, NOT typed text. A slim cream #FFF8E7 crescent highlight hugs the inside of the rim at the upper left. Overlapping the coin's upper-right edge sits a smaller circular BADGE filled pink-red #FF4D6D with its own thick ink outline and a bold white #FFFFFF PLUS sign inside it — the plus is two crossed thick bars drawn as a shape, not typed text. The badge is roughly 45 percent of the coin's diameter and clearly overlaps the coin, so the two read as one silhouette.

This icon is drawn inside a 52pt circular HUD button, so it has to survive at thumbnail size: thick strokes, strong internal contrast, no hair-thin details. The background removal step of our pipeline eats large flat interior areas that look like background, so every enclosed shape must be a closed silhouette filled with a saturated palette color and carrying drawn internal detail — seams, rules, emblems or highlights — instead of one empty plane, and nothing inside the icon may be pure white except where explicitly asked for.

Official game asset, same visual language as the rest of the game: 2D flat vector cartoon, single art direction, uniform thick black outline of constant weight, flat colors with minimal cel-shading, NO gradients, no photorealism, single soft light from the top-left. Locked palette — #FFD93D sunny yellow, #FF6B35 orange, #FF4D6D pink-red, #4D96FF blue, #6BCB77 green, plus #FFF8E7 cream, #2C2C2C ink black and #FFFFFF white — use no colors outside that list. Generous safe margin, square canvas, clean readable shapes, mobile-game production quality, cohesive studio look. Simple flat vector game icon, centered, plain white background. No text, no letters, no numbers, no watermark, no cropping.
