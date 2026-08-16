# 215 — Tab Regalos (UI · rediseño)

- **archivo**: `ui_tab_gifts.png`
- **estado**: pendiente
- **destino**: Tools/asset-pipeline/dropbox/

## Prompt

Tab Regalos is the bottom-bar tab icon of the GIFTS screen for Fisura Evolution, an Argentine merge-idle mobile game. Design it as a fat, front-facing GIFT BOX: a squat rounded-square body filled pink-red #FF4D6D, a separate lid slab across the top with its own thick ink #2C2C2C outline, a sunny yellow #FFD93D ribbon running vertically down the middle of the body and horizontally across the lid, and a big sunny yellow bow with two round loops and two short tails sitting on top of the lid. The ribbon cross and the lid seam cut the face of the box into filled quarters, so no large empty area is left inside the outline. Slightly squashed cartoon proportions — a touch wider than it is tall — and one small white #FFFFFF four-point sparkle at the upper-left corner of the lid.

This icon is drawn at 30pt inside the bottom tab bar, so it has to survive at thumbnail size: one dominant silhouette, thick strokes, strong internal contrast, and no element smaller than roughly one twelfth of the canvas. The background removal step of our pipeline eats large flat interior areas that look like background, so every enclosed shape must be a closed silhouette filled with a saturated palette color and carrying drawn internal detail — seams, rules, emblems or highlights — instead of one empty plane, and nothing inside the icon may be pure white except where explicitly asked for.

Official game asset, same visual language as the rest of the game: 2D flat vector cartoon, single art direction, uniform thick black outline of constant weight, flat colors with minimal cel-shading, NO gradients, no photorealism, single soft light from the top-left. Locked palette — #FFD93D sunny yellow, #FF6B35 orange, #FF4D6D pink-red, #4D96FF blue, #6BCB77 green, plus #FFF8E7 cream, #2C2C2C ink black and #FFFFFF white — use no colors outside that list. Generous safe margin, square canvas, clean readable shapes, mobile-game production quality, cohesive studio look. Simple flat vector game icon, centered, plain white background. No text, no letters, no numbers, no watermark, no cropping.
