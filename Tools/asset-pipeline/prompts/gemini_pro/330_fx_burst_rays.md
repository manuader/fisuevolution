# 330 - Sol de rayos (FX - cofres)

- **archivo**: `fx_burst_rays.png`
- **estado**: pendiente
- **destino**: Tools/asset-pipeline/dropbox/

## Prompt

FX Burst Rays is a background effect sprite for Fisura Evolution, an Argentine merge-idle mobile game: the rotating sunburst that sits behind the reward chest while it is being opened. Draw a radial sunburst of exactly TWELVE straight-sided triangular rays shooting out from a common center point, evenly spaced around the full circle. The rays alternate in width -- six wide ones and six narrow ones between them -- and every ray is filled flat with cream #FFF8E7 and carries a uniform thick ink #2C2C2C outline along both of its long sides and across its blunt outer tip. At the very center sits a small solid ink #2C2C2C disc that the rays spring from. UNLIKE our other assets this one must REACH THE EDGES of the canvas: the ray tips run all the way out to the four sides, with no safe margin, because the game spins this sprite behind a larger object. IMPORTANT: the fill must stay cream only -- the game tints this sprite at runtime to four different rarity colors, and any hue baked into the art would poison that tint. Nothing else in the image: no chest, no stars, no clouds.

This art is used at two very different sizes -- huge in a full-screen opening animation and at 26pt inside a list row -- so it has to survive at thumbnail size: one dominant silhouette, thick strokes, strong internal contrast, and no element smaller than roughly one twelfth of the canvas.

The background removal step of our pipeline eats large flat interior areas that look like background, so every enclosed shape must be a closed silhouette filled with a saturated palette color and carrying drawn internal detail -- planks, grain, rivets or highlights -- instead of one empty plane, and nothing inside the artwork may be pure white.

Official game asset, same visual language as the rest of the game: 2D flat vector cartoon, single art direction, uniform thick black outline of constant weight, flat colors with minimal cel-shading, NO gradients, no photorealism, single soft light from the top-left. Locked palette -- #FFD93D sunny yellow, #FF6B35 orange, #FF4D6D pink-red, #4D96FF blue, #6BCB77 green, plus #FFF8E7 cream, #2C2C2C ink black and #FFFFFF white -- use no colors outside that list. Generous safe margin, square canvas, clean readable shapes, mobile-game production quality, cohesive studio look. Simple flat vector game asset, centered, plain white background. No text, no letters, no numbers, no watermark, no cropping.
