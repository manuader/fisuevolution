# 329 - Chispita (FX - cofres)

- **archivo**: `fx_sparkle.png`
- **estado**: hecho
- **destino**: Tools/asset-pipeline/dropbox/

## Prompt

FX Sparkle is a small particle sprite for Fisura Evolution, an Argentine merge-idle mobile game: the little glint that scatters around the reward chest as it is forced open. Draw ONE four-pointed sparkle, alone and centered, filling most of the canvas. Its four points are long slender concave-sided spikes -- a tall vertical pair and a shorter horizontal pair -- meeting at a plump center, the classic cartoon twinkle. It is filled flat with cream #FFF8E7 and carries a uniform thick ink #2C2C2C outline all the way around. At the center sits a small pure white #FFFFFF diamond with its own thin ink outline so the middle is not one empty plane. IMPORTANT: the fill must stay cream and white only -- the game tints this sprite at runtime to four different rarity colors, and any hue baked into the art would poison that tint. One sparkle only: no stars, no trails, no second sparkle.

This art is used at two very different sizes -- huge in a full-screen opening animation and at 26pt inside a list row -- so it has to survive at thumbnail size: one dominant silhouette, thick strokes, strong internal contrast, and no element smaller than roughly one twelfth of the canvas.

The background removal step of our pipeline eats large flat interior areas that look like background, so every enclosed shape must be a closed silhouette filled with a saturated palette color and carrying drawn internal detail -- planks, grain, rivets or highlights -- instead of one empty plane, and nothing inside the artwork may be pure white.

Official game asset, same visual language as the rest of the game: 2D flat vector cartoon, single art direction, uniform thick black outline of constant weight, flat colors with minimal cel-shading, NO gradients, no photorealism, single soft light from the top-left. Locked palette -- #FFD93D sunny yellow, #FF6B35 orange, #FF4D6D pink-red, #4D96FF blue, #6BCB77 green, plus #FFF8E7 cream, #2C2C2C ink black and #FFFFFF white -- use no colors outside that list. Generous safe margin, square canvas, clean readable shapes, mobile-game production quality, cohesive studio look. Simple flat vector game asset, centered, plain white background. No text, no letters, no numbers, no watermark, no cropping.
