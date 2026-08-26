# 324 - Cofre cerrado (UI - cofres)

- **archivo**: `ui_chest_closed.png`
- **estado**: pendiente
- **destino**: Tools/asset-pipeline/dropbox/

## Prompt

Chest Closed is the reward chest of Fisura Evolution, an Argentine merge-idle mobile game: the sealed treasure chest the player earns and taps to open. Draw it as a chunky wooden chest seen from a three-quarter front-left angle, resting flat and filling most of the canvas. The body is built from four horizontal planks of orange #FF6B35 wood, each plank separated by a thick ink #2C2C2C line and carrying two or three short curved grain strokes so no plank reads as one empty plane. Three sunny yellow #FFD93D metal bands wrap the chest vertically -- one at each corner and one down the middle -- and each band is studded with three round ink rivets. Two short blocky feet in outlined orange hold the chest off the ground. The lid is a fat barrel-shaped dome of the same orange wood, its plank lines curving to follow the dome. A big sunny yellow #FFD93D padlock hangs at the front center over the middle band: a rounded square with a fat ink keyhole and a thick ink shackle looping through a cream #FFF8E7 latch plate. The chest is shut tight -- no gap between lid and body, no light escaping anywhere.

This art is used at two very different sizes -- huge in a full-screen opening animation and at 26pt inside a list row -- so it has to survive at thumbnail size: one dominant silhouette, thick strokes, strong internal contrast, and no element smaller than roughly one twelfth of the canvas.

The background removal step of our pipeline eats large flat interior areas that look like background, so every enclosed shape must be a closed silhouette filled with a saturated palette color and carrying drawn internal detail -- planks, grain, rivets or highlights -- instead of one empty plane, and nothing inside the artwork may be pure white.

Official game asset, same visual language as the rest of the game: 2D flat vector cartoon, single art direction, uniform thick black outline of constant weight, flat colors with minimal cel-shading, NO gradients, no photorealism, single soft light from the top-left. Locked palette -- #FFD93D sunny yellow, #FF6B35 orange, #FF4D6D pink-red, #4D96FF blue, #6BCB77 green, plus #FFF8E7 cream, #2C2C2C ink black and #FFFFFF white -- use no colors outside that list. Generous safe margin, square canvas, clean readable shapes, mobile-game production quality, cohesive studio look. Simple flat vector game asset, centered, plain white background. No text, no letters, no numbers, no watermark, no cropping.
