# Reacciones de campo — revisión

Umbral: confianza < 0.6 → `indiferente`. Corregí `state/decisions.jsonl` y volvé a correr `build.py`.

## Cuántos reaccionan por evento

| evento | reaccionan | emotes |
|---|---|---|
| plan_platita | 20% | festeja 5, sonrisa_torcida 2, se_encoge_de_hombros 1, se_agarra_la_cabeza 1 |
| startup_comprada | 18% | festeja 3, sonrisa_torcida 3, se_encoge_de_hombros 1, se_agarra_la_cabeza 1 |
| devaluacion | 25% | se_agarra_la_cabeza 5, se_encoge_de_hombros 2, sonrisa_torcida 2, festeja 2 |
| blanqueo | 20% | sonrisa_torcida 5, se_esconde 2, festeja 2 |
| cayo_mercado_pago | 23% | se_agarra_la_cabeza 5, festeja 2, se_esconde 2, se_encoge_de_hombros 1 |
| inversion_alienigena | 18% | festeja 3, sonrisa_torcida 3, se_encoge_de_hombros 1, se_agarra_la_cabeza 1 |
| corralito | 23% | se_agarra_la_cabeza 4, sonrisa_torcida 3, se_encoge_de_hombros 1, se_esconde 1, festeja 1 |
| aguinaldo | 23% | festeja 5, se_encoge_de_hombros 3, se_agarra_la_cabeza 2 |

## Todas, lo más dudoso primero

| conf | evento | personaje | propuesto | queda | por qué |
|---|---|---|---|---|---|
| 0.40 | cayo_mercado_pago | Emprendedor | festeja | indiferente ⬇ | vende un curso de 'cómo cobrar sin apps' |
| 0.45 | blanqueo | Dios | sonrisa_torcida | indiferente ⬇ | ante Dios todo estuvo siempre declarado |
| 0.50 | aguinaldo | Programador Jr. | festeja | indiferente ⬇ | si está en blanco |
| 0.50 | blanqueo | Oficinista | se_agarra_la_cabeza | indiferente ⬇ | el que paga todo mira cómo blanquean otros |
| 0.50 | corralito | Magnate Petrolero | sonrisa_torcida | indiferente ⬇ | sus dólares están en otro país |
| 0.50 | inversion_alienigena | Oficinista | se_esconde | indiferente ⬇ | abducción en horario laboral |
| 0.50 | plan_platita | Rentista de Soles | sonrisa_torcida | indiferente ⬇ | lejano: un rentista cósmico mirando una emisión local |
| 0.50 | startup_comprada | Trillonario | sonrisa_torcida | indiferente ⬇ | compra big techs de a pares |
| 0.55 | aguinaldo | CEO | se_agarra_la_cabeza | indiferente ⬇ | firma el cheque |
| 0.55 | corralito | Médico Sr. | se_agarra_la_cabeza | indiferente ⬇ | los ahorros de la guardia |
| 0.55 | devaluacion | Chofer de App | se_agarra_la_cabeza | indiferente ⬇ | la nafta sube al día siguiente |
| 0.55 | inversion_alienigena | Señor de la Galaxia | se_encoge_de_hombros | indiferente ⬇ | para él son vecinos del barrio |
| 0.55 | plan_platita | Administrativo | se_encoge_de_hombros | indiferente ⬇ | idem oficinista, más tibio |
| 0.55 | startup_comprada | Oficinista | se_esconde | indiferente ⬇ | huele reestructuración |
| 0.58 | blanqueo | Administrativo | se_encoge_de_hombros | indiferente ⬇ | a él le retienen todo en el recibo |
| 0.60 | aguinaldo | Director | festeja | festeja | el suyo es más grande |
| 0.60 | aguinaldo | El Fisura | se_encoge_de_hombros | se_encoge_de_hombros | nunca cobró uno |
| 0.60 | blanqueo | Abogado Jr. | festeja | festeja | sus primeros honorarios de verdad |
| 0.60 | cayo_mercado_pago | Programador Sr. | se_agarra_la_cabeza | se_agarra_la_cabeza | a él lo despiertan a las 3 AM |
| 0.60 | corralito | Fondo Buitre Estelar | festeja | festeja | crisis es oportunidad |
| 0.60 | devaluacion | Recién Recibido | se_agarra_la_cabeza | se_agarra_la_cabeza | recién empieza a cobrar y ya vale la mitad |
| 0.60 | inversion_alienigena | Rentista de Soles | sonrisa_torcida | sonrisa_torcida | más inquilinos |
| 0.60 | inversion_alienigena | Space Billionaire | se_agarra_la_cabeza | se_agarra_la_cabeza | le llegó la competencia al espacio |
| 0.60 | plan_platita | CEO | sonrisa_torcida | sonrisa_torcida | sabe cómo termina la fiesta |
| 0.60 | startup_comprada | El Fisura | se_encoge_de_hombros | se_encoge_de_hombros | no sabe qué es una big tech |
| 0.62 | aguinaldo | Médico Jr. | festeja | festeja | la residencia por fin paga algo |
| 0.62 | blanqueo | El Trapito | se_esconde | se_esconde | idem: el que no figura no paga |
| 0.62 | cayo_mercado_pago | Empleado de Fast Food | se_agarra_la_cabeza | se_agarra_la_cabeza | cola de gente sin poder pagar |
| 0.62 | corralito | Cartonero | se_encoge_de_hombros | se_encoge_de_hombros | no tiene plata en el banco que le toquen |
| 0.62 | devaluacion | Millonario | sonrisa_torcida | sonrisa_torcida | los ahorros están afuera |
| 0.62 | inversion_alienigena | Dueño de la Luna | sonrisa_torcida | sonrisa_torcida | les va a alquilar la Luna |
| 0.62 | plan_platita | Dueño de PYME | se_agarra_la_cabeza | se_agarra_la_cabeza | imprimir es inflación, e inflación es sus precios |
| 0.62 | plan_platita | Emprendedor | festeja | festeja | toda ola es una oportunidad de curso online |
| 0.62 | startup_comprada | Recién Recibido | festeja | festeja | el recién recibido ya se ve con el hoodie |
| 0.64 | aguinaldo | Emprendedor | se_agarra_la_cabeza | se_agarra_la_cabeza | no cobra aguinaldo y encima paga los de otros |
| 0.64 | cayo_mercado_pago | Fundador de Startup | se_esconde | se_esconde | ¿será su fintech? |
| 0.64 | corralito | Multimillonario | se_esconde | se_esconde | la sacó el día antes: que no lo miren |
| 0.64 | startup_comprada | Space Billionaire | sonrisa_torcida | sonrisa_torcida | probablemente es el que compró |
| 0.65 | plan_platita | Oficinista | se_encoge_de_hombros | se_encoge_de_hombros | ya sabe que después viene la inflación |
| 0.65 | startup_comprada | Programador Sr. | sonrisa_torcida | sonrisa_torcida | vio tres adquisiciones: sabe que en seis meses hay despidos |
| 0.66 | blanqueo | Fondo Buitre Estelar | sonrisa_torcida | sonrisa_torcida | le encanta una amnistía |
| 0.66 | cayo_mercado_pago | Dueño de PYME | se_agarra_la_cabeza | se_agarra_la_cabeza | el posnet es el QR |
| 0.66 | devaluacion | El Mantero | se_encoge_de_hombros | se_encoge_de_hombros | sobrevivió a todas: ya está entrenado |
| 0.66 | inversion_alienigena | Dueño de Marte | festeja | festeja | vecinos con plata |
| 0.66 | startup_comprada | CEO | sonrisa_torcida | sonrisa_torcida | probablemente negoció la venta |
| 0.68 | startup_comprada | Emprendedor | se_agarra_la_cabeza | se_agarra_la_cabeza | envidia: el exit le tocó a otro |
| 0.70 | aguinaldo | Chofer de App | se_encoge_de_hombros | se_encoge_de_hombros | monotributista: no hay aguinaldo |
| 0.70 | aguinaldo | Repartidor | se_encoge_de_hombros | se_encoge_de_hombros | monotributista: no hay aguinaldo |
| 0.70 | blanqueo | Magnate Petrolero | sonrisa_torcida | sonrisa_torcida | el pozo también estaba declarado |
| 0.70 | blanqueo | Abogado Sr. | festeja | festeja | honorarios |
| 0.70 | cayo_mercado_pago | El Fisura | se_encoge_de_hombros | se_encoge_de_hombros | nunca tuvo la app |
| 0.70 | cayo_mercado_pago | Programador Jr. | se_esconde | se_esconde | está de guardia y no quiere que lo encuentren |
| 0.70 | devaluacion | Empleado de Fast Food | se_agarra_la_cabeza | se_agarra_la_cabeza | el sueldo mínimo se hizo la mitad |
| 0.70 | devaluacion | Magnate Petrolero | festeja | festeja | exporta en dólares |
| 0.70 | inversion_alienigena | Fondo Buitre Estelar | sonrisa_torcida | sonrisa_torcida | les va a vender deuda a los aliens |
| 0.70 | inversion_alienigena | El Fisura | se_encoge_de_hombros | se_encoge_de_hombros | ya nada lo sorprende |
| 0.70 | plan_platita | Cartonero | festeja | festeja | alegría impresa, aunque sea por un rato |
| 0.70 | plan_platita | Fondo Buitre Estelar | sonrisa_torcida | sonrisa_torcida | ya está posicionado para cuando se caiga |
| 0.70 | plan_platita | El Mantero | festeja | festeja | más plata circulando, más ventas en la manta |
| 0.72 | cayo_mercado_pago | El Trapito | festeja | festeja | nunca aceptó QR |
| 0.72 | corralito | Rey del Ladrillo | sonrisa_torcida | sonrisa_torcida | lo suyo está en ladrillos |
| 0.72 | devaluacion | El Fisura | se_encoge_de_hombros | se_encoge_de_hombros | la mitad de nada es nada: ya está entrenado |
| 0.74 | corralito | Millonario | se_agarra_la_cabeza | se_agarra_la_cabeza | no llegó a sacarla |
| 0.75 | blanqueo | El Mantero | se_esconde | se_esconde | cuando se habla de declarar, mejor no figurar |
| 0.75 | inversion_alienigena | Emprendedor | festeja | festeja | por fin alguien le cree |
| 0.75 | plan_platita | El Trapito | festeja | festeja | más plata en la calle, más propinas |
| 0.76 | corralito | El Mantero | sonrisa_torcida | sonrisa_torcida | el efectivo está bajo el colchón |
| 0.78 | aguinaldo | Empleado de Fast Food | festeja | festeja | llegó el medio sueldo |
| 0.78 | blanqueo | Multimillonario | sonrisa_torcida | sonrisa_torcida | 'siempre estuvo declarado' |
| 0.78 | corralito | Dueño de PYME | se_agarra_la_cabeza | se_agarra_la_cabeza | no puede pagar sueldos |
| 0.78 | devaluacion | Rey del Ladrillo | sonrisa_torcida | sonrisa_torcida | el ladrillo está en dólares |
| 0.80 | blanqueo | Millonario | sonrisa_torcida | sonrisa_torcida | todo en regla, de golpe |
| 0.80 | corralito | El Fisura | sonrisa_torcida | sonrisa_torcida | nunca tuvo cuenta en el banco |
| 0.80 | devaluacion | Dueño de PYME | se_agarra_la_cabeza | se_agarra_la_cabeza | insumos en dólares, ventas en pesos |
| 0.80 | plan_platita | El Fisura | festeja | festeja | plata que cae del cielo sobre el que no tiene nada |
| 0.80 | startup_comprada | Programador Jr. | festeja | festeja | hoodie nuevo y stock options |
| 0.82 | blanqueo | Rey del Ladrillo | sonrisa_torcida | sonrisa_torcida | los departamentos en pozo, al fin en blanco |
| 0.82 | cayo_mercado_pago | El Mantero | festeja | festeja | siempre cobró en efectivo |
| 0.82 | corralito | Administrativo | se_agarra_la_cabeza | se_agarra_la_cabeza | el sueldo quedó adentro |
| 0.82 | devaluacion | Administrativo | se_agarra_la_cabeza | se_agarra_la_cabeza | cobra en pesos |
| 0.85 | aguinaldo | Cartonero | indiferente | indiferente |  |
| 0.85 | aguinaldo | Coleccionista de Galaxias | indiferente | indiferente |  |
| 0.85 | aguinaldo | Deidad | indiferente | indiferente |  |
| 0.85 | aguinaldo | Dueño de la Luna | indiferente | indiferente |  |
| 0.85 | aguinaldo | Dueño de Marte | indiferente | indiferente |  |
| 0.85 | aguinaldo | Emperador Cósmico | indiferente | indiferente |  |
| 0.85 | aguinaldo | Estanciero Estelar | indiferente | indiferente |  |
| 0.85 | aguinaldo | Fondo Buitre Estelar | indiferente | indiferente |  |
| 0.85 | aguinaldo | Fundador de Startup | indiferente | indiferente |  |
| 0.85 | aguinaldo | Dios | indiferente | indiferente |  |
| 0.85 | aguinaldo | Recién Recibido | indiferente | indiferente |  |
| 0.85 | aguinaldo | Arquitecto Jr. | indiferente | indiferente |  |
| 0.85 | aguinaldo | Abogado Jr. | indiferente | indiferente |  |
| 0.85 | aguinaldo | Limpiavidrios | indiferente | indiferente |  |
| 0.85 | aguinaldo | Magnate Petrolero | indiferente | indiferente |  |
| 0.85 | aguinaldo | Magnate del Sistema Solar | indiferente | indiferente |  |
| 0.85 | aguinaldo | El Mantero | indiferente | indiferente |  |
| 0.85 | aguinaldo | Millonario | indiferente | indiferente |  |
| 0.85 | aguinaldo | Multimillonario | indiferente | indiferente |  |
| 0.85 | aguinaldo | Rentista de Soles | indiferente | indiferente |  |
| 0.85 | aguinaldo | Rey de los Asteroides | indiferente | indiferente |  |
| 0.85 | aguinaldo | Rey del Ladrillo | indiferente | indiferente |  |
| 0.85 | aguinaldo | Semidiós | indiferente | indiferente |  |
| 0.85 | aguinaldo | Arquitecto Sr. | indiferente | indiferente |  |
| 0.85 | aguinaldo | Médico Sr. | indiferente | indiferente |  |
| 0.85 | aguinaldo | Abogado Sr. | indiferente | indiferente |  |
| 0.85 | aguinaldo | Programador Sr. | indiferente | indiferente |  |
| 0.85 | aguinaldo | Señor de la Galaxia | indiferente | indiferente |  |
| 0.85 | aguinaldo | Ser Ascendido | indiferente | indiferente |  |
| 0.85 | aguinaldo | Space Billionaire | indiferente | indiferente |  |
| 0.85 | aguinaldo | El Trapito | indiferente | indiferente |  |
| 0.85 | aguinaldo | Trillonario | indiferente | indiferente |  |
| 0.85 | blanqueo | Cartonero | indiferente | indiferente |  |
| 0.85 | blanqueo | CEO | indiferente | indiferente |  |
| 0.85 | blanqueo | Chofer de App | indiferente | indiferente |  |
| 0.85 | blanqueo | Coleccionista de Galaxias | indiferente | indiferente |  |
| 0.85 | blanqueo | Deidad | indiferente | indiferente |  |
| 0.85 | blanqueo | Director | indiferente | indiferente |  |
| 0.85 | blanqueo | Dueño de la Luna | indiferente | indiferente |  |
| 0.85 | blanqueo | Dueño de Marte | indiferente | indiferente |  |
| 0.85 | blanqueo | Dueño de PYME | indiferente | indiferente |  |
| 0.85 | blanqueo | Emperador Cósmico | indiferente | indiferente |  |
| 0.85 | blanqueo | Emprendedor | indiferente | indiferente |  |
| 0.85 | blanqueo | Estanciero Estelar | indiferente | indiferente |  |
| 0.85 | blanqueo | Empleado de Fast Food | indiferente | indiferente |  |
| 0.85 | blanqueo | Fundador de Startup | indiferente | indiferente |  |
| 0.85 | blanqueo | El Fisura | indiferente | indiferente |  |
| 0.85 | blanqueo | Recién Recibido | indiferente | indiferente |  |
| 0.85 | blanqueo | Arquitecto Jr. | indiferente | indiferente |  |
| 0.85 | blanqueo | Médico Jr. | indiferente | indiferente |  |
| 0.85 | blanqueo | Programador Jr. | indiferente | indiferente |  |
| 0.85 | blanqueo | Limpiavidrios | indiferente | indiferente |  |
| 0.85 | blanqueo | Magnate del Sistema Solar | indiferente | indiferente |  |
| 0.85 | blanqueo | Rentista de Soles | indiferente | indiferente |  |
| 0.85 | blanqueo | Repartidor | indiferente | indiferente |  |
| 0.85 | blanqueo | Rey de los Asteroides | indiferente | indiferente |  |
| 0.85 | blanqueo | Semidiós | indiferente | indiferente |  |
| 0.85 | blanqueo | Arquitecto Sr. | indiferente | indiferente |  |
| 0.85 | blanqueo | Médico Sr. | indiferente | indiferente |  |
| 0.85 | blanqueo | Programador Sr. | indiferente | indiferente |  |
| 0.85 | blanqueo | Señor de la Galaxia | indiferente | indiferente |  |
| 0.85 | blanqueo | Ser Ascendido | indiferente | indiferente |  |
| 0.85 | blanqueo | Space Billionaire | indiferente | indiferente |  |
| 0.85 | blanqueo | Trillonario | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Administrativo | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Cartonero | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | CEO | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Chofer de App | se_agarra_la_cabeza | se_agarra_la_cabeza | cobra por la app |
| 0.85 | cayo_mercado_pago | Coleccionista de Galaxias | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Deidad | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Director | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Dueño de la Luna | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Dueño de Marte | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Emperador Cósmico | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Estanciero Estelar | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Fondo Buitre Estelar | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Dios | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Recién Recibido | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Arquitecto Jr. | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Médico Jr. | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Abogado Jr. | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Limpiavidrios | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Magnate Petrolero | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Magnate del Sistema Solar | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Millonario | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Multimillonario | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Oficinista | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Rentista de Soles | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Repartidor | se_agarra_la_cabeza | se_agarra_la_cabeza | cobra por la app |
| 0.85 | cayo_mercado_pago | Rey de los Asteroides | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Rey del Ladrillo | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Semidiós | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Arquitecto Sr. | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Médico Sr. | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Abogado Sr. | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Señor de la Galaxia | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Ser Ascendido | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Space Billionaire | indiferente | indiferente |  |
| 0.85 | cayo_mercado_pago | Trillonario | indiferente | indiferente |  |
| 0.85 | corralito | CEO | indiferente | indiferente |  |
| 0.85 | corralito | Chofer de App | indiferente | indiferente |  |
| 0.85 | corralito | Coleccionista de Galaxias | indiferente | indiferente |  |
| 0.85 | corralito | Deidad | indiferente | indiferente |  |
| 0.85 | corralito | Director | indiferente | indiferente |  |
| 0.85 | corralito | Dueño de la Luna | indiferente | indiferente |  |
| 0.85 | corralito | Dueño de Marte | indiferente | indiferente |  |
| 0.85 | corralito | Emperador Cósmico | indiferente | indiferente |  |
| 0.85 | corralito | Emprendedor | indiferente | indiferente |  |
| 0.85 | corralito | Estanciero Estelar | indiferente | indiferente |  |
| 0.85 | corralito | Empleado de Fast Food | indiferente | indiferente |  |
| 0.85 | corralito | Fundador de Startup | indiferente | indiferente |  |
| 0.85 | corralito | Dios | indiferente | indiferente |  |
| 0.85 | corralito | Recién Recibido | indiferente | indiferente |  |
| 0.85 | corralito | Arquitecto Jr. | indiferente | indiferente |  |
| 0.85 | corralito | Médico Jr. | indiferente | indiferente |  |
| 0.85 | corralito | Abogado Jr. | indiferente | indiferente |  |
| 0.85 | corralito | Programador Jr. | indiferente | indiferente |  |
| 0.85 | corralito | Limpiavidrios | indiferente | indiferente |  |
| 0.85 | corralito | Magnate del Sistema Solar | indiferente | indiferente |  |
| 0.85 | corralito | Rentista de Soles | indiferente | indiferente |  |
| 0.85 | corralito | Repartidor | indiferente | indiferente |  |
| 0.85 | corralito | Rey de los Asteroides | indiferente | indiferente |  |
| 0.85 | corralito | Semidiós | indiferente | indiferente |  |
| 0.85 | corralito | Arquitecto Sr. | indiferente | indiferente |  |
| 0.85 | corralito | Abogado Sr. | indiferente | indiferente |  |
| 0.85 | corralito | Programador Sr. | indiferente | indiferente |  |
| 0.85 | corralito | Señor de la Galaxia | indiferente | indiferente |  |
| 0.85 | corralito | Ser Ascendido | indiferente | indiferente |  |
| 0.85 | corralito | Space Billionaire | indiferente | indiferente |  |
| 0.85 | corralito | El Trapito | indiferente | indiferente |  |
| 0.85 | corralito | Trillonario | indiferente | indiferente |  |
| 0.85 | devaluacion | Cartonero | indiferente | indiferente |  |
| 0.85 | devaluacion | CEO | indiferente | indiferente |  |
| 0.85 | devaluacion | Coleccionista de Galaxias | indiferente | indiferente |  |
| 0.85 | devaluacion | Deidad | indiferente | indiferente |  |
| 0.85 | devaluacion | Director | indiferente | indiferente |  |
| 0.85 | devaluacion | Dueño de la Luna | indiferente | indiferente |  |
| 0.85 | devaluacion | Dueño de Marte | indiferente | indiferente |  |
| 0.85 | devaluacion | Emperador Cósmico | indiferente | indiferente |  |
| 0.85 | devaluacion | Emprendedor | indiferente | indiferente |  |
| 0.85 | devaluacion | Estanciero Estelar | indiferente | indiferente |  |
| 0.85 | devaluacion | Fundador de Startup | indiferente | indiferente |  |
| 0.85 | devaluacion | Dios | indiferente | indiferente |  |
| 0.85 | devaluacion | Arquitecto Jr. | indiferente | indiferente |  |
| 0.85 | devaluacion | Médico Jr. | indiferente | indiferente |  |
| 0.85 | devaluacion | Abogado Jr. | indiferente | indiferente |  |
| 0.85 | devaluacion | Programador Jr. | indiferente | indiferente |  |
| 0.85 | devaluacion | Limpiavidrios | indiferente | indiferente |  |
| 0.85 | devaluacion | Magnate del Sistema Solar | indiferente | indiferente |  |
| 0.85 | devaluacion | Multimillonario | indiferente | indiferente |  |
| 0.85 | devaluacion | Oficinista | se_agarra_la_cabeza | se_agarra_la_cabeza | cobra en pesos |
| 0.85 | devaluacion | Rentista de Soles | indiferente | indiferente |  |
| 0.85 | devaluacion | Repartidor | indiferente | indiferente |  |
| 0.85 | devaluacion | Rey de los Asteroides | indiferente | indiferente |  |
| 0.85 | devaluacion | Semidiós | indiferente | indiferente |  |
| 0.85 | devaluacion | Arquitecto Sr. | indiferente | indiferente |  |
| 0.85 | devaluacion | Médico Sr. | indiferente | indiferente |  |
| 0.85 | devaluacion | Abogado Sr. | indiferente | indiferente |  |
| 0.85 | devaluacion | Programador Sr. | indiferente | indiferente |  |
| 0.85 | devaluacion | Señor de la Galaxia | indiferente | indiferente |  |
| 0.85 | devaluacion | Ser Ascendido | indiferente | indiferente |  |
| 0.85 | devaluacion | Space Billionaire | indiferente | indiferente |  |
| 0.85 | devaluacion | El Trapito | indiferente | indiferente |  |
| 0.85 | devaluacion | Trillonario | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Administrativo | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Cartonero | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | CEO | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Chofer de App | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Coleccionista de Galaxias | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Deidad | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Director | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Dueño de PYME | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Emperador Cósmico | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Estanciero Estelar | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Empleado de Fast Food | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Fundador de Startup | festeja | festeja | ronda de inversión, aunque sea interestelar |
| 0.85 | inversion_alienigena | Dios | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Recién Recibido | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Arquitecto Jr. | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Médico Jr. | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Abogado Jr. | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Programador Jr. | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Limpiavidrios | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Magnate Petrolero | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Magnate del Sistema Solar | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | El Mantero | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Millonario | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Multimillonario | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Repartidor | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Rey de los Asteroides | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Rey del Ladrillo | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Semidiós | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Arquitecto Sr. | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Médico Sr. | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Abogado Sr. | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Programador Sr. | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Ser Ascendido | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | El Trapito | indiferente | indiferente |  |
| 0.85 | inversion_alienigena | Trillonario | indiferente | indiferente |  |
| 0.85 | plan_platita | Chofer de App | indiferente | indiferente |  |
| 0.85 | plan_platita | Coleccionista de Galaxias | indiferente | indiferente |  |
| 0.85 | plan_platita | Deidad | indiferente | indiferente |  |
| 0.85 | plan_platita | Director | indiferente | indiferente |  |
| 0.85 | plan_platita | Dueño de la Luna | indiferente | indiferente |  |
| 0.85 | plan_platita | Dueño de Marte | indiferente | indiferente |  |
| 0.85 | plan_platita | Emperador Cósmico | indiferente | indiferente |  |
| 0.85 | plan_platita | Estanciero Estelar | indiferente | indiferente |  |
| 0.85 | plan_platita | Empleado de Fast Food | indiferente | indiferente |  |
| 0.85 | plan_platita | Fundador de Startup | indiferente | indiferente |  |
| 0.85 | plan_platita | Dios | indiferente | indiferente |  |
| 0.85 | plan_platita | Recién Recibido | indiferente | indiferente |  |
| 0.85 | plan_platita | Arquitecto Jr. | indiferente | indiferente |  |
| 0.85 | plan_platita | Médico Jr. | indiferente | indiferente |  |
| 0.85 | plan_platita | Abogado Jr. | indiferente | indiferente |  |
| 0.85 | plan_platita | Programador Jr. | indiferente | indiferente |  |
| 0.85 | plan_platita | Limpiavidrios | indiferente | indiferente |  |
| 0.85 | plan_platita | Magnate Petrolero | indiferente | indiferente |  |
| 0.85 | plan_platita | Magnate del Sistema Solar | indiferente | indiferente |  |
| 0.85 | plan_platita | Millonario | indiferente | indiferente |  |
| 0.85 | plan_platita | Multimillonario | indiferente | indiferente |  |
| 0.85 | plan_platita | Repartidor | indiferente | indiferente |  |
| 0.85 | plan_platita | Rey de los Asteroides | indiferente | indiferente |  |
| 0.85 | plan_platita | Rey del Ladrillo | indiferente | indiferente |  |
| 0.85 | plan_platita | Semidiós | indiferente | indiferente |  |
| 0.85 | plan_platita | Arquitecto Sr. | indiferente | indiferente |  |
| 0.85 | plan_platita | Médico Sr. | indiferente | indiferente |  |
| 0.85 | plan_platita | Abogado Sr. | indiferente | indiferente |  |
| 0.85 | plan_platita | Programador Sr. | indiferente | indiferente |  |
| 0.85 | plan_platita | Señor de la Galaxia | indiferente | indiferente |  |
| 0.85 | plan_platita | Ser Ascendido | indiferente | indiferente |  |
| 0.85 | plan_platita | Space Billionaire | indiferente | indiferente |  |
| 0.85 | plan_platita | Trillonario | indiferente | indiferente |  |
| 0.85 | startup_comprada | Administrativo | indiferente | indiferente |  |
| 0.85 | startup_comprada | Cartonero | indiferente | indiferente |  |
| 0.85 | startup_comprada | Chofer de App | indiferente | indiferente |  |
| 0.85 | startup_comprada | Coleccionista de Galaxias | indiferente | indiferente |  |
| 0.85 | startup_comprada | Deidad | indiferente | indiferente |  |
| 0.85 | startup_comprada | Director | indiferente | indiferente |  |
| 0.85 | startup_comprada | Dueño de la Luna | indiferente | indiferente |  |
| 0.85 | startup_comprada | Dueño de Marte | indiferente | indiferente |  |
| 0.85 | startup_comprada | Dueño de PYME | indiferente | indiferente |  |
| 0.85 | startup_comprada | Emperador Cósmico | indiferente | indiferente |  |
| 0.85 | startup_comprada | Estanciero Estelar | indiferente | indiferente |  |
| 0.85 | startup_comprada | Empleado de Fast Food | indiferente | indiferente |  |
| 0.85 | startup_comprada | Fondo Buitre Estelar | indiferente | indiferente |  |
| 0.85 | startup_comprada | Dios | indiferente | indiferente |  |
| 0.85 | startup_comprada | Arquitecto Jr. | indiferente | indiferente |  |
| 0.85 | startup_comprada | Médico Jr. | indiferente | indiferente |  |
| 0.85 | startup_comprada | Abogado Jr. | indiferente | indiferente |  |
| 0.85 | startup_comprada | Limpiavidrios | indiferente | indiferente |  |
| 0.85 | startup_comprada | Magnate Petrolero | indiferente | indiferente |  |
| 0.85 | startup_comprada | Magnate del Sistema Solar | indiferente | indiferente |  |
| 0.85 | startup_comprada | El Mantero | indiferente | indiferente |  |
| 0.85 | startup_comprada | Millonario | indiferente | indiferente |  |
| 0.85 | startup_comprada | Multimillonario | indiferente | indiferente |  |
| 0.85 | startup_comprada | Rentista de Soles | indiferente | indiferente |  |
| 0.85 | startup_comprada | Repartidor | indiferente | indiferente |  |
| 0.85 | startup_comprada | Rey de los Asteroides | indiferente | indiferente |  |
| 0.85 | startup_comprada | Rey del Ladrillo | indiferente | indiferente |  |
| 0.85 | startup_comprada | Semidiós | indiferente | indiferente |  |
| 0.85 | startup_comprada | Arquitecto Sr. | indiferente | indiferente |  |
| 0.85 | startup_comprada | Médico Sr. | indiferente | indiferente |  |
| 0.85 | startup_comprada | Abogado Sr. | indiferente | indiferente |  |
| 0.85 | startup_comprada | Señor de la Galaxia | indiferente | indiferente |  |
| 0.85 | startup_comprada | Ser Ascendido | indiferente | indiferente |  |
| 0.85 | startup_comprada | El Trapito | indiferente | indiferente |  |
| 0.86 | aguinaldo | Administrativo | festeja | festeja | llegó el medio sueldo |
| 0.86 | corralito | Oficinista | se_agarra_la_cabeza | se_agarra_la_cabeza | el sueldo quedó adentro |
| 0.88 | aguinaldo | Dueño de PYME | se_agarra_la_cabeza | se_agarra_la_cabeza | lo tiene que pagar él |
| 0.88 | aguinaldo | Oficinista | festeja | festeja | llegó el medio sueldo |
| 0.88 | devaluacion | Fondo Buitre Estelar | festeja | festeja | compra barato todo lo que se devaluó |
| 0.90 | startup_comprada | Fundador de Startup | festeja | festeja | es literalmente su sueño: el exit |
