/* La pantalla del banco (js/conta.js) con la base simulada.
   Lo que se comprueba: que el equipo no ve la entrada y Edgar sí; que la
   pantalla pide el control antes de pintar y se pone en rojo si no cuadra
   (falla ruidosa); que cada botón de la bandeja llama a la función que dijo
   la base con sus argumentos y pide el motivo cuando toca; que el importador
   manda el archivo entero y casa hasta «completo»; que conciliar manda el
   saldo como texto y confirma; y que sin señal no pinta nada de memoria.
   Y la pestaña «Estados» (c4): el selector de período en palabras, el control
   fn_estados_control con las vistas de cada tarjeta (su rojo, el conteo, el
   «Sigue» del tope por reloj, «solo dueño»), resultados, balance, balanza →
   mayor (el saldo que trae en su lado, un ajuste del CPA de otro ejercicio) →
   asiento (la obra con su nombre) → papel (la foto firmada, el rastro roto y
   Storage sin contestar), el flujo por los dos métodos, la comparación con
   QuickBooks y sus vacíos, «←», la carrera de dos clics, sin señal y el
   teléfono a 390 px (las tablas apiladas, la balanza con su columna pegajosa).
   Y los cobros en línea (p1, Stripe): la tarjeta de Bancos (conectado, falta
   configurar, modo de prueba, sin instalar, probar la llave), la 1020 y la 1140
   escondidas de toda lista de bancos, la bandeja con un depósito STRIPE, la
   pestaña «Cobros en línea» con su control (rojo, conteo, alarmas), crear el
   enlace (sin monto, con la casilla «pagada» y la retención) y copiarlo, cada
   estado de un pago y de un depósito, sus acciones con la función `stripe`,
   los errores de la función, sin aal2, sin señal y el teléfono a 390 px.
   Y la organización de v290: la portada «Resumen» (fichas con sus cifras y
   «Qué atender», todo controlado antes de pintar), MXP_CONTA.paginas() y los
   hooks pagina()/volver() del contrato con app.js, las pestañas escondidas en
   la computadora, Bancos sin las tarjetas de conexiones y con el importador
   plegado, «Conexiones y seguridad» con las tres tarjetas, y la bandeja como
   bank feed (buscador, motivo, orden, agrupar por comercio, una fila
   desplegada a la vez y sus botones llamando igual que siempre).
   Y la IA contable (c8, fase 7): sin c8 (v_contador_* en 404) la bandeja es
   la de siempre; con c8, la franja «n propuestas listas · m por proponer ·
   este mes $x de $y» con «Proponer con la IA» (apagado sin el código del
   teléfono, sin la función, sin la llave o con el tope; gira mientras
   espera), el chip de cada fila, «Según la IA» (líneas, motivo, confianza,
   flags, fuente, «Así es» con la obra si la pide, «No es eso») y «Según yo»
   (las cuentas de v_contador_cuentas por grupos y con buscador, la obra según
   la cuenta, el motivo, «Recordar», «Clasificar (igual que la IA)»), cada
   acción con la función `contador` y la sesión, sus errores, la falla
   ruidosa de su control (un cuadre o un conteo en rojo y no se pinta nada de
   la IA), la tarjeta de Conexiones con «Probar» y las reglas con «Quitar»,
   sus alarmas en «Qué atender», y el teléfono y el iPad.
   Y la obra que propone la IA (c8, fase 7b): la base de mentira trae las
   columnas nuevas de v_contador_bandeja (obra_propuesta_id, obra_propuesta,
   obra_confianza, obra_motivo, pistas_resumen) y propuestas_con_obra de
   v_contador_estado, el cuadre 64 y «con_obra» en la respuesta de proponer;
   se comprueba la franja «n propuestas listas (m con obra)», el chip con la
   obra (recortada con «…» en el teléfono, nunca el porcentaje), «Obra: … ·
   78 %» con su porqué, las pistas en gris sin obra, el selector siempre que
   una cuenta admite obra y elegido con la propuesta, «Así es» mandando la
   obra propuesta (aprobada) o la que eligió Edgar (editada), «Según yo» con
   la obra propuesta elegida, una propuesta por regla con la obra de sus
   pistas, y una obra que se cerró después (el 64: no tapa la IA, pide otra).
   Y la 7c (31-oct, tarde: «que cada partida ya tenga su propuesta» y «no me
   sirve un 55 %»): la base de mentira trae quedan en «proponer» (con su
   máximo por ráfaga, los más viejos primero, una cola de fallos y cuántas
   van en vuelo), obras_top y obra_fuerte en v_contador_bandeja, la rutina y
   el marcador del mes en v_contador_estado y la alarma 74; se comprueba la
   cadena que propone sola al abrir la Bandeja (tres ráfagas 40 → 20 → 0, el
   avance en la franja, las filas repintadas, nunca dos a la vez, «Parar»,
   el interruptor de Conexiones, el tope y el contador apagado, el MX008
   «ráfaga en marcha» con su único reintento, un error que la para, que no
   insiste con lo mismo ni tras «No es eso», y tras «Sincronizar ahora»), la
   obra en un toque (tres botones con su pista, «Otra obra…», la débil
   marcada y no elegida, la fuerte sin botones), el chip «¿obra?», el
   marcador y la rutina en la franja, en Conexiones y en «Qué atender», y el
   teléfono y el iPad. Las escenas de antes corren con «Proponer sola»
   apagado (localStorage, como lo deja el interruptor): así siguen probando
   «Proponer ahora» a mano tal cual. La 7b, con sus obras ya calibradas: lo
   que probaba elegido de entrada es una obra fuerte (≥ 80 %).
   Los datos son inventados (la forma es la de las vistas de c4, c6 y p1).
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/conta/pantalla.js
   (con --fotos guarda capturas en el temporal del sistema, o en FOTOS_DIR:
   las de cada escena numeradas y, al final, CADA página a 390, 820 y 1280 px
   de ancho como <ancho>-<pagina>.png; sirven para mirarla sin producción)  */
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..', '..');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.webmanifest': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.woff2': 'font/woff2' };
const srv = http.createServer((req, res) => {
  let p = req.url.split('?')[0]; if (p === '/') p = '/index.html';
  fs.readFile(path.join(ROOT, p), (e, d) => {
    if (e) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); res.end(d);
  });
});
const R = []; const ok = (n, c, d) => R.push((c ? '  ✓ ' : '  ✗ ') + n + (d !== undefined ? '   [' + String(d).slice(0, 160) + ']' : ''));

// ---------- la base de mentira ----------
const UID = 'u-edgar-prueba';
const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
const jwt = aal => `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub: UID, role: 'authenticated', exp: 4102444800, ...(aal ? { aal } : {}) })}.firma`;
const JWT = jwt();
// la sesión que la app guarda: con el nivel (aal) y los factores del segundo factor que diga el estado de la prueba
const sesion = () => ({ access_token: jwt(estado.sesionAal), refresh_token: 'r-prueba', token_type: 'bearer', expires_in: 3600, expires_at: Math.floor(Date.now() / 1000) + 3600, user: { id: UID, factors: estado.mfaFactores } });
// como lo devuelve Supabase Auth (GoTrue, librería SVGo): SVG crudo con prólogo xml, el
// comentario «Generated by SVGo», la etiqueta <svg> en varias líneas y colores con «#»
const QR_FALSO = '<?xml version="1.0"?>\n<!-- Generated by SVGo -->\n<svg width="200" height="200"\n     xmlns="http://www.w3.org/2000/svg"\n     xmlns:xlink="http://www.w3.org/1999/xlink">\n<rect x="0" y="0" width="200" height="200" style="fill:#ffffff;stroke:none"/>\n<rect x="20" y="20" width="60" height="60" style="fill:black;stroke:none"/>\n<rect x="120" y="20" width="60" height="60" style="fill:black;stroke:none"/>\n<rect x="20" y="120" width="60" height="60" style="fill:black;stroke:none"/>\n</svg>\n';
const hoyMiami = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());

const MOV = { a: '11111111-1111-4111-8111-111111111111', b: '22222222-2222-4222-8222-222222222222', c: '33333333-3333-4333-8333-333333333333', s: '55555555-5555-4555-8555-555555555555',
  sf: '66666666-6666-4666-8666-666666666666' };
const PART = { p1: 'aaaaaaaa-0000-4000-8000-000000000001', p2: 'aaaaaaaa-0000-4000-8000-000000000002' };
const CONC_AP = 'cccccccc-0000-4000-8000-00000000000a', CONC_NEW = 'cccccccc-0000-4000-8000-00000000000b';
// ---- los estados (c4): un octubre inventado que cuadra ----
// La apertura al 30-sep: 1010 25,000 + 1050 500 = 2010 4,500 + 2100-2013 9,000 + 3000 12,000. En octubre, ocho asientos:
// a pago a proveedor 1,200 (2010/1010) · f factura 22,000 (1110/4000 20,000 + 4100 2,000) · d recibo 8812 300 (5100/Amex) ·
// g devengo 4,000 (5200/2010) · b cobro 5,000 (1010/1110) · e trabajo externo 7,700 (5100/2010) · c pago Amex 2,300 (Amex/1010) ·
// h statement Amex 2,000 (6130 500 + 6300 1,500 / Amex). Resultado 8,000; activo 44,000 = pasivo 24,000 + capital 20,000.
const ASI = { a: 'aaaaaaaa-1111-4111-8111-111111111111', b: 'aaaaaaaa-2222-4222-8222-222222222222', c: 'aaaaaaaa-3333-4333-8333-333333333333', d: 'aaaaaaaa-4444-4444-8444-444444444444',
  e: 'aaaaaaaa-5555-4555-8555-555555555555', f: 'aaaaaaaa-6666-4666-8666-666666666666', g: 'aaaaaaaa-7777-4777-8777-777777777777', h: 'aaaaaaaa-8888-4888-8888-888888888888',
  i: 'aaaaaaaa-9999-4999-8999-999999999999' };
const HOY = hoyMiami();
// un mes 13 meses después de hoy: existe en periodos (c2 los siembra) pero la pantalla lo esconde tras «Más períodos»
const FUTURO = (() => { const [a, m] = HOY.split('-').map(Number); return new Date(Date.UTC(a, m - 1 + 13, 1)).toISOString().slice(0, 7); })();
const res = (periodo, nivel, seccion, so, linea, lo, orden, cuenta, et, mes, ant, varc, pct, acum, asientos) => ({ periodo, periodo_tipo: 'mes', desde: periodo + '-01', hasta: periodo === '2026-10' ? '2026-10-31' : '2026-11-30', anio: 2026, nivel, seccion, seccion_orden: so, linea, linea_orden: lo, orden, cuenta, etiqueta_es: et, etiqueta_en: et, mes, mes_anterior: ant, variacion: varc, variacion_pct: pct, acumulado: acum, acumulado_desde: '2026-10-01', posteriores: 0, acumulado_ajustado: acum, asientos: nivel === 'cuenta' ? asientos : null, asiento_id: null, numero: null, bajar: {} });
const RES_OCT = [
  res('2026-10', 'cuenta', 'ingresos', 100, 'ingresos', 100, 40000, '4000', 'Ingresos por obra', 20000, null, null, null, 20000, 1),
  res('2026-10', 'cuenta', 'ingresos', 100, 'ingresos', 100, 41000, '4100', 'Cambios de obra', 2000, null, null, null, 2000, 1),
  res('2026-10', 'seccion', 'ingresos', 100, 'ingresos', 100, 100, null, 'Ingresos', 22000, null, null, null, 22000),
  res('2026-10', 'cuenta', 'costo', 200, 'costo', 200, 51000, '5100', 'Material de obra', 8000, null, null, null, 8000, 2),
  res('2026-10', 'cuenta', 'costo', 200, 'costo', 200, 52000, '5200', 'Mano de obra', 4000, null, null, null, 4000, 1),
  res('2026-10', 'seccion', 'costo', 200, 'costo', 200, 200, null, 'Costo de obra', 12000, null, null, null, 12000),
  res('2026-10', 'cuenta', 'gastos', 300, 'gastos', 300, 61300, '6130', 'Cargos bancarios', 500, null, null, null, 500, 1),
  res('2026-10', 'cuenta', 'gastos', 300, 'gastos', 300, 63000, '6300', 'Vehículos', 1500, null, null, null, 1500, 1),
  res('2026-10', 'seccion', 'gastos', 300, 'gastos', 300, 300, null, 'Gastos de operación', 2000, null, null, null, 2000),
  res('2026-10', 'total', 'totales', 9000, 'utilidad_bruta', 250, 250, null, 'Utilidad bruta', 10000, null, null, null, 10000),
  res('2026-10', 'total', 'totales', 9000, 'utilidad_operacion', 350, 350, null, 'Utilidad de operación', 8000, null, null, null, 8000),
  res('2026-10', 'total', 'totales', 9000, 'utilidad_neta', 600, 600, null, 'Utilidad neta', 8000, null, null, null, 8000)
];
// noviembre: las mismas cuentas con su mes anterior (octubre) y la variación que la base calcula
const RES_NOV = [
  res('2026-11', 'cuenta', 'ingresos', 100, 'ingresos', 100, 40000, '4000', 'Ingresos por obra', 18000, 20000, -2000, -10.0, 38000, 1),
  res('2026-11', 'cuenta', 'ingresos', 100, 'ingresos', 100, 41000, '4100', 'Cambios de obra', 2000, 2000, 0, 0.0, 4000, 1),
  res('2026-11', 'seccion', 'ingresos', 100, 'ingresos', 100, 100, null, 'Ingresos', 20000, 22000, -2000, -9.1, 42000),
  res('2026-11', 'cuenta', 'costo', 200, 'costo', 200, 51000, '5100', 'Material de obra', 9000, 8000, 1000, 12.5, 17000, 2),
  res('2026-11', 'cuenta', 'costo', 200, 'costo', 200, 52000, '5200', 'Mano de obra', 4000, 4000, 0, 0.0, 8000, 1),
  res('2026-11', 'seccion', 'costo', 200, 'costo', 200, 200, null, 'Costo de obra', 13000, 12000, 1000, 8.3, 25000),
  res('2026-11', 'cuenta', 'gastos', 300, 'gastos', 300, 61300, '6130', 'Cargos bancarios', 400, 500, -100, -20.0, 900, 1),
  res('2026-11', 'cuenta', 'gastos', 300, 'gastos', 300, 63000, '6300', 'Vehículos', 1500, 1500, 0, 0.0, 3000, 1),
  res('2026-11', 'seccion', 'gastos', 300, 'gastos', 300, 300, null, 'Gastos de operación', 1900, 2000, -100, -5.0, 3900),
  res('2026-11', 'total', 'totales', 9000, 'utilidad_bruta', 250, 250, null, 'Utilidad bruta', 7000, 10000, -3000, -30.0, 17000),
  res('2026-11', 'total', 'totales', 9000, 'utilidad_operacion', 350, 350, null, 'Utilidad de operación', 5100, 8000, -2900, -36.3, 13100),
  res('2026-11', 'total', 'totales', 9000, 'utilidad_neta', 600, 600, null, 'Utilidad neta', 5100, 8000, -2900, -36.3, 13100)
];
const bal = (periodo, nivel, seccion, so, linea, lo, orden, cuenta, comp, et, cifra, asientos, cuadra) => ({ periodo, periodo_tipo: periodo === 'hoy' ? 'hoy' : 'mes', corte: periodo === 'hoy' ? HOY : '2026-10-31', anio: 2026, nivel, seccion, seccion_orden: so, linea, linea_orden: lo, orden, cuenta, componente: comp, etiqueta_es: et, etiqueta_en: et, saldo: nivel === 'total' ? null : cifra, cifra, saldo_ajustado: nivel === 'total' ? null : cifra, cifra_ajustada: cifra, asientos, asiento_id: null, numero: null, cuadra: cuadra === undefined ? null : cuadra, bajar: {} });
const BAL = p => [
  bal(p, 'cuenta', 'activo_circulante', 100, 'efectivo', 110, 10100, '1010', null, 'Chase Checking', 26500, 3),
  bal(p, 'cuenta', 'activo_circulante', 100, 'efectivo', 110, 10500, '1050', null, 'Caja chica', 500, 0),
  bal(p, 'linea', 'activo_circulante', 100, 'efectivo', 110, 110, null, null, 'Efectivo y equivalentes', 27000, null),
  bal(p, 'cuenta', 'activo_circulante', 100, 'cuentas_por_cobrar', 120, 11100, '1110', null, 'Cuentas por cobrar', 17000, 2),
  bal(p, 'linea', 'activo_circulante', 100, 'cuentas_por_cobrar', 120, 120, null, null, 'Cuentas por cobrar', 17000, null),
  bal(p, 'seccion', 'activo_circulante', 100, 'activo_circulante', 100, 100, null, null, 'Activo circulante', 44000, null),
  bal(p, 'cuenta', 'pasivo_circulante', 400, 'cuentas_por_pagar', 420, 20100, '2010', null, 'Cuentas por pagar', 15000, 3),
  bal(p, 'linea', 'pasivo_circulante', 400, 'cuentas_por_pagar', 420, 420, null, null, 'Cuentas por pagar', 15000, null),
  bal(p, 'cuenta', 'pasivo_circulante', 400, 'tarjetas', 440, 21005, '2100-2013', null, 'Amex Business Gold', 9000, 3),
  bal(p, 'linea', 'pasivo_circulante', 400, 'tarjetas', 440, 440, null, null, 'Tarjetas de crédito', 9000, null),
  bal(p, 'seccion', 'pasivo_circulante', 400, 'pasivo_circulante', 400, 400, null, null, 'Pasivo circulante', 24000, null),
  bal(p, 'cuenta', 'capital', 600, 'capital_social', 610, 30000, '3000', null, 'Capital social', 12000, 0),
  bal(p, 'linea', 'capital', 600, 'capital_social', 610, 610, null, null, 'Capital social', 12000, null),
  bal(p, 'componente', 'capital', 600, 'resultado_ejercicio', 660, 0, null, 'resultado', 'Resultado del ejercicio 2026 desde el 01-10-2026 (el libro)', 8000, 8),
  bal(p, 'linea', 'capital', 600, 'resultado_ejercicio', 660, 660, null, null, 'Resultado del ejercicio', 8000, null),
  bal(p, 'seccion', 'capital', 600, 'capital', 600, 600, null, null, 'Capital', 20000, null),
  bal(p, 'total', 'totales', 9000, 'total_activo', 900, 900, null, null, 'Total activo', 44000, 8),
  bal(p, 'total', 'totales', 9000, 'total_pasivo', 910, 910, null, null, 'Total pasivo', 24000, 8),
  bal(p, 'total', 'totales', 9000, 'total_capital', 920, 920, null, null, 'Total capital', 20000, 8),
  bal(p, 'total', 'totales', 9000, 'pasivo_mas_capital', 930, 930, null, null, 'Pasivo más capital', 44000, 8),
  bal(p, 'total', 'totales', 9000, 'cuadra', 940, 940, null, null, 'Activo menos pasivo y capital (debe ser 0)', 0, 8, true)
];
const bza = (orden, cuenta, nombre, estado, seccion, si, d, h, lado, asientos) => ({ periodo: '2026-10', periodo_tipo: 'mes', desde: '2026-10-01', hasta: '2026-10-31', nivel: 'cuenta', orden, cuenta, cuenta_nombre: nombre, componente: null, etiqueta_es: nombre, etiqueta_en: nombre, estado, seccion, linea: seccion, saldo_inicial: si, debe: d, haber: h, saldo_final: si + d - h, saldo_en_su_lado: lado, asientos, asiento_id: null, numero: null, cuadra: null, bajar: {} });
const BZA = [
  bza(10100, '1010', 'Chase Checking', 'balance', 'activo_circulante', 25000, 5000, 3500, 26500, 3), bza(10500, '1050', 'Caja chica', 'balance', 'activo_circulante', 500, 0, 0, 500, 0),
  bza(11100, '1110', 'Cuentas por cobrar', 'balance', 'activo_circulante', 0, 22000, 5000, 17000, 2), bza(20100, '2010', 'Cuentas por pagar', 'balance', 'pasivo_circulante', -4500, 1200, 11700, 15000, 3),
  bza(21005, '2100-2013', 'Amex Business Gold', 'balance', 'pasivo_circulante', -9000, 2300, 2300, 9000, 3), bza(30000, '3000', 'Capital social', 'balance', 'capital', -12000, 0, 0, 12000, 0),
  bza(40000, '4000', 'Ingresos por obra', 'resultados', 'ingresos', 0, 0, 20000, 20000, 1), bza(41000, '4100', 'Cambios de obra', 'resultados', 'ingresos', 0, 0, 2000, 2000, 1),
  bza(51000, '5100', 'Material de obra', 'resultados', 'costo', 0, 8000, 0, 8000, 2), bza(52000, '5200', 'Mano de obra', 'resultados', 'costo', 0, 4000, 0, 4000, 1),
  bza(61300, '6130', 'Cargos bancarios', 'resultados', 'gastos', 0, 500, 0, 500, 1), bza(63000, '6300', 'Vehículos', 'resultados', 'gastos', 0, 1500, 0, 1500, 1),
  { ...bza(999999, null, null, null, null, 0, 44500, 44500, null, 8), nivel: 'total', linea: null, etiqueta_es: 'Totales', etiqueta_en: 'Totals', cuadra: true }
];
const may = (id, numero, fecha, desc, monto, saldo, cuenta, nombre, normal, pos, extra) => ({ asiento_id: id, numero, orden: 1, fecha, periodo: '2026-10', periodo_efectivo: '2026-10', anio: 2026, ejercicio: 2026, tipo: 'normal', camino: 'puente', descripcion: desc, memo: null, origen_tabla: 'recibos', cuenta, cuenta_nombre: nombre, saldo_normal: normal, monto, debe: monto > 0 ? monto : 0, haber: monto < 0 ? -monto : 0, saldo, saldo_en_su_lado: normal === 'debe' ? saldo : -saldo, reversado: false, proyecto_id: null, cadena_pos: pos, ...(extra || {}) });
const MAY = [
  may(ASI.a, '2026-000401', '2026-10-02', 'Pago a proveedor', -1200, 23800, '1010', 'Chase Checking', 'debe', 401), may(ASI.b, '2026-000412', '2026-10-15', 'Cobro de obra', 5000, 28800, '1010', 'Chase Checking', 'debe', 412, { origen_tabla: 'cobros' }),
  may(ASI.c, '2026-000420', '2026-10-20', 'Pago Amex', -2300, 26500, '1010', 'Chase Checking', 'debe', 420, { origen_tabla: null, camino: 'mano' }),
  may(ASI.d, '2026-000405', '2026-10-07', 'Recibo 8812 Ferretería Ejemplo', 300, 300, '5100', 'Material de obra', 'debe', 405, { proyecto_id: 'casa-perez-k3m9', memo: 'Recibo 8812' }),
  may(ASI.e, '2026-000418', '2026-10-18', 'Trabajo externo 51 · material', 7700, 8000, '5100', 'Material de obra', 'debe', 418, { origen_tabla: 'trabajos_externos', proyecto_id: 'casa-perez-k3m9' }),
  may(ASI.d, '2026-000405', '2026-10-07', 'Recibo 8812 Ferretería Ejemplo', -300, -9300, '2100-2013', 'Amex Business Gold', 'haber', 405), may(ASI.c, '2026-000420', '2026-10-20', 'Pago Amex', 2300, -7000, '2100-2013', 'Amex Business Gold', 'haber', 420, { origen_tabla: null, camino: 'mano' }),
  may(ASI.h, '2026-000425', '2026-10-22', 'Statement Amex · gastos', -2000, -9000, '2100-2013', 'Amex Business Gold', 'haber', 425, { origen_tabla: 'recibos' }),
  // un ajuste del CPA al cierre de 2026 posteado en enero de 2027: v_mayor lo lista en 2027 pero lo corre con el saldo de 2026, y v_balanza de 2027 no trae la cuenta
  may(ASI.i, '2027-000002', '2027-01-15', 'Ajuste del CPA · depreciación 2026', 400, 1900, '6300', 'Vehículos', 'debe', 2, { periodo: '2027-01', periodo_efectivo: '2026-12', anio: 2027, ejercicio: 2026, tipo: 'ajuste_cpa', camino: 'mano', origen_tabla: null })
];
const lib = (id, numero, fecha, desc, orden, cuenta, nombre, debe, haber, extra) => ({ asiento_id: id, numero, orden, fecha, periodo: '2026-10', periodo_efectivo: '2026-10', anio: 2026, ejercicio: 2026, tipo: 'normal', camino: 'puente', descripcion: desc, motivo: null, reversa_a: null, sustituye_a: null, origen_tabla: 'recibos', origen_id: id === ASI.d ? '8812' : '7001', documento_ruta: null, cadena_pos: id === ASI.d ? 405 : 401, cuenta, cuenta_nombre: nombre, debe, haber, monto: debe - haber, memo: null, proyecto_id: null, cost_code: null, tercero_tipo: null, tercero_id: null, partida_tabla: null, partida_id: null, ...(extra || {}) });
const LIB = [
  lib(ASI.a, '2026-000401', '2026-10-02', 'Pago a proveedor', 1, '2010', 'Cuentas por pagar', 1200, 0), lib(ASI.a, '2026-000401', '2026-10-02', 'Pago a proveedor', 2, '1010', 'Chase Checking', 0, 1200),
  lib(ASI.d, '2026-000405', '2026-10-07', 'Recibo 8812 Ferretería Ejemplo', 1, '5100', 'Material de obra', 300, 0, { proyecto_id: 'casa-perez-k3m9', memo: 'Recibo 8812', tercero_tipo: 'proveedor', tercero_id: 'Ferretería Ejemplo' }),
  lib(ASI.d, '2026-000405', '2026-10-07', 'Recibo 8812 Ferretería Ejemplo', 2, '2100-2013', 'Amex Business Gold', 0, 300)
];
const PAP = [
  { asiento_id: ASI.d, numero: '2026-000405', fecha: '2026-10-07', periodo: '2026-10', tipo: 'normal', camino: 'puente', descripcion: 'Recibo 8812 Ferretería Ejemplo', origen_tabla: 'recibos', origen_id: '8812', documento_ruta: 'recibos/casa-perez/1712.jpg', reversa_a: null, sustituye_a: null, reversado: false, papel_existe: true, papel: 'Recibo 8812 · Ferretería Ejemplo · #4471 · 2026-10-07 · aprobado', papel_ruta: 'recibos/casa-perez/1712.jpg' },
  // el papel de este recibo ya no está en su tabla: rastro roto
  { asiento_id: ASI.a, numero: '2026-000401', fecha: '2026-10-02', periodo: '2026-10', tipo: 'normal', camino: 'puente', descripcion: 'Pago a proveedor', origen_tabla: 'recibos', origen_id: '7001', documento_ruta: null, reversa_a: null, sustituye_a: null, reversado: false, papel_existe: false, papel: 'recibos 7001 (el papel ya no está)', papel_ruta: null }
];
const fl = (metodo, nivel, seccion, so, linea, lo, et, importe, asientos, cuadra) => ({ periodo: '2026-10', periodo_tipo: 'mes', desde: '2026-10-01', hasta: '2026-10-31', metodo, nivel, seccion, seccion_orden: so, linea, linea_orden: lo, etiqueta_es: et, etiqueta_en: et, importe, asientos: asientos == null ? null : asientos, asiento_id: null, numero: null, cuadra: cuadra === undefined ? null : cuadra, bajar: {} });
// cada método sale ENTERO: sus renglones (aunque valgan 0.00), 5 secciones (la de ajustes se duplica como línea; sin_dinero se revela, importe nulo), 3 totales y 5 controles
const flujoMetodo = (m, lineas) => [
  ...lineas,
  fl(m, 'seccion', 'operacion', 100, 'operacion', 100, 'Actividades de operación', 1500), fl(m, 'seccion', 'inversion', 200, 'inversion', 200, 'Actividades de inversión', 0), fl(m, 'seccion', 'financiamiento', 300, 'financiamiento', 300, 'Actividades de financiamiento', 0),
  fl(m, 'seccion', 'ajustes', 400, 'ajustes', 400, 'Ajustes', 0), fl(m, 'linea', 'ajustes', 400, 'ajustes', 400, 'Ajustes', 0, 0), fl(m, 'seccion', 'sin_dinero', 500, 'sin_dinero', 500, 'Actividades sin dinero (se revelan; no suman)', null),
  fl(m, 'linea', 'sin_dinero', 500, 'sd_inversion', 510, 'Inversión sin dinero', 0, 0), fl(m, 'linea', 'sin_dinero', 500, 'sd_financiamiento', 520, 'Financiamiento sin dinero', 0, 0),
  fl(m, 'total', 'totales', 9000, 'efectivo_inicial', 900, 'Efectivo al inicio (con lo que trajo la apertura del 30-09-2026)', 25500, 1), fl(m, 'total', 'totales', 9000, 'cambio', 910, 'Cambio en el efectivo', 1500, 3), fl(m, 'total', 'totales', 9000, 'efectivo_final', 920, 'Efectivo al final', 27000, 3),
  fl(m, 'control', 'totales', 9999, 'cuadra', 9999, 'Diferencia contra el cambio del efectivo y contra el otro método (debe ser 0)', 0, null, true),
  ...['operacion', 'inversion', 'financiamiento', 'ajustes'].map((s, i) => fl(m, 'control', 'totales', 9999, 'cuadra_' + s, 10099 + i * 100, 'Actividades de ' + s + ': indirecto contra directo (debe ser 0)', 0, null, true))
];
const FLU = [
  ...flujoMetodo('directo', [fl('directo', 'linea', 'operacion', 100, 'cobros_clientes', 110, 'Cobros de clientes', 5000, 1), fl('directo', 'linea', 'operacion', 100, 'proveedores', 120, 'Pagos a proveedores', -1200, 1), fl('directo', 'linea', 'operacion', 100, 'tarjetas', 130, 'Pagos de tarjetas', -2300, 1), fl('directo', 'linea', 'operacion', 100, 'nomina', 140, 'Nómina', 0, 0),
    fl('directo', 'linea', 'inversion', 200, 'activos_fijos', 210, 'Compra de activos fijos', 0, 0), fl('directo', 'linea', 'financiamiento', 300, 'prestamos', 310, 'Préstamos', 0, 0), fl('directo', 'linea', 'financiamiento', 300, 'dueno', 330, 'Aportaciones y retiros del dueño', 0, 0)]),
  ...flujoMetodo('indirecto', [fl('indirecto', 'linea', 'operacion', 100, 'resultado', 101, 'Utilidad neta del ejercicio', 8000, 8), fl('indirecto', 'linea', 'operacion', 100, 'op_cxc', 120, 'Cuentas por cobrar', -17000, 2), fl('indirecto', 'linea', 'operacion', 100, 'op_cxp', 130, 'Cuentas por pagar', 10500, 3), fl('indirecto', 'linea', 'operacion', 100, 'op_tarjetas', 140, 'Tarjetas', 0, 3),
    fl('indirecto', 'linea', 'inversion', 200, 'activos_fijos', 210, 'Compra de activos fijos', 0, 0), fl('indirecto', 'linea', 'financiamiento', 300, 'fin_accionista', 320, 'Préstamo del accionista', 0, 0)])
];
// la comparación «como QuickBooks»: debe − haber sin el signo del estado (pasivos, capital e ingresos en negativo)
const cmp = (orden, cuenta, nombre, qbn, libro, qb, expl, okk, clases, extra) => ({ periodo: '2026-10', periodo_tipo: 'mes', corte: '2026-10-31', al: '2026-10-31', documento: 'docs/qb/balanza-2026-10-31.csv', anio: 2026, nivel: 'cuenta', cuenta, cuenta_nombre: nombre, estado: Number(cuenta) >= 4000 ? 'resultados' : 'balance', orden, cuenta_qb: null, cuentas_qb: qbn ? [qbn] : null, libro, arrastre_apertura: 0, posteriores: 0, comparable: libro, qb, diferencia: Math.round((libro - qb) * 100) / 100, explicada: expl, sin_explicar: Math.round((libro - qb - expl) * 100) / 100, ok: okk, clases, anotadas: clases ? clases.length : 0, asientos: 1, asiento_id: null, numero: null, bajar: {}, ...(extra || {}) });
const CMP = [
  cmp(10100, '1010', 'Chase Checking', 'Chase Chk 4392', 26500, 26400, 100, true, ['puente']), cmp(10500, '1050', 'Caja chica', 'Petty Cash', 500, 500, 0, true, null), cmp(11100, '1110', 'Cuentas por cobrar', 'Accounts Receivable', 17000, 17000, 0, true, null),
  cmp(20100, '2010', 'Cuentas por pagar', 'Accounts Payable', -15000, -15000, 0, true, null), cmp(21005, '2100-2013', 'Amex Business Gold', 'Amex Gold', -9000, -9000, 0, true, null), cmp(30000, '3000', 'Capital social', 'Common Stock', -12000, -12000, 0, true, null),
  cmp(40000, '4000', 'Ingresos por obra', 'Contract Income', -20000, -19900, 0, false, null), cmp(41000, '4100', 'Cambios de obra', 'Change Orders', -2000, -2000, 0, true, null),
  cmp(51000, '5100', 'Material de obra', 'Job Materials', 8000, 8000.40, 0, false, null), cmp(52000, '5200', 'Mano de obra', 'Labor', 4000, 4000, 0, true, null),
  cmp(61300, '6130', 'Cargos bancarios', 'Bank Charges', 500, 500, 0, true, null), cmp(63000, '6300', 'Vehículos', 'Vehicles', 1500, 1500, 0, true, null),
  cmp(999999, null, null, null, 0, 50, 0, false, null, { nivel: 'sin_mapeo', estado: null, cuenta_qb: 'QB Misterio', asientos: 0 })
];
const CORTES = [
  { periodo: 'hoy', tipo: 'hoy', anio: Number(HOY.slice(0, 4)), desde: HOY.slice(0, 8) + '01', corte: HOY, estado: 'abierto', paralelo: true },
  { periodo: FUTURO, tipo: 'mes', anio: Number(FUTURO.slice(0, 4)), desde: FUTURO + '-01', corte: FUTURO + '-28', estado: 'abierto', paralelo: false },
  { periodo: '2027', tipo: 'anio', anio: 2027, desde: '2027-01-01', corte: '2027-12-31', estado: 'abierto', paralelo: false },
  { periodo: '2026-11', tipo: 'mes', anio: 2026, desde: '2026-11-01', corte: '2026-11-30', estado: 'abierto', paralelo: true },
  { periodo: '2026-10', tipo: 'mes', anio: 2026, desde: '2026-10-01', corte: '2026-10-31', estado: 'abierto', paralelo: true },
  { periodo: '2026-09-APERTURA', tipo: 'apertura', anio: 2026, desde: '2026-09-30', corte: '2026-09-30', estado: 'cerrado', paralelo: true },
  { periodo: '2026', tipo: 'anio', anio: 2026, desde: '2026-01-01', corte: '2026-12-31', estado: 'abierto', paralelo: true }
];
const saldo = (cuenta, nombre, tipo, libros, banco, al, pend, pendMonto) => ({
  cuenta, cuenta_nombre: nombre, tipo, activa: true, saldo_libros: libros, saldo_libros_como_banco: tipo === 'tarjeta' ? -libros : libros,
  ultimo_archivo_id: banco == null ? null : 'f-' + cuenta, ultimo_archivo: banco == null ? null : `Archivo de prueba ${cuenta}`, ultimo_importado_el: banco == null ? null : '2026-10-16T14:00:00+00:00',
  saldo_banco: banco, saldo_banco_como_banco: banco == null ? null : (tipo === 'tarjeta' ? -banco : banco), saldo_banco_al: al, saldo_libros_al: banco == null ? null : libros,
  pendientes: pend, pendientes_monto: pendMonto, pendiente_mas_viejo: pend ? '2026-10-02' : null, en_transito: 0,
  ultima_conciliacion_id: CONC_AP, ultima_conciliacion: '2026-09-30', ultima_conciliacion_estado: 'confirmada', ultima_conciliacion_diferencia: 0,
  ultima_confirmada: '2026-09-30', dias_sin_conciliar: 16, alarma: false, alarma_texto: '', cubierto_hasta: al, mes_sin_cubrir: null
});
const T = {
  perfiles: [{ id: UID, nombre: 'Edgar Prueba', rol: 'dueno' }],
  v_banco_saldos: [
    saldo('1010', 'Banco operativo', 'banco', 16457.20, null, null, 0, 0),
    // la puente de Stripe (p1): para c6 es un banco más; la pantalla no la pinta ni la ofrece
    saldo('1020', 'Stripe — cobros en tránsito', 'banco', 1000, null, null, 0, 0),
    saldo('1030', 'Reserva de impuestos', 'banco', 0, null, null, 0, 0),
    saldo('2100-2009', 'Amex Business Blue', 'tarjeta', -8596.11, null, null, 0, 0),
    saldo('2100-2013', 'Amex Business Gold', 'tarjeta', -14624.26, -14675.12, '2026-10-08', 3, -50.86)
  ],
  v_banco_bandeja: [
    { movimiento_id: MOV.a, cuenta: '2100-2013', cuenta_nombre: 'Amex Business Gold', fecha: '2026-10-02', periodo: '2026-10', monto: -123.45, descripcion: 'FERRETERIA EJEMPLO TAMPA FL', memo: null, cheque: null, tipo_banco: 'DEBIT',
      motivo: 'sin_ticket', texto: 'Sin ticket ni asiento que lo explique. Si tienes la foto del recibo, súbela: entra por su puente y casa sola. Si no, di de qué es.', opciones: null, obra: null, propuesta: { motivo: 'sin_ticket' },
      posible_duplicado_de: null, duplicado_fecha: null, duplicado_descripcion: null, duplicado_origen: null, dias: 14, alarma: false, origen: 'archivo', archivo_id: 'f-2100-2013', importado_el: '2026-10-16T14:00:00+00:00' },
    { movimiento_id: MOV.b, cuenta: '2100-2013', cuenta_nombre: 'Amex Business Gold', fecha: '2026-10-05', periodo: '2026-10', monto: 500.00, descripcion: 'ONLINE PAYMENT - THANK YOU', memo: null, cheque: null, tipo_banco: 'CREDIT',
      motivo: 'partida_apertura', texto: 'Puede ser una partida en tránsito de la conciliación de apertura. Si lo es, cásala; si no, es dinero entre cuentas propias.',
      opciones: [
        { texto: 'Es la partida en tránsito del 30-sep: Pago desde el banco del 2026-09-21 por 500.00', llamar: 'fn_banco_casar_con', args: { p_movimiento: MOV.b, p_con: { partida_apertura: PART.p1 } } },
        { texto: 'Es la partida en tránsito del 30-sep: Pago desde el banco del 2026-09-22 por 500.00', llamar: 'fn_banco_casar_con', args: { p_movimiento: MOV.b, p_con: { partida_apertura: PART.p2 } } },
        { texto: 'Desde 1010 (Banco operativo)', llamar: 'fn_banco_transferencia', pide_motivo: true, pide: ['p_motivo'], args: { p_movimiento: MOV.b, p_cuenta: '1010' } },
        { texto: 'Desde 1030 (Reserva de impuestos)', llamar: 'fn_banco_transferencia', pide_motivo: true, pide: ['p_motivo'], args: { p_movimiento: MOV.b, p_cuenta: '1030' } },
        // c6 la propone porque la 1020 es «banco propio»: la pantalla la quita (es de Stripe)
        { texto: 'Desde 1020 (Stripe — cobros en tránsito)', llamar: 'fn_banco_transferencia', pide_motivo: true, pide: ['p_motivo'], args: { p_movimiento: MOV.b, p_cuenta: '1020' } }
      ], obra: null, propuesta: { motivo: 'partida_apertura' }, posible_duplicado_de: null, duplicado_fecha: null, duplicado_descripcion: null, duplicado_origen: null, dias: 11, alarma: false, origen: 'archivo', archivo_id: 'f-2100-2013', importado_el: '2026-10-16T14:00:00+00:00' },
    { movimiento_id: MOV.c, cuenta: '2100-2013', cuenta_nombre: 'Amex Business Gold', fecha: '2026-10-06', periodo: '2026-10', monto: -61.21, descripcion: 'PEAJE EJEMPLO', memo: 'peaje', cheque: null, tipo_banco: 'DEBIT',
      motivo: 'posible_duplicado', texto: '¿Es el mismo movimiento que el del 2026-10-05 por -61.21?', opciones: [
        { texto: 'Es el mismo (no entra)', llamar: 'fn_banco_duplicado', args: { p_movimiento: MOV.c, p_es_el_mismo: true } },
        { texto: 'Es otro movimiento', llamar: 'fn_banco_duplicado', args: { p_movimiento: MOV.c, p_es_el_mismo: false } }
      ], obra: null, propuesta: { motivo: 'posible_duplicado' }, posible_duplicado_de: MOV.a, duplicado_fecha: '2026-10-05', duplicado_descripcion: 'PEAJE EJEMPLO', duplicado_origen: 'archivo', dias: 40, alarma: true, origen: 'archivo', archivo_id: 'f-2100-2013', importado_el: '2026-10-16T14:00:00+00:00' }
  ],
  cuentas: [
    ['1010', 'Banco operativo', 'activo', 'prohibida'], ['1050', 'Efectivo (caja chica)', 'activo', 'prohibida'], ['2100-2013', 'Amex Business Gold', 'pasivo', 'prohibida'],
    ['3200', 'Distribuciones al accionista', 'capital', 'prohibida'], ['5100', 'Material', 'costo', 'obligatoria'], ['6130', 'Cargos bancarios', 'gasto', 'prohibida'],
    ['6300', 'Vehículos', 'gasto', 'prohibida'], ['7100', 'Intereses', 'otro_gasto', 'prohibida']
  ].map(([codigo, nombre, tipo, regla_obra]) => ({ codigo, nombre, tipo, regla_obra, imputable: true, activa: true })),
  proyectos: [{ id: 'casa-perez-k3m9', nombre: 'Casa Pérez', estado: 'ejecucion' }, { id: 'oficina-nch-7xq2', nombre: 'Oficina NCH', estado: 'ejecucion' }, { id: 'taller-ruiz-5b2n', nombre: 'Taller Ruiz', estado: 'completado' }],
  v_conciliacion: [
    { conciliacion_id: CONC_AP, cuenta: '2100-2013', cuenta_nombre: 'Amex Business Gold', fecha_corte: '2026-09-30', periodo: '2026-09', tipo: 'apertura', estado: 'confirmada', saldo_libros: -14624.26, saldo_statement: 14610.43, saldo_banco: -14610.43,
      depositos_transito: 3500, cargos_circulacion: 3513.83, sin_casar_banco: 0, n_transito: 27, n_sin_casar: 0, n_alarmas: 0, n_dudosas: 0, n_pide_motivo: 0, diferencia: 0, lista_para_confirmar: false, identidad: 'Libros -14624.26 = banco -14610.43 + (3500.00 − 3513.83) − 0 (cuadra)', falta: null, confirmada_el: '2026-10-16T14:00:00+00:00' }
  ],
  v_conciliacion_partidas: [
    { conciliacion_id: CONC_AP, cuenta: '2100-2013', fecha_corte: '2026-09-30', conciliacion_estado: 'confirmada', grupo: 'en_libros_no_en_banco', partida_id: PART.p1, clase: 'deposito_en_transito', fecha: '2026-09-21', monto: 500, descripcion: 'Pago desde el banco (09/21)', cheque: null, dias: 0, alarma: false, motivo: 'De la conciliación de QuickBooks al 30-sep', explicacion: 'De la era QuickBooks: en tránsito al 30-sep.', asiento_numero: null, resuelta_en: null, resuelta_por_movimiento: null },
    { conciliacion_id: CONC_AP, cuenta: '2100-2013', fecha_corte: '2026-09-30', conciliacion_estado: 'confirmada', grupo: 'en_libros_no_en_banco', partida_id: PART.p2, clase: 'deposito_en_transito', fecha: '2026-09-22', monto: 500, descripcion: 'Pago desde el banco (09/22)', cheque: null, dias: 0, alarma: false, motivo: 'De la conciliación de QuickBooks al 30-sep', explicacion: 'De la era QuickBooks: en tránsito al 30-sep.', asiento_numero: null, resuelta_en: null, resuelta_por_movimiento: null }
  ],
  v_plaid_conexiones: [
    { id: 'px-1', item_id: 'item-prueba', institucion_id: 'ins_1', institucion: 'Platypus Bank', estado: 'activa',
      cuentas: [
        { account_id: 'acc-tarjeta', mask: '2013', nombre: 'Business Gold Card', oficial: 'American Express Business Gold', tipo: 'credit', subtipo: 'credit card', cuenta: '2100-2013', propuesta: 'tarjeta ····2013 dada de alta en 2100-2013' },
        { account_id: 'acc-corriente', mask: '4392', nombre: 'Business Complete Checking', oficial: null, tipo: 'depository', subtipo: 'checking' }
      ], cuentas_sin_fijar: 1, sincronizada_alguna_vez: false, ultimo_sync: null, ultimo_error: null, ultimo_resultado: null,
      creado_por: UID, creado_el: '2026-10-17T12:00:00+00:00', desconectada_el: null, desconectada_motivo: null }
  ],
  v_banco_movimientos: [
    { movimiento_id: MOV.a, cuenta: '2100-2013', fecha: '2026-10-02', monto: -123.45, descripcion: 'FERRETERIA EJEMPLO TAMPA FL', memo: null, cheque: null, tipo_banco: 'DEBIT', estado: 'pendiente', estado_motivo: null, casado_clase: null, casado_regla: null, casado_auto: null, asiento_numero: null, papel_tabla: null, papel_id: null, archivo: 'Archivo de prueba', propuesta_motivo: 'sin_ticket' },
    { movimiento_id: 'm-casado', cuenta: '2100-2013', fecha: '2026-10-01', monto: -31.56, descripcion: 'GASOLINERA EJEMPLO', memo: null, cheque: null, tipo_banco: 'DEBIT', estado: 'casado', estado_motivo: null, casado_clase: 'apertura', casado_regla: 'R0 apertura', casado_auto: true, asiento_numero: null, papel_tabla: null, papel_id: null, archivo: 'Archivo de prueba', propuesta_motivo: null }
  ],
  // los estados (c4): octubre con cifras, noviembre solo en resultados, nada para el año ni la apertura (0 filas = vacío legítimo)
  v_cortes: CORTES, v_resultados: [...RES_OCT, ...RES_NOV], v_balance_general: [...BAL('2026-10'), ...BAL('hoy')], v_balanza: BZA, v_mayor: MAY, v_libro: LIB, v_asiento_papel: PAP, v_flujo_caja: FLU,
  v_comparacion_resumen: [{ periodo: '2026-10', periodo_tipo: 'mes', corte: '2026-10-31', cuentas: 12, cuentas_ok: 10, cuentas_mal: 3, sin_mapeo: 1, sin_explicar: 150.40, ok: false, utilidad_libro: 8000, utilidad_qb: 7900, utilidad_diferencia: 100, utilidad_mes_libro: 8000, utilidad_mes_qb: 7900, periodo_anterior: '2026-09-APERTURA', bajar: {} }],
  v_comparacion: CMP
};
// ---- los cobros en línea (p1): la forma de las vistas v_stripe_* ----
const ESTADO_STRIPE = { instalado: true, modo: 'real', acepta_prueba: false, dueno: UID, desde: '2026-10-20T12:00:00+00:00', funcion_url: 'https://ejemplo.supabase.co/functions/v1/stripe', rutina_activa: true,
  cuenta_puente: '1020', cuenta_puente_nombre: 'Stripe — cobros en tránsito', cuenta_paso: '1140', cuenta_comisiones: '6130', cuenta_banco: '1010',
  saldo_puente: 4000, saldo_paso: 0, por_depositar: 4000, n_por_depositar: 2, vueltos_sin_liquidar: 0, en_camino_monto: 4200.50, en_camino_n: 2, enlaces_activos: 1,
  ultimo_evento_el: '2026-10-26T15:00:00+00:00', ultimo_evento_tipo: 'payment_intent.succeeded', eventos_pendientes: 0, eventos_revisar: 0,
  ultimo_barrido_el: '2026-10-27T13:07:00+00:00', ultimo_barrido_completo_el: '2026-10-27T13:07:00+00:00', ultimo_error: null, ultimo_error_el: null,
  avisos_abiertos: 2, pagos_revisar: 1, payouts_pendientes: 4, cuadres_rojos: 0, alarmas: 0 };
const fac = (id, num, obra, cliente, monto, pagada, cxc, ret, extra) => ({ factura_id: id, num, fecha: '2026-10-0' + id, proyecto_id: 'obra-' + id, obra, cliente, monto_factura: monto, pagada, en_libro: true,
  saldo_cxc: cxc, saldo_retencion: ret, enlace_id: null, enlace_estado: null, enlace_url: null, enlace_monto: null, enlace_con_retencion: null, enlace_creado_el: null, enlace_desfasado: false,
  en_camino_monto: 0, en_camino_n: 0, puede_enlace: true, por_que_no: null, ...(extra || {}) });
const pag = (pi, estado, pantalla, medio, monto, fnum, extra) => ({ id: 'sp-' + pi, pi, estado, estado_pantalla: pantalla, estado_stripe: 'succeeded', medio, monto, objetivo: monto, en_libro: monto, reembolsado: 0, disputa_retirada: 0,
  disputa_estado: null, disputa_vence: null, factura_id: fnum ? Number(fnum) - 1100 : null, factura_num: fnum, obra: fnum ? 'Casa Pérez' : null, enlace_id: null, cobro_asiento: null, cobrado_el: null, ultimo_cambio_el: null,
  falta_depositar: 0, payouts: [], deposito_fecha: null, fallo: null, revisar: null, resuelto: null, dias: 3, creado_el: '2026-10-24T14:00:00+00:00', actualizado_el: '2026-10-24T14:00:00+00:00', ...(extra || {}) });
const pay = (po, estado, pantalla, monto, llegada, extra) => ({ id: 'py-' + po, po, estado, estado_pantalla: pantalla, estado_stripe: 'paid', monto, llegada, bruto: null, comisiones: null, vuelve: null, fuera: null, otros: null, n_pagos: null,
  fecha_asiento: null, asiento_salida_num: null, asiento_llegada_num: null, asiento_vuelta_num: null, reversado: false, movimiento_id: null, movimiento_fecha: null, movimiento_descripcion: null,
  casado_regla: null, casado_automatico: null, candidatos: [], dias_sin_casar: null, revisar: null, esperando: null, lineas: [], creado_el: llegada + 'T12:00:00+00:00', ...(extra || {}) });
const DEP_STRIPE = 'ORIG CO NAME:STRIPE CO ENTRY DESCR:TRANSFER SEC:CCD IND ID:ST-PRUEBA0001';
T.v_stripe_estado = [ESTADO_STRIPE];
T.v_stripe_facturas = [
  fac(1, '1101', 'Casa Pérez', 'Cliente Uno', 5000, true, 5000, 0),
  fac(2, '1102', 'Oficina NCH', 'Cliente Dos', 3200.50, false, 3200.50, 0, { en_camino_monto: 3200.50, en_camino_n: 1, puede_enlace: false, por_que_no: 'pago en camino' }),
  fac(3, '1103', 'Taller Ruiz', 'Cliente Tres', 8000, false, 8000, 0),
  fac(4, '1104', 'Casa Pérez', 'Cliente Uno', 1000, false, 900, 100, { enlace_id: 'e-1104', enlace_estado: 'activo', enlace_url: 'https://buy.stripe.com/test_prueba1104', enlace_monto: 1000, enlace_con_retencion: false, enlace_creado_el: '2026-10-22T13:00:00+00:00', enlace_desfasado: true })
];
T.v_stripe_pagos = [
  pag('pi_PRUEBA01', 'iniciado', 'iniciado', 'ach', 1000, '1105', { estado_stripe: 'requires_action', objetivo: 0, en_libro: 0 }),
  pag('pi_PRUEBA02', 'en_camino', 'en_camino', 'ach', 3200.50, '1102', { estado_stripe: 'processing', objetivo: 0, en_libro: 0 }),
  pag('pi_PRUEBA03', 'cobrado', 'cobrado', 'tarjeta', 1000, '1106', { objetivo: 900, en_libro: 900, reembolsado: 100, cobro_asiento: '2026-000501', cobrado_el: '2026-10-24', falta_depositar: 900 }),
  pag('pi_PRUEBA04', 'cobrado', 'en_payout', 'tarjeta', 1000, '1107', { cobro_asiento: '2026-000502', cobrado_el: '2026-10-21', payouts: ['po_PRUEBA04'] }),
  pag('pi_PRUEBA05', 'cobrado', 'depositado', 'tarjeta', 500, '1108', { cobro_asiento: '2026-000503', cobrado_el: '2026-10-19', payouts: ['po_PRUEBA05'], deposito_fecha: '2026-10-21' }),
  pag('pi_PRUEBA06', 'devuelto', 'devuelto', 'tarjeta', 400, '1109', { objetivo: 0, en_libro: 0, reembolsado: 400 }),
  pag('pi_PRUEBA07', 'en_disputa', 'en_disputa', 'tarjeta', 3000, '1110', { objetivo: 0, en_libro: 0, disputa_retirada: 3000, disputa_estado: 'needs_response', disputa_vence: '2026-11-10' }),
  pag('pi_PRUEBA08', 'fallido', 'fallido', 'ach', 2000, '1111', { estado_stripe: 'requires_payment_method', objetivo: 0, en_libro: 0, fallo: 'Fondos insuficientes' }),
  pag('pi_PRUEBA09', 'revisar', 'revisar', 'tarjeta', 250, null, { objetivo: 250, en_libro: 0, revisar: 'no salió de un enlace de la app' })
];
T.v_stripe_payouts = [
  pay('po_PRUEBA01', 'en_camino', 'en_camino', 970.70, '2026-10-29', { estado_stripe: 'in_transit' }),
  pay('po_PRUEBA02', 'esperando_composicion', 'esperando_composicion', 500, '2026-10-26'),
  pay('po_PRUEBA03', 'esperando_cobros', 'esperando_cobros', 1000, '2026-10-25', { esperando: [{ pi: 'pi_PRUEBA10', motivo: 'sin datos del pago' }] }),
  pay('po_PRUEBA04', 'asentado', 'asentado', 1365.70, '2026-10-23', { bruto: 1400, comisiones: 34.30, n_pagos: 2, fecha_asiento: '2026-10-23', asiento_salida_num: '2026-000510', asiento_llegada_num: '2026-000511', dias_sin_casar: 4,
    candidatos: [{ id: MOV.s, fecha: '2026-10-24', descripcion: DEP_STRIPE }],
    lineas: [{ txn: 'txn_PRUEBA41', tipo: 'charge', clase: 'pago', monto: 1000, comision: 29.30, neto: 970.70, factura_num: '1107', pi: 'pi_PRUEBA04', cuenta: null },
      { txn: 'txn_PRUEBA42', tipo: 'payment', clase: 'pago', monto: 400, comision: 4, neto: 396, factura_num: '1109', pi: 'pi_PRUEBA06', cuenta: null },
      { txn: 'txn_PRUEBA43', tipo: 'stripe_fee', clase: 'comision', monto: -1, comision: 0, neto: -1, factura_num: null, pi: null, cuenta: null }] }),
  pay('po_PRUEBA05', 'asentado', 'casado', 485.20, '2026-10-21', { bruto: 500, comisiones: 14.80, n_pagos: 1, asiento_salida_num: '2026-000505', asiento_llegada_num: '2026-000506', movimiento_id: 'm-dep-5', movimiento_fecha: '2026-10-21',
    movimiento_descripcion: DEP_STRIPE, casado_regla: 'R1 cruce exacto con el libro (mismo monto, en su ventana)', casado_automatico: true }),
  pay('po_PRUEBA06', 'fallido', 'fallido', 300, '2026-10-18', { estado_stripe: 'failed', asiento_salida_num: '2026-000498', asiento_vuelta_num: '2026-000499' }),
  pay('po_PRUEBA07', 'revisar', 'revisar', 200, '2026-10-17', { revisar: '1 movimiento(s) que la app no conoce: dime a qué cuenta va', esperando: [{ txn: 'txn_PRUEBA70', tipo: 'reserve_transaction', monto: -50, motivo: 'a qué cuenta va' }],
    lineas: [{ txn: 'txn_PRUEBA71', tipo: 'charge', clase: 'pago', monto: 250, comision: 0, neto: 250, factura_num: '1112', pi: 'pi_PRUEBA11', cuenta: null },
      { txn: 'txn_PRUEBA70', tipo: 'reserve_transaction', clase: 'otro', monto: -50, comision: 0, neto: -50, factura_num: null, pi: null, cuenta: null }] }),
  pay('po_PRUEBA08', 'asentado', 'asentado', 700, '2026-10-16', { bruto: 720, comisiones: 20, n_pagos: 1, asiento_salida_num: '2026-000480', asiento_llegada_num: '2026-000481', reversado: true }),
  pay('po_PRUEBA09', 'fuera', 'fuera', 485.20, '2026-10-22', { fuera_motivo: 'de antes de instalar: lo registré en la bandeja' })
];
T.v_stripe_avisos = [
  { id: 11, nivel: 'bad', texto: 'Disputa de $3,000.00 en la #1110 (el cliente dice que no reconoce el cargo): Stripe retiró el dinero (y su comisión). El cobro se devolvió en el libro y vuelve a deber: #1110 $3,000.00. Respóndela en Stripe antes del 10 de noviembre.', objeto: 'pi_PRUEBA07', creado_el: '2026-10-25T16:00:00+00:00', repetido_el: null, veces: 1 },
  { id: 12, nivel: 'warn', texto: 'Se devolvió $100.00 de la #1106 en Stripe: el cobro se rehízo por $900.00 y vuelve a deber: #1106 $100.00. Si la factura estaba mal, haz su nota de crédito.', objeto: 'pi_PRUEBA03', creado_el: '2026-10-24T18:00:00+00:00', repetido_el: '2026-10-25T18:00:00+00:00', veces: 2 }
];
// el depósito STRIPE de Chase que trae Plaid (solo cuando la prueba lo pide), en la forma REAL de c6 (v_banco_bandeja, comprobado en el
// banco): «otro_lado_nombrado», su texto (préstamo del accionista, aportación, cobro con fn_banco_cobrar…) y sus 5 opciones
const OPS_C6_STRIPE = id => [
  { texto: 'Préstamo del accionista · 2900', llamar: 'fn_banco_clasificar', pide_motivo: true, pide: ['p_motivo'], args: { p_movimiento: id, p_cuenta: '2900' } },
  { texto: 'Aportación · 3100', llamar: 'fn_banco_clasificar', pide_motivo: true, pide: ['p_motivo'], args: { p_movimiento: id, p_cuenta: '3100' } },
  { texto: 'Devuelve lo que la empresa le prestó · 1130', llamar: 'fn_banco_clasificar', pide_motivo: true, pide: ['p_motivo'], args: { p_movimiento: id, p_cuenta: '1130' } },
  { texto: 'Desde 1020 (Stripe — cobros en tránsito)', llamar: 'fn_banco_transferencia', pide_motivo: true, pide: ['p_motivo'], args: { p_movimiento: id, p_cuenta: '1020' } },
  { texto: 'Desde 1030 (Reserva de impuestos)', llamar: 'fn_banco_transferencia', pide_motivo: true, pide: ['p_motivo'], args: { p_movimiento: id, p_cuenta: '1030' } }
];
const TEXTO_C6_STRIPE = 'Dinero que llega de «STRIPE ST», que el banco nombra sin número de cuenta: no se supone ni una cuenta propia ni tu cuenta personal. Si es tu cuenta personal: un préstamo del accionista (2900), una aportación (3100) o lo que devuelve de lo que la empresa le prestó (1130); si es una cuenta de la empresa, la transferencia desde ella: las dos, con su motivo escrito. Si es el cobro de un cliente, regístralo con su factura (fn_banco_cobrar). Nunca a ingreso.';
const MOV_STRIPE = { movimiento_id: MOV.s, cuenta: '1010', cuenta_nombre: 'Banco operativo', fecha: '2026-10-24', periodo: '2026-10', monto: 1365.70, descripcion: DEP_STRIPE, memo: null, cheque: null, tipo_banco: 'XFER',
  motivo: 'otro_lado_nombrado', texto: TEXTO_C6_STRIPE, opciones: OPS_C6_STRIPE(MOV.s),
  obra: null, propuesta: { motivo: 'otro_lado_nombrado' }, posible_duplicado_de: null, duplicado_fecha: null, duplicado_descripcion: null, duplicado_origen: null, dias: 3, alarma: false, origen: 'plaid', archivo_id: null, importado_el: '2026-10-25T11:00:00+00:00' };
// y el de un depósito que Edgar sacó de la app («Ya está en el libro», po_PRUEBA09): se lleva aquí como antes
const MOV_STRIPE_FUERA = { ...MOV_STRIPE, movimiento_id: MOV.sf, fecha: '2026-10-22', monto: 485.20, descripcion: DEP_STRIPE.replace('PRUEBA0001', 'PRUEBA0009'), opciones: OPS_C6_STRIPE(MOV.sf) };
// ---- la IA contable (c8, fase 7): la forma de las vistas v_contador_* (docs/conta/c8-contador.sql) y la función `contador` ----
// Cinco cargos sin ticket del Banco operativo con su propuesta (cuatro de la IA y una de una regla) y el de la ferretería de la
// Gold sin ninguna. Las cuentas son las de v_contador_cuentas (la única fuente de lo que se puede elegir), con sus nombres de c1.
const MI = { hd: '77777777-0000-4000-8000-000000000001', wawa: '77777777-0000-4000-8000-000000000002', amz: '77777777-0000-4000-8000-000000000003',
  irs: '77777777-0000-4000-8000-000000000004', nfx: '77777777-0000-4000-8000-000000000005' };
const PR = { hd: 'bbbbbbbb-0000-4000-8000-000000000001', wawa: 'bbbbbbbb-0000-4000-8000-000000000002', amz: 'bbbbbbbb-0000-4000-8000-000000000003',
  irs: 'bbbbbbbb-0000-4000-8000-000000000004', nfx: 'bbbbbbbb-0000-4000-8000-000000000005', fe: 'bbbbbbbb-0000-4000-8000-000000000006' };
const RG = { wawa: 'dddddddd-0000-4000-8000-000000000001', shell: 'dddddddd-0000-4000-8000-000000000002' };
// (7b) cuatro cargos más con la obra: CES (la IA propone Calla Terrace), Floor & Decor (una obra de nombre largo: el corte del chip),
// CED (pide obra y las pistas no apuntan a una sola) y Lowe's (por regla, con la obra que dicen sus pistas); y dos obras activas más
Object.assign(MI, { ces: '77777777-0000-4000-8000-000000000006', fyd: '77777777-0000-4000-8000-000000000007', ced: '77777777-0000-4000-8000-000000000008', low: '77777777-0000-4000-8000-000000000009' });
Object.assign(PR, { ces: 'bbbbbbbb-0000-4000-8000-000000000007', fyd: 'bbbbbbbb-0000-4000-8000-000000000008', ced: 'bbbbbbbb-0000-4000-8000-000000000009', low: 'bbbbbbbb-0000-4000-8000-00000000000a' });
RG.low = 'dddddddd-0000-4000-8000-000000000003';
const OBRAS_7B = [{ id: 'calla-terrace-8h2v', nombre: 'Calla Terrace', estado: 'ejecucion' }, { id: 'villanueva-amp-4r7t', nombre: 'Ampliación Residencia Villanueva-Echeverría', estado: 'aprobado' }];
// (7c) dos obras activas más, como las de producción que compran en los mismos comercios la misma semana
const OBRAS_7C = [{ id: 'dicke-subpanel-9p4w', nombre: 'Dicke — Subpanel y EV', estado: 'ejecucion' }, { id: 'metro-clinic-2k8d', nombre: 'Metro Clinic', estado: 'ejecucion' }];
const TODAS_OBRAS = () => T.proyectos.concat(OBRAS_7B, OBRAS_7C);
const CUENTAS_IA = [
  ['1130', 'Cuenta por cobrar al accionista', 'activo', 'prohibida'], ['1420', 'Fianzas', 'activo', 'opcional'], ['1510', 'Vehículos', 'activo', 'prohibida'], ['2900', 'Préstamo del accionista', 'pasivo', 'prohibida'],
  ['3200', 'Distribuciones al accionista', 'capital', 'prohibida'], ['5100', 'Material', 'costo', 'obligatoria'], ['5200', 'Subcontratos', 'costo', 'obligatoria'],
  ['5300', 'Equipo y renta', 'costo', 'obligatoria'], ['6130', 'Cargos bancarios y comisiones de tarjeta', 'gasto', 'prohibida'], ['6300', 'Vehículos — combustible y mantenimiento', 'gasto', 'prohibida'],
  ['6400', 'Herramienta menor y uniformes', 'gasto', 'prohibida'], ['6500', 'Oficina y software', 'gasto', 'prohibida'], ['6600', 'Profesionales — CPA y legal', 'gasto', 'prohibida'],
  ['7100', 'Intereses', 'otro_gasto', 'prohibida'], ['7900', 'Otros gastos', 'otro_gasto', 'prohibida']
].map(([codigo, nombre, tipo, regla_obra]) => ({ codigo, nombre, tipo, regla_obra, saldo_normal: 'debe', etiqueta_fiscal: null, pide_obra: regla_obra === 'obligatoria' }));
const TEXTO_SIN_TICKET = 'Sin ticket ni asiento que lo explique. Si tienes la foto del recibo, súbela: entra por su puente y casa sola. Si no, di de qué es.';
const movIA = (id, fecha, monto, descripcion, dias) => ({ movimiento_id: id, cuenta: '1010', cuenta_nombre: 'Banco operativo', fecha, periodo: fecha.slice(0, 7), monto, descripcion, memo: null, cheque: null, tipo_banco: 'DEBIT',
  motivo: 'sin_ticket', texto: TEXTO_SIN_TICKET, opciones: null, obra: null, propuesta: { motivo: 'sin_ticket' }, posible_duplicado_de: null, duplicado_fecha: null, duplicado_descripcion: null, duplicado_origen: null,
  dias, alarma: false, origen: 'plaid', archivo_id: null, importado_el: '2026-10-29T11:00:00+00:00' });
// una línea como la resuelve v_contador_bandeja: cuenta, su nombre, su tipo, la obra si la trae y pide_obra (obligatoria y sin obra)
const linIA = (cuenta, extra) => { const c = CUENTAS_IA.find(x => x.codigo === cuenta) || {}; const l = { cuenta, cuenta_nombre: c.nombre || '?', tipo: c.tipo || null, ...(extra || {}) };
  l.pide_obra = c.regla_obra === 'obligatoria' && !l.proyecto_id; if (l.proyecto_id) l.obra = (TODAS_OBRAS().find(p => p.id === l.proyecto_id) || {}).nombre; return l; };
const propIA = (id, mov, fuente, lineas, motivo, confianza, flags, extra) => ({ movimiento_id: mov.movimiento_id, cuenta: mov.cuenta, fecha: mov.fecha, monto: mov.monto, descripcion: mov.descripcion, movimiento_estado: 'pendiente',
  propuesta_id: id, fuente, estado: 'pendiente', accion: 'categorizar', lineas, resumen: lineas.map(l => `${l.cuenta} ${l.cuenta_nombre}`).join(' + '), motivo, confianza, flags: flags || {}, pide_obra: !!(flags && flags.pide_obra),
  alternativas: null, modelo: fuente === 'ia' ? 'claude-opus-5-5' : null, effort: fuente === 'ia' ? 'low' : null, prompt_version: fuente === 'ia' ? 'pv-prueba' : null, regla_id: null, regla_nombre: null,
  lote_id: fuente === 'ia' ? 'lote-prueba-1' : null, creado_el: '2026-10-30T18:05:00+00:00', aprobado_por: null, aprobado_el: null, lineas_finales: null, motivo_edgar: null, nota: null,
  asiento_id: null, asiento: null, asiento_vivo: false, dias: 1,
  obra_propuesta_id: null, obra_propuesta: null, obra_confianza: null, obra_motivo: null, pistas_resumen: null, ...(extra || {}) });
// (7b) la obra que propone la IA (o la candidata de las pistas en una propuesta por regla), como la resuelve v_contador_bandeja
const obraIA = (id, confianza, motivo, resumen) => ({ obra_propuesta_id: id, obra_propuesta: (TODAS_OBRAS().find(p => p.id === id) || {}).nombre || null,
  obra_confianza: confianza, obra_motivo: motivo, pistas_resumen: resumen });
const reglaIA = (id, nombre, lineas, veces, ultima, extra) => ({ id, nombre, patron: '^' + nombre, cuenta_banco: null, cuenta_banco_nombre: null, lineas,
  cuentas_texto: lineas.map(l => `${l.cuenta} ${(CUENTAS_IA.find(c => c.codigo === l.cuenta) || {}).nombre || '?'}`).join(' + '),
  pide_obra: lineas.some(l => (CUENTAS_IA.find(c => c.codigo === l.cuenta) || {}).regla_obra === 'obligatoria' && !l.proyecto_id), activa: true, origen: 'aprobacion', creada_por: UID, creada_por_nombre: 'Edgar Prueba',
  creada_el: '2026-10-20T12:00:00+00:00', veces, ultima_vez: ultima, notas: null, pendientes: 0, aprobadas: veces, ...(extra || {}) });
// el comercio de cada descripción, como lo saca fn_contador_nombre_comercio
const COMERCIO_IA = { [MI.hd]: 'THE HOME DEPOT', [MI.wawa]: 'WAWA', [MI.amz]: 'AMAZON MKTPLACE PMTS', [MI.irs]: 'IRS USATAXPYMT', [MI.nfx]: 'NETFLIX.COM', [MOV.a]: 'FERRETERIA EJEMPLO',
  [MI.ces]: 'CES', [MI.fyd]: 'FLOOR & DECOR', [MI.ced]: 'CED', [MI.low]: 'LOWE S' };
// (7c) Graybar: la IA se inclina por una obra con 60 % (débil); y los cargos de mentira para la cadena (MI.cadena(i))
MI.gb = '77777777-0000-4000-8000-00000000000a'; PR.gb = 'bbbbbbbb-0000-4000-8000-00000000000b'; COMERCIO_IA[MI.gb] = 'GRAYBAR ELECTRIC';
const idCadena = i => '79999999-0000-4000-8000-' + String(i).padStart(12, '0');
// una obra de las pistas como la da v_contador_bandeja.obras_top: { proyecto_id, nombre, pista } (la pista, en llano y corta)
const top = (id, pista) => ({ proyecto_id: id, nombre: (TODAS_OBRAS().find(p => p.id === id) || {}).nombre, pista });
const IA = {};
// con7b: la bandeja de la 7b (los cuatro cargos con la obra, las dos obras más, la regla de Lowe's y las pistas de Home Depot)
function iaReset(con7b, con7c) {
  const m = { hd: movIA(MI.hd, '2026-10-27', -245.18, 'THE HOME DEPOT 6341 OCALA FL', 4), wawa: movIA(MI.wawa, '2026-10-28', -48.10, 'WAWA 5123 OCALA FL', 3),
    amz: movIA(MI.amz, '2026-10-24', -2890.00, 'AMAZON MKTPLACE PMTS AMZN.COM/BILL WA', 7), irs: movIA(MI.irs, '2026-10-21', -1500.00, 'IRS USATAXPYMT', 10),
    nfx: movIA(MI.nfx, '2026-10-26', -22.99, 'NETFLIX.COM LOS GATOS CA', 5) };
  Object.assign(IA, {
    movs: Object.values(m), fuera: new Set(), seq: 800,
    props: [
      propIA(PR.hd, m.hd, 'ia', [linIA('5100')], 'Home Depot vende material eléctrico; $245.18 en Ocala es material de una obra. La 5100 pide la obra y no la adivino.', 0.92, { pide_obra: true }),
      propIA(PR.wawa, m.wawa, 'regla', [linIA('6300')], 'Regla: WAWA', 1, {}, { regla_id: RG.wawa, regla_nombre: 'WAWA' }),
      propIA(PR.amz, m.amz, 'ia', [linIA('6400')], 'Amazon sin el detalle de lo comprado; $2,890.00 es mucho para herramienta menor y la factura no trae impuesto.', 0.55, { capitalizable: true, use_tax: true },
        { alternativas: [{ cuenta: '1510', motivo: 'si es un equipo que dura más de un año' }, { cuenta: '6500', motivo: 'si es una computadora de la oficina' }] }),
      propIA(PR.irs, m.irs, 'ia', [linIA('3200')], 'Un pago al IRS (USATAXPYMT): en la S-corp es una distribución al accionista, nunca un gasto.', 0.97, { irs: true }),
      propIA(PR.nfx, m.nfx, 'ia', [linIA('3200')], 'Netflix es una suscripción personal: va a distribuciones (3200), no a gasto de la empresa.', 0.35, { personal: true })
    ],
    reglas: [reglaIA(RG.wawa, 'WAWA', [{ cuenta: '6300' }], 12, '2026-10-28T12:00:00+00:00'), reglaIA(RG.shell, 'SHELL OIL', [{ cuenta: '6300' }], 4, '2026-10-12T12:00:00+00:00')],
    gasto: 420, gastoTotal: 1230, ultimaRafaga: '2026-10-30T18:05:00+00:00', con7b: !!con7b,
    // (7c) la base de la 7c (columnas nuevas), el máximo por ráfaga, el contador apagado, la rutina y el marcador del mes
    con7c: false, max: 20, apagado: false, rutina: null, marcadorBase: null, nProponer: 0
  });
  if (!con7b) return;
  const n = { ces: movIA(MI.ces, '2026-10-29', -612.40, 'CES 1040 TAMPA FL', 2), fyd: movIA(MI.fyd, '2026-10-28', -389.00, 'FLOOR & DECOR 225 OCALA FL', 3),
    ced: movIA(MI.ced, '2026-10-27', -151.30, 'CED OCALA 0412', 4), low: movIA(MI.low, '2026-10-29', -96.55, "LOWE'S #1234 OCALA FL", 2) };
  IA.movs.push(...Object.values(n));
  // Home Depot (pide obra, sin pistas): la base lo dice en el resumen
  Object.assign(IA.props.find(p => p.propuesta_id === PR.hd), { pistas_resumen: 'sin pistas' });
  IA.props.push(
    propIA(PR.ces, n.ces, 'ia', [linIA('5100', { proyecto_id: 'calla-terrace-8h2v' })], 'CES (Consolidated Electrical Supply) vende material eléctrico: $612.40 es material de obra.', 0.85, { obra_propuesta: true },
      obraIA('calla-terrace-8h2v', 0.86, 'Edgar eligió Calla Terrace 2 veces con CES; la cuadrilla reportó 24 h allí esos días.', 'Calla Terrace: 24 h esos días, 61 h en 30 días, 2 tickets de CES, elegida 2 veces · Casa Pérez: 6 h en 30 días')),
    propIA(PR.fyd, n.fyd, 'ia', [linIA('5100', { proyecto_id: 'villanueva-amp-4r7t' })], 'Floor & Decor vende piso y azulejo: material de obra.', 0.74, { obra_propuesta: true },
      obraIA('villanueva-amp-4r7t', 0.82, 'La lista de materiales de Ampliación Residencia Villanueva-Echeverría pide justo piso y azulejo esos días (6 apuntados).', 'Ampliación Residencia Villanueva-Echeverría: 6 materiales recientes · Oficina NCH: 1 material reciente')),
    propIA(PR.ced, n.ced, 'ia', [linIA('5100')], 'CED vende material eléctrico; las pistas no apuntan a una sola obra y no la adivino.', 0.70, { pide_obra: true },
      { pistas_resumen: 'Calla Terrace: 12 h esos días, 12 h en 30 días · Casa Pérez: 10 h esos días, 10 h en 30 días' }),
    // por regla: la regla dice la cuenta; las pistas, la obra (la base la copia con su confianza y su motivo, en minúscula como la escribe)
    propIA(PR.low, n.low, 'regla', [linIA('5100', { proyecto_id: 'casa-perez-k3m9' })], 'Regla: LOWE S', 1, { obra_propuesta: true },
      { regla_id: RG.low, regla_nombre: 'LOWE S', ...obraIA('casa-perez-k3m9', 0.8, 'elegida 2 veces por Edgar con LOWE S; la cuadrilla reportó 16 h en Casa Pérez esos días', 'Casa Pérez: 16 h esos días, 16 h en 30 días, elegida 2 veces') }));
  IA.reglas.push(reglaIA(RG.low, 'LOWE S', [{ cuenta: '5100' }], 3, '2026-10-22T12:00:00+00:00'));
  if (!con7c) return;
  // (7c) la base de la 7c: obra_fuerte y obras_top en v_contador_bandeja (iaUltima), la rutina, el marcador y la alarma 74 en
  // v_contador_estado y v_contador_control; dos obras más; CED (pide obra) con sus tres obras; Graybar con una obra débil
  IA.con7c = true;
  const o = { gb: movIA(MI.gb, '2026-10-30', -318.75, 'GRAYBAR ELECTRIC 0412 TAMPA FL', 1) };
  IA.movs.push(o.gb);
  Object.assign(IA.props.find(p => p.propuesta_id === PR.ces), { obras_top: [top('calla-terrace-8h2v', '24 h esos días · 2 tickets de CES · la elegiste 2 veces con CES'), top('casa-perez-k3m9', '6 h en 30 días')] });
  Object.assign(IA.props.find(p => p.propuesta_id === PR.ced), { obras_top: [top('calla-terrace-8h2v', '12 h esos días · 1 ticket de CED'), top('casa-perez-k3m9', '10 h esos días'), top('dicke-subpanel-9p4w', '3 materiales apuntados')] });
  IA.props.push(propIA(PR.gb, o.gb, 'ia', [linIA('5100', { proyecto_id: 'dicke-subpanel-9p4w' })], 'Graybar vende material eléctrico (breakers, MC 12/2): $318.75 es material de obra.', 0.78, { obra_propuesta: true },
    { ...obraIA('dicke-subpanel-9p4w', 0.6, 'la cuadrilla reportó 21 h en Dicke — Subpanel y EV esos días, pero Metro Clinic también tuvo 12 h y 2 tickets de GRAYBAR ELECTRIC', 'Dicke — Subpanel y EV: 21 h esos días, 7 tickets de GRAYBAR ELECTRIC · Metro Clinic: 12 h esos días, 2 tickets · Calla Terrace: 4 h esos días'),
      obras_top: [top('dicke-subpanel-9p4w', '21 h esos días · 7 tickets de GRAYBAR ELECTRIC'), top('metro-clinic-2k8d', '12 h esos días · 2 tickets de GRAYBAR ELECTRIC'), top('calla-terrace-8h2v', '4 h esos días')] }));
  // la rutina corrió bien hace dos horas; el marcador de lo que va del mes (lo de antes de hoy: la base cuenta además lo de hoy)
  IA.rutina = { activa: true, ultima: new Date(Date.now() - 2 * 3600e3).toISOString(), error: null, desde: '2026-10-31T16:00:00+00:00' };
  IA.marcadorBase = { ca: 16, cc: 2, oa: 6, oc: 0, oe: 2 };
}
// (7c) n cargos sin ticket más, sin propuesta (los de la cadena): CES, Home Depot, CED y Graybar del 3 al 29 de octubre
IA.cadena = n => {
  const com = ['C8 CES 1040 TAMPA FL BREAKERS', 'THE HOME DEPOT 6341 OCALA FL', 'CED OCALA 0412', 'GRAYBAR ELECTRIC 0412 TAMPA FL'];
  for (let i = 1; i <= n; i++) {
    const id = idCadena(i), d = '2026-10-' + String(3 + (i % 27)).padStart(2, '0');
    IA.movs.push(movIA(id, d, -(40 + i * 7.25), com[i % 4], 3));
    COMERCIO_IA[id] = com[i % 4].split(' ').slice(0, 2).join(' ');
  }
};
iaReset();
// las obras que ve la base: con la 7b, las dos de más; con la 7c, otras dos
const obrasBase = () => IA.con7c ? TODAS_OBRAS() : IA.con7b ? T.proyectos.concat(OBRAS_7B) : T.proyectos;
const OBRA_ACTIVA = ['aprobado', 'ejecucion', 'pausa'];
const iaMovs = () => T.v_banco_bandeja.concat(IA.movs).filter(f => !IA.fuera.has(f.movimiento_id));
// v_contador_bandeja: por movimiento, la propuesta pendiente o la última
function iaUltima() {
  const por = new Map(), viva = p => p.estado === 'pendiente';
  for (const p of IA.props) { const q = por.get(p.movimiento_id); if (!q || (viva(p) && !viva(q)) || (viva(p) === viva(q) && p.creado_el >= q.creado_el)) por.set(p.movimiento_id, p); }
  return [...por.values()].map(p => ({ ...p, movimiento_estado: IA.fuera.has(p.movimiento_id) ? 'casado' : 'pendiente',
    // (7c) la base marca la obra fuerte (≥ 0,80) y da las tres primeras obras de las pistas con su pista en llano (null sin pistas)
    ...(IA.con7c ? { obra_fuerte: p.obra_fuerte != null ? p.obra_fuerte : !!p.obra_propuesta_id && Number(p.obra_confianza) >= 0.8, obras_top: p.obras_top || null } : {}) }));
}
// lo que espera propuesta, los más viejos primero (como fn_contador_candidatos)
const iaCandidatos = () => iaMovs().filter(m => ['sin_ticket', 'dudosa'].includes(m.motivo) && !IA.props.some(p => p.movimiento_id === m.movimiento_id && p.estado === 'pendiente'))
  .sort((a, b) => String(a.fecha).localeCompare(String(b.fecha)) || String(a.movimiento_id).localeCompare(String(b.movimiento_id)));
// (7c) la alarma 74 como la calcula la base: la rutina activa con error, o más de 36 horas sin correr (o sin estrenar) con cargos esperando
function iaRutina74() {
  const r = IA.rutina, n = iaCandidatos().length; if (!r) return null;
  const desde = r.ultima || r.desde, vieja = Date.now() - Date.parse(desde) > 36 * 3600e3 && n > 0;
  const hora = ts => new Intl.DateTimeFormat('es', { timeZone: 'America/New_York', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date(ts)).replace(',', '');
  const mal = r.activa && (!!r.error || vieja);
  return { mal, detalle: !r.activa ? 'la rutina está apagada (contador_config.rutina_activa = false): la Bandeja sigue proponiendo sola al abrirla, y «Proponer ahora» sigue'
    : r.error ? `la rutina de las ${hora(r.ultima)} (hora de Miami) terminó con error: ${r.error}`
    : vieja && !r.ultima ? `la rutina no ha corrido nunca desde que se instaló (el ${hora(r.desde)}) y hay ${n} cargo(s) esperando: ¿está CONTADOR_RUTINA_SECRETO en los secretos de Edge Functions…?`
    : vieja ? `la rutina no corre desde el ${hora(r.ultima)} (hora de Miami, hace más de 36 horas) y hay ${n} cargo(s) esperando: mira cron.job_run_details y los logs de la función «contador»`
    : r.ultima ? `la última corrió el ${hora(r.ultima)} (hora de Miami) sin error` : 'la rutina no ha corrido todavía' };
}
// (7c) el marcador del mes como lo cuenta v_contador_estado: lo de antes (marcadorBase) y lo que entró hoy por la IA o una regla
function iaMarcador() {
  const b = IA.marcadorBase || { ca: 0, cc: 0, oa: 0, oc: 0, oe: 0 }, m = { ...b };
  for (const p of IA.props.filter(x => ['ia', 'regla'].includes(x.fuente) && ['aprobada', 'editada'].includes(x.estado))) {
    const cs = ls => (ls || []).map(l => l.cuenta).sort().join(','), igual = cs(p.lineas) === cs(p.lineas_finales);
    if (p.estado === 'aprobada' || igual) m.ca += 1; else m.cc += 1;
    const prop = p.obra_propuesta_id || ((p.lineas || []).find(l => l.proyecto_id) || {}).proyecto_id || null, fin = ((p.lineas_finales || []).find(l => l.proyecto_id) || {}).proyecto_id || null;
    if (prop && fin === prop) m.oa += 1; else if (prop && fin) m.oc += 1; else if (!prop && fin) m.oe += 1;
  }
  return { cuenta_acertadas_mes: m.ca, cuenta_cambiadas_mes: m.cc, obra_acertadas_mes: m.oa, obra_cambiadas_mes: m.oc, obra_elegidas_mes: m.oe };
}
// v_contador_control: 10 y 11 cuentan sus vistas; un cuadre (61) y una alarma (71) que la prueba pone en rojo; 70 sale del gasto
function iaControl() {
  const bj = iaUltima().length, rg = IA.reglas.length, tope = IA.gasto >= 3000 || IA.gastoTotal >= 10000;
  const obrasMal = IA.props.filter(p => p.estado === 'pendiente' && p.obra_propuesta_id && !obrasBase().some(o => o.id === p.obra_propuesta_id && OBRA_ACTIVA.includes(o.estado)));
  const c = (orden, control, nivel, ok, detalle, filas, esperadas) => ({ orden, control, nivel, ok, filas: filas === undefined ? (nivel === 'cuadre' ? 0 : null) : filas, esperadas: esperadas === undefined ? (nivel === 'cuadre' ? 0 : null) : esperadas, detalle: detalle || null });
  return [
    c(10, 'vista: v_contador_bandeja', 'cuadre', true, null, estado.iaConteo ? 99 : bj, estado.iaConteo ? 99 : bj), c(11, 'vista: v_contador_reglas', 'cuadre', true, null, rg, rg),
    c(12, 'ia: hay cuentas que proponer', 'cuadre', true, null, CUENTAS_IA.length, 1), c(60, 'ia: cada propuesta aprobada o editada tiene su asiento vivo', 'cuadre', true),
    c(61, 'ia: ningún asiento con «Propuesta de la IA #» en su motivo sin su propuesta aprobada', 'cuadre', !estado.iaCuadreMal, estado.iaCuadreMal ? '2026-000777 (Propuesta de la IA #bbbbbbbb-… aprobada por Edgar) (prueba)' : null, estado.iaCuadreMal ? 1 : 0, 0),
    c(62, 'ia: las reglas activas van a cuentas activas e imputables', 'cuadre', true), c(63, 'ia: protecciones de la fase 7', 'cuadre', true),
    c(64, 'ia: toda obra propuesta pendiente es una obra activa', 'cuadre', !obrasMal.length,
      obrasMal.length ? obrasMal.map(p => `#${p.propuesta_id} (${p.fecha} ${p.monto} «${p.descripcion}»): la obra propuesta «${p.obra_propuesta}» está ${(obrasBase().find(o => o.id === p.obra_propuesta_id) || {}).estado || 'perdida'}`).join('; ') + ' → recházala (fn_contador_rechazar) o apruébala eligiendo otra obra en el selector' : null,
      obrasMal.length, 0),
    c(70, 'ia: el gasto del mes bajo el tope', 'alarma', !tope, `${HOY.slice(0, 7)}: la IA lleva $${(IA.gastoTotal / 100).toFixed(2)} en total (el tope de la app es $100.00) y el contador $${(IA.gasto / 100).toFixed(2)} (su tope, $30.00)`),
    c(71, 'ia: ninguna propuesta pendiente de más de 7 días', 'alarma', !estado.iaVieja, estado.iaVieja ? '2026-10-21 -1500.00 «IRS USATAXPYMT» (desde el 2026-10-22) (prueba)' : null, estado.iaVieja ? 1 : 0, 0),
    c(72, 'ia: la última ráfaga sin error', 'alarma', true, 'la última fue el 30/10/2026 14:05 (hora de Miami)'),
    c(73, 'ia: la llave y la función', 'alarma', true, `${iaCandidatos().length} cargo(s) esperan propuesta`)
  ].concat(IA.con7c ? [c(74, 'ia: la rutina', 'alarma', !iaRutina74().mal, iaRutina74().detalle)] : []);
}
// v_contador_estado: una fila
function iaEstado() {
  const pend = IA.props.filter(p => p.estado === 'pendiente'), cand = iaCandidatos(), ctl = iaControl();
  const motivo = IA.apagado ? 'apagado' : IA.gastoTotal >= 10000 ? 'tope de la app' : IA.gasto >= 3000 ? 'tope del contador' : null;
  return { instalado: true, modelo: 'claude-opus-5-5', effort: 'low', activa: !IA.apagado, max_por_rafaga: IA.max, tope_mes_centavos: 3000, dueno: UID, dueno_nombre: 'Edgar Prueba', prompt_version: 'pv-prueba', prefijo_hash: 'ph-prueba',
    ultima_rafaga_el: IA.ultimaRafaga, ultimo_error: null, ultimo_error_el: null, actualizado: IA.ultimaRafaga,
    pendientes_sin_propuesta: cand.length, pendientes_desde: cand.length ? cand.map(m => m.fecha).sort()[0] : null,
    propuestas_pendientes: pend.length, propuestas_por_regla: pend.filter(p => p.fuente === 'regla').length, propuestas_por_ia: pend.filter(p => p.fuente === 'ia').length,
    propuestas_con_obra: pend.filter(p => !!p.obra_propuesta_id).length,
    reglas_activas: IA.reglas.filter(r => r.activa).length, mes: HOY.slice(0, 7), centavos_mes_total: IA.gastoTotal, tope_global: 10000, centavos_mes_contador: IA.gasto, aviso_pct: 80,
    bloqueado: !!motivo, bloqueado_motivo: motivo, aviso: IA.gasto * 100 >= 3000 * 80 || IA.gastoTotal * 100 >= 10000 * 80, lotes_abiertos: 0, ultimo_lote_el: IA.ultimaRafaga, ultimo_lote_centavos: 42,
    aprobadas_total: IA.props.filter(p => ['aprobada', 'editada'].includes(p.estado)).length, rechazadas_total: IA.props.filter(p => p.estado === 'rechazada').length, cuentas_permitidas: CUENTAS_IA.length,
    cuadres_rojos: ctl.filter(f => f.nivel === 'cuadre' && !f.ok).length, alarmas: ctl.filter(f => f.nivel === 'alarma' && !f.ok).length,
    // (7c) la rutina y el marcador honesto del mes (solo con la base de la 7c)
    ...(IA.con7c ? { funcion_url: 'https://prueba.supabase.co/functions/v1/contador', rutina_activa: IA.rutina.activa, rutina_ultima_el: IA.rutina.ultima, rutina_ultimo_error: IA.rutina.error,
      rutina_desde: IA.rutina.desde, ...iaMarcador() } : {}) };
}
const VISTAS_IA = { v_contador_estado: () => [iaEstado()], v_contador_bandeja: iaUltima, v_contador_control: iaControl, v_contador_reglas: () => IA.reglas, v_contador_cuentas: () => CUENTAS_IA };
// La función de borde `contador` (supabase/functions/contador), con la forma del contrato: { ok: true, … } o { ok: false, codigo, error, pista? }.
// La salud contesta sin sesión; todo lo demás pide el dueño con aal2 (la lee del JWT), como `stripe`.
function funcionContador(b, auth) {
  if (b.accion === 'salud') return { cuerpo: { ok: true, llave: !estado.iaSinLlave, base: true, modelo: 'claude-opus-5-5', effort: 'low', prompt_version: 'pv-prueba', rutina: !estado.iaSinSecreto, tope: { bloqueado: iaEstado().bloqueado } } };
  let aal = null; try { aal = JSON.parse(Buffer.from(String(auth).replace(/^Bearer /, '').split('.')[1], 'base64url').toString()).aal; } catch { /* sin sesión */ }
  if (aal !== 'aal2') return { estado: 403, cuerpo: { ok: false, codigo: 'MFA', error: 'Falta el código del teléfono: entra otra vez con él (la IA contable lo pide).' } };
  if (estado.iaFalla) { const f = estado.iaFalla; estado.iaFalla = null; return { estado: f.estado, cuerpo: { ok: false, ...f.cuerpo } }; }
  const movDe = id => iaMovs().find(m => m.movimiento_id === id);
  // lo que hace fn_contador_clasificar: el movimiento sale de la bandeja con su asiento, la propuesta queda aprobada o editada y, si se pide, nace la regla
  const clasificar = (p, mov, lineas, estadoP, recordar) => {
    IA.seq += 1; IA.fuera.add(mov.movimiento_id);
    const asiento = '2026-000' + IA.seq, ahora = new Date().toISOString();
    let pid = p ? p.propuesta_id : 'bbbbbbbb-0000-4000-8000-000000000' + IA.seq;
    if (p) Object.assign(p, { estado: estadoP, aprobado_por: UID, aprobado_el: ahora, lineas_finales: lineas, asiento, asiento_vivo: true });
    else IA.props.push(propIA(pid, mov, 'edgar', lineas.map(l => linIA(l.cuenta, l.proyecto_id ? { proyecto_id: l.proyecto_id } : {})), 'Clasificado por Edgar desde la bandeja (fase 7)', 1, {}, { estado: 'aprobada', creado_el: ahora, asiento, asiento_vivo: true }));
    let regla;
    if (recordar !== false) {
      const nombre = COMERCIO_IA[mov.movimiento_id] || mov.descripcion, previa = IA.reglas.find(r => r.activa && r.nombre === nombre);
      if (previa) regla = { regla: previa.id, nombre, patron: previa.patron, nueva: false, cambio: false };
      else { const r = reglaIA('dddddddd-0000-4000-8000-000000000' + IA.seq, nombre, lineas.map(l => ({ cuenta: l.cuenta })), 1, ahora, { creada_el: ahora }); IA.reglas.push(r); regla = { regla: r.id, nombre, patron: r.patron, nueva: true, cambio: false }; }
    }
    return { ok: true, movimiento: mov.movimiento_id, asiento_id: 'as-' + IA.seq, asiento, propuesta: pid, estado: estadoP, fuente: p ? p.fuente : 'edgar', lineas, motivo: 'Propuesta de la IA … (prueba)', ...(regla ? { regla } : {}) };
  };
  if (b.accion === 'proponer') {
    // (7c) la cola de fallos de la cadena: cada «proponer» toma el siguiente (null = contesta bien): el MX008 «ráfaga en marcha», un 502…
    IA.nProponer += 1;
    const falla = estado.iaFallas.length ? estado.iaFallas.shift() : null;
    if (falla) return { estado: falla.estado, cuerpo: { ok: false, ...falla.cuerpo } };
    const e = iaEstado();
    if (e.bloqueado || estado.iaBloqueaFuncion) return { cuerpo: { ok: true, bloqueado: true, motivo: estado.iaBloqueaFuncion ? 'tope del contador (prueba)' : e.bloqueado_motivo } };
    // como la función: los más viejos primero y como mucho max_por_rafaga; al final, cuántos siguen esperando (quedan, 7c)
    let k = 0, sin = 0, conObra = 0;
    const ahora = new Date().toISOString();
    for (const m of iaCandidatos().slice(0, IA.max)) {
      // (7c) la IA no contesta ninguno (negativas, 529…): la ráfaga cuesta y no deja nada
      if (estado.iaNiega) { sin += 1; continue; }
      // (7b) con las pistas de la cuadrilla, la ferretería sale con su obra
      if (m.movimiento_id === MOV.a && IA.con7b) { IA.props.push(propIA(PR.fe, m, 'ia', [linIA('5100', { proyecto_id: 'casa-perez-k3m9' })], 'Ferretería en Tampa: material de obra.', 0.81, { obra_propuesta: true },
        { creado_el: ahora, ...obraIA('casa-perez-k3m9', 0.8, 'La cuadrilla reportó 16 h en Casa Pérez esos días.', 'Casa Pérez: 16 h esos días, 40 h en 30 días') })); k += 1; conObra += 1; }
      else if (m.movimiento_id === MOV.a) { IA.props.push(propIA(PR.fe, m, 'ia', [linIA('5100')], 'Ferretería en Tampa: material de obra. La 5100 pide la obra y no la adivino.', 0.81, { pide_obra: true }, { creado_el: ahora })); k += 1; }
      else if (/^79999999-/.test(m.movimiento_id)) {
        // (7c) los de la cadena, de tres clases: obra fuerte (Dicke, 85 %), débil (Metro Clinic, 60 %) y sin obra (la 5100 la pide)
        const i = Number(m.movimiento_id.slice(-12)), pr = 'bbbbbbbb-9999-4000-8000-' + String(i).padStart(12, '0');
        const tops = [top('dicke-subpanel-9p4w', '21 h esos días · 7 tickets'), top('metro-clinic-2k8d', '12 h esos días · 2 tickets'), top('calla-terrace-8h2v', '4 h esos días')];
        const clase = i % 3;
        if (clase === 0) { IA.props.push(propIA(pr, m, 'ia', [linIA('5100', { proyecto_id: 'dicke-subpanel-9p4w' })], 'Material eléctrico de obra.', 0.9, { obra_propuesta: true },
          { creado_el: ahora, ...obraIA('dicke-subpanel-9p4w', 0.85, 'La lista de materiales de Dicke pide justo breakers y MC 12/2 en Rough-in esos días.', 'Dicke: 21 h esos días'), obra_fuerte: true, obras_top: tops })); conObra += 1; }
        else if (clase === 1) { IA.props.push(propIA(pr, m, 'ia', [linIA('5100', { proyecto_id: 'metro-clinic-2k8d' })], 'Material eléctrico de obra.', 0.88, { obra_propuesta: true },
          { creado_el: ahora, ...obraIA('metro-clinic-2k8d', 0.6, 'la cuadrilla reportó 12 h en Metro Clinic esos días.', 'Metro Clinic: 12 h esos días'), obra_fuerte: false, obras_top: tops })); conObra += 1; }
        else IA.props.push(propIA(pr, m, 'ia', [linIA('5100')], 'Material eléctrico de obra; las pistas no apuntan a una sola obra.', 0.86, { pide_obra: true }, { creado_el: ahora, pistas_resumen: 'Dicke: 21 h · Metro Clinic: 12 h', obras_top: tops }));
        k += 1;
      }
      else sin += 1;
    }
    IA.gasto += 12; IA.gastoTotal += 12; IA.ultimaRafaga = ahora;
    // (7c) quedan: los que siguen esperando; sigue: si tiene sentido otra ahora (quedan y esta dejó alguna propuesta)
    const quedan = iaCandidatos().length;
    return { cuerpo: { ok: true, propuestas: k, con_obra: conObra, reglas: 0, sin_respuesta: sin, invalidas: 0, centavos: 12, cache: { creacion: 1830, lectura: 0 }, quedan, sigue: quedan > 0 && k > 0 } };
  }
  if (b.accion === 'aprobar') {
    const p = IA.props.find(x => x.propuesta_id === b.propuesta);
    if (!p || p.estado !== 'pendiente') return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', error: `Esa propuesta ya está ${p ? p.estado : 'perdida'}: no se aprueba dos veces.` } };
    if (p.lineas.some(l => l.pide_obra) && !b.proyecto_id) return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', pista: 'elige la obra', error: 'Elige la obra: la propuesta va a 5100 (Material), que pide obra. Elígela en el selector y vuelve a aprobar.' } };
    // (7b) como fn_contador_aprobar: la obra que manda Edgar va a toda línea cuya cuenta admite obra (nunca a una prohibida); sin ella,
    // las líneas como vienen (con la obra propuesta); si la de Edgar no es la que traía la línea, la propuesta queda «editada»
    const admite = cod => ['obligatoria', 'opcional'].includes((CUENTAS_IA.find(c => c.codigo === cod) || {}).regla_obra);
    const lineas = p.lineas.map(l => ({ cuenta: l.cuenta, ...(b.proyecto_id && admite(l.cuenta) ? { proyecto_id: b.proyecto_id } : l.proyecto_id ? { proyecto_id: l.proyecto_id } : {}) }));
    const editada = p.lineas.some((l, i) => !!l.proyecto_id && l.proyecto_id !== lineas[i].proyecto_id);
    return { cuerpo: clasificar(p, movDe(p.movimiento_id), lineas, editada ? 'editada' : 'aprobada', b.recordar) };
  }
  if (b.accion === 'clasificar') {
    const mov = movDe(b.movimiento);
    if (!mov) return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', error: 'Ese movimiento ya no está en la bandeja.' } };
    if (!Array.isArray(b.lineas) || !b.lineas.length) return { estado: 400, cuerpo: { ok: false, codigo: 'FORMA', error: 'Faltan las líneas.' } };
    const p = IA.props.find(x => x.movimiento_id === b.movimiento && x.estado === 'pendiente');
    const igual = !!p && p.lineas.length === b.lineas.length && p.lineas.every((l, i) => l.cuenta === b.lineas[i].cuenta && ((l.proyecto_id || '') === (b.lineas[i].proyecto_id || '') || (!l.proyecto_id && p.pide_obra)));
    return { cuerpo: clasificar(p, mov, b.lineas, !p || igual ? 'aprobada' : 'editada', b.recordar) };
  }
  if (b.accion === 'rechazar') {
    const p = IA.props.find(x => x.propuesta_id === b.propuesta);
    if (!p || p.estado !== 'pendiente') return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', error: 'Esa propuesta ya no está pendiente.' } };
    Object.assign(p, { estado: 'rechazada', aprobado_por: UID, aprobado_el: new Date().toISOString(), motivo_edgar: b.motivo || 'No es eso (Edgar, desde la bandeja)' });
    return { cuerpo: { ok: true, propuesta: p.propuesta_id, movimiento: p.movimiento_id, estado: 'rechazada', fuente: p.fuente, motivo_edgar: p.motivo_edgar } };
  }
  if (b.accion === 'regla_baja') {
    const r = IA.reglas.find(x => x.id === b.regla);
    if (!r || !r.activa) return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', error: 'Esa regla ya está dada de baja.' } };
    if (String(b.motivo || '').trim().length < 3) return { estado: 400, cuerpo: { ok: false, codigo: '22023', error: 'Quitar una regla dice por qué (motivo): queda escrito con ella.' } };
    Object.assign(r, { activa: false, notas: 'baja: ' + b.motivo });
    return { cuerpo: { ok: true, ...r, propuestas_caducadas: 0 } };
  }
  if (b.accion === 'estado') return { cuerpo: { ok: true, ...iaEstado(), tope: { bloqueado: iaEstado().bloqueado } } };
  return { estado: 400, cuerpo: { ok: false, codigo: 'ACCION', error: 'Acción desconocida: «' + b.accion + '».' } };
}
const estado = { controlMal: false, controlFilas: null, fallar: false, casarRondas: 0, concNueva: false, plaidFijada: false, plaidSinVista: false, plaidSinFijar: false, mfaFactores: [], sesionAal: undefined,
  // los interruptores de los estados: el control en rojo, el conteo distinto para una vista, el «Sigue» del tope por reloj (cuenta llamadas; 90 o más = nunca termina),
  // el equipo (no dueño), la apertura sin postear, el balance descuadrado, una vista que no existe en la base, un mayor que no termina donde dice la balanza
  // y Storage que no contesta al firmar la foto
  estadosMal: false, estadosFilas: null, estadosFilasVista: null, estadosSigue: 0, estadosNoDueno: false, estadosSinApertura: false, estadosDescuadre: false, estadosVistaRota: false, estadosMayorRoto: false, estadosFotoRota: false,
  // los de Stripe: p1 sin pegar (404), el modo de la llave, la salud sin llave, el depósito STRIPE en la bandeja, un cuadre en rojo, un conteo distinto,
  // una alarma, y el siguiente error que contesta la función ({ estado, cuerpo })
  stripeSinVista: false, stripeModo: 'real', stripeSinLlave: false, stripeDeposito: false, stripeCuadreMal: false, stripeConteo: false, stripeAlarma: false, stripeFalla: null,
  // los de la IA contable (c8): pegada o no (sin ella, las vistas v_contador_* contestan 404), un conteo distinto (10), un cuadre en rojo (61),
  // una propuesta de más de 7 días (alarma 71), la salud sin llave, la función sin desplegar, la función que dice «bloqueado» aunque la vista no,
  // el siguiente error que contesta la función ({ estado, cuerpo }) y cuánto tarda «proponer» (ms, para ver el botón girar)
  c8: false, iaConteo: false, iaCuadreMal: false, iaVieja: false, iaSinLlave: false, iaSinSecreto: false, iaSinFuncion: false, iaBloqueaFuncion: false, iaFalla: null, iaLento: 0,
  // (7c) la cola de fallos de «proponer» (uno por llamada), cuántas ráfagas van a la vez (y el máximo visto) y la preferencia
  // «Proponer sola al abrir la Bandeja» que cada contexto nuevo deja en localStorage ('0', '1', 'quitar' = sin guardar: encendida)
  iaFallas: [], iaVuelo: 0, iaVueloMax: 0, iaSolaPref: '0', iaNiega: false };
const llamadas = [], lecturas = []; // lecturas: cada GET a /rest/v1/<vista>?… tal como lo pidió la pantalla
function tabla(nombre, q) {
  let filas = T[nombre] || [];
  if (nombre.startsWith('v_contador_')) filas = estado.c8 && VISTAS_IA[nombre] ? VISTAS_IA[nombre]() : [];
  if (nombre === 'proyectos' && estado.c8) filas = obrasBase();
  // con c8 la bandeja trae además los cinco cargos sin ticket de la IA; lo que ya se clasificó por la función sale
  if (nombre === 'v_banco_bandeja' && estado.c8) filas = filas.concat(IA.movs).filter(f => !IA.fuera.has(f.movimiento_id));
  if (nombre === 'v_conciliacion' && estado.concNueva) filas = filas.concat([{
    conciliacion_id: CONC_NEW, cuenta: '2100-2013', cuenta_nombre: 'Amex Business Gold', fecha_corte: '2026-10-08', periodo: '2026-10', tipo: 'normal', estado: 'abierta', saldo_libros: -14624.26, saldo_statement: 14675.12, saldo_banco: -14675.12,
    depositos_transito: 0, cargos_circulacion: 50.86, sin_casar_banco: 0, n_transito: 1, n_sin_casar: 0, n_alarmas: 0, n_dudosas: 0, n_pide_motivo: 0, diferencia: 0, lista_para_confirmar: true, identidad: 'Libros -14624.26 = banco -14675.12 + (0.00 − 50.86) − 0.00 (cuadra)', falta: null }]);
  if (nombre === 'v_conciliacion_partidas' && estado.concNueva) filas = filas.concat([
    { conciliacion_id: CONC_NEW, cuenta: '2100-2013', fecha_corte: '2026-10-08', conciliacion_estado: 'abierta', grupo: 'en_libros_no_en_banco', partida_id: 'p-new', clase: 'cargo_en_circulacion', fecha: '2026-10-07', monto: -50.86, descripcion: 'Ticket del 7 oct', cheque: null, dias: 1, alarma: false, motivo: null, explicacion: 'Posteado el 7, el banco aún no lo trae.', asiento_numero: '2026-000009', resuelta_en: null, resuelta_por_movimiento: null },
    { conciliacion_id: CONC_NEW, cuenta: '2100-2013', fecha_corte: '2026-10-08', conciliacion_estado: 'abierta', grupo: 'casado', partida_id: null, clase: 'apertura', fecha: '2026-10-01', monto: -31.56, descripcion: 'GASOLINERA EJEMPLO', cheque: null, dias: null, alarma: false, motivo: null, explicacion: 'Casado por R0 apertura (automático).', asiento_numero: null, resuelta_en: null, resuelta_por_movimiento: null }
  ]);
  if (nombre === 'v_banco_saldos' && estado.stripeSinVista) filas = filas.filter(c => c.cuenta !== '1020'); // sin p1 no hay 1020
  if (nombre === 'v_banco_bandeja' && estado.stripeDeposito) filas = filas.concat([MOV_STRIPE, MOV_STRIPE_FUERA]);
  if (nombre === 'v_stripe_estado') filas = filas.map(e => ({ ...e, modo: estado.stripeModo, cuadres_rojos: estado.stripeCuadreMal ? 1 : 0, alarmas: estado.stripeAlarma ? 1 : 0 }));
  // v_stripe_control: 10, 11 y 12 cuentan sus vistas; un cuadre (21) y una alarma (30) que la prueba pone en rojo
  if (nombre === 'v_stripe_control') {
    const vista = (o, v) => ({ orden: o, control: 'vista: ' + v, nivel: 'cuadre', ok: true, filas: estado.stripeConteo && v === 'v_stripe_pagos' ? 99 : T[v].length, esperadas: estado.stripeConteo && v === 'v_stripe_pagos' ? 99 : T[v].length, detalle: null });
    filas = [vista(10, 'v_stripe_facturas'), vista(11, 'v_stripe_pagos'), vista(12, 'v_stripe_payouts'),
      { orden: 20, control: 'stripe: la puente solo la mueve Stripe', nivel: 'cuadre', ok: true, filas: 0, esperadas: 0, detalle: null },
      { orden: 21, control: 'stripe: la puente = lo que falta depositar', nivel: 'cuadre', ok: !estado.stripeCuadreMal, filas: estado.stripeCuadreMal ? 4100 : 4000, esperadas: 4000, detalle: estado.stripeCuadreMal ? 'la 1020 dice 4,100.00 y lo que falta depositar suma 4,000.00 (prueba)' : null },
      { orden: 30, control: 'stripe: ningún pago por resolver', nivel: 'alarma', ok: !estado.stripeAlarma, filas: estado.stripeAlarma ? 1 : 0, esperadas: 0, detalle: estado.stripeAlarma ? 'pi_PRUEBA09 de $250.00: no salió de un enlace de la app (prueba)' : null },
      { orden: 34, control: 'stripe: protecciones de p1', nivel: 'cuadre', ok: true, filas: 0, esperadas: 0, detalle: null }];
  }
  if (nombre === 'v_plaid_conexiones' && estado.plaidFijada) filas = filas.map(c => ({ ...c, cuentas_sin_fijar: 0, cuentas: c.cuentas.map(a => a.account_id === 'acc-corriente' ? { ...a, cuenta: '1010', propuesta: 'la que fijó Edgar' } : a) }));
  // los estados rotos a propósito: el balance con la fila «cuadra» en false, el mayor de 1010 que no llega al saldo final de la balanza
  if (nombre === 'v_balance_general' && estado.estadosDescuadre) filas = filas.map(f => f.nivel === 'total' && f.linea === 'cuadra' ? { ...f, cuadra: false, cifra: 100, cifra_ajustada: 100 } : f);
  if (nombre === 'v_mayor' && estado.estadosMayorRoto) filas = filas.map(f => f.asiento_id === ASI.c && f.cuenta === '1010' ? { ...f, saldo: 26000, saldo_en_su_lado: 26000 } : f);
  // order=col.desc,col2.asc como PostgREST
  const orden = (q.get('order') || '').split(',').filter(Boolean).map(s => s.split('.'));
  if (orden.length) filas = [...filas].sort((x, y) => { for (const [k, d] of orden) { const a = x[k], b = y[k]; if (a === b) continue; const r = a == null ? 1 : b == null ? -1 : (a > b ? 1 : -1); return d === 'desc' ? -r : r; } return 0; });
  // filtros eq./is. de PostgREST, los que usa la pantalla
  for (const [k, v] of q.entries()) {
    if (['select', 'order', 'limit'].includes(k)) continue;
    const m = /^(eq|is|lte|gte|in)\.(.*)$/.exec(v); if (!m) continue;
    const lista = m[1] === 'in' ? m[2].replace(/^\(|\)$/g, '').split(',') : null;
    filas = filas.filter(f => m[1] === 'in' ? lista.includes(String(f[k])) : m[1] === 'eq' ? String(f[k]) === m[2] : m[1] === 'is' ? (m[2] === 'null' ? f[k] == null : f[k] === (m[2] === 'true')) : m[1] === 'lte' ? String(f[k]) <= m[2] : String(f[k]) >= m[2]);
  }
  return filas;
}
function rpc(fn, a) {
  if (estado.fallar && /^fn_banco_(casar_con|clasificar|transferencia|ignorar|duplicado)$/.test(fn)) return { error: { code: 'MX008', message: 'La base dijo que no (prueba)' } };
  if (fn === 'fn_banco_control') {
    const hoy = hoyMiami(), desde = hoy.slice(0, 8) + '01';
    const cuenta = v => v === 'v_banco_bandeja' ? tabla('v_banco_bandeja', new URLSearchParams()).filter(f => f.fecha <= hoy).length
      : v === 'v_banco_saldos' ? tabla('v_banco_saldos', new URLSearchParams()).length
      : v === 'v_conciliacion' ? tabla('v_conciliacion', new URLSearchParams()).filter(c => c.fecha_corte >= desde && c.fecha_corte <= hoy).length
      : v === 'v_conciliacion_partidas' ? tabla('v_conciliacion_partidas', new URLSearchParams()).filter(c => c.fecha_corte >= desde && c.fecha_corte <= hoy).length
      : v === 'v_banco_movimientos' ? 2 : 0;
    const filas = (a.p_vistas || []).map((v, i) => ({ orden: i + 1, vista: v, filas: estado.controlFilas != null ? estado.controlFilas : cuenta(v), esperadas: cuenta(v), ok: !estado.controlMal, detalle: estado.controlMal ? 'la vista trae 3 y la tabla tiene 4 (prueba)' : null }));
    filas.push({ orden: 51, vista: 'cuadre: un movimiento, un casado', filas: null, esperadas: null, ok: true, detalle: null });
    return filas;
  }
  if (fn === 'fn_banco_importar_ofx') return { archivo: 'f-nuevo', cuenta: a.p_cuenta || '2100-2013', formato: 'ofx_sgml', filas_leidas: 31, filas_nuevas: 4, filas_repetidas: 27, filas_fuera: 0, antes_del_corte: 27, duplicados_posibles: 0, desde: '2026-09-07', hasta: '2026-10-08', saldo: -14675.12, saldo_al: '2026-10-08', avisos: ['Un aviso de prueba'], siguiente: 'select fn_banco_casar_todo(…);' };
  if (fn === 'fn_banco_casar_todo') {
    estado.casarRondas += 1;
    return estado.casarRondas % 2 === 1
      ? { pendientes_antes: 29, casados: 20, por_regla: { apertura: 20 }, pendientes: 9, por_motivo: { sin_ticket: 9 }, propuestas: 0, completo: false, siguiente: 'select fn_banco_casar_todo(…);', ms: 4100 }
      : { pendientes_antes: 9, casados: 5, por_regla: { apertura: 5 }, pendientes: 4, por_motivo: { sin_ticket: 2, interes_tarjeta: 1, partida_apertura: 1 }, propuestas: 4, completo: true, ms: 180 };
  }
  if (fn === 'fn_conciliar') { estado.concNueva = true; return { conciliacion: CONC_NEW, cuenta: a.p_cuenta, fecha_corte: a.p_fecha_corte, estado: 'abierta', diferencia: 0, lista_para_confirmar: true }; }
  if (fn === 'fn_conciliacion_confirmar') return { conciliacion: a.p_conciliacion, estado: 'confirmada', alarmas: [] };
  if (fn === 'fn_estuve') return null;
  // fn_estados_control(p_periodo, p_vistas): una fila por vista (filas = lo que la vista da con periodo=eq.p, como cuenta la base), más los
  // cuadres que siempre salen (61 protecciones, 63 apertura) y el 56 cuando resultados y balance van juntas. ok = null con «Sigue: …» es el tope por reloj.
  if (fn === 'fn_estados_control') {
    if (estado.estadosNoDueno) return { status: 403, error: { code: '42501', message: 'Los estados los ve solo Edgar (el dueño).', details: null, hint: null } };
    const cuentaEst = v => tabla(v, new URLSearchParams('periodo=eq.' + a.p_periodo)).length;
    const sigue = i => estado.estadosSigue > 0 && (i > 0 || estado.estadosSigue >= 90);
    const filas = (a.p_vistas || []).map((v, i) => ({ orden: 10 + i, vista: v,
      filas: estado.estadosFilas != null && v === estado.estadosFilasVista ? estado.estadosFilas : cuentaEst(v), esperadas: cuentaEst(v),
      ok: estado.estadosMal ? false : sigue(i) ? null : true,
      detalle: estado.estadosMal ? 'La vista ' + v + ' devolvió 3 filas y el libro dice 4: no se pinta. (prueba)' : sigue(i) ? 'Sigue: esta llamada ya llevaba 3100 ms y ' + v + ' no se controló todavía (prueba)' : null }));
    if (estado.estadosSigue > 0) estado.estadosSigue -= 1;
    filas.push({ orden: 61, vista: 'cuadre: protecciones de c4', filas: null, esperadas: null, ok: true, detalle: null });
    filas.push({ orden: 63, vista: 'cuadre: apertura en el libro', filas: null, esperadas: null, ok: !estado.estadosSinApertura, detalle: estado.estadosSinApertura ? 'No cuadra: fn_apertura no ha posteado una apertura viva (prueba)' : null });
    if ((a.p_vistas || []).includes('v_resultados') && (a.p_vistas || []).includes('v_balance_general')) filas.push({ orden: 56, vista: 'cuadre: resultado del estado = resultado del balance', filas: null, esperadas: null, ok: true, detalle: null });
    return filas;
  }
  return { movimiento: a.p_movimiento, estado: 'casado', asiento: '2026-000012' };
}
// La función de borde `plaid` (supabase/functions/plaid), con la forma de sus respuestas
function funcionPlaid(b) {
  if (b.accion === 'link_token') return { cuerpo: { ok: true, link_token: 'link-sandbox-prueba', expiration: '2026-10-17T16:00:00Z', reconexion: !!b.item_id } };
  if (b.accion === 'fijar_cuenta') { estado.plaidFijada = true; return { cuerpo: { ok: true, conexion: { item_id: b.item_id, estado: 'activa', cuentas_sin_fijar: 0 } } }; }
  if (b.accion === 'canjear') return { cuerpo: { ok: true, conexion: { item_id: 'item-nuevo', institucion: (b.metadata && b.metadata.institution && b.metadata.institution.name) || 'Banco', estado: 'activa', cuentas_sin_fijar: 1 } } };
  if (b.accion === 'sincronizar') {
    if (estado.plaidSinFijar) return { estado: 409, cuerpo: { ok: false, codigo: 'SIN_FIJAR', sin_fijar: ['····4392'], error: 'Falta decir a qué cuenta del plan va ····4392 (o «ignorar»). Hasta entonces no se sincroniza.' } };
    return { cuerpo: { ok: true, item_id: b.item_id, lotes: 2, agregadas: 4, paginas: 1, conexion: { item_id: b.item_id, estado: 'activa', cursor: 'c1', ultimo_resultado: { por_que: 'pantalla', importado: [{ cuenta: '2100-2013', filas_nuevas: 3, duplicados_posibles: 1 }] } } } };
  }
  if (b.accion === 'desconectar') return { cuerpo: { ok: true, conexion: { item_id: b.item_id, estado: 'desconectada', desconectada_motivo: b.motivo } } };
  return { estado: 400, cuerpo: { ok: false, error: 'Acción desconocida: «' + b.accion + '».' } };
}
// La función de borde `stripe` (supabase/functions/stripe), con la forma de sus respuestas: { ok: true, … } o
// { ok: false, codigo, error, pista?, rak? }. La salud contesta sin sesión; todo lo demás pide el dueño con aal2 (la lee del JWT).
function funcionStripe(b, auth) {
  if (b.accion === 'salud') return { cuerpo: { ok: true, modo: estado.stripeModo, llave: !estado.stripeSinLlave, llave_restringida: !estado.stripeSinLlave, webhook: true, rutina: true, base: true, sesion: true, version: '2026-09-30.endive', banco_de_pruebas: false } };
  let aal = null; try { aal = JSON.parse(Buffer.from(String(auth).replace(/^Bearer /, '').split('.')[1], 'base64url').toString()).aal; } catch { /* sin sesión */ }
  if (aal !== 'aal2') return { estado: 403, cuerpo: { ok: false, codigo: 'MFA', error: 'Falta el código del teléfono: entra otra vez con él (los cobros en línea lo piden).' } };
  if (estado.stripeFalla) { const f = estado.stripeFalla; estado.stripeFalla = null; return { estado: f.estado, cuerpo: { ok: false, ...f.cuerpo } }; }
  const F = T.v_stripe_facturas, P = T.v_stripe_pagos, Q = T.v_stripe_payouts;
  if (b.accion === 'crear_enlace') {
    const f = F.find(x => x.factura_id === b.factura_id);
    if (!f) return { estado: 409, cuerpo: { ok: false, codigo: '22023', error: 'No existe la factura ' + b.factura_id + '.' } };
    if (f.pagada && !b.aunque_pagada) return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', pista: 'pagada_en_app', error: `La casilla dice que la #${f.num} está pagada (QuickBooks), pero el libro dice que debe $${f.saldo_cxc}. Confírmalo.` } };
    if (f.enlace_estado === 'activo' && !b.reemplazar) return { cuerpo: { ok: true, nuevo: false, enlace: { id: f.enlace_id, url: f.enlace_url, monto: f.enlace_monto } } };
    const monto = f.saldo_cxc + (b.con_retencion ? f.saldo_retencion : 0), n = (f.enlace_url ? 2 : 1);
    Object.assign(f, { enlace_id: 'e-' + f.num + '-' + n, enlace_estado: 'activo', enlace_url: 'https://buy.stripe.com/test_prueba' + f.num + (n > 1 ? '_' + n : ''), enlace_monto: monto, enlace_con_retencion: !!b.con_retencion, enlace_creado_el: new Date().toISOString(), enlace_desfasado: false });
    return { cuerpo: { ok: true, nuevo: true, enlace: { id: f.enlace_id, url: f.enlace_url, monto, con_retencion: !!b.con_retencion } } };
  }
  if (b.accion === 'desactivar_enlace') {
    const f = F.find(x => x.enlace_id === b.enlace); if (!f) return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', error: 'Ese enlace ya no está activo.' } };
    Object.assign(f, { enlace_id: null, enlace_estado: null, enlace_url: null, enlace_monto: null, enlace_con_retencion: null, enlace_creado_el: null, enlace_desfasado: false });
    return { cuerpo: { ok: true, enlace: { id: b.enlace, estado: 'desactivado' } } };
  }
  if (b.accion === 'probar_llave') return { cuerpo: { ok: true, modo: estado.stripeModo, restringida: true, permisos: [
    { recurso: 'payment_links', ok: true }, { recurso: 'checkout_sessions', ok: true }, { recurso: 'payment_intents', ok: true }, { recurso: 'charges', ok: true }, { recurso: 'refunds', ok: true },
    { recurso: 'disputes', ok: true }, { recurso: 'payouts', ok: true }, { recurso: 'Balance transactions (con su origen)', ok: false, rak: 'rak_balance_transaction_source_read', panel: 'Balance transaction sources: Read' }, { recurso: 'events', ok: true }] } };
  if (b.accion === 'casar_payout') {
    const q = Q.find(x => x.po === b.po); if (!q) return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', error: 'Ese depósito no está asentado.' } };
    Object.assign(q, { estado_pantalla: 'casado', candidatos: [], movimiento_id: b.movimiento_id || 'm-dep', movimiento_fecha: '2026-10-24', movimiento_descripcion: DEP_STRIPE, casado_regla: 'R1 cruce exacto con el libro (mismo monto, en su ventana)', casado_automatico: true, dias_sin_casar: null });
    if (b.movimiento_id === MOV.s) estado.stripeDeposito = false;
    return { cuerpo: { ok: true, po: b.po, casado: true, movimiento: b.movimiento_id || null, regla: q.casado_regla, automatico: true } };
  }
  if (b.accion === 'resolver_pago') {
    const x = P.find(y => y.pi === b.pi); if (!x || x.estado !== 'revisar') return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', error: 'Ese pago ya está resuelto.' } };
    Object.assign(x, { estado: 'cobrado', estado_pantalla: 'cobrado', revisar: null, en_libro: x.monto, cobro_asiento: '2026-000520', factura_num: b.factura_id ? String(1100 + b.factura_id) : null, falta_depositar: x.monto });
    return { cuerpo: { ok: true, pago: x, payouts: [] } };
  }
  if (b.accion === 'resolver_linea') {
    const q = Q.find(x => x.po === b.po); if (!q) return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', error: 'No existe ese depósito.' } };
    Object.assign(q, { estado: 'asentado', estado_pantalla: 'asentado', revisar: null, esperando: null, lineas: q.lineas.map(l => l.txn === b.txn ? { ...l, cuenta: b.cuenta } : l), asiento_salida_num: '2026-000530', asiento_llegada_num: '2026-000531' });
    return { cuerpo: { ok: true, payout: q } };
  }
  if (b.accion === 'payout_fuera') {
    const q = Q.find(x => x.po === b.po); if (!q || q.asiento_salida_num) return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', error: 'Ese depósito ya tiene sus asientos en el libro: no se saca.' } };
    Object.assign(q, { estado: 'fuera', estado_pantalla: 'fuera', fuera_motivo: b.motivo, revisar: null, esperando: null });
    return { cuerpo: { ok: true, estado: 'fuera', payout: q, pagos: 0 } };
  }
  if (b.accion === 'aviso_visto') { T.v_stripe_avisos = T.v_stripe_avisos.filter(a => a.id !== b.aviso); return { cuerpo: { ok: true } }; }
  if (b.accion === 'reprocesar') {
    if (b.po && b.rehacer) { const q = Q.find(x => x.po === b.po); if (q) q.reversado = false; }
    return { cuerpo: { ok: true, resultado: { estado: 'hecho' } } };
  }
  if (b.accion === 'barrer') return { cuerpo: { ok: true, resumen: { eventos: 0, pagos: 2, payouts: 1, casar: 0, incompleto: false } } };
  if (b.accion === 'estado') return { cuerpo: { ok: true, resumen: ESTADO_STRIPE } };
  return { estado: 400, cuerpo: { ok: false, codigo: 'ACCION', error: 'Acción desconocida: «' + b.accion + '».' } };
}
// Plaid Link de mentira (cdn.plaid.com): «abrir» termina enseguida con éxito
const PLAID_FALSO = "window.Plaid = { create(cfg) { window.__plaidCfg = cfg; return { open() { window.__plaidAbierto = (window.__plaidAbierto || 0) + 1; setTimeout(() => cfg.onSuccess('public-sandbox-prueba', { institution: { name: 'Platypus Bank', institution_id: 'ins_1' } }), 50); }, exit() {}, destroy() {} }; } };";
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS' };
async function simular(ctx, rol) {
  // (7c) las pruebas de antes de la 7c corren con «Proponer sola» apagado ('0'): así «Proponer ahora» y sus avisos se prueban a mano, como antes
  await ctx.addInitScript(([s, sola]) => {
    localStorage.setItem('mxp_sesion', JSON.stringify(s)); localStorage.removeItem('mxp_idioma');
    if (sola === '0' || sola === '1') localStorage.setItem('mxp.contador.sola', sola); else if (sola === 'quitar') localStorage.removeItem('mxp.contador.sola');
  }, [sesion(), estado.iaSolaPref]);
  await ctx.route(/cdn\.plaid\.com/, route => route.fulfill({ status: 200, contentType: 'text/javascript', body: PLAID_FALSO }));
  await ctx.route(/supabase\.co/, route => {
    const req = route.request(), u = new URL(req.url());
    if (req.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: CORS });
    if (u.pathname === '/functions/v1/plaid') {
      let b = {}; try { b = JSON.parse(req.postData() || '{}'); } catch { /* vacío */ }
      llamadas.push({ fn: 'plaid:' + b.accion, args: b, auth: req.headers()['authorization'] || '' });
      const r = funcionPlaid(b);
      return route.fulfill({ status: r.estado || 200, headers: CORS, contentType: 'application/json', body: JSON.stringify(r.cuerpo) });
    }
    if (u.pathname === '/functions/v1/stripe') {
      let b = {}; try { b = JSON.parse(req.postData() || '{}'); } catch { /* vacío */ }
      const auth = req.headers()['authorization'] || '';
      llamadas.push({ fn: 'stripe:' + b.accion, args: b, auth });
      const r = funcionStripe(b, auth);
      return route.fulfill({ status: r.estado || 200, headers: CORS, contentType: 'application/json', body: JSON.stringify(r.cuerpo) });
    }
    if (u.pathname === '/functions/v1/contador') {
      let b = {}; try { b = JSON.parse(req.postData() || '{}'); } catch { /* vacío */ }
      const auth = req.headers()['authorization'] || '';
      llamadas.push({ fn: 'contador:' + b.accion, args: b, auth });
      if (estado.iaSinFuncion) return route.fulfill({ status: 404, headers: CORS, contentType: 'application/json', body: JSON.stringify({ code: 'NOT_FOUND', message: 'Requested function was not found' }) });
      // (7c) cuántas «proponer» hay en vuelo a la vez: la pantalla nunca manda dos
      if (b.accion === 'proponer') { estado.iaVuelo += 1; estado.iaVueloMax = Math.max(estado.iaVueloMax, estado.iaVuelo); }
      const r = funcionContador(b, auth);
      const responder = () => { if (b.accion === 'proponer') estado.iaVuelo -= 1; return route.fulfill({ status: r.estado || 200, headers: CORS, contentType: 'application/json', body: JSON.stringify(r.cuerpo) }); };
      return b.accion === 'proponer' && estado.iaLento ? new Promise(listo => setTimeout(listo, estado.iaLento)).then(responder) : responder();
    }
    // c8 sin pegar: las vistas v_contador_* no existen (PostgREST: 404 PGRST205); la lectura se anota igual (la pantalla sí las pidió)
    if (u.pathname.startsWith('/rest/v1/v_contador_') && !estado.c8) {
      const v = u.pathname.slice('/rest/v1/'.length);
      lecturas.push(v + u.search);
      return route.fulfill({ status: 404, headers: CORS, contentType: 'application/json', body: JSON.stringify({ code: 'PGRST205', message: `Could not find the table 'public.${v}' in the schema cache`, details: null, hint: null }) });
    }
    // p1 sin pegar: las vistas v_stripe_* no existen (PostgREST: 404 PGRST205)
    if (u.pathname.startsWith('/rest/v1/v_stripe_') && estado.stripeSinVista) {
      const v = u.pathname.slice('/rest/v1/'.length);
      return route.fulfill({ status: 404, headers: CORS, contentType: 'application/json', body: JSON.stringify({ code: 'PGRST205', message: `Could not find the table 'public.${v}' in the schema cache`, details: null, hint: null }) });
    }
    if (u.pathname === '/rest/v1/v_plaid_conexiones' && estado.plaidSinVista) {
      return route.fulfill({ status: 404, headers: CORS, contentType: 'application/json', body: JSON.stringify({ code: 'PGRST205', message: "Could not find the table 'public.v_plaid_conexiones' in the schema cache", details: null, hint: null }) });
    }
    if (u.pathname.startsWith('/auth/v1/token')) return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify(sesion()) });
    if (u.pathname === '/auth/v1/user' && req.method() === 'GET') return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify({ id: UID, email: 'edgar@prueba', factors: estado.mfaFactores }) });
    if (u.pathname === '/auth/v1/factors' && req.method() === 'POST') {
      let b = {}; try { b = JSON.parse(req.postData() || '{}'); } catch { /* vacío */ }
      llamadas.push({ fn: 'auth:enrolar', args: b });
      estado.mfaFactores = [{ id: 'f-1', friendly_name: b.friendly_name || 'Teléfono', factor_type: 'totp', status: 'unverified' }];
      return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify({ id: 'f-1', type: 'totp', friendly_name: b.friendly_name, totp: { qr_code: QR_FALSO, secret: 'ABCDEFGHIJKLMNOP', uri: 'otpauth://totp/Max%20Power%20Panel:edgar?secret=ABCDEFGHIJKLMNOP&issuer=Max%20Power%20Panel' } }) });
    }
    if (u.pathname === '/auth/v1/factors/f-1/challenge') { llamadas.push({ fn: 'auth:reto' }); return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify({ id: 'ch-1', type: 'totp', expires_at: Math.floor(Date.now() / 1000) + 300 }) }); }
    if (u.pathname === '/auth/v1/factors/f-1/verify') {
      let b = {}; try { b = JSON.parse(req.postData() || '{}'); } catch { /* vacío */ }
      llamadas.push({ fn: 'auth:verificar', args: b });
      if (b.code !== '123456') return route.fulfill({ status: 400, headers: CORS, contentType: 'application/json', body: JSON.stringify({ error: 'invalid_grant', error_description: 'Invalid TOTP code entered' }) });
      estado.mfaFactores = [{ id: 'f-1', friendly_name: 'Teléfono de Edgar', factor_type: 'totp', status: 'verified' }];
      estado.sesionAal = 'aal2';
      return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify(sesion()) });
    }
    if (u.pathname === '/auth/v1/factors/f-1' && req.method() === 'DELETE') { llamadas.push({ fn: 'auth:quitar' }); estado.mfaFactores = []; return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify({ id: 'f-1' }) }); }
    // Storage: firmar la foto de un recibo (bucket privado «fotos»), como lo pide DB.firmarFotos
    if (u.pathname === '/storage/v1/object/sign/fotos' && req.method() === 'POST') {
      let b = {}; try { b = JSON.parse(req.postData() || '{}'); } catch { /* vacío */ }
      llamadas.push({ fn: 'storage:firmar', args: b });
      if (estado.estadosFotoRota) return route.abort('failed'); // Storage no contesta (CORS, filtro, caída) con la REST viva
      return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify((b.paths || []).map(ruta => ({ path: ruta, signedURL: '/object/sign/fotos/' + ruta + '?token=prueba' }))) });
    }
    if (u.pathname.startsWith('/rest/v1/rpc/')) {
      const fn = u.pathname.slice('/rest/v1/rpc/'.length); let args = {};
      try { args = JSON.parse(req.postData() || '{}'); } catch { /* vacío */ }
      llamadas.push({ fn, args });
      const r = rpc(fn, args);
      if (r && r.error) return route.fulfill({ status: r.status || 400, headers: CORS, contentType: 'application/json', body: JSON.stringify(r.error) });
      if (r === null) return route.fulfill({ status: 204, headers: CORS });
      return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify(r) });
    }
    if (u.pathname.startsWith('/rest/v1/')) {
      const nombre = u.pathname.slice('/rest/v1/'.length);
      if (req.method() !== 'GET') return route.fulfill({ status: 201, headers: CORS, contentType: 'application/json', body: '[]' });
      lecturas.push(nombre + u.search);
      // una vista de c4 que no existe en la base (c4 sin pegar): PostgREST contesta 404 con 42P01
      if (estado.estadosVistaRota && nombre === 'v_balanza') return route.fulfill({ status: 404, headers: CORS, contentType: 'application/json', body: JSON.stringify({ code: '42P01', message: 'relation "v_balanza" does not exist', details: null, hint: null }) });
      // el equipo (no dueño) recibe [] con 200 de toda vista de c4: la RLS no deja ver el libro
      let filas = estado.estadosNoDueno && nombre.startsWith('v_') ? [] : tabla(nombre, u.searchParams);
      if (nombre === 'perfiles') filas = [{ id: UID, nombre: rol === 'dueno' ? 'Edgar Prueba' : 'Campo Prueba', rol }];
      return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify(filas) });
    }
    return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: '[]' });
  });
}
const OFX = 'OFXHEADER:100\r\nDATA:OFXSGML\r\nVERSION:102\r\nSECURITY:NONE\r\nENCODING:USASCII\r\nCHARSET:1252\r\nCOMPRESSION:NONE\r\nOLDFILEUID:NONE\r\nNEWFILEUID:NONE\r\n\r\n<OFX><CREDITCARDMSGSRSV1><CCSTMTTRNRS><CCSTMTRS><CURDEF>USD<CCACCTFROM><ACCTID>379999999931007</ACCTID></CCACCTFROM><BANKTRANLIST><STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20261002<TRNAMT>-123.45<FITID>A1<NAME>FERRETERIA EJEMPLO</STMTTRN></BANKTRANLIST><LEDGERBAL><BALAMT>-14675.12<DTASOF>20261008</LEDGERBAL></CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1></OFX>\r\n';
const desde = (n) => llamadas.slice(n);
const esperarLlamada = async (p, n, fn) => { for (let i = 0; i < 60 && !desde(n).some(l => l.fn === fn); i++) await p.waitForTimeout(100); };
const FOTOS = process.argv.includes('--fotos') ? (process.env.FOTOS_DIR || path.join(require('os').tmpdir(), 'mxp-pantalla-fotos')) : null;
if (FOTOS) fs.mkdirSync(FOTOS, { recursive: true });
// animations: 'disabled' porque el fullPage encoge el viewport un instante, la media query del lateral cambia y la transición de .15 s salía a medias en la imagen
const foto = async (p, nombre) => { if (FOTOS) await p.screenshot({ path: path.join(FOTOS, nombre + '.png'), fullPage: true, animations: 'disabled' }); };
const texto = async (p, sel) => (await p.locator(sel).allTextContents()).join(' ');
const PAGS = ['resumen', 'bancos', 'bandeja', 'conciliar', 'movimientos', 'estados', 'cobros', 'conexiones'];
// cambiar de página por su pestaña: en la computadora (≥ 1024 px) las pestañas están escondidas (las enseña el lateral de app.js), así que el clic es del DOM
const tab = async (pg, k) => { await pg.locator(`.ct-tab[data-pag="${k}"]`).evaluate(b => b.click()); };
// esperar a que la pantalla termine de pintar (ni «Cargando…» ni una acción en curso)
// (7c) ni la cadena de la IA en marcha (propone sola: sin esperarla, lo pintado sería de antes de terminar)
const pintado = async pg => { await pg.waitForTimeout(150); await pg.waitForFunction(() => !document.querySelector('#conta-raiz .ct-cargando') && !window.MXP_CONTA._estado.ocupado && !(window.MXP_CONTA._estado.cadena && window.MXP_CONTA._estado.cadena.activa), null, { timeout: 8000 }); };
// una fila de la bandeja: se despliega (si no lo está) y devuelve su tarjeta, con los botones a la vista
const fila = async (pg, id) => { const c = pg.locator(`.ct-mov[data-id="${id}"]`); await c.locator('.ct-mov-fila').waitFor({ state: 'attached', timeout: 8000 });
  if ((await c.locator('.ct-mov-fila').getAttribute('aria-expanded')) !== 'true') { await c.locator('.ct-mov-fila').evaluate(b => b.click()); await pg.waitForTimeout(120); } return c; };
// espías sobre los hooks del contrato (app.js los pasa al abrir y los vuelve a pasar en cada entrada; S.hooks los guarda y conta.js los busca en cada llamada)
const espiar = pg => pg.evaluate(() => { window.__pag = window.__pag || []; window.__vol = window.__vol || []; const h = window.MXP_CONTA._estado.hooks; if (h.__espiado) return; h.__espiado = true;
  const p0 = h.pagina, v0 = h.volver; h.pagina = k => { window.__pag.push(k); p0(k); }; h.volver = v => { window.__vol.push(v); v0(v); }; });

(async () => {
  await new Promise(r => srv.listen(8873, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const errs = [];
  // ---- el campo: ni la loseta, ni el lateral, ni «Más» ----
  {
    const ctx = await b.newContext({ viewport: { width: 1280, height: 900 }, serviceWorkers: 'block' });
    await simular(ctx, 'campo');
    const p = await ctx.newPage(); p.on('pageerror', e => errs.push('campo: ' + String(e).slice(0, 160)));
    await p.goto('http://localhost:8873/index.html');
    await p.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await p.waitForTimeout(800);
    await p.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
    ok('El campo no ve la loseta de Contabilidad', await p.locator('#btn-conta').isHidden());
    ok('…ni la pestaña «Contabilidad» del lateral con sus páginas', (await p.locator('#lateral [data-lat="conta"], #lateral [data-lat^="conta-"]').count()) === 0);
    ok('…ni el botón «Contabilidad» de la barra de abajo', (await p.locator('#nav-abajo button[data-nav="conta"]').getAttribute('hidden')) !== null);
    await ctx.close();
  }
  // ---- Edgar ----
  const ctx = await b.newContext({ viewport: { width: 1280, height: 900 }, serviceWorkers: 'block' });
  await simular(ctx, 'dueno');
  // «Copiar» el enlace de pago: el portapapeles del navegador (se lee de vuelta en la prueba)
  await ctx.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: 'http://localhost:8873' });
  const p = await ctx.newPage(); p.on('pageerror', e => errs.push('dueño: ' + String(e).slice(0, 160)));
  await p.goto('http://localhost:8873/index.html');
  await p.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await p.waitForTimeout(800);
  await p.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
  // el período que la pantalla debe preseleccionar: el mes de v_cortes que contiene hoy; si no, el más reciente ya empezado
  const mesRegla = (() => { const meses = CORTES.filter(c => c.tipo === 'mes' && c.desde <= HOY).sort((x, y) => y.desde.localeCompare(x.desde)); return (meses.find(c => c.corte >= HOY) || meses[0]).periodo; })();
  const titulo = async () => (await p.locator('#titulo-vista').textContent()).trim();
  ok('Edgar tiene la loseta (escondida en Hoy, como las demás del dueño)', !(await p.locator('#btn-conta').getAttribute('hidden')) );
  ok('…y la pestaña «Contabilidad» en el lateral con las 8 páginas como subtítulos (conta-<k>, los que da MXP_CONTA.paginas()), y el botón de la barra de abajo', (await p.locator('#lateral [data-lat="conta"]').count()) === 1 &&
    JSON.stringify(await p.locator('#lateral [data-lat^="conta-"]').evaluateAll(bs => bs.map(b => b.dataset.lat))) === JSON.stringify(PAGS.map(k => 'conta-' + k)) && (await p.locator('#nav-abajo button[data-nav="conta"]').getAttribute('hidden')) === null);

  // ---- La portada («Resumen»): control antes de pintar, las fichas y «Qué atender» ----
  let n = llamadas.length; let nLect = lecturas.length;
  await p.locator('#btn-conta').evaluate(b => b.click());
  await p.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 });
  ok('Al entrar, la vista de la contabilidad se ve, la página es «Resumen» (la portada) y la pestaña «resumen» está marcada', await p.locator('#vista-conta').isVisible() && (await p.locator('#titulo-vista').textContent()).trim() === 'Resumen' && (await p.locator('.ct-tab[data-pag="resumen"][aria-current="page"]').count()) === 1, await p.locator('#titulo-vista').textContent());
  const pags = await p.evaluate(() => window.MXP_CONTA.paginas().map(x => [x.k, x.nombre, /^<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"/.test(x.svg) && /<\/svg>$/.test(x.svg)]));
  ok('MXP_CONTA.paginas() da las 8 páginas en su orden, con su nombre y un svg del estilo del menú', JSON.stringify(pags.map(x => x[0])) === JSON.stringify(PAGS) && pags.every(x => x[2]) && pags.map(x => x[1]).join('|') === 'Resumen|Bancos y tarjetas|Bandeja|Conciliar|Movimientos|Estados financieros|Cobros en línea|Conexiones y seguridad', JSON.stringify(pags));
  ok('La página no repite el título que ya pone la barra de la app: la cabecera trae la línea de cifras y, como aria-label, el nombre', (await p.locator('.ct-pag-h').count()) === 0 && (await p.locator('.ct-pag-cab').getAttribute('aria-label')) === 'Resumen' && (await p.locator('.ct-pag-sub').count()) === 1);
  {
    // la lista de respaldo de app.js (por si conta.js no cargó) lleva los mismos trazos que ICONOS de conta.js: el lateral y las pestañas nunca enseñan iconos distintos para la misma página
    const appJs = fs.readFileSync(path.join(ROOT, 'js', 'app.js'), 'utf8'), contaJs = fs.readFileSync(path.join(ROOT, 'js', 'conta.js'), 'utf8');
    const fijos = Object.fromEntries([...appJs.matchAll(/\{ k: "(\w+)", nombre: "[^"]+", svg: SVG_MENU\('([^']*)'\) \}/g)].map(m => [m[1], m[2]]));
    const iconos = Object.fromEntries([...contaJs.matchAll(/^\s+(\w+): svgMenu\('([^']*)'\),?$/gm)].map(m => [m[1], m[2]]));
    ok('La lista de respaldo CONTA_PAGINAS_FIJAS de app.js trae los mismos 8 trazos que ICONOS de conta.js', Object.keys(fijos).length === 8 && PAGS.every(k => fijos[k] && fijos[k] === iconos[k]), PAGS.filter(k => fijos[k] !== iconos[k]).join(','));
  }
  ok('En la computadora (1280 px) las pestañas de arriba van escondidas (las enseña el lateral), pero siguen en el DOM con sus 8 páginas', (await p.locator('.ct-tabs').evaluate(e => getComputedStyle(e).display)) === 'none' && (await p.locator('.ct-tab').count()) === 8 && JSON.stringify(await p.locator('.ct-tab').evaluateAll(bs => bs.map(b => b.dataset.pag))) === JSON.stringify(PAGS));
  await espiar(p);
  const ctrlR0 = desde(n).find(l => l.fn === 'fn_banco_control');
  ok('La portada pidió fn_banco_control(hoy) con las cuatro vistas del banco (v_banco_saldos manda) y fn_estados_control con v_resultados del mes de hoy', !!ctrlR0 && ctrlR0.args.p_periodo === 'hoy' && JSON.stringify(ctrlR0.args.p_vistas) === '["v_banco_saldos","v_banco_bandeja","v_conciliacion","v_banco_movimientos"]' &&
    desde(n).some(l => l.fn === 'fn_estados_control' && JSON.stringify(l.args.p_vistas) === '["v_resultados"]' && l.args.p_periodo === mesRegla) && lecturas.slice(nLect).some(l => new RegExp('^v_resultados\\?.*periodo=eq\\.' + mesRegla).test(l)), JSON.stringify(ctrlR0 && ctrlR0.args));
  const fichaTxt = async k => texto(p, `.ct-ficha[data-ir="${k}"]`);
  const diasViejo = Math.round((Date.parse(HOY) - Date.parse('2026-10-02')) / 86400000);
  ok('Fichas: Bancos $16,457.20 en libros (1010 + 1030, sin la 1020 de Stripe) «sin archivo del banco todavía»; Tarjetas $23,220.37 (lo que se debe, 2 tarjetas); Bandeja 3, «el más viejo del 2 oct»; Cobros en línea $4,000.00 sin depositar y $4,200.50 en camino',
    /Bancos\$16,457\.20en libros · sin archivo del banco todavía/.test(await fichaTxt('bancos')) && /Tarjetas\$23,220\.37lo que se debe · 2 tarjetas/.test(await texto(p, '.ct-ficha[data-ir="bancos"] >> nth=1')) &&
    /^Bandeja3esperan · el más viejo del 2 oct/.test(await fichaTxt('bandeja')) && /Cobros en línea\$4,000\.00en Stripe sin depositar · en camino \$4,200\.50/.test(await fichaTxt('cobros')), (await fichaTxt('bancos')) + ' | ' + (await fichaTxt('bandeja')) + ' | ' + (await fichaTxt('cobros')));
  ok('La ficha de la bandeja se pone en rojo solo si lo más viejo pasa de 30 días', (await p.locator('.ct-ficha[data-ir="bandeja"]').evaluate(e => e.classList.contains('bad'))) === (diasViejo > 30), diasViejo);
  const resMes = T.v_resultados.filter(f => f.periodo === mesRegla), ingMes = resMes.find(f => f.nivel === 'seccion' && f.seccion === 'ingresos'), netaMes = resMes.find(f => f.nivel === 'total' && f.linea === 'utilidad_neta');
  const fmtUS = v => '$' + Number(v).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const mesTxt = await fichaTxt('estados');
  ok(resMes.length ? `«Este mes» trae ingresos ${fmtUS(ingMes.mes)}, costo y gastos (la suma de las secciones que no son ingresos) y el resultado ${fmtUS(netaMes.mes)} de v_resultados, y lleva a Estados` : '«Este mes» sin asientos lo dice en llano (no pinta ceros)',
    resMes.length ? new RegExp('Ingresos' + fmtUS(ingMes.mes).replace(/[$.]/g, '\\$&') + 'Costo y gastos' + fmtUS(resMes.filter(f => f.nivel === 'seccion' && f.seccion !== 'ingresos').reduce((a, f) => a + f.mes, 0)).replace(/[$.]/g, '\\$&') + 'Resultado' + fmtUS(netaMes.mes).replace(/[$.]/g, '\\$&')).test(mesTxt) : /no tiene asientos de resultados todavía/.test(mesTxt) && !/\$0\.00/.test(mesTxt), mesTxt);
  const atn = await p.locator('#ct-atender .ct-atn').allTextContents();
  ok('«Qué atender»: el código del teléfono no activo (→ Conexiones) y la cuenta de Plaid sin fijar (→ Conexiones); nada de Stripe (su control está en verde)', atn.length === 2 && /El código del teléfono .*no está activo/.test(atn[0]) && /Platypus Bank: 1 cuenta del banco sin fijar/.test(atn[1]) && (await p.locator('#ct-atender .ct-atn button[data-ir="conexiones"]').count()) === 2, atn.join(' | '));
  await foto(p, '0-resumen');
  await p.locator('.ct-ficha[data-ir="bandeja"]').click(); await p.waitForSelector('.ct-mov', { timeout: 8000 });
  const hooks1 = await p.evaluate(() => ({ pag: window.__pag.slice(), vol: window.__vol.slice() }));
  ok('Tocar la ficha de la bandeja abre la Bandeja: hooks.pagina("bandeja") y hooks.volver(false) (en la raíz de una página no hay nada interno que cerrar)', (await titulo()) === 'Bandeja' && hooks1.pag.join() === 'bandeja' && hooks1.vol.length >= 1 && hooks1.vol.every(v => v === false), JSON.stringify(hooks1));
  ok('…y el lateral ancho enciende «conta-bandeja» (lo hace app.js con hooks.pagina) y «←» no está a la vista (lo hace app.js con hooks.volver)', (await p.locator('#lateral [data-lat="conta-bandeja"][aria-current="page"]').count()) === 1 && (await p.locator('#lateral .lat-item[aria-current="page"]').count()) === 1 && await p.locator('#btn-volver').isHidden());
  await p.locator('#lateral [data-lat="conta-conciliar"]').evaluate(b => b.click()); await p.waitForSelector('#ct-conc-form', { timeout: 8000 });
  // (app.js vuelve a llamar a abrir(hooks, k) con hooks nuevos: los espías se vuelven a poner)
  await espiar(p);
  ok('El subtítulo del lateral abre su página (Conciliar) y queda encendido', (await titulo()) === 'Conciliar' && (await p.evaluate(() => window.MXP_CONTA._estado.pagina)) === 'conciliar' && (await p.locator('#lateral [data-lat="conta-conciliar"][aria-current="page"]').count()) === 1);
  await tab(p, 'resumen'); await p.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 });
  await p.locator('#ct-atender .ct-atn button[data-ir="conexiones"]').first().click(); await p.waitForSelector('#ct-mfa', { timeout: 8000 });
  ok('El botón de «Qué atender» lleva a Conexiones y seguridad', (await titulo()) === 'Conexiones y seguridad' && (await p.evaluate(() => window.__pag.slice(-1)[0])) === 'conexiones');

  // ---- Bancos y tarjetas: control antes de pintar, solo las cuentas ----
  n = llamadas.length;
  await tab(p, 'bancos'); await p.waitForSelector('#conta-raiz .ct-cuenta', { timeout: 8000 });
  ok('Bancos y tarjetas: el título, una tarjeta por cuenta (4) y NINGUNA tarjeta del código del teléfono, de Plaid ni de Stripe (viven en Conexiones)', (await p.locator('#titulo-vista').textContent()).trim() === 'Bancos y tarjetas' && (await p.locator('.ct-cuenta').count()) === 4 && (await p.locator('#ct-mfa, #ct-plaid, #ct-stripe').count()) === 0, await p.locator('.ct-cuenta').count());
  const ctrl = desde(n).find(l => l.fn === 'fn_banco_control');
  ok('Pidió el control con la vista que pinta (v_banco_saldos, período hoy)', !!ctrl && ctrl.args.p_periodo === 'hoy' && JSON.stringify(ctrl.args.p_vistas) === '["v_banco_saldos"]', JSON.stringify(ctrl && ctrl.args));
  ok('La Gold dice su deuda en libros ($14,624.26) y la del banco ($14,675.12 al 8 oct), con «3 en la bandeja» y las acciones Bandeja / Conciliar / Movimientos', /\$14,624\.26/.test(await texto(p, '.ct-cuenta[data-cuenta="2100-2013"] .ct-val')) && /\$14,675\.12/.test(await texto(p, '.ct-cuenta[data-cuenta="2100-2013"] .ct-val')) && /8 oct 2026/.test(await texto(p, '.ct-cuenta[data-cuenta="2100-2013"]')) &&
    /3 en la bandeja/.test(await texto(p, '.ct-cuenta[data-cuenta="2100-2013"] .ct-cab')) && JSON.stringify(await p.locator('.ct-cuenta[data-cuenta="2100-2013"] [data-ir]').evaluateAll(bs => bs.map(b => b.dataset.ir))) === '["bandeja","conciliar","movimientos"]');
  ok('El contador de la bandeja dice 3', (await p.locator('#ct-n-bandeja').textContent()).trim() === '3');
  ok('…y el subtítulo «Bandeja» del lateral lleva el mismo 3 (en la computadora las pestañas van escondidas)', (await p.locator('#lateral [data-lat="conta-bandeja"] #lat-conta-badge').textContent()).trim() === '3' && await p.locator('#lat-conta-badge').isVisible());
  ok('El importador general va plegado detrás de «Importar un estado de cuenta»', (await p.locator('#ct-importar').isHidden()) && (await p.locator('#ct-imp-abrir').getAttribute('aria-expanded')) === 'false');
  await foto(p, '1-bancos');

  // ---- Falla ruidosa ----
  estado.controlMal = true;
  await tab(p, 'resumen'); await p.waitForSelector('.ct-rojo', { timeout: 8000 });
  ok('Control en rojo en la portada: rojo con el detalle y ninguna ficha ni cifra', (await p.locator('.ct-ficha').count()) === 0 && /no cuadra/.test(await texto(p, '.ct-rojo h2')) && /prueba/.test(await texto(p, '.ct-rojo')));
  await tab(p, 'bancos'); await p.waitForSelector('.ct-rojo', { timeout: 8000 });
  await foto(p, '2-rojo');
  ok('Control en rojo: la pantalla se pone en rojo y no pinta ninguna cuenta', (await p.locator('.ct-cuenta').count()) === 0 && /no cuadra/.test(await texto(p, '.ct-rojo h2')) && /prueba/.test(await texto(p, '.ct-rojo')));
  estado.controlMal = false; estado.controlFilas = 99;
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('.ct-rojo', { timeout: 8000 }); await p.waitForTimeout(200);
  ok(`Si la pantalla trae ${T.v_banco_saldos.length} (la lista entera, con la 1020 de Stripe) y el control cuenta 99, también es rojo`, new RegExp(`trajo ${T.v_banco_saldos.length} fila\\(s\\) y el control contó 99`).test(await texto(p, '.ct-rojo')));
  estado.controlFilas = null;
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('.ct-cuenta', { timeout: 8000 });
  ok('Al cuadrar otra vez, vuelve a pintar', (await p.locator('.ct-cuenta').count()) === 4);

  // ---- Importar ----
  n = llamadas.length;
  await p.locator('#ct-imp-abrir').click(); await p.waitForSelector('#ct-importar:not([hidden])', { timeout: 8000 });
  ok('«Importar un estado de cuenta» abre la tarjeta del importador (con su «¿Qué es esto?» plegado)', await p.locator('#ct-importar').isVisible() && (await p.locator('#ct-importar .ct-ayuda').count()) === 1 && !(await p.locator('#ct-importar .ct-ayuda').evaluate(d => d.open)));
  await p.setInputFiles('#ct-imp-archivo', { name: 'gold-2026-10-08.qfx', mimeType: 'application/x-ofx', buffer: Buffer.from(OFX, 'latin1') });
  await p.locator('#ct-imp-btn').click();
  await p.waitForSelector('.ct-ok-box', { timeout: 10000 });
  const imp = desde(n).find(l => l.fn === 'fn_banco_importar_ofx');
  ok('El importador manda el archivo entero como texto, sin cuenta (la dice el archivo) y con su nombre', !!imp && imp.args.p_cuenta === null && imp.args.p_nombre === 'gold-2026-10-08.qfx' && /OFXHEADER:100/.test(imp.args.p_texto) && /<\/OFX>/.test(imp.args.p_texto));
  const casas = desde(n).filter(l => l.fn === 'fn_banco_casar_todo');
  ok('Después casa hasta «completo» (dos rondas, con la cuenta del archivo)', casas.length === 2 && casas.every(c => c.args.p_cuenta === '2100-2013'), casas.length);
  ok('Y lo cuenta: 25 casaron solos (20 + 5), 4 esperan', /25 movimientos casaron solos/.test(await texto(p, '.ct-ok-box')) && /4 esperan/.test(await texto(p, '.ct-ok-box')) && /Un aviso de prueba/.test(await texto(p, '.ct-ok-box')));
  n = llamadas.length;
  await p.setInputFiles('.ct-cuenta[data-cuenta="1010"] input[type=file]', { name: 'chase.qfx', mimeType: 'application/x-ofx', buffer: Buffer.from(OFX.replace('CREDITCARDMSGSRSV1', 'BANKMSGSRSV1'), 'latin1') });
  await p.waitForFunction(() => document.querySelector('.ct-ok-box') && /chase\.qfx/.test(document.querySelector('.ct-ok-box').textContent), null, { timeout: 10000 });
  const imp2 = desde(n).find(l => l.fn === 'fn_banco_importar_ofx');
  ok('Subir desde la tarjeta de una cuenta manda esa cuenta (1010)', !!imp2 && imp2.args.p_cuenta === '1010');

  // ---- La bandeja (el bank feed) ----
  n = llamadas.length;
  await tab(p, 'bandeja'); await p.waitForSelector('.ct-mov', { timeout: 8000 });
  ok('La bandeja pinta los 3 movimientos y pidió su control (v_banco_bandeja)', (await p.locator('.ct-mov').count()) === 3 && desde(n).some(l => l.fn === 'fn_banco_control' && JSON.stringify(l.args.p_vistas) === '["v_banco_bandeja"]'));
  ok('Sin c8 en la base (v_contador_* contesta 404) la bandeja es la de siempre: la pidió, y no hay franja de la IA, ni chips, ni columnas, ni llamada a la función «contador»',
    lecturas.some(l => /^v_contador_estado\?/.test(l)) && (await p.locator('#ct-ia-franja, .ct-ia-chip, .ct-ia').count()) === 0 && !desde(n).some(l => /^contador:/.test(l.fn)) && (await p.locator('.ct-rojo').count()) === 0);
  ok('El de más de 30 días va primero, con su alarma', (await p.locator('.ct-mov').first().getAttribute('data-id')) === MOV.c && /más de 30 días/.test(await texto(p, '.ct-mov >> nth=0')));
  ok('La cabecera dice «3 movimientos del banco esperan tu respuesta por $315.34 · 1 lleva más de 30 días» y «Casar otra vez» es su acción', /3 movimientos del banco esperan tu respuesta por \$315\.34 · 1 lleva más de 30 días/.test(await texto(p, '.ct-pag-sub')) && (await p.locator('.ct-pag-acc #ct-casar').count()) === 1, await texto(p, '.ct-pag-sub'));
  ok('Filas compactas: cada movimiento es un <article class="ct-mov" data-id> con su cabecera (un botón, aria-expanded) y el detalle plegado; en la computadora la cabecera es una fila de tabla con las columnas alineadas',
    (await p.locator('.ct-mov .ct-mov-fila[aria-expanded="false"]').count()) === 3 && (await p.locator('.ct-mov .ct-mov-det[hidden]').count()) === 3 && (await p.locator('.ct-feed-cab').isVisible()) &&
    (await p.locator('.ct-mov-fila').first().evaluate(e => getComputedStyle(e).gridTemplateAreas)).includes('fecha desc cuenta motivo monto chev') && /PEAJE EJEMPLO/.test(await texto(p, '.ct-mov >> nth=0 >> .ct-f-desc')) && /Amex Business Gold/.test(await texto(p, '.ct-mov >> nth=0 >> .ct-f-cuenta')) && /¿Duplicado\?/.test(await texto(p, '.ct-mov >> nth=0 >> .ct-f-motivo')) && /−\$61\.21/.test(await texto(p, '.ct-mov >> nth=0 >> .ct-f-monto')));
  const cardB = p.locator(`.ct-mov[data-id="${MOV.b}"]`);
  ok('El que tiene propuesta pinta un botón por opción (4) más «Otra cosa…»', (await cardB.locator('[data-op]').count()) === 4 && (await cardB.locator('[data-otra]').count()) === 1);
  ok('El sin ticket no tiene botones de la base, solo «Otra cosa…»', (await p.locator(`.ct-mov[data-id="${MOV.a}"] [data-op]`).count()) === 0);
  // desplegar una fila: solo una a la vez
  await cardB.locator('.ct-mov-fila').click(); await p.waitForTimeout(150);
  ok('Tocar la fila la despliega (el texto de la base y sus botones a la vista) y es la única desplegada', (await cardB.locator('.ct-mov-fila').getAttribute('aria-expanded')) === 'true' && await cardB.locator('.ct-mov-det').isVisible() && await cardB.locator('[data-op="0"]').isVisible() && (await p.locator('.ct-mov.abierta').count()) === 1 && /Puede ser una partida en tránsito/.test(await cardB.locator('.ct-texto').textContent()));
  ok('Desplegada, la descripción envuelve y se lee entera (plegada va en una línea con «…»); la fila lleva la descripción como title', (await cardB.locator('.ct-f-desc b').evaluate(e => getComputedStyle(e).whiteSpace)) === 'normal' && (await p.locator(`.ct-mov[data-id="${MOV.a}"] .ct-f-desc b`).evaluate(e => getComputedStyle(e).whiteSpace)) === 'nowrap' && (await cardB.locator('.ct-f-desc').getAttribute('title')) === (await cardB.locator('.ct-f-desc b').textContent()));
  await p.locator(`.ct-mov[data-id="${MOV.a}"] .ct-mov-fila`).click(); await p.waitForTimeout(150);
  ok('Tocar otra cierra la anterior', (await p.locator('.ct-mov.abierta').count()) === 1 && (await p.locator(`.ct-mov[data-id="${MOV.a}"] .ct-mov-fila`).getAttribute('aria-expanded')) === 'true' && (await cardB.locator('.ct-mov-fila').getAttribute('aria-expanded')) === 'false' && await cardB.locator('.ct-mov-det').isHidden());
  await p.locator(`.ct-mov[data-id="${MOV.a}"] .ct-mov-fila`).click(); await p.waitForTimeout(150);
  ok('Tocar la desplegada la pliega', (await p.locator('.ct-mov.abierta').count()) === 0);
  // la barra: buscador, motivo, orden, agrupar por comercio (sin volver a la base)
  nLect = lecturas.length; n = llamadas.length;
  await p.fill('#ct-bj-buscar', 'peaje'); await p.waitForTimeout(150);
  ok('El buscador filtra por descripción («peaje» → 1) y dice «1 de 3 movimientos», sin volver a leer', (await p.locator('.ct-mov').count()) === 1 && (await p.locator('.ct-mov').first().getAttribute('data-id')) === MOV.c && /1 de 3 movimientos/.test(await texto(p, '#ct-bj-n')) && lecturas.length === nLect && desde(n).length === 0, await texto(p, '#ct-bj-n'));
  await p.fill('#ct-bj-buscar', '123.45'); await p.waitForTimeout(150);
  ok('…y por monto («123.45» → la ferretería)', (await p.locator('.ct-mov').count()) === 1 && (await p.locator('.ct-mov').first().getAttribute('data-id')) === MOV.a);
  await p.fill('#ct-bj-buscar', 'zzz'); await p.waitForTimeout(150);
  ok('Sin resultado lo dice («Nada con ese filtro (zzz)»)', (await p.locator('.ct-mov').count()) === 0 && /Nada con ese filtro \(«zzz»\)/.test(await texto(p, '#ct-bj-lista .ct-vacio')));
  await p.fill('#ct-bj-buscar', ''); await p.waitForTimeout(150);
  const optMotivo = await p.locator('#ct-bj-motivo option').allTextContents();
  await p.selectOption('#ct-bj-motivo', 'sin_ticket'); await p.waitForTimeout(150);
  ok('El filtro por motivo ofrece los motivos presentes en llano con su conteo y filtra («Sin ticket» → 1)', optMotivo.length === 4 && optMotivo.some(t => /Sin ticket \(1\)/.test(t)) && optMotivo.some(t => /¿Duplicado\? \(1\)/.test(t)) && (await p.locator('.ct-mov').count()) === 1 && (await p.locator('.ct-mov').first().getAttribute('data-id')) === MOV.a, optMotivo.join(' | '));
  await p.selectOption('#ct-bj-motivo', ''); await p.selectOption('#ct-bj-orden', 'monto_desc'); await p.waitForTimeout(150);
  ok('Ordenar por monto (de mayor a menor) pone primero el de $500.00 y último el de $61.21', (await p.locator('.ct-mov').first().getAttribute('data-id')) === MOV.b && (await p.locator('.ct-mov').last().getAttribute('data-id')) === MOV.c);
  await p.selectOption('#ct-bj-orden', 'fecha_desc'); await p.waitForTimeout(150);
  ok('«Más nuevos primero» pone primero el del 6 oct', (await p.locator('.ct-mov').first().getAttribute('data-id')) === MOV.c && (await p.locator('.ct-mov').last().getAttribute('data-id')) === MOV.a);
  await p.selectOption('#ct-bj-orden', 'fecha_asc'); await p.check('#ct-bj-agrupar'); await p.waitForTimeout(150);
  const grupos = await p.locator('.ct-grupo').evaluateAll(gs => gs.map(g => [g.dataset.grupo, g.open, g.querySelector('.ct-g-n').textContent.trim(), g.querySelector('.ct-g-desc small').textContent, g.querySelector('.ct-g-monto').textContent]));
  ok('«Agrupar por comercio» arma un grupo por descripción normalizada (3, plegados) con su cuenta, su conteo y su total; las filas siguen dentro', grupos.length === 3 && grupos.every(g => !g[1] && /1 movimiento/.test(g[2]) && g[3] === 'Amex Business Gold') && grupos.some(g => g[0] === 'PEAJE EJEMPLO' && g[4] === '−$61.21') && grupos.some(g => g[0] === 'ONLINE PAYMENT - THANK YOU' && g[4] === '+$500.00') && (await p.locator('.ct-grupo .ct-mov').count()) === 3, JSON.stringify(grupos));
  await p.locator('.ct-grupo[data-grupo="PEAJE EJEMPLO"] summary').click(); await p.waitForTimeout(150);
  const cardCg = await fila(p, MOV.c);
  ok('Un grupo se despliega a sus filas y una fila dentro del grupo se despliega a su detalle con sus botones', (await p.locator('.ct-grupo[data-grupo="PEAJE EJEMPLO"]').evaluate(g => g.open)) && await cardCg.locator('[data-op="1"]').isVisible());
  n = llamadas.length;
  await cardCg.locator('[data-op="1"]').click(); await esperarLlamada(p, n, 'fn_banco_duplicado'); await pintado(p);
  const dup = desde(n).find(l => l.fn === 'fn_banco_duplicado');
  ok('…y el botón llama igual que siempre: fn_banco_duplicado {p_movimiento, p_es_el_mismo: false}', !!dup && dup.args.p_movimiento === MOV.c && dup.args.p_es_el_mismo === false, JSON.stringify(dup && dup.args));
  ok('Al repintar, la agrupación sigue y la fila tocada sigue desplegada (su grupo abierto)', (await p.locator('#ct-bj-agrupar').isChecked()) && (await p.locator('.ct-grupo').count()) === 3 && (await p.locator(`.ct-mov[data-id="${MOV.c}"] .ct-mov-fila`).getAttribute('aria-expanded')) === 'true' && (await p.locator('.ct-grupo[data-grupo="PEAJE EJEMPLO"]').evaluate(g => g.open)));
  const cabCols = async () => (await p.locator('.ct-feed-cab span').allTextContents()).filter(Boolean).join(' · ');
  ok('Agrupado, la cabecera de columnas dice Comercio · Movimientos · Total (lo que hay debajo)', (await p.locator('.ct-feed.agrupada').count()) === 1 && (await cabCols()) === 'Comercio · Movimientos · Total', await cabCols());
  await foto(p, '3b-bandeja-agrupada');
  await p.uncheck('#ct-bj-agrupar'); await p.waitForTimeout(150);
  ok('Sin agrupar vuelven las 3 filas sueltas, en el orden de la base', (await p.locator('.ct-grupo').count()) === 0 && (await p.locator('.ct-mov').count()) === 3 && (await p.locator('.ct-mov').first().getAttribute('data-id')) === MOV.c);
  ok('…y la cabecera vuelve a las columnas del movimiento: Fecha · Descripción · Cuenta · Motivo · Monto', (await cabCols()) === 'Fecha · Descripción · Cuenta · Motivo · Monto', await cabCols());
  await fila(p, MOV.b);
  await foto(p, '3-bandeja');
  // la opción que pide motivo
  n = llamadas.length;
  await cardB.locator('[data-op="2"]').click();
  ok('La opción con pide_motivo abre el campo del motivo en vez de llamar', (await cardB.locator('textarea[name="p_motivo"]').count()) === 1 && !desde(n).some(l => l.fn === 'fn_banco_transferencia'));
  await cardB.locator('button[type=submit]').click(); await p.waitForTimeout(200);
  ok('Sin motivo no manda nada y lo dice', /Falta/.test(await texto(p, `.ct-mov[data-id="${MOV.b}"] .ct-error`)) && !desde(n).some(l => l.fn === 'fn_banco_transferencia'));
  await cardB.locator('textarea[name="p_motivo"]').fill('Pago de la Gold desde Chase el 5 de octubre');
  await cardB.locator('button[type=submit]').click();
  await p.waitForFunction(() => document.getElementById('toast') && !document.getElementById('toast').hidden && /Hecho/.test(document.getElementById('toast').textContent), null, { timeout: 8000 });
  const tr = desde(n).find(l => l.fn === 'fn_banco_transferencia');
  ok('Con motivo llama a fn_banco_transferencia con los args de la base más el motivo', !!tr && tr.args.p_movimiento === MOV.b && tr.args.p_cuenta === '1010' && tr.args.p_motivo === 'Pago de la Gold desde Chase el 5 de octubre', JSON.stringify(tr && tr.args));
  ok('…y dice «Hecho: casado · asiento 2026-000012»', /Hecho: casado · asiento 2026-000012/.test(await p.locator('#toast').textContent()));
  await pintado(p); await p.waitForSelector(`.ct-mov[data-id="${MOV.b}"] .ct-mov-fila`, { state: 'attached', timeout: 8000 });
  ok('Después de la acción la bandeja se repinta y la fila sigue desplegada (sigue en la lista)', (await cardB.locator('.ct-mov-fila').getAttribute('aria-expanded')) === 'true' && (await p.locator('.ct-mov.abierta').count()) === 1);
  // la opción sin pide: un toque
  await p.waitForSelector(`.ct-mov[data-id="${MOV.b}"] [data-op="0"]`, { timeout: 8000 });
  n = llamadas.length;
  await p.locator(`.ct-mov[data-id="${MOV.b}"] [data-op="0"]`).click();
  await esperarLlamada(p, n, 'fn_banco_casar_con'); await p.waitForTimeout(400);
  const cc = desde(n).find(l => l.fn === 'fn_banco_casar_con');
  ok('La opción sin motivo llama de un toque: fn_banco_casar_con con la partida de apertura', !!cc && cc.args.p_movimiento === MOV.b && cc.args.p_con && cc.args.p_con.partida_apertura === PART.p1, JSON.stringify(cc && cc.args));
  // «Otra cosa…»: clasificar con obra
  await pintado(p); n = llamadas.length;
  const cardA = await fila(p, MOV.a);
  await cardA.locator('[data-otra]').click();
  await cardA.locator('[data-que="clasificar"]').click();
  await foto(p, '4-clasificar');
  ok('Clasificar ofrece el plan de cuentas por grupos (costo, gasto…) y las obras', (await cardA.locator('select[name="cuenta"] optgroup').count()) >= 4 && (await cardA.locator('select[name="proyecto"] option').count()) === 4);
  await cardA.locator('select[name="cuenta"]').selectOption('6300');
  await cardA.locator('select[name="proyecto"]').selectOption('casa-perez-k3m9');
  await cardA.locator('button[type=submit]').click(); await p.waitForTimeout(600);
  const cl = desde(n).find(l => l.fn === 'fn_banco_clasificar');
  ok('Manda fn_banco_clasificar con una línea {cuenta, proyecto_id} y sin motivo (null)', !!cl && cl.args.p_movimiento === MOV.a && JSON.stringify(cl.args.p_lineas) === JSON.stringify([{ cuenta: '6300', proyecto_id: 'casa-perez-k3m9' }]) && cl.args.p_motivo === null, JSON.stringify(cl && cl.args));
  // ignorar pide motivo
  await pintado(p); await fila(p, MOV.a);
  n = llamadas.length;
  await p.locator(`.ct-mov[data-id="${MOV.a}"] [data-otra]`).click();
  await p.locator(`.ct-mov[data-id="${MOV.a}"] [data-que="ignorar"]`).click();
  await p.locator(`.ct-mov[data-id="${MOV.a}"] button[type=submit]`).click(); await p.waitForTimeout(200);
  ok('Ignorar sin motivo no manda nada', !desde(n).some(l => l.fn === 'fn_banco_ignorar'));
  await p.locator(`.ct-mov[data-id="${MOV.a}"] textarea[name="p_motivo"]`).fill('Es un cargo personal que devolví');
  await p.locator(`.ct-mov[data-id="${MOV.a}"] button[type=submit]`).click(); await p.waitForTimeout(600);
  const ig = desde(n).find(l => l.fn === 'fn_banco_ignorar');
  ok('Con motivo, fn_banco_ignorar lo lleva', !!ig && ig.args.p_motivo === 'Es un cargo personal que devolví');
  // la partida del 30-sep a mano
  await pintado(p); await fila(p, MOV.a);
  n = llamadas.length;
  await p.locator(`.ct-mov[data-id="${MOV.a}"] [data-otra]`).click();
  await p.locator(`.ct-mov[data-id="${MOV.a}"] [data-que="partida"]`).click();
  await p.waitForSelector(`.ct-mov[data-id="${MOV.a}"] select[name="partida"]`, { timeout: 8000 });
  ok('«Partida del 30-sep» lista las de la apertura de esa cuenta (2)', (await p.locator(`.ct-mov[data-id="${MOV.a}"] select[name="partida"] option`).count()) === 3);
  await p.locator(`.ct-mov[data-id="${MOV.a}"] select[name="partida"]`).selectOption(PART.p2);
  await p.locator(`.ct-mov[data-id="${MOV.a}"] button[type=submit]`).click(); await p.waitForTimeout(600);
  const cp = desde(n).find(l => l.fn === 'fn_banco_casar_con');
  ok('…y casa con {partida_apertura}', !!cp && cp.args.p_con && cp.args.p_con.partida_apertura === PART.p2);
  // el error de la base se enseña en la tarjeta
  await pintado(p); await fila(p, MOV.c);
  estado.fallar = true;
  await p.locator(`.ct-mov[data-id="${MOV.c}"] [data-op="0"]`).click();
  await p.waitForSelector(`.ct-mov[data-id="${MOV.c}"] .ct-error`, { timeout: 8000 });
  ok('Si la base dice que no, el motivo sale en la tarjeta y los botones vuelven', /La base dijo que no \(prueba\)/.test(await texto(p, `.ct-mov[data-id="${MOV.c}"] .ct-error`)) && !(await p.locator(`.ct-mov[data-id="${MOV.c}"] [data-op="0"]`).isDisabled()));
  estado.fallar = false;
  // «Casar otra vez»
  n = llamadas.length;
  await p.locator('#ct-casar').click(); await p.waitForSelector('.ct-mov', { timeout: 8000 }); await p.waitForTimeout(300);
  ok('«Casar otra vez» llama a fn_banco_casar_todo sin cuenta, hasta completo', desde(n).filter(l => l.fn === 'fn_banco_casar_todo' && l.args.p_cuenta === null).length === 2);

  // ---- Conciliar ----
  n = llamadas.length;
  await tab(p, 'conciliar'); await p.waitForSelector('#ct-conc-form', { timeout: 8000 });
  ok('Conciliar lista la apertura confirmada y pidió su control; la cabecera cuenta «1 conciliación · 0 abiertas · 1 confirmada» y la explicación larga va plegada en «¿Qué es esto?»', (await p.locator('[data-conc]').count()) === 1 && desde(n).some(l => l.fn === 'fn_banco_control' && JSON.stringify(l.args.p_vistas) === '["v_conciliacion"]') &&
    /1 conciliación · 0 abiertas · 1 confirmada/.test(await texto(p, '.ct-pag-sub')) && /Sube antes el archivo del statement/.test(await texto(p, '.ct-ayuda')) && !(await p.locator('.ct-ayuda').first().evaluate(d => d.open)), await texto(p, '.ct-pag-sub'));
  await p.locator('#ct-conc-form select[name="cuenta"]').selectOption('2100-2013');
  ok('Al elegir la Gold, la fecha y el saldo salen del último archivo (8 oct, 14675.12)', (await p.inputValue('#ct-conc-form input[name="fecha"]')) === '2026-10-08' && (await p.inputValue('#ct-conc-form input[name="saldo"]')) === '14675.12');
  await p.fill('#ct-conc-form input[name="saldo"]', '14,675.12');
  n = llamadas.length;
  await p.locator('#ct-conc-form button[type=submit]').click();
  await p.waitForSelector('#ct-conf', { timeout: 8000 });
  const fc = desde(n).find(l => l.fn === 'fn_conciliar');
  ok('fn_conciliar recibe la cuenta, la fecha y el saldo COMO TEXTO, con su coma', !!fc && fc.args.p_cuenta === '2100-2013' && fc.args.p_fecha_corte === '2026-10-08' && fc.args.p_saldo_statement === '14,675.12', JSON.stringify(fc && fc.args));
  await foto(p, '5-conciliacion');
  ok('Abre la conciliación: título, identidad, las dos listas y «Confirmar» porque está lista; hooks.volver(true) porque hay algo interno que cerrar', /Conciliación · Amex Business Gold/.test(await p.locator('#titulo-vista').textContent()) && /cuadra/.test(await texto(p, '.ct-nota')) && (await p.locator('.ct-partida').count()) >= 2 && (await p.evaluate(() => window.__vol.slice(-1)[0])) === true);
  n = llamadas.length;
  await p.locator('#ct-conf').click(); await p.waitForTimeout(600);
  const cf = desde(n).find(l => l.fn === 'fn_conciliacion_confirmar');
  ok('«Confirmar» llama a fn_conciliacion_confirmar con la conciliación', !!cf && cf.args.p_conciliacion === CONC_NEW);
  // «←»: primero cierra la conciliación, después sale
  await p.locator('#btn-volver').click(); await p.waitForSelector('#ct-conc-form', { timeout: 8000 });
  ok('«←» con la conciliación abierta vuelve a la lista (sigue en la contabilidad) y hooks.volver(false)', await p.locator('#vista-conta').isVisible() && (await p.locator('#titulo-vista').textContent()).trim() === 'Conciliar' && (await p.evaluate(() => window.__vol.slice(-1)[0])) === false);
  ok('En la raíz de la página ya no hay «←» (Contabilidad es una pestaña: app.js lo esconde con hooks.volver(false))', await p.locator('#btn-volver').isHidden());
  await p.locator('#lateral [data-lat="hoy"]').evaluate(b => b.click()); await p.waitForTimeout(400);
  ok('Se sale de la contabilidad por el menú (Hoy)', await p.locator('#vista-conta').isHidden());

  // ---- Movimientos ----
  await p.locator('#btn-conta').evaluate(b => b.click()); await p.waitForSelector('#ct-main', { state: 'attached', timeout: 8000 }); await espiar(p);
  ok('Volver a entrar abre la última página en la que se estaba (Conciliar), no la portada', (await p.evaluate(() => window.MXP_CONTA._estado.pagina)) === 'conciliar');
  await tab(p, 'movimientos'); await p.waitForSelector('#ct-mov-cuenta', { timeout: 8000 });
  ok('Movimientos arranca en la primera cuenta (Chase, sin movimientos de prueba) y lo dice; los selectores van en la cabecera', (await p.inputValue('#ct-mov-cuenta')) === '1010' && /Nada con ese filtro/.test(await texto(p, '.ct-vacio')) && (await p.locator('.ct-pag-ctl #ct-mov-cuenta').count()) === 1);
  await p.selectOption('#ct-mov-cuenta', '2100-2013'); await p.waitForSelector('.ct-tabla tbody tr', { timeout: 8000 });
  await foto(p, '6-movimientos');
  ok('Movimientos pinta la tabla densa de la cuenta (2 filas, cabecera a la vista) con su estado', (await p.locator('.ct-tabla tbody tr').count()) === 2 && /casado/.test(await texto(p, '.ct-tabla')) && (await p.locator('.ct-mov-tabla thead').isVisible()) && /2 movimientos de Amex Business Gold/.test(await texto(p, '.ct-pag-sub')));

  // ---- Estados financieros (c4) ----
  const estEst = () => p.evaluate(() => window.MXP_CONTA._estado.est);
  // tocar un chip de período; si está escondido (empieza después de hoy), antes «Más períodos»
  const elegir = async per => { if (!(await p.locator(`[data-periodo="${per}"]`).count())) { await p.locator('#ct-est-mas').click(); await p.waitForSelector(`[data-periodo="${per}"]`, { timeout: 8000 }); } await p.locator(`[data-periodo="${per}"]`).click(); };
  const esperarTexto = (sel, re) => p.waitForFunction(([s, r]) => { const e = document.querySelector(s); return e && new RegExp(r).test(e.textContent); }, [sel, re.source], { timeout: 8000 });
  const nBal = T.v_balance_general.filter(f => f.periodo === '2026-10').length;
  nLect = lecturas.length; n = llamadas.length;
  ok('Las pestañas van en el orden del menú: Resumen, Bancos, Bandeja, Conciliar, Movimientos, Estados, Cobros, Conexiones (cada una con su icono)', JSON.stringify(await p.locator('.ct-tab').evaluateAll(bs => bs.map(b => b.dataset.pag))) === JSON.stringify(PAGS) && (await p.locator('.ct-tab svg').count()) === 8 && /Estados/.test(await p.locator('.ct-tab').nth(5).textContent()));
  await tab(p, 'estados'); await p.waitForSelector('#ct-est-resultados', { timeout: 8000 });
  ok('Al tocarla el título es «Estados financieros» y aparece la barra de chips', (await titulo()) === 'Estados financieros' && (await p.locator('#ct-est-barra').count()) === 1, await titulo());
  const est0 = await estEst();
  ok('Arranca en Resultados con el mes de hoy preseleccionado por la regla (v_cortes leída con order=desde.desc)', est0.sub === 'resultados' && (await p.locator('[data-sub="resultados"][aria-pressed="true"]').count()) === 1 && est0.periodo === mesRegla && lecturas.slice(nLect).some(l => /^v_cortes\?.*order=desde\.desc/.test(l)), JSON.stringify({ periodo: est0.periodo, regla: mesRegla }));
  const chips = await texto(p, '#ct-est-periodos');
  ok('Los chips de período dicen palabras, no códigos; sin «Hoy» fuera del balance; el mes futuro va escondido tras «Más períodos»', /Octubre 2026/.test(chips) && /Septiembre 2026 · apertura/.test(chips) && /Año 2026/.test(chips) && !/2026-10|APERTURA/.test(chips) && !/Hoy/.test(chips) && (await p.locator(`[data-periodo="${FUTURO}"]`).count()) === 0 && /Más períodos/.test(await texto(p, '#ct-est-mas')), chips);
  n = llamadas.length; nLect = lecturas.length;
  await p.locator('[data-periodo="2026-10"]').click(); await p.waitForSelector('#ct-est-resultados .ct-kpi', { timeout: 8000 });
  const ctrlR = desde(n).filter(l => l.fn === 'fn_estados_control');
  ok('Pidió el control de Resultados con p_periodo 2026-10 y p_vistas [v_resultados, v_balance_general], en una sola llamada', ctrlR.length === 1 && ctrlR[0].args.p_periodo === '2026-10' && JSON.stringify(ctrlR[0].args.p_vistas) === '["v_resultados","v_balance_general"]', JSON.stringify(ctrlR.map(c => c.args)));
  ok('La lectura de v_resultados va con periodo=eq.2026-10', lecturas.slice(nLect).some(l => /^v_resultados\?.*periodo=eq\.2026-10/.test(l)), lecturas.slice(nLect).join(' | '));
  const kpiR = await texto(p, '#ct-est-resultados .ct-kpi');
  ok('KPIs de Resultados desde la vista: ingresos $22,000.00, utilidad bruta $10,000.00, utilidad neta $8,000.00 y el acumulado «desde el 1 oct 2026»', /Ingresos del mes\$22,000\.00/.test(kpiR) && /Utilidad bruta\$10,000\.00/.test(kpiR) && /Utilidad neta\$8,000\.00/.test(kpiR) && /Acumulado del año\$8,000\.00desde el 1 oct 2026/.test(kpiR), kpiR);
  const tbR = await texto(p, '#ct-est-resultados tbody'), pos = s => tbR.indexOf(s);
  ok('La tabla intercala secciones, subtotales y totales en el orden del estado, y la única fila cobre es «Utilidad neta»', pos('Ingresos') < pos('Total ingresos') && pos('Total ingresos') < pos('Costo de obra') && pos('Costo de obra') < pos('Utilidad bruta') && pos('Utilidad bruta') < pos('Gastos de operación') && pos('Gastos de operación') < pos('Utilidad de operación') && pos('Utilidad de operación') < pos('Utilidad neta') && (await p.locator('#ct-est-resultados tr.ct-neto').count()) === 1 && /Utilidad neta/.test(await texto(p, '#ct-est-resultados tr.ct-neto')), tbR.slice(0, 160));
  const antR = await p.locator('#ct-est-resultados td[data-col="Mes anterior"]').allTextContents();
  ok('Sin mes anterior en el libro: las celdas dicen «—» (ninguna $0.00) y la nota dice que septiembre está en QuickBooks', antR.length === 12 && antR.every(t => t.trim() === '—') && /Sin mes anterior en el libro: septiembre de 2026 está en QuickBooks/.test(await texto(p, '#ct-est-resultados .ct-nota')), antR.join('|'));
  ok('La franja dice «Cuadra · la utilidad neta es la misma que trae el balance» (cuadre 56), la cabecera lleva «Controlado» y toda cifra va en mono', /Cuadra · la utilidad neta es la misma que trae el balance/.test(await texto(p, '#ct-est-resultados .ct-cuadre')) && /Controlado/.test(await texto(p, '#ct-est-resultados .ct-cab .ct-pill')) && (await p.locator('#ct-est-resultados td.r:not(.ct-num)').count()) === 0);
  const alin = await p.evaluate(() => { const f = document.querySelector('#ct-est-resultados tr.ct-fila-cuenta'), s = document.querySelector('#ct-est-resultados tr.ct-subtotal'), td = f.querySelector('td.r'), r = document.createRange(); r.selectNodeContents(td);
    return { fila: f.getBoundingClientRect().height, lisa: s.getBoundingClientRect().height, btn: f.querySelector('.ct-cuenta-btn .ct-num').getBoundingClientRect().top, cifra: r.getBoundingClientRect().top }; });
  ok('El botón de la cuenta no estira la fila ni baja su etiqueta: la fila mide lo que una sin botón y el número de cuenta queda a la altura de la cifra', Math.abs(alin.fila - alin.lisa) <= 3 && Math.abs(alin.btn - alin.cifra) <= 2, JSON.stringify(alin));
  await foto(p, '11-estados-resultados');
  // noviembre: con mes anterior y variación
  n = llamadas.length;
  await elegir('2026-11'); await p.waitForSelector('#ct-est-resultados .ct-kpi', { timeout: 8000 });
  const ctrlN = desde(n).filter(l => l.fn === 'fn_estados_control').pop();
  const f4000 = p.locator('#ct-est-resultados tr.ct-fila-cuenta', { hasText: '4000' }), t4000 = await f4000.textContent();
  ok('«Noviembre 2026» vuelve a controlar con 2026-11, el contexto dice «Del 1 al 30 de noviembre de 2026» y la fila 4000 trae −$2,000.00, −10.0 % y la flecha desfavorable', !!ctrlN && ctrlN.args.p_periodo === '2026-11' && /Del 1 al 30 de noviembre de 2026/.test(await texto(p, '#ct-est-ctx')) && /−\$2,000\.00/.test(t4000) && /−10\.0 %/.test(t4000) && (await f4000.locator('.ct-var.desfav .ct-var-ico').count()) === 1, t4000);
  ok('El sentido depende de la sección: 5100 (costo que sube) desfavorable, 6130 (gasto que baja) favorable', (await p.locator('#ct-est-resultados tr.ct-fila-cuenta', { hasText: '5100' }).locator('.ct-var.desfav').count()) === 1 && (await p.locator('#ct-est-resultados tr.ct-fila-cuenta', { hasText: '6130' }).locator('.ct-var.fav').count()) === 1);
  ok('Ningún negativo sale con guion ASCII ni paréntesis: todos con el «−» tipográfico', !/-\$|\(\$/.test(await texto(p, '#ct-est-resultados tbody')) && /−\$/.test(await texto(p, '#ct-est-resultados tbody')));
  // balance
  await p.locator('[data-periodo="2026-10"]').click(); await p.waitForSelector('#ct-est-resultados .ct-kpi', { timeout: 8000 });
  n = llamadas.length;
  await p.locator('[data-sub="balance"]').click(); await p.waitForSelector('#ct-est-balance .ct-kpi', { timeout: 8000 });
  const ctrlB = desde(n).find(l => l.fn === 'fn_estados_control');
  ok('Balance: control con [v_balance_general], el chip «Hoy» existe solo aquí y la franja dice «Cuadra · activo $44,000.00 − pasivo $24,000.00 − capital $20,000.00 = $0.00»', !!ctrlB && JSON.stringify(ctrlB.args.p_vistas) === '["v_balance_general"]' && (await p.locator('[data-periodo="hoy"]').count()) === 1 && /Cuadra · activo \$44,000\.00 − pasivo \$24,000\.00 − capital \$20,000\.00 = \$0\.00/.test(await texto(p, '#ct-est-balance .ct-cuadre')), await texto(p, '#ct-est-balance .ct-cuadre'));
  const tbB = await texto(p, '#ct-est-balance tbody');
  ok('Balance: KPI Efectivo $27,000.00, la fila «cuadra» no se repite como renglón, «Pasivo más capital» es la fila cobre, el componente del resultado trae su etiqueta larga, «Total activo» va antes de «Pasivo circulante» y el contexto dice «Al 31 de octubre de 2026 · 8 asientos al corte»', /Efectivo\$27,000\.00/.test(await texto(p, '#ct-est-balance .ct-kpi')) && !/debe ser 0/.test(tbB) && /Pasivo más capital/.test(await texto(p, '#ct-est-balance tr.ct-neto')) && /Resultado del ejercicio 2026 desde el 01-10-2026 \(el libro\)/.test(tbB) && tbB.indexOf('Total activo') < tbB.indexOf('Pasivo circulante') && /Al 31 de octubre de 2026 · 8 asientos al corte/.test(await texto(p, '#ct-est-ctx')), await texto(p, '#ct-est-ctx'));
  ok('Sin ajustes del CPA no hay columna «Con ajustes» y la nota lo dice', (await p.locator('#ct-est-balance th', { hasText: 'Con ajustes' }).count()) === 0 && /Sin ajustes posteriores del CPA/.test(await texto(p, '#ct-est-balance .ct-nota')));
  n = llamadas.length;
  await p.locator('[data-periodo="hoy"]').click(); await p.waitForSelector('#ct-est-balance .ct-kpi', { timeout: 8000 });
  const ctrlH = desde(n).find(l => l.fn === 'fn_estados_control');
  ok('«Hoy» en el balance controla con p_periodo hoy y el contexto dice «Al día de hoy … lo que va del mes»', !!ctrlH && ctrlH.args.p_periodo === 'hoy' && /Al día de hoy, .* · lo que va del mes/.test(await texto(p, '#ct-est-ctx')), await texto(p, '#ct-est-ctx'));
  n = llamadas.length;
  await p.locator('[data-sub="resultados"]').click(); await p.waitForSelector('#ct-est-resultados .ct-kpi', { timeout: 8000 });
  ok('Al pasar a Resultados con «hoy» elegido, el período cae al mes por la regla, el contexto avisa «“Hoy” solo vale para el balance» y nadie pidió v_resultados con hoy', (await estEst()).periodo === mesRegla && /«Hoy» solo vale para el balance/.test(await texto(p, '#ct-est-ctx')) && !desde(n).some(l => l.fn === 'fn_estados_control' && l.args.p_periodo === 'hoy'), await texto(p, '#ct-est-ctx'));
  // la falla ruidosa de los estados
  await p.locator('[data-periodo="2026-10"]').click(); await p.waitForSelector('#ct-est-resultados .ct-kpi', { timeout: 8000 });
  estado.estadosDescuadre = true;
  await p.locator('[data-sub="balance"]').click(); await p.waitForSelector('#ct-est-cuerpo .ct-rojo', { timeout: 8000 });
  ok('Balance descuadrado (la fila cuadra en false, $100.00): rojo «El balance no cuadra», sin KPI ni fila cobre, y los chips siguen arriba', /El balance no cuadra/.test(await texto(p, '.ct-rojo h2')) && /\$100\.00/.test(await texto(p, '.ct-rojo')) && (await p.locator('.ct-kpi').count()) === 0 && (await p.locator('tr.ct-neto').count()) === 0 && (await p.locator('#ct-est-barra [data-periodo]').count()) > 0, await texto(p, '.ct-rojo h2'));
  await foto(p, '12-estados-descuadre');
  estado.estadosDescuadre = false; estado.estadosMal = true;
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('#ct-est-cuerpo .ct-rojo', { timeout: 8000 });
  ok('Control en rojo: «El control de los estados no cuadra», «pintar ceros sería mentir», el detalle literal de la base en la tabla y ningún KPI', /El control de los estados no cuadra/.test(await texto(p, '.ct-rojo h2')) && /pintar ceros sería mentir/.test(await texto(p, '.ct-rojo')) && /devolvió 3 filas y el libro dice 4/.test(await texto(p, '.ct-rojo .ct-tabla')) && /Vista.*Trajo.*Debía.*Detalle/.test(await texto(p, '.ct-rojo thead')) && (await p.locator('.ct-kpi').count()) === 0, await texto(p, '.ct-rojo'));
  estado.estadosMal = false; estado.estadosFilas = 99; estado.estadosFilasVista = 'v_balance_general';
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('#ct-est-cuerpo .ct-rojo', { timeout: 8000 });
  ok(`Si la pantalla trae ${nBal} filas y el control contó 99, también es rojo`, new RegExp(`trajo ${nBal} fila\\(s\\) y el control contó 99`).test(await texto(p, '.ct-rojo')), await texto(p, '.ct-rojo .ct-tabla'));
  estado.estadosFilas = null; estado.estadosFilasVista = null; estado.estadosSinApertura = true;
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('#ct-est-cuerpo .ct-rojo', { timeout: 8000 });
  ok('El cuadre 63 en false pinta el rojo «Falta la apertura en el libro» con el detalle «fn_apertura no ha posteado»', /Falta la apertura en el libro/.test(await texto(p, '.ct-rojo h2')) && /fn_apertura no ha posteado/.test(await texto(p, '.ct-rojo')), await texto(p, '.ct-rojo h2'));
  estado.estadosSinApertura = false; estado.estadosSigue = 1; n = llamadas.length;
  await p.locator('[data-sub="resultados"]').click(); await p.waitForSelector('#ct-est-resultados .ct-kpi', { timeout: 8000 });
  const sig = desde(n).filter(l => l.fn === 'fn_estados_control').map(l => JSON.stringify(l.args.p_vistas));
  ok('Con ok = null «Sigue» el control se pide dos veces: las dos vistas y luego solo la que faltó; y Resultados pinta sus 4 KPI', sig.length === 2 && sig[0] === '["v_resultados","v_balance_general"]' && sig[1] === '["v_balance_general"]' && (await p.locator('#ct-est-resultados .ct-kpi').count()) === 4, sig.join(' '));
  estado.estadosSigue = 99; n = llamadas.length;
  await p.locator('[data-sub="resultados"]').click(); await p.waitForSelector('#ct-est-cuerpo .ct-rojo', { timeout: 8000 });
  ok('Con un «Sigue» que nunca termina: exactamente 6 llamadas y rojo «no alcanzó a revisar esta vista en 6 llamadas»', desde(n).filter(l => l.fn === 'fn_estados_control').length === 6 && /no alcanzó a revisar esta vista en 6 llamadas/.test(await texto(p, '.ct-rojo')), desde(n).length);
  estado.estadosSigue = 0; estado.estadosNoDueno = true; n = llamadas.length;
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('.ct-rojo', { timeout: 8000 }); await p.waitForTimeout(300);
  const cnd = desde(n).find(l => l.fn === 'fn_estados_control');
  ok('No dueño: v_cortes trae [], se pregunta fn_estados_control(hoy, [v_cortes]), la base dice 42501 y el rojo es «Contabilidad es solo del dueño», sin vacíos ni cifras', !!cnd && cnd.args.p_periodo === 'hoy' && JSON.stringify(cnd.args.p_vistas) === '["v_cortes"]' && /Contabilidad es solo del dueño/.test(await texto(p, '.ct-rojo h2')) && /Los estados los ve solo Edgar/.test(await texto(p, '.ct-rojo')) && (await p.locator('.ct-vacio').count()) === 0 && (await p.locator('.ct-kpi').count()) === 0, await texto(p, '.ct-rojo'));
  estado.estadosNoDueno = false;
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('#ct-est-resultados .ct-kpi', { timeout: 8000 });
  // balanza → mayor → asiento → papel
  n = llamadas.length;
  await p.locator('[data-sub="balanza"]').click(); await p.waitForSelector('#ct-est-balanza .ct-cuenta-btn', { timeout: 8000 });
  const ctrlZ = desde(n).find(l => l.fn === 'fn_estados_control'), f2010 = await p.locator('#ct-est-balanza tr.ct-fila-cuenta', { hasText: '2010' }).textContent();
  ok('Balanza: control con [v_balanza], 12 cuentas con botón, ninguno en la fila «Totales» (cobre), franja «Cuadra · debe $44,500.00 = haber $44,500.00 · saldo final $0.00» y «· 8 asientos del período»', !!ctrlZ && JSON.stringify(ctrlZ.args.p_vistas) === '["v_balanza"]' && (await p.locator('#ct-est-balanza .ct-cuenta-btn').count()) === 12 && (await p.locator('#ct-est-balanza tr.ct-componente button, #ct-est-balanza tr.ct-neto button').count()) === 0 && /Totales/.test(await texto(p, '#ct-est-balanza tr.ct-neto')) && /Cuadra · debe \$44,500\.00 = haber \$44,500\.00 · saldo final \$0\.00/.test(await texto(p, '#ct-est-balanza .ct-cuadre')) && /· 8 asientos del período/.test(await texto(p, '#ct-est-ctx')), await texto(p, '#ct-est-balanza .ct-cuadre'));
  ok('La fila 2010 muestra el saldo final −$15,000.00 y, en su lado, $15,000.00', /−\$15,000\.00/.test(f2010) && /(^|[^−])\$15,000\.00/.test(f2010), f2010);
  await foto(p, '13-estados-balanza');
  n = llamadas.length; nLect = lecturas.length;
  await p.locator('#ct-est-balanza .ct-cuenta-btn[data-cuenta="1010"]').click(); await p.waitForSelector('#ct-est-mayor .ct-asiento-btn', { timeout: 8000 });
  const ctrlM = desde(n).find(l => l.fn === 'fn_estados_control');
  ok('Tocar 1010 abre su mayor: título «Mayor · 1010 Chase Checking», v_mayor por cuenta y período con su orden, v_balanza de la cuenta, control con [v_mayor] y est.cuenta = 1010', (await titulo()) === 'Mayor · 1010 Chase Checking' && lecturas.slice(nLect).some(l => /^v_mayor\?.*cuenta=eq\.1010.*periodo=eq\.2026-10.*order=fecha\.asc,cadena_pos\.asc,orden\.asc/.test(l)) && lecturas.slice(nLect).some(l => /^v_balanza\?.*periodo=eq\.2026-10.*cuenta=eq\.1010/.test(l)) && !!ctrlM && JSON.stringify(ctrlM.args.p_vistas) === '["v_mayor"]' && (await estEst()).cuenta === '1010', await titulo());
  const tbM = await texto(p, '#ct-est-mayor tbody');
  ok('El mayor pinta «Saldo que trae» $25,000.00, 3 asientos con el saldo corrido 23,800 → 28,800 → 26,500 y la fila cobre «Saldo al 31 oct» $26,500.00, sin aviso', /Saldo que trae/.test(await texto(p, '#ct-est-mayor tr.ct-trae')) && /\$25,000\.00/.test(await texto(p, '#ct-est-mayor tr.ct-trae')) && (await p.locator('#ct-est-mayor .ct-asiento-btn').count()) === 3 && /23,800\.00.*28,800\.00.*26,500\.00/.test(tbM) && /Saldo al 31 oct\$26,500\.00/.test(await texto(p, '#ct-est-mayor tr.ct-neto')) && (await p.locator('.ct-aviso.warn').count()) === 0, tbM.slice(0, 160));
  await foto(p, '14-estados-mayor');
  estado.estadosMayorRoto = true;
  await p.evaluate(() => window.MXP_CONTA.ir('estados', { cuenta: '1010' })); await p.waitForSelector('#ct-est-cuerpo .ct-rojo', { timeout: 8000 });
  ok('Si la última línea del mayor no termina donde dice la balanza (y no hay ajuste del CPA): rojo «El mayor no termina donde dice la balanza» con $26,000.00 y $26,500.00', /El mayor no termina donde dice la balanza/.test(await texto(p, '.ct-rojo h2')) && /\$26,000\.00/.test(await texto(p, '.ct-rojo')) && /\$26,500\.00/.test(await texto(p, '.ct-rojo')), await texto(p, '.ct-rojo .ct-tabla'));
  estado.estadosMayorRoto = false;
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('#ct-est-mayor .ct-asiento-btn', { timeout: 8000 });
  n = llamadas.length;
  await p.locator(`.ct-asiento-btn[data-asiento="${ASI.a}"]`).click(); await p.waitForSelector('#ct-est-asiento', { timeout: 8000 });
  const ctrlA = desde(n).find(l => l.fn === 'fn_estados_control');
  ok('Tocar el asiento abre «Asiento 2026-000401»: 2 líneas (2010 por $1,200.00), control con [v_libro, v_asiento_papel], sin fila «Suma» y la nota del candado de c2', (await titulo()) === 'Asiento 2026-000401' && (await p.locator('#ct-est-asiento tbody tr').count()) === 2 && /2010/.test(await texto(p, '#ct-est-asiento tbody')) && /\$1,200\.00/.test(await texto(p, '#ct-est-asiento tbody')) && !!ctrlA && JSON.stringify(ctrlA.args.p_vistas) === '["v_libro","v_asiento_papel"]' && (await p.locator('#ct-est-asiento tr.ct-neto').count()) === 0 && !/Suma/.test(await texto(p, '#ct-est-asiento tbody')) && /debe = haber \(candado de c2\)/.test(await texto(p, '#ct-est-asiento .ct-nota')), await titulo());
  ok('Papel roto: la tarjeta noche dice «El papel de este asiento ya no está: rastro roto» en rojo, sin botón de foto ni llamada a Storage', /El papel de este asiento ya no está: rastro roto/.test(await texto(p, '#ct-est-papel.ct-noche .ct-aviso.bad')) && (await p.locator('#ct-est-papel-foto').count()) === 0 && !desde(n).some(l => l.fn === 'storage:firmar'));
  await foto(p, '14-estados-asiento-roto');
  await p.locator('#btn-volver').click(); await p.waitForSelector('#ct-est-mayor .ct-asiento-btn', { timeout: 8000 });
  ok('«←» en el asiento vuelve al mayor (sigue en la contabilidad, est.asiento vacío) y hooks.volver sigue en true (el mayor también se cierra)', await p.locator('#vista-conta').isVisible() && /^Mayor · 1010/.test(await titulo()) && (await estEst()).asiento === null && (await p.evaluate(() => window.__vol.slice(-1)[0])) === true, await titulo());
  await p.locator('#btn-volver').click(); await p.waitForSelector('#ct-est-balanza .ct-cuenta-btn', { timeout: 8000 });
  ok('«←» otra vez vuelve a la balanza con sus 12 cuentas y el período 2026-10, y hooks.volver(false)', (await p.locator('#ct-est-balanza .ct-cuenta-btn').count()) === 12 && (await estEst()).periodo === '2026-10' && (await estEst()).cuenta === null && (await p.evaluate(() => window.__vol.slice(-1)[0])) === false);
  ok('En la raíz de la balanza ya no hay «←» (hooks.volver(false))', await p.locator('#btn-volver').isHidden());
  await p.locator('#lateral [data-lat="hoy"]').evaluate(b => b.click()); await p.waitForTimeout(400);
  ok('Se sale de la contabilidad por el menú (Hoy)', await p.locator('#vista-conta').isHidden());
  await p.locator('#btn-conta').evaluate(b => b.click()); await p.waitForSelector('#ct-main', { state: 'attached', timeout: 8000 }); await espiar(p);
  n = llamadas.length;
  await p.evaluate(() => window.MXP_CONTA.ir('estados', { cuenta: '5100' })); await p.waitForSelector('#ct-est-mayor .ct-asiento-btn', { timeout: 8000 });
  await p.locator(`.ct-asiento-btn[data-asiento="${ASI.d}"]`).click(); await p.waitForSelector('#ct-est-papel', { timeout: 8000 });
  const firma = desde(n).find(l => l.fn === 'storage:firmar');
  ok('El recibo 8812: firma la foto en Storage con su ruta, el botón «Ver la foto del recibo» lleva la URL firmada y abre aparte, la noche dice el papel y «Camino: puente», y el asiento lleva la pastilla «puente»', !!firma && JSON.stringify(firma.args.paths) === '["recibos/casa-perez/1712.jpg"]' && /token=prueba/.test(await p.locator('#ct-est-papel-foto').getAttribute('href')) && (await p.locator('#ct-est-papel-foto').getAttribute('target')) === '_blank' && /Recibo 8812 · Ferretería Ejemplo · #4471/.test(await texto(p, '.ct-noche-txt')) && /Camino: puente/.test(await texto(p, '.ct-noche-meta')) && /puente/.test(await texto(p, '#ct-est-asiento .ct-cab .ct-pill')), await texto(p, '#ct-est-papel'));
  ok('La obra de la línea sale con su nombre (Casa Pérez) y la pastilla «Controlado»', /Casa Pérez/.test(await texto(p, '#ct-est-asiento tbody')) && /Controlado/.test(await texto(p, '#ct-est-asiento .ct-cab')));
  // Storage no contesta (CORS, un filtro, una caída) con la REST viva: el asiento y su papel se pintan igual, con el aviso; nunca «Sin señal»
  estado.estadosFotoRota = true; n = llamadas.length;
  await p.evaluate(a => window.MXP_CONTA.ir('estados', { cuenta: '5100', asiento: a }), ASI.d); await p.waitForSelector('#ct-est-papel .ct-aviso.warn', { timeout: 8000 });
  ok('Si Storage no contesta al firmar la foto, el asiento se pinta entero con el aviso «La foto no se pudo abrir ahora (sin señal hacia Storage)» y su ruta, sin botón de foto, sin «Sin señal» ni rojo', /La foto no se pudo abrir ahora \(sin señal hacia Storage\)\. Ruta: recibos\/casa-perez\/1712\.jpg/.test(await texto(p, '#ct-est-papel .ct-aviso.warn')) && (await p.locator('#ct-est-asiento tbody tr').count()) === 2 && (await p.locator('#ct-est-papel-foto').count()) === 0 && (await p.locator('.ct-rojo').count()) === 0 && desde(n).some(l => l.fn === 'storage:firmar'), await texto(p, '#ct-est-papel'));
  estado.estadosFotoRota = false;
  await p.locator('#ct-est-asiento .ct-cuenta-btn[data-cuenta="2100-2013"]').click(); await p.waitForSelector('#ct-est-mayor .ct-asiento-btn', { timeout: 8000 });
  ok('Dentro del asiento, tocar la cuenta 2100-2013 abre su mayor (3 asientos, saldo al 31 oct $9,000.00 en su lado) y deja est.asiento vacío', /^Mayor · 2100-2013 Amex Business Gold/.test(await titulo()) && (await estEst()).asiento === null && (await p.locator('#ct-est-mayor .ct-asiento-btn').count()) === 3 && /Saldo al 31 oct\$9,000\.00/.test(await texto(p, '#ct-est-mayor tr.ct-neto')), await titulo());
  const traeAmex = await texto(p, '#ct-est-mayor tr.ct-trae'), tbAmex = await texto(p, '#ct-est-mayor tbody');
  ok('En una cuenta de haber el saldo que trae también va en su lado: «Saldo que trae» $9,000.00 (no −$9,000.00, que es como lo guarda v_balanza) y la columna corre 9,300 → 7,000 → 9,000', /\$9,000\.00/.test(traeAmex) && !/−\$9,000\.00/.test(traeAmex) && /9,300\.00.*7,000\.00.*9,000\.00/.test(tbAmex) && /Saldo que trae\$9,000\.00en su lado/.test(await texto(p, '#ct-est-mayor .ct-kpi')), traeAmex);
  await p.evaluate(() => window.MXP_CONTA.ir('estados', { cuenta: '1050' })); await p.waitForSelector('#ct-est-mayor .ct-vacio', { timeout: 8000 });
  ok('Una cuenta sin movimientos (1050) dice «no tiene movimientos en octubre 2026. Saldo que trae: $500.00», sin ceros', /La cuenta 1050 no tiene movimientos en octubre 2026\. Saldo que trae: \$500\.00\./.test(await texto(p, '#ct-est-mayor .ct-vacio')) && !/\$0\.00/.test(await texto(p, '#ct-est-mayor')) && /Dato: v_mayor/.test(await texto(p, '#ct-est-mayor .ct-nota')), await texto(p, '#ct-est-mayor .ct-vacio'));
  // flujo de caja
  n = llamadas.length; nLect = lecturas.length;
  await p.locator('[data-sub="flujo"]').click(); await p.waitForSelector('#ct-est-flujo .ct-kpi', { timeout: 8000 });
  const ctrlF = desde(n).find(l => l.fn === 'fn_estados_control');
  ok(`Flujo: lectura entera con su orden, control con [v_flujo_caja] (${T.v_flujo_caja.length} filas cotejadas), arranca en «Directo», 3 KPI, franja «Cuadra · cambio en el efectivo +$1,500.00 = …» y «· 3 asientos con dinero»`, lecturas.slice(nLect).some(l => /^v_flujo_caja\?.*periodo=eq\.2026-10.*order=metodo\.asc,seccion_orden\.asc,linea_orden\.asc/.test(l)) && !!ctrlF && JSON.stringify(ctrlF.args.p_vistas) === '["v_flujo_caja"]' && (await p.locator('[data-metodo="directo"][aria-pressed="true"]').count()) === 1 && (await p.locator('#ct-est-flujo .ct-kpi').count()) === 3 && /Cuadra · cambio en el efectivo \+\$1,500\.00 = efectivo al final \$27,000\.00 − al inicio \$25,500\.00 · igual por los dos métodos/.test(await texto(p, '#ct-est-flujo .ct-cuadre')) && /· 3 asientos con dinero/.test(await texto(p, '#ct-est-ctx')), await texto(p, '#ct-est-flujo .ct-cuadre'));
  const tbF = await texto(p, '#ct-est-flujo tbody');
  ok('Flujo directo: +$5,000.00 y −$1,200.00 en la tabla, un 0.00 atenuado, la sección sin dinero sin subtotal, «Ajustes» una sola vez, «Efectivo al final» en cobre, ninguna fila «cuadra» y el KPI dice «con lo que trajo la apertura»', /\+\$5,000\.00/.test(tbF) && /−\$1,200\.00/.test(tbF) && (await p.locator('#ct-est-flujo td.ct-cero').count()) >= 1 && /Actividades sin dinero \(se revelan; no suman\)/.test(tbF) && !/Total actividades sin dinero/.test(tbF) && (tbF.match(/Ajustes/g) || []).length === 1 && /Efectivo al final/.test(await texto(p, '#ct-est-flujo tr.ct-neto')) && !/cuadra|debe ser 0/i.test(tbF) && /con lo que trajo la apertura/.test(await texto(p, '#ct-est-flujo .ct-kpi .ct-sub')), tbF.slice(0, 200));
  n = llamadas.length; nLect = lecturas.length;
  await p.locator('[data-metodo="indirecto"]').click(); await p.waitForTimeout(200);
  ok('Cambiar a «Indirecto» pinta «Utilidad neta del ejercicio» $8,000.00 desde memoria: ni control ni lectura nuevos', /Utilidad neta del ejercicio/.test(await texto(p, '#ct-est-flujo tbody')) && /\$8,000\.00/.test(await texto(p, '#ct-est-flujo tbody')) && desde(n).length === 0 && lecturas.length === nLect && (await p.locator('[data-metodo="indirecto"][aria-pressed="true"]').count()) === 1);
  await foto(p, '15-estados-flujo');
  // contra QuickBooks
  n = llamadas.length;
  await p.locator('[data-sub="comparacion"]').click(); await p.waitForSelector('#ct-est-comparacion .ct-kpi', { timeout: 8000 });
  const ctrlQ = desde(n).find(l => l.fn === 'fn_estados_control'), kpiQ = await texto(p, '#ct-est-comparacion .ct-kpi');
  ok('Contra QuickBooks: control con [v_comparacion, v_comparacion_resumen], franja volt «2 cuentas con diferencia · $150.40 sin explicar · 1 sin mapeo» (lo sin mapeo no se cuenta dos veces) y KPIs «10 de 12», $8,000.00 y $7,900.00', !!ctrlQ && JSON.stringify(ctrlQ.args.p_vistas) === '["v_comparacion","v_comparacion_resumen"]' && /2 cuentas con diferencia · \$150\.40 sin explicar · 1 sin mapeo/.test(await texto(p, '#ct-est-comparacion .ct-cuadre.volt')) && /10 de 12/.test(kpiQ) && /\$8,000\.00/.test(kpiQ) && /\$7,900\.00/.test(kpiQ), await texto(p, '#ct-est-comparacion .ct-cuadre'));
  const filaQ = c => p.locator('#ct-est-comparacion tbody tr', { hasText: c });
  ok('Cada cuenta lleva su pastilla con icono y texto: Igual (1050), Explicada (1010, «explicada: puente»), Centavos (5100), Por explicar (4000, fila cobre) y Sin mapeo (QB Misterio, rojo)', /Igual/.test(await filaQ('1050').locator('.ct-pill.ok').textContent()) && /Explicada/.test(await filaQ('1010').locator('.ct-pill.ok').textContent()) && /explicada: puente/.test(await filaQ('1010').textContent()) && /Centavos/.test(await filaQ('5100').locator('.ct-pill.warn').textContent()) && /Por explicar/.test(await filaQ('4000').locator('.ct-pill.cu').textContent()) && (await filaQ('4000').evaluate(e => e.classList.contains('ct-porexplicar'))) && /Sin mapeo/.test(await filaQ('QB Misterio').locator('.ct-pill.bad').textContent()) && (await filaQ('QB Misterio').evaluate(e => e.classList.contains('ct-sinmapeo'))) && (await p.locator('#ct-est-comparacion .ct-pill .ct-ico').count()) >= 13);
  ok('Libro y QuickBooks salen «como QuickBooks» (4000 en −$20,000.00), la nota lo dice, y el documento es texto, sin enlace', /−\$20,000\.00/.test(await filaQ('4000').textContent()) && /como QuickBooks/.test(await texto(p, '#ct-est-comparacion .ct-nota')) && /docs\/qb\/balanza-2026-10-31\.csv/.test(await texto(p, '#ct-est-comparacion .ct-nota')) && (await p.locator('a[href*="docs/qb"]').count()) === 0);
  await foto(p, '16-estados-quickbooks');
  // los vacíos legítimos (control 0 = vista 0)
  await p.locator('[data-periodo="2026"]').click(); await esperarTexto('#ct-est-comparacion', /Todavía no hay balanza/);
  ok('Sin balanza de QuickBooks para «Año 2026» (0 = 0): el vacío lo dice, con «Dato: comparacion_qb → v_comparacion», sin rojo ni $0.00', /Todavía no hay balanza de QuickBooks para año 2026/.test(await texto(p, '#ct-est-comparacion .ct-vacio')) && /Dato: comparacion_qb → v_comparacion/.test(await texto(p, '#ct-est-comparacion .ct-nota')) && (await p.locator('.ct-rojo').count()) === 0 && !/\$0\.00/.test(await texto(p, '#ct-est-comparacion')), await texto(p, '#ct-est-comparacion .ct-vacio'));
  await elegir('2027'); await esperarTexto('#ct-est-comparacion', /marcha en paralelo/);
  ok('Con «Año 2027» (paralelo terminado) el vacío dice «La marcha en paralelo con QuickBooks terminó el 31 dic 2026» (la fecha sale de v_cortes), sin rojo', /La marcha en paralelo con QuickBooks terminó el 31 dic 2026: la comparación queda para los períodos hasta esa fecha\./.test(await texto(p, '#ct-est-comparacion .ct-vacio')) && (await p.locator('.ct-rojo').count()) === 0, await texto(p, '#ct-est-comparacion .ct-vacio'));
  const perWrap = await p.evaluate(() => { const e = document.querySelector('#ct-est-periodos'); return [e.scrollWidth, e.clientWidth, e.querySelectorAll('.ct-chip').length, (document.querySelector('#ct-est-mas') || {}).textContent]; });
  ok('En la computadora, con todos los períodos a la vista, los chips envuelven: nada queda fuera del borde ni hace falta deslizar', perWrap[0] <= perWrap[1] && perWrap[2] >= 7 && /Menos períodos/.test(perWrap[3] || ''), JSON.stringify(perWrap));
  // un ajuste del CPA de otro ejercicio: v_balanza del año no trae la cuenta, el mayor avisa y no da por bueno el saldo corrido
  await p.evaluate(() => window.MXP_CONTA.ir('estados', { cuenta: '6300' })); await p.waitForSelector('#ct-est-mayor .ct-aviso.warn', { timeout: 8000 });
  const kpiAj = await texto(p, '#ct-est-mayor .ct-kpi');
  ok('Mayor de 6300 en «Año 2027» (solo un ajuste del CPA de 2026, sin fila en v_balanza): aviso «no trae la cuenta … corren con el saldo de su año», «—» en «Saldo al» (fila y KPI), KPI Asientos 1 (asientos, no líneas) y sin rojo', /La balanza de año 2027 no trae la cuenta 6300: sus líneas son ajustes del CPA de otro ejercicio y corren con el saldo de su año/.test(await texto(p, '#ct-est-mayor .ct-aviso.warn')) && /Saldo al 31 dic—/.test(await texto(p, '#ct-est-mayor tr.ct-neto')) && /Saldo al 31 dic—sin fila en la balanza/.test(kpiAj) && /Asientos1/.test(kpiAj) && /Ajuste del CPA/.test(await texto(p, '#ct-est-mayor tbody')) && (await p.locator('.ct-rojo').count()) === 0, kpiAj);
  await p.locator('[data-periodo="2026"]').click(); await esperarTexto('#ct-est-comparacion', /Todavía no hay balanza/);
  await p.locator('[data-sub="flujo"]').click(); await p.waitForSelector('#ct-est-flujo .ct-vacio', { timeout: 8000 });
  const vacioF = await texto(p, '#ct-est-flujo .ct-vacio');
  await p.locator('[data-sub="balanza"]').click(); await p.waitForSelector('#ct-est-balanza .ct-vacio', { timeout: 8000 });
  ok('Flujo y balanza del año sin movimientos (0 = 0): «Sin movimientos de dinero en año 2026…» y «Ningún asiento en año 2026.», cada uno con su dato', /Sin movimientos de dinero en año 2026: ni entró ni salió efectivo\./.test(vacioF) && /Ningún asiento en año 2026\./.test(await texto(p, '#ct-est-balanza .ct-vacio')) && /Dato: v_balanza/.test(await texto(p, '#ct-est-balanza .ct-nota')) && (await p.locator('.ct-rojo').count()) === 0, vacioF);
  n = llamadas.length;
  await p.locator('[data-sub="resultados"]').click(); await p.waitForSelector('#ct-est-resultados', { timeout: 8000 });
  await p.locator('[data-periodo="2026-09-APERTURA"]').click(); await esperarTexto('#ct-est-resultados', /La apertura no tiene/);
  ok('Resultados en la apertura: se controla y se lee con 2026-09-APERTURA (0 = 0), el vacío dice «La apertura no tiene estado de resultados», el contexto «Al 30 de septiembre de 2026» con «Cerrado», sin rojo', desde(n).some(l => l.fn === 'fn_estados_control' && l.args.p_periodo === '2026-09-APERTURA') && lecturas.some(l => /^v_resultados\?.*periodo=eq\.2026-09-APERTURA/.test(l)) && /La apertura no tiene estado de resultados/.test(await texto(p, '#ct-est-resultados .ct-vacio')) && /Al 30 de septiembre de 2026/.test(await texto(p, '#ct-est-ctx')) && /Cerrado/.test(await texto(p, '#ct-est-ctx .ct-pill')) && (await p.locator('.ct-rojo').count()) === 0, await texto(p, '#ct-est-ctx'));
  // una vista que no existe en la base
  estado.estadosVistaRota = true;
  await p.locator('[data-periodo="2026-10"]').click(); await p.waitForSelector('#ct-est-resultados .ct-kpi', { timeout: 8000 });
  await p.locator('[data-sub="balanza"]').click(); await p.waitForSelector('#ct-est-cuerpo .ct-rojo', { timeout: 8000 });
  ok('Vista rota (v_balanza 404 42P01): rojo «La base no contestó bien» con «le falta el último SQL», sin vacío', /La base no contestó bien/.test(await texto(p, '.ct-rojo h2')) && /le falta el último SQL/.test(await texto(p, '.ct-rojo')) && (await p.locator('.ct-vacio').count()) === 0, await texto(p, '.ct-rojo'));
  estado.estadosVistaRota = false;
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('#ct-est-balanza .ct-cuenta-btn', { timeout: 8000 });
  ok('Al arreglarse y «Reintentar», vuelve a pintar la balanza con sus 12 cuentas', (await p.locator('#ct-est-balanza .ct-cuenta-btn').count()) === 12);
  // la carrera de dos clics
  await p.locator('[data-sub="resultados"]').click(); await p.waitForSelector('#ct-est-resultados .ct-kpi', { timeout: 8000 });
  if (!(await p.locator('[data-periodo="2026-11"]').count())) { await p.locator('#ct-est-mas').click(); await p.waitForSelector('[data-periodo="2026-11"]', { timeout: 8000 }); }
  await p.locator('[data-periodo="2026-10"]').evaluate(b => b.click()); await p.locator('[data-periodo="2026-11"]').evaluate(b => b.click());
  await p.waitForSelector('#ct-est-resultados .ct-kpi', { timeout: 8000 }); await p.waitForTimeout(500);
  ok('Dos clics rápidos de período (2026-10 y enseguida 2026-11) dejan en pantalla el último: noviembre, con su chip marcado', /noviembre/.test(await texto(p, '#ct-est-ctx')) && (await p.locator('[data-periodo="2026-11"][aria-pressed="true"]').count()) === 1 && /\$18,000\.00/.test(await texto(p, '#ct-est-resultados tbody')), await texto(p, '#ct-est-ctx'));
  // sin señal en los estados
  await p.locator('[data-periodo="2026-10"]').click(); await p.waitForSelector('#ct-est-resultados .ct-kpi', { timeout: 8000 });
  await ctx.setOffline(true);
  await p.locator('[data-sub="flujo"]').click(); await p.waitForSelector('.ct-rojo', { timeout: 8000 });
  ok('Sin señal en Estados: «Sin señal» en rojo y nada de cifras de memoria', /Sin señal/.test(await texto(p, '.ct-rojo h2')) && (await p.locator('.ct-kpi').count()) === 0 && (await p.locator('.ct-est-tabla, .ct-tabla.angosta').count()) === 0);
  await ctx.setOffline(false);
  await p.waitForSelector('#ct-est-flujo .ct-kpi', { timeout: 8000 }).catch(() => {});
  ok('Al volver la señal reintenta sola y pinta la subvista en la que estaba (el flujo)', (await p.locator('#ct-est-flujo .ct-kpi').count()) === 3);
  const sinPeriodo = lecturas.filter(l => /^v_(resultados|balance_general|balanza|flujo_caja|comparacion|comparacion_resumen)\?/.test(l) && !/periodo=eq\./.test(l));
  ok('Ninguna lectura de las vistas de estados fue sin periodo=eq. (sin filtro se calculan para todos los períodos)', sinPeriodo.length === 0, sinPeriodo.join(' | '));
  // el teléfono: 390 px
  {
    const tel = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, serviceWorkers: 'block' });
    await simular(tel, 'dueno');
    const q = await tel.newPage(); q.on('pageerror', e => errs.push('teléfono estados: ' + String(e).slice(0, 160)));
    await q.goto('http://localhost:8873/index.html'); await q.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await q.waitForTimeout(800);
    await q.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
    await q.locator('#btn-conta').evaluate(b => b.click()); await q.waitForSelector('.ct-tab', { timeout: 8000 });
    const tabsTel = await q.evaluate(() => { const t = document.querySelector('.ct-tabs'); return { display: getComputedStyle(t).display, snap: getComputedStyle(t).scrollSnapType, desliza: t.scrollWidth > t.clientWidth, n: t.querySelectorAll('.ct-tab').length }; });
    ok('Teléfono (390 px): las 8 pestañas van arriba, a la vista, deslizan con tope (scroll-snap)', tabsTel.display !== 'none' && tabsTel.n === 8 && tabsTel.desliza && /x/.test(tabsTel.snap), JSON.stringify(tabsTel));
    await tab(q, 'estados'); await q.waitForSelector('#ct-est-resultados', { timeout: 8000 });
    const tabVis = await q.evaluate(() => { const t = document.querySelector('.ct-tabs'), a = t.querySelector('.ct-tab[aria-current="page"]'), T = t.getBoundingClientRect(), A = a.getBoundingClientRect();
      return { pag: a.dataset.pag, izq: Math.round(A.left - T.left), der: Math.round(T.right - A.right), tira: [Math.round(T.left), Math.round(T.right)], iw: window.innerWidth, sw: document.documentElement.scrollWidth }; });
    ok('Teléfono: la pestaña activa («Estados») se ve entera dentro de la tira, fuera de los 14 px del desvanecido de cada borde, y la tira (que se sale al margen) no desplaza la página de lado', tabVis.pag === 'estados' && tabVis.izq >= 14 && tabVis.der >= 14 && tabVis.tira[0] >= 0 && tabVis.tira[1] <= tabVis.iw && tabVis.sw <= tabVis.iw + 1, JSON.stringify(tabVis));
    await q.locator('[data-periodo="2026-10"]').click(); await q.waitForSelector('#ct-est-resultados .ct-kpi', { timeout: 8000 });
    const medidas = await q.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: window.innerWidth, thead: getComputedStyle(document.querySelector('#ct-est-resultados thead')).display,
      chips: (() => { const e = document.querySelector('.ct-est-subs'); return [e.scrollWidth, e.clientWidth]; })(), before: getComputedStyle(document.querySelector('#ct-est-resultados td[data-col="Mes"]'), '::before').content }));
    ok('Teléfono (390 px): la tabla de Resultados se apila (sin cabecera, cada cifra con su etiqueta), la página no desplaza de lado y los chips deslizan', medidas.sw <= medidas.iw + 1 && medidas.thead === 'none' && /Mes/.test(medidas.before) && medidas.chips[0] >= medidas.chips[1], JSON.stringify(medidas));
    await foto(q, '17-tel-estados-resultados');
    await q.locator('[data-sub="balanza"]').click(); await q.waitForSelector('#ct-est-balanza .ct-cuenta-btn', { timeout: 8000 });
    const env = await q.evaluate(() => { const e = document.querySelector('#ct-est-balanza .ct-tabla-env'); return [e.scrollWidth, e.clientWidth, document.documentElement.scrollWidth, window.innerWidth]; });
    ok('Teléfono: la balanza desplaza dentro de su tarjeta (.ct-tabla-env), no la página', env[0] > env[1] && env[2] <= env[3] + 1, JSON.stringify(env));
    const colZ = await q.evaluate(() => { const th = document.querySelectorAll('#ct-est-balanza thead th'), e = document.querySelector('#ct-est-balanza .ct-tabla-env'), w = th[0].getBoundingClientRect().width; return { cuenta: w, cifra: th[1].getBoundingClientRect().width, ventana: e.clientWidth - w }; });
    ok('Teléfono: la columna pegajosa de la cuenta es estrecha (el nombre pasa a dos líneas) y deja ventana para las cifras', colZ.cuenta <= 150 && colZ.ventana >= 200, JSON.stringify(colZ));
    await foto(q, '17-tel-estados-balanza');
    await q.locator('#ct-est-balanza .ct-cuenta-btn[data-cuenta="5100"]').click(); await q.waitForSelector('#ct-est-mayor .ct-asiento-btn', { timeout: 8000 });
    await q.locator(`.ct-asiento-btn[data-asiento="${ASI.d}"]`).click(); await q.waitForSelector('#ct-est-papel-foto', { timeout: 8000 });
    ok('Teléfono: balanza → 5100 → asiento con su papel y el botón de la foto, sin desplazar la página de lado', (await q.locator('#ct-est-papel.ct-noche').count()) === 1 && (await q.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1)));
    const asiTel = await q.evaluate(() => { const d = document.querySelector('#ct-est-asiento td[data-col="Debe"]'); return { debeDer: d.getBoundingClientRect().right, iw: window.innerWidth, antes: getComputedStyle(d, '::before').content, obra: document.querySelector('#ct-est-asiento td.ct-obra').textContent, proyectos: (window.MXP_CONTA._estado.proyectos || []).length }; });
    ok('Teléfono: el asiento se apila (Debe y Haber en pantalla con su etiqueta) y la obra sale con su nombre (Casa Pérez) aunque la Bandeja no haya corrido', asiTel.debeDer <= asiTel.iw && /Debe/.test(asiTel.antes) && asiTel.obra === 'Casa Pérez' && asiTel.proyectos === 3, JSON.stringify(asiTel));
    await foto(q, '18-tel-estados-papel');
    // el mayor en el teléfono, desplazado hasta el final (para mirar la columna pegajosa y las filas «Saldo que trae» / «Saldo al»)
    await q.locator('#btn-volver').click(); await q.waitForSelector('#ct-est-mayor .ct-asiento-btn', { timeout: 8000 });
    await q.evaluate(() => { const e = document.querySelector('#ct-est-mayor .ct-tabla-env'); e.scrollLeft = e.scrollWidth; });
    const mayTel = await q.evaluate(() => { const c = document.querySelector('#ct-est-mayor tr.ct-trae td[data-col="Saldo"]'); c.scrollIntoView({ block: 'center' }); const r = c.getBoundingClientRect(), hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2), d = document.querySelector('#ct-est-mayor tbody tr:not(.ct-trae) td[data-col="Debe"]');
      return { visto: hit === c || c.contains(hit), saldo: c.textContent, columnas: getComputedStyle(d.parentElement).gridTemplateColumns.split(' ').length, debeDer: d.getBoundingClientRect().right, iw: window.innerWidth, sw: document.documentElement.scrollWidth }; });
    ok('Teléfono: el mayor se apila en tres columnas (debe | haber | saldo): la cifra de «Saldo que trae» está a la vista (nada la tapa), Debe cabe en pantalla y la página no desplaza de lado', mayTel.visto && /\$/.test(mayTel.saldo) && mayTel.columnas === 3 && mayTel.debeDer <= mayTel.iw && mayTel.sw <= mayTel.iw + 1, JSON.stringify(mayTel));
    await foto(q, '19-tel-estados-mayor');
    await tel.close();
  }

  // ---- Conexiones y seguridad: el código del teléfono (segundo factor) ----
  n = llamadas.length;
  await tab(p, 'conexiones'); await p.waitForSelector('#ct-mfa', { timeout: 8000 });
  const latCx = await p.evaluate(() => { const l = document.querySelector('#lateral'), sp = l.querySelector('[data-lat="conta-conexiones"] span'), cs = getComputedStyle(l), ps = getComputedStyle(l, '::after');
    return { cortado: sp.scrollWidth > sp.clientWidth + 1, txt: sp.textContent, desborda: l.scrollHeight > l.clientHeight, barra: cs.scrollbarWidth, pista: ps.position, alto: Math.round(l.querySelector('[data-lat="conta-bandeja"]').getBoundingClientRect().height) }; });
  ok('Lateral (1280×900): «Conexiones y seguridad» se lee entero (envuelve, sin «…»), los subtítulos van compactos (38 px) y, como la lista no cabe, el lateral desplaza con barra fina y el desvanecido de abajo como pista', !latCx.cortado && latCx.txt === 'Conexiones y seguridad' && latCx.alto === 38 && (!latCx.desborda || (latCx.barra === 'thin' && latCx.pista === 'sticky')), JSON.stringify(latCx));
  ok('«Conexiones y seguridad» trae las cuatro tarjetas (el código del teléfono, Plaid, Stripe y la IA contable, sin c8 «sin instalar») en ese orden, con su cabecera; pidió el control de v_banco_saldos (las cuentas a las que va cada cuenta de Plaid)',
    (await titulo()) === 'Conexiones y seguridad' && JSON.stringify(await p.locator('#ct-main > section').evaluateAll(ss => ss.map(x => x.id))) === '["ct-mfa","ct-plaid","ct-stripe","ct-ia"]' && /código del teléfono no activo · 1 banco conectado · Stripe conectado · IA contable sin instalar/.test(await texto(p, '.ct-pag-sub')) &&
    /sin instalar/.test(await texto(p, '#ct-ia .ct-cab')) && /docs\/conta\/c8-contador\.sql/.test(await texto(p, '#ct-ia')) &&
    desde(n).some(l => l.fn === 'fn_banco_control' && JSON.stringify(l.args.p_vistas) === '["v_banco_saldos"]') && (await p.locator('.ct-cuenta').count()) === 0, await texto(p, '.ct-pag-sub'));
  ok('La tarjeta del código del teléfono dice «no activo» y «Conectar un banco» (Plaid) sale apagado', /no activo/.test(await texto(p, '#ct-mfa')) && await p.locator('#ct-plaid-conectar').isDisabled() && /Primero activa el código/.test(await texto(p, '#ct-plaid')));
  await p.locator('#ct-mfa-activar').click();
  await p.waitForSelector('#ct-mfa .ct-qr', { timeout: 8000 });
  const enr = desde(n).find(l => l.fn === 'auth:enrolar');
  await p.waitForFunction(() => { const i = document.querySelector('#ct-mfa .ct-qr'); return i && i.complete; }, null, { timeout: 8000 });
  const qrCarga = await p.evaluate(() => { const i = document.querySelector('#ct-mfa .ct-qr'); return i ? { ancho: i.naturalWidth, src: i.getAttribute('src').slice(0, 40) } : null; });
  ok('«Activar el código» pide el factor TOTP a Supabase Auth y enseña el QR (el SVG crudo convertido en imagen que carga) y la clave', !!enr && enr.args.factor_type === 'totp' && enr.args.issuer === 'Max Power Panel' && qrCarga && qrCarga.ancho > 0 && qrCarga.src.startsWith('data:image/svg+xml;charset=utf-8,') && /ABCDEFGHIJKLMNOP/.test(await texto(p, '#ct-mfa .ct-clave')), JSON.stringify({ enr: enr && enr.args, qrCarga }));
  await foto(p, '10-codigo-qr');
  await p.locator('#ct-mfa [name=codigo]').fill('000000');
  await p.locator('#ct-mfa button[type=submit]').click(); await p.waitForTimeout(250);
  ok('Un código equivocado lo dice y no activa nada', /no es válido/.test(await texto(p, '#ct-mfa .ct-form')) && desde(n).some(l => l.fn === 'auth:verificar' && l.args.code === '000000' && l.args.challenge_id === 'ch-1'));
  await p.locator('#ct-mfa [name=codigo]').fill('123456');
  await p.locator('#ct-mfa button[type=submit]').click();
  await p.waitForFunction(() => { const e = document.querySelector('#ct-mfa'); return e && /activo/.test(e.textContent) && !/no activo/.test(e.textContent); }, null, { timeout: 8000 });
  ok('Con el código bueno queda «activo», la sesión guardada pasa a aal2 y «Conectar un banco» se enciende', !(await p.locator('#ct-plaid-conectar').isDisabled()) && (await p.evaluate(() => { try { const s = JSON.parse(localStorage.getItem('mxp_sesion')); return JSON.parse(atob(s.access_token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))).aal; } catch { return null; } })) === 'aal2', await texto(p, '#ct-mfa'));

  // ---- La conexión automática (Plaid) ----
  n = llamadas.length;
  await tab(p, 'conexiones'); await p.waitForSelector('#ct-plaid', { timeout: 8000 });
  ok('La tarjeta de Plaid pinta el banco conectado, «1 sin fijar» y el enlace a la política de privacidad', /Platypus Bank/.test(await texto(p, '#ct-plaid')) && /1 sin fijar/.test(await texto(p, '#ct-plaid')) && (await p.locator('#ct-plaid a[href*="PRIVACY-POLICY"]').count()) === 1);
  const opcionesSel = await p.locator('.ct-conexion select[data-account="acc-corriente"] option').allTextContents();
  ok('La cuenta de banco sin fijar solo ofrece bancos (1010, 1030) e «ignorar»; la tarjeta ya viene fijada a 2100-2013', opcionesSel.some(t => /1010/.test(t)) && opcionesSel.some(t => /1030/.test(t)) && !opcionesSel.some(t => /2100/.test(t)) && opcionesSel.some(t => /Ignorar/.test(t)) && (await p.locator('.ct-conexion select[data-account="acc-tarjeta"]').inputValue()) === '2100-2013', opcionesSel.join(' | '));
  await foto(p, '9-plaid');
  estado.plaidSinFijar = true;
  await p.locator('.ct-conexion [data-plaid="sincronizar"]').click();
  await p.waitForSelector('.ct-conexion-res .ct-aviso.warn', { timeout: 8000 });
  ok('«Sincronizar ahora» con una cuenta sin fijar: la función dice SIN_FIJAR y la pantalla lo enseña en amarillo, con la sesión en la llamada', /Falta decir a qué cuenta/.test(await texto(p, '.ct-conexion-res')) && desde(n).some(l => l.fn === 'plaid:sincronizar' && l.args.item_id === 'item-prueba' && /^Bearer /.test(l.auth)));
  estado.plaidSinFijar = false;
  n = llamadas.length;
  await p.locator('.ct-conexion select[data-account="acc-corriente"]').selectOption('1010');
  await esperarLlamada(p, n, 'plaid:fijar_cuenta');
  await p.waitForFunction(() => { const e = document.querySelector('#ct-plaid'); return e && !/sin fijar/.test(e.textContent); }, null, { timeout: 8000 });
  const fij = desde(n).find(l => l.fn === 'plaid:fijar_cuenta');
  ok('Elegir 1010 se lo pide a la función (fijar_cuenta) con la conexión, la cuenta de Plaid y 1010, con la sesión, y la tarjeta se repinta sin «sin fijar»', !!fij && fij.args.item_id === 'item-prueba' && fij.args.account_id === 'acc-corriente' && fij.args.cuenta === '1010' && /^Bearer /.test(fij.auth) && !/sin fijar/.test(await texto(p, '#ct-plaid')) && !desde(n).some(l => l.fn === 'fn_plaid_cuenta_fijar'), JSON.stringify(fij && fij.args));
  n = llamadas.length;
  await p.locator('.ct-conexion [data-plaid="sincronizar"]').click();
  await p.waitForFunction(() => { const t = document.getElementById('toast'); return t && /Sincronizado/.test(t.textContent); }, null, { timeout: 8000 });
  ok('«Sincronizar ahora» llama a la función y cuenta lo que entró (3 nuevos, 1 posible duplicado)', desde(n).some(l => l.fn === 'plaid:sincronizar') && /3 movimientos nuevos/.test(await texto(p, '#toast')) && /1 posible/.test(await texto(p, '#toast')), await texto(p, '#toast'));
  n = llamadas.length;
  await p.waitForSelector('#ct-plaid-conectar', { timeout: 8000 });
  await p.locator('#ct-plaid-conectar').click();
  await esperarLlamada(p, n, 'plaid:canjear');
  const lt = desde(n).find(l => l.fn === 'plaid:link_token'), cj = desde(n).find(l => l.fn === 'plaid:canjear');
  ok('«Conectar un banco»: pide el link token, abre Plaid Link y canjea el public token con la institución', !!lt && !lt.args.item_id && !!cj && cj.args.public_token === 'public-sandbox-prueba' && cj.args.metadata.institution.name === 'Platypus Bank' && (await p.evaluate(() => window.__plaidAbierto)) === 1, JSON.stringify(cj && cj.args));
  await p.waitForFunction(() => { const t = document.getElementById('toast'); return t && /conectado/.test(t.textContent); }, null, { timeout: 8000 }).catch(() => {});
  ok('Y lo avisa: «Platypus Bank conectado: di a qué cuenta…»', /Platypus Bank conectado/.test(await texto(p, '#toast')), await texto(p, '#toast'));
  n = llamadas.length;
  await p.waitForSelector('.ct-conexion [data-plaid="desconectar"]', { timeout: 8000 });
  await p.locator('.ct-conexion [data-plaid="desconectar"]').click();
  await p.locator('.ct-conexion .ct-form button[type=submit]').click(); await p.waitForTimeout(150);
  ok('«Desconectar» pide el motivo y sin él no manda nada', /Falta/.test(await texto(p, '.ct-conexion .ct-form')) && !desde(n).some(l => l.fn === 'plaid:desconectar'));
  await p.locator('.ct-conexion .ct-form [name=p_motivo]').fill('prueba del arnés');
  await p.locator('.ct-conexion .ct-form button[type=submit]').click();
  await esperarLlamada(p, n, 'plaid:desconectar');
  const dc = desde(n).find(l => l.fn === 'plaid:desconectar');
  ok('Con motivo, llama a la función con la conexión y el motivo', !!dc && dc.args.item_id === 'item-prueba' && dc.args.motivo === 'prueba del arnés', JSON.stringify(dc && dc.args));

  estado.plaidSinVista = true;
  await tab(p, 'conexiones'); await p.waitForSelector('#ct-plaid', { timeout: 8000 });
  ok('Sin c7 en la base (la vista no existe), la tarjeta dice «sin instalar» y las otras dos se pintan igual', /sin instalar/.test(await texto(p, '#ct-plaid')) && /Plaid sin instalar/.test(await texto(p, '.ct-pag-sub')) && (await p.locator('#ct-mfa, #ct-stripe').count()) === 2, await texto(p, '#ct-plaid'));
  await tab(p, 'bancos'); await p.waitForSelector('.ct-cuenta', { timeout: 8000 });
  ok('…y Bancos pinta sus 4 cuentas igual', (await p.locator('.ct-cuenta').count()) === 4);
  estado.plaidSinVista = false; estado.plaidFijada = false;
  // ---- Los cobros en línea (Stripe, p1), con el código del teléfono activo (aal2) ----
  const toast = async re => p.waitForFunction(r => { const t = document.getElementById('toast'); return t && !t.hidden && new RegExp(r).test(t.textContent); }, re.source, { timeout: 8000 });
  const ficha = (cls, attr, v) => p.locator(`.${cls}[data-${attr}="${v}"]`);
  // después de una acción, la pantalla avisa y se repinta: esperar a que termine antes de mirar o tocar otra cosa
  const repintado = () => pintado(p);
  n = llamadas.length; nLect = lecturas.length;
  await tab(p, 'conexiones'); await p.waitForSelector('#ct-stripe', { timeout: 8000 });
  const tStripe = await texto(p, '#ct-stripe');
  ok('Conexiones: la tarjeta «Cobros en línea (Stripe)» dice «conectado» y «cuadra», lo que está en Stripe sin depositar ($4,000.00, 2 cobros), lo que va en camino por cuenta de banco ($4,200.50) y la última revisión; leyó v_stripe_estado y pidió la salud a la función con la sesión',
    /conectado/.test(await texto(p, '#ct-stripe .ct-cab')) && /cuadra/.test(await texto(p, '#ct-stripe .ct-cab')) && !/modo de prueba/.test(tStripe) && /En Stripe, sin depositar: \$4,000\.00 \(2 cobros\)/.test(tStripe) && /En camino por cuenta de banco: \$4,200\.50 \(2\)/.test(tStripe) && /Último aviso de Stripe: 26 oct 2026 .*payment_intent\.succeeded/.test(tStripe) && /Revisión automática: 27 oct 2026/.test(tStripe) &&
    lecturas.slice(nLect).some(l => /^v_stripe_estado\?select=\*/.test(l)) && desde(n).some(l => l.fn === 'stripe:salud' && /^Bearer /.test(l.auth)), tStripe.slice(0, 200));
  const sinMilVeinte = !(await p.locator('.ct-conexion select option').allTextContents()).some(t => /1020/.test(t));
  await foto(p, '20-stripe-conexiones');
  await tab(p, 'bancos'); await p.waitForSelector('.ct-cuenta', { timeout: 8000 });
  const ctrlS = desde(n).find(l => l.fn === 'fn_banco_control');
  ok('La 1020 (Stripe — cobros en tránsito) no se pinta como banco: siguen 4 tarjetas y no sale en el importador ni en las cuentas de Plaid; el control de v_banco_saldos sigue verde con la lista entera (5)',
    (await p.locator('.ct-cuenta').count()) === 4 && (await p.locator('.ct-cuenta[data-cuenta="1020"]').count()) === 0 && !(await p.locator('#ct-imp-cuenta option').allTextContents()).some(t => /1020/.test(t)) &&
    sinMilVeinte && (await p.locator('.ct-rojo').count()) === 0 && !!ctrlS && T.v_banco_saldos.length === 5, await p.locator('.ct-cuenta').count());
  await tab(p, 'conexiones'); await p.waitForSelector('#ct-stripe', { timeout: 8000 });
  // «Probar la llave»: cada recurso con ✓ o ✗ y el permiso que falta
  n = llamadas.length;
  await p.locator('#ct-stripe-probar').click(); await p.waitForSelector('#ct-stripe .ct-permisos', { timeout: 8000 });
  const perm = await texto(p, '#ct-stripe .ct-stripe-res');
  ok('«Probar la llave» llama a la función (probar_llave) y lista cada recurso: ✓ los buenos y ✗ con «Falta el permiso «Balance transaction sources: Read» (rak_…) en la llave restringida» (el nombre del panel y el rak_)',
    desde(n).some(l => l.fn === 'stripe:probar_llave' && /^Bearer /.test(l.auth)) && (await p.locator('#ct-stripe .ct-permisos li.ok').count()) === 8 && (await p.locator('#ct-stripe .ct-permisos li.bad').count()) === 1 && /Falta el permiso «Balance transaction sources: Read» \(rak_balance_transaction_source_read\) en la llave restringida/.test(perm), perm.slice(0, 200));
  // las demás listas de bancos: Conciliar, Movimientos y «Dinero entre cuentas propias» de la bandeja
  await tab(p, 'conciliar'); await p.waitForSelector('#ct-conc-form', { timeout: 8000 });
  const optConc = await p.locator('#ct-conc-form select[name="cuenta"] option').allTextContents();
  await tab(p, 'movimientos'); await p.waitForSelector('#ct-mov-cuenta', { timeout: 8000 });
  const optMov = await p.locator('#ct-mov-cuenta option').allTextContents();
  ok('Conciliar y Movimientos no ofrecen la 1020 (no tiene estado de cuenta: la vigila el control de Stripe)', optConc.length === 4 && !optConc.some(t => /1020/.test(t)) && optMov.length === 4 && !optMov.some(t => /1020/.test(t)), optConc.join(' | '));
  // la bandeja: el depósito STRIPE de Chase
  estado.stripeDeposito = true; n = llamadas.length;
  await tab(p, 'bandeja'); await p.waitForSelector(`.ct-mov[data-id="${MOV.s}"]`, { timeout: 8000 });
  ok('El depósito de Stripe lleva la pastilla «Stripe» en su fila compacta', /Stripe/.test(await texto(p, `.ct-mov[data-id="${MOV.s}"] .ct-f-motivo .ct-pill.cu`)));
  const cardS = await fila(p, MOV.s);
  const opsS = await cardS.locator('[data-op]').allTextContents();
  const tS = await cardS.textContent();
  ok('Bandeja: el depósito STRIPE (la forma REAL de c6: «otro_lado_nombrado» con préstamo, aportación, 1130 y transferencias) no enseña NINGUNA opción de c6, ni «Otra cosa…», ni el texto de c6: el de p1 y el aviso «Depósito de Stripe: casa solo… No lo clasifiques ni lo registres aquí: el dinero entraría dos veces»; el control de la bandeja contó también este movimiento',
    /Depósito de Stripe: casa solo con su depósito en «Cobros en línea».*No lo clasifiques ni lo registres aquí: el dinero entraría dos veces\./.test(await texto(p, `.ct-mov[data-id="${MOV.s}"] .ct-aviso-dep`)) && opsS.length === 0 && (await cardS.locator('[data-otra]').count()) === 0 &&
    !/préstamo del accionista|Aportación|fn_banco_cobrar|1130|Desde 10[23]0/.test(tS) && /Dinero que llega de Stripe: los cobros en línea de tus clientes, menos sus comisiones\./.test(await texto(p, `.ct-mov[data-id="${MOV.s}"] .ct-texto`)) && (await p.locator('.ct-rojo').count()) === 0, opsS.join(' | '));
  ok('…y solo ofrece «Es el depósito de Stripe del 23 oct 2026: casarlo» (el depósito asentado con ese monto, leído de v_stripe_payouts con los asentados y los de fuera)', /Es el depósito de Stripe del 23 oct 2026: casarlo/.test(await cardS.locator('.ct-acciones .accion').first().textContent()) && (await cardS.locator('.ct-acciones .accion').count()) === 1 &&
    lecturas.some(l => /^v_stripe_payouts\?select=po,estado_pantalla,monto,llegada,fuera_motivo&estado_pantalla=in\.\(asentado,fuera\)/.test(l)));
  const cardSF = p.locator(`.ct-mov[data-id="${MOV.sf}"]`);
  ok('Un depósito STRIPE de un depósito que Edgar sacó de la app («Ya está en el libro») se lleva aquí como antes: «de fuera de la app… regístralo aquí como siempre», con las opciones de c6 (menos la 1020) y «Otra cosa…»',
    /Depósito de Stripe de fuera de la app \(de antes de instalar: lo registré en la bandeja\): regístralo aquí como siempre\./.test(await cardSF.textContent()) && (await cardSF.locator('[data-op]').count()) === 4 && (await cardSF.locator('[data-otra]').count()) === 1 &&
    !(await cardSF.locator('[data-op]').allTextContents()).some(t => /1020/.test(t)));
  const opsB = await p.locator(`.ct-mov[data-id="${MOV.b}"] [data-op]`).allTextContents();
  ok('En otro movimiento, la opción de c6 «Desde 1020 (Stripe…)» tampoco sale (siguen las 4 de siempre)', opsB.length === 4 && !opsB.some(t => /1020/.test(t)), opsB.join(' | '));
  await fila(p, MOV.b);
  await p.locator(`.ct-mov[data-id="${MOV.b}"] [data-otra]`).click(); await p.locator(`.ct-mov[data-id="${MOV.b}"] [data-que="transferencia"]`).click();
  const optTr = await p.locator(`.ct-mov[data-id="${MOV.b}"] select[name="cuenta"] option`).allTextContents();
  ok('«Otra cosa… → Dinero entre cuentas propias» no ofrece la 1020 como destino', optTr.some(t => /1010/.test(t)) && !optTr.some(t => /1020/.test(t)), optTr.join(' | '));
  await foto(p, '21-stripe-bandeja');
  n = llamadas.length;
  await fila(p, MOV.s);
  await cardS.locator('[data-stripe-po]').click(); await esperarLlamada(p, n, 'stripe:casar_payout'); await repintado();
  const csb = desde(n).find(l => l.fn === 'stripe:casar_payout');
  ok('«Es el depósito de Stripe…: casarlo» llama a la función (casar_payout) con el depósito y el movimiento, con la sesión', !!csb && csb.args.po === 'po_PRUEBA04' && csb.args.movimiento_id === MOV.s && /^Bearer /.test(csb.auth), JSON.stringify(csb && csb.args));
  await p.waitForFunction(id => !document.querySelector(`.ct-mov[data-id="${id}"]`), MOV.s, { timeout: 8000 }).catch(() => {});
  ok('…y la bandeja se repinta sin él', (await p.locator(`.ct-mov[data-id="${MOV.s}"]`).count()) === 0);
  // devuelve el depósito asentado a como estaba, para la pestaña
  Object.assign(T.v_stripe_payouts.find(q => q.po === 'po_PRUEBA04'), { estado_pantalla: 'asentado', candidatos: [{ id: MOV.s, fecha: '2026-10-24', descripcion: DEP_STRIPE }], movimiento_id: null, movimiento_fecha: null, movimiento_descripcion: null, casado_regla: null, casado_automatico: null, dias_sin_casar: 4 });

  // la página «Cobros en línea»
  n = llamadas.length; nLect = lecturas.length;
  await tab(p, 'conexiones'); await p.waitForSelector('#ct-stripe-ver', { timeout: 8000 });
  await p.locator('#ct-stripe-ver').click(); await p.waitForSelector('#ct-cobros-facturas', { timeout: 8000 });
  const leidas = lecturas.slice(nLect);
  ok('«Ver los cobros en línea» (en Conexiones) abre la página «Cobros en línea» y lee sus seis vistas con su orden',
    (await titulo()) === 'Cobros en línea' && (await p.locator('.ct-tab[data-pag="cobros"][aria-current="page"]').count()) === 1 &&
    ['^v_stripe_estado\\?select=\\*', '^v_stripe_control\\?select=\\*&order=orden\\.asc', '^v_stripe_facturas\\?select=\\*&order=fecha\\.asc,num\\.asc', '^v_stripe_pagos\\?select=\\*&order=creado_el\\.desc', '^v_stripe_payouts\\?select=\\*&order=llegada\\.desc', '^v_stripe_avisos\\?select=\\*'].every(r => leidas.some(l => new RegExp(r).test(l))), leidas.join(' | '));
  ok('La cabecera dice «4 facturas por cobrar · 2 pagos en camino · 3 depósitos esperando a Chase» con «Revisar con Stripe ahora» a la derecha, sin caja de alarmas (todo verde), las explicaciones largas plegadas y el pie del paralelo',
    /4 facturas por cobrar · 2 pagos en camino · 3 depósitos esperando a Chase/.test(await texto(p, '#ct-cobros-top .ct-pag-sub')) && (await p.locator('#ct-cobros-top .ct-pag-acc #ct-cobros-barrer').count()) === 1 && (await p.locator('#ct-cobros-alarmas').count()) === 0 &&
    (await p.locator('#ct-cobros-facturas .ct-ayuda, #ct-cobros-payouts .ct-ayuda').count()) === 2 && /La casilla «pagada» y QuickBooks los sigues llevando tú durante el paralelo/.test(await texto(p, '.ct-cobros-pie')), await texto(p, '#ct-cobros-top .ct-pag-sub'));
  // las facturas
  ok('Facturas: 4 fichas; la 1102 con «pago en camino» y sin botón de crear; la 1104 con su enlace, el aviso de desfasado y «Crear otro enlace»; la 1101 «pagada en la app»',
    (await p.locator('.ct-factura').count()) === 4 && /pago en camino/.test(await ficha('ct-factura', 'factura', 2).textContent()) && (await ficha('ct-factura', 'factura', 2).locator('[data-crear]').count()) === 0 &&
    /Hay un pago por cuenta de banco de \$3,200\.50 en camino/.test(await ficha('ct-factura', 'factura', 2).textContent()) &&
    (await ficha('ct-factura', 'factura', 4).locator('.ct-enlace-url').inputValue()) === 'https://buy.stripe.com/test_prueba1104' && /El enlace es por \$1,000\.00 y la factura ahora debe \$900\.00/.test(await ficha('ct-factura', 'factura', 4).textContent()) &&
    (await ficha('ct-factura', 'factura', 4).locator('[data-crear="reemplazar"]').count()) === 1 && /pagada en la app/.test(await ficha('ct-factura', 'factura', 1).textContent()));
  await foto(p, '22-cobros');
  // crear el enlace de la 1103: sin monto, solo la factura y la retención
  n = llamadas.length;
  await ficha('ct-factura', 'factura', 3).locator('[data-crear]').click();
  const forma3 = ficha('ct-factura', 'factura', 3).locator('.ct-form');
  ok('«Crear enlace de pago» abre la forma «Enlace de pago de la #1103 por $8,000.00 (un solo uso…)» sin casilla de retención (no tiene) ni de «pagada»',
    /Enlace de pago de la #1103 por \$8,000\.00 \(un solo uso; el cliente elige cuenta de banco o tarjeta\)/.test(await forma3.textContent()) && (await forma3.locator('input[type=checkbox]').count()) === 0 && !desde(n).some(l => l.fn === 'stripe:crear_enlace'));
  await forma3.locator('button[type=submit]').click(); await esperarLlamada(p, n, 'stripe:crear_enlace'); await repintado();
  const ce = desde(n).find(l => l.fn === 'stripe:crear_enlace');
  ok('«Crear el enlace» llama a la función con la sesión y EXACTAMENTE {accion, factura_id: 3, con_retencion: false}: sin monto', !!ce && JSON.stringify(ce.args) === JSON.stringify({ accion: 'crear_enlace', factura_id: 3, con_retencion: false }) && /^Bearer /.test(ce.auth), JSON.stringify(ce && ce.args));
  await toast(/Enlace creado: cópialo y mándaselo al cliente\./);
  await p.waitForSelector('.ct-factura[data-factura="3"] .ct-enlace-url', { timeout: 8000 });
  ok('…avisa «Enlace creado: cópialo y mándaselo al cliente.» y la ficha enseña el enlace, de solo lectura', (await ficha('ct-factura', 'factura', 3).locator('.ct-enlace-url').inputValue()) === 'https://buy.stripe.com/test_prueba1103' && (await ficha('ct-factura', 'factura', 3).locator('.ct-enlace-url').getAttribute('readonly')) !== null);
  await ficha('ct-factura', 'factura', 3).locator('[data-copiar]').click(); await toast(/Enlace copiado/);
  const copiado = await p.evaluate(() => navigator.clipboard.readText()).catch(e => 'error: ' + e);
  ok('«Copiar» deja el enlace en el portapapeles y avisa «Enlace copiado: pégalo en el mensaje al cliente.»', copiado === 'https://buy.stripe.com/test_prueba1103' && /Enlace copiado: pégalo en el mensaje al cliente\./.test(await texto(p, '#toast')), copiado);
  await foto(p, '23-cobros-enlace');
  // la 1101: la casilla «pagada» (QuickBooks) dice pagada y el libro dice que debe
  n = llamadas.length;
  await ficha('ct-factura', 'factura', 1).locator('[data-crear]').click();
  const forma1 = ficha('ct-factura', 'factura', 1).locator('.ct-form');
  await forma1.locator('button[type=submit]').click(); await p.waitForTimeout(200);
  ok('Factura con la casilla «pagada»: la forma lo explica y pide «Sí: el cliente todavía la debe»; sin marcarla dice «Falta confirmar…» y no llama',
    /La casilla «pagada» dice que la #1101 está pagada/.test(await forma1.textContent()) && (await forma1.locator('input[name="aunque_pagada"]').count()) === 1 && /Falta confirmar que el cliente todavía la debe/.test(await texto(p, '.ct-factura[data-factura="1"] .ct-error')) && !desde(n).some(l => l.fn === 'stripe:crear_enlace'));
  await forma1.locator('input[name="aunque_pagada"]').check(); await forma1.locator('button[type=submit]').click(); await esperarLlamada(p, n, 'stripe:crear_enlace'); await repintado();
  const ce1 = desde(n).find(l => l.fn === 'stripe:crear_enlace');
  ok('…marcada, manda {accion, factura_id: 1, con_retencion: false, aunque_pagada: true}', !!ce1 && JSON.stringify(ce1.args) === JSON.stringify({ accion: 'crear_enlace', factura_id: 1, con_retencion: false, aunque_pagada: true }), JSON.stringify(ce1 && ce1.args));
  await p.waitForSelector('.ct-factura[data-factura="1"] .ct-enlace-url', { timeout: 8000 });
  // la 1104: enlace desfasado → crear otro (reemplaza), con la casilla de la retención
  n = llamadas.length;
  await ficha('ct-factura', 'factura', 4).locator('[data-crear="reemplazar"]').click();
  const forma4 = ficha('ct-factura', 'factura', 4).locator('.ct-form');
  ok('«Crear otro enlace» ofrece «Incluir la retención ($100.00)» y dice que el de ahora se desactiva', /Incluir la retención \(\$100\.00\)/.test(await forma4.textContent()) && /El enlace de ahora se desactiva/.test(await forma4.textContent()));
  await forma4.locator('input[name="con_retencion"]').check(); await forma4.locator('button[type=submit]').click(); await esperarLlamada(p, n, 'stripe:crear_enlace'); await repintado();
  const ce4 = desde(n).find(l => l.fn === 'stripe:crear_enlace');
  ok('…y manda {accion, factura_id: 4, con_retencion: true, reemplazar: true}', !!ce4 && JSON.stringify(ce4.args) === JSON.stringify({ accion: 'crear_enlace', factura_id: 4, con_retencion: true, reemplazar: true }), JSON.stringify(ce4 && ce4.args));
  await p.waitForFunction(() => { const i = document.querySelector('.ct-factura[data-factura="4"] .ct-enlace-url'); return i && /_2$/.test(i.value); }, null, { timeout: 8000 });
  ok('El enlace nuevo de la 1104 ya no está desfasado (sin aviso) y es por $1,000.00 con la retención', !/El enlace es por/.test(await ficha('ct-factura', 'factura', 4).textContent()) && /Enlace por \$1,000\.00 \(con la retención\)/.test(await ficha('ct-factura', 'factura', 4).textContent()));
  // desactivar pide motivo
  n = llamadas.length;
  await ficha('ct-factura', 'factura', 4).locator('[data-desactivar]').click();
  await ficha('ct-factura', 'factura', 4).locator('.ct-form button[type=submit]').click(); await p.waitForTimeout(150);
  ok('«Desactivar» pide el motivo y sin él no llama', /Falta motivo/.test(await texto(p, '.ct-factura[data-factura="4"] .ct-error')) && !desde(n).some(l => l.fn === 'stripe:desactivar_enlace'));
  await ficha('ct-factura', 'factura', 4).locator('.ct-form [name=motivo]').fill('El cliente pagó con cheque');
  await ficha('ct-factura', 'factura', 4).locator('.ct-form button[type=submit]').click(); await esperarLlamada(p, n, 'stripe:desactivar_enlace'); await repintado();
  const dsa = desde(n).find(l => l.fn === 'stripe:desactivar_enlace');
  ok('…con motivo llama a desactivar_enlace {enlace, motivo}', !!dsa && dsa.args.enlace === 'e-1104-2' && dsa.args.motivo === 'El cliente pagó con cheque', JSON.stringify(dsa && dsa.args));
  await p.waitForFunction(() => { const c = document.querySelector('.ct-factura[data-factura="4"]'); return c && c.querySelector('[data-crear]') && !c.querySelector('.ct-enlace-url'); }, null, { timeout: 8000 });
  // los pagos: una pastilla por estado, con su texto y su clase
  const ESPERA = { pi_PRUEBA01: ['verificando la cuenta', 'warn', /falta verificar la cuenta \(hasta 10 días\)/], pi_PRUEBA02: ['en camino', 'cu', /tarda unos 4 días hábiles/], pi_PRUEBA03: ['cobrado', 'ok', /En el libro \(asiento 2026-000501\)\. Falta que Stripe lo deposite en Chase\./],
    pi_PRUEBA04: ['en el depósito de Stripe', 'ok', /falta que llegue a Chase/], pi_PRUEBA05: ['depositado', 'ok', /Llegó a Chase con el depósito del 21 oct 2026/], pi_PRUEBA06: ['devuelto', 'bad', /la factura vuelve a deber/],
    pi_PRUEBA07: ['en disputa', 'bad', /Responde en Stripe antes del 10 nov 2026/], pi_PRUEBA08: ['falló', 'bad', /Fondos insuficientes: no entró nada al libro/], pi_PRUEBA09: ['por resolver', 'bad', /no salió de un enlace de la app/] };
  const malPag = [];
  for (const [pi, [txt, cls, re]] of Object.entries(ESPERA)) {
    const f = ficha('ct-pago', 'pi', pi);
    const pl = await f.locator('.ct-cab .ct-pill').first().evaluate(e => ({ t: e.textContent, c: e.className }));
    if (pl.t !== txt || !pl.c.split(' ').includes(cls) || !re.test(await f.textContent())) malPag.push(`${pi}: ${pl.t} (${pl.c})`);
  }
  ok('Pagos: cada estado con su pastilla, su clase y su texto (verificando la cuenta, en camino, cobrado, en el depósito de Stripe, depositado, devuelto, en disputa, falló, por resolver)', (await p.locator('.ct-pago').count()) === 9 && malPag.length === 0, malPag.join(' | '));
  ok('…la secundaria «devuelto $100.00» en el cobrado con un reembolso parcial, y el medio en palabras («Tarjeta», «Cuenta de banco (ACH)»)', /devuelto \$100\.00/.test(await ficha('ct-pago', 'pi', 'pi_PRUEBA03').locator('.ct-pill.warn').textContent()) &&
    /Cuenta de banco \(ACH\)/.test(await ficha('ct-pago', 'pi', 'pi_PRUEBA02').locator('h3').textContent()) && /Tarjeta/.test(await ficha('ct-pago', 'pi', 'pi_PRUEBA03').locator('h3').textContent()) && (await p.locator('.ct-pago [data-resolver]').count()) === 1);
  // «Decir a qué va» el pago por resolver
  n = llamadas.length;
  const f9 = ficha('ct-pago', 'pi', 'pi_PRUEBA09');
  await f9.locator('[data-resolver]').click();
  await f9.locator('select[name="que"]').selectOption('fuera');
  ok('«Decir a qué va»: al elegir «Va a otra cuenta» enseña las cuentas libres (gasto, ingreso…), sin bancos, tarjetas, la 1020 ni cuentas que piden obra, y avisa que lo que ya está en el libro va con «Ya está en el libro»', await f9.locator('label[data-si="fuera"]').isVisible() && await f9.locator('label[data-si="factura"]').isHidden() &&
    /Sácalo con «Ya está en el libro» en su depósito/.test(await f9.locator('p[data-si="fuera"]').textContent()) && await f9.locator('p[data-si="fuera"]').isVisible() &&
    (await f9.locator('select[name="cuenta"] option').allTextContents()).some(t => /6130/.test(t)) && !(await f9.locator('select[name="cuenta"] option').allTextContents()).some(t => /^(1010|1020|2100|5100)/.test(t)));
  await f9.locator('[name=motivo]').fill('Cobro a mano en el panel de Stripe');
  await f9.locator('button[type=submit]').click(); await p.waitForTimeout(150);
  ok('…sin cuenta dice «Falta la cuenta.» y no llama', /Falta la cuenta\./.test(await texto(p, '.ct-pago[data-pi="pi_PRUEBA09"] .ct-error')) && !desde(n).some(l => l.fn === 'stripe:resolver_pago'));
  await f9.locator('select[name="que"]').selectOption('factura'); await f9.locator('select[name="factura_id"]').selectOption('3');
  await f9.locator('[name=motivo]').fill(''); await f9.locator('button[type=submit]').click(); await p.waitForTimeout(150);
  ok('…sin motivo dice «Falta motivo…» y no llama', /Falta motivo/.test(await texto(p, '.ct-pago[data-pi="pi_PRUEBA09"] .ct-error')) && !desde(n).some(l => l.fn === 'stripe:resolver_pago'));
  await f9.locator('[name=motivo]').fill('Es la #1103: el cliente pagó por otro enlace');
  await f9.locator('button[type=submit]').click(); await esperarLlamada(p, n, 'stripe:resolver_pago'); await repintado();
  const rp = desde(n).find(l => l.fn === 'stripe:resolver_pago');
  ok('…con factura y motivo llama a resolver_pago {pi, factura_id: 3, motivo} y el pago queda «cobrado»', !!rp && JSON.stringify(rp.args) === JSON.stringify({ accion: 'resolver_pago', pi: 'pi_PRUEBA09', motivo: 'Es la #1103: el cliente pagó por otro enlace', factura_id: 3 }), JSON.stringify(rp && rp.args));
  await p.waitForFunction(() => { const c = document.querySelector('.ct-pago[data-pi="pi_PRUEBA09"] .ct-pill'); return c && c.textContent === 'cobrado'; }, null, { timeout: 8000 }).catch(() => {});
  n = llamadas.length;
  await ficha('ct-pago', 'pi', 'pi_PRUEBA02').locator('[data-mirar]').click(); await esperarLlamada(p, n, 'stripe:reprocesar'); await repintado();
  ok('«Volver a mirar en Stripe» en un pago llama a reprocesar {pi}', desde(n).some(l => l.fn === 'stripe:reprocesar' && l.args.pi === 'pi_PRUEBA02' && !l.args.po));
  await p.waitForSelector('#ct-cobros-payouts .ct-payout', { timeout: 8000 });
  // los depósitos
  const ESPERA_PO = { po_PRUEBA01: ['en camino a Chase', 'cu'], po_PRUEBA02: ['esperando el detalle de Stripe', 'warn'], po_PRUEBA03: ['espera: falta un cobro', 'bad'], po_PRUEBA04: ['en el libro; falta que llegue a Chase', 'warn'],
    po_PRUEBA05: ['casado con Chase', 'ok'], po_PRUEBA06: ['no llegó (falló)', 'bad'], po_PRUEBA07: ['por revisar', 'bad'], po_PRUEBA09: ['fuera de la app', 'cu'] };
  const malPo = [];
  for (const [po, [txt, cls]] of Object.entries(ESPERA_PO)) {
    const pl = await ficha('ct-payout', 'po', po).locator('.ct-cab .ct-pill').first().evaluate(e => ({ t: e.textContent, c: e.className }));
    if (pl.t !== txt || !pl.c.split(' ').includes(cls)) malPo.push(`${po}: ${pl.t} (${pl.c})`);
  }
  ok('Depósitos: cada estado con su pastilla y su clase (en camino a Chase, esperando el detalle, espera: falta un cobro, en el libro; falta que llegue a Chase, casado con Chase, no llegó, por revisar, fuera de la app)', (await p.locator('.ct-payout').count()) === 9 && malPo.length === 0, malPo.join(' | '));
  const f7t = await ficha('ct-payout', 'po', 'po_PRUEBA07').textContent(), f8t = await ficha('ct-payout', 'po', 'po_PRUEBA08').textContent();
  ok('Las tarjetas no se contradicen: con el detalle guardado y sin asiento dice «Stripe ya dio el detalle» (nunca «todavía no dio el detalle»); el reversado a mano pide «Volver a ponerlo» (no «casa solo»); la línea que la app no conoce sale en llano',
    /Stripe ya dio el detalle de este depósito/.test(f7t) && !/todavía no dio el detalle/.test(f7t) && /Alguien reversó su asiento a mano: toca «Volver a ponerlo»/.test(f8t) && !/casa solo/.test(f8t) &&
    /A qué cuenta va: Stripe retuvo \(o soltó\) una reserva/.test(f7t) && /Fuera de la app \(de antes de instalar: lo registré en la bandeja\)/.test(await ficha('ct-payout', 'po', 'po_PRUEBA09').textContent()), [f7t.slice(0, 200), f8t.slice(0, 200)]);
  const f4 = ficha('ct-payout', 'po', 'po_PRUEBA04'), f5 = ficha('ct-payout', 'po', 'po_PRUEBA05');
  ok('El asentado dice «2 cobros por $1,400.00 − comisiones $34.30 = $1,365.70», «Asientos 2026-000510 (sale de Stripe) y 2026-000511 (llega a Chase)», sus 3 líneas y el depósito de Chase candidato; el casado, con qué movimiento y que casó solo',
    /2 cobros por \$1,400\.00 − comisiones \$34\.30 = \$1,365\.70/.test(await f4.textContent()) && /Asientos 2026-000510 \(sale de Stripe\) y 2026-000511 \(llega a Chase\)/.test(await f4.textContent()) && (await f4.locator('.ct-payout-lineas li').count()) === 3 &&
    /Casar con el depósito de Chase del 24 oct 2026/.test(await f4.locator('[data-casar]').textContent()) && /Casó con «ORIG CO NAME:STRIPE.*» del 21 oct 2026 · casó solo/.test(await f5.textContent()) && /Cobro pi_PRUEBA10: sin datos del pago/.test(await ficha('ct-payout', 'po', 'po_PRUEBA03').textContent()));
  await foto(p, '24-cobros-depositos');
  n = llamadas.length;
  await f4.locator('[data-casar]').click(); await esperarLlamada(p, n, 'stripe:casar_payout'); await repintado();
  const cp4 = desde(n).find(l => l.fn === 'stripe:casar_payout');
  ok('«Casar con el depósito de Chase del …» llama a casar_payout {po, movimiento_id}', !!cp4 && cp4.args.po === 'po_PRUEBA04' && cp4.args.movimiento_id === MOV.s, JSON.stringify(cp4 && cp4.args));
  await p.waitForFunction(() => { const c = document.querySelector('.ct-payout[data-po="po_PRUEBA04"] .ct-pill'); return c && c.textContent === 'casado con Chase'; }, null, { timeout: 8000 }).catch(() => {});
  ok('…y se repinta «casado con Chase»', (await ficha('ct-payout', 'po', 'po_PRUEBA04').locator('.ct-cab .ct-pill').first().textContent()) === 'casado con Chase');
  // «Ya está en el libro»: un depósito sin asientos que espera sale de la app con su motivo
  const f3 = ficha('ct-payout', 'po', 'po_PRUEBA03');
  ok('Un depósito sin asientos que espera (o por revisar) ofrece «Ya está en el libro»; uno asentado, no', (await f3.locator('[data-fuera]').count()) === 1 && (await ficha('ct-payout', 'po', 'po_PRUEBA07').locator('[data-fuera]').count()) === 1 &&
    (await ficha('ct-payout', 'po', 'po_PRUEBA04').locator('[data-fuera]').count()) === 0 && (await ficha('ct-payout', 'po', 'po_PRUEBA08').locator('[data-fuera]').count()) === 0);
  n = llamadas.length;
  await f3.locator('[data-fuera]').click(); await f3.locator('.ct-form button[type=submit]').click(); await p.waitForTimeout(150);
  ok('…sin motivo dice «Falta …» y no llama', /Falta/.test(await texto(p, '.ct-payout[data-po="po_PRUEBA03"] .ct-error')) && !desde(n).some(l => l.fn === 'stripe:payout_fuera'));
  await f3.locator('.ct-form [name=motivo]').fill('Es de antes de instalar: lo registré en la bandeja');
  await f3.locator('.ct-form button[type=submit]').click(); await esperarLlamada(p, n, 'stripe:payout_fuera'); await repintado();
  const pf = desde(n).find(l => l.fn === 'stripe:payout_fuera');
  ok('…con motivo llama a payout_fuera {po, motivo} y se repinta «fuera de la app»', !!pf && JSON.stringify(pf.args) === JSON.stringify({ accion: 'payout_fuera', po: 'po_PRUEBA03', motivo: 'Es de antes de instalar: lo registré en la bandeja' }) &&
    (await ficha('ct-payout', 'po', 'po_PRUEBA03').locator('.ct-cab .ct-pill').first().textContent()) === 'fuera de la app', JSON.stringify(pf && pf.args));
  n = llamadas.length;
  const f7 = ficha('ct-payout', 'po', 'po_PRUEBA07');
  await f7.locator('[data-linea]').click();
  await f7.locator('.ct-form button[type=submit]').click(); await p.waitForTimeout(150);
  ok('Un movimiento que la app no conoce: «A qué cuenta va» pide la cuenta (sin elegirla, «Falta cuenta.») y no llama', /Falta cuenta/.test(await texto(p, '.ct-payout[data-po="po_PRUEBA07"] .ct-error')) && !desde(n).some(l => l.fn === 'stripe:resolver_linea'));
  await f7.locator('.ct-form select[name="cuenta"]').selectOption('6130'); await f7.locator('.ct-form [name=motivo]').fill('Reserva de Stripe');
  await f7.locator('.ct-form button[type=submit]').click(); await esperarLlamada(p, n, 'stripe:resolver_linea'); await repintado();
  const rl = desde(n).find(l => l.fn === 'stripe:resolver_linea');
  ok('…con cuenta y motivo llama a resolver_linea {po, txn, cuenta, motivo}', !!rl && JSON.stringify(rl.args) === JSON.stringify({ accion: 'resolver_linea', po: 'po_PRUEBA07', txn: 'txn_PRUEBA70', cuenta: '6130', motivo: 'Reserva de Stripe' }), JSON.stringify(rl && rl.args));
  await p.waitForSelector('.ct-payout[data-po="po_PRUEBA08"] [data-rehacer]', { timeout: 8000 });
  n = llamadas.length;
  ok('Un depósito con un asiento reversado a mano lleva «reversado a mano»', /reversado a mano/.test(await ficha('ct-payout', 'po', 'po_PRUEBA08').textContent()));
  await ficha('ct-payout', 'po', 'po_PRUEBA08').locator('[data-rehacer]').click(); await esperarLlamada(p, n, 'stripe:reprocesar'); await repintado();
  ok('…«Volver a ponerlo» llama a reprocesar {po, rehacer: true}', desde(n).some(l => l.fn === 'stripe:reprocesar' && l.args.po === 'po_PRUEBA08' && l.args.rehacer === true));
  await p.waitForSelector('#ct-cobros-avisos .ct-aviso-stripe', { timeout: 8000 });
  // los avisos y «Revisar con Stripe ahora»
  ok('Avisos de Stripe: los dos, el grave primero (clase bad) y el repetido con «2 veces»', (await p.locator('.ct-aviso-stripe').count()) === 2 && (await p.locator('.ct-aviso-stripe').first().getAttribute('class')).includes('bad') && /2 veces/.test(await texto(p, '.ct-aviso-stripe.warn')), await texto(p, '#ct-cobros-avisos'));
  n = llamadas.length;
  await p.locator('.ct-aviso-stripe[data-aviso="11"] [data-visto]').click(); await esperarLlamada(p, n, 'stripe:aviso_visto'); await repintado();
  ok('«Entendido» llama a aviso_visto {aviso: 11} y el aviso se va', desde(n).some(l => l.fn === 'stripe:aviso_visto' && l.args.aviso === 11) && await p.waitForFunction(() => !document.querySelector('.ct-aviso-stripe[data-aviso="11"]'), null, { timeout: 8000 }).then(() => true).catch(() => false));
  n = llamadas.length;
  await p.locator('#ct-cobros-barrer').click(); await esperarLlamada(p, n, 'stripe:barrer'); await repintado(); await toast(/Revisado con Stripe/); await repintado();
  ok('«Revisar con Stripe ahora» llama a barrer y avisa «Revisado con Stripe»', desde(n).some(l => l.fn === 'stripe:barrer' && /^Bearer /.test(l.auth)));
  // los errores de la función
  await p.waitForSelector('.ct-factura[data-factura="2"]', { timeout: 8000 });
  estado.stripeFalla = { estado: 409, cuerpo: { codigo: 'MX008', error: 'La factura #1103 no debe nada en el libro (prueba).' } };
  await ficha('ct-pago', 'pi', 'pi_PRUEBA01').locator('[data-mirar]').click();
  await p.waitForSelector('.ct-pago[data-pi="pi_PRUEBA01"] .ct-stripe-res .ct-aviso.warn', { timeout: 8000 });
  ok('Un 409 MX008 de la función sale en amarillo con su mensaje y los botones vuelven', /La factura #1103 no debe nada en el libro \(prueba\)/.test(await texto(p, '.ct-pago[data-pi="pi_PRUEBA01"] .ct-stripe-res .ct-aviso.warn')) && !(await ficha('ct-pago', 'pi', 'pi_PRUEBA01').locator('[data-mirar]').isDisabled()), await texto(p, '.ct-pago[data-pi="pi_PRUEBA01"]'));
  estado.stripeFalla = { estado: 502, cuerpo: { codigo: 'STRIPE_PERMISO', error: "A la llave de Stripe le falta un permiso: rak_payment_link_write (/v1/payment_links).", rak: 'rak_payment_link_write' } };
  await ficha('ct-pago', 'pi', 'pi_PRUEBA01').locator('[data-mirar]').click();
  await p.waitForSelector('.ct-pago[data-pi="pi_PRUEBA01"] .ct-stripe-res .ct-aviso.bad', { timeout: 8000 });
  ok('Un 502 STRIPE_PERMISO sale en rojo con el permiso que falta (rak_payment_link_write)', /A la llave de Stripe le falta el permiso rak_payment_link_write/.test(await texto(p, '.ct-pago[data-pi="pi_PRUEBA01"] .ct-stripe-res')));
  estado.stripeFalla = { estado: 403, cuerpo: { codigo: 'MFA', error: 'Falta el código del teléfono: entra otra vez con él (los cobros en línea lo piden).' } };
  await ficha('ct-pago', 'pi', 'pi_PRUEBA01').locator('[data-mirar]').click();
  await p.waitForFunction(() => /Falta el código del teléfono: entra otra vez con él\./.test((document.querySelector('.ct-pago[data-pi="pi_PRUEBA01"] .ct-stripe-res') || {}).textContent || ''), null, { timeout: 8000 }).catch(() => {});
  ok('Un 403 MFA dice «Falta el código del teléfono: entra otra vez con él.»', /Falta el código del teléfono: entra otra vez con él\./.test(await texto(p, '.ct-pago[data-pi="pi_PRUEBA01"] .ct-stripe-res .ct-aviso.warn')));
  estado.stripeFalla = { estado: 502, cuerpo: { codigo: 'STRIPE_CAIDO', error: 'Stripe no contestó: el enlace se termina de crear solo cuando vuelva (o toca otra vez «Crear enlace»).' } };
  await ficha('ct-factura', 'factura', 4).locator('[data-crear]').click(); await ficha('ct-factura', 'factura', 4).locator('.ct-form button[type=submit]').click();
  await p.waitForSelector('.ct-factura[data-factura="4"] .ct-stripe-res .ct-aviso.warn', { timeout: 8000 });
  ok('Stripe caído al crear el enlace: amarillo con «se termina de crear solo cuando vuelva»', /se termina de crear solo cuando vuelva/.test(await texto(p, '.ct-factura[data-factura="4"] .ct-stripe-res')));
  await ctx.setOffline(true); n = llamadas.length;
  await ficha('ct-pago', 'pi', 'pi_PRUEBA01').locator('[data-mirar]').click(); await p.waitForTimeout(200);
  ok('Sin señal, una acción dice «Sin señal: no se hizo nada.» y no llama', /Sin señal: no se hizo nada\./.test(await texto(p, '.ct-pago[data-pi="pi_PRUEBA01"] .ct-stripe-res')) && !desde(n).some(l => /^stripe:/.test(l.fn)));
  await tab(p, 'cobros'); await p.waitForSelector('.ct-rojo', { timeout: 8000 });
  ok('Sin señal, la pestaña pinta «Sin señal» con «Reintentar» y nada de memoria', /Sin señal/.test(await texto(p, '.ct-rojo h2')) && (await p.locator('.ct-factura, .ct-pago, .ct-payout').count()) === 0 && (await p.locator('#ct-reintentar').count()) === 1);
  await ctx.setOffline(false);
  await p.waitForSelector('#ct-cobros-facturas', { timeout: 8000 }).catch(() => {});
  ok('Al volver la señal, reintenta sola y pinta los cobros', (await p.locator('.ct-factura').count()) === 4);
  // el control: falla ruidosa
  estado.stripeCuadreMal = true;
  await tab(p, 'cobros'); await p.waitForSelector('.ct-rojo', { timeout: 8000 });
  ok('Un cuadre en rojo (21): «Los cobros en línea no cuadran: no se pinta», el detalle de la base, y ninguna lista', /Los cobros en línea no cuadran: no se pinta/.test(await texto(p, '.ct-rojo h2')) && /la 1020 dice 4,100\.00/.test(await texto(p, '.ct-rojo')) && (await p.locator('#ct-cobros-facturas, .ct-pago, .ct-payout').count()) === 0);
  await foto(p, '25-cobros-rojo');
  estado.stripeCuadreMal = false; estado.stripeConteo = true;
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('.ct-rojo', { timeout: 8000 }); await p.waitForTimeout(150);
  ok(`Si la pantalla trae ${T.v_stripe_pagos.length} pagos y el control contó 99, también es rojo`, new RegExp(`trajo ${T.v_stripe_pagos.length} fila\\(s\\) y el control contó 99`).test(await texto(p, '.ct-rojo')), await texto(p, '.ct-rojo .ct-tabla'));
  estado.stripeConteo = false; estado.stripeAlarma = true;
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('#ct-cobros-facturas', { timeout: 8000 });
  ok('Una alarma en rojo (30) no tumba la pantalla: la caja «Hay que mirar esto:» arriba, en llano (lo que pasa y qué hacer, no el nombre del control) con su detalle, y las listas debajo', /Hay que mirar esto:/.test(await texto(p, '#ct-cobros-alarmas h2')) && /Pagos que no sé a qué factura van: «Decir a qué va».*pi_PRUEBA09/.test(await texto(p, '#ct-cobros-alarmas')) && !/ningún pago por resolver/.test(await texto(p, '#ct-cobros-alarmas')) && (await p.locator('.ct-factura').count()) === 4 && (await p.locator('.ct-rojo').count()) === 0);
  // la alarma también sale en la portada, en «Qué atender», con su botón a Cobros
  await tab(p, 'resumen'); await p.waitForSelector('#ct-atender', { timeout: 8000 });
  const atnS = await p.locator('#ct-atender .ct-atn').allTextContents();
  ok('La portada lista la alarma de Stripe (30) en «Qué atender» en llano, con su detalle y el botón a Cobros', atnS.some(t => /Pagos que no sé a qué factura van.*pi_PRUEBA09/.test(t)) && (await p.locator('#ct-atender .ct-atn button[data-ir="cobros"]').count()) === 1 && (await p.locator('.ct-rojo').count()) === 0, atnS.join(' | '));
  estado.stripeAlarma = false;
  // la tarjeta de Conexiones: modo de prueba, falta configurar
  estado.stripeModo = 'prueba';
  await tab(p, 'conexiones'); await p.waitForSelector('#ct-stripe', { timeout: 8000 });
  ok('Con una llave de prueba la tarjeta dice «modo de prueba» y que no se registra nada', /modo de prueba/.test(await texto(p, '#ct-stripe .ct-cab')) && /no se registra nada/.test(await texto(p, '#ct-stripe')));
  estado.stripeModo = 'real'; estado.stripeSinLlave = true;
  await tab(p, 'conexiones'); await p.waitForFunction(() => /falta configurar/.test((document.querySelector('#ct-stripe .ct-cab') || {}).textContent || ''), null, { timeout: 8000 }).catch(() => {});
  ok('Si la salud dice que falta la llave: «falta configurar» y qué falta en Secrets', /falta configurar/.test(await texto(p, '#ct-stripe .ct-cab')) && /STRIPE_SECRET_KEY/.test(await texto(p, '#ct-stripe .ct-aviso.bad')));
  estado.stripeSinLlave = false;
  // p1 sin pegar
  estado.stripeSinVista = true;
  await tab(p, 'conexiones'); await p.waitForFunction(() => /sin instalar/.test((document.querySelector('#ct-stripe') || {}).textContent || ''), null, { timeout: 8000 }).catch(() => {});
  ok('Sin p1 en la base (404 PGRST205): la tarjeta dice «sin instalar» y la cabecera «Stripe sin instalar»', /sin instalar/.test(await texto(p, '#ct-stripe')) && /docs\/conta\/p1-stripe\.sql/.test(await texto(p, '#ct-stripe')) && /Stripe sin instalar/.test(await texto(p, '.ct-pag-sub')));
  await tab(p, 'resumen'); await p.waitForSelector('.ct-ficha', { timeout: 8000 });
  ok('…la portada dice «sin instalar» en la ficha de cobros, sin rojo', /Cobros en línea—sin instalar/.test(await texto(p, '.ct-ficha[data-ir="cobros"]')) && (await p.locator('.ct-rojo').count()) === 0, await texto(p, '.ct-ficha[data-ir="cobros"]'));
  await tab(p, 'bancos'); await p.waitForSelector('.ct-cuenta', { timeout: 8000 });
  ok('…y las cuentas se pintan igual (4)', (await p.locator('.ct-cuenta').count()) === 4);
  await tab(p, 'cobros'); await p.waitForSelector('#ct-cobros-sin', { timeout: 8000 });
  ok('…y la página dice «Los cobros en línea no están instalados», sin rojo', /no están instalados/.test(await texto(p, '#ct-cobros-sin')) && (await p.locator('.ct-rojo').count()) === 0);
  estado.stripeSinVista = false;
  const guardado = await p.evaluate(() => { const t = []; for (const st of [localStorage, sessionStorage]) for (let i = 0; i < st.length; i++) t.push(st.key(i) + '=' + st.getItem(st.key(i))); return t.join('\n'); });
  ok('Nada de cobros en el teléfono: localStorage y sessionStorage sin enlaces, pagos ni depósitos', !/buy\.stripe\.com|pi_PRUEBA|po_PRUEBA|v_stripe/.test(guardado));
  await tab(p, 'conexiones'); await p.waitForSelector('#ct-stripe', { timeout: 8000 });
  n = llamadas.length;
  await p.waitForSelector('#ct-mfa-quitar', { timeout: 8000 });
  await p.locator('#ct-mfa-quitar').click();
  await p.locator('#ct-mfa .ct-form button[type=submit]').click();
  await p.waitForFunction(() => { const e = document.querySelector('#ct-mfa'); return e && /no activo/.test(e.textContent); }, null, { timeout: 8000 });
  ok('«Quitar el código» pregunta, lo quita en Supabase Auth y la tarjeta vuelve a «no activo»', desde(n).some(l => l.fn === 'auth:quitar') && await p.locator('#ct-plaid-conectar').isDisabled());
  // sin el código del teléfono (aal2), nada de lo que habla con Stripe se puede tocar (la función también lo exige)
  ok('Sin el código: en la tarjeta de Stripe «Probar la llave» y «Revisar con Stripe ahora» salen apagados con «Primero activa el código del teléfono»', await p.locator('#ct-stripe-probar').isDisabled() && await p.locator('#ct-stripe-barrer').isDisabled() && /Primero activa el código del teléfono/.test(await texto(p, '#ct-stripe')) && !(await p.locator('#ct-stripe-ver').isDisabled()));
  n = llamadas.length;
  await tab(p, 'cobros'); await p.waitForSelector('#ct-cobros-facturas', { timeout: 8000 });
  const crearSin = p.locator('.ct-factura [data-crear]').first();
  await crearSin.click({ force: true }).catch(() => {}); await p.waitForTimeout(200);
  ok('…y en «Cobros en línea» «Crear enlace de pago» sale apagado con «Primero activa el código del teléfono (Conexiones y seguridad).», igual que «Revisar con Stripe ahora»; tocarlo no llama a crear_enlace',
    (await p.locator('.ct-factura [data-crear]').count()) >= 1 && await crearSin.isDisabled() && /Primero activa el código del teléfono \(Conexiones y seguridad\)\./.test(await texto(p, '#ct-cobros-facturas')) && await p.locator('#ct-cobros-barrer').isDisabled() &&
    !desde(n).some(l => l.fn === 'stripe:crear_enlace') && (await p.locator('.ct-factura .ct-form:not([hidden])').count()) === 0 && !(await p.locator('.ct-factura [data-copiar]').first().isDisabled()));
  await foto(p, '26-cobros-sin-codigo');

  // ---- Entrar con el código: una sesión guardada sin el código, con el factor activado ----
  estado.mfaFactores = [{ id: 'f-1', friendly_name: 'Teléfono de Edgar', factor_type: 'totp', status: 'verified' }]; estado.sesionAal = 'aal1';
  const ctx2 = await b.newContext({ viewport: { width: 1280, height: 900 }, serviceWorkers: 'block' });
  await simular(ctx2, 'dueno');
  // con un robot (navigator.webdriver) la app usa los cuadros nativos del navegador; aquí se prueban sus ventanas propias
  await ctx2.addInitScript(() => { window.__mxpDialogosNativos = false; });
  const p2 = await ctx2.newPage(); p2.on('pageerror', e => errs.push('código: ' + String(e).slice(0, 160)));
  const consola2 = []; p2.on('console', m => { if (m.type() === 'warning' || m.type() === 'error') consola2.push(m.text().slice(0, 160)); });
  p2.on('dialog', d => { consola2.push('diálogo nativo: ' + d.message().slice(0, 80)); d.dismiss().catch(() => {}); });
  await p2.goto('http://localhost:8873/index.html');
  const pidio = await p2.waitForSelector('dialog[open] [name=dato]', { timeout: 15000 }).then(() => true).catch(() => false);
  const diag2 = async () => JSON.stringify({ login: await p2.locator('#vista-login').isVisible(), app: await p2.locator('#vista-app').isVisible(), dialogos: await p2.locator('dialog[open]').count(),
    sesion: await p2.evaluate(() => { try { const s = JSON.parse(localStorage.getItem('mxp_sesion')); return s ? { aal: JSON.parse(atob(s.access_token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))).aal, factores: (s.user && s.user.factors || []).map(f => f.status) } : null; } catch (e) { return String(e); } }),
    pendiente: await p2.evaluate(() => window.MXP_DB && window.MXP_DB.mfaPendiente ? window.MXP_DB.mfaPendiente() : 'sin mfaPendiente'), consola: consola2.slice(-4) });
  ok('Con el código activado y una sesión que entró solo con la contraseña, la app pide los 6 dígitos antes de arrancar', pidio && /Código del teléfono/.test(await texto(p2, 'dialog[open]')) && await p2.locator('#vista-app').isHidden(), await diag2());
  if (pidio) {
    await p2.locator('dialog[open] [name=dato]').fill('123456');
    await p2.locator('dialog[open] button[value=si]').click();
    await p2.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }).catch(() => {});
  }
  ok('Con los 6 dígitos buenos, la sesión pasa a aal2 y la app arranca', pidio && await p2.locator('#vista-app').isVisible() && (await p2.evaluate(() => { try { const s = JSON.parse(localStorage.getItem('mxp_sesion')); return JSON.parse(atob(s.access_token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))).aal; } catch { return null; } })) === 'aal2', await diag2());
  await ctx2.close();
  estado.mfaFactores = []; estado.sesionAal = undefined;

  // ---- Los cobros en línea en el teléfono (390 px) ----
  {
    const tel = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, serviceWorkers: 'block' });
    await simular(tel, 'dueno');
    const q = await tel.newPage(); q.on('pageerror', e => errs.push('teléfono cobros: ' + String(e).slice(0, 160)));
    await q.goto('http://localhost:8873/index.html'); await q.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await q.waitForTimeout(800);
    await q.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
    await q.locator('#btn-conta').evaluate(b => b.click()); await q.waitForSelector('.ct-ficha', { timeout: 8000 });
    const telR = await q.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: window.innerWidth, cols: getComputedStyle(document.querySelector('.ct-fichas')).gridTemplateColumns.split(' ').length, fuera: [...document.querySelectorAll('#conta-raiz *')].filter(e => e.getBoundingClientRect().right > window.innerWidth + 1 && !e.closest('.ct-tabs')).length }));
    ok('Teléfono (390 px): la portada va a dos columnas de fichas y nada se sale de la pantalla', telR.sw <= telR.iw + 1 && telR.cols === 2 && telR.fuera === 0, JSON.stringify(telR));
    await tab(q, 'conexiones'); await q.waitForSelector('#ct-stripe', { timeout: 8000 });
    await q.locator('#ct-stripe').scrollIntoViewIfNeeded();
    const telB = await q.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: window.innerWidth, der: document.querySelector('#ct-stripe').getBoundingClientRect().right }));
    ok('Teléfono (390 px): la tarjeta de Stripe en Conexiones cabe y la página no desplaza de lado', telB.sw <= telB.iw + 1 && telB.der <= telB.iw, JSON.stringify(telB));
    await foto(q, '27-tel-stripe-conexiones');
    await tab(q, 'bandeja'); await q.waitForSelector('.ct-mov', { timeout: 8000 });
    const telF = await q.evaluate(() => { const f = document.querySelector('.ct-mov-fila'); const r = f.getBoundingClientRect(); const desc = f.querySelector('.ct-f-desc').getBoundingClientRect(), meta = f.querySelector('.ct-f-meta').getBoundingClientRect(), monto = f.querySelector('.ct-f-monto').getBoundingClientRect();
      return { sw: document.documentElement.scrollWidth, iw: window.innerWidth, cab: getComputedStyle(document.querySelector('.ct-feed-cab')).display, dosLineas: meta.top >= desc.bottom - 2 && monto.top < desc.bottom && monto.bottom > desc.top, alto: r.height }; });
    ok('Teléfono: cada fila de la bandeja va en dos líneas (descripción y monto arriba; fecha, cuenta y motivo debajo), sin la cabecera de tabla y sin desplazar de lado', telF.sw <= telF.iw + 1 && telF.cab === 'none' && telF.dosLineas, JSON.stringify(telF));
    await tab(q, 'cobros'); await q.waitForSelector('#ct-cobros-payouts .ct-payout', { timeout: 8000 });
    await q.evaluate(() => document.querySelectorAll('.ct-payout-det').forEach(d => { d.open = true; }));
    const telC = await q.evaluate(() => { const u = document.querySelector('.ct-enlace-url'); const fuera = [...document.querySelectorAll('#conta-raiz *')].filter(e => e.getBoundingClientRect().right > window.innerWidth + 1 && getComputedStyle(e).position !== 'fixed' && !e.closest('.ct-tabs')).map(e => e.className || e.tagName).slice(0, 5);
      return { sw: document.documentElement.scrollWidth, iw: window.innerWidth, url: u ? u.getBoundingClientRect().right : null, fuera }; });
    ok('Teléfono: «Cobros en línea» (facturas con su enlace, pagos, depósitos con su detalle abierto) sin desplazamiento lateral: nada se sale de la pantalla y el enlace cabe', telC.sw <= telC.iw + 1 && telC.url != null && telC.url <= telC.iw && telC.fuera.length === 0, JSON.stringify(telC));
    await foto(q, '28-tel-cobros');
    await tel.close();
  }

  // ---- La IA contable (c8, fase 7): la franja de la bandeja, el chip de cada fila, «Según la IA» y «Según yo», Conexiones y «Qué atender» ----
  {
    estado.c8 = true; iaReset();
    estado.mfaFactores = [{ id: 'f-1', friendly_name: 'Teléfono de Edgar', factor_type: 'totp', status: 'verified' }]; estado.sesionAal = 'aal2';
    const cx = await b.newContext({ viewport: { width: 1280, height: 900 }, serviceWorkers: 'block' });
    await simular(cx, 'dueno');
    const q = await cx.newPage(); q.on('pageerror', e => errs.push('IA: ' + String(e).slice(0, 160)));
    await q.goto('http://localhost:8873/index.html'); await q.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await q.waitForTimeout(800);
    await q.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
    await q.locator('#btn-conta').evaluate(x => x.click()); await q.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 });
    const irA = async k => { await q.evaluate(k => window.MXP_CONTA.ir(k), k); await pintado(q); };
    // el aviso se vacía antes de cada acción: así no se lee el de la anterior
    const sinToast = () => q.evaluate(() => { const t = document.getElementById('toast'); if (t) t.textContent = ''; });
    const tostada = async re => { await q.waitForFunction(r => { const t = document.getElementById('toast'); return t && !t.hidden && new RegExp(r).test(t.textContent); }, re.source, { timeout: 8000 }).catch(() => {}); return (await q.locator('#toast').textContent()) || ''; };
    const movQ = id => q.locator(`.ct-mov[data-id="${id}"]`);
    const ultima = (n0, fn) => desde(n0).filter(l => l.fn === fn).slice(-1)[0];
    let n0 = llamadas.length, l0 = lecturas.length;
    await irA('bandeja');
    // la franja
    ok('IA · la bandeja lee v_contador_estado, v_contador_bandeja, v_contador_control y v_contador_cuentas, y con el código del teléfono pide la salud a la función con la sesión',
      ['v_contador_estado', 'v_contador_bandeja', 'v_contador_control', 'v_contador_cuentas'].every(v => lecturas.slice(l0).some(l => l.startsWith(v + '?'))) && desde(n0).some(l => l.fn === 'contador:salud' && /^Bearer /.test(l.auth)),
      lecturas.slice(l0).filter(l => /contador/.test(l)).join(' | '));
    ok('IA · la franja dice «5 propuestas listas · 1 por proponer · este mes $4.20 de $30.00» y «Proponer ahora (1)» se puede tocar, sin freno (con «Proponer sola» apagado no arrancó nada: no hubo «proponer»)',
      !desde(n0).some(l => l.fn === 'contador:proponer') && /^5 propuestas listas · 1 por proponer · este mes \$4\.20 de \$30\.00$/.test((await q.locator('#ct-ia-cifras').textContent()).trim()) && /Proponer ahora \(1\)/.test(await q.locator('#ct-ia-proponer').textContent()) && !(await q.locator('#ct-ia-proponer').isDisabled()) && (await q.locator('.ct-ia-freno').count()) === 0,
      await q.locator('#ct-ia-franja').textContent());
    ok('IA · la franja va debajo de la cabecera y antes de la barra de herramientas; la bandeja trae los 8 movimientos (los 3 de siempre y los 5 cargos de la IA)',
      JSON.stringify(await q.locator('#ct-main > *').evaluateAll(xs => xs.map(x => x.id || x.className).slice(0, 3))) === '["ct-pag-cab","ct-ia-franja","ct-bj-herr"]' && (await q.locator('.ct-mov').count()) === 8,
      JSON.stringify(await q.locator('#ct-main > *').evaluateAll(xs => xs.map(x => x.id || x.className))));
    // el chip de cada fila
    const chip = async id => (await movQ(id).locator('.ct-f-motivo .ct-ia-chip').count()) ? (await movQ(id).locator('.ct-f-motivo .ct-ia-chip').textContent()).trim() : null;
    const chips = { hd: await chip(MI.hd), wawa: await chip(MI.wawa), amz: await chip(MI.amz), fe: await chip(MOV.a), b: await chip(MOV.b), c: await chip(MOV.c) };
    ok('IA · el chip de la fila compacta: «IA · 5100 Material · ¿obra? · 92 %» (la 5100 pide la obra y falta), «Regla · WAWA», «IA · 6400 Herramienta menor y uniformes · 55 %», «sin propuesta» en la ferretería sin ticket, y ninguno en la partida ni en el duplicado',
      chips.hd === 'IA · 5100 Material · ¿obra? · 92 %' && chips.wawa === 'Regla · WAWA' && chips.amz === 'IA · 6400 Herramienta menor y uniformes · 55 %' && chips.fe === 'sin propuesta' && chips.b === null && chips.c === null, JSON.stringify(chips));
    // «Proponer ahora»: la función dice «bloqueado» (no se gasta nada), y después la ráfaga de verdad, con el botón girando y el avance de la cadena
    estado.iaBloqueaFuncion = true; n0 = llamadas.length;
    await sinToast(); await q.locator('#ct-ia-proponer').click();
    const tb = await tostada(/La IA no propuso nada/);
    await pintado(q);
    ok('IA · si la función contesta «bloqueado» (el tope), el aviso lo dice en rojo y la ferretería sigue «sin propuesta»', /La IA no propuso nada: tope del contador \(prueba\)/.test(tb) && /error/.test(await q.locator('#toast').getAttribute('class')) && (await chip(MOV.a)) === 'sin propuesta' && desde(n0).some(l => l.fn === 'contador:proponer'), tb);
    estado.iaBloqueaFuncion = false; estado.iaLento = 700; n0 = llamadas.length;
    await sinToast(); await q.locator('#ct-ia-proponer').click(); await q.waitForTimeout(250);
    const girando = await q.evaluate(() => { const bt = document.getElementById('ct-ia-proponer'); return { gira: !!bt && bt.disabled && bt.getAttribute('aria-busy') === 'true', espera: /^Proponiendo… 0 de 1 · \$0\.00$/.test(((document.querySelector('#ct-ia-cadena .ct-ia-avance') || {}).textContent || '').trim()) && !!document.getElementById('ct-ia-parar') }; });
    const tp = await tostada(/propuesta/);
    await pintado(q); estado.iaLento = 0;
    const pro = ultima(n0, 'contador:proponer');
    ok('IA · «Proponer ahora» llama a la función (proponer) con la sesión; mientras espera el botón se apaga (aria-busy) y la franja dice «Proponiendo… 0 de 1 · $0.00» (girando) con «Parar»', !!pro && JSON.stringify(pro.args) === '{"accion":"proponer"}' && /^Bearer /.test(pro.auth) && girando.gira && girando.espera, JSON.stringify(girando));
    ok('IA · al terminar avisa «1 propuesta · 0 por regla · 0 sin respuesta · $0.12» y repinta: la ferretería trae «IA · 5100 Material · ¿obra? · 81 %» y la franja «6 propuestas listas · 0 por proponer · este mes $4.32»',
      /^1 propuesta · 0 por regla · 0 sin respuesta · \$0\.12$/.test(tp.trim()) && (await chip(MOV.a)) === 'IA · 5100 Material · ¿obra? · 81 %' && /^6 propuestas listas · 0 por proponer · este mes \$4\.32 de \$30\.00$/.test((await q.locator('#ct-ia-cifras').textContent()).trim()), tp);
    ok('IA · sin nada por proponer el botón se apaga y dice por qué', await q.locator('#ct-ia-proponer').isDisabled() && /Nada por proponer/.test(await texto(q, '.ct-ia-freno')));
    // Home Depot: las dos columnas y «Así es» con la obra
    const hd = await fila(q, MI.hd);
    const cols = await hd.evaluate(c => { const a = c.querySelector('.ct-ia-suya').getBoundingClientRect(), y = c.querySelector('.ct-ia-mia').getBoundingClientRect(); return { lado: Math.abs(a.top - y.top) < 2 && a.right <= y.left, a: Math.round(a.width), y: Math.round(y.width) }; });
    ok('IA · desplegado, el movimiento trae «Según la IA» y «Según yo» lado a lado en la computadora', cols.lado && (await hd.locator('.ct-ia-suya .ct-ia-h').textContent()) === 'Según la IA' && (await hd.locator('.ct-ia-mia .ct-ia-h').textContent()) === 'Según yo', JSON.stringify(cols));
    const suya = await hd.locator('.ct-ia-suya').textContent();
    ok('IA · «Según la IA»: la línea (5100 Material, falta la obra), el motivo en llano, «92 % de confianza» en verde, el chip «Pide obra», «Propuso claude-opus-5-5» y el selector de la obra',
      /5100\s*Material/.test(suya) && /falta la obra/.test(suya) && /Home Depot vende material eléctrico/.test(suya) && (await hd.locator('.ct-ia-pills .ct-conf').textContent()) === '92 % de confianza' &&
      (await hd.locator('.ct-ia-pills .ct-conf').getAttribute('class')).includes(' ok') && (await hd.locator('[data-flag="pide_obra"]').textContent()) === 'Pide obra' && /Propuso claude-opus-5-5/.test(suya) &&
      (await hd.locator('[data-ia-obra] option').count()) === 3, suya.slice(0, 300));
    ok('IA · con la obra sin elegir el botón lo dice: «✓ Así es (elige antes la obra)», y «No es eso» al lado', (await hd.locator('[data-ia-asi]').textContent()) === '✓ Así es (elige antes la obra)' && (await hd.locator('[data-ia-no]').count()) === 1);
    n0 = llamadas.length;
    await hd.locator('[data-ia-asi]').click(); await q.waitForTimeout(150);
    ok('IA · «Así es» sin obra no llama: pide la obra en la tarjeta', !desde(n0).some(l => l.fn === 'contador:aprobar') && /Elige antes la obra/.test(await texto(q, `.ct-mov[data-id="${MI.hd}"] .ct-ia-res`)));
    await hd.locator('[data-ia-obra]').selectOption('casa-perez-k3m9');
    ok('IA · elegida la obra, el botón dice «✓ Así es · Casa Pérez»', (await hd.locator('[data-ia-asi]').textContent()) === '✓ Así es · Casa Pérez');
    await foto(q, 'ia-1-bandeja-propuesta');
    await sinToast(); await hd.locator('[data-ia-asi]').click();
    const ta = await tostada(/Así es/); await pintado(q);
    const apr = ultima(n0, 'contador:aprobar');
    ok('IA · «Así es» llama a aprobar {accion, propuesta, recordar: true, proyecto_id} con la sesión', !!apr && JSON.stringify(apr.args) === JSON.stringify({ accion: 'aprobar', propuesta: PR.hd, recordar: true, proyecto_id: 'casa-perez-k3m9' }) && /^Bearer /.test(apr.auth), JSON.stringify(apr && apr.args));
    ok('IA · …avisa «Así es: en el libro · asiento … · regla nueva «THE HOME DEPOT»» y el movimiento sale de la bandeja', /^Así es: en el libro · asiento 2026-000801 · regla nueva «THE HOME DEPOT»$/.test(ta.trim()) && (await movQ(MI.hd).count()) === 0 && (await q.locator('.ct-mov').count()) === 7, ta);
    // Amazon: confianza ámbar, los flags, las alternativas y «No es eso»
    const amz = await fila(q, MI.amz);
    ok('IA · Amazon: «55 % de confianza» en ámbar, «¿Activo fijo?» y «¿Use tax?» (con su explicación al pasar), y las otras posibilidades (1510, 6500)',
      (await amz.locator('.ct-ia-pills .ct-conf').getAttribute('class')).includes(' warn') && (await amz.locator('[data-flag="capitalizable"]').textContent()) === '¿Activo fijo?' && (await amz.locator('[data-flag="use_tax"]').textContent()) === '¿Use tax?' &&
      /2,500/.test(await amz.locator('[data-flag="capitalizable"]').getAttribute('title')) && /Otras posibilidades: 1510 .* · 6500/.test(await amz.locator('.ct-ia-alt').textContent()) && (await amz.locator('[data-ia-asi]').textContent()) === '✓ Así es');
    const nfx = await fila(q, MI.nfx);
    ok('IA · Netflix: «35 % de confianza» en gris y el chip «Personal»; el IRS, «IRS» y 97 % en verde', !/ (ok|warn)\b/.test(await nfx.locator('.ct-ia-pills .ct-conf').getAttribute('class')) && (await nfx.locator('[data-flag="personal"]').textContent()) === 'Personal' &&
      (await (await fila(q, MI.irs)).locator('[data-flag="irs"]').textContent()) === 'IRS' && (await movQ(MI.irs).locator('.ct-conf').getAttribute('class')).includes(' ok'));
    await fila(q, MI.amz); n0 = llamadas.length;
    await sinToast(); await movQ(MI.amz).locator('[data-ia-no]').click();
    const tr = await tostada(/rechazada/); await pintado(q);
    const rec = ultima(n0, 'contador:rechazar');
    const foco = await q.evaluate(id => { const a = document.activeElement; return !!a && a.matches('[data-ia-cuenta]') && !!a.closest(`.ct-mov[data-id="${id}"]`); }, MI.amz);
    ok('IA · «No es eso» llama a rechazar {accion, propuesta, motivo} y avisa; el movimiento sigue (desplegado), su chip dice «sin propuesta», «Según la IA» dice que la rechazaste y el foco queda en la cuenta de «Según yo»',
      !!rec && rec.args.accion === 'rechazar' && rec.args.propuesta === PR.amz && /No es eso/.test(rec.args.motivo) && /Propuesta rechazada/.test(tr) && (await movQ(MI.amz).count()) === 1 &&
      (await movQ(MI.amz).getAttribute('class')).includes('abierta') && (await chip(MI.amz)) === 'sin propuesta' && /Rechazaste la propuesta \(6400 Herramienta menor y uniformes\)/.test(await movQ(MI.amz).locator('.ct-ia-suya').textContent()) && foco,
      JSON.stringify(rec && rec.args) + ' foco=' + foco);
    // «Según yo»: las cuentas de v_contador_cuentas por grupos, el buscador, la obra según la cuenta, el motivo y «Recordar»
    const yo = movQ(MI.amz).locator('.ct-ia-mia');
    const grupos = await yo.locator('[data-ia-cuenta] optgroup').evaluateAll(gs => gs.map(g => g.label));
    const codigos = await yo.locator('[data-ia-cuenta] option').evaluateAll(os => os.map(o => o.value).filter(Boolean));
    ok('IA · «Según yo» ofrece SOLO las cuentas de v_contador_cuentas (15), agrupadas por tipo con <optgroup> (costo, gastos, otros gastos, activo, pasivo, capital), sin bancos, tarjetas ni sueldos',
      JSON.stringify(grupos) === '["Costo de obra","Gastos","Otros gastos","Activo","Pasivo","Capital"]' && codigos.length === 15 && codigos.every(c => CUENTAS_IA.some(x => x.codigo === c)) && !codigos.some(c => /^10|^2100|^6000$/.test(c)), JSON.stringify(grupos) + ' ' + codigos.join(','));
    await yo.locator('[data-ia-cuenta]').selectOption('5100');
    ok('IA · con una cuenta que pide obra (5100) la obra se vuelve obligatoria y lo dice', (await yo.locator('[data-ia-obra-et]').textContent()) === 'Obra (esta cuenta la pide)' && !(await yo.locator('[data-ia-obra-yo]').isDisabled()));
    n0 = llamadas.length;
    await yo.locator('[data-ia-clasificar]').click(); await q.waitForTimeout(150);
    ok('IA · «Clasificar» a 5100 sin obra no llama y lo dice', !desde(n0).some(l => l.fn === 'contador:clasificar') && /pide la obra/.test(await texto(q, `.ct-mov[data-id="${MI.amz}"] .ct-ia-res`)));
    await yo.locator('[data-ia-buscar]').fill('oficina');
    ok('IA · el buscador acota la lista («oficina» → solo 6500) y, si queda una, la elige; con 6500 (no lleva obra) la obra se apaga', JSON.stringify(await yo.locator('[data-ia-cuenta] option').evaluateAll(os => os.map(o => o.value).filter(Boolean))) === '["6500"]' &&
      (await yo.locator('[data-ia-cuenta]').inputValue()) === '6500' && await yo.locator('[data-ia-obra-yo]').isDisabled() && (await yo.locator('[data-ia-obra-et]').textContent()) === 'Obra (esta cuenta no lleva obra)');
    await yo.locator('textarea[name="ia_motivo"]').fill('Laptop de la oficina');
    ok('IA · «Recordar para este comercio» viene marcada', await yo.locator('input[name="ia_recordar"]').isChecked());
    await yo.locator('input[name="ia_recordar"]').uncheck();
    await foto(q, 'ia-2-segun-yo');
    await sinToast(); await yo.locator('[data-ia-clasificar]').click();
    const tc = await tostada(/Clasificado/); await pintado(q);
    const cla = ultima(n0, 'contador:clasificar');
    ok('IA · «Clasificar» manda {accion, movimiento, lineas: [{cuenta, proyecto_id}], motivo, recordar} con la sesión (sin recordar: false; sin obra: null) y el movimiento sale de la bandeja',
      !!cla && JSON.stringify(cla.args) === JSON.stringify({ accion: 'clasificar', movimiento: MI.amz, lineas: [{ cuenta: '6500', proyecto_id: null }], motivo: 'Laptop de la oficina', recordar: false }) && /^Bearer /.test(cla.auth) &&
      /^Clasificado · asiento 2026-000802$/.test(tc.trim()) && (await movQ(MI.amz).count()) === 0, JSON.stringify(cla && cla.args) + ' | ' + tc);
    // el IRS: lo mismo que la IA → «Clasificar (igual que la IA)»; con recordar y sin motivo
    const irs = await fila(q, MI.irs), yoI = irs.locator('.ct-ia-mia');
    await yoI.locator('[data-ia-cuenta]').selectOption('3200');
    const igual = (await yoI.locator('[data-ia-clasificar]').textContent()).trim();
    await yoI.locator('[data-ia-cuenta]').selectOption('6600');
    const distinto = (await yoI.locator('[data-ia-clasificar]').textContent()).trim();
    ok('IA · si lo elegido coincide con la propuesta, el botón dice «Clasificar (igual que la IA)»; si no, «Clasificar»', igual === 'Clasificar (igual que la IA)' && distinto === 'Clasificar', igual + ' | ' + distinto);
    await yoI.locator('[data-ia-cuenta]').selectOption('3200');
    n0 = llamadas.length;
    await sinToast(); await yoI.locator('[data-ia-clasificar]').click();
    const ti = await tostada(/Clasificado/); await pintado(q);
    const claI = ultima(n0, 'contador:clasificar');
    ok('IA · …y manda {lineas: [{cuenta: 3200, proyecto_id: null}], motivo: null, recordar: true}; la base la deja «aprobada» y el aviso dice «Clasificado (igual que la IA)» con la regla nueva',
      !!claI && JSON.stringify(claI.args) === JSON.stringify({ accion: 'clasificar', movimiento: MI.irs, lineas: [{ cuenta: '3200', proyecto_id: null }], motivo: null, recordar: true }) && /^Clasificado \(igual que la IA\) · asiento 2026-000803 · regla nueva «IRS USATAXPYMT»$/.test(ti.trim()), ti);
    // Netflix: Edgar dice otra cosa → «editada»
    const nf = await fila(q, MI.nfx);
    await nf.locator('.ct-ia-mia [data-ia-cuenta]').selectOption('6500');
    await sinToast(); await nf.locator('.ct-ia-mia [data-ia-clasificar]').click();
    const tn = await tostada(/cambiaste/); await pintado(q);
    ok('IA · con líneas distintas de la propuesta la base la deja «editada» y el aviso lo dice', /^Clasificado \(cambiaste la propuesta\) · asiento 2026-000804/.test(tn.trim()) && IA.props.find(x => x.propuesta_id === PR.nfx).estado === 'editada', tn);
    // un error de la función (409 MX008) sale en ámbar en la tarjeta y los botones vuelven
    const ww = await fila(q, MI.wawa);
    ok('IA · la propuesta de una regla dice «Regla: WAWA» y «100 % de confianza»; su cuenta (6300) es de obra prohibida en el plan, así que no trae selector de obra ni pistas, y «✓ Así es» tal cual',
      /Regla: WAWA/.test(await ww.locator('.ct-ia-fuente').textContent()) && (await ww.locator('.ct-conf').textContent()) === '100 % de confianza' && (await ww.locator('[data-ia-obra]').count()) === 0 &&
      (await ww.locator('.ct-ia-obra-sel').count()) === 0 && (await ww.locator('.ct-ia-pistas').count()) === 0 && (await ww.locator('[data-ia-asi]').textContent()) === '✓ Así es');
    estado.iaFalla = { estado: 409, cuerpo: { codigo: 'MX008', error: 'Ese movimiento ya está casado con otro asiento: deshazlo antes con fn_banco_descasar (prueba).' } };
    await ww.locator('[data-ia-asi]').click();
    await q.waitForSelector(`.ct-mov[data-id="${MI.wawa}"] .ct-ia-res .ct-aviso.warn`, { timeout: 8000 }).catch(() => {});
    ok('IA · un 409 MX008 de la función sale en ámbar con su mensaje, en la tarjeta, y «Así es» vuelve a poderse tocar', /ya está casado con otro asiento/.test(await texto(q, `.ct-mov[data-id="${MI.wawa}"] .ct-ia-res .ct-aviso.warn`)) && !(await ww.locator('[data-ia-asi]').isDisabled()) && (await movQ(MI.wawa).count()) === 1);
    // el tope, la función sin desplegar, la llave que falta
    IA.gasto = 3000;
    await irA('bandeja');
    ok('IA · con el tope del contador alcanzado: «este mes $30.00 de $30.00», el botón apagado y por qué', /este mes \$30\.00 de \$30\.00/.test(await q.locator('#ct-ia-cifras').textContent()) && await q.locator('#ct-ia-proponer').isDisabled() && /La IA contable llegó a su tope del mes \(\$30\.00\)/.test(await texto(q, '.ct-ia-freno')));
    n0 = llamadas.length;
    await q.locator('#ct-ia-proponer').click({ force: true }).catch(() => {}); await q.waitForTimeout(200);
    ok('IA · …y tocarlo no llama a la función', !desde(n0).some(l => l.fn === 'contador:proponer'));
    IA.gasto = 432;
    estado.iaSinFuncion = true;
    await irA('bandeja');
    ok('IA · si la función «contador» no contesta (sin desplegar), el botón se apaga y lo dice', await q.locator('#ct-ia-proponer').isDisabled() && /La función «contador» no contestó/.test(await texto(q, '.ct-ia-freno')));
    estado.iaSinFuncion = false; estado.iaSinLlave = true;
    await irA('bandeja');
    ok('IA · si la salud dice que falta la llave, el botón se apaga y dice dónde ponerla (ANTHROPIC_API_KEY)', await q.locator('#ct-ia-proponer').isDisabled() && /ANTHROPIC_API_KEY/.test(await texto(q, '.ct-ia-freno.bad')));
    estado.iaSinLlave = false;
    // la falla ruidosa de la IA: un cuadre en rojo o un conteo distinto y no se pinta nada de ella (la bandeja sigue)
    estado.iaCuadreMal = true;
    await irA('bandeja');
    ok('IA · un cuadre de la IA en rojo (61): la franja en rojo «no se pinta ninguna propuesta» con el detalle, sin chips ni columnas; la bandeja sigue con «Otra cosa…»',
      /La IA contable no cuadra: no se pinta ninguna propuesta/.test(await texto(q, '#ct-ia-franja')) && /2026-000777/.test(await texto(q, '#ct-ia-franja')) && (await q.locator('.ct-ia-chip, .ct-ia').count()) === 0 &&
      (await q.locator('#ct-ia-proponer').count()) === 0 && (await q.locator('.ct-mov').count()) === 4 && (await q.locator('.ct-mov [data-otra]').count()) === 4 && (await q.locator('.ct-rojo').count()) === 0);
    await foto(q, 'ia-3-no-cuadra');
    estado.iaCuadreMal = false; estado.iaConteo = true;
    await irA('bandeja');
    ok('IA · si v_contador_bandeja trae otro número de filas que el que contó el control: también rojo, «la pantalla trajo … y el control contó 99»', /la pantalla trajo \d+ fila\(s\) y el control contó 99/.test(await texto(q, '#ct-ia-franja')) && (await q.locator('.ct-ia-chip').count()) === 0);
    estado.iaConteo = false;
    // Conexiones y seguridad: la tarjeta de la IA, «Probar» y las reglas con «Quitar»
    n0 = llamadas.length; l0 = lecturas.length;
    await irA('conexiones');
    const tIA = await texto(q, '#ct-ia');
    ok('IA · Conexiones: la tarjeta «IA contable (fase 7)» dice «conectada» y «cuadra», la llave puesta, el modelo (claude-opus-5-5, esfuerzo low), el gasto del mes con los dos topes y la última ráfaga; leyó v_contador_reglas',
      /conectada/.test(await texto(q, '#ct-ia .ct-cab')) && /cuadra/.test(await texto(q, '#ct-ia .ct-cab')) && /Llave de Anthropic: puesta/.test(tIA) && /Modelo: claude-opus-5-5 \(esfuerzo low\)/.test(tIA) &&
      /la IA contable lleva \$4\.32 de \$30\.00; toda la IA de la app, \$12\.42 de \$100\.00/.test(tIA) && /Última ráfaga: \d+ \w+ 2026 \d\d:\d\d/.test(tIA) && lecturas.slice(l0).some(l => /^v_contador_reglas\?/.test(l)) && /IA contable con 5 reglas/.test(await texto(q, '.ct-pag-sub')) &&
      !/no cuadra/.test(await texto(q, '#ct-ia .ct-cab')), tIA.slice(0, 400));
    const reglasTxt = (await q.locator('#ct-ia .ct-ia-regla').allTextContents()).map(x => x.replace(/\s+/g, ' ').trim());
    ok('IA · las reglas: el comercio → sus cuentas, cuántas veces y la última, cada una con «Quitar» (las dos de antes y las tres que nacieron hoy con «Recordar»: THE HOME DEPOT, IRS y NETFLIX; Amazon no, que iba sin recordar)',
      reglasTxt.length === 5 && reglasTxt.some(x => /WAWA → 6300 Vehículos — combustible y mantenimiento.*12 veces · la última el 28 oct 2026/.test(x)) && reglasTxt.some(x => /THE HOME DEPOT → 5100 Material.*pide obra/.test(x)) && reglasTxt.some(x => /IRS USATAXPYMT → 3200/.test(x)) &&
      !reglasTxt.some(x => /AMAZON/.test(x)) && (await q.locator('#ct-ia .ct-ia-regla [data-quitar]').count()) === 5, reglasTxt.join(' | '));
    n0 = llamadas.length;
    await q.locator('#ct-ia-probar').click();
    await q.waitForSelector('#ct-ia > .ct-ia-res .ct-aviso.ok', { timeout: 8000 }).catch(() => {});
    ok('IA · «Probar» pide la salud a la función con la sesión y enseña «La función «contador» contesta: tiene la llave y llega a la base»', desde(n0).some(l => l.fn === 'contador:salud' && /^Bearer /.test(l.auth)) && /La función «contador» contesta: tiene la llave y llega a la base/.test(await texto(q, '#ct-ia > .ct-ia-res')));
    const shell = q.locator(`#ct-ia .ct-ia-regla[data-regla="${RG.shell}"]`);
    n0 = llamadas.length;
    await shell.locator('[data-quitar]').click();
    await shell.locator('button[type=submit]').click(); await q.waitForTimeout(150);
    ok('IA · «Quitar» pide el motivo y sin él no llama', /Falta motivo/.test(await texto(q, `#ct-ia .ct-ia-regla[data-regla="${RG.shell}"] .ct-error`)) && !desde(n0).some(l => l.fn === 'contador:regla_baja'));
    await shell.locator('textarea[name="motivo"]').fill('Ya no cargamos en Shell con la tarjeta de la empresa');
    await foto(q, 'ia-4-conexiones-quitar');
    await sinToast(); await shell.locator('button[type=submit]').click();
    const tq = await tostada(/quitada/); await pintado(q);
    const rb = ultima(n0, 'contador:regla_baja');
    ok('IA · …con motivo llama a regla_baja {accion, regla, motivo} y la tarjeta se repinta sin ella («1 regla dada de baja»)', !!rb && JSON.stringify(rb.args) === JSON.stringify({ accion: 'regla_baja', regla: RG.shell, motivo: 'Ya no cargamos en Shell con la tarjeta de la empresa' }) &&
      /Regla «SHELL OIL» quitada/.test(tq) && (await q.locator(`#ct-ia .ct-ia-regla[data-regla="${RG.shell}"]`).count()) === 0 && /1 regla dada de baja/.test(await texto(q, '#ct-ia')), JSON.stringify(rb && rb.args));
    // «Qué atender» en el Resumen: las alarmas y los cuadres de la IA
    estado.iaVieja = true; IA.gasto = 3000;
    await irA('resumen');
    const atnIA = await q.locator('#ct-atender .ct-atn').allTextContents();
    ok('IA · «Qué atender» lista las alarmas de v_contador_control en llano con su detalle: la propuesta de más de 7 días (→ Bandeja) y el tope del mes (→ Conexiones)',
      atnIA.some(x => /Propuestas de la IA que esperan más de 7 días.*IRS USATAXPYMT/.test(x)) && atnIA.some(x => /llegó al tope de gasto del mes.*el contador \$30\.00 \(su tope, \$30\.00\)/.test(x)) &&
      (await q.locator('#ct-atender .ct-atn', { hasText: 'más de 7 días' }).locator('button[data-ir="bandeja"]').count()) === 1 && (await q.locator('#ct-atender .ct-atn', { hasText: 'tope de gasto' }).locator('button[data-ir="conexiones"]').count()) === 1, atnIA.join(' | '));
    estado.iaVieja = false; IA.gasto = 432; estado.iaCuadreMal = true;
    await irA('resumen');
    ok('IA · …y un cuadre de la IA en rojo: «La IA contable no cuadra (…): la Bandeja no pinta sus propuestas»', (await q.locator('#ct-atender .ct-atn').allTextContents()).some(x => /La IA contable no cuadra \(ningún asiento con «Propuesta de la IA #».*\): la Bandeja no pinta sus propuestas/.test(x)));
    estado.iaCuadreMal = false;
    const guardadoIA = await q.evaluate(() => { const t = []; for (const st of [localStorage, sessionStorage]) for (let i = 0; i < st.length; i++) t.push(st.key(i) + '=' + st.getItem(st.key(i))); return t.join('\n'); });
    ok('IA · nada de la IA se guarda en el teléfono (ni propuestas, ni reglas, ni el gasto)', !/v_contador|bbbbbbbb-0000|THE HOME DEPOT|USATAXPYMT|claude-opus/.test(guardadoIA));
    await cx.close();

    // el teléfono (390 px) y el iPad (820 px): las dos columnas, una debajo de otra en el teléfono y lado a lado en el iPad; nada se sale de la pantalla
    for (const w of [390, 820]) {
      const tc2 = await b.newContext({ viewport: { width: w, height: w < 700 ? 844 : 1100 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, serviceWorkers: 'block' });
      await simular(tc2, 'dueno');
      const t2 = await tc2.newPage(); t2.on('pageerror', e => errs.push(`IA ${w}: ` + String(e).slice(0, 160)));
      await t2.goto('http://localhost:8873/index.html'); await t2.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await t2.waitForTimeout(800);
      await t2.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
      await t2.locator('#btn-conta').evaluate(x => x.click()); await t2.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 });
      await t2.evaluate(() => window.MXP_CONTA.ir('bandeja')); await pintado(t2);
      const fe = await fila(t2, MOV.a); await t2.waitForTimeout(300);
      const med = await t2.evaluate(() => {
        const c = document.querySelector('.ct-mov.abierta'), a = c.querySelector('.ct-ia-suya').getBoundingClientRect(), y = c.querySelector('.ct-ia-mia').getBoundingClientRect();
        const btn = document.getElementById('ct-ia-proponer').getBoundingClientRect(), fr = document.getElementById('ct-ia-franja').getBoundingClientRect();
        const fuera = [...document.querySelectorAll('#conta-raiz *')].filter(e => e.getBoundingClientRect().right > window.innerWidth + 1 && getComputedStyle(e).position !== 'fixed' && !e.closest('.ct-tabs')).map(e => e.className || e.tagName).slice(0, 5);
        const chipsFuera = [...document.querySelectorAll('.ct-ia-chip')].filter(e => e.getBoundingClientRect().right > e.closest('.ct-mov').getBoundingClientRect().right + 1).length;
        return { sw: document.documentElement.scrollWidth, iw: window.innerWidth, debajo: y.top >= a.bottom - 1, lado: Math.abs(a.top - y.top) < 2 && a.right <= y.left, fuera, chipsFuera, btnAncho: Math.round(btn.width), frAncho: Math.round(fr.width) };
      });
      if (w === 390) ok('IA · teléfono (390 px): «Según yo» va debajo de «Según la IA», «Proponer ahora» va entero a lo ancho de la franja, ningún chip se sale de su fila y la página no desplaza de lado',
        med.sw <= med.iw + 1 && med.debajo && med.fuera.length === 0 && med.chipsFuera === 0 && med.btnAncho >= med.frAncho - 60, JSON.stringify(med));
      else ok('IA · iPad (820 px): las dos columnas van lado a lado y nada se sale de la pantalla', med.sw <= med.iw + 1 && med.lado && med.fuera.length === 0 && med.chipsFuera === 0, JSON.stringify(med));
      await foto(t2, `ia-5-${w}-bandeja-propuesta`);
      if (w === 390) {
        await t2.evaluate(() => window.MXP_CONTA.ir('conexiones')); await pintado(t2);
        await t2.locator('#ct-ia').scrollIntoViewIfNeeded();
        const cxm = await t2.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: window.innerWidth, der: document.querySelector('#ct-ia').getBoundingClientRect().right }));
        ok('IA · teléfono: la tarjeta de la IA en Conexiones cabe y la página no desplaza de lado', cxm.sw <= cxm.iw + 1 && cxm.der <= cxm.iw, JSON.stringify(cxm));
        await foto(t2, 'ia-6-390-conexiones');
      }
      await tc2.close();
    }

    // sin el código del teléfono (aal1): se ve todo, no se toca nada, y ni se le pregunta la salud a la función
    estado.mfaFactores = []; estado.sesionAal = undefined;
    const sc = await b.newContext({ viewport: { width: 1280, height: 900 }, serviceWorkers: 'block' });
    await simular(sc, 'dueno');
    const s2 = await sc.newPage(); s2.on('pageerror', e => errs.push('IA sin código: ' + String(e).slice(0, 160)));
    await s2.goto('http://localhost:8873/index.html'); await s2.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await s2.waitForTimeout(800);
    await s2.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
    await s2.locator('#btn-conta').evaluate(x => x.click()); await s2.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 });
    n0 = llamadas.length;
    await s2.evaluate(() => window.MXP_CONTA.ir('bandeja')); await pintado(s2);
    const fs2 = await fila(s2, MOV.a);
    ok('IA · sin el código del teléfono: la franja y las propuestas se ven, pero «Proponer», «Así es», «No es eso» y «Clasificar» van apagados con «Primero activa el código del teléfono», y no se llamó a la función',
      await s2.locator('#ct-ia-proponer').isDisabled() && /Primero activa el código del teléfono/.test(await texto(s2, '.ct-ia-freno')) && await fs2.locator('[data-ia-asi]').isDisabled() && await fs2.locator('[data-ia-no]').isDisabled() &&
      await fs2.locator('[data-ia-clasificar]').isDisabled() && /Primero activa el código del teléfono/.test(await fs2.locator('.ct-ia-sin').textContent()) && !desde(n0).some(l => /^contador:/.test(l.fn)) && !(await fs2.locator('[data-otra]').isDisabled()));
    await sc.close();
    estado.c8 = false; iaReset();
  }

  // ---- La obra que propone la IA (c8, fase 7b): las pistas las calcula la base, la IA propone la obra y Edgar la confirma o la cambia ----
  {
    estado.c8 = true; iaReset(true);
    estado.mfaFactores = [{ id: 'f-1', friendly_name: 'Teléfono de Edgar', factor_type: 'totp', status: 'verified' }]; estado.sesionAal = 'aal2';
    const abrir = async (w, alto) => {
      const cx = await b.newContext({ viewport: { width: w, height: alto }, deviceScaleFactor: w < 1024 ? 2 : 1, isMobile: w < 1024, hasTouch: w < 1024, serviceWorkers: 'block' });
      await simular(cx, 'dueno');
      const q = await cx.newPage(); q.on('pageerror', e => errs.push(`IA 7b ${w}: ` + String(e).slice(0, 160)));
      await q.goto('http://localhost:8873/index.html'); await q.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await q.waitForTimeout(800);
      await q.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
      await q.locator('#btn-conta').evaluate(x => x.click()); await q.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 });
      await q.evaluate(() => window.MXP_CONTA.ir('bandeja')); await pintado(q);
      return [cx, q];
    };
    const [cx, q] = await abrir(1280, 900);
    const sinToast = () => q.evaluate(() => { const t = document.getElementById('toast'); if (t) t.textContent = ''; });
    const tostada = async re => { await q.waitForFunction(r => { const t = document.getElementById('toast'); return t && !t.hidden && new RegExp(r).test(t.textContent); }, re.source, { timeout: 8000 }).catch(() => {}); return (await q.locator('#toast').textContent()) || ''; };
    const movQ = id => q.locator(`.ct-mov[data-id="${id}"]`);
    const ultima = (n0, fn) => desde(n0).filter(l => l.fn === fn).slice(-1)[0];
    const chip = async id => (await movQ(id).locator('.ct-f-motivo .ct-ia-chip').count()) ? (await movQ(id).locator('.ct-f-motivo .ct-ia-chip').textContent()).trim() : null;
    const cifras = async () => (await q.locator('#ct-ia-cifras').textContent()).trim();
    const valores = async (c, sel) => c.locator(`${sel} option`).evaluateAll(os => os.map(o => o.value));
    let n0 = llamadas.length;
    // la franja y los chips
    ok('IA 7b · la franja dice «9 propuestas listas (3 con obra) · 1 por proponer · …» (propuestas_con_obra de v_contador_estado)', /^9 propuestas listas \(3 con obra\) · 1 por proponer · este mes \$4\.20 de \$30\.00$/.test(await cifras()), await cifras());
    const chips = { ces: await chip(MI.ces), fyd: await chip(MI.fyd), ced: await chip(MI.ced), low: await chip(MI.low), hd: await chip(MI.hd) };
    ok('IA 7b · el chip lleva la obra entre la cuenta y la confianza: «IA · 5100 Material · Calla Terrace · 85 %»; por regla, «Regla · LOWE S · Casa Pérez»; sin obra propuesta, como antes',
      chips.ces === 'IA · 5100 Material · Calla Terrace · 85 %' && chips.fyd === 'IA · 5100 Material · Ampliación Residencia Villanueva-Echeverría · 74 %' && chips.low === 'Regla · LOWE S · Casa Pérez' &&
      chips.ced === 'IA · 5100 Material · ¿obra? · 70 %' && chips.hd === 'IA · 5100 Material · ¿obra? · 92 %', JSON.stringify(chips));
    const chipPc = await q.evaluate(([ia, regla]) => {
      const r = e => e.getBoundingClientRect();
      const nat = el => { const s = el.cloneNode(true); s.style.cssText = 'position:absolute;visibility:hidden;white-space:pre;max-width:none;min-width:0;width:auto;flex:none;overflow:visible'; el.parentNode.appendChild(s); const x = s.getBoundingClientRect().width; s.remove(); return x; };
      const medir = id => {
        const ch = document.querySelector(`.ct-mov[data-id="${id}"] .ct-ia-chip.con-obra`), [c, o, p] = ['.ct-ia-chip-q', '.ct-ia-chip-o', '.ct-ia-chip-p'].map(s => ch.querySelector(s));
        return { obraAbajo: r(o).top >= r(c).bottom - 1, pArriba: !p || Math.abs(r(p).top - r(c).top) < 2, enteros: [c, o, p].filter(Boolean).map(el => r(el).width + 0.25 >= nat(el)),
          sep: getComputedStyle(o.querySelector('.ct-ia-sep')).display, dentro: r(ch).right <= r(ch.closest('.ct-f-motivo')).right + 1 };
      };
      return { ia: medir(ia), regla: medir(regla) };
    }, [MI.ces, MI.low]);
    const bienPc = m => m.obraAbajo && m.pArriba && m.enteros.every(Boolean) && m.sep === 'none' && m.dentro;
    ok('IA 7b · computadora: en la columna «Motivo» la obra baja a su renglón dentro del chip («IA · 5100 Material · 85 %» arriba, «Calla Terrace» debajo, sin el «·»; y «Regla · LOWE S» sobre «Casa Pérez»), todo entero y dentro de la columna',
      bienPc(chipPc.ia) && bienPc(chipPc.regla), JSON.stringify(chipPc));
    ok('IA 7b · el chip dice al pasar por encima la obra con su confianza y su porqué', /Obra: Calla Terrace \(86 %\): Edgar eligió Calla Terrace 2 veces con CES/.test(await movQ(MI.ces).locator('.ct-ia-chip').getAttribute('title')));
    // CES: «Según la IA» con la obra
    const ces = await fila(q, MI.ces), suya = ces.locator('.ct-ia-suya');
    const tSuya = (await suya.textContent()).replace(/\s+/g, ' ');
    ok('IA 7b · «Según la IA» trae la obra FUERTE «Obra: Calla Terrace · 86 %» (en verde) y debajo su porqué en llano (las pistas que citó), sin «falta la obra» ni «Pide obra» y sin repetir la obra en la línea',
      (await suya.locator('.ct-ia-obra-t').textContent()).replace(/\s+/g, ' ').trim() === 'Obra: Calla Terrace · 86 %' &&
      (await suya.locator('.ct-ia-obra-m').textContent()).trim() === 'Edgar eligió Calla Terrace 2 veces con CES; la cuadrilla reportó 24 h allí esos días.' &&
      !/falta la obra|obra: Calla/.test(await suya.locator('.ct-ia-lineas').textContent()) && (await suya.locator('[data-flag="pide_obra"]').count()) === 0 && (await suya.locator('.ct-ia-pistas').count()) === 0 &&
      (await suya.locator('.ct-ia-obra-p').getAttribute('class')).includes(' ok'), tSuya.slice(0, 400));
    ok('IA 7b · el selector de la obra sale elegido con la propuesta, con la etiqueta «¿De qué obra? (la IA propone Calla Terrace)», sin opción vacía, y «✓ Así es · Calla Terrace»; la nota de «editada», escondida',
      (await ces.locator('[data-ia-obra]').inputValue()) === 'calla-terrace-8h2v' && /^¿De qué obra\? \(la IA propone Calla Terrace\)/.test(await ces.locator('.ct-ia-obra-sel').textContent()) &&
      JSON.stringify(await valores(ces, '[data-ia-obra]')) === JSON.stringify(['villanueva-amp-4r7t', 'calla-terrace-8h2v', 'casa-perez-k3m9', 'oficina-nch-7xq2']) &&
      (await ces.locator('[data-ia-asi]').textContent()) === '✓ Así es · Calla Terrace' && await ces.locator('[data-ia-obra-cambio]').isHidden() && /la obra no/.test(await ces.locator('.ct-ia-pie').textContent()),
      JSON.stringify(await valores(ces, '[data-ia-obra]')));
    // «Según yo»: la obra propuesta queda elegida en cuanto la cuenta la admite (y no si es de obra prohibida), mientras Edgar no la toque
    const yo = ces.locator('.ct-ia-mia'), cuentaYo = yo.locator('[data-ia-cuenta]'), obraYo = yo.locator('[data-ia-obra-yo]');
    const antes = await obraYo.inputValue();
    await cuentaYo.selectOption('5100');
    const con5100 = { obra: await obraYo.inputValue(), btn: (await yo.locator('[data-ia-clasificar]').textContent()).trim() };
    await cuentaYo.selectOption('6500');
    const con6500 = { obra: await obraYo.inputValue(), apagada: await obraYo.isDisabled() };
    await cuentaYo.selectOption('1420');
    const con1420 = await obraYo.inputValue();
    await obraYo.selectOption('oficina-nch-7xq2'); await cuentaYo.selectOption('5100');
    const tocada = await obraYo.inputValue();
    ok('IA 7b · «Según yo»: sin cuenta, sin obra; con 5100 la obra de la IA queda elegida («Clasificar (igual que la IA)»); con 6500 (prohibida) se apaga; con 1420 (opcional) vuelve; si Edgar la cambia, se respeta',
      antes === '' && con5100.obra === 'calla-terrace-8h2v' && con5100.btn === 'Clasificar (igual que la IA)' && con6500.obra === '' && con6500.apagada && con1420 === 'calla-terrace-8h2v' && tocada === 'oficina-nch-7xq2',
      JSON.stringify({ antes, con5100, con6500, con1420, tocada }));
    await foto(q, 'ia7b-1-1280-obra-propuesta');
    // «Así es» con la obra propuesta → aprobada
    n0 = llamadas.length;
    await sinToast(); await ces.locator('[data-ia-asi]').click();
    const tCes = await tostada(/Así es/); await pintado(q);
    const aCes = ultima(n0, 'contador:aprobar');
    ok('IA 7b · «✓ Así es · Calla Terrace» manda aprobar con el proyecto_id propuesto {accion, propuesta, recordar, proyecto_id: calla-terrace} y la base la deja «aprobada»',
      !!aCes && JSON.stringify(aCes.args) === JSON.stringify({ accion: 'aprobar', propuesta: PR.ces, recordar: true, proyecto_id: 'calla-terrace-8h2v' }) && /^Bearer /.test(aCes.auth) &&
      /^Así es: en el libro · asiento 2026-000801 · regla nueva «CES»$/.test(tCes.trim()) && IA.props.find(x => x.propuesta_id === PR.ces).estado === 'aprobada' && (await movQ(MI.ces).count()) === 0, JSON.stringify(aCes && aCes.args) + ' | ' + tCes);
    ok('IA 7b · …la regla que aprende es de la cuenta, sin la obra (la próxima vez la dicen las pistas)', JSON.stringify((IA.reglas.find(r => r.nombre === 'CES') || {}).lineas) === '[{"cuenta":"5100"}]');
    // Floor & Decor: Edgar cambia la obra → manda la suya y queda «editada»
    const fyd = await fila(q, MI.fyd);
    await fyd.locator('[data-ia-obra]').selectOption('casa-perez-k3m9');
    ok('IA 7b · cambiar la obra cambia el botón («✓ Así es · Casa Pérez») y enseña «Con otra obra entra la tuya y la propuesta queda «editada»»',
      (await fyd.locator('[data-ia-asi]').textContent()) === '✓ Así es · Casa Pérez' && await fyd.locator('[data-ia-obra-cambio]').isVisible() && /queda «editada»/.test(await fyd.locator('[data-ia-obra-cambio]').textContent()));
    await fyd.locator('[data-ia-obra]').selectOption('villanueva-amp-4r7t');
    const devuelta = { btn: await fyd.locator('[data-ia-asi]').textContent(), nota: await fyd.locator('[data-ia-obra-cambio]').isHidden() };
    await fyd.locator('[data-ia-obra]').selectOption('casa-perez-k3m9');
    n0 = llamadas.length;
    await sinToast(); await fyd.locator('[data-ia-asi]').click();
    const tFyd = await tostada(/Así es/); await pintado(q);
    const aFyd = ultima(n0, 'contador:aprobar');
    ok('IA 7b · …volver a la propuesta esconde la nota; con otra obra «Así es» manda la de Edgar (proyecto_id: casa-perez), la base la deja «editada» y el aviso dice «Así es, con tu obra»',
      devuelta.btn === '✓ Así es · Ampliación Residencia Villanueva-Echeverría' && devuelta.nota && !!aFyd && JSON.stringify(aFyd.args) === JSON.stringify({ accion: 'aprobar', propuesta: PR.fyd, recordar: true, proyecto_id: 'casa-perez-k3m9' }) &&
      /^Así es, con tu obra: en el libro · asiento 2026-000802/.test(tFyd.trim()) && IA.props.find(x => x.propuesta_id === PR.fyd).estado === 'editada', JSON.stringify(aFyd && aFyd.args) + ' | ' + tFyd);
    // CED: pide obra y las pistas no apuntan a una sola → el resumen de las pistas en gris; Home Depot: «sin pistas»
    const ced = await fila(q, MI.ced);
    ok('IA 7b · sin obra propuesta y con pistas: «Pistas: Calla Terrace: 12 h esos días… · Casa Pérez: 10 h…» en gris, «Pide obra», el selector vacío «Elige la obra…» con «(la cuenta la pide)» y «✓ Así es (elige antes la obra)»',
      /^Pistas: Calla Terrace: 12 h esos días, 12 h en 30 días · Casa Pérez: 10 h esos días, 10 h en 30 días$/.test((await ced.locator('.ct-ia-pistas').textContent()).trim()) && (await ced.locator('.ct-ia-obra').count()) === 0 &&
      (await ced.locator('[data-flag="pide_obra"]').count()) === 1 && (await ced.locator('[data-ia-obra]').inputValue()) === '' && (await ced.locator('[data-ia-obra] option').first().textContent()) === 'Elige la obra…' &&
      /^¿De qué obra\? \(la cuenta la pide\)/.test(await ced.locator('.ct-ia-obra-sel').textContent()) && (await ced.locator('[data-ia-asi]').textContent()) === '✓ Así es (elige antes la obra)');
    n0 = llamadas.length;
    await ced.locator('[data-ia-asi]').click(); await q.waitForTimeout(150);
    ok('IA 7b · …y «Así es» sin obra no llama: pide la obra', !desde(n0).some(l => l.fn === 'contador:aprobar') && /Elige antes la obra/.test(await texto(q, `.ct-mov[data-id="${MI.ced}"] .ct-ia-res`)));
    const hd = await fila(q, MI.hd);
    ok('IA 7b · y si la base no vio pistas, lo dice en llano: «Pistas: ninguna obra tiene horas de la cuadrilla, tickets de este comercio ni materiales…»', /^Pistas: ninguna obra tiene horas de la cuadrilla/.test((await hd.locator('.ct-ia-pistas').textContent()).trim()));
    // Lowe's: por regla, con la obra de sus pistas
    const low = await fila(q, MI.low);
    ok('IA 7b · una propuesta por regla trae la obra (fuerte) de sus pistas: «Regla: LOWE S», «Obra: Casa Pérez · 80 %» con el porqué en mayúscula, el selector en Casa Pérez y «✓ Así es · Casa Pérez»',
      /Regla: LOWE S/.test(await low.locator('.ct-ia-fuente').textContent()) && (await low.locator('.ct-ia-obra-t').textContent()).replace(/\s+/g, ' ').trim() === 'Obra: Casa Pérez · 80 %' &&
      /^Elegida 2 veces por Edgar con LOWE S; la cuadrilla reportó 16 h en Casa Pérez/.test((await low.locator('.ct-ia-obra-m').textContent()).trim()) && (await low.locator('[data-ia-obra]').inputValue()) === 'casa-perez-k3m9' &&
      (await low.locator('[data-ia-asi]').textContent()) === '✓ Así es · Casa Pérez');
    n0 = llamadas.length;
    await sinToast(); await low.locator('[data-ia-asi]').click();
    const tLow = await tostada(/Así es/); await pintado(q);
    const aLow = ultima(n0, 'contador:aprobar');
    ok('IA 7b · …«Así es» manda la obra de la regla y queda «aprobada»', !!aLow && aLow.args.proyecto_id === 'casa-perez-k3m9' && /^Así es: en el libro/.test(tLow.trim()) && IA.props.find(x => x.propuesta_id === PR.low).estado === 'aprobada', tLow);
    // «Proponer ahora»: la ráfaga dice cuántas traen obra
    n0 = llamadas.length;
    await sinToast(); await q.locator('#ct-ia-proponer').click();
    const tPro = await tostada(/propuesta/); await pintado(q);
    ok('IA 7b · la ráfaga avisa «1 propuesta (1 con obra) · …» (con_obra de la función) y la ferretería sale con «IA · 5100 Material · Casa Pérez · 81 %»; la franja, «7 propuestas listas (1 con obra)»',
      /^1 propuesta \(1 con obra\) · 0 por regla · 0 sin respuesta · \$0\.12$/.test(tPro.trim()) && (await chip(MOV.a)) === 'IA · 5100 Material · Casa Pérez · 81 %' && /^7 propuestas listas \(1 con obra\) · 0 por proponer/.test(await cifras()), tPro + ' | ' + await cifras());
    // una obra que se cerró después de proponerla (el cuadre 64): la IA se sigue viendo, la propuesta lo dice y «Así es» pide otra
    const pfe = IA.props.find(x => x.propuesta_id === PR.fe);
    Object.assign(pfe, { lineas: [linIA('5100', { proyecto_id: 'taller-ruiz-5b2n' })], ...obraIA('taller-ruiz-5b2n', 0.8, 'La cuadrilla reportó 16 h en Taller Ruiz esos días.', 'Taller Ruiz: 16 h esos días') });
    await q.evaluate(() => window.MXP_CONTA.ir('bandeja')); await pintado(q);
    const fe = await fila(q, MOV.a);
    ok('IA 7b · cuadre 64 en rojo: la IA NO se tapa (chips y columnas siguen), la franja avisa «1 propuesta trae una obra que ya no está activa…» y el chip va sin la obra, con «¿obra?»',
      (await q.locator('#ct-ia-franja.mal').count()) === 0 && (await q.locator('.ct-ia').count()) > 0 && /^1 propuesta trae una obra que ya no está activa/.test(await texto(q, '#ct-ia-cerradas')) && (await chip(MOV.a)) === 'IA · 5100 Material · ¿obra? · 81 %',
      await texto(q, '#ct-ia-franja'));
    ok('IA 7b · …la propuesta dice «Ya no está activa (completado)», el selector sale vacío «Elige otra obra…» con su porqué en la etiqueta, y «Según yo» no la preselecciona',
      /Ya no está activa \(completado\)/.test(await fe.locator('.ct-ia-obra.cerrada').textContent()) && (await fe.locator('[data-ia-obra]').inputValue()) === '' && (await fe.locator('[data-ia-obra] option').first().textContent()) === 'Elige otra obra…' &&
      !(await valores(fe, '[data-ia-obra]')).includes('taller-ruiz-5b2n') && /la que propuso la IA, Taller Ruiz, ya no está activa/.test(await fe.locator('.ct-ia-obra-sel').textContent()) &&
      (await fe.locator('[data-ia-asi]').textContent()) === '✓ Así es (elige antes la obra)' && await (async () => { await fe.locator('.ct-ia-mia [data-ia-cuenta]').selectOption('5100'); return (await fe.locator('.ct-ia-mia [data-ia-obra-yo]').inputValue()) === ''; })());
    n0 = llamadas.length;
    await fe.locator('[data-ia-asi]').click(); await q.waitForTimeout(150);
    ok('IA 7b · …«Así es» sin elegir otra no llama y lo dice («Elige otra obra: la que propuso la IA (Taller Ruiz) ya no está activa»)', !desde(n0).some(l => l.fn === 'contador:aprobar') && /Elige otra obra: la que propuso la IA \(Taller Ruiz\) ya no está activa/.test(await texto(q, `.ct-mov[data-id="${MOV.a}"] .ct-ia-res`)));
    await foto(q, 'ia7b-2-1280-obra-cerrada');
    await fe.locator('[data-ia-obra]').selectOption('oficina-nch-7xq2');
    await sinToast(); await fe.locator('[data-ia-asi]').click();
    const tFe = await tostada(/Así es/); await pintado(q);
    ok('IA 7b · …eligiendo otra, manda la de Edgar (proyecto_id: oficina-nch) y queda «editada»; el aviso de la franja se va', (ultima(n0, 'contador:aprobar') || { args: {} }).args.proyecto_id === 'oficina-nch-7xq2' && pfe.estado === 'editada' &&
      /^Así es, con tu obra/.test(tFe.trim()) && (await q.locator('#ct-ia-cerradas').count()) === 0, tFe);
    // «Qué atender» con el 64 en rojo: va a la Bandeja y dice qué hacer (no «no cuadra»)
    const pced = IA.props.find(x => x.propuesta_id === PR.ced);
    Object.assign(pced, { lineas: [linIA('5100', { proyecto_id: 'taller-ruiz-5b2n' })], pide_obra: false, flags: { obra_propuesta: true }, ...obraIA('taller-ruiz-5b2n', 0.7, 'La cuadrilla reportó 12 h en Taller Ruiz esos días.', 'Taller Ruiz: 12 h esos días') });
    await q.evaluate(() => window.MXP_CONTA.ir('resumen')); await pintado(q);
    const atn = await q.locator('#ct-atender .ct-atn').allTextContents();
    ok('IA 7b · «Qué atender»: «1 propuesta de la IA trae una obra que ya no está activa: en la Bandeja, elige otra obra al aprobarla…» con su detalle y el botón a la Bandeja (no «no cuadra»)',
      atn.some(x => /^1 propuesta de la IA trae una obra que ya no está activa: en la Bandeja, elige otra obra al aprobarla o di «No es eso»\..*Taller Ruiz/.test(x)) && !atn.some(x => /La IA contable no cuadra/.test(x)) &&
      (await q.locator('#ct-atender .ct-atn', { hasText: 'ya no está activa' }).locator('button[data-ir="bandeja"]').count()) === 1, atn.join(' | '));
    // Conexiones: cuántas esperan con obra
    await q.evaluate(() => window.MXP_CONTA.ir('conexiones')); await pintado(q);
    ok('IA 7b · Conexiones dice cuántas propuestas esperan con obra, explica las pistas (las reglas no guardan la obra) y, con el 64 en rojo, «cuadra» con la pastilla «1 obra propuesta cerrada»',
      /Propuestas: \d+ esperan en la bandeja \(\d+ con obra\)/.test(await texto(q, '#ct-ia .ct-datos')) && /Las reglas recuerdan la cuenta, nunca la obra/.test(await texto(q, '#ct-ia .ct-ayuda')) &&
      /conectada.*cuadra/.test(await texto(q, '#ct-ia .ct-cab')) && !/no cuadra/.test(await texto(q, '#ct-ia .ct-cab')) && /1 obra propuesta cerrada/.test(await texto(q, '#ct-ia .ct-cab')), await texto(q, '#ct-ia .ct-cab'));
    await cx.close();

    // el teléfono (390) y el iPad (820): el corte del chip (la obra con «…», nunca el porcentaje) y la propuesta con obra desplegada
    iaReset(true);
    for (const w of [390, 820]) {
      const [tcx, t] = await abrir(w, w < 700 ? 844 : 1100);
      const med = await t.evaluate(ids => {
        const r = e => e.getBoundingClientRect(), dentro = (a, b) => r(a).right <= r(b).right + 1 && r(a).left >= r(b).left - 1;
        const chipDe = id => document.querySelector(`.ct-mov[data-id="${id}"] .ct-ia-chip.ia`);
        const largo = chipDe(ids.fyd), corto = chipDe(ids.ces);
        const o = largo.querySelector('.ct-ia-chip-o'), p = largo.querySelector('.ct-ia-chip-p'), c = largo.querySelector('.ct-ia-chip-q');
        // «entero»: la caja le da al menos lo que mide su texto entero (una copia sin tope en el mismo chip); scrollWidth redondea
        // y no ve un recorte de una fracción de píxel, que ya pinta «…»
        const nat = el => { const s = el.cloneNode(true); s.style.cssText = 'position:absolute;visibility:hidden;white-space:pre;max-width:none;min-width:0;width:auto;flex:none;overflow:visible'; el.parentNode.appendChild(s); const x = s.getBoundingClientRect().width; s.remove(); return x; };
        const entero = el => r(el).width + 0.25 >= nat(el);
        return { sw: document.documentElement.scrollWidth, iw: window.innerWidth,
          chipDentro: dentro(largo, largo.closest('.ct-mov')) && dentro(corto, corto.closest('.ct-mov')),
          obraCortada: !entero(o), elipsis: getComputedStyle(o).textOverflow, pEntera: entero(p) && dentro(p, largo) && p.textContent === ' · 74 %',
          cuentaEntera: entero(c), cortoEntero: [...corto.children].every(entero) };
      }, { fyd: MI.fyd, ces: MI.ces });
      const ces2 = await fila(t, MI.ces); await t.waitForTimeout(300);
      const det = await t.evaluate(() => {
        const c = document.querySelector('.ct-mov.abierta'), a = c.querySelector('.ct-ia-suya').getBoundingClientRect(), y = c.querySelector('.ct-ia-mia').getBoundingClientRect();
        const fuera = [...document.querySelectorAll('#conta-raiz *')].filter(e => e.getBoundingClientRect().right > window.innerWidth + 1 && getComputedStyle(e).position !== 'fixed' && !e.closest('.ct-tabs')).map(e => e.className || e.tagName).slice(0, 5);
        const ob = c.querySelector('.ct-ia-obra').getBoundingClientRect();
        return { sw: document.documentElement.scrollWidth, iw: window.innerWidth, debajo: y.top >= a.bottom - 1, lado: Math.abs(a.top - y.top) < 2 && a.right <= y.left, fuera, obraDentro: ob.right <= a.right + 1 && ob.left >= a.left - 1 };
      });
      if (w === 390) {
        ok('IA 7b · teléfono (390 px): en el chip largo la obra se corta con «…» y el porcentaje se ve entero («· 74 %»); la cuenta no se corta; el chip corto (CES) entero; nada se sale de su fila',
          med.sw <= med.iw + 1 && med.chipDentro && med.obraCortada && med.elipsis === 'ellipsis' && med.pEntera && med.cuentaEntera && med.cortoEntero, JSON.stringify(med));
        ok('IA 7b · teléfono: la propuesta con obra desplegada cabe («Según yo» debajo, la línea de la obra dentro de su columna) y la página no desplaza de lado',
          det.sw <= det.iw + 1 && det.debajo && det.fuera.length === 0 && det.obraDentro && (await ces2.locator('[data-ia-obra]').inputValue()) === 'calla-terrace-8h2v', JSON.stringify(det));
      } else ok('IA 7b · iPad (820 px): las dos columnas lado a lado con la obra dentro, el chip dentro de su fila y nada se sale de la pantalla', det.sw <= det.iw + 1 && det.lado && det.fuera.length === 0 && det.obraDentro && med.chipDentro && med.pEntera, JSON.stringify({ det, med }));
      await foto(t, `ia7b-3-${w}-obra-propuesta`);
      await tcx.close();
    }
    estado.c8 = false; estado.mfaFactores = []; estado.sesionAal = undefined; iaReset();
  }

  // ---- La 7c (31-oct, tarde): las propuestas salen solas, la obra calibrada se elige de un toque, el marcador y la rutina ----
  {
    estado.c8 = true; iaReset(true, true); IA.cadena(59);
    // sin preferencia guardada: «Proponer sola al abrir la Bandeja» viene encendido
    estado.iaSolaPref = 'quitar'; estado.iaFallas = []; estado.iaVueloMax = 0;
    estado.mfaFactores = [{ id: 'f-1', friendly_name: 'Teléfono de Edgar', factor_type: 'totp', status: 'verified' }]; estado.sesionAal = 'aal2';
    const abrir = async (w, alto) => {
      const cx = await b.newContext({ viewport: { width: w, height: alto }, deviceScaleFactor: w < 1024 ? 2 : 1, isMobile: w < 1024, hasTouch: w < 1024, serviceWorkers: 'block' });
      await simular(cx, 'dueno');
      const q = await cx.newPage(); q.on('pageerror', e => errs.push(`IA 7c ${w}: ` + String(e).slice(0, 160)));
      await q.goto('http://localhost:8873/index.html'); await q.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await q.waitForTimeout(800);
      await q.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
      await q.locator('#btn-conta').evaluate(x => x.click()); await q.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 });
      // el avance de la cadena tal como lo fue enseñando la franja (cada texto distinto, en orden)
      await q.evaluate(() => { window.__av = []; setInterval(() => { const t = document.querySelector('#ct-ia-cadena .ct-ia-avance'), x = t && t.textContent.trim(); if (x && window.__av[window.__av.length - 1] !== x) window.__av.push(x); }, 30); });
      return [cx, q];
    };
    const [cx, q] = await abrir(1280, 900);
    const irA = async k => { await q.evaluate(k => window.MXP_CONTA.ir(k), k); await pintado(q); };
    const sinToast = () => q.evaluate(() => { const t = document.getElementById('toast'); if (t) t.textContent = ''; });
    const tostada = async re => { await q.waitForFunction(r => { const t = document.getElementById('toast'); return t && !t.hidden && new RegExp(r).test(t.textContent); }, re.source, { timeout: 15000 }).catch(() => {}); return (await q.locator('#toast').textContent()) || ''; };
    const movQ = id => q.locator(`.ct-mov[data-id="${id}"]`);
    const ultima = (n0, fn) => desde(n0).filter(l => l.fn === fn).slice(-1)[0];
    const chip = async id => (await movQ(id).locator('.ct-f-motivo .ct-ia-chip').count()) ? (await movQ(id).locator('.ct-f-motivo .ct-ia-chip').textContent()).trim() : null;
    const cifras = async () => (await q.locator('#ct-ia-cifras').textContent()).trim();
    const proponeres = n0 => desde(n0).filter(l => l.fn === 'contador:proponer');
    const finCadena = async (pg, ms) => { await pg.waitForFunction(() => !(window.MXP_CONTA._estado.cadena && window.MXP_CONTA._estado.cadena.activa), null, { timeout: ms || 15000 }).catch(() => {}); await pintado(pg); };
    const avance = async pg => ((await pg.locator('#ct-ia-cadena .ct-ia-avance').count()) ? (await pg.locator('#ct-ia-cadena .ct-ia-avance').textContent()) : '').trim();
    const resFranja = async () => (await texto(q, '#ct-ia-franja > .ct-ia-res')).replace(/\s+/g, ' ').trim();
    // lo que la automática recuerda (qué esperaba al terminar la última cadena) vive en la memoria de la página, como al abrir la
    // app otra vez: las escenas que vuelven a sembrar los mismos cargos lo olvidan para empezar de cero
    const olvidar = () => q.evaluate(() => { window.MXP_CONTA._estado.iaSola.memo = null; window.MXP_CONTA._estado.iaSola.parada = false; });
    const MX008 = { estado: 409, cuerpo: { codigo: 'MX008', error: 'Ya hay una ráfaga en marcha (la abrió Edgar Prueba hace 12 s): espera a que termine y vuelve a mirar la bandeja. Si la función se cortó, la base la da por perdida a los 5 minutos.' } };
    // 1. al abrir la Bandeja la IA propone SOLA: tres ráfagas (la función dice quedan 40 → 20 → 0) sin que Edgar toque nada
    estado.iaLento = 600; let n0 = llamadas.length;
    await sinToast();
    await q.evaluate(() => window.MXP_CONTA.ir('bandeja'));
    await q.waitForFunction(() => /^Proponiendo… 20 de 60/.test(((document.querySelector('#ct-ia-cadena .ct-ia-avance') || {}).textContent || '').trim()), null, { timeout: 8000 }).catch(() => {});
    const aMedias = await q.evaluate(() => { const bt = document.getElementById('ct-ia-proponer');
      return { ia: document.querySelectorAll('.ct-mov .ct-ia-chip.ia, .ct-mov .ct-ia-chip.regla').length, nada: document.querySelectorAll('.ct-mov .ct-ia-chip.nada').length,
        gira: !!bt && bt.disabled && bt.getAttribute('aria-busy') === 'true' && /^Proponer ahora/.test(bt.textContent) && document.querySelector('#ct-ia-cadena .ct-ia-avance').classList.contains('ct-espera'), parar: !!document.getElementById('ct-ia-parar') }; });
    await foto(q, 'ia7c-1-1280-proponiendo-sola');
    // volver a pintar la Bandeja con la cadena en marcha (y tocar «Proponer ahora», apagado) no arranca otra
    await q.evaluate(() => window.MXP_CONTA.ir('bandeja'));
    await q.locator('#ct-ia-proponer').click({ force: true, timeout: 2000 }).catch(() => {});
    const conAvance = (await q.locator('#ct-ia-cadena').count()) === 1;
    const tFin = await tostada(/ráfagas/);
    await finCadena(q);
    const pr1 = proponeres(n0), av1 = await q.evaluate(() => window.__av.slice());
    ok('IA 7c · al abrir la Bandeja la IA propone SOLA, sin tocar nada: tres «proponer» seguidas ({accion: proponer}, con la sesión) mientras la función dice que quedan (40 → 20 → 0), y nunca dos a la vez aunque se vuelva a pintar la Bandeja a media cadena',
      pr1.length === 3 && pr1.every(l => JSON.stringify(l.args) === '{"accion":"proponer"}' && /^Bearer /.test(l.auth)) && estado.iaVueloMax === 1 && conAvance, `${pr1.length} · en vuelo ${estado.iaVueloMax} · ${conAvance}`);
    const iAv = s => av1.indexOf(s);
    ok('IA 7c · la franja fue enseñando el avance «Proponiendo… 0 de 60 · $0.00» → «20 de 60 · $0.12» → «40 de 60 · $0.24» (girando) con «Parar», y «Proponer ahora» apagado mientras tanto',
      iAv('Proponiendo… 0 de 60 · $0.00') >= 0 && iAv('Proponiendo… 0 de 60 · $0.00') < iAv('Proponiendo… 20 de 60 · $0.12') && iAv('Proponiendo… 20 de 60 · $0.12') < iAv('Proponiendo… 40 de 60 · $0.24') && aMedias.gira && aMedias.parar,
      JSON.stringify(av1) + ' ' + JSON.stringify(aMedias));
    ok('IA 7c · cada ráfaga repinta las filas: tras la primera ya hay 30 filas con su propuesta y 40 «sin propuesta»; al terminar, ninguna sin propuesta',
      aMedias.ia === 30 && aMedias.nada === 40 && (await q.locator('.ct-mov .ct-ia-chip.nada').count()) === 0 && (await q.locator('.ct-mov .ct-ia-chip.ia').count()) >= 60, JSON.stringify(aMedias));
    ok('IA 7c · al terminar avisa «3 ráfagas: 60 propuestas (40 con obra) · 0 por regla · 0 sin respuesta · $0.36», la franja dice «Listo: 60 propuestas (40 con obra) · $0.36.» y «0 por proponer»',
      /^3 ráfagas: 60 propuestas \(40 con obra\) · 0 por regla · 0 sin respuesta · \$0\.36$/.test(tFin.trim()) && (await resFranja()) === 'Listo: 60 propuestas (40 con obra) · $0.36.' &&
      /^70 propuestas listas \(44 con obra\) · 0 por proponer · este mes \$4\.56 de \$30\.00$/.test(await cifras()) && (await q.locator('#ct-ia-cadena').count()) === 0, tFin + ' | ' + await resFranja() + ' | ' + await cifras());
    // 2. «Parar»: la ráfaga en vuelo termina (lo suyo se guarda) y no se pide otra; la Bandeja no vuelve a arrancar sola; «Proponer ahora» sí
    iaReset(true, true); IA.cadena(59); estado.iaLento = 900; n0 = llamadas.length;
    await sinToast();
    await q.evaluate(() => window.MXP_CONTA.ir('bandeja'));
    await q.waitForSelector('#ct-ia-parar', { timeout: 8000 }).catch(() => {});
    await q.locator('#ct-ia-parar').click();
    const parando = await avance(q);
    const tPar = await tostada(/Paraste/);
    await finCadena(q);
    ok('IA 7c · «Parar» corta la cadena: la franja dice «Parando: termina la ráfaga que ya está en marcha…», la que estaba en vuelo termina (20 propuestas) y no se pide otra; aviso y franja dicen que la paraste',
      proponeres(n0).length === 1 && /^Parando: termina la ráfaga que ya está en marcha/.test(parando) && /^Paraste la IA: 20 propuestas/.test(tPar.trim()) &&
      /^Paraste la IA \(dejó 20 propuestas .*\): no vuelve a proponer sola hasta que abras la app otra vez o toques «Proponer ahora»\.$/.test(await resFranja()) && /· 40 por proponer ·/.test(await cifras()), parando + ' | ' + tPar + ' | ' + await resFranja());
    n0 = llamadas.length;
    await irA('bandeja');
    ok('IA 7c · …volver a la Bandeja no la arranca otra vez sola (ni una «proponer»), y «Proponer ahora (40)» se puede tocar', proponeres(n0).length === 0 && (await q.locator('#ct-ia-proponer').textContent()) === 'Proponer ahora (40)' && !(await q.locator('#ct-ia-proponer').isDisabled()));
    estado.iaLento = 0;
    await sinToast(); await q.locator('#ct-ia-proponer').click();
    await tostada(/ráfagas/); await finCadena(q);
    ok('IA 7c · …«Proponer ahora» la sigue a mano hasta el final: dos ráfagas más (quedan 20 → 0) y «0 por proponer»', proponeres(n0).length === 2 && /· 0 por proponer ·/.test(await cifras()), `${proponeres(n0).length} · ${await cifras()}`);
    // 3. el interruptor de Conexiones: encendido por defecto; apagado (localStorage «0»), la Bandeja no propone sola
    iaReset(true, true); IA.cadena(59);
    await irA('conexiones');
    const solaAntes = await q.locator('#ct-ia-sola').isChecked();
    await sinToast(); await q.locator('#ct-ia-sola').uncheck();
    const tSola = await tostada(/ya no propone sola/), pref = await q.evaluate(() => localStorage.getItem('mxp.contador.sola'));
    n0 = llamadas.length;
    await irA('bandeja');
    ok('IA 7c · Conexiones trae el interruptor «Proponer sola al abrir la Bandeja», encendido por defecto; apagado (queda «0» en este aparato) la Bandeja no propone sola: ni una «proponer», «Proponer ahora (60)» a mano y el pie de la franja lo dice',
      solaAntes && pref === '0' && /ya no propone sola/.test(tSola) && proponeres(n0).length === 0 && (await q.locator('#ct-ia-proponer').textContent()) === 'Proponer ahora (60)' && !(await q.locator('#ct-ia-proponer').isDisabled()) &&
      /no propone sola al abrir la Bandeja/.test(await texto(q, '#ct-ia-pie')), `${solaAntes} ${pref} ${tSola}`);
    await irA('conexiones'); await q.locator('#ct-ia-sola').check();
    // 4. con el tope del mes o el contador apagado, no arranca (ni una llamada) y la franja dice por qué
    IA.gasto = 3000; n0 = llamadas.length;
    await irA('bandeja');
    const frTope = await texto(q, '.ct-ia-freno');
    IA.gasto = 432; IA.apagado = true;
    await irA('bandeja');
    const frApagado = await texto(q, '.ct-ia-freno');
    ok('IA 7c · con el tope del contador o con el contador apagado (contador_config.activa = false) no arranca sola: ni una «proponer», y la franja dice por qué',
      proponeres(n0).length === 0 && /La IA contable llegó a su tope del mes/.test(frTope) && /El contador está apagado/.test(frApagado), frTope + ' | ' + frApagado);
    IA.apagado = false;
    // 5. MX008 «ráfaga en marcha» (la rutina de la mañana, otra pestaña): espera 5 s y reintenta UNA vez
    estado.iaFallas = [MX008]; n0 = llamadas.length;
    await sinToast();
    await q.evaluate(() => window.MXP_CONTA.ir('bandeja'));
    await q.waitForFunction(() => /Otra ráfaga está en marcha/.test(((document.querySelector('#ct-ia-cadena .ct-ia-avance') || {}).textContent || '')), null, { timeout: 5000 }).catch(() => {});
    const esperando = await avance(q), tEsp0 = Date.now();
    await q.waitForFunction(() => !/Otra ráfaga está en marcha/.test(((document.querySelector('#ct-ia-cadena .ct-ia-avance') || {}).textContent || '')), null, { timeout: 9000 }).catch(() => {});
    const espero = Date.now() - tEsp0;
    await finCadena(q, 20000);
    ok('IA 7c · un MX008 «ráfaga en marcha»: la franja dice «Otra ráfaga está en marcha (¿la rutina, otra pestaña?): espero 5 s…», reintenta UNA vez a los 5 s y sigue hasta el final (1 + 3 «proponer»)',
      /^Otra ráfaga está en marcha \(¿la rutina, otra pestaña\?\): espero 5 s y vuelvo a probar…$/.test(esperando) && espero >= 3500 && proponeres(n0).length === 4 && /· 0 por proponer ·/.test(await cifras()), `${esperando} · ${espero} ms · ${proponeres(n0).length}`);
    iaReset(true, true); IA.cadena(59); estado.iaFallas = [MX008, MX008]; await olvidar(); n0 = llamadas.length;
    await sinToast();
    await q.evaluate(() => window.MXP_CONTA.ir('bandeja'));
    const tMx = await tostada(/se paró/);
    await finCadena(q, 20000);
    ok('IA 7c · …si al reintentar sigue en marcha, la cadena se para sin insistir (2 «proponer») y lo dice en rojo en la franja y en el aviso, con el mensaje de la base',
      proponeres(n0).length === 2 && /^La IA se paró: Ya hay una ráfaga en marcha/.test(await resFranja()) && (await q.locator('#ct-ia-franja > .ct-ia-res .ct-aviso.bad').count()) === 1 &&
      /^La IA se paró: Ya hay una ráfaga en marcha/.test(tMx.trim()) && /error/.test(await q.locator('#toast').getAttribute('class')), await resFranja());
    // 6. un error de la función (Anthropic 529 dos veces) en la segunda ráfaga para la cadena; lo de la primera se queda
    await olvidar(); iaReset(true, true); IA.cadena(59); estado.iaFallas = [null, { estado: 502, cuerpo: { codigo: 'ANTHROPIC', error: 'Anthropic no contestó (529, dos veces) (prueba)' } }]; n0 = llamadas.length;
    await sinToast();
    await q.evaluate(() => window.MXP_CONTA.ir('bandeja'));
    const tErr = await tostada(/se paró/);
    await finCadena(q);
    ok('IA 7c · un error de la función para la cadena (2 «proponer»): la franja lo dice en rojo con lo que ya dejó («… Antes dejó 20 propuestas …») y quedan 40 por proponer',
      proponeres(n0).length === 2 && /^La IA se paró: Anthropic no contestó \(529, dos veces\) \(prueba\)\. Antes dejó 20 propuestas/.test(await resFranja()) && /error/.test(await q.locator('#toast').getAttribute('class')) &&
      /· 40 por proponer ·/.test(await cifras()), tErr + ' | ' + await resFranja());
    n0 = llamadas.length;
    await irA('bandeja');
    ok('IA 7c · …y la próxima pintada no insiste sola con los mismos 40 (ni una «proponer»): el aviso ya se dio y queda «Proponer ahora (40)»', proponeres(n0).length === 0 && (await q.locator('#ct-ia-proponer').textContent()) === 'Proponer ahora (40)' && (await resFranja()) === '');
    estado.iaFallas = [];
    // 6b. la IA no contesta ninguno (la función: sigue = false con quedan 60): una ráfaga, se para y no insiste
    await olvidar(); iaReset(true, true); IA.cadena(59); estado.iaNiega = true; n0 = llamadas.length;
    await sinToast();
    await q.evaluate(() => window.MXP_CONTA.ir('bandeja'));
    const tNiega = await tostada(/sin respuesta/);
    await finCadena(q);
    ok('IA 7c · si una ráfaga no deja ninguna propuesta (la función dice sigue: false con quedan 60), la cadena no insiste: una sola «proponer» (20 sin respuesta), y la franja dice que 60 siguen sin propuesta',
      proponeres(n0).length === 1 && /^0 propuestas · 0 por regla · 20 sin respuesta · \$0\.12$/.test(tNiega.trim()) &&
      /^Listo: 0 propuestas · \$0\.12\. 60 cargos siguen sin propuesta \(la IA no los contestó\): clasifícalos tú o vuelve a probar más tarde\.$/.test(await resFranja()) && (await q.locator('#ct-ia-franja > .ct-ia-res .ct-aviso.warn').count()) === 1,
      tNiega + ' | ' + await resFranja());
    n0 = llamadas.length;
    await irA('bandeja');
    ok('IA 7c · …y volver a la Bandeja tampoco los vuelve a pedir solos (ni una «proponer»); «Proponer ahora (60)» queda a mano', proponeres(n0).length === 0 && (await q.locator('#ct-ia-proponer').textContent()) === 'Proponer ahora (60)');
    estado.iaNiega = false;
    // 7. la obra en un toque: obras_top, «Otra obra…», la débil marcada y no elegida; con una fuerte, sin botones; el chip «¿obra?»
    iaReset(true, true); await olvidar(); n0 = llamadas.length;
    await irA('bandeja');
    ok('IA 7c · con un solo cargo esperando (la ferretería), una sola ráfaga (quedan 0) y sale con su obra fuerte en el chip', proponeres(n0).length === 1 && (await chip(MOV.a)) === 'IA · 5100 Material · Casa Pérez · 81 %', await chip(MOV.a));
    ok('IA 7c · el marcador del mes, al pie de la franja: «Este mes: cuenta 16 de 18 · obra 6 de 8 acertadas (2 elegiste tú)»', /^Este mes: cuenta 16 de 18 · obra 6 de 8 acertadas \(2 elegiste tú\) · /.test(await texto(q, '#ct-ia-pie')), await texto(q, '#ct-ia-pie'));
    const chips = { ces: await chip(MI.ces), ced: await chip(MI.ced), gb: await chip(MI.gb), low: await chip(MI.low) };
    const ambar = await q.evaluate(id => { const f = document.querySelector(`.ct-mov[data-id="${id}"] .ct-ia-chip-f`); const s = document.createElement('span'); s.style.color = 'var(--warn-ink)'; document.getElementById('conta-raiz').appendChild(s);
      const c = getComputedStyle(s).color; s.remove(); return !!f && getComputedStyle(f).color === c; }, MI.ced);
    ok('IA 7c · el chip de la fila: la obra solo si es fuerte («IA · 5100 Material · Calla Terrace · 85 %», «Regla · LOWE S · Casa Pérez»); sin obra o con una débil, «IA · 5100 Material · ¿obra? · 70 %» y «… · ¿obra? · 78 %», con el «¿obra?» en ámbar',
      chips.ces === 'IA · 5100 Material · Calla Terrace · 85 %' && chips.low === 'Regla · LOWE S · Casa Pérez' && chips.ced === 'IA · 5100 Material · ¿obra? · 70 %' && chips.gb === 'IA · 5100 Material · ¿obra? · 78 %' && ambar, JSON.stringify(chips) + ' ámbar=' + ambar);
    const chipF = await q.evaluate(id => {
      const r = e => e.getBoundingClientRect(), ch = document.querySelector(`.ct-mov[data-id="${id}"] .ct-ia-chip.falta`), [c, f, p] = ['.ct-ia-chip-q', '.ct-ia-chip-f', '.ct-ia-chip-p'].map(s => ch.querySelector(s));
      const nat = el => { const s = el.cloneNode(true); s.style.cssText = 'position:absolute;visibility:hidden;white-space:pre;max-width:none;min-width:0;width:auto;flex:none;overflow:visible'; el.parentNode.appendChild(s); const x = s.getBoundingClientRect().width; s.remove(); return x; };
      return { abajo: r(f).top >= r(c).bottom - 1, pArriba: Math.abs(r(p).top - r(c).top) < 2, enteros: [c, f, p].map(el => r(el).width + 0.25 >= nat(el)), dentro: r(ch).right <= r(ch.closest('.ct-f-motivo')).right + 1 };
    }, MI.hd);
    ok('IA 7c · computadora: en la columna «Motivo» el «¿obra?» baja a su renglón dentro del chip («IA · 5100 Material · 92 %» arriba, entera; «¿obra?» debajo), sin recortar la cuenta',
      chipF.abajo && chipF.pArriba && chipF.enteros.every(Boolean) && chipF.dentro, JSON.stringify(chipF));
    // CED: sin obra y la cuenta la pide → tres botones de sus pistas
    const ced = await fila(q, MI.ced);
    const opsDe = c => c.locator('[data-ia-obra-op]').evaluateAll(bs => bs.map(x => ({ id: x.dataset.iaObraOp, n: x.querySelector('.ct-ia-obra-op-n').textContent, p: (x.querySelector('.ct-ia-obra-op-p') || {}).textContent || '', ia: (x.querySelector('.ct-ia-obra-op-ia') || {}).textContent || '', on: x.getAttribute('aria-pressed') })));
    const opsCed = await opsDe(ced);
    ok('IA 7c · sin obra y la cuenta la pide (CED): «¿De qué obra?» con tres botones de sus pistas, cada uno con la obra y su pista en llano, más «Otra obra…»; nada elegido, el selector escondido, sin el resumen gris de las pistas, y «✓ Así es (elige antes la obra)»',
      JSON.stringify(opsCed) === JSON.stringify([{ id: 'calla-terrace-8h2v', n: 'Calla Terrace', p: '12 h esos días · 1 ticket de CED', ia: '', on: 'false' }, { id: 'casa-perez-k3m9', n: 'Casa Pérez', p: '10 h esos días', ia: '', on: 'false' }, { id: 'dicke-subpanel-9p4w', n: 'Dicke — Subpanel y EV', p: '3 materiales apuntados', ia: '', on: 'false' }]) &&
      (await ced.locator('[data-ia-obra-otra]').textContent()) === 'Otra obra…' && await ced.locator('.ct-ia-obra-sel').isHidden() && (await ced.locator('[data-ia-obra]').inputValue()) === '' && (await ced.locator('.ct-ia-pistas').count()) === 0 &&
      /^¿De qué obra\?la cuenta la pide: toca la que es$/.test((await ced.locator('.ct-ia-obra-q').textContent()).trim()) && (await ced.locator('[data-ia-asi]').textContent()) === '✓ Así es (elige antes la obra)', JSON.stringify(opsCed));
    await ced.locator('[data-ia-obra-op="casa-perez-k3m9"]').click();
    const unToque = { ops: (await opsDe(ced)).map(o => o.on).join(), sel: await ced.locator('[data-ia-obra]').inputValue(), asi: await ced.locator('[data-ia-asi]').textContent(), oculto: await ced.locator('.ct-ia-obra-sel').isHidden() };
    await ced.locator('[data-ia-obra-op="casa-perez-k3m9"]').click();
    const otroToque = { ops: (await opsDe(ced)).map(o => o.on).join(), sel: await ced.locator('[data-ia-obra]').inputValue(), asi: await ced.locator('[data-ia-asi]').textContent() };
    ok('IA 7c · un toque en «Casa Pérez» la elige (su botón marcado, el selector escondido toma el valor) y el botón dice «✓ Así es · Casa Pérez»; otro toque en la misma la suelta',
      unToque.ops === 'false,true,false' && unToque.sel === 'casa-perez-k3m9' && unToque.asi === '✓ Así es · Casa Pérez' && unToque.oculto && otroToque.ops === 'false,false,false' && otroToque.sel === '' && otroToque.asi === '✓ Así es (elige antes la obra)',
      JSON.stringify({ unToque, otroToque }));
    await ced.locator('[data-ia-obra-otra]').click();
    const nOpc = await ced.locator('[data-ia-obra] option').count();
    await ced.locator('[data-ia-obra]').selectOption('metro-clinic-2k8d');
    ok('IA 7c · «Otra obra…» despliega el selector de siempre (las 6 obras activas y «Elige la obra…»); una obra que no está en los botones: ninguno marcado y «✓ Así es · Metro Clinic»',
      await ced.locator('.ct-ia-obra-sel').isVisible() && (await ced.locator('[data-ia-obra-otra]').getAttribute('aria-expanded')) === 'true' && nOpc === 7 &&
      (await opsDe(ced)).every(o => o.on === 'false') && (await ced.locator('[data-ia-asi]').textContent()) === '✓ Así es · Metro Clinic', `${nOpc}`);
    await ced.locator('[data-ia-obra-op="calla-terrace-8h2v"]').click();
    n0 = llamadas.length;
    await sinToast(); await ced.locator('[data-ia-asi]').click();
    await tostada(/Así es/); await pintado(q);
    const aCed = ultima(n0, 'contador:aprobar');
    ok('IA 7c · «Así es» con el botón elegido manda aprobar {proyecto_id: calla-terrace}; sin obra propuesta y la cuenta la pedía, la base la deja «aprobada» y el marcador suma una obra que elegiste tú',
      !!aCed && JSON.stringify(aCed.args) === JSON.stringify({ accion: 'aprobar', propuesta: PR.ced, recordar: true, proyecto_id: 'calla-terrace-8h2v' }) && IA.props.find(x => x.propuesta_id === PR.ced).estado === 'aprobada' &&
      /^Este mes: cuenta 17 de 19 · obra 6 de 9 acertadas \(3 elegiste tú\)/.test(await texto(q, '#ct-ia-pie')), JSON.stringify(aCed && aCed.args) + ' | ' + await texto(q, '#ct-ia-pie'));
    // Graybar: la IA se inclina por Dicke con 60 % (débil): se dice, se marca y NO va elegida
    const gb = await fila(q, MI.gb), opsGb = await opsDe(gb);
    ok('IA 7c · obra débil (Graybar, 60 %): «La IA se inclina por Dicke — Subpanel y EV · 60 %, pero no está segura: elige tú.» con su porqué; su botón lleva «la IA se inclina por esta (60 %)» pero NO va elegido, y «✓ Así es (elige antes la obra)»',
      (await gb.locator('.ct-ia-obra.debil .ct-ia-obra-t').textContent()).replace(/\s+/g, ' ').trim() === 'La IA se inclina por Dicke — Subpanel y EV · 60 %, pero no está segura: elige tú.' &&
      /^La cuadrilla reportó 21 h en Dicke/.test((await gb.locator('.ct-ia-obra.debil .ct-ia-obra-m').textContent()).trim()) && opsGb.length === 3 && opsGb[0].id === 'dicke-subpanel-9p4w' && opsGb[0].ia === 'la IA se inclina por esta (60 %)' &&
      opsGb.every(o => o.on === 'false') && opsGb.slice(1).every(o => !o.ia) && (await gb.locator('[data-ia-obra-op].ia').count()) === 1 && (await gb.locator('[data-ia-obra]').inputValue()) === '' &&
      (await gb.locator('[data-ia-asi]').textContent()) === '✓ Así es (elige antes la obra)' && (await gb.locator('.ct-ia-obra-t').count()) === 1, JSON.stringify(opsGb));
    n0 = llamadas.length;
    await gb.locator('[data-ia-asi]').click(); await q.waitForTimeout(150);
    ok('IA 7c · …«Así es» sin elegir no llama y lo dice («Elige antes la obra: la IA se inclina por Dicke — Subpanel y EV (60 %), pero no está segura. Toca la que es.»)',
      !desde(n0).some(l => l.fn === 'contador:aprobar') && /^Elige antes la obra: la IA se inclina por Dicke — Subpanel y EV \(60 %\), pero no está segura\. Toca la que es\.$/.test((await texto(q, `.ct-mov[data-id="${MI.gb}"] .ct-ia-res`)).trim()));
    await gb.locator('[data-ia-obra-op="metro-clinic-2k8d"]').click();
    const conOtra = { asi: await gb.locator('[data-ia-asi]').textContent(), nota: await gb.locator('[data-ia-obra-cambio]').isVisible(), err: (await texto(q, `.ct-mov[data-id="${MI.gb}"] .ct-ia-res`)).trim() };
    await gb.locator('[data-ia-obra-op="dicke-subpanel-9p4w"]').click();
    const conLaSuya = { asi: await gb.locator('[data-ia-asi]').textContent(), nota: await gb.locator('[data-ia-obra-cambio]').isHidden() };
    ok('IA 7c · …tocar otra obra («Metro Clinic») avisa que la propuesta quedará «editada» (y el aviso de antes se va); tocar la de la IA lo esconde: «✓ Así es · Dicke — Subpanel y EV»',
      conOtra.asi === '✓ Así es · Metro Clinic' && conOtra.nota && conOtra.err === '' && conLaSuya.asi === '✓ Así es · Dicke — Subpanel y EV' && conLaSuya.nota, JSON.stringify({ conOtra, conLaSuya }));
    await foto(q, 'ia7c-2-1280-chips');
    n0 = llamadas.length;
    await sinToast(); await gb.locator('[data-ia-asi]').click();
    const tGb = await tostada(/Así es/); await pintado(q);
    const aGb = ultima(n0, 'contador:aprobar');
    ok('IA 7c · …«Así es» manda la obra elegida (la de la IA: «aprobada») y el marcador suma cuenta y obra acertadas: «Este mes: cuenta 18 de 20 · obra 7 de 10 acertadas (3 elegiste tú)»',
      !!aGb && aGb.args.proyecto_id === 'dicke-subpanel-9p4w' && /^Así es: en el libro/.test(tGb.trim()) && IA.props.find(x => x.propuesta_id === PR.gb).estado === 'aprobada' &&
      /^Este mes: cuenta 18 de 20 · obra 7 de 10 acertadas \(3 elegiste tú\)/.test(await texto(q, '#ct-ia-pie')), JSON.stringify(aGb && aGb.args) + ' | ' + await texto(q, '#ct-ia-pie'));
    // con obra FUERTE no hay botones: como la 7b
    const ces = await fila(q, MI.ces);
    ok('IA 7c · con obra FUERTE (CES, 86 %) no hay botones: «Obra: Calla Terrace · 86 %», el selector a la vista y elegido, «✓ Así es · Calla Terrace»',
      (await ces.locator('[data-ia-obra-elegir]').count()) === 0 && await ces.locator('.ct-ia-obra-sel').isVisible() && (await ces.locator('[data-ia-obra]').inputValue()) === 'calla-terrace-8h2v' &&
      (await ces.locator('.ct-ia-obra-t').textContent()).replace(/\s+/g, ' ').trim() === 'Obra: Calla Terrace · 86 %' && (await ces.locator('[data-ia-asi]').textContent()) === '✓ Así es · Calla Terrace');
    // Floor & Decor: la obra fuerte cambiada por Edgar → «editada»: el marcador la cuenta como obra corregida (la cuenta sí acertó)
    const fyd = await fila(q, MI.fyd);
    await fyd.locator('[data-ia-obra]').selectOption('casa-perez-k3m9');
    await sinToast(); await fyd.locator('[data-ia-asi]').click();
    await tostada(/Así es/); await pintado(q);
    ok('IA 7c · una obra fuerte que Edgar cambia queda «editada» y el marcador lo dice: «Este mes: cuenta 19 de 21 · obra 7 de 11 acertadas (1 corregiste, 3 elegiste tú)»',
      IA.props.find(x => x.propuesta_id === PR.fyd).estado === 'editada' && /^Este mes: cuenta 19 de 21 · obra 7 de 11 acertadas \(1 corregiste, 3 elegiste tú\)/.test(await texto(q, '#ct-ia-pie')), await texto(q, '#ct-ia-pie'));
    // «No es eso» no hace que la IA proponga otra al instante
    n0 = llamadas.length;
    const amz = await fila(q, MI.amz);
    await sinToast(); await amz.locator('[data-ia-no]').click();
    await tostada(/rechazada/); await pintado(q);
    ok('IA 7c · «No es eso» no hace que la IA proponga otra al instante: rechazada, la Bandeja se repinta y ni una «proponer» (lo dices tú en «Según yo»)',
      !!ultima(n0, 'contador:rechazar') && proponeres(n0).length === 0 && (await chip(MI.amz)) === 'sin propuesta' && /· 1 por proponer ·/.test(await cifras()), await cifras());
    // 8. la rutina: en el pie de la franja, en Conexiones y, si falla, en «Qué atender» (la 74)
    const MESES = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    const hmMiami = d => { const p = new Intl.DateTimeFormat('en-US', { timeZone: 'America/New_York', hour: 'numeric', minute: '2-digit', hourCycle: 'h23' }).formatToParts(d); const g = k => Number(p.find(x => x.type === k).value); return [g('hour'), g('minute')]; };
    const hm = ([h, m]) => `${h}:${String(m).padStart(2, '0')}`;
    const cuando = ts => { const d = new Date(ts), dia = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit' }).format(d);
      const dif = Math.round((Date.parse(HOY) - Date.parse(dia)) / 864e5), [, mm, dd] = dia.split('-').map(Number); return `${dif === 0 ? 'hoy' : dif === 1 ? 'ayer' : `${dd} ${MESES[mm]}`} ${hm(hmMiami(d))}`; };
    const utc = (h, m) => { const d = new Date(); d.setUTCHours(h, m, 0, 0); return hmMiami(d); };
    const [tH, tM] = utc(21, 0);
    const rutinaTxt = `Propone sola cada mañana tras el banco (${hm(utc(11, 25))}) y a las ${tH - 12}${tM ? ':' + String(tM).padStart(2, '0') : ''} de la tarde`;
    ok('IA 7c · el pie de la franja dice cómo va la rutina («la rutina: hoy H:MM, bien», en verde)', (await texto(q, '#ct-ia-pie')).endsWith(` · la rutina: ${cuando(IA.rutina.ultima)}, bien`) && (await q.locator('#ct-ia-pie .ct-ia-rut.ok').count()) === 1, await texto(q, '#ct-ia-pie'));
    await irA('conexiones');
    ok(`IA 7c · Conexiones: «${rutinaTxt} · última: … · bien» (las horas de Miami de hoy: pg_cron va en UTC), el marcador del mes y el interruptor encendido`,
      (await texto(q, '#ct-ia-rutina')).trim() === `${rutinaTxt} · última: ${cuando(IA.rutina.ultima)} · bien` && /^Este mes: cuenta 19 de 21 · obra 7 de 11 acertadas \(1 corregiste, 3 elegiste tú\)$/.test((await texto(q, '#ct-ia-marcador')).trim()) &&
      await q.locator('#ct-ia-sola').isChecked() && !/rutina con error/.test(await texto(q, '#ct-ia .ct-cab')), (await texto(q, '#ct-ia-rutina')).trim());
    await foto(q, 'ia7c-3-1280-conexiones');
    IA.rutina.error = 'Anthropic contestó 529 (prueba)';
    await irA('conexiones');
    ok('IA 7c · la rutina con error: Conexiones lo dice en rojo («… · con error: Anthropic contestó 529 (prueba)») con la pastilla «rutina con error»',
      (await q.locator('#ct-ia-rutina.bad-txt').count()) === 1 && (await texto(q, '#ct-ia-rutina')).trim() === `${rutinaTxt} · última: ${cuando(IA.rutina.ultima)} · con error: Anthropic contestó 529 (prueba)` && /rutina con error/.test(await texto(q, '#ct-ia .ct-cab')), await texto(q, '#ct-ia-rutina'));
    await irA('resumen');
    const atn74 = await q.locator('#ct-atender .ct-atn', { hasText: 'La rutina que propone sola' });
    ok('IA 7c · …y «Qué atender» la lista (la alarma 74) con el detalle de la base y el botón a Conexiones', (await atn74.count()) === 1 && /terminó con error: Anthropic contestó 529 \(prueba\)/.test(await atn74.textContent()) && (await atn74.locator('button[data-ir="conexiones"]').count()) === 1,
      (await q.locator('#ct-atender .ct-atn').allTextContents()).join(' | '));
    await irA('bandeja');
    ok('IA 7c · …y el pie de la franja también, en rojo («la rutina de hoy H:MM terminó con error (en Conexiones)»)', (await q.locator('#ct-ia-pie .ct-ia-rut.bad').count()) === 1 && (await texto(q, '#ct-ia-pie .ct-ia-rut.bad')) === `la rutina de ${cuando(IA.rutina.ultima)} terminó con error (en Conexiones)`, await texto(q, '#ct-ia-pie'));
    Object.assign(IA.rutina, { error: null, ultima: new Date(Date.now() - 40 * 3600e3).toISOString() });
    await irA('resumen');
    const atn74b = await q.locator('#ct-atender .ct-atn', { hasText: 'La rutina que propone sola' });
    const vieja74 = (await atn74b.count()) === 1 && /no corre desde el .* hace más de 36 horas/.test(await atn74b.textContent());
    await irA('conexiones');
    ok('IA 7c · más de 36 horas sin correr con cargos esperando: la 74 en «Qué atender» («no corre desde … hace más de 36 horas») y Conexiones «… · hace más de 36 horas: mira «Qué atender»» en ámbar',
      vieja74 && (await texto(q, '#ct-ia-rutina')).trim() === `${rutinaTxt} · última: ${cuando(IA.rutina.ultima)} · hace más de 36 horas: mira «Qué atender»` && (await q.locator('#ct-ia-rutina.warn').count()) === 1, await texto(q, '#ct-ia-rutina'));
    IA.rutina.ultima = new Date(Date.now() - 2 * 3600e3).toISOString();
    await irA('resumen');
    ok('IA 7c · …y cuando vuelve a correr bien, la 74 se va de «Qué atender»', (await q.locator('#ct-atender .ct-atn', { hasText: 'La rutina que propone sola' }).count()) === 0);
    // la función sin CONTADOR_RUTINA_SECRETO (salud.rutina false): Conexiones lo dice y dónde ponerlo; la Bandeja sigue proponiendo al abrirla
    estado.iaSinSecreto = true;
    await irA('conexiones');
    ok('IA 7c · si la salud dice que la función no tiene el secreto de la rutina (rutina: false), Conexiones avisa en ámbar dónde ponerlo (CONTADOR_RUTINA_SECRETO, el valor que enseña el pegado) y que la Bandeja sigue proponiendo al abrirla',
      (await q.locator('#ct-ia-sin-secreto.ct-aviso.warn').count()) === 1 && /CONTADOR_RUTINA_SECRETO/.test(await texto(q, '#ct-ia-sin-secreto')) && /contador_rutina_secreto/.test(await texto(q, '#ct-ia-sin-secreto')) && /la Bandeja sí propone al abrirla/.test(await texto(q, '#ct-ia-sin-secreto')),
      await texto(q, '#ct-ia'));
    estado.iaSinSecreto = false;
    await irA('conexiones');
    ok('IA 7c · …y con el secreto puesto (rutina: true) el aviso no está', (await q.locator('#ct-ia-sin-secreto').count()) === 0);
    // 9. después de «Sincronizar ahora» (Plaid) lo nuevo se propone solo, sin ir a la Bandeja (el aviso lo dice al terminar)
    iaReset(true, true); IA.cadena(59);
    await irA('conexiones');
    n0 = llamadas.length;
    await sinToast(); await q.locator('.ct-conexion [data-plaid="sincronizar"]').first().click();
    await tostada(/ráfagas/); await finCadena(q);
    ok('IA 7c · tras «Sincronizar ahora» de Plaid, lo que espera se propone solo desde Conexiones (sincronizar y luego 3 «proponer»), y el aviso lo cuenta al terminar',
      desde(n0).some(l => l.fn === 'plaid:sincronizar') && proponeres(n0).length === 3 && desde(n0).findIndex(l => l.fn === 'plaid:sincronizar') < desde(n0).findIndex(l => l.fn === 'contador:proponer') &&
      /^3 ráfagas: 60 propuestas/.test((await q.locator('#toast').textContent()).trim()), desde(n0).map(l => l.fn).filter(f => /plaid|proponer/.test(f)).join(','));
    const guardado7c = await q.evaluate(() => { const t = []; for (const st of [localStorage, sessionStorage]) for (let i = 0; i < st.length; i++) t.push(st.key(i) + '=' + st.getItem(st.key(i))); return t.join('\n'); });
    // (la lista de obras sí puede estar: es la caché de la app para la cuadrilla, de js/app.js, no de la contabilidad)
    ok('IA 7c · de la IA, en el teléfono solo queda la preferencia del interruptor (mxp.contador.sola): ni propuestas, ni cargos del banco, ni el marcador, ni la rutina', /mxp\.contador\.sola=1/.test(guardado7c) && !/v_contador|bbbbbbbb-|79999999-|GRAYBAR|acertadas|rutina|claude-opus/.test(guardado7c),
      guardado7c.split('\n').map(l => l.slice(0, 60)).join(' | '));
    await cx.close();

    // el teléfono (390) y el iPad (820): la Bandeja proponiendo sola y los botones de la obra desplegados, sin desplazamiento lateral
    for (const w of [390, 820]) {
      iaReset(true, true); IA.cadena(59); estado.iaLento = 1200;
      const [tcx, t] = await abrir(w, w < 700 ? 844 : 1100);
      await t.evaluate(() => window.MXP_CONTA.ir('bandeja'));
      await t.waitForFunction(() => /^Proponiendo… 20 de 60/.test(((document.querySelector('#ct-ia-cadena .ct-ia-avance') || {}).textContent || '').trim()), null, { timeout: 10000 }).catch(() => {});
      const med1 = await t.evaluate(() => {
        const r = e => e.getBoundingClientRect(), fr = r(document.getElementById('ct-ia-franja')), pa = r(document.getElementById('ct-ia-parar')), av = r(document.querySelector('#ct-ia-cadena .ct-ia-avance'));
        const fuera = [...document.querySelectorAll('#conta-raiz *')].filter(e => r(e).right > window.innerWidth + 1 && getComputedStyle(e).position !== 'fixed' && !e.closest('.ct-tabs')).map(e => e.className || e.tagName).slice(0, 5);
        return { sw: document.documentElement.scrollWidth, iw: window.innerWidth, fuera, pararDentro: pa.right <= fr.right + 1 && pa.left >= fr.left - 1, avDentro: av.right <= fr.right + 1 && av.width > 100, pararAlto: Math.round(pa.height) };
      });
      ok(`IA 7c · ${w === 390 ? 'teléfono (390 px)' : 'iPad (820 px)'}: la franja proponiendo sola («Proponiendo… 20 de 60 · $0.12» y «Parar» dentro de la franja) sin desplazamiento lateral`,
        med1.sw <= med1.iw + 1 && med1.fuera.length === 0 && med1.pararDentro && med1.avDentro && med1.pararAlto >= 36 && /^Proponiendo… 20 de 60 · \$0\.12$/.test(await avance(t)), JSON.stringify(med1));
      await foto(t, `ia7c-1-${w}-proponiendo-sola`);
      await finCadena(t, 25000); estado.iaLento = 0;
      const g2 = await fila(t, MI.gb); await t.waitForTimeout(300);
      const med2 = await t.evaluate(() => {
        const r = e => e.getBoundingClientRect(), c = document.querySelector('.ct-mov.abierta'), col = r(c.querySelector('.ct-ia-suya'));
        const bs = [...c.querySelectorAll('.ct-ia-obra-ops > button')].map(r);
        const fuera = [...document.querySelectorAll('#conta-raiz *')].filter(e => r(e).right > window.innerWidth + 1 && getComputedStyle(e).position !== 'fixed' && !e.closest('.ct-tabs')).map(e => e.className || e.tagName).slice(0, 5);
        return { sw: document.documentElement.scrollWidth, iw: window.innerWidth, fuera, n: bs.length, dentro: bs.every(x => x.left >= col.left - 1 && x.right <= col.right + 1), altos: bs.every(x => x.height >= 44),
          apilados: bs.every((x, i) => !i || x.top >= bs[i - 1].bottom - 1), anchos: bs.every(x => x.width >= col.width - 40) };
      });
      ok(`IA 7c · ${w === 390 ? 'teléfono' : 'iPad'}: «¿De qué obra?» con sus 4 botones (3 obras y «Otra obra…») uno debajo de otro, a lo ancho de su columna, de 44 px o más para el dedo, y nada se sale de la pantalla`,
        med2.sw <= med2.iw + 1 && med2.fuera.length === 0 && med2.n === 4 && med2.dentro && med2.altos && med2.apilados && med2.anchos, JSON.stringify(med2));
      await g2.locator('[data-ia-obra-op="dicke-subpanel-9p4w"]').click();
      ok(`IA 7c · ${w === 390 ? 'teléfono' : 'iPad'}: un toque elige (el botón en cobre) y «✓ Así es · Dicke — Subpanel y EV»`, (await g2.locator('[data-ia-obra-op="dicke-subpanel-9p4w"]').getAttribute('aria-pressed')) === 'true' && (await g2.locator('[data-ia-asi]').textContent()) === '✓ Así es · Dicke — Subpanel y EV');
      await foto(t, `ia7c-2-${w}-chips`);
      await tcx.close();
    }
    // sin el código del teléfono (aal1), con «Proponer sola» encendido: no arranca (ni se le pregunta nada a la función)
    estado.mfaFactores = []; estado.sesionAal = undefined; iaReset(true, true); IA.cadena(59);
    {
      const [scx, s3] = await abrir(1280, 900);
      const n3 = llamadas.length;
      await s3.evaluate(() => window.MXP_CONTA.ir('bandeja')); await pintado(s3); await s3.waitForTimeout(300);
      ok('IA 7c · sin el código del teléfono, con «Proponer sola» encendido, la Bandeja no propone sola: ni una llamada a la función «contador» y la franja dice por qué', !desde(n3).some(l => /^contador:/.test(l.fn)) && /Primero activa el código del teléfono/.test(await texto(s3, '.ct-ia-freno')));
      await scx.close();
    }
    estado.c8 = false; estado.iaSolaPref = '0'; estado.iaLento = 0; estado.iaFallas = []; iaReset();
  }

  // ---- Sin señal ----
  await ctx.setOffline(true);
  await tab(p, 'bancos'); await p.waitForSelector('.ct-rojo', { timeout: 8000 });
  ok('Sin señal: «Sin señal» en rojo, ninguna cuenta de memoria', /Sin señal/.test(await texto(p, '.ct-rojo h2')) && (await p.locator('.ct-cuenta').count()) === 0);
  await ctx.setOffline(false);
  await p.waitForSelector('.ct-cuenta', { timeout: 8000 }).catch(() => {});
  ok('Al volver la señal, reintenta sola', (await p.locator('.ct-cuenta').count()) === 4);

  if (FOTOS) {
    // cada página a 390, 820 y 1280 px (<ancho>-<pagina>.png), con el código del teléfono activo, Plaid conectado, la bandeja con el depósito de Stripe
    // y la IA contable (c8 con la 7b y la 7c) pegada: la bandeja con la propuesta de CES (la obra fuerte que propone la IA) desplegada y Conexiones con su
    // tarjeta (la rutina, el marcador, el interruptor) y sus reglas («Proponer sola» apagado: las fotos de la cadena son las de ia7c-1-*)
    estado.mfaFactores = [{ id: 'f-1', friendly_name: 'Teléfono de Edgar', factor_type: 'totp', status: 'verified' }]; estado.sesionAal = 'aal2'; estado.stripeDeposito = true;
    estado.c8 = true; iaReset(true, true);
    for (const w of [390, 820, 1280]) {
      const cx = await b.newContext({ viewport: { width: w, height: w < 700 ? 844 : 1000 }, deviceScaleFactor: w < 1024 ? 2 : 1, isMobile: w < 1024, hasTouch: w < 1024, serviceWorkers: 'block' });
      await simular(cx, 'dueno');
      const q = await cx.newPage(); q.on('pageerror', e => errs.push(`fotos ${w}: ` + String(e).slice(0, 160)));
      await q.goto('http://localhost:8873/index.html'); await q.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await q.waitForTimeout(800);
      await q.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
      await q.locator('#btn-conta').evaluate(b => b.click()); await q.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 });
      for (const k of PAGS) {
        await q.evaluate(k => window.MXP_CONTA.ir(k), k); await pintado(q); await q.waitForTimeout(300);
        if (k === 'bancos') await q.locator('#ct-imp-abrir').click().catch(() => {});
        if (k === 'bandeja') await fila(q, MI.ces).catch(() => {});
        if (k === 'movimientos') { await q.selectOption('#ct-mov-cuenta', '2100-2013').catch(() => {}); await pintado(q); }
        if (k === 'estados') { await q.locator('[data-periodo="2026-10"]').click().catch(() => {}); await pintado(q); }
        await q.waitForTimeout(200);
        await foto(q, `${w}-${k}`);
      }
      await cx.close();
    }
    estado.mfaFactores = []; estado.sesionAal = undefined; estado.stripeDeposito = false; estado.c8 = false; iaReset();
  }
  ok('Sin errores de JavaScript en la página', errs.length === 0, errs.join(' | '));
  await b.close(); srv.close();
  console.log('pantalla.js · la pantalla del banco con la base simulada\n' + R.join('\n'));
  const mal = R.filter(l => l.startsWith('  ✗')).length;
  console.log(mal ? `\n${mal} comprobación(es) fallaron` : '\nTodo en orden');
  process.exit(mal ? 1 : 0);
})().catch(e => { console.error('El arnés se cayó:', e); console.log(R.join('\n')); process.exit(2); });
