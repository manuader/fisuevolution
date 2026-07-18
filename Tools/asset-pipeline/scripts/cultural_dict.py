"""Biblia cultural de Hobo Evolution: assetKey -> descripcion visual EN INGLES.

SD 1.5 no sabe que es un cartonero, un arbolito ni un demonio de ARCA.
La argentinidad se logra describiendo los PROPS visualmente (seccion 5 del
asset doc), nunca escribiendo "argentino" y rezando. El estilo NO va aca:
vive en el LoRA (trigger `hoboevo_style`). Aca va solo el contenido:
subject / props / ar_cues / wealth_cues / expression.

Claves = ids reales de tiers.json (36 personajes; el choice node `junior` es
abstracto y no lleva sprite) + specials + backgrounds + ui + fx del checklist
(seccion 8 del asset doc).

Solo stdlib: importable sin instalar nada.
"""

# ---------------------------------------------------------------------------
# PERSONAJES (36) — claves = tiers.json ids. Vista 3/4, cuerpo completo,
# fondo transparente (el sufijo de framing lo agrega gen_prompts.py).
# Entradas de seccion 5 del asset doc usadas textuales donde existen.
# ---------------------------------------------------------------------------

CHARACTERS = {
    # ----- EARTH T1-T10 (tanda 1) -----
    "homeless": {
        "subject": "scruffy homeless street man with attitude",
        "props": "bottle, tattered layered clothes, fingerless gloves",
        "ar_cues": "Buenos Aires street 'fisura' vibe, disheveled but endearing",
        "wealth_cues": "none, dirty patched clothes",
        "expression": "dazed goofy stare",
    },
    "cartonero": {
        "subject": "street cardboard collector pushing a big two-wheeled cart",
        "props": "cart piled with flattened cardboard, hi-vis reflective vest, worn cap",
        "ar_cues": "urban recycler hustling through the city, streetwise and proud",
        "wealth_cues": "very poor, patched trousers",
        "expression": "determined squint with a tired smile",
    },
    "kiosco": {
        "subject": "small kiosk shop attendant behind a tiny counter window",
        "props": "counter crammed with candy, pack of cigarettes, sleeping cat beside him, hanging snack strips",
        "ar_cues": "neighborhood corner kiosk that never closes",
        "wealth_cues": "modest, simple apron over t-shirt",
        "expression": "sleepy deadpan stare",
    },
    "repartidor": {
        "subject": "food delivery rider on a beat-up scooter",
        "props": "oversized generic cube-shaped food-delivery backpack (parody, no real brand), scuffed helmet, cracked phone mounted on handlebar",
        "ar_cues": "gig-economy courier racing through traffic",
        "wealth_cues": "low income, worn-out sneakers",
        "expression": "stressed wide-eyed hurry",
    },
    "chofer_app": {
        "subject": "rideshare app driver leaning on his compact car",
        "props": "small sedan car, courtesy water bottle and lollipop on the dashboard, phone with navigation app",
        "ar_cues": "chatty rideshare driver proud of his five-star rating",
        "wealth_cues": "working class, tidy polo shirt",
        "expression": "friendly overeager grin",
    },
    "fast_food": {
        "subject": "fast food employee at the fryer counter",
        "props": "fast-food uniform and paper hat (parody 'McRonald's'), greasy spatula, tray of fries",
        "ar_cues": "burger-joint shift that was supposed to be temporary",
        "wealth_cues": "minimum wage, grease-stained uniform",
        "expression": "resigned thousand-yard stare",
    },
    "oficinista": {
        "subject": "tired office clerk at a cluttered desk",
        "props": "wrinkled dress shirt, loosened tie, heavy eye bags, a mate gourd with metal straw on the desk",
        "ar_cues": "Buenos Aires office worker surviving on mate",
        "wealth_cues": "lower middle class, cheap tie",
        "expression": "exhausted forced smile",
    },
    "administrativo": {
        "subject": "administrative clerk buried in official paperwork",
        "props": "towering stacks of stamped folders, rubber stamp in hand, clip-on tie, loose form sheets flying",
        "ar_cues": "endless bureaucracy, everything in triplicate with official seals",
        "wealth_cues": "modest, sweater vest over shirt",
        "expression": "bored bureaucratic blank stare",
    },
    "junior_programmer": {
        "subject": "young junior programmer fresh out of university",
        "props": "laptop covered in stickers, dark-mode screen glow, hoodie, energy drink can",
        "ar_cues": "proud new graduate holding his first job, empty pockets",
        "wealth_cues": "broke graduate, worn backpack",
        "expression": "nervous eager smile",
    },
    "junior_architect": {
        "subject": "young junior architect fresh out of university",
        "props": "rolled blueprints, small building model, scale ruler in shirt pocket",
        "ar_cues": "proud new graduate at his first studio internship, empty pockets",
        "wealth_cues": "broke graduate, thrifted blazer",
        "expression": "hopeful wide smile",
    },
    "junior_doctor": {
        "subject": "young junior doctor fresh out of medical school",
        "props": "oversized white coat, stethoscope around neck, clipboard, giant coffee thermos",
        "ar_cues": "proud new graduate on a 24-hour hospital shift, empty pockets",
        "wealth_cues": "broke graduate, scrubs under the coat",
        "expression": "sleep-deprived enthusiastic grin",
    },
    "junior_lawyer": {
        "subject": "young junior lawyer fresh out of law school",
        "props": "cheap slightly oversized suit, thick law code book under arm, bulging folder of case papers",
        "ar_cues": "proud new graduate running courthouse errands, empty pockets",
        "wealth_cues": "broke graduate, scuffed dress shoes",
        "expression": "overconfident rookie smirk",
    },
    "senior_programmer": {
        "subject": "veteran senior programmer",
        "props": "mechanical keyboard, triple monitor glow, worn hoodie over collared shirt, gray-streaked beard, rubber duck on desk",
        "ar_cues": "grumpy tech lead who has seen every bug in existence",
        "wealth_cues": "comfortable, expensive headphones",
        "expression": "smug all-knowing smirk",
    },
    "senior_architect": {
        "subject": "veteran senior architect",
        "props": "white hard hat, long blueprint tube, glasses pushed up on forehead, miniature skyscraper model in hand",
        "ar_cues": "seasoned architect bossing around a construction site",
        "wealth_cues": "well-off, tailored shirt with rolled sleeves",
        "expression": "confident appraising look",
    },
    "senior_doctor": {
        "subject": "veteran senior doctor",
        "props": "pristine white coat, head mirror, expensive pen in chest pocket, framed diploma under arm",
        "ar_cues": "renowned specialist with a private practice",
        "wealth_cues": "wealthy professional, gold wristwatch",
        "expression": "calm reassuring smile",
    },
    "senior_lawyer": {
        "subject": "veteran senior lawyer",
        "props": "sharp pinstripe suit, leather briefcase, gold fountain pen, thick signed contract",
        "ar_cues": "feared courtroom shark who never loses",
        "wealth_cues": "wealthy professional, silk tie",
        "expression": "predatory confident grin",
    },
    # ----- EARTH T11-T21 (tanda 4) -----
    "director": {
        "subject": "corporate director in a corner office",
        "props": "tailored suit, desk name plate, tiny espresso cup, city skyline window behind",
        "ar_cues": "middle-management boss who loves calling meetings",
        "wealth_cues": "upper class, shiny cufflinks",
        "expression": "practiced power smile",
    },
    "fundador_startup": {
        "subject": "startup founder pitching his big idea",
        "props": "blazer over graphic t-shirt, conference lanyard badge, floating pitch-deck slides, unicorn coffee mug",
        "ar_cues": "buzzword-loving tech founder promising to disrupt everything",
        "wealth_cues": "paper millionaire, designer sneakers",
        "expression": "visionary wide-eyed intensity",
    },
    "dueno_pyme": {
        "subject": "small factory business owner",
        "props": "shirt with rolled sleeves, big ring of keys on belt, small delivery truck behind, old calculator in hand",
        "ar_cues": "hard-working family business boss who does every job himself",
        "wealth_cues": "solid middle class, sturdy work boots",
        "expression": "proud tired smile",
    },
    "emprendedor": {
        "subject": "hustling serial entrepreneur",
        "props": "megaphone in hand, generic mindset book under arm, whiteboard with rising arrow chart, headset microphone",
        "ar_cues": "hustle-culture guru selling online courses",
        "wealth_cues": "flashy but leveraged, shiny suit",
        "expression": "over-caffeinated megawatt smile",
    },
    "ceo": {
        "subject": "powerful corporate CEO",
        "props": "immaculate dark suit, golden tie, smartphone in hand, skyscraper silhouette behind",
        "ar_cues": "untouchable big-company boss, board meetings and golf",
        "wealth_cues": "rich, gold watch and pocket square",
        "expression": "cold triumphant smirk",
    },
    "millonario": {
        "subject": "flashy new millionaire",
        "props": "banknotes raining around him, champagne glass, fur-collared coat, chunky gold rings",
        "ar_cues": "new money showing off everything at once",
        "wealth_cues": "millionaire, bills stuffed in every pocket",
        "expression": "ecstatic laughing grin",
    },
    "multimillonario": {
        "subject": "extravagant multi-millionaire",
        "props": "open briefcase overflowing with cash, small yacht model in hand, multiple gold chains, diamond tie pin",
        "ar_cues": "tycoon who owns half the city and forgot which half",
        "wealth_cues": "obscene wealth, velvet suit",
        "expression": "bored unimpressed look",
    },
    "rey_ladrillo": {
        "subject": "real-estate mogul, king of bricks",
        "props": "holding a brick and a tower model, crown made of little bricks, folded blueprints in pocket",
        "ar_cues": "buys whole city blocks, preaches that bricks never lose value",
        "wealth_cues": "massive property wealth, brick-red suit",
        "expression": "beaming landlord grin",
    },
    "magnate_petrolero": {
        "subject": "classic oil tycoon magnate",
        "props": "black top hat, oil derrick silhouette behind, oil barrel, fat cigar, oil-drop pattern tie",
        "ar_cues": "old-school baron striking black gold",
        "wealth_cues": "petro-rich, gold-tipped cane",
        "expression": "greedy delighted grin",
    },
    "space_billionaire": {
        "subject": "eccentric space-obsessed billionaire",
        "props": "business suit with astronaut helmet under arm, toy-like personal rocket behind, mission patch on chest",
        "ar_cues": "tech billionaire racing his own rockets to space, generic parody of no real person",
        "wealth_cues": "billionaire, platinum watch",
        "expression": "manic visionary grin",
    },
    "trillonario": {
        "subject": "reality-bending trillionaire",
        "props": "monocle, banknotes orbiting him like satellites, tiny planet held like a stress ball, infinity-pattern suit",
        "ar_cues": "wealth beyond countries, buys economies for fun",
        "wealth_cues": "trillions, glowing golden trim on suit",
        "expression": "serene untouchable smile",
    },
    # ----- COSMIC T22-T30 (tanda 4) -----
    "dueno_luna": {
        "subject": "proud owner of the Moon standing on lunar ground",
        "props": "chunky moon boots, planted flag with his own smiling face on it, framed property deed, astronaut helmet under arm",
        "ar_cues": "bought the entire Moon as a real-estate flex",
        "wealth_cues": "lunar landlord, silver-glitter suit",
        "expression": "smug landlord smirk",
    },
    "dueno_marte": {
        "subject": "owner of planet Mars",
        "props": "red dusty ground, sold-style sign post planted in the soil, snow globe with a tiny domed city inside, spacesuit with a painted-on necktie",
        "ar_cues": "flipping an entire red planet like a fixer-upper",
        "wealth_cues": "interplanetary mogul, copper-red cape",
        "expression": "deal-closing wink",
    },
    "magnate_solar": {
        "subject": "magnate of the entire solar system",
        "props": "holding a miniature glowing sun like a beach ball, small planets orbiting his head, cosmic sunglasses",
        "ar_cues": "owns every planet and charges tolls per orbit",
        "wealth_cues": "solar-scale riches, radiant golden suit",
        "expression": "blinding confident smile",
    },
    "senor_galaxia": {
        "subject": "lord of the galaxy",
        "props": "swirling spiral-galaxy cape, small stars orbiting his crown, staff topped with a tiny black hole",
        "ar_cues": "galactic overlord signing away star systems like paperwork",
        "wealth_cues": "galactic empire, constellation-pattern robe",
        "expression": "regal amused stare",
    },
    "emperador_cosmico": {
        "subject": "cosmic emperor on a floating nebula throne",
        "props": "massive jagged crown, scepter topped with a spinning planet, cape made of nebula clouds",
        "ar_cues": "rules space itself and taxes light for passing through",
        "wealth_cues": "cosmic empire, jewel-studded ceremonial robe",
        "expression": "imperious raised eyebrow",
    },
    "ser_ascendido": {
        "subject": "ascended being of pure energy",
        "props": "floating cross-legged in lotus pose, glowing third eye, body outlined in radiant light, small floating orbs",
        "ar_cues": "transcended money, now he IS the economy",
        "wealth_cues": "beyond material wealth, luminous aura",
        "expression": "blissful enlightened smile",
    },
    "semidios": {
        "subject": "muscular demigod",
        "props": "white toga with golden trim, laurel wreath, lightning bolt gripped in fist, tiny pet storm cloud",
        "ar_cues": "half mortal half divine, still checks his investment portfolio",
        "wealth_cues": "divine treasures, golden sandals",
        "expression": "heroic overconfident grin",
    },
    "deidad": {
        "subject": "radiant multi-armed deity",
        "props": "four arms holding a coin, a lightning bolt, balance scales and a mate gourd, golden halo disc behind head",
        "ar_cues": "worshipped as the god of hustle",
        "wealth_cues": "temples of gold, ornate jewelry",
        "expression": "serene all-knowing smile",
    },
    "god": {
        "subject": "supreme god of everything",
        "props": "enormous white cloud beard, all-seeing eye above his head, cosmic halo, tiny spinning universe in one palm, mate gourd in the other hand",
        "ar_cues": "the final form: God himself, but he still drinks mate",
        "wealth_cues": "owns existence itself, robe of stars",
        "expression": "warm omnipotent smile",
    },
}

# ---------------------------------------------------------------------------
# SPECIALS (10) — atlas specials, tanda 5
# ---------------------------------------------------------------------------

SPECIALS = {
    "sp_cryptobro": {
        "subject": "smug crypto bro trader",
        "props": "flashy oversized watch, phone showing green candlestick chart, sunglasses pushed up, coin-pattern shirt",
        "ar_cues": "to-the-moon evangelist who never sells at the top",
        "wealth_cues": "volatile riches, gold chain over hoodie",
        "expression": "insufferable smug grin",
    },
    "sp_demonio_arca": {
        "subject": "bureaucratic tax demon",
        "props": "bat wings, small horns, office necktie, armful of tax forms, giant red ink stamp",
        "ar_cues": "tax-collector demon from the underworld revenue service",
        "wealth_cues": "feeds on late fees, shabby office suit",
        "expression": "gleeful sadistic smile",
    },
    "sp_contador_dios": {
        "subject": "divine celestial accountant",
        "props": "glowing ledger book, halo shaped like a calculator, floating glowing spreadsheets, feather quill",
        "ar_cues": "audits the finances of mortals from heaven",
        "wealth_cues": "cosmic order, immaculate white suit",
        "expression": "serene judging stare",
    },
    "sp_zombie_ceo": {
        "subject": "undead zombie CEO",
        "props": "torn pinstripe suit, green skin, stitched forehead, dangling loose tie, coffee cup clutched in stiff hand",
        "ar_cues": "still attends board meetings from beyond the grave",
        "wealth_cues": "posthumous stock options, dusty gold watch",
        "expression": "vacant hungry stare",
    },
    "sp_lizard": {
        "subject": "reptilian humanoid in a business suit",
        "props": "green scales, vertical slit pupils, forked tongue, half-lifted human face mask, tailored gray suit",
        "ar_cues": "conspiracy-theory lizard person secretly running world finance",
        "wealth_cues": "shadow-elite wealth, obsidian cufflinks",
        "expression": "unsettling too-wide smile",
    },
    "sp_alien_investor": {
        "subject": "little green alien venture investor",
        "props": "big oval head with antenna, briefcase overflowing with glowing space currency, small UFO parked behind, tablet with charts",
        "ar_cues": "intergalactic venture capitalist scouting Earth startups",
        "wealth_cues": "galactic funds, tiny silver suit",
        "expression": "curious calculating stare",
    },
    "sp_bug_simulacion": {
        "subject": "glitched-out simulation error character",
        "props": "body split into offset slices, floating warning signs, half-rendered limbs, patches of static noise",
        "ar_cues": "a rendering error of the simulation that became self-aware",
        "wealth_cues": "corrupted data, flickering outline",
        "expression": "confused fragmented face",
    },
    "sp_arbolito": {
        "subject": "street currency dealer whispering exchange rates",
        "props": "jacket held open lined with fanned foreign banknotes, small leafy branch with bill-shaped leaves sprouting from his cap, hand beside mouth mid-whisper",
        "ar_cues": "downtown Buenos Aires street money changer, the human money tree",
        "wealth_cues": "wads of foreign cash, worn windbreaker",
        "expression": "shifty sideways glance",
    },
    "sp_coach": {
        "subject": "over-the-top motivational life coach",
        "props": "headset microphone, sparkling white teeth, tight polo shirt, whiteboard with rocket doodle, rubber wristbands",
        "ar_cues": "sells success formulas and five-am morning routines",
        "wealth_cues": "seminar money, shiny loafers",
        "expression": "aggressively positive beam",
    },
    "sp_influencer": {
        "subject": "social media influencer mid-selfie",
        "props": "ring light glowing behind head like a halo, phone on selfie stick, shopping bags, floating heart and thumbs-up symbols",
        "ar_cues": "monetizes every waking second of her life",
        "wealth_cues": "gifted products, designer knockoffs",
        "expression": "practiced duck-face pout",
    },
}

# ---------------------------------------------------------------------------
# BACKGROUNDS (11) — escenas SIN personajes, canvas completo (no transparente).
# `expression` se usa como mood/iluminacion de la escena.
# ---------------------------------------------------------------------------

BACKGROUNDS = {
    "bg_alley": {
        "subject": "gritty dead-end city alley background scene",
        "props": "dumpster, flattened cardboard boxes, graffiti wall, clothesline with rags, dripping pipe, lonely street lamp",
        "ar_cues": "Buenos Aires back alley where the Fisura sleeps",
        "wealth_cues": "poor neighborhood, cracked plaster walls",
        "expression": "moody but warm, soft light from top-left",
    },
    "bg_urban": {
        "subject": "lively city street corner background scene",
        "props": "corner kiosk, bus stop shelter, tangled power lines, obelisk silhouette on the horizon, parked scooter, pigeons",
        "ar_cues": "Buenos Aires downtown energy",
        "wealth_cues": "working-class city, faded posters",
        "expression": "busy daytime cheer",
    },
    "bg_corporate": {
        "subject": "glass corporate district background scene",
        "props": "mirrored office towers, revolving door entrance, grids of office windows, small coffee cart",
        "ar_cues": "financial district ambition",
        "wealth_cues": "corporate polish, blue glass and steel",
        "expression": "cool professional morning light",
    },
    "bg_luxury": {
        "subject": "luxury penthouse interior background scene",
        "props": "floor-to-ceiling window over a night skyline, marble floor, golden chandelier, abstract art piece",
        "ar_cues": "new-money penthouse excess",
        "wealth_cues": "opulent gold and marble",
        "expression": "glamorous night glow",
    },
    "bg_island": {
        "subject": "private tropical island background scene",
        "props": "white sand beach, palm trees, yacht anchored offshore, beach cabana, turquoise water",
        "ar_cues": "billionaire hideaway island",
        "wealth_cues": "owning paradise itself",
        "expression": "sunny vacation bliss",
    },
    "bg_moon": {
        "subject": "lunar surface background scene",
        "props": "gray craters, several planted flags, small glass dome habitat, Earth rising in a black sky, rover tracks",
        "ar_cues": "the Moon turned into private property",
        "wealth_cues": "lunar real estate development",
        "expression": "serene cosmic quiet",
    },
    "bg_mars": {
        "subject": "red martian desert background scene",
        "props": "red dunes and rocky mesas, terraforming domes, two small moons in a pink sky, distant dust devil",
        "ar_cues": "Mars in the middle of a real-estate development boom",
        "wealth_cues": "planetary-scale investment",
        "expression": "warm alien dusk",
    },
    "bg_solar": {
        "subject": "solar system panorama background scene",
        "props": "giant stylized sun, planets aligned along orbit rings, asteroid belt, tiny toll gates on the orbit lines",
        "ar_cues": "the whole solar system managed like a portfolio",
        "wealth_cues": "star-scale assets",
        "expression": "radiant cosmic grandeur",
    },
    "bg_galaxy": {
        "subject": "spiral galaxy panorama background scene",
        "props": "swirling spiral arms of stars, colorful nebulas, star clusters, tiny constellations",
        "ar_cues": "a galaxy under new management",
        "wealth_cues": "galactic scale property",
        "expression": "deep space majesty",
    },
    "bg_cosmic": {
        "subject": "abstract cosmic realm background scene",
        "props": "floating rock islands, aurora ribbons, geometric portals, rivers of stars",
        "ar_cues": "space itself bending to wealth",
        "wealth_cues": "reality-scale power",
        "expression": "surreal cosmic wonder",
    },
    "bg_god_realm": {
        "subject": "divine heavenly realm background scene",
        "props": "sea of clouds, golden gates, marble columns, god rays from above, golden coins floating like stars",
        "ar_cues": "the afterlife of infinite wealth",
        "wealth_cues": "paradise made of gold and light",
        "expression": "blinding holy serenity",
    },
}

# ---------------------------------------------------------------------------
# UI (31 = 10 botones + 7 currency + 7 upgrades + 6 boosts + logo)
# Iconos flat simples, centrados, fondo transparente. Sin texto NUNCA.
# ---------------------------------------------------------------------------

UI = {
    # --- botones (10) ---
    "ui_btn_primary": {
        "subject": "mobile game button, rounded rectangle",
        "props": "sunny yellow fill, darker flat bottom edge, no icon, no label",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_btn_secondary": {
        "subject": "mobile game button, rounded rectangle",
        "props": "sky blue fill, darker flat bottom edge, no icon, no label",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_btn_danger": {
        "subject": "mobile game button, rounded rectangle",
        "props": "hot pink-red fill, darker flat bottom edge, no icon, no label",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_btn_disabled": {
        "subject": "mobile game button, rounded rectangle",
        "props": "desaturated gray fill, pressed flat look, no icon, no label",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_btn_store": {
        "subject": "mobile game button, rounded rectangle",
        "props": "orange fill with a white shopping cart glyph",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_btn_upgrade": {
        "subject": "mobile game button, rounded rectangle",
        "props": "green fill with a white upward arrow glyph",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_btn_reincarnate": {
        "subject": "mobile game button, rounded rectangle",
        "props": "blue fill with a pink circular rebirth spiral glyph",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_btn_watch_ad": {
        "subject": "mobile game button, rounded rectangle",
        "props": "blue fill with a white play triangle inside a small screen glyph",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_btn_claim": {
        "subject": "mobile game button, rounded rectangle",
        "props": "yellow fill with a small gift box glyph",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_btn_collect": {
        "subject": "mobile game button, rounded rectangle",
        "props": "green fill with an open hand catching a falling coin glyph",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    # --- currency (7) ---
    "ui_coin": {
        "subject": "game currency icon",
        "props": "shiny golden coin with an embossed generic money glyph",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_money": {
        "subject": "game currency icon",
        "props": "small stack of green banknotes with a paper band",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_dollar": {
        "subject": "game currency icon",
        "props": "single crisp green banknote with a generic oval portrait",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_million": {
        "subject": "game currency icon",
        "props": "tall bundle of strapped banknote stacks",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_billion": {
        "subject": "game currency icon",
        "props": "open briefcase packed with banknote bundles and a gold bar",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_trillion": {
        "subject": "game currency icon",
        "props": "sparkling diamond sitting on a pile of gold coins",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_infinity": {
        "subject": "game currency icon",
        "props": "glowing golden infinity loop symbol floating above a coin",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    # --- upgrade icons (7) ---
    "ui_up_income": {
        "subject": "game upgrade icon",
        "props": "gold coin with a rising arrow",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_up_spawn": {
        "subject": "game upgrade icon",
        "props": "hatching golden egg with sparkles and a tiny plus burst",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_up_offline": {
        "subject": "game upgrade icon",
        "props": "crescent moon over a small pile of coins",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_up_tap": {
        "subject": "game upgrade icon",
        "props": "pointing finger tapping with radial burst lines",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_up_crit": {
        "subject": "game upgrade icon",
        "props": "coin struck by a lightning bolt with an impact burst",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_up_golden": {
        "subject": "game upgrade icon",
        "props": "golden hand touching a coin with sparkling midas-touch stars",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "ui_up_prestige": {
        "subject": "game upgrade icon",
        "props": "star with an orbiting loop arrow around it",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    # --- boosts (6) ---
    "ui_boost_mate": {
        "subject": "game boost icon",
        "props": "Argentine mate gourd with metal bombilla straw and a steam wisp",
        "ar_cues": "the national fuel of Argentina",
        "wealth_cues": "", "expression": "",
    },
    "ui_boost_cafe": {
        "subject": "game boost icon",
        "props": "small espresso coffee cup with bold steam swirls",
        "ar_cues": "extra-strong 'cargado' coffee",
        "wealth_cues": "", "expression": "",
    },
    "ui_boost_fernet": {
        "subject": "game boost icon",
        "props": "tall glass of dark herbal liquor mixed with cola, foam on top, ice cubes",
        "ar_cues": "iconic Argentine fernet con coca",
        "wealth_cues": "", "expression": "",
    },
    "ui_boost_milanesa": {
        "subject": "game boost icon",
        "props": "golden breaded meat cutlet on a plate with a lemon wedge",
        "ar_cues": "the sacred Argentine milanesa",
        "wealth_cues": "", "expression": "",
    },
    "ui_boost_asado": {
        "subject": "game boost icon",
        "props": "smoking charcoal grill with sizzling meat cuts and sausages",
        "ar_cues": "Sunday asado barbecue ritual",
        "wealth_cues": "", "expression": "",
    },
    "ui_boost_turbo": {
        "subject": "game boost icon",
        "props": "rocket-flame speed gauge with a fire trail",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    # --- logo (marca grafica SIN texto; tambien base del AppIcon) ---
    "logo": {
        "subject": "game logo mark, graphic emblem only, absolutely no letters or words",
        "props": "circular badge with a cartoon scruffy bearded face wearing a tilted golden crown, bold upward evolution arrow behind the head",
        "ar_cues": "from street fisura to god, cheeky and iconic",
        "wealth_cues": "",
        "expression": "cheeky one-eyebrow grin",
    },
}

# ---------------------------------------------------------------------------
# FX (5) — sprites simples de particula para SKEmitterNode.
# ---------------------------------------------------------------------------

FX = {
    "fx_merge": {
        "subject": "particle sprite for a game effect",
        "props": "radial starburst pop, thick flat rays",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "fx_money": {
        "subject": "particle sprite for a game effect",
        "props": "single spinning golden coin with small motion tick marks",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "fx_tap": {
        "subject": "particle sprite for a game effect",
        "props": "concentric tap ripple rings",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "fx_unlock": {
        "subject": "particle sprite for a game effect",
        "props": "four-pointed sparkle star",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
    "fx_evolution_flash": {
        "subject": "particle sprite for a game effect",
        "props": "bright radial flash burst with flat wedge rays",
        "ar_cues": "", "wealth_cues": "", "expression": "",
    },
}

# ---------------------------------------------------------------------------
# Ordenes canonicos (fijan seeds deterministas; NO reordenar una vez generado)
# ---------------------------------------------------------------------------

SPECIALS_ORDER = [
    "sp_cryptobro", "sp_demonio_arca", "sp_contador_dios", "sp_zombie_ceo",
    "sp_lizard", "sp_alien_investor", "sp_bug_simulacion", "sp_arbolito",
    "sp_coach", "sp_influencer",
]

BACKGROUNDS_ORDER = [
    "bg_alley", "bg_urban", "bg_corporate",            # tempranos (tanda 3)
    "bg_luxury", "bg_island", "bg_moon", "bg_mars",    # cosmicos/tardios (tanda 4)
    "bg_solar", "bg_galaxy", "bg_cosmic", "bg_god_realm",
]
EARLY_BACKGROUNDS = 3  # los primeros N de BACKGROUNDS_ORDER van en tanda 3

UI_ORDER = [
    # botones (10)
    "ui_btn_primary", "ui_btn_secondary", "ui_btn_danger", "ui_btn_disabled",
    "ui_btn_store", "ui_btn_upgrade", "ui_btn_reincarnate", "ui_btn_watch_ad",
    "ui_btn_claim", "ui_btn_collect",
    # currency (7)
    "ui_coin", "ui_money", "ui_dollar", "ui_million", "ui_billion",
    "ui_trillion", "ui_infinity",
    # upgrades (7)
    "ui_up_income", "ui_up_spawn", "ui_up_offline", "ui_up_tap", "ui_up_crit",
    "ui_up_golden", "ui_up_prestige",
    # boosts (6)
    "ui_boost_mate", "ui_boost_cafe", "ui_boost_fernet", "ui_boost_milanesa",
    "ui_boost_asado", "ui_boost_turbo",
    # logo (1)
    "logo",
]

FX_ORDER = ["fx_merge", "fx_money", "fx_tap", "fx_unlock", "fx_evolution_flash"]

CULTURAL_DICT = {**CHARACTERS, **SPECIALS, **BACKGROUNDS, **UI, **FX}


if __name__ == "__main__":
    print(f"characters : {len(CHARACTERS)}")
    print(f"specials   : {len(SPECIALS)}")
    print(f"backgrounds: {len(BACKGROUNDS)}")
    print(f"ui         : {len(UI)}")
    print(f"fx         : {len(FX)}")
    print(f"total      : {len(CULTURAL_DICT)}")
