# 328 - Estrella de celebracion (FX - cofres)

- **archivo**: `fx_star.png`
- **estado**: pendiente
- **destino**: Tools/asset-pipeline/dropbox/

## Prompt

FX Star is a particle sprite for Fisura Evolution, an Argentine merge-idle mobile game: the celebration star that bursts out of the reward chest by the dozen. Draw ONE five-pointed star, alone and centered, filling most of the canvas. The points are fat and stubby rather than thin and spiky, with slightly convex edges so the star reads as chunky and friendly. It is filled flat with cream #FFF8E7 and carries a uniform thick ink #2C2C2C outline all the way around. Inside, off toward the upper-left point, sits one smaller five-pointed highlight star of pure white #FFFFFF with its own thin ink outline, so the interior is never one empty plane. IMPORTANT: the fill must stay cream and white only -- the game tints this sprite at runtime to four different rarity colors, and any hue baked into the art would poison that tint. One star only: no trails, no sparkles around it, no second star.

This art is used at two very different sizes -- huge in a full-screen opening animation and at 26pt inside a list row -- so it has to survive at thumbnail size: one dominant silhouette, thick strokes, strong internal contrast, and no element smaller than roughly one twelfth of the canvas.

The background removal step of our pipeline eats large flat interior areas that look like background, so every enclosed shape must be a closed silhouette filled with a saturated palette color and carrying drawn internal detail -- planks, grain, rivets or highlights -- instead of one empty plane, and nothing inside the artwork may be pure white.

Official game asset, same visual language as the rest of the game: 2D flat vector cartoon, single art direction, uniform thick black outline of constant weight, flat colors with minimal cel-shading, NO gradients, no photorealism, single soft light from the top-left. Locked palette -- #FFD93D sunny yellow, #FF6B35 orange, #FF4D6D pink-red, #4D96FF blue, #6BCB77 green, plus #FFF8E7 cream, #2C2C2C ink black and #FFFFFF white -- use no colors outside that list. Generous safe margin, square canvas, clean readable shapes, mobile-game production quality, cohesive studio look. Simple flat vector game asset, centered, plain white background. No text, no letters, no numbers, no watermark, no cropping.
