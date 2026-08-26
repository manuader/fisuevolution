# 325 - Cofre forzado (UI - cofres)

- **archivo**: `ui_chest_cracked.png`
- **estado**: pendiente
- **destino**: Tools/asset-pipeline/dropbox/

## Prompt

Chest Cracked is the mid-animation state of the reward chest in Fisura Evolution, an Argentine merge-idle mobile game: the same chest after the player has hammered on it twice and the lock has given way. Draw the EXACT same chunky wooden chest as the closed version, at the exact same three-quarter front-left angle, same size and same proportions, so the two images can be swapped without anything jumping. The body is built from four horizontal planks of orange #FF6B35 wood, each plank separated by a thick ink #2C2C2C line and carrying two or three short curved grain strokes so no plank reads as one empty plane. Three sunny yellow #FFD93D metal bands wrap the chest vertically -- one at each corner and one down the middle -- and each band is studded with three round ink rivets. Two short blocky feet in outlined orange hold the chest off the ground. The differences are only these three: the sunny yellow #FFD93D padlock is snapped in two, its shackle broken open and the two halves tilted apart but still hanging from the cream #FFF8E7 latch plate; the barrel-shaped lid is lifted a finger's width at the front, tilted slightly back on its hinges; and a hard-edged wedge of sunny yellow #FFD93D light escapes through that gap, drawn as a flat outlined shape and not as a glow. Two or three short ink crack lines run out from the broken lock across the front planks.

This art is used at two very different sizes -- huge in a full-screen opening animation and at 26pt inside a list row -- so it has to survive at thumbnail size: one dominant silhouette, thick strokes, strong internal contrast, and no element smaller than roughly one twelfth of the canvas.

The background removal step of our pipeline eats large flat interior areas that look like background, so every enclosed shape must be a closed silhouette filled with a saturated palette color and carrying drawn internal detail -- planks, grain, rivets or highlights -- instead of one empty plane, and nothing inside the artwork may be pure white.

Official game asset, same visual language as the rest of the game: 2D flat vector cartoon, single art direction, uniform thick black outline of constant weight, flat colors with minimal cel-shading, NO gradients, no photorealism, single soft light from the top-left. Locked palette -- #FFD93D sunny yellow, #FF6B35 orange, #FF4D6D pink-red, #4D96FF blue, #6BCB77 green, plus #FFF8E7 cream, #2C2C2C ink black and #FFFFFF white -- use no colors outside that list. Generous safe margin, square canvas, clean readable shapes, mobile-game production quality, cohesive studio look. Simple flat vector game asset, centered, plain white background. No text, no letters, no numbers, no watermark, no cropping.
