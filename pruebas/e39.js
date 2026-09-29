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
// lo que Edgar puso en su cuenta: $12.130 de generales
const GEN = [
  { cat: 'viajes', desc: 'Viajes Ocala–Broward', cant: 12, uni: 'viaje', costo: 425 },
  { cat: 'permiso', desc: 'Permiso eléctrico', cant: 1, uni: 'lote', costo: 2500 },
  { cat: 'pm', desc: 'PM y supervisión', cant: 20, uni: 'h', costo: 86.5 },
  { cat: 'equipo', desc: 'Lift y disposición de lámparas', cant: 1, uni: 'lote', costo: 1700 },
  { cat: 'overtime', desc: 'Overtime en los apagones', cant: 1, uni: 'lote', costo: 1100 }
];
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
  ok('los cinco renglones de Edgar suman $12.130', cerca(g.subtotal, 12130) && cerca(g.total, 12130), g.subtotal);
  ok('las ocho categorías salen siempre, en su orden, con las vacías (lista de chequeo)', g.porCat.length === 8 && g.porCat[0].id === 'viajes' && g.porCat.find(k => k.id === 'estadia').filas.length === 0);
  ok('viajes: 12 × $425 = $5.100', cerca(g.porCat.find(k => k.id === 'viajes').total, 5100));
  const gc = await p.evaluate(e => window.MXP_PRUEBA.e0.generales(e), { ...BASE, gastos_generales: GEN, generales_colchon_pct: 0.1 });
  ok('el colchón del 10 % sube la lista entera: $12.130 → $13.343', cerca(gc.colchon, 1213) && cerca(gc.total, 13343), gc.total);
  const raro = await p.evaluate(e => window.MXP_PRUEBA.e0.generales(e), { ...BASE, gastos_generales: [{ cat: 'nave', desc: 'x', cant: -3, costo: 'abc' }, null] });
  ok('datos raros no rompen: categoría desconocida → Otros, negativos y texto → 0', raro.filas.length === 2 && raro.filas[0].cat === 'otros' && raro.total === 0, JSON.stringify(raro.filas[0]));
  const vacio = await p.evaluate(e => window.MXP_PRUEBA.e0.generales(e), BASE);
  ok('sin generales, nada: total 0', vacio.total === 0 && vacio.filas.length === 0);

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
  ok('c.generales y c.gen salen del cálculo', cerca(con.generales, 12130) && con.gen && con.gen.porCat.length === 8);

  /* === 3. los papeles === */
  const mep = await p.evaluate(e => { const c = window.MXP_PRUEBA.e0.calcula(e); return window.MXP_PRUEBA.e0.mep(e, c); }, { ...BASE, gastos_generales: GEN });
  ok('el resumen MEP dice los generales, por categoría, y el costo directo', /Generales del proyecto:\s+\$12,130\.00/.test(mep) && /· Viajes y traslado: \$5,100\.00/.test(mep) && /Costo directo:/.test(mep), (mep.match(/Generales.*$/m) || [''])[0]);
  const tk = await p.evaluate(e => { const c = window.MXP_PRUEBA.e0.calcula(e); return window.MXP_PRUEBA.e0.takeoff(e, c); }, { ...BASE, gastos_generales: GEN, generales_colchon_pct: 0.1 });
  ok('el takeoff para copiar los lleva en su bloque, fuera del material', /GENERALES DEL PROYECTO/.test(tk) && /Viajes Ocala–Broward\tgenerales · viajes y traslado\t12\.00\tviaje\t425\.00/.test(tk) && /= GENERALES\t.*13343\.00/.test(tk), (tk.match(/= GENERALES.*$/m) || [''])[0]);
  ok('… y dice el costo directo', /= COSTO DIRECTO/.test(tk));
  const tkMat = tk.split('= MATERIAL')[0];
  ok('ningún general se cuela entre los renglones del material', !/Ocala|Permiso eléctrico/.test(tkMat));

  /* === 4. la tarjeta === */
  const card = await p.evaluate(e => window.MXP_PRUEBA.e0.generalesCard(e, window.MXP_PRUEBA.e0.calcula(e)), { ...BASE, gastos_generales: GEN, generales_colchon_pct: 0.1 });
  ok('la tarjeta dice que va fuera del takeoff y entra al costo directo', /fuera del takeoff/.test(card) && /costo directo/.test(card));
  ok('cada renglón con su cantidad y su costo editables', (card.match(/class="gen-cant"/g) || []).length === 5 && (card.match(/class="gen-costo"/g) || []).length === 5);
  ok('las categorías vacías dicen qué va ahí (hotel y per diem)', /Hotel y per diem/.test(card) && /hotel, comidas por trabajador/.test(card));
  ok('subtotal, colchón y total', /Subtotal de generales/.test(card) && /id="gen-colchon"[^>]*value="10"/.test(card) && /Total de generales/.test(card) && /\$13,343\.00/.test(card));
  ok('la lista del catálogo ofrece solo los de PROJECT GENERAL', /Scissor Lift 19/.test(card) && /Dumpster/.test(card) && !/<option[^>]*>CAJA/.test(card));
  const soloLect = await p.evaluate(e => window.MXP_PRUEBA.e0.generalesCard(e, null, true), { ...BASE, estado: 'congelado', gastos_generales: GEN });
  ok('congelado: se ve sin editar, y solo las categorías con algo', !/gen-cant|gen-nuevo|gen-colchon/.test(soloLect) && /Viajes y traslado/.test(soloLect) && !/Hotel y per diem/.test(soloLect));
  const nada = await p.evaluate(e => window.MXP_PRUEBA.e0.generalesCard(e, null, true), { ...BASE, estado: 'congelado' });
  ok('congelado y sin generales: no hay tarjeta', nada === '');

  /* === 5. lo que está en el takeoff y es general se ofrece pasar === */
  await datos(ITEMS.concat([
    { id: 2, estimado_id: 44, item: "Scissor Lift 19' (electric)", cantidad: 6, precio: 185, horas: 0, unidad: 'DAY', orden: 2 },
    { id: 3, estimado_id: 44, item: 'MOVILIZACIÓN Y ACARREO (por viaje)', cantidad: 2, precio: 0, horas: 4, unidad: 'E', orden: 3 }]));
  const cardM = await p.evaluate(e => window.MXP_PRUEBA.e0.generalesCard(e, window.MXP_PRUEBA.e0.calcula(e)), BASE);
  ok('avisa de los 2 renglones del takeoff que son generales (el lift del catálogo y la movilización de antes)', /Hay 2 renglón\(es\) en el takeoff que son generales/.test(cardM) && /btn-gen-mover/.test(cardM));
  const cats = await p.evaluate(() => ["Scissor Lift 19' (electric)", 'Dumpster Rental (10-15 yd)', 'Per Diem Meals (per worker/day)', 'MOVILIZACIÓN Y ACARREO (por viaje)', 'Electrical Permit (Saint Petersburg)', 'Overtime Premium (per hour)', 'Project Management Fee', 'Consumables/Supplies']
    .map(n => window.MXP_PRUEBA.e0.generalesCatDe(n)).join(','));
  ok('cada general del catálogo cae en su categoría', cats === 'equipo,dispo,estadia,viajes,permiso,overtime,pm,otros', cats);

  /* === 6. las horas del proyecto ya no proponen lift, permiso ni viajes === */
  const h = await p.evaluate(e => window.MXP_PRUEBA.e0.horas([], e, {}), BASE);
  ok('ni lift, ni permiso, ni movilización en las horas del proyecto', !h.filas.some(f => /lift|permiso|movilizacion/.test(f.id)), h.filas.map(f => f.id).join(','));

  /* === 7. el editor entero, con la tarjeta y el resumen === */
  const ed = await p.evaluate(([c, e, cf, it, est]) => {
    window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it, estimados: [est], ensambles: [], estEnsambles: [] });
    try { return window.MXP_PRUEBA.e0.editor(44); } catch (err) { return { err: String(err) }; }
  }, [CAT, ESC, CFG, ITEMS, { ...BASE, gastos_generales: GEN }]);
  ok('el editor se pinta con la tarjeta de Generales y su formulario', ed.ids && ed.ids.includes('btn-gen-poner') && ed.ids.includes('gen-colchon') && ed.ids.includes('gen-lista'), ed.err || '');
  ok('el resumen tiene su sección «Generales del proyecto» y el «Costo directo»', ed.txt && /Generales del proyecto\n/.test(ed.txt) && /Viajes y traslado/.test(ed.txt) && /= Costo directo/.test(ed.txt));

  ok('sin errores de página', errs.length === 0, errs.join(' | ').slice(0, 200));
  console.log('E39 · GENERALES DEL PROYECTO\n' + R.join('\n'));
  const mal = R.filter(x => x.startsWith('  ✗')).length;
  console.log(mal ? '\n' + mal + ' FALLAN' : '\nTODO BIEN (' + R.length + ')');
  await b.close(); srv.close(); process.exit(mal ? 1 : 0);
})().catch(e => { console.log(R.join('\n')); console.error(e); process.exit(2); });
