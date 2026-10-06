# Biblia de visitantes — FisuEvolution 2.0

Los personajes que entran a escena en la 2.0, con su descriptor canónico y su imagen de
referencia. Sirve para que el Comisario del globo, el del popup, el del chip y el del loop
animado sean **el mismo**, aunque salgan de prompts, motores y meses distintos.

Sigue la metodología de `content-urbe/design-system/biblia/personajes.md`: una fila por
personaje, un descriptor en inglés para pegar tal cual en el prompt, una referencia canónica, y
las variantes salen de esa canónica con **un solo cambio**. El contenido sale de
`Docs/PLAN-v2.md`: E8, §5, Anexo A (qué hace cada uno en escena) y Anexo B (los 8 nuevos).

Los prompts viven en `~/Desktop/projects/automatic-image-generation/projects/fisu-evolution-v2/`
(222 en total, el orden en `prompts/00_INDICE.md`). **Si cambia un descriptor acá, cambia en
sus prompts, y al revés.**

## Reglas de uso

1. **Antes de generar** a un personaje de esta biblia, adjuntá su referencia canónica, escribí
   "the SAME character as the attached reference" y pegá su descriptor.
2. **Una pose o una cara nueva es una variante**: sale de la canónica y cambia una sola cosa (la
   pose, o el encuadre). Se registra acá con ID `char_fisu_<nombre>_<estado>_vN`.
3. **Sólo arquetipos.** Ni personas reales, ni marcas, ni insignias reales: ni de policía, ni de
   partidos, ni de gremios, ni de organismos. Las caras son genéricas e inventadas.
4. **Sin texto en la imagen.** Carteles, papeles, bolsas, pantallas y banderas van en blanco.
   El texto lo pone el juego, que tiene es + en.
5. **Nada de armas.** El gaucho de la familia de skins va sin facón ni rebenque.
6. **En los prompts, el Demonio de ARCA se llama "the Tax Demon"**, sin el nombre del organismo,
   para que el modelo no lo escriba en los formularios. El nombre del juego no cambia
   (decisión del dueño, PLAN-v2 §2 "Nombres").

## Estilo maestro

- **Referencia de estilo:** `Tools/asset-pipeline/heroes/approved/fisura.png`. En el proyecto
  generador es `references/fisura.png`.
- **Prompts en ASCII puro.**
- **Apertura fija** de todo prompt de personaje (Anexo B):

  ```
  Match EXACTLY the art style, line weight, proportions and color treatment of the attached reference character - same game, same studio.
  ```

- **Cierre fijo** de todo cuerpo entero (canónica, hablando, acción y skins):

  ```
  Full body standing character, both feet planted on the ground, hands visible, generous margins, centered on a plain pure white background, square image, no text, no watermark, no cropping.
  ```

- **Cierre de las caras.** No usan el de cuerpo entero, que contradice un primer plano: usan el
  de las 43 caras de la v1.

  ```
  Head and shoulders only, face centered and filling most of the frame, no hands, nothing below the chest, on a plain pure white background, square image, no text, no watermark, do not crop the top of the head.
  ```

- **Canónica de un visitante nuevo:** adjunta `fisura.png` y aclara que la imagen es **sólo
  guía de estilo** ("draw a brand-new character, not the one in the image"). Sin esa línea,
  ChatGPT tiende a disfrazar al Fisura en vez de dibujar a otro.

## Dónde aparece un visitante (vale para los 18)

| Pieza | Dónde |
|---|---|
| Canónica | Entra y sale de escena (`VisitorNode`, E4). Es el cuadro inicial del loop de retrato de Higgsfield (Kling, E8). |
| Hablando | En escena, mientras está el globo (`SpeechBubbleNode`). El globo lo dibuja el juego: la pose deja aire arriba de la cabeza. |
| Acción | En escena, cuando se concreta la oferta o el evento. |
| Cara | `StageChips`, el chip del evento que presenta (`ActiveBonus.Icon.face`) y el Álbum de especiales. |

## Los 8 visitantes nuevos

Todavía no tienen arte. La **referencia canónica** es lo que genere su primer prompt, en
`output/npc_<nombre>.png` del proyecto generador. Cuando se integre, queda en
`Tools/asset-pipeline/dropbox/procesadas/`.

| ID | Quién es | Referencia canónica | Descriptor (EN, para pegar en el prompt) | Paleta | Poses (canónica · hablando · acción · cara) | Dónde aparece (Anexo A) |
|---|---|---|---|---|---|---|
| `char_fisu_npc_comisario_v1` | El comisario del barrio. Demora empleados por motivos absurdos y multa por "exceso de productividad". El arresto siempre indemniza. | `output/npc_comisario.png` (prompt 001, piloto) | a heavyset middle-aged police chief with a thick bushy mustache and a double chin, navy peaked cap with a plain gold badge shape (no emblem, no letters), whistle on a cord around the neck, small ticket booklet and pen, generic navy uniform with brass buttons and no real insignia, patches or flags, belly straining the belt, black shoes | azul marino, dorado, crema | pulgares en el cinturón, talonario bajo el brazo · dedo levantado · anota la multa · ojos entrecerrados de sospecha, bigote erizado | Guiones *arresto* y *multa*. Cinemática de arresto (Higgsfield). |
| `char_fisu_npc_sindicalista_v1` | Delegado gremial. Cierra la paritaria de tus muchachos y trae asado y un paquete. | `output/npc_sindicalista.png` | a stocky union organizer with a thick neck, a short dark beard and a cloth headband tied around the forehead, padded sleeveless work vest over a plain T-shirt, jeans and work boots, carrying a megaphone and a plain blank banner on a pole with no logo and no lettering | rojo ladrillo, gris, amarillo | megáfono al hombro, pancarta en blanco · grita al megáfono · puño en alto · grita con una vena en la frente | Guiones *aumento* y *asado*. Eventos Aguinaldo, Feriado Puente y Paro General. |
| `char_fisu_npc_turista_v1` | Turista al que todo le parece barato. Paga cash por tu mejor empleado y deja propinas. | `output/npc_turista.png` | a tall lanky sunburned tourist with pink cheeks and a peeling nose, wide straw sun hat, loud tropical print shirt, khaki shorts, white socks pulled up under sandals, a camera hanging around the neck, a fanny pack and a folding paper map with no readable text | turquesa, beige, rojo | mapa abierto en las dos manos · señala el mapa · saca la foto · asombro con ojos brillantes | Guiones *compra* y *propina*. |
| `char_fisu_npc_puntero_v1` | Puntero del barrio. Se lleva tres muchachos para un acto y deja un bolsón. | `output/npc_puntero.png` | a burly neighborhood political fixer with slicked-back hair, a thin mustache and a wide friendly grin, sleeveless puffer vest over a plain polo shirt, a plain violet armband with no symbols and no letters, a chunky gold ring, carrying a big reusable grocery bag stuffed with food packages that have no brand labels | violeta, verde oliva, gris | bolsón en una mano, pulgar arriba · palmada (guiño) · entrega el bolsón · sonrisa cómplice con guiño | Guiones *acto* y *bolsón*. Evento Lluvia de Paquetes. |
| `char_fisu_npc_ministro_v1` | Ministro de Economía genérico: no se parece a ninguno real. Reparte subsidios y anuncia casi todos los eventos económicos. | `output/npc_ministro.png` | a thin nervous economy minister with thick round glasses, a comb-over and drops of sweat on the forehead, rumpled gray suit with a blue tie, a leather briefcase and a chart board showing a big downward arrow over abstract bars with no numbers and no text | gris, azul, verde billete | sonrisa tranquilizadora forzada, maletín y gráfico · señala el gráfico · tacha números (garabatos sin cifras) · sonrisa nerviosa, sudor, un ojo que tiembla | Guion *subsidio*. Eventos Plan Platita, Devaluación, Blanqueo, Corralito, Hiperinflación y Cepo Cambiario. |
| `char_fisu_npc_vecina_v1` | La vecina chusma que ve todo desde el balcón. Te adelanta el próximo evento y te pide ayuda con las bolsas. | `output/npc_vecina.png` (prompt 002, piloto) | a short plump middle-aged nosy neighbor with pink hair curlers under a hairnet, cat-eye glasses on a chain, a floral house dress with an apron, fluffy slippers, holding a straw broom | rosa, celeste, lila | apoyada en la escoba, mano en la cadera · cuchichea · mira con prismáticos · ojos de costado, labios fruncidos | Guiones *chisme* y *favor*. Eventos Apagón, Piquete en la autopista y Ola de Calor. |
| `char_fisu_npc_vendedor_v1` | Vendedor ambulante. Pasa cada ~3 min de juego activo ofreciendo boosts por video (Mate, Café, Turbo). | `output/npc_vendedor.png` | a wiry energetic street vendor with a big toothy grin and a backwards cap, an enormous overstuffed backpack, a tray hanging from a strap around his neck loaded with mate gourds, rolled socks and small gadgets with no brand labels, a long open coat and a whistle | naranja, marrón, verde | bandeja adelante, mano en alto llamando · ofrece un mate · abre el abrigo lleno de cosas (sin billetes, para no pisarse con El del Arbolito) · sonrisa de vendedor a los gritos | Guion *ofertas*. Eventos Se cayó el home banking y Liquidación Total. |
| `char_fisu_npc_conductor_v1` | Conductor de un programa de juegos. Presenta la Ruleta y regala un giro por día. | `output/npc_conductor.png` | a flashy TV game-show host with a perfect swoosh of shiny hair, an enormous bright white smile and a spray tan, a shiny sequined jacket over a black shirt, a bow tie, holding a handheld microphone | magenta, dorado, celeste | micrófono al mentón, mano en la cadera · brazos abiertos · gira una ruleta imaginaria · sonrisa con destello en los dientes | Guion *ruleta* (la presenta, E5). Eventos Startup comprada y ¡Salimos campeones! |

## Los 10 especiales existentes

Ya tienen canónica: la de la v1. Esa pose hace de **acción**, y la 2.0 les suma **hablando** y
**cara**. La referencia del proyecto generador es una copia de
`Tools/asset-pipeline/dropbox/procesadas/sp_<id>.png`, el original que se integró. En el juego
están en `specials.atlas/sp_<id>@3x.png`.

⚠️ El `sp_influencer.png` de `automatic-image-generation/projects/fisu-evolution/output/` **no es
el del juego**: es una versión vieja de buzo gris con marcas de moda reales en las bolsas. El del
juego es el de buzo rosa, sin marcas, y es el que se usa.

Algunas canónicas de la v1 tienen texto dibujado: el Demonio, en los formularios; el Bug, en los
carteles de error; el Coach, en la chomba. Los prompts nuevos piden esas superficies en blanco.

| ID | Quién es | Referencia canónica | Descriptor (EN, para pegar en el prompt) | Paleta | Poses (canónica · hablando · cara) | Dónde aparece (Anexo A) |
|---|---|---|---|---|---|---|
| `char_fisu_sp_cryptobro_v1` | Crypto Bro. Especial de fusión desde el tier 5, con ingresos ×1,03. | `references/chars/sp_cryptobro.png` | a smug crypto bro trader with sunglasses pushed up on his head, a short beard, an orange hoodie under a coin-pattern shirt, a gold chain, a flashy oversized watch and a phone showing a green candlestick chart | naranja, dorado, azul jean | la de la v1 (celular con el gráfico, puño en alto) · se inclina y te pasa el dato con la mano en la boca · sonrisa sobradora, una ceja arriba | Guion *señal*. |
| `char_fisu_sp_demonio_arca_v1` | Demonio de ARCA. Especial desde el tier 8, con contratar −5 %. | `references/chars/sp_demonio_arca.png` | a bureaucratic tax demon with small curved horns, bat wings, a shabby office suit with a loosened red necktie, an armful of tax forms and a giant red ink stamp | gris carbón, rojo, negro | la de la v1 (sello en alto, formularios) · extiende un formulario en blanco y lo golpea con el sello · sonrisa sádica con todos los dientes | Guiones *paraíso fiscal* (arresto de tu tier alto) y *factura*. |
| `char_fisu_sp_contador_dios_v1` | Contador de Dios. Especial desde el tier 9 con prestigio 5, con ingresos ×1,10. | `references/chars/sp_contador_dios.png` | a divine celestial accountant in an immaculate white suit, a halo shaped like a calculator, a glowing ledger book on one palm, a feather quill and small glowing spreadsheets floating around him | blanco, dorado, crema | la de la v1 (libro abierto, pluma) · te muestra el libro y señala un renglón con la pluma · mirada serena que juzga, ceja arriba | Guion *crédito*. |
| `char_fisu_sp_zombie_ceo_v1` | Zombie CEO. Especial desde el tier 15, con offline +5 %. | `references/chars/sp_zombie_ceo.png` | an undead zombie CEO with green skin and a stitched forehead, a torn pinstripe suit, a dangling loose tie, a dusty gold watch and a paper coffee cup in one stiff hand | verde, gris a rayas, bordó | la de la v1 (arrastra los pies, café) · brazo rígido con el índice arriba, como en el directorio · mirada vacía y hambrienta, mandíbula colgando | Guion *reto* (40 toques). |
| `char_fisu_sp_lizard_v1` | Lizard. Especial desde el tier 17, con crítico +2 %. | `references/chars/sp_lizard.png` | a reptilian humanoid with green scales, vertical slit pupils and a forked tongue, a tailored dark gray suit with a black tie and a half-lifted human face mask held in one clawed hand | verde, gris oscuro, negro | la de la v1 (máscara a medio levantar) · manos en punta, máscara bajo el brazo, lengua afuera · sonrisa demasiado ancha con la lengua bífida (cara de lagarto, sin máscara) | Guion *lengua*. |
| `char_fisu_sp_alien_investor_v1` | Alien Investor. Especial desde el tier 22, con ingresos ×1,05. | `references/chars/sp_alien_investor.png` | a little green alien venture investor with a big oval head, a single antenna and huge dark eyes, a tiny silver suit, a briefcase overflowing with glowing space coins and a tablet with charts | verde, plateado, cian | la de la v1 (valija de monedas) · saluda con una mano, valija en la otra · mirada calculadora, un ojo entrecerrado | Guion *inversión*. Evento Inversión Alienígena. |
| `char_fisu_sp_bug_simulacion_v1` | Bug de la Simulación. Especial desde el tier 21 con prestigio 8, con crítico +5 %. | `references/chars/sp_bug_simulacion.png` | a glitched-out simulation error character whose body is split into offset horizontal slices, with half-rendered limbs, patches of static noise, a flickering cyan and magenta outline and small floating warning signs around him | marrón y verde del Fisura, cian y magenta del glitch, amarillo de los carteles | la de la v1 (cuerpo en rebanadas) · mano en alto explicando, boca y mano duplicadas por el glitch · cara fragmentada, cada rebanada con otra expresión | Guion *reinicio*. |
| `char_fisu_sp_arbolito_v1` | El del Arbolito. Especial desde el tier 6 con prestigio 3, con contratar −5 %. | `references/chars/sp_arbolito.png` | a downtown street currency dealer in a worn windbreaker and a worn cap with a small leafy branch sprouting bill-shaped leaves, the jacket lining fanned with banknotes and wads of cash bulging in the pockets | marrón, verde billete, azul gastado | la de la v1 (campera abierta, cuchicheo) · grita "cambio" con la mano en la boca, abanica billetes · mirada de reojo, labios de costado | Guiones *cambio* y *blue* (sólo en el Cepo). |
| `char_fisu_sp_coach_v1` | Coach Ontológico. Especial desde el tier 4, con ingresos ×1,02. | `references/chars/sp_coach.png` | an over-the-top motivational life coach with a dark beanie, a headset microphone, sparkling white teeth, a tight maroon polo shirt, rubber wristbands and a laminated success-formula card | bordó, negro, azul oscuro | la de la v1 (puño arriba, tarjeta) · brazos abiertos como en el escenario de un seminario · sonrisa agresivamente positiva | Guion *reto* (60 toques). |
| `char_fisu_sp_influencer_v1` | Influencer. Especial desde el tier 3, con ingresos ×1,02. | `references/chars/sp_influencer.png` (la del juego, de buzo rosa) | a social media influencer with long wavy blonde hair, big gold hoop earrings and a pink cropped tracksuit, a phone on a selfie stick, unbranded shopping bags hooked on one arm, a ring light glowing behind her head like a halo and floating heart and thumbs-up symbols around her | rosa, rubio, dorado | la de la v1 (selfie con el palo) · le habla al celular y tira un beso · trompita ensayada, un ojo entornado | Guiones *novio* y *código*. |

## Estados registrados

Cada estado es una variante de la canónica con un solo cambio. La clave es el nombre del PNG en
el proyecto generador.

| Estado | ID | Clave del prompt | Cambio único |
|---|---|---|---|
| Hablando | `char_fisu_<nombre>_habla_v1` | `npc_<nombre>_talk` · `sp_<id>_talk` | la pose: boca abierta a mitad de frase, aire arriba para el globo |
| Acción (sólo los nuevos) | `char_fisu_npc_<nombre>_accion_v1` | `npc_<nombre>_action` | la pose: la acción de su guion |
| Cara | `char_fisu_<nombre>_cara_v1` | `npc_<nombre>_face` · `sp_<id>_face` | el encuadre: cabeza y hombros, gesto exagerado para leerse en un círculo chico |

Las 18 caras y las 18 canónicas alimentan los **18 loops de retrato** de Higgsfield (E8): cuadro
inicial = cuadro final = canónica.

## Familias de skins (las mismas reglas, aplicadas a los 43)

Cada skin de familia es **el mismo personaje con otra ropa**. Se conservan la cara, el pelo
visible, la pose, la expresión, todo lo que tiene en las manos o a los pies, y los rasgos que no
son ropa: aureola, brillo, alas, cuernos, brazos de más. Cambia **sólo la ropa**, y el diseño
del disfraz es el mismo para los 43, así la familia se lee como un juego. Cada prompt adjunta el
PNG original de SU personaje, nunca el del Fisura. La clave es `<tipo>__<familia>`.

| Familia | Clave | Descriptor del disfraz (EN, para pegar) | Paleta |
|---|---|---|---|
| Pijama de Ositos | `__pijama` | a cozy two-piece flannel pajama set in pastel sky blue printed all over with small brown teddy bear faces, with a cream collar and cream cuffs, a matching floppy nightcap with a fluffy pom-pom on the head (it replaces any hat), and fuzzy brown slippers shaped like bear paws on the feet | celeste pastel, marrón osito, crema |
| Gaucho | `__gaucho` | a traditional Argentine gaucho outfit, made of a black boina beret on the head (it replaces any hat), a woven poncho in deep red with thin black and white geometric stripes draped over the shoulders, a white shirt with a black neckerchief knotted at the throat, a wide brown leather belt decorated with plain round silver discs (no engravings), loose pleated light gray bombacha trousers and soft brown leather boots. No knife, no whip and no weapon of any kind | rojo punzó, negro, blanco, cuero, plata |
| Disfraz de Dinosaurio | `__dinosaurio` | a full-body plush dinosaur costume onesie in bright green with a pale yellow belly panel, a big hood shaped like a friendly cartoon dinosaur head with rounded white felt teeth along its rim, worn so that the character's whole face stays fully visible inside the open mouth of the hood (it replaces any hat), a row of soft orange spikes running from the top of the hood down the back, a chunky stuffed tail resting on the ground behind, and plush three-toed dinosaur feet | verde, amarillo pálido, naranja |

Casos con nota propia en su prompt:

- **Rentista de Soles × Pijama**: ya usa pijama a rayas y bata, así que el disfraz los reemplaza
  del todo.
- **Estanciero Estelar × Gaucho**: ya es medio gaucho. Pierde el sombrero de ala ancha por la
  boina y suma el poncho rojo.
- **Estanciero Estelar** (las tres familias): su original trae el alambrado estrellado de fondo,
  y el prompt pide no dibujarlo.
- **Deidad** (las tres familias): tiene cuatro brazos, así que el disfraz lleva cuatro mangas.
- **Programador Jr.**: no quedó el original sin recortar, y su referencia es el `@3x` del atlas
  aplanado sobre blanco (512 px). Sus stickers con logos reales se piden en blanco, como en todas
  las skins.

## Identidad nueva

Un visitante que no está en esta biblia se agrega con una fila nueva:

1. Escribí el descriptor en inglés ASCII: aspecto, ropa y utilería, sin pose.
2. Generá la canónica adjuntando `fisura.png` sólo como guía de estilo.
3. Registralo acá con ID `char_fisu_<nombre>_v1`, y después sus estados.
