# 213 — Tab Mejoras (UI · rediseño)

- **archivo**: `ui_tab_upgrades.png`
- **estado**: pendiente
- **destino**: Tools/asset-pipeline/dropbox/

## Prompt

Tab Mejoras is the bottom-bar tab icon of the UPGRADES screen for Fisura Evolution, an Argentine merge-idle mobile game; it has to read instantly as "level up, make it better". Design it as a single chunky arrow pointing straight UP: a wide triangular arrowhead on top and a short, thick rectangular shaft below it, corners softly rounded, the glyph filling most of the canvas. The arrow is filled green #6BCB77. A cream #FFF8E7 highlight stripe runs up the left side of the shaft and a thin ink #2C2C2C seam separates the arrowhead from the shaft, so the arrow is never one empty plane. Under the shaft sit two short stacked horizontal bars — the upper one orange #FF6B35, the lower one sunny yellow #FFD93D — like a small step the arrow is rising from. Bold, symmetrical, centered, no thin details.

This icon is drawn at 30pt inside the bottom tab bar, so it has to survive at thumbnail size: one dominant silhouette, thick strokes, strong internal contrast, and no element smaller than roughly one twelfth of the canvas. The background removal step of our pipeline eats large flat interior areas that look like background, so every enclosed shape must be a closed silhouette filled with a saturated palette color and carrying drawn internal detail — seams, rules, emblems or highlights — instead of one empty plane, and nothing inside the icon may be pure white except where explicitly asked for.

Official game asset, same visual language as the rest of the game: 2D flat vector cartoon, single art direction, uniform thick black outline of constant weight, flat colors with minimal cel-shading, NO gradients, no photorealism, single soft light from the top-left. Locked palette — #FFD93D sunny yellow, #FF6B35 orange, #FF4D6D pink-red, #4D96FF blue, #6BCB77 green, plus #FFF8E7 cream, #2C2C2C ink black and #FFFFFF white — use no colors outside that list. Generous safe margin, square canvas, clean readable shapes, mobile-game production quality, cohesive studio look. Simple flat vector game icon, centered, plain white background. No text, no letters, no numbers, no watermark, no cropping.
