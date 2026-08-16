# 219 — Ascensor (UI · rediseño)

- **archivo**: `ui_elevator.png`
- **estado**: pendiente
- **destino**: Tools/asset-pipeline/dropbox/

## Prompt

Ascensor is the HUD button icon that opens the tower's elevator screen in Fisura Evolution, an Argentine merge-idle mobile game. Design it as a front-facing ELEVATOR CABIN: a tall rounded-rectangle door frame filled blue #4D96FF with a thick ink #2C2C2C outline, and inside it a pair of closed sliding doors filled sunny yellow #FFD93D, split down the exact middle by a vertical ink seam, each door leaf carrying a small ink handle notch and one thin ink panel line so the doors are never one flat plane. Set into the frame just above the doors, a narrow cream #FFF8E7 indicator strip with a single ink dot on it. Stacked vertically to the RIGHT of the frame, two chunky call arrows drawn as solid triangles with the same thick ink outline: a green #6BCB77 one pointing UP on top, a pink-red #FF4D6D one pointing DOWN below it. Squat, symmetrical, unmistakably an elevator even at button size.

This icon is drawn inside a 52pt circular HUD button, so it has to survive at thumbnail size: thick strokes, strong internal contrast, no hair-thin details. The background removal step of our pipeline eats large flat interior areas that look like background, so every enclosed shape must be a closed silhouette filled with a saturated palette color and carrying drawn internal detail — seams, rules, emblems or highlights — instead of one empty plane, and nothing inside the icon may be pure white except where explicitly asked for.

Official game asset, same visual language as the rest of the game: 2D flat vector cartoon, single art direction, uniform thick black outline of constant weight, flat colors with minimal cel-shading, NO gradients, no photorealism, single soft light from the top-left. Locked palette — #FFD93D sunny yellow, #FF6B35 orange, #FF4D6D pink-red, #4D96FF blue, #6BCB77 green, plus #FFF8E7 cream, #2C2C2C ink black and #FFFFFF white — use no colors outside that list. Generous safe margin, square canvas, clean readable shapes, mobile-game production quality, cohesive studio look. Simple flat vector game icon, centered, plain white background. No text, no letters, no numbers, no watermark, no cropping.
