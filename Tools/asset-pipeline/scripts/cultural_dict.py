"""Biblia cultural de Hobo Evolution: assetKey -> descripcion visual EN INGLES.

Direccion de arte "Cow Evolution": los personajes son FIGURAS COMPLETAS DE PIE
(cuerpo entero, pies apoyados, manos visibles, pose idle con personalidad) que
viven paradas sobre un escenario visible. Los backgrounds son EL CAMPO DE
JUEGO: escena completa con el tercio inferior de piso despejado y transitable
(ahi se paran los personajes) y el paisaje/skyline arriba.

SD no sabe que es un cartonero, un arbolito ni un demonio de ARCA. La
argentinidad se logra describiendo los PROPS visualmente (seccion 5 del asset
doc), nunca escribiendo "argentino" y rezando. El estilo final lo define el
workflow SDXL (DreamShaper XL Turbo + LoRAs de estilo); aca va solo el
CONTENIDO por asset: subject (quien es + pose) / props / ar_cues /
wealth_cues / expression.

Claves = ids reales de tiers.json (36 personajes; el choice node `junior` es
abstracto y no lleva sprite) + specials + backgrounds + ui + fx del checklist
(seccion 8 del asset doc).

Solo stdlib: importable sin instalar nada.
"""

# ---------------------------------------------------------------------------
# PERSONAJES (36) — claves = tiers.json ids. Figura completa DE PIE, pies
# apoyados, manos visibles, pose idle propia de cada personaje, fondo
# transparente (el sufijo de framing lo agrega gen_prompts.py).
# Los props son portables/vestibles o pequenios objetos a sus pies: el
# personaje se recorta y se para sobre el background-playfield.
# ---------------------------------------------------------------------------

CHARACTERS = {
    # ----- EARTH T1-T10 (tanda 1) -----
    "homeless": {
        "subject": "scruffy homeless street man standing hunched forward with a lazy swagger, one knee bent, clutching a bottle against his chest",
        "props": "green glass bottle hugged in both hands, tattered layered coats, fingerless gloves, patched beanie, broken untied sneakers",
        "ar_cues": "Buenos Aires street 'fisura' vibe, disheveled but endearing",
        "wealth_cues": "none, dirty patched clothes",
        "expression": "dazed goofy cross-eyed stare with a crooked grin",
    },
    "cartonero": {
        "subject": "street cardboard collector standing proudly, one fist on his hip, the other hand gripping the handle of his upright two-wheeled cart beside him",
        "props": "tall two-wheeled hand cart piled with flattened cardboard standing at his side, hi-vis reflective vest, worn cap, coil of rope over one shoulder",
        "ar_cues": "urban recycler hustling through the city, streetwise and proud",
        "wealth_cues": "very poor, patched trousers",
        "expression": "determined squint with a tired smile",
    },
    "kiosco": {
        "subject": "kiosk shop attendant standing with a wooden vendor tray strapped over his shoulders, both hands steadying the tray, a sleeping cat curled at his feet",
        "props": "vendor tray crammed with candy, packs of cigarettes and hanging snack strips, simple apron over t-shirt, sleeping cat at his feet",
        "ar_cues": "neighborhood corner kiosk that never closes, now on the go",
        "wealth_cues": "modest, faded apron",
        "expression": "sleepy deadpan stare",
    },
    "repartidor": {
        "subject": "food delivery courier standing with knees slightly bent as if about to sprint, phone gripped in one hand, the other thumb hooked in his backpack strap",
        "props": "oversized generic cube-shaped food-delivery backpack towering over his head (parody, no real brand), scuffed helmet with visor up, cracked phone",
        "ar_cues": "gig-economy courier always racing the clock",
        "wealth_cues": "low income, worn-out sneakers",
        "expression": "stressed wide-eyed hurry",
    },
    "chofer_app": {
        "subject": "rideshare app driver standing relaxed with weight on one leg, politely offering a tiny water bottle in one hand and a lollipop in the other",
        "props": "courtesy mini water bottle and wrapped lollipop held out, car keys clipped to his belt, pine-tree air freshener dangling from his pocket, phone with navigation app in shirt pocket",
        "ar_cues": "chatty rideshare driver proud of his five-star rating",
        "wealth_cues": "working class, tidy polo shirt",
        "expression": "friendly overeager grin",
    },
    "fast_food": {
        "subject": "fast food employee standing with slumped shoulders, holding a greasy spatula like a wilted flag in one hand and a tray of fries in the other",
        "props": "fast-food uniform and crooked paper hat (parody 'McRonald's'), greasy spatula, cardboard tray of fries, name tag",
        "ar_cues": "burger-joint shift that was supposed to be temporary",
        "wealth_cues": "minimum wage, grease-stained uniform",
        "expression": "resigned thousand-yard stare",
    },
    "oficinista": {
        "subject": "tired office clerk standing hunched, sipping from a mate gourd through a metal straw with one hand, a thermos tucked under the other arm",
        "props": "mate gourd with metal bombilla straw, thermos under arm, wrinkled dress shirt, loosened cheap tie, lanyard ID badge, heavy eye bags",
        "ar_cues": "Buenos Aires office worker surviving on mate",
        "wealth_cues": "lower middle class, cheap tie",
        "expression": "exhausted forced smile",
    },
    "administrativo": {
        "subject": "administrative clerk standing stiffly, hugging a wobbling tower of stamped folders with both arms, a rubber stamp balanced on top of the pile",
        "props": "teetering stack of stamped official folders hugged to his chest, rubber stamp, clip-on tie, loose form sheets slipping out, sweater vest over shirt",
        "ar_cues": "endless bureaucracy, everything in triplicate with official seals",
        "wealth_cues": "modest, sweater vest",
        "expression": "bored bureaucratic blank stare",
    },
    "junior_programmer": {
        "subject": "young junior programmer fresh out of university, standing hugging a sticker-covered laptop to his chest with one arm, energy drink can raised in the other hand",
        "props": "laptop covered in stickers hugged to chest, energy drink can, hoodie, rolled diploma with ribbon poking out of his worn backpack",
        "ar_cues": "proud new graduate holding his first job, empty pockets",
        "wealth_cues": "broke graduate, worn backpack",
        "expression": "nervous eager smile",
    },
    "junior_architect": {
        "subject": "young junior architect fresh out of university, standing very upright trying to look professional, rolled blueprints and a rolled diploma tucked under one arm, a small building model balanced on the other palm",
        "props": "rolled blueprints, rolled diploma with ribbon, small building model held on open palm, scale ruler in shirt pocket, thrifted blazer",
        "ar_cues": "proud new graduate at his first studio internship, empty pockets",
        "wealth_cues": "broke graduate, thrifted blazer",
        "expression": "hopeful wide smile",
    },
    "junior_doctor": {
        "subject": "young junior doctor fresh out of medical school, standing swaying half-asleep on his feet, gripping a giant coffee thermos with both hands",
        "props": "oversized white coat, stethoscope around neck, giant coffee thermos held in both hands, rolled diploma with ribbon sticking out of coat pocket, scrubs under the coat",
        "ar_cues": "proud new graduate on a 24-hour hospital shift, empty pockets",
        "wealth_cues": "broke graduate, worn clogs",
        "expression": "sleep-deprived enthusiastic grin",
    },
    "junior_lawyer": {
        "subject": "young junior lawyer fresh out of law school, standing with chest puffed out, hugging a thick law code book with one arm and raising his rolled diploma triumphantly with the other hand",
        "props": "cheap slightly oversized suit, thick law code book under arm, rolled diploma with ribbon held high, bulging folder of case papers wedged in his armpit",
        "ar_cues": "proud new graduate running courthouse errands, empty pockets",
        "wealth_cues": "broke graduate, scuffed dress shoes",
        "expression": "overconfident rookie smirk",
    },
    "senior_programmer": {
        "subject": "veteran senior programmer standing slouched with one hand deep in his hoodie pocket, a coffee-stained mug hooked on a finger of the other hand",
        "props": "worn hoodie over collared shirt, laptop bag slung across chest, coffee-stained mug, rubber duck peeking out of the hoodie pocket, gray-streaked beard, expensive headphones around neck",
        "ar_cues": "grumpy tech lead who has seen every bug in existence",
        "wealth_cues": "comfortable, expensive headphones",
        "expression": "smug all-knowing smirk",
    },
    "senior_architect": {
        "subject": "veteran senior architect standing with feet planted wide as if surveying a construction site, blueprint tube resting over one shoulder, miniature skyscraper model held up in the other hand",
        "props": "white hard hat, long blueprint tube over shoulder, miniature skyscraper model in hand, glasses pushed up on forehead, tailored shirt with rolled sleeves",
        "ar_cues": "seasoned architect bossing around a construction site",
        "wealth_cues": "well-off, tailored shirt",
        "expression": "confident appraising look",
    },
    "senior_doctor": {
        "subject": "veteran senior doctor standing perfectly upright, one hand adjusting the head mirror on his forehead, a framed diploma tucked under the other arm",
        "props": "pristine white coat, head mirror, framed diploma under arm, expensive pen in chest pocket, gold wristwatch",
        "ar_cues": "renowned specialist with a private practice",
        "wealth_cues": "wealthy professional, gold wristwatch",
        "expression": "calm reassuring smile",
    },
    "senior_lawyer": {
        "subject": "veteran senior lawyer standing in a courtroom power stance, one arm thrust forward brandishing a signed contract, leather briefcase gripped in the other hand",
        "props": "sharp pinstripe suit, leather briefcase, thick signed contract held out, gold fountain pen in breast pocket, silk tie",
        "ar_cues": "feared courtroom shark who never loses",
        "wealth_cues": "wealthy professional, silk tie",
        "expression": "predatory confident grin",
    },
    # ----- EARTH T11-T21 (tanda 4) -----
    "director": {
        "subject": "corporate director standing straight-backed, one hand adjusting a shiny cufflink, the other pinching a tiny espresso cup with his pinky raised",
        "props": "tailored suit, tiny espresso cup held pinky-out, shiny cufflinks, small desk name plate tucked under one arm",
        "ar_cues": "middle-management boss who loves calling meetings",
        "wealth_cues": "upper class, shiny cufflinks",
        "expression": "practiced power smile",
    },
    "fundador_startup": {
        "subject": "startup founder standing mid-pitch with both arms spread wide, presenting an invisible world-changing idea",
        "props": "blazer over graphic t-shirt, conference lanyard badge swinging, unicorn coffee mug hooked on one thumb, small pitch-deck cards fanned in the other hand",
        "ar_cues": "buzzword-loving tech founder promising to disrupt everything",
        "wealth_cues": "paper millionaire, designer sneakers",
        "expression": "visionary wide-eyed intensity",
    },
    "dueno_pyme": {
        "subject": "small factory business owner standing solid with feet planted wide, hoisting a heavy ring of keys in one fist, an old calculator gripped in the other hand",
        "props": "shirt with rolled sleeves, big ring of keys held up, chunky old calculator, pencil behind ear, sturdy work boots",
        "ar_cues": "hard-working family business boss who does every job himself",
        "wealth_cues": "solid middle class, sturdy work boots",
        "expression": "proud tired smile",
    },
    "emprendedor": {
        "subject": "hustling serial entrepreneur standing on tiptoes, shouting into a megaphone raised high with one hand, a generic mindset book clutched against his chest with the other",
        "props": "megaphone raised high, generic mindset book, headset microphone, shiny suit, rubber motivational wristbands",
        "ar_cues": "hustle-culture guru selling online courses",
        "wealth_cues": "flashy but leveraged, shiny suit",
        "expression": "over-caffeinated megawatt smile",
    },
    "ceo": {
        "subject": "powerful corporate CEO standing with arms firmly crossed over his chest, chin raised, feet planted like he owns the ground",
        "props": "immaculate dark suit, golden tie, gold watch peeking from crossed arms, smartphone poking out of breast pocket, pocket square",
        "ar_cues": "untouchable big-company boss, board meetings and golf",
        "wealth_cues": "rich, gold watch and pocket square",
        "expression": "cold triumphant smirk",
    },
    "millonario": {
        "subject": "flashy new millionaire standing with legs wide mid-laugh, both arms thrown open, champagne glass raised in one hand",
        "props": "banknotes raining around him, champagne glass held high, fur-collared coat, chunky gold rings on every finger, bills stuffed in every pocket",
        "ar_cues": "new money showing off everything at once",
        "wealth_cues": "millionaire, overflowing pockets",
        "expression": "ecstatic laughing grin",
    },
    "multimillonario": {
        "subject": "extravagant multi-millionaire standing bored with his weight on one leg, presenting an open cash-stuffed briefcase on one flat palm like a waiter's tray, a tiny yacht model dangling from the other hand",
        "props": "open briefcase overflowing with cash held on one palm, small yacht model dangling by its mast, multiple gold chains, diamond tie pin, velvet suit",
        "ar_cues": "tycoon who owns half the city and forgot which half",
        "wealth_cues": "obscene wealth, velvet suit",
        "expression": "bored unimpressed look",
    },
    "rey_ladrillo": {
        "subject": "real-estate mogul king of bricks, standing like a statue holding a single brick aloft in one hand like a trophy, a tower model tucked under the other arm",
        "props": "crown made of little bricks, single brick raised high, apartment tower model under arm, folded blueprints in pocket, brick-red suit",
        "ar_cues": "buys whole city blocks, preaches that bricks never lose value",
        "wealth_cues": "massive property wealth, brick-red suit",
        "expression": "beaming landlord grin",
    },
    "magnate_petrolero": {
        "subject": "classic oil tycoon standing with one foot propped up on an oil barrel, both hands resting on a gold-tipped cane, fat cigar clamped in his grin",
        "props": "black top hat, oil barrel under his boot, gold-tipped cane, fat cigar, oil-drop pattern tie, oil splashes on his suit",
        "ar_cues": "old-school baron striking black gold",
        "wealth_cues": "petro-rich, gold-tipped cane",
        "expression": "greedy delighted grin",
    },
    "space_billionaire": {
        "subject": "eccentric space-obsessed billionaire standing in a heroic launch pose, one arm pointing straight up at the sky, astronaut helmet tucked under the other arm",
        "props": "business suit with a small toy-like jetpack strapped on his back, astronaut helmet under arm, mission patch on chest, platinum watch",
        "ar_cues": "tech billionaire racing his own rockets to space, generic parody of no real person",
        "wealth_cues": "billionaire, platinum watch",
        "expression": "manic visionary grin",
    },
    "trillonario": {
        "subject": "reality-bending trillionaire standing perfectly still and serene, one hand behind his back, the other holding a tiny planet like a stress ball",
        "props": "monocle, banknotes orbiting around him like satellites, tiny planet held in one palm, infinity-pattern suit with glowing golden trim",
        "ar_cues": "wealth beyond countries, buys economies for fun",
        "wealth_cues": "trillions, glowing golden trim",
        "expression": "serene untouchable smile",
    },
    # ----- COSMIC T22-T30 (tanda 4) -----
    "dueno_luna": {
        "subject": "proud new owner of the Moon standing with chest puffed out, one hand gripping a planted flag pole at his side, framed property deed tucked under the other arm",
        "props": "planted flag with his own smiling face printed on it, framed property deed under arm, chunky moon boots, astronaut helmet hooked on his belt, silver-glitter suit",
        "ar_cues": "bought the entire Moon as a real-estate flex",
        "wealth_cues": "lunar landlord, silver-glitter suit",
        "expression": "smug landlord smirk",
    },
    "dueno_marte": {
        "subject": "owner of planet Mars standing mid-wink, one hand resting on a 'sold'-style sign post planted beside him, the other hand holding up a snow globe with a tiny domed city inside",
        "props": "sold-style sign post at his side, snow globe with miniature domed city, spacesuit with a painted-on necktie, copper-red cape, red dust on his boots",
        "ar_cues": "flipping an entire red planet like a fixer-upper",
        "wealth_cues": "interplanetary mogul, copper-red cape",
        "expression": "deal-closing wink",
    },
    "magnate_solar": {
        "subject": "magnate of the entire solar system standing with legs apart, hoisting a miniature glowing sun overhead in one hand like a championship trophy, the other fist on his hip",
        "props": "miniature glowing sun held overhead, small planets orbiting his head, cosmic sunglasses, radiant golden suit",
        "ar_cues": "owns every planet and charges tolls per orbit",
        "wealth_cues": "solar-scale riches, radiant golden suit",
        "expression": "blinding confident smile",
    },
    "senor_galaxia": {
        "subject": "lord of the galaxy standing regally with both hands resting on a tall staff planted in front of him, cape billowing behind",
        "props": "staff topped with a tiny swirling black hole, spiral-galaxy cape, small stars orbiting his crown, constellation-pattern robe",
        "ar_cues": "galactic overlord signing away star systems like paperwork",
        "wealth_cues": "galactic empire, constellation robe",
        "expression": "regal amused stare",
    },
    "emperador_cosmico": {
        "subject": "cosmic emperor standing imperiously with feet planted, scepter struck into the ground beside him, the other hand raised mid-decree",
        "props": "massive jagged crown, scepter topped with a spinning planet, cape made of nebula clouds spread wide, jewel-studded ceremonial robe",
        "ar_cues": "rules space itself and taxes light for passing through",
        "wealth_cues": "cosmic empire, jeweled robe",
        "expression": "imperious raised eyebrow",
    },
    "ser_ascendido": {
        "subject": "ascended being of pure energy standing weightlessly on tiptoe, bare feet barely touching the ground, arms open at his sides with palms up",
        "props": "glowing third eye, body outlined in radiant light, small glowing orbs circling his open hands, faint energy ripples at his feet",
        "ar_cues": "transcended money, now he IS the economy",
        "wealth_cues": "beyond material wealth, luminous aura",
        "expression": "blissful enlightened smile",
    },
    "semidios": {
        "subject": "muscular demigod standing in a heroic contrapposto, flexing one bicep while gripping a lightning bolt raised in the other fist",
        "props": "white toga with golden trim, laurel wreath, lightning bolt gripped in fist, tiny pet storm cloud hovering by his shoulder, golden sandals",
        "ar_cues": "half mortal half divine, still checks his investment portfolio",
        "wealth_cues": "divine treasures, golden sandals",
        "expression": "heroic overconfident grin",
    },
    "deidad": {
        "subject": "radiant multi-armed deity standing perfectly symmetrical and serene, four arms fanned out like a golden statue",
        "props": "four hands holding a coin, a lightning bolt, balance scales and a mate gourd, golden halo disc behind head, ornate jewelry",
        "ar_cues": "worshipped as the god of hustle",
        "wealth_cues": "temples of gold, ornate jewelry",
        "expression": "serene all-knowing smile",
    },
    "god": {
        "subject": "supreme god of everything standing calm and colossal, one open palm holding a tiny spinning universe at chest height, the other hand raising a mate gourd like a toast",
        "props": "enormous white cloud beard flowing down to his feet, all-seeing eye above his head, cosmic halo, tiny spinning universe in one palm, mate gourd with metal straw in the other hand, robe of stars",
        "ar_cues": "the final form: God himself, but he still drinks mate",
        "wealth_cues": "owns existence itself, robe of stars",
        "expression": "warm omnipotent smile",
    },
}

# ---------------------------------------------------------------------------
# SPECIALS (10) — atlas specials, tanda 5. Mismas reglas: figura completa DE
# PIE con pose idle propia.
# ---------------------------------------------------------------------------

SPECIALS = {
    "sp_cryptobro": {
        "subject": "smug crypto bro trader standing with legs apart, thrusting his phone forward to show off a chart with one hand, the other fist clenched in victory",
        "props": "phone showing green candlestick chart held out, flashy oversized watch, sunglasses pushed up on his head, coin-pattern shirt, gold chain over hoodie",
        "ar_cues": "to-the-moon evangelist who never sells at the top",
        "wealth_cues": "volatile riches, gold chain over hoodie",
        "expression": "insufferable smug grin",
    },
    "sp_demonio_arca": {
        "subject": "bureaucratic tax demon standing hunched with bat wings half spread, hugging an armful of tax forms with one arm, a giant red ink stamp raised ready to strike in the other hand",
        "props": "bat wings, small horns, office necktie over shabby suit, armful of tax forms, giant red ink stamp raised high",
        "ar_cues": "tax-collector demon from the underworld revenue service",
        "wealth_cues": "feeds on late fees, shabby office suit",
        "expression": "gleeful sadistic smile",
    },
    "sp_contador_dios": {
        "subject": "divine celestial accountant standing tall and serene, a glowing ledger book open on one flat palm, a feather quill raised in the other hand",
        "props": "glowing ledger book on open palm, feather quill, halo shaped like a calculator, small glowing spreadsheets floating around him, immaculate white suit",
        "ar_cues": "audits the finances of mortals from heaven",
        "wealth_cues": "cosmic order, immaculate white suit",
        "expression": "serene judging stare",
    },
    "sp_zombie_ceo": {
        "subject": "undead zombie CEO standing tilted in a stiff shamble pose, both rigid arms half raised forward, a coffee cup clutched in one stiff hand",
        "props": "torn pinstripe suit, green skin, stitched forehead, dangling loose tie, paper coffee cup clutched in stiff fingers, dusty gold watch",
        "ar_cues": "still attends board meetings from beyond the grave",
        "wealth_cues": "posthumous stock options, dusty gold watch",
        "expression": "vacant hungry stare",
    },
    "sp_lizard": {
        "subject": "reptilian humanoid in a business suit standing unnaturally straight and still, hands folded in front, a half-lifted human face mask held in one clawed hand",
        "props": "green scales, vertical slit pupils, forked tongue flicking out, half-lifted human face mask in one claw, tailored gray suit, obsidian cufflinks",
        "ar_cues": "conspiracy-theory lizard person secretly running world finance",
        "wealth_cues": "shadow-elite wealth, obsidian cufflinks",
        "expression": "unsettling too-wide smile",
    },
    "sp_alien_investor": {
        "subject": "little green alien venture investor standing on short legs, holding up a briefcase overflowing with glowing space currency with both hands",
        "props": "big oval head with antenna, briefcase overflowing with glowing space coins held with both hands, tablet with charts wedged under one arm, tiny silver suit",
        "ar_cues": "intergalactic venture capitalist scouting Earth startups",
        "wealth_cues": "galactic funds, tiny silver suit",
        "expression": "curious calculating stare",
    },
    "sp_bug_simulacion": {
        "subject": "glitched-out simulation error character standing with his body split into offset horizontal slices, one leg misaligned but both feet planted, arms flickering in duplicated positions",
        "props": "body split into offset glitch slices, floating warning signs around him, half-rendered limbs, patches of static noise, flickering outline",
        "ar_cues": "a rendering error of the simulation that became self-aware",
        "wealth_cues": "corrupted data, flickering outline",
        "expression": "confused fragmented face",
    },
    "sp_arbolito": {
        "subject": "street currency dealer standing shifty with knees bent, holding his jacket wide open with one hand to reveal the lining, the other hand cupped beside his mouth mid-whisper",
        "props": "jacket lining fanned with foreign banknotes, small leafy branch with bill-shaped leaves sprouting from his cap, worn windbreaker, wads of cash bulging in pockets",
        "ar_cues": "downtown Buenos Aires street money changer, the human money tree",
        "wealth_cues": "wads of foreign cash, worn windbreaker",
        "expression": "shifty sideways glance",
    },
    "sp_coach": {
        "subject": "over-the-top motivational life coach standing in an exaggerated power stance, one fist pumped to the sky, the other hand pointing straight at the viewer",
        "props": "headset microphone, sparkling white teeth, tight polo shirt, rubber wristbands on both wrists, laminated success-formula card in the pointing hand",
        "ar_cues": "sells success formulas and five-am morning routines",
        "wealth_cues": "seminar money, shiny loafers",
        "expression": "aggressively positive beam",
    },
    "sp_influencer": {
        "subject": "social media influencer standing in a rehearsed pose with one hip cocked, holding a phone on a selfie stick high with one hand, shopping bags hooked on the other forearm",
        "props": "phone on selfie stick, ring light glowing behind her head like a halo, glossy shopping bags on forearm, floating heart and thumbs-up symbols around her",
        "ar_cues": "monetizes every waking second of her life",
        "wealth_cues": "gifted products, designer knockoffs",
        "expression": "practiced duck-face pout",
    },
}

# ---------------------------------------------------------------------------
# BACKGROUNDS (11) — EL CAMPO DE JUEGO (estilo pradera de Cow Evolution).
# Escena completa, canvas entero: tercio INFERIOR = piso despejado y
# transitable (ahi se paran los personajes, SIN objetos en esa zona);
# paisaje/skyline en la parte superior. SIN personajes, SIN texto.
# `expression` se usa como mood/iluminacion de la escena.
# ---------------------------------------------------------------------------

BACKGROUNDS = {
    "bg_alley": {
        "subject": "gritty Buenos Aires dead-end alley game playfield, the bottom third is a wide empty stretch of worn cobblestone ground where characters will stand, all scenery kept above it",
        "props": "graffiti-covered cracked plaster walls, stacks of flattened cardboard leaning against the back wall, dumpster tucked against a side wall, clothesline with rags strung overhead, dripping pipe, lonely street lamp, narrow strip of night sky between rooftops",
        "ar_cues": "porteno back alley where the Fisura sleeps, cardboard everywhere",
        "wealth_cues": "poor neighborhood, cracked plaster and stained walls",
        "expression": "moody but warm, soft street-lamp glow from top-left",
    },
    "bg_urban": {
        "subject": "lively Buenos Aires street corner game playfield, the bottom third is a wide empty gray sidewalk where characters will stand, storefronts and street furniture kept behind and above it",
        "props": "corner kiosk stall with hanging snack strips at one side, bus stop shelter at the other side, tangled power lines overhead, faded posters on walls, obelisk silhouette on the horizon, pigeons perched on the wires",
        "ar_cues": "downtown Buenos Aires energy, kiosks on every corner",
        "wealth_cues": "working-class city, faded posters and worn shutters",
        "expression": "busy daytime cheer, bright noon light",
    },
    "bg_corporate": {
        "subject": "glass corporate district game playfield, the bottom third is a wide empty polished granite plaza where characters will stand, office towers rising behind it",
        "props": "mirrored office towers with grids of lit windows filling the upper area, revolving door entrances at the far edges, small coffee cart tucked to one side, thin strip of morning sky between skyscrapers",
        "ar_cues": "financial district downtown office canyon, ambition in glass and steel",
        "wealth_cues": "corporate polish, blue glass and steel",
        "expression": "cool professional morning light",
    },
    "bg_luxury": {
        "subject": "luxury waterfront promenade game playfield, the bottom third is a wide empty polished stone-and-wood boardwalk where characters will stand, the marina skyline across the water behind it",
        "props": "sleek glass towers and renovated red-brick dock warehouses across the water, elegant white harp-shaped pedestrian bridge, gleaming yacht moored at the dock, golden street lamps, calm reflective water",
        "ar_cues": "Puerto Madero new-money waterfront, old docks turned millionaire mile",
        "wealth_cues": "opulent marina, gold-lit towers",
        "expression": "glamorous warm sunset glow",
    },
    "bg_island": {
        "subject": "private tropical island game playfield, the bottom third is a wide empty stretch of pristine white sand where characters will stand, sea and palms behind it",
        "props": "leaning palm trees framing the sides, beach cabana at one edge, turquoise water, luxury yacht anchored offshore, distant green islet, a few puffy clouds",
        "ar_cues": "billionaire hideaway island, paradise with a deed",
        "wealth_cues": "owning paradise itself",
        "expression": "sunny vacation bliss",
    },
    "bg_moon": {
        "subject": "lunar surface game playfield, the bottom third is a smooth empty stretch of gray moon dust where characters will stand, craters and structures kept in the distance behind it",
        "props": "cratered gray hills in the midground, several planted flags in the distance, small glass dome habitat on the horizon, Earth rising big and blue in a black star-filled sky",
        "ar_cues": "the Moon turned into private property",
        "wealth_cues": "lunar real estate development",
        "expression": "serene cosmic quiet, cool earthlight",
    },
    "bg_mars": {
        "subject": "red martian desert game playfield, the bottom third is a flat empty plain of red dust where characters will stand, dunes and mesas rising behind it",
        "props": "red dunes and rocky mesas in the midground, cluster of terraforming domes on the horizon, two small moons in a pink sky, distant dust devil",
        "ar_cues": "Mars in the middle of a real-estate development boom",
        "wealth_cues": "planetary-scale investment",
        "expression": "warm alien dusk",
    },
    "bg_solar": {
        "subject": "solar system panorama game playfield, the bottom third is a smooth glowing golden orbit-ring platform forming an empty floor where characters will stand, the system spread across the sky above",
        "props": "giant stylized sun low on the horizon, planets aligned along glowing orbit arcs in the sky, asteroid belt sweeping across, tiny toll gates on the distant orbit lines",
        "ar_cues": "the whole solar system managed like a portfolio",
        "wealth_cues": "star-scale assets",
        "expression": "radiant cosmic grandeur",
    },
    "bg_galaxy": {
        "subject": "spiral galaxy panorama game playfield, the bottom third is a smooth empty plain of compacted stardust forming a floor where characters will stand, the galaxy filling the sky above",
        "props": "huge swirling spiral arms of stars overhead, colorful nebulas, dense star clusters, tiny constellations drawn with thin lines",
        "ar_cues": "a galaxy under new management",
        "wealth_cues": "galactic scale property",
        "expression": "deep space majesty",
    },
    "bg_cosmic": {
        "subject": "abstract cosmic realm game playfield, the bottom third is the flat empty top of a huge floating rock plateau where characters will stand, surreal space scenery around and above it",
        "props": "smaller floating rock islands drifting in the distance, aurora ribbons weaving across the sky, geometric glowing portals, rivers of stars flowing between the islands",
        "ar_cues": "space itself bending to wealth",
        "wealth_cues": "reality-scale power",
        "expression": "surreal cosmic wonder",
    },
    "bg_god_realm": {
        "subject": "divine heavenly realm game playfield, the bottom third is a solid flat floor of dense golden clouds forming an empty walkable surface where characters will stand, celestial architecture behind it",
        "props": "sea of golden clouds, tall golden gates in the far center, white marble columns at the sides, god rays beaming from above, golden coins floating high up like stars",
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
