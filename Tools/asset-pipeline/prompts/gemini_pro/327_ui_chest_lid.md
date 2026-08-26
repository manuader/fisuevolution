# 327 - Tapa suelta (UI - cofres)

- **archivo**: `ui_chest_lid.png`
- **estado**: pendiente
- **destino**: Tools/asset-pipeline/dropbox/

## Prompt

Chest Lid is the loose lid of the reward chest in Fisura Evolution, an Argentine merge-idle mobile game: the piece that blows off and tumbles through the air when the chest bursts open. Draw the lid ALONE, floating free with nothing under it, tilted about thirty degrees as if caught mid-tumble, filling most of the canvas. It is a fat barrel-shaped dome of orange #FF6B35 wood built from three curved planks, each separated by a thick ink #2C2C2C line and carrying two short curved grain strokes. Three sunny yellow #FFD93D metal bands wrap over the dome, each studded with three round ink rivets. The underside is visible along the bottom edge as a hollow shell: a crescent of darker outlined orange with a cream #FFF8E7 inner face. Two stubby ink hinge knuckles stick out from the back edge, torn and bent. No chest body, no ground, no shadow underneath.

This art is used at two very different sizes -- huge in a full-screen opening animation and at 26pt inside a list row -- so it has to survive at thumbnail size: one dominant silhouette, thick strokes, strong internal contrast, and no element smaller than roughly one twelfth of the canvas.

The background removal step of our pipeline eats large flat interior areas that look like background, so every enclosed shape must be a closed silhouette filled with a saturated palette color and carrying drawn internal detail -- planks, grain, rivets or highlights -- instead of one empty plane, and nothing inside the artwork may be pure white.

Official game asset, same visual language as the rest of the game: 2D flat vector cartoon, single art direction, uniform thick black outline of constant weight, flat colors with minimal cel-shading, NO gradients, no photorealism, single soft light from the top-left. Locked palette -- #FFD93D sunny yellow, #FF6B35 orange, #FF4D6D pink-red, #4D96FF blue, #6BCB77 green, plus #FFF8E7 cream, #2C2C2C ink black and #FFFFFF white -- use no colors outside that list. Generous safe margin, square canvas, clean readable shapes, mobile-game production quality, cohesive studio look. Simple flat vector game asset, centered, plain white background. No text, no letters, no numbers, no watermark, no cropping.
