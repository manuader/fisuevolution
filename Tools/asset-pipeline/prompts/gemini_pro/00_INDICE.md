# Índice de generación — Gemini Pro

Orden secuencial para generar los assets de FisuEvolution con Gemini Pro (chat con imagen).
Cada fila corresponde a un archivo `NN_assetKey.md` en esta carpeta. El `estado` pasa a
`hecho` cuando la imagen se aprueba y se copia a `Tools/asset-pipeline/dropbox/`: el runner
lo reescribe solo, recién después de verificar el PNG de destino.

**El runner lee la carpeta, no esta tabla** (`gemini_selenium_runner.py` glob-ea
`[0-9][0-9]*.md` y saltea los que ya están en `hecho`). La tabla es para ver el estado de un
vistazo.

| Tanda | NN | Qué | Cuántos |
|---|---|---|---|
| Original | 01–93 | 36 personajes + 10 specials + 11 fondos + 30 UI + logo + 5 fx | 93 |
| UI y tutorial | 94–120 | paneles, botones, íconos y las 4 poses del Fisura del tutorial | 27 |
| Skins ganables | 121–156 | una skin por personaje | 36 |
| ORO | 157 | ícono de la moneda de prestigio | 1 |
| **RF-10 · RF-05 · RF-13** | **158–209** | **7 personajes nuevos + 43 caras + 2 skins pagas** | **52** |

La tanda 158–209 sale de `Docs/superpowers/specs/2026-08-06-siete-personajes-y-remapeo.md`.
Dos cosas que hay que respetar al correrla:

- **Con `--process`**: las caras de los 7 personajes nuevos adjuntan como referencia el
  `dropbox/procesadas/<id>.png` de su propio cuerpo, que no existe hasta que ese cuerpo se
  generó *y* se procesó. Por eso los siete cuerpos van primero en la numeración.
- **Con `--ref-threshold 5`** para el tramo de caras y de skins: ahí la referencia adjunta es
  el **mismo** personaje que se está generando, y el umbral de fábrica (12, calibrado para
  cuando la referencia era otro personaje) puede descartar imágenes buenas.

| NN | asset | archivo | estado |
|---|---|---|---|
| 01 | homeless | `homeless.png` | hecho |
| 02 | cartonero | `cartonero.png` | hecho |
| 03 | kiosco | `kiosco.png` | hecho |
| 04 | repartidor | `repartidor.png` | hecho |
| 05 | chofer_app | `chofer_app.png` | hecho |
| 06 | fast_food | `fast_food.png` | hecho |
| 07 | oficinista | `oficinista.png` | hecho |
| 08 | administrativo | `administrativo.png` | hecho |
| 09 | junior_programmer | `junior_programmer.png` | hecho |
| 10 | junior_architect | `junior_architect.png` | hecho |
| 11 | junior_doctor | `junior_doctor.png` | hecho |
| 12 | junior_lawyer | `junior_lawyer.png` | hecho |
| 13 | senior_programmer | `senior_programmer.png` | hecho |
| 14 | senior_architect | `senior_architect.png` | hecho |
| 15 | senior_doctor | `senior_doctor.png` | hecho |
| 16 | senior_lawyer | `senior_lawyer.png` | hecho |
| 17 | director | `director.png` | hecho |
| 18 | fundador_startup | `fundador_startup.png` | hecho |
| 19 | dueno_pyme | `dueno_pyme.png` | hecho |
| 20 | emprendedor | `emprendedor.png` | hecho |
| 21 | ceo | `ceo.png` | hecho |
| 22 | millonario | `millonario.png` | hecho |
| 23 | multimillonario | `multimillonario.png` | hecho |
| 24 | rey_ladrillo | `rey_ladrillo.png` | hecho |
| 25 | magnate_petrolero | `magnate_petrolero.png` | hecho |
| 26 | space_billionaire | `space_billionaire.png` | hecho |
| 27 | trillonario | `trillonario.png` | hecho |
| 28 | dueno_luna | `dueno_luna.png` | hecho |
| 29 | dueno_marte | `dueno_marte.png` | hecho |
| 30 | magnate_solar | `magnate_solar.png` | hecho |
| 31 | senor_galaxia | `senor_galaxia.png` | hecho |
| 32 | emperador_cosmico | `emperador_cosmico.png` | hecho |
| 33 | ser_ascendido | `ser_ascendido.png` | hecho |
| 34 | semidios | `semidios.png` | hecho |
| 35 | deidad | `deidad.png` | hecho |
| 36 | god | `god.png` | hecho |
| 37 | sp_cryptobro | `sp_cryptobro.png` | hecho |
| 38 | sp_demonio_arca | `sp_demonio_arca.png` | hecho |
| 39 | sp_contador_dios | `sp_contador_dios.png` | hecho |
| 40 | sp_zombie_ceo | `sp_zombie_ceo.png` | hecho |
| 41 | sp_lizard | `sp_lizard.png` | hecho |
| 42 | sp_alien_investor | `sp_alien_investor.png` | hecho |
| 43 | sp_bug_simulacion | `sp_bug_simulacion.png` | hecho |
| 44 | sp_arbolito | `sp_arbolito.png` | hecho |
| 45 | sp_coach | `sp_coach.png` | hecho |
| 46 | sp_influencer | `sp_influencer.png` | hecho |
| 47 | bg_alley | `bg_alley.png` | hecho |
| 48 | bg_urban | `bg_urban.png` | hecho |
| 49 | bg_corporate | `bg_corporate.png` | hecho |
| 50 | bg_luxury | `bg_luxury.png` | hecho |
| 51 | bg_island | `bg_island.png` | hecho |
| 52 | bg_moon | `bg_moon.png` | hecho |
| 53 | bg_mars | `bg_mars.png` | hecho |
| 54 | bg_solar | `bg_solar.png` | hecho |
| 55 | bg_galaxy | `bg_galaxy.png` | hecho |
| 56 | bg_cosmic | `bg_cosmic.png` | hecho |
| 57 | bg_god_realm | `bg_god_realm.png` | hecho |
| 58 | ui_btn_primary | `ui_btn_primary.png` | hecho |
| 59 | ui_btn_secondary | `ui_btn_secondary.png` | hecho |
| 60 | ui_btn_danger | `ui_btn_danger.png` | hecho |
| 61 | ui_btn_disabled | `ui_btn_disabled.png` | hecho |
| 62 | ui_btn_store | `ui_btn_store.png` | hecho |
| 63 | ui_btn_upgrade | `ui_btn_upgrade.png` | hecho |
| 64 | ui_btn_reincarnate | `ui_btn_reincarnate.png` | hecho |
| 65 | ui_btn_watch_ad | `ui_btn_watch_ad.png` | hecho |
| 66 | ui_btn_claim | `ui_btn_claim.png` | hecho |
| 67 | ui_btn_collect | `ui_btn_collect.png` | hecho |
| 68 | ui_coin | `ui_coin.png` | hecho |
| 69 | ui_money | `ui_money.png` | hecho |
| 70 | ui_dollar | `ui_dollar.png` | hecho |
| 71 | ui_million | `ui_million.png` | hecho |
| 72 | ui_billion | `ui_billion.png` | hecho |
| 73 | ui_trillion | `ui_trillion.png` | hecho |
| 74 | ui_infinity | `ui_infinity.png` | hecho |
| 75 | ui_up_income | `ui_up_income.png` | hecho |
| 76 | ui_up_spawn | `ui_up_spawn.png` | hecho |
| 77 | ui_up_offline | `ui_up_offline.png` | hecho |
| 78 | ui_up_tap | `ui_up_tap.png` | hecho |
| 79 | ui_up_crit | `ui_up_crit.png` | hecho |
| 80 | ui_up_golden | `ui_up_golden.png` | hecho |
| 81 | ui_up_prestige | `ui_up_prestige.png` | hecho |
| 82 | ui_boost_mate | `ui_boost_mate.png` | hecho |
| 83 | ui_boost_cafe | `ui_boost_cafe.png` | hecho |
| 84 | ui_boost_fernet | `ui_boost_fernet.png` | hecho |
| 85 | ui_boost_milanesa | `ui_boost_milanesa.png` | hecho |
| 86 | ui_boost_asado | `ui_boost_asado.png` | hecho |
| 87 | ui_boost_turbo | `ui_boost_turbo.png` | hecho |
| 88 | logo | `logo.png` | hecho |
| 89 | fx_merge | `fx_merge.png` | hecho |
| 90 | fx_money | `fx_money.png` | hecho |
| 91 | fx_tap | `fx_tap.png` | hecho |
| 92 | fx_unlock | `fx_unlock.png` | hecho |
| 93 | fx_evolution_flash | `fx_evolution_flash.png` | hecho |
| 94 | panel_store | `panel_store.png` | hecho |
| 95 | panel_upgrades | `panel_upgrades.png` | hecho |
| 96 | panel_prestige | `panel_prestige.png` | hecho |
| 97 | panel_config | `panel_config.png` | hecho |
| 98 | panel_career | `panel_career.png` | hecho |
| 99 | panel_reward | `panel_reward.png` | hecho |
| 100 | panel_dialog | `panel_dialog.png` | hecho |
| 101 | panel_tutorial | `panel_tutorial.png` | hecho |
| 102 | ui_btn_close | `ui_btn_close.png` | hecho |
| 103 | ui_btn_back | `ui_btn_back.png` | hecho |
| 104 | ui_btn_settings | `ui_btn_settings.png` | hecho |
| 105 | ui_btn_buy | `ui_btn_buy.png` | hecho |
| 106 | ui_toggle_on | `ui_toggle_on.png` | hecho |
| 107 | ui_toggle_off | `ui_toggle_off.png` | hecho |
| 108 | ui_tab_active | `ui_tab_active.png` | hecho |
| 109 | ui_tab_inactive | `ui_tab_inactive.png` | hecho |
| 110 | ui_slot_upgrade | `ui_slot_upgrade.png` | hecho |
| 111 | ui_slot_store | `ui_slot_store.png` | hecho |
| 112 | ui_header_ribbon | `ui_header_ribbon.png` | hecho |
| 113 | ui_pill_currency | `ui_pill_currency.png` | hecho |
| 114 | ui_progress_bar | `ui_progress_bar.png` | hecho |
| 115 | ui_badge | `ui_badge.png` | hecho |
| 116 | ui_speech_bubble | `ui_speech_bubble.png` | hecho |
| 117 | fisura_point | `fisura_point.png` | hecho |
| 118 | fisura_explain | `fisura_explain.png` | hecho |
| 119 | fisura_celebrate | `fisura_celebrate.png` | hecho |
| 120 | fisura_wave | `fisura_wave.png` | hecho |
| 121 | homeless__second_life | `homeless__second_life.png` | hecho |
| 122 | cartonero__urban_trailblazer | `cartonero__urban_trailblazer.png` | hecho |
| 123 | kiosco__nocturno | `kiosco__nocturno.png` | hecho |
| 124 | repartidor__cohete | `repartidor__cohete.png` | hecho |
| 125 | chofer_app__taxi_clasico | `chofer_app__taxi_clasico.png` | hecho |
| 126 | fast_food__chef_estrella | `fast_food__chef_estrella.png` | hecho |
| 127 | oficinista__home_office | `oficinista__home_office.png` | hecho |
| 128 | administrativo__sindicalista | `administrativo__sindicalista.png` | hecho |
| 129 | junior_programmer__hacker | `junior_programmer__hacker.png` | hecho |
| 130 | junior_architect__obra | `junior_architect__obra.png` | hecho |
| 131 | junior_doctor__guardia | `junior_doctor__guardia.png` | hecho |
| 132 | junior_lawyer__tribunales | `junior_lawyer__tribunales.png` | hecho |
| 133 | senior_programmer__open_source | `senior_programmer__open_source.png` | hecho |
| 134 | senior_architect__starchitect | `senior_architect__starchitect.png` | hecho |
| 135 | senior_doctor__cirujano | `senior_doctor__cirujano.png` | hecho |
| 136 | senior_lawyer__penalista | `senior_lawyer__penalista.png` | hecho |
| 137 | director__directorio | `director__directorio.png` | hecho |
| 138 | fundador_startup__unicornio | `fundador_startup__unicornio.png` | hecho |
| 139 | dueno_pyme__industrial | `dueno_pyme__industrial.png` | hecho |
| 140 | emprendedor__conferencia | `emprendedor__conferencia.png` | hecho |
| 141 | ceo__magnate | `ceo__magnate.png` | hecho |
| 142 | millonario__yate | `millonario__yate.png` | hecho |
| 143 | multimillonario__filantropo | `multimillonario__filantropo.png` | hecho |
| 144 | rey_ladrillo__rascacielos | `rey_ladrillo__rascacielos.png` | hecho |
| 145 | magnate_petrolero__esquisto | `magnate_petrolero__esquisto.png` | hecho |
| 146 | space_billionaire__traje_presurizado | `space_billionaire__traje_presurizado.png` | hecho |
| 147 | trillonario__moneda_propia | `trillonario__moneda_propia.png` | hecho |
| 148 | dueno_luna__selenita | `dueno_luna__selenita.png` | hecho |
| 149 | dueno_marte__terraformador | `dueno_marte__terraformador.png` | hecho |
| 150 | magnate_solar__corona_solar | `magnate_solar__corona_solar.png` | hecho |
| 151 | senor_galaxia__agujero_negro | `senor_galaxia__agujero_negro.png` | hecho |
| 152 | emperador_cosmico__dinastia | `emperador_cosmico__dinastia.png` | hecho |
| 153 | ser_ascendido__iluminado | `ser_ascendido__iluminado.png` | hecho |
| 154 | semidios__titan | `semidios__titan.png` | hecho |
| 155 | deidad__oraculo | `deidad__oraculo.png` | hecho |
| 156 | god__genesis | `god__genesis.png` | hecho |
| 157 | ui_oro | `ui_oro.png` | hecho |
| 158 | trapito | `trapito.png` | pendiente |
| 159 | limpiavidrios | `limpiavidrios.png` | pendiente |
| 160 | mantero | `mantero.png` | pendiente |
| 161 | rey_asteroides | `rey_asteroides.png` | pendiente |
| 162 | rentista_soles | `rentista_soles.png` | pendiente |
| 163 | estanciero_estelar | `estanciero_estelar.png` | pendiente |
| 164 | coleccionista_galaxias | `coleccionista_galaxias.png` | pendiente |
| 165 | homeless_face | `homeless_face.png` | pendiente |
| 166 | trapito_face | `trapito_face.png` | pendiente |
| 167 | limpiavidrios_face | `limpiavidrios_face.png` | pendiente |
| 168 | cartonero_face | `cartonero_face.png` | pendiente |
| 169 | mantero_face | `mantero_face.png` | pendiente |
| 170 | kiosco_face | `kiosco_face.png` | pendiente |
| 171 | repartidor_face | `repartidor_face.png` | pendiente |
| 172 | chofer_app_face | `chofer_app_face.png` | pendiente |
| 173 | fast_food_face | `fast_food_face.png` | pendiente |
| 174 | oficinista_face | `oficinista_face.png` | pendiente |
| 175 | administrativo_face | `administrativo_face.png` | pendiente |
| 176 | junior_programmer_face | `junior_programmer_face.png` | pendiente |
| 177 | junior_architect_face | `junior_architect_face.png` | pendiente |
| 178 | junior_doctor_face | `junior_doctor_face.png` | pendiente |
| 179 | junior_lawyer_face | `junior_lawyer_face.png` | pendiente |
| 180 | senior_programmer_face | `senior_programmer_face.png` | pendiente |
| 181 | senior_architect_face | `senior_architect_face.png` | pendiente |
| 182 | senior_doctor_face | `senior_doctor_face.png` | pendiente |
| 183 | senior_lawyer_face | `senior_lawyer_face.png` | pendiente |
| 184 | director_face | `director_face.png` | pendiente |
| 185 | fundador_startup_face | `fundador_startup_face.png` | pendiente |
| 186 | dueno_pyme_face | `dueno_pyme_face.png` | pendiente |
| 187 | emprendedor_face | `emprendedor_face.png` | pendiente |
| 188 | ceo_face | `ceo_face.png` | pendiente |
| 189 | millonario_face | `millonario_face.png` | pendiente |
| 190 | multimillonario_face | `multimillonario_face.png` | pendiente |
| 191 | rey_ladrillo_face | `rey_ladrillo_face.png` | pendiente |
| 192 | magnate_petrolero_face | `magnate_petrolero_face.png` | pendiente |
| 193 | space_billionaire_face | `space_billionaire_face.png` | pendiente |
| 194 | trillonario_face | `trillonario_face.png` | pendiente |
| 195 | dueno_luna_face | `dueno_luna_face.png` | pendiente |
| 196 | dueno_marte_face | `dueno_marte_face.png` | pendiente |
| 197 | rey_asteroides_face | `rey_asteroides_face.png` | pendiente |
| 198 | magnate_solar_face | `magnate_solar_face.png` | pendiente |
| 199 | rentista_soles_face | `rentista_soles_face.png` | pendiente |
| 200 | estanciero_estelar_face | `estanciero_estelar_face.png` | pendiente |
| 201 | senor_galaxia_face | `senor_galaxia_face.png` | pendiente |
| 202 | coleccionista_galaxias_face | `coleccionista_galaxias_face.png` | pendiente |
| 203 | emperador_cosmico_face | `emperador_cosmico_face.png` | pendiente |
| 204 | ser_ascendido_face | `ser_ascendido_face.png` | pendiente |
| 205 | semidios_face | `semidios_face.png` | pendiente |
| 206 | deidad_face | `deidad_face.png` | pendiente |
| 207 | god_face | `god_face.png` | pendiente |
| 208 | homeless__mundialista | `homeless__mundialista.png` | pendiente |
| 209 | god__parrillero | `god__parrillero.png` | pendiente |

**Progreso**: 157/209 hechos, 52 pendientes.
