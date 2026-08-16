# 217 — Tab Menú (UI · rediseño)

- **archivo**: `ui_tab_menu.png`
- **estado**: pendiente
- **destino**: Tools/asset-pipeline/dropbox/

## Prompt

Tab Menú is the bottom-bar tab icon of the MENU screen for Fisura Evolution, an Argentine merge-idle mobile game; it must echo the game's own panels, which look like a ring-bound notebook. Design it as a closed SPIRAL NOTEBOOK seen straight on: an upright rounded rectangle cover filled blue #4D96FF with a thick ink #2C2C2C outline, and a row of four chunky ink wire rings clipped over the TOP edge, each ring showing a small open gap above the cover. A cream #FFF8E7 label rectangle sits in the middle of the cover carrying three short horizontal ink lines that suggest handwriting — drawn strokes only, never real letters. A pink-red #FF4D6D bookmark ribbon hangs out from behind the bottom-right corner, and that corner of the cover is slightly curled. The rings, the label and the ribbon keep the cover from reading as one empty rectangle.

This icon is drawn at 30pt inside the bottom tab bar, so it has to survive at thumbnail size: one dominant silhouette, thick strokes, strong internal contrast, and no element smaller than roughly one twelfth of the canvas. The background removal step of our pipeline eats large flat interior areas that look like background, so every enclosed shape must be a closed silhouette filled with a saturated palette color and carrying drawn internal detail — seams, rules, emblems or highlights — instead of one empty plane, and nothing inside the icon may be pure white except where explicitly asked for.

Official game asset, same visual language as the rest of the game: 2D flat vector cartoon, single art direction, uniform thick black outline of constant weight, flat colors with minimal cel-shading, NO gradients, no photorealism, single soft light from the top-left. Locked palette — #FFD93D sunny yellow, #FF6B35 orange, #FF4D6D pink-red, #4D96FF blue, #6BCB77 green, plus #FFF8E7 cream, #2C2C2C ink black and #FFFFFF white — use no colors outside that list. Generous safe margin, square canvas, clean readable shapes, mobile-game production quality, cohesive studio look. Simple flat vector game icon, centered, plain white background. No text, no letters, no numbers, no watermark, no cropping.
