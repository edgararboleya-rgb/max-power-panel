/* E39 · GENERALES DEL PROYECTO, FUERA DEL TAKEOFF (29/09, Peninsula).
   Edgar cuadró su número contra el de la app: la diferencia eran los generales
   (viajes Ocala–Broward, permiso, su PM, lift, overtime en los apagones), que no
   tenían sitio y, cuando se ponían, entraban como renglones del takeoff. Ahora
   van aparte, por categoría, con un colchón en %, y entran al COSTO DIRECTO:
   overhead y profit sí; tax, misceláneas, markup y escalación no.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e39.js          */
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.webmanifest': 'application/json' };
const srv = http.createServer((req, res) => { let p = req.url.split('?')[0]; if (p === '/') p = '/index.html'; fs.readFile(path.join(ROOT, p), (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); res.end(d); }); });
const R = []; const ok = (n, c, d) => R.push((c ? '  ✓ ' : '  ✗ ') + n + (d !== undefined ? '   [' + d + ']' : ''));
const CAT = [
  { id: 1, item: 'CAJA', seccion: 'RACEWAY', unidad: 'E', precio: 10, horas_unidad: 0.5 },
  { id: 987, item: "Scissor Lift 19' (electric)", seccion: 'PROJECT GENERAL', unidad: 'DAY', precio: 185, horas_unidad: 0, codigo: '19-EQUIP' },
  { id: 1001, item: 'Dumpster Rental (10-15 yd)', seccion: 'PROJECT GENERAL', unidad: 'EA', precio: 385, horas_unidad: 0, codigo: '19-EQUIP' },
  { id: 995, item: 'Per Diem Meals (per worker/day)', seccion: 'PROJECT GENERAL', unidad: 'DAY', precio: 65, horas_unidad: 0, codigo: '20-MISC' },
  { id: 1147, item: 'MOVILIZACIÓN Y ACARREO (por viaje)', seccion: 'LABOR', unidad: 'E', precio: 0, horas_unidad: 4, codigo: '20-MISC' },
  { id: 1121, item: 'AS-BUILT, PRUEBAS Y CIERRE (por proyecto)', seccion: 'LABOR', unidad: 'E', precio: 0, horas_unidad: 8, codigo: '20-MISC' }
];
// el escenario de la fórmula MEP de Edgar: overhead 15 % del costo directo × profit 15 %
const ESC = [{ id: 'MEP', foreman: 43, journeyman: 34, helper: 22, pct_foreman: .2, pct_journeyman: .5, pct_helper: .3,
               benefits: .28, tax_material: .07, overhead_hh: 0, overhead_pct: 0.15, profit: .15 }];
const CFG = { misc_pct: 0.03 };
const BASE = { id: 44, nombre: 'Peninsula', escenario: 'MEP', modo: 'planos', estado: 'borrador', factor: 1, markup_pct: 0.2 };
// lo que Edgar puso en su cuenta ($12.130), en renglones fijos: un número cada uno; el lift, 10 días a $500 la semana
const GEN = { lift_dias: 10, viajes: 5100, permiso: 2500, pm: 1730, dispo: 700, overtime: 1100 };
// lo que guardó la primera versión (v246): una lista, con el lift en «días» de 1 h
const VIEJO = [
  { cat: 'equipo', uni: 'e', cant: 10, desc: 'LIFT O ANDAMIO — MONTAJE Y MOVIMIENTO (por día) (incluye 1 h de mano)', costo: 43.2 },
  { cat: 'permiso', uni: 'e', cant: 1, desc: 'PERMISO E INSPECCIONES (por proyecto) (incluye 6 h de mano)', costo: 259.2 },
  { cat: 'viajes', uni: 'e', cant: 4, desc: 'MOVILIZACIÓN Y ACARREO (por viaje) (incluye 4 h de mano)', costo: 172.8 }];
const cerca = (a, b) => Math.abs(a - b) < 0.011;

(async () => {
  await new Promise(r => srv.listen(8939, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const p = await (await b.newContext({ viewport: { width: 1200, height: 900 }, serviceWorkers: 'block' })).newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.route(/supabase\.co/, r => r.fulfill({ status: 200, contentType: 'application/json', body: '[]' }));
  await p.goto('http://localhost:8939/index.html'); await p.waitForFunction(() => window.MXP_PRUEBA && window.MXP_PRUEBA.e0, null, { timeout: 15000 });
  const ITEMS = [{ id: 1, estimado_id: 44, item: 'CAJA', cantidad: 100, precio: 10, horas: 0.5, unidad: 'E', orden: 1 }];
  const datos = (items, ests) => p.evaluate(([c, e, cf, it, es]) => window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it, estimados: es || [], ensambles: [], estEnsambles: [] }), [CAT, ESC, CFG, items, ests]);
  await datos(ITEMS);
  const calc = est => p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e), est);

  /* === 1. la cuenta pura === */
  const g = await p.evaluate(e => window.MXP_PRUEBA.e0.generales(e), { ...BASE, gastos_generales: GEN });
  const R_ = (x, id) => x.renglones.find(r => r.id === id);
  ok('los renglones fijos salen siempre, en su orden, el lift el primero', g.renglones.length === 10 && g.renglones[0].id === 'lift' && R_(g, 'hotel').total === 0);
  ok('el lift: 10 días = 2 semanas × $500 = $1.000 (Edgar: «5 días de una semana más 5 de otra»)', R_(g, 'lift').semanas === 2 && R_(g, 'lift').precioSemana === 500 && R_(g, 'lift').total === 1000, JSON.stringify(R_(g, 'lift')));
  const semanas = await p.evaluate(() => [1, 5, 6, 11].map(d => window.MXP_PRUEBA.e0.generales({ gastos_generales: { lift_dias: d } }).renglones[0].semanas).join(','));
  ok('1 día = 1 semana, 5 = 1, 6 = 2, 11 = 3 (la renta es por semana empezada)', semanas === '1,1,2,3', semanas);
  const propio = await p.evaluate(() => window.MXP_PRUEBA.e0.generales({ gastos_generales: { lift_dias: 10, lift_semana: 425 } }).total);
  ok('el precio por semana se cambia en el estimado: 2 × $425 = $850', propio === 850, propio);
  const cfg = await p.evaluate(() => window.MXP_PRUEBA.e0.generales({ gastos_generales: { lift_dias: 5 } }, { lift_semana: '450' }).total);
  ok('y la casa puede tener el suyo (config lift_semana)', cfg === 450, cfg);
  ok('los demás son un monto: $5.100 + $2.500 + $1.730 + $700 + $1.100 + lift $1.000 = $12.130', Math.abs(g.subtotal - 12130) < 0.01 && Math.abs(g.total - 12130) < 0.01, g.subtotal);
  const gc = await p.evaluate(e => window.MXP_PRUEBA.e0.generales(e), { ...BASE, gastos_generales: GEN, generales_colchon_pct: 0.1 });
  ok('el colchón del 10 % sube la lista entera: $12.130 → $13.343', Math.abs(gc.colchon - 1213) < 0.01 && Math.abs(gc.total - 13343) < 0.01, gc.total);
  const viejo = await p.evaluate(e => window.MXP_PRUEBA.e0.generales(e), { ...BASE, gastos_generales: VIEJO });
  ok('lo guardado por la primera versión se lee: los 10 «días» de lift pasan a 10 días de renta; permiso y viajes, su dinero', R_(viejo, 'lift').dias === 10 && R_(viejo, 'lift').total === 1000 && Math.abs(R_(viejo, 'permiso').total - 259.2) < 0.01 && Math.abs(R_(viejo, 'viajes').total - 691.2) < 0.01, JSON.stringify(viejo.guardado));
  const raro = await p.evaluate(e => window.MXP_PRUEBA.e0.generales(e), { ...BASE, gastos_generales: { hotel: -3, comida: 'abc', lift_dias: 'x' } });
  ok('datos raros no rompen: negativos y texto → 0', raro.total === 0);
  const vacio = await p.evaluate(e => window.MXP_PRUEBA.e0.generales(e), BASE);
  ok('sin nada, nada: total 0', vacio.total === 0);

  /* === 2. en la fórmula: costo directo, con overhead y profit, sin tax ni markup === */
  const sin = await calc(BASE), con = await calc({ ...BASE, gastos_generales: GEN });
  ok('el material no se mueve (no pagan tax, misceláneas ni markup)', cerca(sin.totalMaterial, con.totalMaterial) && cerca(sin.tax, con.tax) && cerca(sin.markup, con.markup));
  ok('la mano de obra y las horas no se mueven', cerca(sin.totalLabor, con.totalLabor) && cerca(sin.horas, con.horas));
  ok('el costo directo sube exactamente $12.130', cerca(con.prime - sin.prime, 12130), (con.prime - sin.prime).toFixed(2));
  ok('y el bid sube $12.130 × 1,15 × 1,15 = $16.041,93 (overhead y profit, como en la cuenta de Edgar)', cerca(con.bid - sin.bid, 12130 * 1.15 * 1.15), (con.bid - sin.bid).toFixed(2));
  ok('la hora cargada no se infla con los generales', cerca(sin.tarifaCargada, con.tarifaCargada), sin.tarifaCargada.toFixed(2) + ' / ' + con.tarifaCargada.toFixed(2));
  const conEsc = await calc({ ...BASE, gastos_generales: GEN, meses_obra: 18, escalacion_pct: 0.04 });
  const sinEsc = await calc({ ...BASE, meses_obra: 18, escalacion_pct: 0.04 });
  ok('no pagan escalación', cerca(conEsc.escalacion, sinEsc.escalacion));
  ok('c.generales y c.gen salen del cálculo', cerca(con.generales, 12130) && con.gen && con.gen.renglones.length === 10);

  /* === 3. los papeles === */
  const mep = await p.evaluate(e => { const c = window.MXP_PRUEBA.e0.calcula(e); return window.MXP_PRUEBA.e0.mep(e, c); }, { ...BASE, gastos_generales: GEN });
  ok('el resumen MEP dice los otros gastos, renglón a renglón, y el costo directo', /Otros gastos del proyecto:\s+\$12,130\.00/.test(mep) && /· Renta de lift \(10 días = 2 sem × \$500\.00\): \$1,000\.00/.test(mep) && /Costo directo:/.test(mep), (mep.match(/Renta.*$/m) || [''])[0]);
  const tk = await p.evaluate(e => { const c = window.MXP_PRUEBA.e0.calcula(e); return window.MXP_PRUEBA.e0.takeoff(e, c); }, { ...BASE, gastos_generales: GEN, generales_colchon_pct: 0.1 });
  ok('el takeoff para copiar los lleva en su bloque, fuera del material', /OTROS GASTOS DEL PROYECTO/.test(tk) && /Renta de lift\totros gastos · 10 días de obra\t2\.00\tsemana\t500\.00/.test(tk) && /= OTROS GASTOS\t.*13343\.00/.test(tk), (tk.match(/= OTROS GASTOS.*$/m) || [''])[0]);
  ok('… y dice el costo directo', /= COSTO DIRECTO/.test(tk));
  const tkMat = tk.split('= MATERIAL')[0];
  ok('ningún otro gasto se cuela entre los renglones del material', !/Renta de lift|Permiso e insp/.test(tkMat));

  /* === 4. la tarjeta === */
  const card = await p.evaluate(e => window.MXP_PRUEBA.e0.generalesCard(e, window.MXP_PRUEBA.e0.calcula(e)), { ...BASE, gastos_generales: GEN, generales_colchon_pct: 0.1 });
  ok('la tarjeta dice que va fuera del takeoff y se suma al costo directo', /fuera del takeoff/.test(card) && /costo directo/.test(card));
  ok('un número por renglón: 9 montos, y el lift con sus días y su precio por semana', (card.match(/class="gen-monto"/g) || []).length === 9 && /class="gen-lift-dias"[^>]*value="10"/.test(card) && /class="gen-lift-semana"[^>]*value="500"/.test(card));
  ok('el lift dice las semanas que salen: «2 semanas»', /<b>2 semanas<\/b>/.test(card));
  ok('hotel, comidas, equipo… están aunque estén vacíos (renglones predeterminados)', /Hotel/.test(card) && /Comidas \/ per diem/.test(card) && /Otro equipo/.test(card));
  ok('ya no hay categorías, unidades ni la lista del catálogo', !/gen-n-cat|id="gen-lista"|gen-cant|gen-costo|<select/.test(card));
  ok('subtotal, colchón y total', /Subtotal/.test(card) && /id="gen-colchon"[^>]*value="10"/.test(card) && /Total de otros gastos/.test(card) && /\$13,343\.00/.test(card));
  const soloLect = await p.evaluate(e => window.MXP_PRUEBA.e0.generalesCard(e, null, true), { ...BASE, estado: 'congelado', gastos_generales: GEN });
  ok('congelado: se ve sin editar, y solo los renglones con algo', !/gen-monto|gen-colchon|gen-lift-dias/.test(soloLect) && /Renta de lift/.test(soloLect) && /10 días → 2 sem/.test(soloLect) && !/Hotel/.test(soloLect));
  const nada = await p.evaluate(e => window.MXP_PRUEBA.e0.generalesCard(e, null, true), { ...BASE, estado: 'congelado' });
  ok('congelado y sin nada: no hay tarjeta', nada === '');
  const gcCard = await p.evaluate(e => window.MXP_PRUEBA.e0.generalesCard(e), { ...BASE, contratista_id: 'wisdom' });
  ok('con contratista, el permiso avisa de la regla del GC', /si el permiso lo saca el GC, no lo pongas/.test(gcCard));

  /* === 5. lo que está en el takeoff y es general se ofrece pasar === */
  await datos(ITEMS.concat([
    { id: 2, estimado_id: 44, item: "Scissor Lift 19' (electric)", cantidad: 6, precio: 185, horas: 0, unidad: 'DAY', orden: 2 },
    { id: 3, estimado_id: 44, item: 'MOVILIZACIÓN Y ACARREO (por viaje)', cantidad: 2, precio: 0, horas: 4, unidad: 'E', orden: 3 }]));
  const cardM = await p.evaluate(e => window.MXP_PRUEBA.e0.generalesCard(e, window.MXP_PRUEBA.e0.calcula(e)), BASE);
  ok('avisa de los 2 renglones del takeoff que son otros gastos (el lift del catálogo y la movilización de antes)', /Hay 2 renglón\(es\) en el takeoff que son otros gastos/.test(cardM) && /btn-gen-mover/.test(cardM));
  const cats = await p.evaluate(() => ["Scissor Lift 19' (electric)", 'LIFT O ANDAMIO — MONTAJE Y MOVIMIENTO (por día)', 'Dumpster Rental (10-15 yd)', 'Per Diem Meals (per worker/day)', 'Lodging (per worker/night)', 'MOVILIZACIÓN Y ACARREO (por viaje)', 'Electrical Permit (Saint Petersburg)', 'Overtime Premium (per hour)', 'Project Management Fee', 'Scaffold (per section/day)', 'Consumables/Supplies']
    .map(n => window.MXP_PRUEBA.e0.generalesRenglonDe(n)).join(','));
  ok('cada general del catálogo cae en su renglón (los lifts, como días de renta)', cats === 'lift,lift,dispo,comida,hotel,viajes,permiso,overtime,pm,equipo,otros', cats);

  /* === 6. las horas del proyecto ya no proponen lift, permiso ni viajes === */
  const h = await p.evaluate(e => window.MXP_PRUEBA.e0.horas([], e, {}), BASE);
  ok('ni lift, ni permiso, ni movilización en las horas del proyecto', !h.filas.some(f => /lift|permiso|movilizacion/.test(f.id)), h.filas.map(f => f.id).join(','));

  /* === 7. el editor entero, con la tarjeta y el resumen === */
  const ed = await p.evaluate(([c, e, cf, it, est]) => {
    window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it, estimados: [est], ensambles: [], estEnsambles: [] });
    try { return window.MXP_PRUEBA.e0.editor(44); } catch (err) { return { err: String(err) }; }
  }, [CAT, ESC, CFG, ITEMS, { ...BASE, gastos_generales: GEN }]);
  ok('el editor se pinta con la tarjeta de Otros gastos', ed.ids && ed.ids.includes('gen-colchon'), ed.err || '');
  ok('el resumen: tres bloques con su total —materiales, mano de obra, otros gastos— y el costo directo',
    ed.txt && /= Total de materiales/.test(ed.txt) && /= Total de mano de obra/.test(ed.txt) && /Otros gastos del proyecto\n/.test(ed.txt) && /= Total de otros gastos/.test(ed.txt) && /= Costo directo \(materiales \+ mano de obra \+ otros gastos\)/.test(ed.txt));
  ok('… y el lift en el resumen dice sus semanas', /Renta de lift \(10 días = 2 sem\. × \$500\.00\)/.test(ed.txt));

  ok('sin errores de página', errs.length === 0, errs.join(' | ').slice(0, 200));
  console.log('E39 · OTROS GASTOS DEL PROYECTO\n' + R.join('\n'));
  const mal = R.filter(x => x.startsWith('  ✗')).length;
  console.log(mal ? '\n' + mal + ' FALLAN' : '\nTODO BIEN (' + R.length + ')');
  await b.close(); srv.close(); process.exit(mal ? 1 : 0);
})().catch(e => { console.log(R.join('\n')); console.error(e); process.exit(2); });
