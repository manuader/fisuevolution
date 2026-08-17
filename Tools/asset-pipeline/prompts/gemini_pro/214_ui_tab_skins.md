# 214 — Tab Personalizacion (UI · rediseño)

- **archivo**: `ui_tab_skins.png`
- **estado**: hecho
- **destino**: Tools/asset-pipeline/dropbox/

## Prompt

Tab Personalizacion is the bottom-bar tab icon of the CUSTOMIZATION screen (character skins and outfits) for Fisura Evolution, an Argentine merge-idle mobile game. Design it as two big props crossed in an X: a baseball CAP and a PAINTBRUSH. The cap sits in the lower half, seen from the side facing left, its crown filled blue #4D96FF with an ink #2C2C2C seam curving over the crown, a sunny yellow #FFD93D button on top and a stiff, thickly outlined visor pointing left. The paintbrush crosses over it diagonally from lower-left to upper-right: a fat orange #FF6B35 wooden handle, a cream #FFF8E7 metal ferrule with two ink rivet lines across it, and chunky bristles dipped in pink-red #FF4D6D, with one fat round drop of pink-red paint falling from the tip. Two objects only, both huge, strongly overlapping so the pair reads as a single silhouette.

This icon is drawn at 30pt inside the bottom tab bar, so it has to survive at thumbnail size: one dominant silhouette, thick strokes, strong internal contrast, and no element smaller than roughly one twelfth of the canvas. The background removal step of our pipeline eats large flat interior areas that look like background, so every enclosed shape must be a closed silhouette filled with a saturated palette color and carrying drawn internal detail — seams, rules, emblems or highlights — instead of one empty plane, and nothing inside the icon may be pure white except where explicitly asked for.

Official game asset, same visual language as the rest of the game: 2D flat vector cartoon, single art direction, uniform thick black outline of constant weight, flat colors with minimal cel-shading, NO gradients, no photorealism, single soft light from the top-left. Locked palette — #FFD93D sunny yellow, #FF6B35 orange, #FF4D6D pink-red, #4D96FF blue, #6BCB77 green, plus #FFF8E7 cream, #2C2C2C ink black and #FFFFFF white — use no colors outside that list. Generous safe margin, square canvas, clean readable shapes, mobile-game production quality, cohesive studio look. Simple flat vector game icon, centered, plain white background. No text, no letters, no numbers, no watermark, no cropping.
