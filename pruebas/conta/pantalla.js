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
   Y el cierre del mes (c9, fase 8): la base de mentira trae las vistas y
   funciones de docs/conta/c9-cierre.sql con la forma EXACTA del contrato
   (la revisión de la apertura y de octubre como en el banco c9a, el cierre
   con su huella del mayor calculada como fn_cierre_hash_mayor, el bucket
   «cierres» que guarda lo que llega, los activos, la reserva, el DR-15, la
   ronda); se comprueba la ronda en «Qué atender», la revisión con lo que
   detiene (y su ir_a) y los avisos aparte, el botón apagado (algo detiene,
   sin el código del teléfono) y encendido, la confirmación mal escrita que
   no cierra, cerrar → el export subido y registrado con el sha256 de lo que
   llegó (y la huella recalculada desde el CSV con la receta del README),
   descargar con URL firmada, imprimir, MX010 explicado, la huella que no
   coincide (no exporta) y «Volver a exportar», los activos (alta, depreciar,
   baja), la reserva sin y con %, los estimados, el DR-15, el historial, los
   ajustes, sin c9, la falla ruidosa de la revisión, y el teléfono, el iPad y
   la computadora sin desplazamiento lateral. Una prueba de antes cambió: la
   de «Qué atender», que suponía la bandeja sin nada de más de 30 días y
   empezó a fallar sola el 2 nov (lo más viejo es del 2 oct).
   Y las facturas (c11, fase 10): la base de mentira trae v_emision_estado,
   v_emision_documentos, v_emision_obras, v_emision_control, emision_config y
   las fn_emision_* con la forma y los textos de docs/conta/c11-emision.sql
   (sacados del banco), y la función de borde `facturas` («pdf», «enviar»,
   «ver») con la de supabase/functions/facturas; se comprueba antes del corte
   (arriba lo dice, lo que falta, borradores para probar, «Emitir» apagado),
   Ajustes, por facturar (hitos, retención de la obra, porcentaje, T&M), el
   borrador con sus avisos y su vista previa en inglés, cambiar y refrescar,
   emitir con el código del teléfono (la confirmación, el «visto», MX011),
   el PDF con su enlace solo por cuenta de banco y sin enlace, mandar,
   reenviar, apuntar un correo que no se apuntó, en mano, la lista, tirar,
   el texto que parece español, anular con nota de crédito y desactivar su
   enlace, el 🧾 de la ficha antes y desde el corte (js/app.js), sin la
   función, sin c11, el rojo del control y 390/820/1280 px. Y (arreglo del
   12-nov) el 🧾 ante la duda (v_emision_estado en 500: no factura, salvo
   con un corte visto que aún no llega; sin c11, QuickBooks), antes del
   corte sin prometer número, el «How to pay» que habla de un enlace (avisa)
   y, tras un pago parcial, «Balance due today» igual al enlace. La forma y
   los textos de la mentira se compararon con el banco (c11 y c12 pegadas
   sobre g9a): solo difieren los ids, las huellas y el id del usuario.
   Y el WIP por costo a costo (c12, fase 10): la base de mentira trae fn_wip_resumen,
   v_wip_schedule (sus 47 columnas), fn_wip_control (17 filas), fn_wip_cierre (174 a
   177), v_wip_obras, v_wip_ajustes, v_wip_revisiones, wip_config y las fn_wip_* con
   la forma, el cálculo (en centavos, como la base) y los textos de docs/conta/c12-
   wip.sql (sacados del banco); se comprueba la página «WIP» (el mes que toca, lo de
   antes del libro, revisar, los totales de la base, el schedule, postear con el
   código del teléfono, ya no está al día y rehacer, deshacer, otro mes con «Sigue
   igual», la propuesta que cambió, terminada, pasada de 100 %, el mes cerrado), sus
   apartados «Obras», «Historial» y «Ajustes», la misma revisión dentro de «Cierre
   del mes» (las filas 174 a 177, revisar y postear desde ahí), la falla ruidosa,
   sin c12, el equipo, sin el código del teléfono y 390/820/1280 px.
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
  may(ASI.d, '2026-000405', '2026-10-07', 'Recibo 8812 Ferretería Ejemplo', -300, -9300, '2100-2013', 'Amex Business Gold', 'haber', 405, { orden: 2 }), may(ASI.c, '2026-000420', '2026-10-20', 'Pago Amex', 2300, -7000, '2100-2013', 'Amex Business Gold', 'haber', 420, { origen_tabla: null, camino: 'mano', orden: 2 }),
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
  // (fase 9, v2) lo de la IA de los pagos de la cuadrilla (J.ia): rechazar la pendiente, caducar la aprobada cuyo asiento ya no vive.
  // J.iaFalla: la función no contesta (como un 502 de la IA) esas veces seguidas
  if ((b.accion === 'rechazar' || b.accion === 'caducar') && estado.c10 && J.ia && J.ia.some(x => x.propuesta_id === b.propuesta)) {
    if (J.iaFalla > 0) { J.iaFalla -= 1; return { estado: 502, cuerpo: { ok: false, codigo: 'IA', error: 'La IA contable no contestó (prueba).' } }; }
    const p = J.ia.find(x => x.propuesta_id === b.propuesta);
    if (b.accion === 'caducar') {
      if (String(b.motivo || '').trim().length < 3) return { estado: 400, cuerpo: { ok: false, codigo: '22023', error: 'Cerrar una propuesta aprobada dice por qué (motivo): queda escrito.' } };
      if (p.estado === 'pendiente') return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', error: 'Esa propuesta está pendiente: se rechaza (fn_contador_rechazar), no se caduca.' } };
      if (!['aprobada', 'editada'].includes(p.estado)) return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', error: `Esa propuesta ya está ${p.estado}.` } };
      p.estado = 'caducada'; p.motivo = b.motivo;
      return { cuerpo: { ok: true, propuesta: p.propuesta_id, movimiento: p.movimiento_id, estado: 'caducada' } };
    }
    if (p.estado !== 'pendiente') return { estado: 409, cuerpo: { ok: false, codigo: 'MX008', error: `Esa propuesta ya está ${p.estado}.` } };
    p.estado = 'rechazada'; p.motivo = b.motivo || 'No es eso (Edgar, desde la bandeja)';
    return { cuerpo: { ok: true, propuesta: p.propuesta_id, movimiento: p.movimiento_id, estado: 'rechazada', fuente: 'ia', motivo_edgar: p.motivo } };
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
// ---- el cierre del mes (c9, fase 8): la forma EXACTA de v_cierre_estado, v_cierres, v_ronda_ultima, v_activos_fijos,
// v_reserva_impuestos, v_dr15_mes, cierre_config y reserva_estimados, y de fn_cierre_revisar, fn_cierre_cerrar,
// fn_cierre_export, fn_cierre_balanza, fn_cierre_config, fn_activo_alta/baja, fn_depreciacion_plan/mes y
// fn_reserva_estimado_marcar/anular (docs/conta/c9-cierre.sql y el contrato del agente de la base, con sus mensajes).
// La revisión de la apertura y de octubre es la del banco c9a (21 filas en octubre: 4 detienen y 3 avisos con la apertura
// abierta); los interruptores de C9.rojos los apagan. La huella del mayor la calcula la base de mentira como
// fn_cierre_hash_mayor, con node:crypto, sobre las mismas filas de v_mayor que lee la pantalla: si la pantalla arma
// otro texto, no coincide. El bucket «cierres» guarda lo que sube la pantalla (bytes y sha256 de lo que llegó). Sin
// estado.c9 todo esto contesta 404 (c9 sin pegar: PGRST205 en las vistas, PGRST202 en las funciones).
const cripto = require('crypto');
const sha = b => cripto.createHash('sha256').update(b).digest('hex');
const usd = v => (v < 0 ? '-' : '') + '$' + Math.abs(v).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const r2 = v => Math.round(v * 100) / 100;
const C9_PER = [
  { periodo: '2026-09-APERTURA', tipo: 'apertura', anio: 2026, desde: '2026-09-30', hasta: '2026-09-30', nombre: 'la apertura (30-sep-2026)', confirmacion: 'CERRAR LA APERTURA' },
  { periodo: '2026-10', tipo: 'mes', anio: 2026, desde: '2026-10-01', hasta: '2026-10-31', nombre: 'octubre de 2026', confirmacion: 'CERRAR OCTUBRE 2026' },
  { periodo: '2026-11', tipo: 'mes', anio: 2026, desde: '2026-11-01', hasta: '2026-11-30', nombre: 'noviembre de 2026', confirmacion: 'CERRAR NOVIEMBRE 2026' },
  { periodo: '2026-12', tipo: 'mes', anio: 2026, desde: '2026-12-01', hasta: '2026-12-31', nombre: 'diciembre de 2026', confirmacion: 'CERRAR DICIEMBRE 2026' },
  { periodo: '2027-01', tipo: 'mes', anio: 2027, desde: '2027-01-01', hasta: '2027-01-31', nombre: 'enero de 2027', confirmacion: 'CERRAR ENERO 2027' }
];
// el mayor de la apertura (dos líneas, un memo con coma y comillas para el CSV) y una línea de la IA en octubre (el sello)
const C9_MAYOR = [
  { ...may('aaaaaaaa-0000-4000-8000-0000000000a1', '2026-000001', '2026-09-30', 'Apertura: balanza de QuickBooks al 30-sep', 25000, 25000, '1010', 'Chase Checking', 'debe', 1,
    { periodo: '2026-09-APERTURA', periodo_efectivo: '2026-09-APERTURA', tipo: 'apertura', camino: 'mano', origen_tabla: null, memo: 'Balanza de QuickBooks, 30-sep "apertura"' }), cost_code: null },
  { ...may('aaaaaaaa-0000-4000-8000-0000000000a1', '2026-000001', '2026-09-30', 'Apertura: balanza de QuickBooks al 30-sep', -25000, -25000, '3000', 'Capital social', 'haber', 1,
    { periodo: '2026-09-APERTURA', periodo_efectivo: '2026-09-APERTURA', tipo: 'apertura', camino: 'mano', origen_tabla: null, orden: 2 }), cost_code: null },
  { ...may('aaaaaaaa-0000-4000-8000-0000000000a2', '2026-000430', '2026-10-28', 'Comisión mensual del banco', 35, 535, '6130', 'Cargos bancarios', 'debe', 430,
    { camino: 'ia', origen_tabla: 'movimientos_banco', origen_id: 'mb-77', proyecto_id: null, memo: 'Comisión, «mensual»' }), cost_code: 'G-01' }
];
const C9_ASIENTOS = [{ id: 'aaaaaaaa-0000-4000-8000-0000000000e5', numero: '2026-000005', fecha_contable: HOY, descripcion: 'IRS USATAXPYMT · estimado' }];
const C9 = {};
function c9Reset() {
  Object.assign(C9, {
    estado: Object.fromEntries(C9_PER.map(p => [p.periodo, 'abierto'])),
    rev: {}, cierres: {}, objetos: new Map(), exports: [], ronda: [], activos: [], deps: [], estimados: [], n: 0,
    // lo que la revisión trae en rojo (la apertura sin su asiento; en octubre el banco sin clasificar, sin conciliar y sin archivos al 31)
    rojos: { aperturaViva: true, banco40: true, conc50: true, archivos111: true },
    // interruptores: al cerrar, la base encuentra algo nuevo (MX010); la huella guardada no es la del mayor; v_cierre_estado no dice lo que la revisión
    mx010: false, hashMal: false, estadoMal: false,
    config: { id: 1, ronda_activa: true, reserva_pct: null, metodo_depreciacion: 'linea_recta', aviso_push: true, actualizado: '2026-11-06T12:00:00+00:00', actualizado_por: UID }
  });
}
c9Reset();
const c9Per = p => C9_PER.find(x => x.periodo === p);
const c9Cap = s => s.charAt(0).toUpperCase() + s.slice(1);
const err9 = (code, message, hint, status) => ({ status: status || 400, error: { code, message, hint: hint || null, details: null } });
const fila9 = (orden, control, nivel, ok, detalle, que_hacer, ir_a) => ({ ok, ir_a: ir_a || null, nivel, orden, control, detalle, que_hacer: que_hacer || null });
// la revisión de un período (fn_cierre_revisar), con los textos del banco c9a
function c9Revisar(periodo) {
  const p = c9Per(periodo), ap = p.tipo === 'apertura', R = C9.rojos;
  const antes = C9_PER.filter(x => x.desde < p.desde && C9.estado[x.periodo] !== 'cerrado');
  const term = p.hasta < HOY;
  const f = [
    fila9(10, 'orden: los períodos anteriores cerrados', 'detiene', !antes.length, antes.length ? `Antes de cerrar ${p.nombre} hay que cerrar ${antes[0].nombre}: todo se cierra en orden, la apertura primero (c2).` : `Los períodos anteriores a ${p.nombre} están cerrados.`, antes.length ? `Cierra primero ${antes[0].nombre}, desde esta misma pantalla.` : null, 'cierre'),
    fila9(15, 'calendario: el período ya terminó', 'detiene', term, `${c9Cap(p.nombre)} ${term ? 'terminó' : 'termina'} el ${p.hasta}; hoy es ${HOY} en Miami.`, term ? null : 'Espera a que termine el período.', 'cierre'),
    fila9(30, 'cuadre: debe = haber en el período', 'detiene', true, `3 asientos y 6 líneas en ${p.nombre}: debe $1,332.00 = haber $1,332.00.`, null, 'conexiones'),
    fila9(100, 'libro: cadena, numeración, guardas y permisos', 'detiene', true, 'Los 10 controles de fn_verificar_cadena (c2) están en verde.', null, 'conexiones'),
    fila9(121, 'estados: apertura en el libro', 'aviso', false, 'No cuadra: no hay apertura en el libro: carga la balanza de QuickBooks (fn_apertura_balanza_cargar), mapea sus cuentas y postéala con fn_apertura.', 'c2 deja cerrar con cualquier asiento de apertura vivo, pero los estados (c4) no se publican hasta que la apertura sea la de la balanza de QuickBooks: cárgala (fn_apertura_balanza_cargar) y postéala con fn_apertura; si hay una hecha a mano, revérsala.', 'estados'),
    fila9(130, 'puentes: los controles de los puentes (c3)', 'detiene', true, 'Los 13 controles de fn_puentes_verificar están en verde.', null, 'movimientos'),
    fila9(141, 'cobros en línea: la revisión automática corre', 'aviso', false, 'nunca ha corrido', 'El detalle dice qué (p1): Cobros en línea.', 'cobros'),
    fila9(146, 'ia: la llave y la función', 'aviso', false, 'ninguna ráfaga ha corrido nunca y hay 5 cargo(s) sin propuesta desde el 2026-10-02: ¿está ANTHROPIC_API_KEY en los secretos de Edge Functions y la función «contador» desplegada? Abre la Bandeja (propone sola) o toca «Proponer ahora»', 'El detalle dice qué (c8): la Bandeja y Conexiones → IA contable.', 'bandeja')
  ];
  if (ap) {
    f.push(fila9(20, 'apertura: su asiento de apertura está vivo', 'detiene', !R.aperturaViva, R.aperturaViva ? 'Falta el asiento de apertura del 2026-09-30 (o se reversó): cerrada vacía, la balanza de QuickBooks ya no tendría dónde entrar (c2).' : 'El asiento de apertura del 2026-09-30 está vivo (2026-000001).', R.aperturaViva ? 'Carga la balanza de QuickBooks al 30-sep (fn_apertura_balanza_cargar), mapea sus cuentas y postéala (fn_apertura, c4); después audítala.' : null, 'estados'));
    f.push(fila9(110, 'banco: los cuadres del banco (c6)', 'detiene', true, 'Los cuadres de fn_banco_control de la apertura (30-sep-2026) están en verde.', null, 'conciliar'));
  } else {
    const falta92 = C9.activos.some(a => a.fecha_servicio <= p.hasta && (a.estado === 'activo' || a.baja_fecha > p.hasta)) && !C9.deps.some(d => d.periodo === periodo);
    f.push(
      fila9(40, 'banco: todo lo del mes casado o clasificado', 'detiene', !R.banco40, R.banco40 ? `7 movimiento(s) del banco de ${p.nombre} sin clasificar ni casar: cargos por $787.40 y depósitos por $2,500.00; 1 posible(s) duplicado(s) sin decidir. Lo que no se clasifique no está en los libros de este mes.` : `Todo lo del banco de ${p.nombre} está casado o clasificado.`, R.banco40 ? 'Abre la Bandeja y resuelve cada uno: «Así es» a la propuesta de la IA, «Según yo», «Casar» con su ticket, o ignóralo con su motivo.' : null, 'bandeja'),
      fila9(42, 'ia: propuestas del mes sin decidir', 'aviso', true, `Ninguna propuesta de la IA de ${p.nombre} espera decisión.`, null, 'bandeja'),
      fila9(50, 'banco: cada cuenta conciliada al último día del mes', 'detiene', !R.conc50, R.conc50 ? `2 de 2 cuenta(s) sin conciliar al ${p.hasta}: Banco operativo (1010): sin conciliación confirmada al ${p.hasta} (la última confirmada: ninguna); Amex Business Gold (2100-2013): sin conciliación confirmada al ${p.hasta} (la última confirmada: ninguna).` : `Las 2 cuentas están conciliadas y confirmadas al ${p.hasta}.`, R.conc50 ? 'Conciliar: cada cuenta al último día del mes (fn_conciliar) y «Confirmar».' : null, 'conciliar'),
      fila9(52, 'banco: partidas en tránsito de más de 30 días', 'aviso', true, 'Ninguna partida en tránsito con más de 30 días en las conciliaciones del fin de mes.', null, 'conciliar'),
      fila9(60, '2010: lo que se le debe a cada proveedor', 'aviso', true, '2010 al 2026-10-31: $320.00. Por proveedor: Luis — ayudante, demolición 2 días $320.00. 0 partida(s) con más de 60 días por $0.00.', 'Compara el saldo de cada proveedor con el statement del supply (como en QuickBooks, a mano).', 'estados'),
      fila9(70, 'obras: el auxiliar por obra suma lo mismo que el mayor', 'detiene', true, `Todas las líneas de cuentas que exigen obra llevan su obra en ${p.nombre}: 1 obra(s), $320.00 en líneas con obra.`, null, 'movimientos'),
      fila9(80, 'recibos: los tickets del mes sin foto', 'aviso', true, `Todos los tickets contabilizados en ${p.nombre} tienen su foto.`, null, null),
      fila9(82, 'recibos: los tickets del mes con impuesto desconocido', 'aviso', true, `Todos los tickets contabilizados en ${p.nombre} dicen su impuesto (o que no llevaban).`, null, null),
      fila9(90, 'activos: 1590 = la depreciación acumulada de los activos', 'detiene', true, C9.activos.length ? `1590 al ${p.hasta} = la depreciación acumulada de los ${C9.activos.length} activo(s).` : `No hay activos fijos dados de alta todavía (se cargan en f12 con la cédula del CPA); 1590 tiene $0.00 al ${p.hasta}, lo que trajo QuickBooks. Se comprueba cuando estén.`, null, 'cierre'),
      fila9(92, 'activos: la depreciación del mes posteada', 'detiene', !falta92, falta92 ? `Falta la depreciación de ${p.nombre}: hay activos vivos y su asiento (Dr 6950 / Cr 1590) no está.` : C9.activos.length ? `La depreciación de ${p.nombre} está posteada.` : 'No hay activos fijos: nada que depreciar.', falta92 ? 'Cierre del mes → Activos fijos → «Depreciar» (fn_depreciacion_mes).' : null, 'cierre'),
      R.archivos111 ? fila9(111, 'banco: cada cuenta hasta el fin del mes', 'detiene', false, `Antes de cerrar el mes, importa lo de cada cuenta hasta su último día: Banco operativo (1010): sus archivos llegan al 2026-10-30 y 2026-10 terminó el 2026-10-31.`, 'Importa lo de esa cuenta hasta el último día del mes (la actividad reciente en QFX, o espera a la sincronización de Plaid) y vuelve a revisar.', 'conciliar')
        : fila9(110, 'banco: los cuadres del banco (c6)', 'detiene', true, `Los cuadres de fn_banco_control de ${p.nombre} están en verde.`, null, 'conciliar'),
      fila9(150, 'cambios: reversos y asientos de la IA del período', 'aviso', true, `En ${p.nombre}: 0 reverso(s) por $0.00; 1 asiento(s) de la IA aprobados por Edgar por $35.00; 0 a mano; 3 de los puentes.`, null, 'movimientos'),
      fila9(160, 'subs: COI vigente de cada sub pagado en el mes', 'aviso', true, 'Todavía no hay datos de COI en proveedores (llegan con f12a: W-9, COI y 1099): no se puede comprobar, y no frena.', 'Pide el certificado de seguro (COI) a cada sub antes de pagarle (f12a).', null)
    );
  }
  // (fase 10) el bloque de c12 en fn_cierre_revisar (scratchpad f10/c9-bloque-c12.sql): las cuatro filas de fn_wip_cierre en un mes
  if (!ap && estado.c12 && !estado.c12NoDueno && wPer(p.periodo)) for (const x of wCierre(p.periodo)) f.push(fila9(x.orden, x.control, x.nivel === 'aviso' ? 'aviso' : 'detiene', x.ok, x.detalle, x.que_hacer, x.ir_a));
  return f.sort((a, b) => a.orden - b.orden);
}
const rojo9 = x => x.ok !== true;
// la huella del mayor, como fn_cierre_hash_mayor: las líneas del período en el orden del libro, «numero|fecha|orden|cuenta|monto|proyecto_id|cost_code|memo»
function c9Huella(periodo) {
  const ls = tabla('v_mayor', new URLSearchParams(`periodo=eq.${periodo}&order=fecha.asc,cadena_pos.asc,orden.asc`));
  return { lineas: ls.length, asientos: new Set(ls.map(l => l.asiento_id)).size,
    hash: sha(Buffer.from(ls.map(l => [l.numero, String(l.fecha).slice(0, 10), l.orden, l.cuenta, Number(l.monto).toFixed(2), l.proyecto_id || '', l.cost_code || '', l.memo || ''].join('|')).join('\n'), 'utf8')) };
}
// la balanza que guarda la base al cerrar (fn_cierre_balanza)
function c9Balanza(periodo) {
  if (periodo === '2026-09-APERTURA') return [{ cuenta: '1010', inicial: 0, debe: 25000, haber: 0, final: 25000 }, { cuenta: '3000', inicial: 0, debe: 0, haber: 25000, final: -25000 }];
  if (periodo === '2026-10') return BZA.filter(b => b.nivel === 'cuenta').map(b => ({ cuenta: b.cuenta, inicial: b.saldo_inicial, debe: b.debe, haber: b.haber, final: b.saldo_final }));
  return [];
}
function c9Estado() {
  const sig = C9_PER.find(p => C9.estado[p.periodo] !== 'cerrado');
  return C9_PER.map(p => {
    const c = C9.cierres[p.periodo], rv = C9.rev[p.periodo], cer = C9.estado[p.periodo] === 'cerrado';
    return { periodo: p.periodo, tipo: p.tipo, anio: p.anio, desde: p.desde, hasta: p.hasta, estado: C9.estado[p.periodo], paralelo: true, terminado: p.hasta < HOY, siguiente: !!sig && sig.periodo === p.periodo,
      detienen: cer ? 0 : rv ? rv.detienen + (C9.estadoMal ? 1 : 0) : null, avisos: cer ? (c ? c.revision.filter(x => x.nivel === 'aviso' && rojo9(x)).length : 0) : rv ? rv.avisos : null,
      revisado_el: cer ? (c ? c.cerrado_el : null) : rv ? rv.revisado_el : null, cerrado_el: c ? c.cerrado_el : null, cerrado_por: c ? UID : null, cerrado_por_nombre: c ? 'Edgar Prueba' : null,
      hash_mayor: c ? c.hash_mayor : null, export_ruta: c ? c.export_ruta : null, exportado: !!(c && c.export_archivos), exportado_el: c ? c.exportado_el : null,
      confirmacion: p.confirmacion, nombre: p.nombre, export_carpeta: p.periodo + '/' };
  });
}
const c9Cierres = () => Object.values(C9.cierres).map(c => ({ ...c, avisos: c.revision.filter(x => x.nivel === 'aviso' && rojo9(x)).length, exportado: !!c.export_archivos, exports_anteriores: c.historial.length, historial: undefined }));
// la última corrida de la ronda: cada fila repite el resumen
function c9Ronda() {
  const f = C9.ronda; if (!f.length) return [];
  const rojos = f.filter(rojo9);
  return f.map(x => ({ fecha: x.fecha || HOY, corrida_el: x.corrida_el || '2026-11-06T11:45:00+00:00', rojos: rojos.length, detienen: rojos.filter(y => y.nivel === 'detiene').length, avisos: rojos.filter(y => y.nivel === 'aviso').length,
    avisados: f.filter(y => y.avisado).length, filas: f.length, avisado: false, ...x }));
}
function c9Activo(a) {
  const ds = C9.deps.filter(d => d.activo_id === a.id), libro = r2(ds.reduce((s, d) => s + d.monto, 0));
  const cuota = a.metodo === 'manual' ? a.monto_mensual : r2((a.costo - a.residual) / a.vida_meses);
  return { ...a, cuenta_nombre: { 1510: 'Vehículos', 1520: 'Herramienta y equipo', 1530: 'Equipo de cómputo', 1540: 'Mejoras' }[a.cuenta] || 'Activo', depreciado_libro: libro, acumulada: r2(a.dep_acumulada_inicial + libro),
    valor_libros: r2(a.costo - a.dep_acumulada_inicial - libro), meses_posteados: ds.length, ultimo_periodo: ds.length ? ds.map(d => d.periodo).sort().pop() : null, cuota_mensual: cuota,
    terminado: a.costo - a.residual - a.dep_acumulada_inicial - libro <= 0 };
}
function c9Plan(periodo) {
  const p = c9Per(periodo); if (!p || p.tipo !== 'mes') return [];
  return C9.activos.filter(a => a.fecha_servicio <= p.hasta && (a.estado === 'activo' || a.baja_fecha > p.hasta)).map(a => {
    const cuota = a.metodo === 'manual' ? a.monto_mensual : r2((a.costo - a.residual) / a.vida_meses);
    const acum = r2(a.dep_acumulada_inicial + C9.deps.filter(d => d.activo_id === a.id && c9Per(d.periodo).hasta < p.desde).reduce((s, d) => s + d.monto, 0));
    return { activo_id: a.id, descripcion: a.descripcion, cuenta: a.cuenta, metodo: a.metodo, cuota, acumulada_antes: acum, monto: r2(Math.max(0, Math.min(cuota, a.costo - a.residual - acum))) };
  });
}
function c9Proximo() {
  const [a] = HOY.split('-').map(Number);
  return [0, 1].flatMap(y => [1, 4, 6, 9].map(m => `${a + y}-${String(m).padStart(2, '0')}-15`)).filter(d => d >= HOY).sort()[0];
}
function c9Reserva() {
  const anio = Number(HOY.slice(0, 4)), util = 13100, pct = C9.config.reserva_pct, saldo = 0;
  const vivos = C9.estimados.filter(e => !e.anulado_el && e.anio_fiscal === anio), pag = r2(vivos.reduce((s, e) => s + e.monto, 0));
  const objetivo = pct == null ? null : Math.max(r2(util * pct / 100), 0), obj = objetivo == null ? null : Math.max(r2(objetivo - pag), 0), dif = obj == null ? null : r2(obj - saldo);
  const prox = c9Proximo(), dias = Math.round((Date.parse(prox) - Date.parse(HOY)) / 86400000);
  const mensaje = pct == null ? 'Falta el % que fije el CPA: cuando lo diga, guárdalo en Cierre → ajustes (fn_cierre_config, reserva_pct) y aquí saldrá cuánto transferir a la reserva (1030).'
    : dif > 0 ? `Transfiere ${usd(dif)} a la reserva (1030): la utilidad de ${anio} a la fecha es ${usd(util)}, el ${pct.toFixed(2)} % son ${usd(objetivo)}, ya pagaste ${usd(pag)} en estimados y la reserva tiene ${usd(saldo)}.`
    : dif < 0 ? `Sobra ${usd(-dif)} en la reserva (1030).` : `La reserva (1030) está al día: ${usd(saldo)}, lo que piden la utilidad de ${anio} a la fecha (${usd(util)}) y el ${pct.toFixed(2)} % del CPA, menos ${usd(pag)} ya pagados.`;
  return { anio, hoy: HOY, utilidad_anio: util, reserva_pct: pct, objetivo, estimados_pagados: pag, estimados_n: vivos.length, objetivo_1030: obj, saldo_1030: saldo, diferencia: dif, mensaje,
    proximo_estimado: prox, dias_para_estimado: dias, estimado_en_15_dias: dias <= 15, monto_sugerido: obj, nota: 'El monto sugerido es orientativo (lo acumulado y no pagado al % del CPA): el estimado lo fija el CPA.' };
}
const NOTA_DR15 = 'La base son las compras que la IA marcó «use_tax» y Edgar aprobó (c8); la tasa la pone el DR-15. Lo cargado a 2300 es el use tax ya devengado; lo pagado, los pagos al DOR. Las ventas gravables y el sales tax cobrado todavía no se saben: las facturas de la app no separan el impuesto (llegan con f10).';
const c9Dr15 = () => C9_PER.filter(p => p.tipo === 'mes').map(p => ({ periodo: p.periodo, desde: p.desde, hasta: p.hasta, compras_use_tax_n: p.periodo === '2026-10' ? 2 : 0, compras_use_tax_base: p.periodo === '2026-10' ? 840 : 0,
  use_tax_cargado_2300: p.periodo === '2026-10' ? 50.4 : 0, use_tax_pagado_2300: 0, use_tax_saldo_2300: p.periodo === '2026-10' ? 50.4 : 0, ventas_gravables: null, sales_tax_cobrado: null, nota: NOTA_DR15 }));
const C9_VISTAS = { v_cierre_estado: c9Estado, v_cierres: c9Cierres, v_ronda_ultima: c9Ronda, v_activos_fijos: () => C9.activos.map(c9Activo), v_reserva_impuestos: () => [c9Reserva()], v_dr15_mes: c9Dr15,
  cierre_config: () => [{ ...C9.config }], reserva_estimados: () => C9.estimados.map(e => ({ ...e })) };
// las funciones de c9 (POST /rest/v1/rpc/…): { error } o lo que devuelven
const C9_FN = {
  fn_cierre_revisar(a) {
    const p = c9Per(a.p_periodo);
    if (!p) return err9('MX002', `No existe el período «${a.p_periodo}»: un mes es AAAA-MM (2026-10), la apertura es 2026-09-APERTURA y un año es AAAA.`);
    const f = c9Revisar(p.periodo);
    if (C9.estado[p.periodo] !== 'cerrado') C9.rev[p.periodo] = { revisado_el: new Date().toISOString(), detienen: f.filter(x => x.nivel === 'detiene' && rojo9(x)).length, avisos: f.filter(x => x.nivel === 'aviso' && rojo9(x)).length };
    return f;
  },
  fn_cierre_cerrar(a) {
    const p = c9Per(a.p_periodo);
    if (!p) return err9('MX002', `No existe el período «${a.p_periodo}».`);
    if (C9.estado[p.periodo] === 'cerrado') return err9('MX002', `${c9Cap(p.nombre)} ya está cerrado. Un cierre no se repite ni se deshace.`);
    if (String(a.p_confirmo || '').trim() !== p.confirmacion) return err9('22023', `Para cerrar ${p.nombre} escribe exactamente «${p.confirmacion}» (llegó «${a.p_confirmo || ''}»). Un cierre no se deshace: por eso se pide escrito.`, p.confirmacion);
    // al cerrar, la base vuelve a revisar con el candado puesto: si entró algo (el interruptor), MX010 con la lista
    if (C9.mx010) { C9.mx010 = false; C9.rojos.banco40 = true; }
    const rev = c9Revisar(p.periodo), rojos = rev.filter(x => x.nivel === 'detiene' && rojo9(x));
    if (rojos.length) return err9('MX010', `No se cierra ${p.nombre}: ${rojos.length} cosa(s) lo detienen. ${rojos.map(x => `${x.orden}) ${x.control}: ${x.detalle}${x.que_hacer ? ' → ' + x.que_hacer : ''}`).join(' ')}`,
      `Resuélvelas y vuelve a tocar «Cerrar». La lista entera: select * from fn_cierre_revisar('${p.periodo}') where nivel = 'detiene' and not ok;`);
    const h = c9Huella(p.periodo), ahora = new Date().toISOString();
    C9.estado[p.periodo] = 'cerrado'; delete C9.rev[p.periodo];
    C9.cierres[p.periodo] = { periodo: p.periodo, tipo: p.tipo, anio: p.anio, desde: p.desde, hasta: p.hasta, cerrado_el: ahora, cerrado_por: UID, cerrado_por_nombre: 'Edgar Prueba', cerrado_rol: 'authenticated',
      cadena_al_cerrar: sha('cadena ' + p.periodo), hash_mayor: C9.hashMal ? sha('otra cosa') : h.hash, asientos: h.asientos, lineas: h.lineas, revision: rev,
      export_ruta: null, export_archivos: null, exportado_el: null, exportado_por: null, exportado_por_nombre: null, historial: [] };
    const sig = C9_PER.find(x => C9.estado[x.periodo] !== 'cerrado');
    return { periodo: p.periodo, nombre: p.nombre, cerrado_el: ahora, cerrado_por: UID, hash_mayor: C9.cierres[p.periodo].hash_mayor, cadena_al_cerrar: C9.cierres[p.periodo].cadena_al_cerrar,
      asientos: h.asientos, lineas: h.lineas, avisos: rev.filter(x => x.nivel === 'aviso' && rojo9(x)).length, siguiente: sig ? sig.periodo : null, siguiente_confirmacion: sig ? sig.confirmacion : null, export_carpeta: p.periodo + '/' };
  },
  fn_cierre_balanza: a => c9Balanza(a.p_periodo),
  fn_cierre_export(a) {
    const p = c9Per(a.p_periodo), c = p && C9.cierres[p.periodo];
    if (!c) return err9('MX002', `${p ? c9Cap(p.nombre) : a.p_periodo} no está cerrado desde la app: solo se exporta un período cerrado (ciérralo primero).`);
    const L = a.p_archivos;
    if (!Array.isArray(L) || !L.length) return err9('22023', 'Los archivos llegan como una lista [{ruta, sha256, bytes}], con al menos uno (el CSV del mayor).');
    const rutas = [], falta = []; let total = 0;
    for (const [i, f] of L.entries()) {
      if (!f || typeof f !== 'object' || Array.isArray(f)) return err9('22023', `Archivo ${i + 1}: cada archivo es un objeto {ruta, sha256, bytes}.`);
      const sobra = Object.keys(f).filter(k => !['ruta', 'sha256', 'bytes', 'tipo'].includes(k));
      if (sobra.length) return err9('22023', `Archivo ${i + 1}: clave desconocida: ${sobra.join(', ')}.`);
      if (!String(f.ruta || '').startsWith(p.periodo + '/') || String(f.ruta).length <= p.periodo.length + 1 || /(^|\/)\.\.(\/|$)/.test(f.ruta)) return err9('22023', `Archivo ${i + 1}: la ruta «${f.ruta || ''}» tiene que estar dentro de la carpeta del período en el bucket cierres (${p.periodo}/…).`);
      if (!/^[0-9a-f]{64}$/.test(String(f.sha256 || ''))) return err9('22023', `Archivo ${i + 1} (${f.ruta}): el sha256 va en 64 caracteres hexadecimales en minúsculas.`);
      if (!Number.isInteger(Number(f.bytes)) || Number(f.bytes) < 0) return err9('MX005', `Archivo ${i + 1} (${f.ruta}): bytes es su tamaño, un entero de 0 o más.`);
      if (rutas.includes(f.ruta)) return err9('22023', `Archivo ${i + 1}: la ruta «${f.ruta}» viene dos veces.`);
      rutas.push(f.ruta); total += Number(f.bytes);
      if (!C9.objetos.has(f.ruta)) falta.push(f.ruta);
    }
    if (falta.length) return err9('22023', `No está(n) en el bucket cierres: ${falta.join(', ')}. Sube los archivos primero y registra después.`);
    C9.exports.push({ periodo: p.periodo, archivos: L });
    if (c.export_archivos) c.historial.push({ exportado_el: c.exportado_el, export_ruta: c.export_ruta, archivos: c.export_archivos });
    Object.assign(c, { export_ruta: p.periodo + '/', export_archivos: L.map(f => ({ ...f })), exportado_el: new Date().toISOString(), exportado_por: UID, exportado_por_nombre: 'Edgar Prueba' });
    return { periodo: p.periodo, export_ruta: c.export_ruta, archivos: L.length, bytes: total, exportado_el: c.exportado_el, hash_mayor: c.hash_mayor, veces: c.historial.length + 1 };
  },
  fn_cierre_config(a) {
    const q = a.p;
    if (!q || typeof q !== 'object' || Array.isArray(q)) return err9('22023', 'La configuración llega como un objeto JSON.');
    const sobra = Object.keys(q).filter(k => !['ronda_activa', 'reserva_pct', 'metodo_depreciacion', 'aviso_push'].includes(k));
    if (sobra.length) return err9('22023', `Clave desconocida en la configuración: ${sobra.join(', ')}.`);
    if (q.reserva_pct != null && (typeof q.reserva_pct !== 'number' || q.reserva_pct < 0 || q.reserva_pct > 100)) return err9('MX005', 'reserva_pct va de 0 a 100, con dos decimales como mucho.');
    if ('metodo_depreciacion' in q && !['linea_recta', 'manual'].includes(q.metodo_depreciacion)) return err9('22023', 'metodo_depreciacion es linea_recta o manual (el método libro lo decide el CPA).');
    for (const k of ['ronda_activa', 'aviso_push']) if (k in q && typeof q[k] !== 'boolean') return err9('22023', 'ronda_activa y aviso_push son true o false.');
    Object.assign(C9.config, q, { actualizado: new Date().toISOString(), actualizado_por: UID });
    return { ...C9.config };
  },
  fn_activo_alta(a) {
    const q = a.p || {};
    const sobra = Object.keys(q).filter(k => !['descripcion', 'placa_serie', 'cuenta', 'fecha_servicio', 'costo', 'residual', 'vida_meses', 'metodo', 'monto_mensual', 'dep_acumulada_inicial', 'asiento_alta_id', 'notas'].includes(k));
    if (sobra.length) return err9('22023', `Clave desconocida: ${sobra.join(', ')}.`);
    if (!String(q.descripcion || '').trim()) return err9('22023', 'Todo activo dice qué es (descripcion): «Camioneta Ford F-150 2024», «Taladro magnético».');
    if (!/^15\d\d$/.test(String(q.cuenta || '')) || q.cuenta === '1590') return err9('MX004', `La cuenta del activo es una 15xx imputable y activa (1510 vehículos, 1520 herramienta, 1530 cómputo, 1540 mejoras), no «${q.cuenta || ''}».`);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(q.fecha_servicio || ''))) return err9('22023', 'La fecha en servicio va como AAAA-MM-DD.');
    const costo = Number(q.costo), residual = Number(q.residual || 0), metodo = q.metodo || C9.config.metodo_depreciacion;
    if (!(costo > 0)) return err9('MX005', 'El costo es un monto mayor que cero, en centavos.');
    if (metodo === 'linea_recta' && !(Number.isInteger(Number(q.vida_meses)) && q.vida_meses >= 1 && q.vida_meses <= 600)) return err9('MX005', 'La vida en meses va de 1 a 600 (en línea recta es obligatoria).');
    if (metodo === 'manual' && !(Number(q.monto_mensual) > 0)) return err9('MX005', 'El método manual pide el monto de cada mes (monto_mensual), mayor que cero.');
    const act = { id: 'afafafaf-0000-4000-8000-' + String(++C9.n).padStart(12, '0'), descripcion: q.descripcion, placa_serie: q.placa_serie || null, cuenta: q.cuenta, fecha_servicio: q.fecha_servicio, costo, residual,
      vida_meses: metodo === 'linea_recta' ? Number(q.vida_meses) : null, metodo, monto_mensual: metodo === 'manual' ? Number(q.monto_mensual) : null, dep_acumulada_inicial: Number(q.dep_acumulada_inicial || 0),
      asiento_alta_id: q.asiento_alta_id || null, estado: 'activo', baja_fecha: null, baja_motivo: null, baja_asiento_id: null, baja_el: null, notas: q.notas || null, creado: new Date().toISOString(), creado_por: UID };
    C9.activos.push(act);
    return c9Activo(act);
  },
  fn_activo_baja(a) {
    const act = C9.activos.find(x => x.id === a.p_id);
    if (!act) return err9('22023', 'No existe ese activo.');
    if (act.estado === 'baja') return err9('MX008', `«${act.descripcion}» ya está dado de baja (${act.baja_fecha}).`);
    if (!a.p_fecha || a.p_fecha < act.fecha_servicio) return err9('22023', 'La fecha de la baja no puede ser anterior a la fecha en servicio.');
    if (String(a.p_motivo || '').trim().length < 3) return err9('22023', 'Una baja dice por qué (motivo).');
    Object.assign(act, { estado: 'baja', baja_fecha: a.p_fecha, baja_motivo: String(a.p_motivo).trim(), baja_asiento_id: a.p_asiento_id || null, baja_el: new Date().toISOString() });
    return { ...c9Activo(act), nota: 'Hasta que apuntes el asiento de la baja (Dr 1590 por lo acumulado, Cr 1510 por el costo, 4920 por la diferencia), 1590 sigue contando este activo.' };
  },
  fn_depreciacion_plan: a => c9Plan(a.p_periodo),
  fn_depreciacion_mes(a) {
    const p = c9Per(a.p_periodo);
    if (!p || p.tipo !== 'mes') return err9('MX002', `La depreciación se postea por mes (AAAA-MM), no en ${a.p_periodo}.`);
    if (C9.estado[p.periodo] === 'cerrado') return err9('MX002', `${c9Cap(p.nombre)} ya está cerrado: la depreciación que faltó entra en el mes abierto (un asiento a mano Dr 6950 / Cr 1590, o como ajuste del CPA).`);
    const ya = C9.deps.filter(d => d.periodo === p.periodo);
    if (ya.length) return { periodo: p.periodo, activos: ya.length, monto: r2(ya.reduce((s, d) => s + d.monto, 0)), asiento: { id: ya[0].asiento_id, numero: '2026-000004' }, ya_estaba: true, detalle: [],
      nota: `La depreciación de ${p.nombre} ya estaba posteada (asiento 2026-000004): no se duplica. Si estaba mal, revérsala (fn_reversar) y vuelve a postear.` };
    const plan = c9Plan(p.periodo).filter(x => x.monto > 0);
    const asiento = { id: 'aaaaaaaa-0000-4000-8000-0000000000d4', numero: '2026-000004' }, monto = r2(plan.reduce((s, x) => s + x.monto, 0));
    for (const x of plan) C9.deps.push({ periodo: p.periodo, activo_id: x.activo_id, monto: x.monto, asiento_id: asiento.id });
    return { periodo: p.periodo, activos: plan.length, monto, asiento: plan.length ? asiento : null, ya_estaba: false, detalle: plan,
      nota: `Posteada la depreciación de ${p.nombre}: ${usd(monto)} en ${plan.length} activo(s) (asiento 2026-000004, Dr 6950 / Cr 1590).` };
  },
  fn_reserva_estimado_marcar(a) {
    const as = C9_ASIENTOS.find(x => x.id === a.p_asiento);
    if (!as) return err9('22023', 'No existe ese asiento.');
    if (C9.estimados.some(e => e.asiento_id === as.id && !e.anulado_el)) return err9('MX008', `El asiento ${as.numero} ya está marcado como estimado pagado.`);
    const anio = a.p_anio_fiscal != null ? Number(a.p_anio_fiscal) : (as.fecha_contable.slice(5, 7) === '01' ? Number(as.fecha_contable.slice(0, 4)) - 1 : Number(as.fecha_contable.slice(0, 4)));
    const e = { id: 'eeeeeeee-0000-4000-8000-' + String(++C9.n).padStart(12, '0'), fecha: as.fecha_contable, monto: 1200, asiento_id: as.id, anio_fiscal: anio, nota: a.p_nota || null,
      creado: new Date().toISOString(), creado_por: UID, anulado_el: null, anulado_por: null, anulado_motivo: null };
    C9.estimados.push(e);
    return { ...e, asiento_numero: as.numero };
  },
  fn_reserva_estimado_anular(a) {
    const e = C9.estimados.find(x => x.id === a.p_id);
    if (!e) return err9('22023', 'No existe ese estimado.');
    if (e.anulado_el) return err9('MX008', `Ese estimado ya estaba anulado (${e.anulado_motivo}).`);
    if (String(a.p_motivo || '').trim().length < 3) return err9('22023', 'Anular un estimado dice por qué (motivo).');
    Object.assign(e, { anulado_el: new Date().toISOString(), anulado_por: UID, anulado_motivo: String(a.p_motivo).trim() });
    return { ...e };
  }
};
// ---- la mano de obra y el costo por obra (c10, fase 9): la forma EXACTA de v_jornal_pendientes, v_jornal_repartos,
// v_jornal_personas, v_jornal_control, v_margen_obra, v_margen_control y jornal_config, y de las respuestas de
// fn_jornal_propuesta, fn_jornal_aplicar, fn_jornal_deshacer, fn_jornal_persona, fn_jornal_config y fn_margen_obra
// (docs/conta/c10-costo-obra.sql, los ejemplos del banco f9ej). El reparto se calcula aquí con la regla de la base
// (centavos por mayores restos, a resto igual más horas y luego la obra): el total es el pago. Datos inventados («C10 PRUEBA»).
const J_MOV = { ana: 'c1000000-0000-4000-8000-000000000001', beto: 'c1000000-0000-4000-8000-000000000002', ana2: 'c1000000-0000-4000-8000-000000000003', carla: 'c1000000-0000-4000-8000-000000000004' };
const J_PER = { ana: '00000000-0000-4000-a000-0000000c1001', beto: '00000000-0000-4000-a000-0000000c1002', carla: '00000000-0000-4000-a000-0000000c1003' };
const J_OBRAS = { 'c10-prueba-a': ['C10 PRUEBA Obra A', 'ejecucion'], 'c10-prueba-b': ['C10 PRUEBA Obra B', 'ejecucion'], 'c10-prueba-e': ['C10 PRUEBA Obra E', 'pausa'],
  'c10-prueba-f': ['C10 PRUEBA Obra F', 'completado'], 'c10-prueba-h': ['C10 PRUEBA Obra H', 'ejecucion'], 'c10-prueba-i': ['C10 PRUEBA Obra I', 'ejecucion'] };
// los asientos de la obra A que ya están en el libro (el material, el subcontrato de verdad, el equipo, el permiso, la factura) y el del jornal de ejemplo
const J_AS = { mat: 'c1a00000-0000-4000-8000-000000000001', co: 'c1a00000-0000-4000-8000-000000000002', sub: 'c1a00000-0000-4000-8000-000000000003', perm: 'c1a00000-0000-4000-8000-000000000005', fac: 'c1a00000-0000-4000-8000-000000000006', jornal: '1b0d2ea3-e7a3-4620-8f9b-958ad9a6acaf' };
const J_IA = 'c1b00000-0000-4000-8000-0000000000aa'; // la propuesta de la IA (c8) que tenía el pago de Zzbeto (pendiente: se rechaza)
const J_IA2 = 'c1b00000-0000-4000-8000-0000000000bb'; // (v2) la del pago de Zzana: aprobada y su asiento reversado (sin_asiento: se caduca)
const MES_J = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
// los textos de la base: fn_jornal_rango, fn_jornal_dia (2-nov, o 2-nov-2026), fn_jornal_h (37, 4.5) y fn_jornal_mes (noviembre de 2026)
const MES3_J = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const jDiaT = (iso, anio) => { const [a, m, d] = iso.split('-').map(Number); return `${d}-${MES3_J[m]}${anio ? '-' + a : ''}`; };
const jH = v => String(Number(v));
const jMes = iso => { const [a, m] = iso.split('-').map(Number); return `${MES_J[m]} de ${a}`; };
const jTexto = (d, h) => { const [a1, m1, d1] = d.split('-').map(Number), [a2, m2, d2] = h.split('-').map(Number);
  if (d === h) return `el ${d1} de ${MES_J[m1]} de ${a1}`;
  return a1 !== a2 ? `del ${d1} de ${MES_J[m1]} de ${a1} al ${d2} de ${MES_J[m2]} de ${a2}` : m1 !== m2 ? `del ${d1} de ${MES_J[m1]} al ${d2} de ${MES_J[m2]} de ${a2}` : `del ${d1} al ${d2} de ${MES_J[m2]} de ${a2}`; };
const jDia = (iso, n) => { const [a, m, d] = iso.split('-').map(Number); return new Date(Date.UTC(a, m - 1, d + n)).toISOString().slice(0, 10); };
// la regla de la base: lunes a miércoles → la semana anterior; jueves a domingo → la semana en curso (de lunes a domingo)
function jRegla(f) {
  const [a, m, d] = f.split('-').map(Number), dow = (new Date(Date.UTC(a, m - 1, d)).getUTCDay() + 6) % 7, lunes = jDia(f, -dow);
  const anterior = { desde: jDia(lunes, -7), hasta: jDia(lunes, -1), regla: 'semana_anterior' }, esta = { desde: lunes, hasta: jDia(lunes, 6), regla: 'semana_en_curso' };
  return { def: dow <= 2 ? anterior : esta, anterior, esta };
}
const J = {};
const jMov = (id, fecha, monto, descripcion) => ({ movimiento_id: id, cuenta: '1010', cuenta_nombre: 'Banco operativo', fecha, periodo: fecha.slice(0, 7), monto, descripcion, memo: null, cheque: null, tipo_banco: 'DEBIT',
  motivo: 'sin_ticket', texto: TEXTO_SIN_TICKET, opciones: [{ texto: 'Clasificarlo a 5200 (pide obra)', llamar: 'fn_banco_clasificar', args: { p_movimiento: id, p_lineas: [{ cuenta: '5200' }] } }], obra: null, propuesta: { motivo: 'sin_ticket' },
  posible_duplicado_de: null, duplicado_fecha: null, duplicado_descripcion: null, duplicado_origen: null, dias: Math.max(0, Math.round((Date.parse(HOY) - Date.parse(fecha)) / 86400000)), alarma: false, origen: 'plaid', archivo_id: null, importado_el: fecha + 'T12:00:00+00:00' });
function jReset() {
  J.config = { id: 1, cuenta_defecto: '5200', cuenta_sin_obra: null, burden_estandar_pct: null, aviso_tarifa_pct: 25.00, actualizado: '2026-11-09T22:00:00+00:00', actualizado_por: null };
  J.personas = [
    { usuario_id: J_PER.ana, nombre: 'Zzana C10 PRUEBA', rol: 'campo', perfil_activo: true, tarifa: 25, registrada: true, activa: true, patron: '\\mPRUEBA ZZANA\\M', cuenta_propia: null, nota: null, creado_el: '2026-11-09T22:00:00+00:00' },
    { usuario_id: J_PER.beto, nombre: 'Zzbeto C10 PRUEBA', rol: 'campo', perfil_activo: true, tarifa: 24, registrada: true, activa: true, patron: '\\mPRUEBA ZZBETO\\M', cuenta_propia: null, nota: null, creado_el: '2026-11-09T22:00:00+00:00' },
    { usuario_id: J_PER.carla, nombre: 'Zzcarla C10 PRUEBA', rol: 'campo', perfil_activo: true, tarifa: 18, registrada: false, activa: false, patron: null, cuenta_propia: null, nota: null, creado_el: null }
  ];
  const h = (id, u, fecha, p, co, fase, horas) => ({ id, u, fecha, p, co, fase, horas });
  J.horas = [
    // Zzana, la semana del 26-oct (37 h en 6 obras; la A con y sin CO; la F terminada)
    h(-1010000001, J_PER.ana, '2026-10-26', 'c10-prueba-a', null, 'rough', 8), h(-1010000002, J_PER.ana, '2026-10-27', 'c10-prueba-a', 'CO #1', 'rough', 6.5),
    h(-1010000003, J_PER.ana, '2026-10-27', 'c10-prueba-b', null, 'trim', 1.5), h(-1010000004, J_PER.ana, '2026-10-28', 'c10-prueba-e', null, null, 7.25),
    h(-1010000005, J_PER.ana, '2026-10-29', 'c10-prueba-f', null, 'rough', 4), h(-1010000006, J_PER.ana, '2026-10-29', 'c10-prueba-h', null, 'rough', 4),
    h(-1010000007, J_PER.ana, '2026-10-30', 'c10-prueba-i', null, 'mobilizacion', 3.75), h(-1010000008, J_PER.ana, '2026-10-30', 'c10-prueba-a', null, 'trim', 2),
    // Zzbeto, la semana del 2-nov (24 h; 2 sin obra)
    h(-1020000001, J_PER.beto, '2026-11-02', 'c10-prueba-a', null, 'rough', 8), h(-1020000002, J_PER.beto, '2026-11-03', 'c10-prueba-a', null, 'rough', 8),
    h(-1020000003, J_PER.beto, '2026-11-04', 'c10-prueba-h', null, 'rough', 6), h(-1020000004, J_PER.beto, '2026-11-05', null, null, null, 2),
    // Zzcarla (sin dar de alta), la semana del 2-nov: 12 h en la B
    h(-1030000001, J_PER.carla, '2026-11-02', 'c10-prueba-b', null, 'trim', 6), h(-1030000002, J_PER.carla, '2026-11-03', 'c10-prueba-b', null, 'trim', 6)
  ];
  J.movs = [jMov(J_MOV.ana, '2026-11-02', -940.00, 'Zelle payment to C10 PRUEBA ZZANA 9001'), jMov(J_MOV.beto, '2026-11-06', -600.00, 'Zelle payment to C10 PRUEBA ZZBETO 9003'),
    jMov(J_MOV.ana2, '2026-11-09', -520.00, 'Zelle payment to C10 PRUEBA ZZANA 9002'), jMov(J_MOV.carla, '2026-11-06', -300.00, 'Zelle payment to C10 PRUEBA ZZCARLA 9004')];
  J.fuera = new Set(); J.repartos = []; J.seq = 3; J.mx011 = false; J.pideMotivo = false; J.ctlRojo = false; J.margenRojo = false;
  // (v2) lo de la IA (c8) en estos pagos: la pendiente del de Zzbeto y, en el de Zzana, una aprobada cuyo asiento se reversó (se
  // des-casó para repartirlo por horas). J.iaFalla: cuántas veces seguidas la función «contador» no contesta al cerrarlas
  J.ia = [{ propuesta_id: J_IA, movimiento_id: J_MOV.beto, estado: 'pendiente', sinAsiento: false, resumen: '5200 → C10 PRUEBA Obra A', asiento: null },
    { propuesta_id: J_IA2, movimiento_id: J_MOV.ana, estado: 'aprobada', sinAsiento: true, resumen: '5100 → C10 PRUEBA Obra B', asiento: '2026-000002' }];
  J.iaFalla = 0;
  // el libro de la obra A (lo que «bajar» lee de v_libro): material base y del CO, un subcontrato de verdad en 5200, equipo, el permiso, la factura y el jornal
  const lj = (asiento_id, numero, fecha, descripcion, orden, cuenta, cuenta_nombre, monto, proyecto_id, memo) => ({ asiento_id, numero, orden, fecha, periodo: fecha.slice(0, 7), descripcion, memo: memo || null, cuenta, cuenta_nombre, debe: monto > 0 ? monto : 0, haber: monto < 0 ? -monto : 0, monto, proyecto_id, cost_code: null });
  J.libro = [
    lj(J_AS.mat, '2026-000101', '2026-10-05', 'Ticket · material de la obra A', 2, '5100', 'Material', 450.25, 'c10-prueba-a'), lj(J_AS.mat, '2026-000101', '2026-10-05', 'Ticket · renta de equipo', 3, '5300', 'Equipo y renta', 75.25, 'c10-prueba-a'),
    lj(J_AS.co, '2026-000102', '2026-10-20', 'Ticket · material del CO #1', 2, '5100', 'Material', 300.00, 'c10-prueba-a', 'CO #1'),
    lj(J_AS.sub, '2026-000103', '2026-10-22', 'Subcontrato · zanja', 2, '5200', 'Subcontratos', 500.00, 'c10-prueba-a'),
    lj(J_AS.perm, '2026-000104', '2026-10-23', 'Permiso de la obra A', 2, '5400', 'Permisos e inspecciones', 60.00, 'c10-prueba-a'),
    lj(J_AS.fac, '2026-000105', '2026-10-25', 'Factura 1 de la obra A', 2, '4020', 'Ingresos comerciales', -5000.00, 'c10-prueba-a'),
    lj(J_AS.jornal, '2026-000004', '2026-11-02', 'Jornal de Zzana C10 PRUEBA', 2, '5200', 'Subcontratos', 254.05, 'c10-prueba-a', 'Jornal de Zzana C10 PRUEBA · 26-oct a 1-nov-2026 · 10 h de 37 h'),
    lj(J_AS.jornal, '2026-000004', '2026-11-02', 'Jornal de Zzana C10 PRUEBA', 3, '5200', 'Subcontratos', 165.14, 'c10-prueba-a', 'CO #1 · 6.5 h de 37 h'),
    lj(J_AS.jornal, '2026-000004', '2026-11-02', 'Jornal de Zzana C10 PRUEBA', 4, '5200', 'Subcontratos', 38.11, 'c10-prueba-b')
  ];
}
const jPersonaDe = m => J.personas.find(p => p.registrada && p.activa && p.patron && new RegExp(p.patron.replace(/\\m|\\M/g, '\\b'), 'i').test(m.descripcion));
const jHorasCubiertas = () => new Set(J.repartos.filter(r => r.estado === 'aplicado').flatMap(r => r.horas_ids));
const jAviso = (codigo, corto, texto, extra) => ({ codigo, corto, ...(extra || {}), texto });
const jSuma = xs => xs.reduce((s, x) => s + x.horas, 0);
// (v2) lo de la IA (c8) que un pago tiene abierto, como fn_jornal_ia: la pendiente y la aprobada cuyo asiento ya no vive; sin
// movimiento, las de los pagos con un reparto aplicado (lo que enseña el control del jornal, el 80)
const jIA = mid => J.ia.filter(p => (p.estado === 'pendiente' || (['aprobada', 'editada'].includes(p.estado) && p.sinAsiento)) &&
  (mid ? p.movimiento_id === mid : J.repartos.some(r => r.movimiento_id === p.movimiento_id && r.estado === 'aplicado')))
  .map(p => ({ movimiento_id: p.movimiento_id, propuesta_id: p.propuesta_id, clase: p.estado === 'pendiente' ? 'pendiente' : 'sin_asiento', estado: p.estado, resumen: p.resumen, asiento: p.asiento }))
  .sort((a, b) => (a.clase === 'pendiente' ? 0 : 1) - (b.clase === 'pendiente' ? 0 : 1));
// (v2) las horas tardías, como fn_jornal_tardias: dentro de las fechas de un reparto aplicado de esa persona y fuera de todo reparto
function jTardias(u) {
  const cub = jHorasCubiertas(), viv = J.repartos.filter(r => r.estado === 'aplicado');
  return J.horas.filter(x => (!u || x.u === u) && !cub.has(x.id)).map(x => {
    const r = viv.find(y => y.usuario_id === x.u && x.fecha >= y.desde && x.fecha <= y.hasta);
    return r ? { horas_id: x.id, usuario_id: x.u, persona: (J.personas.find(p => p.usuario_id === x.u) || {}).nombre, fecha: x.fecha, proyecto_id: x.p, obra: x.p ? J_OBRAS[x.p][0] : null, horas: x.horas, reparto_id: r.reparto_id, fecha_pago: r.fecha_pago } : null;
  }).filter(Boolean).sort((a, b) => a.fecha.localeCompare(b.fecha) || a.horas_id - b.horas_id);
}
// mayores restos en centavos: a cada parte la entera de C × h / H; lo que sobra, de uno en uno a los restos mayores (a resto igual, más horas, luego el orden)
function jPartir(cents, partes) {
  const H = partes.reduce((s, x) => s + Math.round(x.horas * 100), 0);
  const base = partes.map((x, i) => { const num = cents * Math.round(x.horas * 100); return { i, ent: Math.floor(num / H), resto: num % H, horas: x.horas }; });
  let sobra = cents - base.reduce((s, x) => s + x.ent, 0);
  [...base].sort((a, b) => b.resto - a.resto || b.horas - a.horas || a.i - b.i).forEach(x => { if (sobra > 0) { x.ent += 1; sobra -= 1; } });
  return base.map(x => x.ent);
}
// fn_jornal_calcular (lo que devuelve fn_jornal_propuesta): la forma y los TEXTOS de la base v2, aviso por aviso y en su orden
function jCalc(mid, desde, hasta, op) {
  op = op || {};
  const incl = !!op.incluir_cubiertas;
  const m = J.movs.find(x => x.movimiento_id === mid), per = m && jPersonaDe(m);
  const movJ = m ? { id: m.movimiento_id, fecha: m.fecha, monto: Math.abs(m.monto), cuenta: m.cuenta, descripcion: m.descripcion, estado: J.fuera.has(mid) ? 'casado' : 'pendiente' } : null;
  if (!per) return { reconocido: false, movimiento: movJ, por_que: 'No es el pago de nadie dado de alta para repartir por horas. Si es de alguien de la cuadrilla con horas en la app, dalo de alta y sus pagos se reconocerán solos.',
    candidatos: J.personas.filter(p => !p.registrada).map(p => ({ usuario_id: p.usuario_id, nombre: p.nombre, rol: p.rol })) };
  const rg = jRegla(m.fecha), d = desde || rg.def.desde, h = hasta || rg.def.hasta;
  const regla = d === rg.anterior.desde && h === rg.anterior.hasta ? 'semana_anterior' : d === rg.esta.desde && h === rg.esta.hasta ? 'semana_en_curso' : 'a_mano';
  const cub = jHorasCubiertas(), todas = J.horas.filter(x => x.u === per.usuario_id && x.fecha >= d && x.fecha <= h).sort((a, b) => a.fecha.localeCompare(b.fecha) || b.id - a.id);
  const cubiertas = todas.filter(x => cub.has(x.id)), entran = todas.filter(x => incl || !cub.has(x.id));
  const cents = Math.round(Math.abs(m.monto) * 100);
  const grupos = [];
  for (const x of entran) { const k = (x.p || '~') + '|' + (x.co || ''); let g = grupos.find(y => y.k === k); if (!g) grupos.push(g = { k, p: x.p, co: x.co, horas: 0, rep: [] }); g.horas += x.horas; g.rep.push(x); }
  grupos.sort((a, b) => (a.p ? 0 : 1) - (b.p ? 0 : 1) || String(a.p).localeCompare(String(b.p)) || (a.co ? 1 : 0) - (b.co ? 1 : 0));
  const montos = grupos.length ? jPartir(cents, grupos) : [];
  const lineas = [], detalle = []; let sinObra = null;
  grupos.forEach((g, i) => {
    const n = i + 1, monto = montos[i] / 100;
    const reps = jPartir(montos[i], g.rep);
    g.rep.forEach((x, j) => detalle.push({ horas_id: x.id, fecha: x.fecha, proyecto_id: x.p, obra: x.p ? J_OBRAS[x.p][0] : null, co: x.co, fase: x.fase, horas: x.horas, aprobada: cub.has(x.id), entra: true, monto: reps[j] / 100, n, cubierta_por: null }));
    if (g.p) lineas.push({ n, proyecto_id: g.p, obra: J_OBRAS[g.p][0], obra_estado: J_OBRAS[g.p][1], co: g.co, horas: g.horas, monto, cuenta: '5200' });
    else sinObra = { n, horas: g.horas, monto, cuenta: J.config.cuenta_sin_obra, falta_cuenta: !J.config.cuenta_sin_obra };
  });
  const repDe = id => J.repartos.find(r => r.estado === 'aplicado' && r.horas_ids.includes(id));
  for (const x of todas.filter(y => !entran.includes(y))) detalle.push({ horas_id: x.id, fecha: x.fecha, proyecto_id: x.p, obra: x.p ? J_OBRAS[x.p][0] : null, co: x.co, fase: x.fase, horas: x.horas, aprobada: true, entra: false, monto: null, n: null, cubierta_por: [repDe(x.id).reparto_id] });
  const horas = jSuma(entran), texto = jTexto(d, h);
  // «el del pago del 2-nov ($940.00, del 26 de octubre al 1 de noviembre de 2026)»
  const repTxt = rs => rs.map(r => `el del pago del ${jDiaT(r.fecha_pago)} (${usd(r.monto)}, ${jTexto(r.desde, r.hasta)})`).join('; ');
  const cubReps = [...new Set(cubiertas.map(x => repDe(x.id)))].sort((a, b) => a.fecha_pago.localeCompare(b.fecha_pago)), cubH = jSuma(cubiertas);
  const avisos = []; let porQue = null;
  if (!horas) {
    porQue = !todas.length ? `${per.nombre} no tiene horas reportadas ${texto}. Elige otras fechas (la semana anterior, esta semana, o a mano); si este pago no es por horas, clasifícalo en la Bandeja como siempre.`
      : `Las ${jH(cubH)} h de ${per.nombre} ${texto} ya entraron en otro reparto: ${repTxt(cubReps)}. Si este es OTRO pago de esas mismas horas (un adelanto y el resto), repártelo también por ellas; si no, elige otras fechas.`;
    avisos.push(jAviso('sin_horas', 'Sin horas en esas fechas', porQue));
  } else if (cubiertas.length) avisos.push(jAviso('horas_cubiertas', 'Parte de las horas ya tiene otro pago', incl
    ? `${jH(cubH)} h de esas fechas ya estaban en otro reparto (${repTxt(cubReps)}) y entran también en este, porque lo pediste: es otro pago de las mismas horas.`
    : `${jH(cubH)} h de esas fechas ya las cubre otro pago (${repTxt(cubReps)}): no entran en este reparto, que va solo por las ${jH(horas)} h que faltaban.`));
  const tard = jTardias(per.usuario_id).filter(t => !entran.some(x => x.id === t.horas_id));
  if (tard.length) avisos.push(jAviso('horas_tardias', 'Tiene horas de una semana ya repartida sin pago',
    `${per.nombre} tiene ${jH(jSuma(tard))} h de una semana ya repartida que no están en ningún reparto (se reportaron o se movieron después): ${tard.map(t => `${jH(t.horas)} h del ${jDiaT(t.fecha)}${t.obra ? ' en ' + t.obra : ' sin obra'} (semana del pago del ${jDiaT(t.fecha_pago)})`).join('; ')}. Si este pago las cubre, elige fechas que las incluyan (a mano, desde el ${jDiaT(tard[0].fecha, true)}); si no, deshaz aquel reparto y vuelve a repartirlo con las horas de hoy.`,
    { horas: jSuma(tard), reportes: tard.length, desde: tard[0].fecha, hasta: tard.map(t => t.fecha).sort().pop() }));
  const pisan = J.repartos.filter(r => r.usuario_id === per.usuario_id && r.estado === 'aplicado' && r.desde <= h && r.hasta >= d).sort((a, b) => a.fecha_pago.localeCompare(b.fecha_pago));
  if (pisan.length) avisos.push(jAviso('se_pisa', 'Se pisa con otro reparto', `Estas fechas se pisan con otro reparto de ${per.nombre}: ${repTxt(pisan)}. Mira que no sea la misma semana pagada dos veces.`, { repartos: pisan.map(r => r.reparto_id) }));
  const tarifaSale = horas ? Math.round(cents / horas) / 100 : null, desvio = tarifaSale && per.tarifa ? Math.round((tarifaSale / per.tarifa - 1) * 1000) / 10 : null;
  if (per.tarifa == null) avisos.push(jAviso('sin_tarifa', 'Sin tarifa para comparar', `${per.nombre} no tiene tarifa en Costos del equipo: no hay con qué comparar lo que sale por hora.`));
  else if (desvio != null && Math.abs(desvio) > J.config.aviso_tarifa_pct) avisos.push(jAviso('tarifa_lejos', 'La tarifa que sale se aleja de la suya',
    `Sale a ${usd(tarifaSale)} la hora y su tarifa en Costos del equipo es ${usd(per.tarifa)} (${Math.abs(desvio)} % ${desvio > 0 ? 'más' : 'menos'}). Revisa las fechas (¿el pago es de otra semana, o de dos?) o las horas reportadas; y si el pago lleva además otra cosa (un reembolso de material), aquí iría entero a su mano de obra. Es solo un aviso: se puede repartir igual.`));
  const T = m.descripcion.toUpperCase();
  if (!/\b(ZELLE|TRANSFER|TRANSFERENCIA|PAYMENT|PMT|PAGO|CHECK|CHEQUE|ACH|WIRE|VENMO|PAYPAL|CASHAPP|P2P)\b/.test(T) || /\b(POS|PURCHASE|COMPRA|CARD|TARJETA)\b/.test(T))
    avisos.push(jAviso('no_parece_pago', 'No parece un pago a una persona', `El banco no lo describe como un pago a una persona (un Zelle, una transferencia, un cheque): «${m.descripcion.slice(0, 80)}». Mira que no sea una compra en un comercio con un nombre parecido al de ${per.nombre}: si lo es, no lo repartas, clasifícalo en la Bandeja como siempre.`));
  const term = lineas.filter(l => ['completado', 'no_aprobado'].includes(l.obra_estado));
  if (term.length) avisos.push(jAviso('obra_terminada', term.some(l => l.obra_estado === 'completado') ? 'Hay una obra terminada' : 'Hay una obra no aprobada',
    `Hay horas en una obra que ya no está activa: ${[...new Set(term.map(l => `${l.obra} (${l.obra_estado === 'completado' ? 'terminada' : 'no aprobada'})`))].sort().join('; ')}. Su parte va a esa obra igual: el trabajo se hizo ahí.`));
  if (sinObra && sinObra.falta_cuenta) {
    const x = `${jH(sinObra.horas)} h no tienen obra (les tocan ${usd(sinObra.monto)}) y no pueden ir a 5200, que exige obra. Di una vez a qué cuenta va la mano de obra sin obra (ajustes del jornal), o ponles su obra en Horas y vuelve a mirar.`;
    avisos.push(jAviso('falta_cuenta_sin_obra', 'Falta la cuenta de lo sin obra', x)); if (!porQue) porQue = x;
  }
  // el corte de mes y de año: el asiento entra el día del pago (en esta base de mentira ningún mes está cerrado)
  const fa = m.fecha, fuera = detalle.filter(x => x.entra && x.fecha.slice(0, 7) !== fa.slice(0, 7));
  const deOtroAnio = fuera.filter(x => x.fecha.slice(0, 4) !== fa.slice(0, 4)), sumM = xs => Math.round(xs.reduce((s, x) => s + x.monto * 100, 0)) / 100;
  if (deOtroAnio.length) avisos.push(jAviso('otro_anio', 'Horas de otro año',
    `${jH(jSuma(deOtroAnio))} h de este pago (${usd(sumM(deOtroAnio))}) se trabajaron en ${[...new Set(deOtroAnio.map(x => x.fecha.slice(0, 4)))].sort().join(' y ')} y el asiento entra el ${jDiaT(fa, true)}: su costo queda en el ejercicio ${fa.slice(0, 4)} (el libro va por la fecha del pago, como QuickBooks). Si el CPA quiere ese costo en el año en que se trabajó, es un ajuste suyo de fin de año: díselo. Es solo un aviso.`,
    { horas: jSuma(deOtroAnio), monto: sumM(deOtroAnio), fecha_asiento: fa }));
  else if (fuera.length) avisos.push(jAviso('otro_mes', 'Horas de otro mes',
    `${jH(jSuma(fuera))} h de este pago (${usd(sumM(fuera))}) se trabajaron en ${[...new Set(fuera.map(x => x.fecha.slice(0, 7)))].sort().map(x => jMes(x + '-01')).join(' y ')} y el asiento entra el ${jDiaT(fa, true)}: su costo queda en ${jMes(fa)} (el libro va por la fecha del pago, como QuickBooks). Es solo un aviso.`,
    { horas: jSuma(fuera), monto: sumM(fuera), fecha_asiento: fa }));
  if (d > m.fecha) avisos.push(jAviso('periodo_futuro', 'Las fechas son posteriores al pago', `Las fechas (${texto}) empiezan después del día del pago (${jDiaT(m.fecha, true)}): ¿seguro que pagó por adelantado?`));
  // lo que el «Así es» aprobará: los reportes de esas fechas sin aprobar (aquí, los que no tienen ya un reparto), entren o no
  const aprueba = todas.filter(x => !cub.has(x.id)).map(x => x.id).sort((a, b) => a - b);
  const visto = sha(Buffer.from(JSON.stringify([mid, d, h, Math.abs(m.monto), J.config.cuenta_sin_obra, incl, entran.map(x => [x.id, x.fecha, x.p, x.co, x.fase, x.horas]), aprueba]))).slice(0, 32);
  const opciones = [rg.anterior, rg.esta].map(o => { const hs = J.horas.filter(x => x.u === per.usuario_id && x.fecha >= o.desde && x.fecha <= o.hasta); return { regla: o.regla, desde: o.desde, hasta: o.hasta, por_defecto: o.regla === rg.def.regla, horas: jSuma(hs), horas_sin_pago: jSuma(hs.filter(x => !cub.has(x.id))) }; });
  const ia = jIA(mid).map(p => ({ propuesta_id: p.propuesta_id, clase: p.clase, estado: p.estado, resumen: p.resumen, asiento: p.asiento, que_hacer: p.clase === 'pendiente' ? 'rechazar' : 'caducar' }));
  return { reconocido: true, movimiento: { ...movJ, periodo: m.periodo, mes_cerrado: false, fecha_asiento: fa },
    persona: { usuario_id: per.usuario_id, nombre: per.nombre, rol: per.rol, tarifa: per.tarifa, cuenta: '5200', patron: per.patron },
    periodo: { desde: d, hasta: h, regla, texto, por_defecto: { desde: rg.def.desde, hasta: rg.def.hasta, regla: rg.def.regla }, opciones },
    horas, reportes: entran.length, obras: new Set(lineas.map(l => l.proyecto_id)).size, lineas, sin_obra: sinObra, detalle,
    cubiertas: cubiertas.length ? { horas: cubH, reportes: cubiertas.length, incluidas: incl, repartos: cubReps.map(r => ({ reparto_id: r.reparto_id, fecha_pago: r.fecha_pago, monto: r.monto, desde: r.desde, hasta: r.hasta, horas: jSuma(cubiertas.filter(x => repDe(x.id) === r)) })) } : null,
    tarifa_sale: tarifaSale, tarifa_equipo: per.tarifa, tarifa_desvio_pct: desvio, avisos, puede_aplicar: !porQue, por_que: porQue, visto,
    aprueba: { reportes: aprueba.length, ids: aprueba }, propuesta_ia: (ia.find(p => p.clase === 'pendiente') || {}).propuesta_id || null, propuestas_ia: ia,
    opciones: { incluir_cubiertas: incl } };
}
// v_jornal_pendientes: una fila por pago pendiente reconocido, con la semana de la regla (= fn_jornal_propuesta sin fechas)
const jPendientes = () => J.movs.filter(m => !J.fuera.has(m.movimiento_id) && jPersonaDe(m)).map(m => {
  const p = jCalc(m.movimiento_id);
  return { movimiento_id: m.movimiento_id, cuenta: m.cuenta, fecha: m.fecha, monto: Math.abs(m.monto), descripcion: m.descripcion, usuario_id: p.persona.usuario_id, persona: p.persona.nombre, tarifa: p.persona.tarifa,
    desde: p.periodo.desde, hasta: p.periodo.hasta, regla: p.periodo.regla, periodo_texto: p.periodo.texto, horas: p.horas, reportes: p.reportes, obras: p.obras, horas_sin_obra: p.sin_obra ? p.sin_obra.horas : null,
    tarifa_sale: p.tarifa_sale, puede_aplicar: p.puede_aplicar, por_que: p.por_que, aviso: p.avisos.map(a => a.corto).join(' · ') || null, n_avisos: p.avisos.length, avisos: p.avisos, lineas: p.lineas, visto: p.visto, propuesta_ia: p.propuesta_ia };
});
const jRepartosVista = () => [...J.repartos].sort((a, b) => b.creado_el.localeCompare(a.creado_el)).map(r => ({ ...r, horas_ids: undefined, horas_aprobadas: r.horas_ids.length }));
const jPersonasVista = () => J.personas.map(p => {
  const pend = jPendientes().filter(f => f.usuario_id === p.usuario_id), reps = J.repartos.filter(r => r.usuario_id === p.usuario_id && r.estado === 'aplicado'), hs = J.horas.filter(x => x.u === p.usuario_id), cub = jHorasCubiertas();
  return { usuario_id: p.usuario_id, nombre: p.nombre, rol: p.rol, perfil_activo: true, registrada: p.registrada, activa: p.activa, patron: p.patron, cuenta_propia: null, cuenta: '5200', tarifa: p.tarifa, nota: p.nota, creado_el: p.creado_el, actualizado_el: p.creado_el,
    pagos_pendientes: pend.length, pagos_pendientes_monto: pend.reduce((s, f) => s + f.monto, 0), repartos: reps.length, repartido: reps.reduce((s, r) => s + r.monto, 0), ultimo_reparto: reps.length ? reps[reps.length - 1].creado_el : null,
    horas_90_dias: hs.reduce((s, x) => s + x.horas, 0), horas_sin_pago: hs.filter(x => !cub.has(x.id)).reduce((s, x) => s + x.horas, 0) };
});
// v_jornal_control (v2): sus 11 filas con los nombres y los textos de la base; 35, 70 y 80 son avisos. El 35 sale de las horas
// tardías y el 80 de lo de la IA que siguen abiertas en un pago repartido (jIA); J.ctlRojo pone en rojo el 20 (un pago suelto)
const jCtl = () => {
  const viv = J.repartos.filter(r => r.estado === 'aplicado'), tard = jTardias(null), ia = jIA(null), f = (orden, cuadre, nivel, ok, detalle) => ({ orden, cuadre, nivel, ok, detalle });
  const g35 = []; for (const t of tard) { let g = g35.find(x => x.reparto_id === t.reparto_id && x.persona === t.persona); if (!g) g35.push(g = { reparto_id: t.reparto_id, persona: t.persona, fecha_pago: t.fecha_pago, h: 0, n: 0, dias: new Set() }); g.h += t.horas; g.n += 1; g.dias.add(`${jDiaT(t.fecha)}${t.obra ? ' en ' + t.obra : ' sin obra'}`); }
  return [
    f(10, 'jornal: cada reparto aplicado = las líneas de su asiento', 'cuadre', true, `${viv.length} reparto(s) aplicado(s): cada parte está en su asiento con su cuenta, su obra, su CO, su monto y su persona, todas suman el pago, y su detalle por reporte de horas suma cada parte.`),
    f(20, 'jornal: ningún reparto aplicado con su asiento reversado o su pago suelto', 'cuadre', !J.ctlRojo, J.ctlRojo
      ? 'el reparto del pago del 2026-11-02 a Zzana C10 PRUEBA (940.00): su asiento 2026-000004 se reversó por fuera (des-casado en la Bandeja) → toca «Deshacer» en ese reparto (en Repartos), con su motivo, y, si toca, vuelve a repartir el pago.'
      : 'Cada reparto aplicado tiene su asiento vivo y su pago casado con él.'),
    f(25, 'jornal: ningún reparto deshecho con su asiento todavía vivo', 'cuadre', true, 'Cada reparto deshecho tiene su asiento reversado.'),
    f(30, 'jornal: las horas de cada reparto aplicado siguen como se repartieron', 'cuadre', true, `${viv.reduce((s, r) => s + r.horas_ids.length, 0)} reporte(s) de horas en repartos aplicados: siguen con su obra, su CO, su fase y sus horas, y aprobados.`),
    f(35, 'jornal: ninguna hora de una semana ya repartida se quedó fuera de su reparto', 'aviso', !g35.length, g35.length
      ? g35.map(g => `${g.persona}: ${jH(g.h)} h en ${g.n} reporte(s) (${[...g.dias].sort().join(', ')}) dentro del reparto del pago del ${g.fecha_pago}`).join('; ') + ' → se reportaron o se movieron después de repartir esa semana: no recibieron nada de ese pago, que sigue repartido entre las demás obras, y en su obra salen a estándar. Toca «Deshacer» en ese reparto y vuelve a repartirlo con las horas de hoy; o, si las paga otro pago, repártelas con él eligiendo sus fechas a mano.'
      : 'Ninguna persona tiene horas, dentro de las fechas de un reparto suyo aplicado, fuera de sus repartos.'),
    f(40, 'jornal: ninguna hora en dos repartos vivos sin que Edgar lo aceptara', 'cuadre', true, 'Ninguna hora está en dos repartos vivos.'),
    f(50, 'jornal: ninguna hora a la vez en el devengo estándar de un mes y en un jornal pagado ese mes', 'cuadre', true, 'Ninguna hora está a la vez en el devengo estándar de un mes abierto y en un jornal que entró al libro ese mes.'),
    f(60, 'jornal: cada persona dada de alta se reconoce sin dudas y va a una cuenta que sirve', 'aviso', true, `${J.personas.filter(p => p.registrada && p.activa).length} persona(s) activa(s): patrones válidos, ningún pago casa con dos, y sus cuentas sirven.`),
    f(70, 'jornal: ningún pago de una persona dada de alta resuelto fuera del jornal', 'aviso', true, 'Ningún pago ya resuelto en la Bandeja por otro camino es de una persona del jornal con horas sin pago en esas semanas.'),
    f(80, 'jornal: ninguna propuesta de la IA abierta en un pago ya repartido', 'aviso', !ia.length, ia.length
      ? ia.map(i => { const r = viv.find(x => x.movimiento_id === i.movimiento_id); return `el pago del ${r.fecha_pago} a ${r.persona} (${usd(r.monto)}): su propuesta de la IA ${i.clase === 'pendiente' ? 'sigue pendiente' : `está ${i.estado} y su asiento ${i.asiento || '(no tiene)'} ya no vive`}${i.resumen ? ` (proponía ${i.resumen})` : ''}`; }).join('; ') +
        ' → ya no se pueden aprobar (ese pago está repartido) y la IA contable las sigue contando como abiertas: pueden frenar el cierre del mes. Hay que cerrarlas: a la pendiente se le dice «No es eso»; la aprobada cuyo asiento se reversó se cierra con su motivo. Si la Bandeja no lo hizo al repartir, vuelve a abrirla; si siguen aquí, avisa.'
      : 'Ningún pago repartido tiene una propuesta de la IA pendiente, ni una aprobada cuyo asiento ya no vive.'),
    f(90, 'jornal: protecciones de la capa', 'cuadre', true, 'Ninguna función de c10 es SECURITY DEFINER ni la ejecutan anon o service_role; las tablas con RLS y su guarda; las vistas security_invoker.')
  ];
};
// v_margen_control: sus 6 cuadres con los textos de la base (las sumas, de las obras de abajo); J.margenRojo pone en rojo el 10
const jCtlMargen = () => {
  const os = jObras(), suma = k => Math.round(os.reduce((s, o) => s + (o[k] || 0) * 100, 0)) / 100, rep = J.repartos.filter(r => r.estado === 'aplicado');
  const jor = Math.round(rep.reduce((s, r) => s + r.lineas.filter(l => l.proyecto_id).reduce((t, l) => t + l.monto * 100, 0), 0)) / 100;
  return [
    { orden: 10, cuadre: 'margen: el costo real por obra sumado = el 5xxx con obra del mayor', nivel: 'cuadre', ok: !J.margenRojo, detalle: J.margenRojo
      ? `Las obras suman ${usd(suma('costo_real'))} de costo y el mayor (cuentas de costo con obra) ${usd(suma('costo_real') + 54.5)}: diferencia ${usd(-54.5)}. Avisa: no toques el libro.`
      : `${os.length} obras: su costo real suma ${usd(suma('costo_real'))}, lo mismo que las cuentas de costo con obra del mayor.` },
    { orden: 20, cuadre: 'margen: el ingreso por obra sumado = el 40xx con obra del mayor', nivel: 'cuadre', ok: true, detalle: `El ingreso por obra suma ${usd(suma('ingreso_libro'))}, lo mismo que las cuentas de ingreso con obra del mayor.` },
    { orden: 30, cuadre: 'margen: los conceptos de cada obra suman su costo', nivel: 'cuadre', ok: true, detalle: 'En cada obra, material + mano de obra + subcontratos + equipo + otros = su costo real; y jornales + nómina = su mano de obra real.' },
    { orden: 40, cuadre: 'margen: la mano de obra de jornales en el libro = los repartos aplicados', nivel: 'cuadre', ok: true, detalle: `${rep.length} reparto(s) aplicado(s) con su asiento vivo: ${usd(jor)} de jornales en las obras, lo mismo en el libro.` },
    { orden: 50, cuadre: 'margen: las horas de cada obra = las de la app', nivel: 'cuadre', ok: true, detalle: `${jH(J.horas.filter(x => x.p).reduce((s, x) => s + x.horas, 0))} h con obra en la app, las mismas en el margen; y en cada obra, antes del libro + con pago real + a estándar + del dueño = sus horas.` },
    { orden: 60, cuadre: 'margen: el costo de cada obra = el de Estados (c4)', nivel: 'cuadre', ok: true, detalle: 'Obra por obra, el costo real de aquí es el de «Estados» (su costo por obra, todo el libro, hasta el período 2026-11). Los jornales van a la cuenta de subcontratos: en «Estados» salen dentro de «Subcontratos» y aquí como mano de obra real; el total de cada obra es el mismo.' }
  ];
};
// v_margen_obra (v2): la A del ejemplo (estimado completo), la B sin nada estimado, la F terminada y parcial, y la G con el
// estimado incompleto (horas estimadas, sin presupuesto de material, y ya con material en el libro: ni «se pasa» ni «dentro»).
// La mano de obra estándar depende del burden de jornal_config: sin él no se calcula (y la diferencia queda vacía)
const J_FALTA_BURDEN = 'Falta fijar el burden estándar (0 si no aplica): la mano de obra estándar no se calcula.';
function jEstandar(o, horasEst, costoHoras) {
  const b = J.config.burden_estandar_pct;
  if (!horasEst) return { mano_obra_estandar: 0, mano_obra_estandar_falta: null, burden_estandar_pct: b, costo_con_estandar: o.costo_real };
  if (b == null) return { mano_obra_estandar: null, mano_obra_estandar_falta: J_FALTA_BURDEN, burden_estandar_pct: null, costo_con_estandar: null };
  const est = r2(costoHoras * (1 + b / 100));
  return { mano_obra_estandar: est, mano_obra_estandar_falta: null, burden_estandar_pct: b, costo_con_estandar: r2(o.costo_real + est) };
}
// lo que sigue al estimado: completo o no, los márgenes y la diferencia (como fn_margen_obras)
function jEstimado(o) {
  const nada = o.horas_estimadas == null && o.material_presupuesto == null, moSinTarifa = o.horas_estimadas != null && o.tarifa_estimada == null;
  const moFalta = o.mano_obra_estimada == null && (o.mano_obra_real !== 0 || o.horas_estandar > 0), matFalta = o.material_presupuesto == null && o.material_real !== 0;
  const completo = !(nada || moSinTarifa || moFalta || matFalta), costo = completo ? r2((o.mano_obra_estimada || 0) + (o.material_presupuesto || 0)) : null;
  const falta = nada ? 'No hay estimado: faltan las horas estimadas y el presupuesto de material.' : completo ? null : 'Estimado incompleto: ' + [
    moSinTarifa ? `hay ${jH(o.horas_estimadas)} h estimadas y falta el escenario ${o.escenario} del estimador (o sus tarifas) para valorarlas` : moFalta ? `no tiene horas estimadas y ya lleva mano de obra (${[o.mano_obra_real ? usd(o.mano_obra_real) + ' real' : null, o.horas_estandar ? jH(o.horas_estandar) + ' h a estándar' : null].filter(Boolean).join(' y ')})` : null,
    matFalta ? `no tiene presupuesto de material y ya lleva ${usd(o.material_real)} de material en el libro` : null].filter(Boolean).join('; y ') + '. No da un total que comparar con el costo real: se compara concepto por concepto lo que sí está estimado.';
  return { costo_estimado: costo, estimado_completo: completo, estimado_falta: falta,
    margen_real: r2(o.ingreso_libro - o.costo_real), margen_real_pct: o.ingreso_libro ? Math.round(1000 * (o.ingreso_libro - o.costo_real) / o.ingreso_libro) / 10 : null,
    margen_estimado: o.contrato != null && costo != null ? r2(o.contrato - costo) : null, margen_estimado_pct: o.contrato && costo != null ? Math.round(1000 * (o.contrato - costo) / o.contrato) / 10 : null,
    diferencia: costo != null && o.costo_con_estandar != null ? r2(costo - o.costo_con_estandar) : null, falta: !completo && !nada ? falta : null };
}
// los avisos de una obra, en el orden y con los textos de la base
function jAvisosObra(o, extra) {
  return [o.parcial ? `El libro empieza el 1-oct-2026 y esta obra ya tenía de antes: ${o.parcial_por}. Lo de antes está en QuickBooks: aquí el real es parcial.` : null,
    o.pagos_sin_repartir ? `${o.pagos_sin_repartir} pago(s) de mano de obra de esas semanas siguen sin repartir en la Bandeja: su costo todavía no está en esta obra.` : null,
    o.horas_estandar ? `${jH(o.horas_estandar)} h van a estándar (sin pago real repartido)${o.mano_obra_estandar != null ? ': ' + usd(o.mano_obra_estandar) + ', estándar, no real' : ''}.` : null,
    o.mano_obra_estandar_falta, o.contrato == null ? 'Sin contrato en la ficha de la obra.' : null, o.horas_estimadas == null ? 'Sin horas estimadas.' : null,
    o.horas_estimadas != null && o.tarifa_estimada == null ? `Falta el escenario ${o.escenario} del estimador (o sus tarifas): no hay con qué estimar la mano de obra.` : null,
    o.material_presupuesto == null ? 'Sin presupuesto de material.' : null, extra].filter(Boolean);
}
function jObra(base, horasEst, costoHoras) {
  const o = { ...base }; Object.assign(o, jEstandar(o, horasEst, costoHoras));
  const e = jEstimado(o); Object.assign(o, e); delete o.falta; o.avisos = jAvisosObra(o, e.falta);
  return o;
}
const J_BASE = { cliente: 'C10 PRUEBA Cliente', tipo: 'comercial', estado: 'ejecucion', completado_el: null, libro_desde: '2026-10-01', parcial: false, parcial_por: null, mano_obra_nomina: 0.00, horas_base: null, horas_antes_libro: 0, horas_dueno: 0,
  mano_obra_dueno: null, escenario: 'B', estimado_id: null, asientos: 1 };
const jObraA = () => jObra({ ...J_BASE, proyecto_id: 'c10-prueba-a', obra: 'C10 PRUEBA Obra A', contrato: 12000.00, ingreso_libro: 5000.00, material_real: 750.25, mano_obra_real: 419.19, mano_obra_jornales: 419.19, subcontratos_real: 500.00,
  equipo_real: 75.25, otros_costos_real: 60.00, costo_real: 1804.69, horas_reales: 32.5, horas_co: 6.5, horas_con_pago_real: 16.5, horas_estandar: 16, horas_sin_aprobar: 16, horas_estimadas: 120, tarifa_estimada: 36.25,
  mano_obra_estimada: 4350.00, material_presupuesto: 2500.00, pagos_sin_repartir: 1, asientos: 3 }, 16, 16 * 24);
const jObraB = () => jObra({ ...J_BASE, proyecto_id: 'c10-prueba-b', obra: 'C10 PRUEBA Obra B', contrato: null, ingreso_libro: 0, material_real: 0, mano_obra_real: 38.11, mano_obra_jornales: 38.11, subcontratos_real: 0, equipo_real: 0,
  otros_costos_real: 0, costo_real: 38.11, horas_reales: 1.5, horas_co: 0, horas_con_pago_real: 1.5, horas_estandar: 0, horas_sin_aprobar: 0, horas_estimadas: null, tarifa_estimada: null, escenario: null,
  mano_obra_estimada: null, material_presupuesto: null, pagos_sin_repartir: 0 }, 0, 0);
const jObraF = () => jObra({ ...J_BASE, proyecto_id: 'c10-prueba-f', obra: 'C10 PRUEBA Obra F', cliente: 'C10 PRUEBA Otro cliente', tipo: 'residencial', estado: 'completado', completado_el: '2026-10-31', parcial: true, parcial_por: 'horas, saldo en la apertura',
  contrato: 3000.00, ingreso_libro: 1500.00, material_real: 1200.00, mano_obra_real: 101.62, mano_obra_jornales: 101.62, subcontratos_real: 0, equipo_real: 0, otros_costos_real: 0, costo_real: 1301.62, horas_reales: 4, horas_co: 0, horas_antes_libro: 30,
  horas_con_pago_real: 4, horas_estandar: 0, horas_sin_aprobar: 0, horas_estimadas: 40, tarifa_estimada: 36.25, mano_obra_estimada: 1450.00, material_presupuesto: 800.00, pagos_sin_repartir: 0, asientos: 2 }, 0, 0);
const jObraG = () => jObra({ ...J_BASE, proyecto_id: 'c10-prueba-g', obra: 'C10 PRUEBA Obra G', contrato: 4000.00, ingreso_libro: 0, material_real: 300.00, mano_obra_real: 0, mano_obra_jornales: 0, subcontratos_real: 0, equipo_real: 0,
  otros_costos_real: 0, costo_real: 300.00, horas_reales: 6, horas_co: 0, horas_con_pago_real: 0, horas_estandar: 6, horas_sin_aprobar: 6, horas_estimadas: 40, tarifa_estimada: 36.25, mano_obra_estimada: 1450.00,
  material_presupuesto: null, pagos_sin_repartir: 0 }, 6, 6 * 24);
const jObras = () => [jObraA(), jObraB(), jObraF(), jObraG()];
const jBajar = (filtros, signo) => [{ vista: 'v_libro', campo: 'monto', signo: signo || 1, filtros }];
const J_COSTO = ['5000', '5001', '5010', '5011', '5015', '5019', '5100', '5200', '5300', '5400', '5500', '5600', '5900', '5950'];
const J_NOTA_EST = 'Horas sin pago real repartido × la tarifa de Costos del equipo × (1 + burden estándar), con la tarifa y el burden de hoy (si cambian, este número cambia). No está en el libro.';
// el concepto «total» de fn_margen_obra (v2): su estimado y su diferencia, solo con el estimado completo; si no, su nota dice qué falta
const jTotal = (o, bajar) => ({ concepto: 'total', nivel: 'total', etiqueta: 'Costo de la obra', estimado: o.costo_estimado, real: o.costo_real, estandar: o.mano_obra_estandar, total: o.costo_con_estandar, diferencia: o.diferencia,
  estimado_completo: o.estimado_completo, nota: o.estimado_falta, ...(bajar ? { bajar } : {}) });
// fn_margen_obra de la obra A: la del ejemplo G del informe, entera (conceptos con su «bajar», por cuenta, por CO, por fase, el vacío del cost code, la cobertura y el reparto)
const jMargenA = () => {
  const A = 'c10-prueba-a', no = [J_AS.jornal], o = jObraA(), est = o.mano_obra_estandar, mas = (a, b) => b == null ? null : r2(a + b);
  return { obra: o, avisos: o.avisos,
    conceptos: [
      { concepto: 'material', nivel: 'concepto', etiqueta: 'Material', estimado: 2500.00, real: 750.25, estandar: null, total: 750.25, diferencia: 1749.75, bajar: jBajar({ cuenta: '5100', proyecto_id: A, asiento_id_no: no }) },
      { concepto: 'mano_obra', nivel: 'concepto', etiqueta: 'Mano de obra', estimado: 4350.00, real: 419.19, estandar: est, total: mas(419.19, est), diferencia: est == null ? null : r2(4350 - 419.19 - est), horas_reales: 32.5, horas_estimadas: 120, tarifa_estimada: 36.25,
        bajar: [...jBajar({ cuenta: J_COSTO, proyecto_id: A, asiento_id: no }), ...jBajar({ cuenta: J_COSTO.slice(0, 6), proyecto_id: A, asiento_id_no: no })] },
      { concepto: 'mano_obra_real', nivel: 'detalle', etiqueta: 'Mano de obra real (pagada y repartida)', estimado: null, real: 419.19, estandar: null, total: 419.19, diferencia: null, horas: 16.5, jornales: 419.19, nomina: 0.00,
        bajar: [...jBajar({ cuenta: J_COSTO, proyecto_id: A, asiento_id: no }), ...jBajar({ cuenta: J_COSTO.slice(0, 6), proyecto_id: A, asiento_id_no: no })] },
      { concepto: 'mano_obra_estandar', nivel: 'detalle', etiqueta: 'Mano de obra estándar, no real', estimado: null, real: null, estandar: est, total: est, diferencia: null, horas: 16, burden_estandar_pct: o.burden_estandar_pct,
        nota: o.mano_obra_estandar_falta || J_NOTA_EST },
      { concepto: 'subcontratos', nivel: 'concepto', etiqueta: 'Subcontratos', estimado: null, real: 500.00, estandar: null, total: 500.00, diferencia: null, bajar: jBajar({ cuenta: '5200', proyecto_id: A, asiento_id_no: no }) },
      { concepto: 'equipo', nivel: 'concepto', etiqueta: 'Equipo y renta', estimado: null, real: 75.25, estandar: null, total: 75.25, diferencia: null, bajar: jBajar({ cuenta: '5300', proyecto_id: A, asiento_id_no: no }) },
      { concepto: 'otros', nivel: 'concepto', etiqueta: 'Otros costos de obra', estimado: null, real: 60.00, estandar: null, total: 60.00, diferencia: null, bajar: jBajar({ cuenta: ['5400', '5500', '5600', '5900', '5950'], proyecto_id: A, asiento_id_no: no }) },
      jTotal(o, jBajar({ cuenta: J_COSTO, proyecto_id: A })),
      { concepto: 'ingreso', nivel: 'ingreso', etiqueta: 'Facturado (en el libro)', estimado: 12000.00, real: 5000.00, estandar: null, total: 5000.00, diferencia: null, bajar: jBajar({ cuenta: ['4010', '4020', '4030', '4040'], proyecto_id: A }, -1) }
    ],
    por_cuenta: [
      { cuenta: '5100', nombre: 'Material', concepto: 'material', jornal: false, real: 750.25, asientos: 2, bajar: jBajar({ cuenta: '5100', proyecto_id: A, asiento_id_no: no }) },
      { cuenta: '5200', nombre: 'Subcontratos', concepto: 'subcontratos', jornal: false, real: 500.00, asientos: 1, bajar: jBajar({ cuenta: '5200', proyecto_id: A, asiento_id_no: no }) },
      { cuenta: '5200', nombre: 'Subcontratos', concepto: 'mano_obra', jornal: true, real: 419.19, asientos: 1, bajar: jBajar({ cuenta: '5200', proyecto_id: A, asiento_id: no }) },
      { cuenta: '5300', nombre: 'Equipo y renta', concepto: 'equipo', jornal: false, real: 75.25, asientos: 1, bajar: jBajar({ cuenta: '5300', proyecto_id: A, asiento_id_no: no }) },
      { cuenta: '5400', nombre: 'Permisos e inspecciones', concepto: 'otros', jornal: false, real: 60.00, asientos: 1, bajar: jBajar({ cuenta: '5400', proyecto_id: A, asiento_id_no: no }) }
    ],
    por_co: [
      { co: null, etiqueta: 'Base (sin CO)', horas: 26, horas_con_pago_real: 10, horas_estandar: 16, mano_obra_real: 254.05, mano_obra_estandar: est, material_real: 450.25, subcontratos_real: 500.00, equipo_real: 75.25, otros_costos_real: 60.00, costo_real: 1339.55, ingreso_libro: 5000.00, alcance: null },
      { co: 'CO #1', etiqueta: 'CO #1', horas: 6.5, horas_con_pago_real: 6.5, horas_estandar: 0, mano_obra_real: 165.14, mano_obra_estandar: 0, material_real: 300.00, subcontratos_real: 0, equipo_real: 0, otros_costos_real: 0, costo_real: 465.14, ingreso_libro: 0, alcance: null }
    ],
    por_fase: [
      { fase: 'rough', etiqueta: 'rough', horas: 30.5, horas_con_pago_real: 14.5, mano_obra_real: 368.38, horas_estandar: 16, mano_obra_estandar: est, horas_dueno: 0, horas_antes_libro: 0, otros_costos_libro: 300.00 },
      { fase: 'trim', etiqueta: 'trim', horas: 2, horas_con_pago_real: 2, mano_obra_real: 50.81, horas_estandar: 0, mano_obra_estandar: 0, horas_dueno: 0, horas_antes_libro: 0, otros_costos_libro: 0 }
    ],
    por_cost_code: { hay: false, nota: 'Todavía no hay nada capturado con código en esta obra: las líneas del libro no traen cost code (el ticket no lo lleva). Se compara por obra y por cuenta.', filas: [] },
    cobertura: [
      { usuario_id: J_PER.ana, persona: 'Zzana C10 PRUEBA', es_dueno: false, tarifa: 25, horas: 16.5, horas_con_pago_real: 16.5, pagado: 419.19, horas_estandar: 0, estandar: null, horas_dueno: 0, horas_antes_libro: 0, horas_sin_aprobar: 0 },
      { usuario_id: J_PER.beto, persona: 'Zzbeto C10 PRUEBA', es_dueno: false, tarifa: 24, horas: 16, horas_con_pago_real: 0, pagado: 0.00, horas_estandar: 16, estandar: est, horas_dueno: 0, horas_antes_libro: 0, horas_sin_aprobar: 16 }
    ],
    repartos: [{ reparto_id: '1b4c2dd2-f106-44c3-a7fc-7ed7bdc1434b', estado: 'aplicado', fecha_pago: '2026-11-02', usuario_id: J_PER.ana, persona: 'Zzana C10 PRUEBA', desde: '2026-10-26', hasta: '2026-11-01', monto: 940.00, horas: 37.00,
      monto_obra: 419.19, horas_obra: 16.5, asiento_id: J_AS.jornal, asiento: '2026-000004', reverso_id: null, deshecho_motivo: null }] };
};
const jMargenOtra = o => ({ obra: { ...o }, avisos: o.avisos, conceptos: [jTotal(o)],
  por_cuenta: [], por_co: [], por_fase: [], por_cost_code: { hay: false, nota: 'Todavía no hay nada capturado con código en esta obra. Se compara por obra y por cuenta.', filas: [] }, cobertura: [], repartos: [] });
const err10 = (code, message, hint, status) => ({ status: status || 400, error: { code, message, hint: hint || null, details: null } });
const C10_VISTAS = { v_jornal_pendientes: jPendientes, v_jornal_repartos: jRepartosVista, v_jornal_personas: jPersonasVista, v_jornal_control: jCtl, v_margen_control: jCtlMargen,
  v_margen_obra: jObras, jornal_config: () => [J.config] };
const C10_FN = {
  fn_jornal_propuesta: a => {
    if (!a.p_movimiento) return err10('22023', 'Di de qué movimiento del banco (p_movimiento).');
    if (!!a.p_desde !== !!a.p_hasta) return err10('22023', 'Las fechas a mano van las dos (desde y hasta), o ninguna: entonces va la semana que toca.');
    const extra = Object.keys(a.p_opciones || {}).filter(k => !['incluir_cubiertas', 'motivo'].includes(k));
    if (extra.length) return err10('22023', `Opción desconocida: ${extra.join(', ')}. Las que hay: incluir_cubiertas (true o false) y motivo (un texto).`);
    return jCalc(a.p_movimiento, a.p_desde, a.p_hasta, a.p_opciones);
  },
  fn_jornal_aplicar: a => {
    if (!a.p_visto) return err10('22023', 'Falta «visto»: la huella de lo que viste (la trae fn_jornal_propuesta). Sin ella no se aprueba ni se postea nada.');
    const op = a.p_opciones || {};
    if (J.mx011) { J.mx011 = false; J.horas.push({ id: -1010000099, u: J_PER.ana, fecha: '2026-10-31', p: 'c10-prueba-b', co: null, fase: 'trim', horas: 3 }); }
    const c = jCalc(a.p_movimiento, a.p_desde, a.p_hasta, { incluir_cubiertas: !!op.incluir_cubiertas });
    if (!c.reconocido) return err10('MX008', c.por_que);
    if (c.visto !== a.p_visto) return err10('MX011', `Las horas de ${c.persona.nombre} ${c.periodo.texto} ya no son las que viste (alguien reportó, cambió o borró horas, o cambió una cuenta, entre que miraste y que tocaste): no se aprobó ni se posteó nada. Vuelve a mirar el reparto y acepta lo que veas ahora.`, 'vuelve a pedir fn_jornal_propuesta');
    if (!c.puede_aplicar) return err10('MX008', c.por_que);
    if (J.pideMotivo && !op.motivo) return err10('MX008', 'Este pago puede ser el del cheque 1234 que ya está en el libro por el mismo monto (c6). Si de verdad es otra cosa, dilo en el motivo.');
    J.seq += 1; J.fuera.add(a.p_movimiento);
    const numero = '2026-00000' + J.seq, asiento = { id: 'c1a00000-0000-4000-8000-0000000001' + String(J.seq).padStart(2, '0'), numero, periodo: c.movimiento.periodo, fecha_contable: c.movimiento.fecha };
    const r = { reparto_id: 'c1c00000-0000-4000-8000-0000000000' + String(J.seq).padStart(2, '0'), estado: 'aplicado', movimiento_id: a.p_movimiento, fecha_pago: c.movimiento.fecha, cuenta_banco: '1010', descripcion: c.movimiento.descripcion,
      usuario_id: c.persona.usuario_id, persona: c.persona.nombre, desde: c.periodo.desde, hasta: c.periodo.hasta, regla_periodo: c.periodo.regla, periodo_texto: c.periodo.texto, monto: c.movimiento.monto, horas: c.horas, tarifa_sale: c.tarifa_sale,
      tarifa_equipo: c.tarifa_equipo, cuenta: '5200', cuenta_sin_obra: c.sin_obra ? c.sin_obra.cuenta : null, obras: c.obras,
      lineas: c.lineas.map((l, i) => ({ n: l.n, orden: i + 2, proyecto_id: l.proyecto_id, obra: l.obra, co: l.co, cuenta: l.cuenta, horas: l.horas, monto: l.monto })).concat(c.sin_obra ? [{ n: c.sin_obra.n, orden: c.lineas.length + 2, proyecto_id: null, obra: null, co: null, cuenta: c.sin_obra.cuenta, horas: c.sin_obra.horas, monto: c.sin_obra.monto }] : []),
      asiento_id: asiento.id, asiento: numero, asiento_fecha: asiento.fecha_contable, asiento_vivo: true, avisos: c.avisos, opciones: { incluir_cubiertas: !!op.incluir_cubiertas, ...(op.motivo ? { motivo: op.motivo } : {}) },
      horas_ids: c.detalle.filter(x => x.entra).map(x => x.horas_id), creado_el: new Date(Date.now() + J.seq).toISOString(), creado_por: UID, creado_por_nombre: 'Edgar Prueba',
      deshecho_el: null, deshecho_por: null, deshecho_por_nombre: null, deshecho_motivo: null, reverso_id: null, reverso: null };
    J.repartos.push(r);
    return { reparto_id: r.reparto_id, movimiento_id: r.movimiento_id, estado: 'aplicado', persona: c.persona, desde: r.desde, hasta: r.hasta, regla_periodo: r.regla_periodo, monto: r.monto, horas: r.horas, tarifa_sale: r.tarifa_sale, asiento, tardio: null,
      horas_aprobadas: c.aprueba, lineas: c.lineas, sin_obra: c.sin_obra, avisos: c.avisos, propuesta_ia: c.propuesta_ia, propuestas_ia: c.propuestas_ia,
      nota: `Repartido: ${usd(r.monto)} de ${r.persona} (${r.periodo_texto}, ${jH(r.horas)} h) entre ${new Set(c.lineas.filter(l => l.monto > 0).map(l => l.proyecto_id)).size} obra(s)${c.sin_obra && c.sin_obra.monto > 0 ? ' y lo sin obra' : ''}; asiento ${numero} del ${jDiaT(asiento.fecha_contable, true)}.${c.aprueba.reportes ? ` Quedaron aprobados ${c.aprueba.reportes} reporte(s) de horas.` : ''}` };
  },
  fn_jornal_deshacer: a => {
    if (!a.p_reparto) return err10('22023', 'Di qué reparto.');
    if (String(a.p_motivo || '').trim().length < 3) return err10('22023', 'Deshacer un reparto dice por qué (motivo): queda escrito en él y en el reverso.');
    const r = J.repartos.find(x => x.reparto_id === a.p_reparto); if (!r) return err10('22023', 'No existe ese reparto.');
    if (r.estado === 'deshecho') return err10('MX008', `Ese reparto ya estaba deshecho (el ${jDiaT(r.deshecho_el.slice(0, 10), true)}: ${r.deshecho_motivo}).`);
    J.seq += 1; J.fuera.delete(r.movimiento_id);
    Object.assign(r, { estado: 'deshecho', deshecho_el: new Date().toISOString(), deshecho_por: UID, deshecho_por_nombre: 'Edgar Prueba', deshecho_motivo: String(a.p_motivo).trim(), reverso_id: 'c1a00000-0000-4000-8000-0000000002' + String(J.seq).padStart(2, '0'), reverso: '2026-00000' + J.seq, asiento_vivo: false });
    return { reparto_id: r.reparto_id, estado: 'deshecho', movimiento_id: r.movimiento_id, movimiento_estado: 'pendiente', asiento: { id: r.asiento_id, numero: r.asiento }, reverso: { id: r.reverso_id, numero: r.reverso, fecha_contable: r.fecha_pago },
      por_fuera: false, horas_siguen_aprobadas: r.horas_ids.length, nota: `Reparto deshecho: el asiento ${r.asiento} quedó reversado con el ${r.reverso} y el pago volvió a la Bandeja. Sus ${r.horas_ids.length} reporte(s) de horas siguen aprobados: se aprobó lo que viste, y lo que se deshace es el reparto del pago.` };
  },
  fn_jornal_persona: a => {
    const p = a.p || {}, per = J.personas.find(x => x.usuario_id === p.usuario_id);
    const extra = Object.keys(p).filter(k => !['usuario_id', 'patron', 'movimiento_id', 'cuenta', 'activa', 'nota'].includes(k));
    if (extra.length) return err10('22023', `Clave desconocida: ${extra.join(', ')}. Las que hay: usuario_id, patron, movimiento_id, cuenta, activa y nota.`);
    if (!p.usuario_id) return err10('22023', 'Di quién: usuario_id (su perfil en la app).');
    if (!per) return err10('22023', 'No existe ese perfil en la app.');
    let patron = p.patron ? String(p.patron).trim() : undefined;
    if (!patron && p.movimiento_id) { const m = J.movs.find(x => x.movimiento_id === p.movimiento_id); const t = m ? (/ to (.+?)\s+\d+$/i.exec(m.descripcion) || [])[1] : null; if (!t) return err10('22023', 'De la descripción de ese movimiento no sale un nombre: escribe el patrón (su nombre, como lo pone el banco).'); patron = '\\m' + t.toUpperCase() + '\\M'; }
    if (patron !== undefined && patron.replace(/\\[mM]/g, '').trim().length < 4) return err10('22023', `El patrón no vale: «${patron}» es muy corto: casaría con cualquier pago. Pon el nombre como lo escribe el banco.`);
    const nueva = !per.registrada;
    if (patron !== undefined) per.patron = patron;
    if (nueva) { per.registrada = true; per.activa = true; per.creado_el = new Date().toISOString(); }
    if (p.activa !== undefined) per.activa = !!p.activa;
    // cuántos pagos pendientes reconoce ahora, cuántos casan también con otra persona, y los avisos (como fn_jornal_persona v2)
    const re = x => new RegExp(String(x).replace(/\\m|\\M/g, '\\b'), 'i'), mio = re(per.patron);
    const pend = per.activa ? J.movs.filter(m => !J.fuera.has(m.movimiento_id) && m.monto < 0 && mio.test(m.descripcion)) : [];
    const amb = pend.filter(m => J.personas.some(o => o !== per && o.registrada && o.activa && o.patron && re(o.patron).test(m.descripcion))).length;
    const avisos = [];
    if (per.activa) {
      const pila = per.nombre.split(' ')[0].toUpperCase();
      if (/^[A-Z]{3,}$/.test(pila) && !per.patron.toUpperCase().includes(pila)) avisos.push(`El patrón «${per.patron}» no lleva el nombre de ${per.nombre} («${pila}»): mira que sea el de sus pagos y no el de otra persona.`);
      const dest = new Map(); for (const m of J.movs.filter(x => x.monto < 0 && mio.test(x.descripcion))) { const d = m.descripcion.toUpperCase().replace(/^ZELLE PAYMENT TO /, '').replace(/\s+\d+$/, ''); dest.set(d, (dest.get(d) || 0) + 1); }
      if (dest.size > 1) avisos.push(`El patrón casa con pagos que el banco describe de ${dest.size} formas distintas (${[...dest].sort((x, y) => y[1] - x[1] || x[0].localeCompare(y[0])).map(([d]) => `«${d}»`).join(', ')}): mira que todos sean suyos; si alguno es de un comercio o de otra persona, afina el patrón.`);
    }
    const nota = (!per.activa ? `${per.nombre} queda de baja: sus pagos ya no se reconocen solos.` : amb ? `${amb} de sus ${pend.length} pago(s) pendientes casan también con otra persona: afina el patrón.` : `${per.nombre}: ${pend.length} pago(s) pendientes reconocidos con «${per.patron}».`) + (avisos.length ? ' Ojo: ' + avisos.join(' ') : '');
    return { usuario_id: per.usuario_id, patron: per.patron, cuenta: null, activa: per.activa, nota: per.nota, creado_el: per.creado_el, nombre: per.nombre, nueva, pagos_pendientes: pend.length, ambiguos: amb, avisos, nota_alta: nota };
  },
  fn_jornal_config: a => {
    const p = a.p || {}, extra = Object.keys(p).filter(k => !['cuenta_defecto', 'cuenta_sin_obra', 'burden_estandar_pct', 'aviso_tarifa_pct'].includes(k));
    if (extra.length) return err10('22023', `Clave desconocida: ${extra.join(', ')}.`);
    if (p.cuenta_sin_obra && /^50|^600[05]$/.test(p.cuenta_sin_obra)) return err10('MX004', `La ${p.cuenta_sin_obra} no sirve para lo sin obra: la nómina y el sueldo entran solo por su journal.`);
    if (p.burden_estandar_pct != null && (p.burden_estandar_pct < 0 || p.burden_estandar_pct > 100)) return err10('22023', 'El burden estándar va de 0 a 100 (o nulo).');
    Object.assign(J.config, p, { actualizado: new Date().toISOString(), actualizado_por: UID });
    return { ...J.config };
  },
  fn_jornal_ia: a => jIA(a.p_movimiento || null),
  fn_margen_obra: a => {
    if (!a.p_proyecto) return err10('22023', 'Di qué obra (p_proyecto).');
    if (a.p_proyecto === 'c10-prueba-a') return jMargenA();
    const o = jObras().find(x => x.proyecto_id === a.p_proyecto);
    return o ? jMargenOtra(o) : err10('22023', 'No existe esa obra.');
  }
};

// ---- las facturas (c11, fase 10): la forma EXACTA de v_emision_estado, v_emision_documentos, v_emision_obras,
// v_emision_control y emision_config, y de las respuestas de fn_emision_borrador, fn_emision_documento, fn_emision_emitir,
// fn_emision_descartar, fn_emision_anular, fn_emision_obra, fn_emision_config, fn_emision_envio y fn_emision_pago, con sus
// textos (docs/conta/c11-emision.sql; los ejemplos del banco u10a del 11-nov). La base de mentira calcula como la base (en
// centavos enteros: la retención redondeada una vez por factura, lo que se paga es la resta) para que la pantalla tenga
// algo que enseñar: la pantalla no calcula nada. Y la función de borde `facturas` («pdf», «enviar», «ver»), con la forma de
// supabase/functions/facturas/index.ts. Datos inventados («C11 PRUEBA», «ZZ»). Sin estado.c11, 404 (PGRST205/PGRST202).
const F_EMPRESA = { web: 'c11-pruebas.invalid', correo: 'billing@c11-pruebas.invalid', nombre: 'ZZ Electric C11 PRUEBA, Inc.', licencia: 'ZZ-0000', telefono: '(000) 000-0000', direccion: '100 ZZ Test Ave, Testville, FL 00000' };
const F_COMO_PAGAR = 'Check payable to ZZ Electric C11 PRUEBA, Inc. Please write the invoice number on the check.';
const F_OBRAS = {
  'c11-prueba-a': { obra: 'C11 PRUEBA Oficina Uno', tipo: 'comercial', estado: 'ejecucion', cliente: 'ZZ Cliente Uno', direccion: '1 ZZ Test Rd, Testville, FL 00000', correo: 'zz.uno@c11-pruebas.invalid', contrato: 1850055, a_contratista: false },
  'c11-prueba-b': { obra: 'C11 PRUEBA Casa Dos', tipo: 'residencial', estado: 'ejecucion', cliente: 'ZZ Cliente Dos', direccion: '2 ZZ Test Rd, Testville, FL 00000', correo: 'zz.dos@c11-pruebas.invalid', contrato: 400000, a_contratista: false },
  'c11-prueba-c': { obra: 'C11 PRUEBA Nave Tres', tipo: 'comercial', estado: 'ejecucion', cliente: 'ZZ Contractor C11 PRUEBA, LLC', atencion: 'ZZ Project Manager', correo: 'zz.pm@c11-pruebas.invalid', contrato: 900000, a_contratista: true },
  'c11-prueba-d': { obra: 'C11 PRUEBA Taller Cuatro', tipo: 'servicio', estado: 'completado', cliente: 'ZZ Cliente Cuatro', contrato: null, a_contratista: false }
};
const F = {};
const c2s = c => { const n = Math.abs(c); return `${c < 0 ? '-' : ''}${Math.floor(n / 100)}.${String(n % 100).padStart(2, '0')}`; };   // centavos → «1234.57»
const s2c = s => { const m = /^(-)?(\d+)(?:\.(\d{1,4}))?$/.exec(String(s).trim()); if (!m) return NaN; const v = Number(m[2]) * 10000 + Number(((m[3] || '') + '0000').slice(0, 4)); return (m[1] ? -1 : 1) * v; }; // diezmilésimos
const redC = x => Math.sign(x) * Math.round(Math.abs(x));                       // redondeo de numeric: la mitad, lejos de cero
const MES_C11 = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const fDia = iso => { const [a, m, d] = iso.split('-').map(Number); return `${d}-${MES_C11[m - 1]}-${a}`; };   // fn_emision_dia
const fMas = (iso, n) => { const d = new Date(iso + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };
const fUsd = c => usd(c / 100);
function fReset({ antes = false, sinEmpresa = false } = {}) {
  Object.assign(F, {
    config: { id: 1, ach: true, corte: antes ? '2027-01-01' : HOY, empresa: sinEmpresa ? {} : { ...F_EMPRESA }, pdf_dias: 2, como_pagar: sinEmpresa ? '' : F_COMO_PAGAR, tarjeta_pct: null,
      serie_formato: 'MXP-AAAA-NNNN', terminos_dias: 0, cuenta_recargo: null, terminos_texto: '', actualizado: '2026-11-11T14:00:00+00:00', actualizado_por: UID },
    retObra: { 'c11-prueba-a': 10 },
    hitos: [
      { id: -1110000001, p: 'c11-prueba-a', titulo: 'C11 PRUEBA Rough-in', condicion: 'Due upon passing the rough-in inspection', monto: 123457, estado: 'pendiente', dep: false, orden: 1 },
      { id: -1110000002, p: 'c11-prueba-a', titulo: 'C11 PRUEBA Trim-out', condicion: null, monto: 1726598, estado: 'pendiente', dep: false, orden: 2 },
      { id: -1110000003, p: 'c11-prueba-b', titulo: 'C11 PRUEBA Deposit', condicion: 'Due at contract signing', monto: 120000, estado: 'pendiente', dep: true, orden: 0 },
      { id: -1110000004, p: 'c11-prueba-b', titulo: 'C11 PRUEBA Final', condicion: null, monto: 280000, estado: 'pendiente', dep: false, orden: 1 },
      { id: -1110000005, p: 'c11-prueba-c', titulo: 'C11 PRUEBA Mobilization', condicion: null, monto: 270000, estado: 'pendiente', dep: false, orden: 1 }
    ],
    docs: [], seq: 0, fid: 700, asi: 1, nc: 0, uuid: 0, ctlRojo: false, avisoSinPdf: false,
    fnFalla: null, fnLlamadas: [], enlaces: [], pdfN: 0, resendN: 0
  });
}
const fId = () => `f1100000-0000-4000-8000-${String(++F.uuid).padStart(12, '0')}`;
const fObra = id => F_OBRAS[id];
const fRetDe = p => F.retObra[p] != null ? { pct: F.retObra[p], origen: 'obra' } : { pct: 0, origen: 'ninguna' };
const fDest = p => { const o = fObra(p); return { a_contratista: !!o.a_contratista, cliente: Object.fromEntries(Object.entries({ nombre: o.cliente, atencion: o.a_contratista ? o.atencion : undefined, direccion: o.a_contratista ? undefined : o.direccion, correo: o.correo }).filter(([, v]) => v)) }; };
const fPareceEsp = t => !!t && /[ñ¿¡áéíóú]|\b(de la|del|los|las|obra|materiales|trabajo|factura|mano de obra)\b/i.test(t);
// los totales del documento: las líneas suman el monto; la retención, una vez sobre el monto; lo que se paga, la resta
function fTotales(d) {
  d.monto = d.lineas.reduce((s, l) => s + l.importe, 0);
  d.retencion = d.forma === 'retencion' ? 0 : redC(d.monto * d.retencion_pct / 100);
  d.a_pagar = d.monto - d.retencion;
}
// fn_emision_revisar: los avisos con sus textos y su orden
function fAvisos(d) {
  const v = [], cfg = F.config, o = fObra(d.proyecto_id);
  const av = (codigo, frena, texto) => v.push({ frena, texto, codigo });
  if (HOY < cfg.corte) av('antes_del_corte', true, `Todavía no se factura por la app: hasta el ${fDia(fMas(cfg.corte, -1))} las facturas salen por QuickBooks (el 🧾 de siempre). Este borrador se queda guardado para probar; se podrá emitir desde el ${fDia(cfg.corte)}.`);
  if (!String(cfg.empresa.nombre || '').trim()) av('falta_empresa', true, 'Faltan los datos de la empresa (por lo menos el nombre) en los ajustes de facturación: sin ellos la factura saldría sin membrete.');
  if (!cfg.como_pagar.trim()) av('falta_como_pagar', true, 'Falta el texto «How to pay» en los ajustes de facturación: la factura tiene que decirle al cliente cómo pagar.');
  if (!String((d.cliente || {}).nombre || '').trim()) av('falta_cliente', true, 'Falta a quién se le factura (el nombre del cliente o del contratista): ponlo en el borrador o en la obra.');
  if (o.estado === 'completado') av('obra_cerrada', false, `La obra «${o.obra}» está terminada: se puede facturar igual; solo mira que sea lo que quieres.`);
  if (!d.lineas.length || d.monto <= 0) av('sin_monto', true, 'El borrador no tiene líneas o suma cero: una factura tiene que sumar más de cero.');
  if (d.forma === 'hito') {
    const h = F.hitos.find(x => x.id === d.hito_id);
    if (h.estado === 'cobrado') av('hito_cobrado', true, `El hito «${h.titulo}» ya está marcado como cobrado: no se factura otra vez. Si de verdad hay que facturarlo, ponlo antes en pendiente.`);
    if (h.monto !== d.monto) av('hito_cambio', true, `El hito «${h.titulo}» ahora vale ${fUsd(h.monto)} y este borrador dice ${fUsd(d.monto)}: refresca el borrador y vuelve a mirarlo.`);
  }
  if (['porcentaje', 'tm'].includes(d.forma) && F.hitos.some(h => h.p === d.proyecto_id && h.estado === 'pendiente')) av('obra_con_hitos', false, 'Esta obra tiene hitos pendientes de facturar: una factura que no sale de un hito no mueve ninguno.');
  if (d.forma !== 'retencion' && d.retencion_origen !== 'borrador' && fRetDe(d.proyecto_id).pct !== d.retencion_pct) av('retencion_cambio', true, `La retención de la obra ahora es ${fRetDe(d.proyecto_id).pct} % y este borrador dice ${d.retencion_pct} %: refresca el borrador y vuelve a mirarlo.`);
  if (d.forma !== 'retencion' && d.a_contratista && !d.retencion_pct) av('contratista_sin_retencion', false, 'Es a un contratista y va sin retención: si él retiene un porcentaje, ponlo en la obra antes de emitir.');
  const esp = [d.lineas.some(l => fPareceEsp(l.descripcion) || fPareceEsp(l.detalle)) ? 'una línea' : null, fPareceEsp(d.notas) ? 'las notas' : null].filter(Boolean);
  if (esp.length) av('en_espanol', true, `Parece que hay texto en español (${esp.join(', ')}) y lo que ve el cliente va en inglés: cámbialo, o confirma que está bien así.`);
  return v;
}
const fVisto = d => cripto.createHash('md5').update(JSON.stringify([d.forma, d.proyecto_id, d.hito_id, d.porcentaje, d.cliente, d.notas, d.retencion_pct, d.monto, d.lineas, F.config.empresa, F.config.como_pagar, F.config.terminos_dias, F.config.terminos_texto, F.config.ach])).digest('hex');
const fLineaJ = l => ({ n: l.n, ref: l.ref, tipo: l.tipo, precio: l.precioD / 10000, unidad: l.unidad, detalle: l.detalle, importe: l.importe / 100, cantidad: l.cantD / 10000, descripcion: l.descripcion });
const fNum = v => { const t = String(v); return t.includes('.') ? t.replace(/0+$/, '').replace(/\.$/, '') : t; };
const fPrecioTxt = d => { const t = (d / 10000).toFixed(4).replace(/0{1,2}$/, ''); return t.split('.')[1].length < 2 ? (d / 10000).toFixed(2) : t; };
function fContenido(d, numero, fecha) {
  const cfg = F.config, o = fObra(d.proyecto_id), f = fecha || HOY;
  const h = d.hito_id != null ? F.hitos.find(x => x.id === d.hito_id) : null;
  const antes = F.docs.filter(x => x.proyecto_id === d.proyecto_id && x.estado === 'emitida' && !x.anulado_el && x !== d && x.forma !== 'retencion');
  const antesC = antes.reduce((s, x) => s + x.monto, 0);
  const ret = F.docs.filter(x => x.proyecto_id === d.proyecto_id && x.estado === 'emitida' && !x.anulado_el && x.forma !== 'retencion' && x !== d).reduce((s, x) => s + x.retencion, 0) + (d.forma !== 'retencion' ? d.retencion : 0);
  const esta = d.forma === 'retencion' ? 0 : d.monto;
  const limpio = x => JSON.parse(JSON.stringify(x, (k, v) => v === null ? undefined : v));
  return limpio({
    v: 1, forma: d.forma, numero: numero || null, fecha: f, vence: fMas(f, cfg.terminos_dias),
    terminos: { dias: cfg.terminos_dias, etiqueta: cfg.terminos_dias ? `Net ${cfg.terminos_dias}` : 'Due on receipt', texto: cfg.terminos_texto.trim() || null },
    empresa: cfg.empresa, cliente: d.cliente, a_contratista: d.a_contratista,
    obra: { id: d.proyecto_id, nombre: o.obra, direccion: o.direccion || null, ref: null },
    hito: h ? { id: h.id, titulo: h.titulo, es_deposito: h.dep } : null,
    ordinal: d.forma !== 'retencion' ? antes.length + 1 : null,
    lineas: d.lineas.map(l => ({ n: l.n, tipo: l.tipo, descripcion: l.descripcion, detalle: l.detalle, cantidad: fNum(l.cantD / 10000), unidad: l.unidad, precio: fPrecioTxt(l.precioD), importe: c2s(l.importe), ref: l.ref })),
    totales: { subtotal: c2s(d.monto), retencion_pct: fNum(d.retencion_pct), retencion: c2s(d.retencion), a_pagar: c2s(d.a_pagar), retenido_a_la_fecha: c2s(ret) },
    contrato: o.contrato ? { monto: c2s(o.contrato), facturado_antes: c2s(antesC), esta: c2s(esta), facturado_con_esta: c2s(antesC + esta), pct: (Math.round((antesC + esta) * 1000 / o.contrato) / 10).toFixed(1) } : null,
    como_pagar: cfg.como_pagar.trim() || null, pago_en_linea: { ach: cfg.ach && d.forma !== 'retencion', tarjeta: false }, notas: d.notas || null
  });
}
const fEstado = d => d.estado === 'borrador' ? 'borrador' : d.anulado_el ? 'anulada' : 'emitida';
const fDocJ = d => ({ id: d.id, base: d.base == null ? null : d.base / 100, hito: d.hito_id != null ? F.hitos.find(x => x.id === d.hito_id).titulo : null, obra: fObra(d.proyecto_id).obra, fecha: d.fecha || null, forma: d.forma,
  monto: d.monto / 100, notas: d.notas || null, vence: d.vence || null, estado: fEstado(d), numero: d.numero || null, a_pagar: d.a_pagar / 100, asiento: d.asiento || null, cliente: d.cliente, hito_id: d.hito_id,
  creado_el: d.creado_el, retencion: d.retencion / 100, anulado_el: d.anulado_el || null, emitido_el: d.emitido_el || null, factura_id: d.factura_id || null, porcentaje: d.porcentaje, es_deposito: !!d.es_deposito,
  proyecto_id: d.proyecto_id, nota_credito: d.nota_credito || null, a_contratista: d.a_contratista, retencion_pct: d.retencion_pct, actualizado_el: d.actualizado_el, anulado_motivo: d.anulado_motivo || null, retencion_origen: d.retencion_origen });
function fDocumento(d) {
  if (d.estado === 'borrador') {
    const av = fAvisos(d), frena = av.find(a => a.frena);
    return { visto: fVisto(d), avisos: av, lineas: d.lineas.map(fLineaJ), documento: fDocJ(d), por_que_no: frena ? frena.texto : null, puede_emitir: !frena, vista_previa: fContenido(d, null) };
  }
  return { pdfs: d.pdfs, libro: d.factura_id ? { saldo: d.saldoC / 100, factura_estado: d.anulado_el ? 'anulada' : 'emitida', saldo_retencion: d.saldoRetC / 100 } : null, envios: d.envios, huella: d.huella,
    lineas: d.lineas.map(fLineaJ), contenido: d.contenido, documento: fDocJ(d) };
}
const errF = (code, message, status) => ({ status: status || 400, error: { code, message, hint: null, details: null } });
// una línea T&M de la pantalla (texto) → la de la base; MX005 con el texto de c11 si no vale
function fLineaTm(l, n) {
  const cant = s2c(l.cantidad == null ? '1' : l.cantidad), pre = s2c(l.precio);
  if (!(cant > 0) || !Number.isFinite(pre) || pre === 0 || (pre < 0 && (l.tipo || 'otro') !== 'otro')) return { error: errF('MX005', `Línea ${n}: la cantidad va de más de 0 y el precio no da cero, con cuatro decimales como mucho; un precio negativo (un descuento) va solo en una línea de tipo «otro».`) };
  return { n, ref: null, tipo: l.tipo || 'otro', precioD: pre, unidad: l.unidad || null, detalle: l.detalle || null, importe: redC(cant * pre / 1e6), cantD: cant, descripcion: String(l.descripcion || '').trim() };
}
const C11_FN = {
  fn_emision_borrador: a => {
    const p = a.p || {};
    const extra = Object.keys(p).filter(k => !['documento', 'forma', 'proyecto_id', 'hito_id', 'porcentaje', 'lineas', 'descripcion', 'detalle', 'retencion_pct', 'cliente', 'notas'].includes(k));
    if (extra.length) return errF('22023', `Clave desconocida en el borrador: ${extra.join(', ')}.`);
    let d, nuevo = false;
    if (p.documento) {
      d = F.docs.find(x => x.id === p.documento);
      if (!d) return errF('22023', 'No existe ese borrador.');
      if (d.estado !== 'borrador') return errF('MX008', `La factura ${d.numero} ya se emitió: no se cambia. Si está mal, se anula con su nota de crédito.`);
    } else {
      const forma = p.forma;
      if (!['hito', 'porcentaje', 'tm', 'retencion'].includes(forma)) return errF('22023', 'Di qué factura es (forma): hito, porcentaje, tm o retencion.');
      if (forma === 'hito') {
        if (p.hito_id == null) return errF('22023', 'Di qué hito se factura (hito_id).');
        const h = F.hitos.find(x => x.id === Number(p.hito_id)); if (!h) return errF('22023', 'No existe ese hito.');
        const ya = F.docs.find(x => x.hito_id === h.id && x.estado === 'borrador');
        if (ya) return { nuevo: false, ...fDocumento(ya) };
        const em = F.docs.find(x => x.hito_id === h.id && x.estado === 'emitida' && !x.anulado_el);
        if (em) return errF('MX008', `El hito «${h.titulo}» ya se facturó: factura ${em.numero} del ${fDia(em.fecha)}. No se hace otra; si aquella está mal, se anula con su nota de crédito.`);
        if (h.estado === 'cobrado') return errF('MX008', `El hito «${h.titulo}» ya está marcado como cobrado: no se factura otra vez. Si de verdad hay que facturarlo, ponlo antes en pendiente.`);
        d = { forma, proyecto_id: h.p, hito_id: h.id, es_deposito: h.dep, lineas: [{ n: 1, ref: { hito_id: h.id }, tipo: 'hito', precioD: h.monto * 100, unidad: null, detalle: h.condicion, importe: h.monto, cantD: 10000, descripcion: h.titulo }] };
      } else {
        if (!fObra(p.proyecto_id)) return errF('22023', 'No existe esa obra.');
        d = { forma, proyecto_id: p.proyecto_id, hito_id: null, es_deposito: false, lineas: [] };
        if (forma === 'retencion') {
          const ya = F.docs.find(x => x.forma === 'retencion' && x.estado === 'borrador' && x.proyecto_id === p.proyecto_id);
          if (ya) return { nuevo: false, ...fDocumento(ya) };
          d.lineas = F.docs.filter(x => x.proyecto_id === p.proyecto_id && x.estado === 'emitida' && !x.anulado_el && x.saldoRetC > 0)
            .map((x, i) => ({ n: i + 1, ref: { numero: x.numero, factura_id: x.factura_id }, tipo: 'retencion', precioD: x.saldoRetC * 100, unidad: null, detalle: null, importe: x.saldoRetC, cantD: 10000, descripcion: `Retainage withheld on invoice ${x.numero} (${MES_EN_F[Number(x.fecha.slice(5, 7)) - 1]} ${Number(x.fecha.slice(8))}, ${x.fecha.slice(0, 4)})` }));
          if (!d.lineas.length) return errF('MX008', `La obra «${fObra(p.proyecto_id).obra}» no tiene retención por reclamar en el libro.`);
        }
      }
      nuevo = true;
      Object.assign(d, { id: fId(), estado: 'borrador', porcentaje: null, base: null, notas: null, creado_el: new Date().toISOString(), pdfs: [], envios: [] });
      const dest = fDest(d.proyecto_id); d.a_contratista = dest.a_contratista; d.cliente = dest.cliente;
      const r = fRetDe(d.proyecto_id); d.retencion_pct = d.forma === 'retencion' ? 0 : r.pct; d.retencion_origen = d.forma === 'retencion' ? 'ninguna' : r.origen;
      F.docs.push(d);
    }
    // lo que llega (forma porcentaje: el % del contrato; tm: las líneas; las demás: el texto de su línea)
    if (d.forma === 'porcentaje' && (p.porcentaje != null || nuevo)) {
      const pc = s2c(p.porcentaje == null ? d.porcentaje : p.porcentaje);
      if (!(pc > 0) || pc > 1000000) { if (nuevo) F.docs.pop(); return errF('MX005', 'El porcentaje va de más de 0 a 100 (30 = 30 %), con cuatro decimales como mucho.'); }
      const o = fObra(d.proyecto_id); d.porcentaje = pc / 10000; d.base = o.contrato;
      d.lineas = [{ n: 1, ref: null, tipo: 'porcentaje', precioD: redC(o.contrato * pc / 1e6) * 100, unidad: null, detalle: d.lineas[0] ? d.lineas[0].detalle : null, importe: redC(o.contrato * pc / 1e6), cantD: 10000,
        descripcion: `Progress billing — ${fNum(pc / 10000)}% of contract amount (${fUsd(o.contrato)})` }];
    }
    if (d.forma === 'tm' && p.lineas) {
      const ls = []; for (const [i, l] of p.lineas.entries()) { const x = fLineaTm(l, i + 1); if (x.error) { if (nuevo) F.docs.pop(); return x.error; } ls.push(x); }
      d.lineas = ls;
    }
    if (p.descripcion !== undefined && d.lineas[0] && ['hito', 'porcentaje'].includes(d.forma)) d.lineas[0].descripcion = String(p.descripcion).trim() || d.lineas[0].descripcion;
    if (p.detalle !== undefined && d.lineas[0] && ['hito', 'porcentaje'].includes(d.forma)) d.lineas[0].detalle = p.detalle || null;
    if (p.retencion_pct !== undefined && d.forma !== 'retencion') {
      if (p.retencion_pct === null) { const r = fRetDe(d.proyecto_id); d.retencion_pct = r.pct; d.retencion_origen = r.origen; }
      else { const t = s2c(p.retencion_pct); if (!(t >= 0) || t >= 1000000) return errF('MX005', 'La retención va de 0 a menos de 100 (10 = 10 %), con dos decimales como mucho.'); d.retencion_pct = t / 10000; d.retencion_origen = 'borrador'; }
    } else if (!p.documento || Object.keys(p).length === 1) {
      // refrescar: lo de fuera otra vez (el hito, la retención de la obra)
      if (d.forma === 'hito') { const h = F.hitos.find(x => x.id === d.hito_id); d.lineas[0].importe = h.monto; d.lineas[0].precioD = h.monto * 100; }
      if (d.retencion_origen !== 'borrador' && d.forma !== 'retencion') { const r = fRetDe(d.proyecto_id); d.retencion_pct = r.pct; d.retencion_origen = r.origen; }
    }
    if (p.cliente !== undefined) d.cliente = p.cliente === null ? fDest(d.proyecto_id).cliente : Object.fromEntries(Object.entries(p.cliente).filter(([, v]) => v));
    if (p.notas !== undefined) d.notas = p.notas || null;
    fTotales(d);
    d.actualizado_el = new Date().toISOString();
    return { nuevo, ...fDocumento(d) };
  },
  fn_emision_documento: a => { const d = F.docs.find(x => x.id === a.p_documento); return d ? fDocumento(d) : errF('22023', 'No existe ese documento.'); },
  fn_emision_descartar: a => {
    const d = F.docs.find(x => x.id === a.p_documento); if (!d) return errF('22023', 'No existe ese borrador.');
    if (d.estado !== 'borrador') return errF('MX008', `La factura ${d.numero} ya se emitió: no se tira. Si está mal, se anula con su nota de crédito.`);
    F.docs = F.docs.filter(x => x !== d);
    return { documento: d.id, descartado: true };
  },
  fn_emision_emitir: a => {
    const d = F.docs.find(x => x.id === a.p_documento); if (!d) return errF('22023', 'No existe ese borrador.');
    const op = a.p_opciones || {};
    if (Object.keys(op).some(k => k !== 'idioma_revisado')) return errF('22023', `Opción desconocida: ${Object.keys(op).filter(k => k !== 'idioma_revisado').join(', ')}. La que hay: idioma_revisado.`);
    if (d.estado === 'emitida') return errF('MX008', `Ese borrador ya se emitió: es la factura ${d.numero} del ${fDia(d.fecha)}. No se emite dos veces.`);
    if (a.p_visto !== fVisto(d)) return errF('MX011', 'El borrador ya no es el que viste (cambió en otra pestaña, o cambiaron los ajustes de la factura): no se emitió nada. Vuelve a mirarlo y emite otra vez.');
    for (const x of fAvisos(d)) if (x.frena && !(x.codigo === 'en_espanol' && op.idioma_revisado)) return errF(/_cambio$/.test(x.codigo) ? 'MX011' : 'MX008', x.texto);
    F.seq += 1;
    Object.assign(d, { estado: 'emitida', numero: `MXP-${HOY.slice(0, 4)}-${String(F.seq).padStart(4, '0')}`, fecha: HOY, vence: fMas(HOY, F.config.terminos_dias), factura_id: ++F.fid, asiento: `2026-${String(++F.asi).padStart(6, '0')}`,
      emitido_el: new Date().toISOString(), saldoC: d.forma === 'retencion' ? 0 : d.a_pagar, saldoRetC: d.forma === 'retencion' ? 0 : d.retencion });
    if (d.forma === 'retencion') { d.factura_id = null; d.asiento = null; }
    d.contenido = fContenido(d, d.numero, d.fecha);
    d.huella = sha(JSON.stringify(d.contenido));
    const h = d.hito_id != null ? F.hitos.find(x => x.id === d.hito_id) : null; if (h) h.estado = 'facturado';
    return { fecha: d.fecha, monto: d.monto / 100, sigue: 'El PDF y el envío: la función de facturas lo pinta con este contenido, lo sube y lo registra.', vence: d.vence, estado: 'emitida', huella: d.huella, numero: d.numero, a_pagar: d.a_pagar / 100,
      ...(d.asiento ? { asiento: d.asiento } : {}), hito_id: d.hito_id, documento: d.id, retencion: d.retencion / 100, ...(d.factura_id ? { factura_id: d.factura_id } : {}), hito_estado: h ? 'facturado' : null, fecha_contable: d.fecha };
  },
  fn_emision_anular: a => {
    if (!String(a.p_motivo || '').trim()) return errF('22023', 'Anular una factura dice por qué (el motivo): queda escrito con ella.');
    const d = F.docs.find(x => x.id === a.p_documento); if (!d) return errF('22023', 'No existe esa factura.');
    if (d.estado === 'borrador') return errF('MX008', 'Un borrador no se anula: se tira (todavía no es una factura).');
    if (d.anulado_el) return errF('MX008', `La factura ${d.numero} ya estaba anulada (${d.nota_credito}).`);
    if (d.cobradoC) return errF('MX008', `La factura #${d.numero} tiene cobros aplicados por ${fUsd(d.cobradoC)}: primero se deshacen los cobros (o se reversa el cobro) y después se anula.`);
    F.nc += 1;
    Object.assign(d, { anulado_el: new Date().toISOString(), anulado_motivo: String(a.p_motivo).trim(), nota_credito: d.factura_id ? `NC-2026-${String(F.nc).padStart(4, '0')}` : null, saldoC: 0, saldoRetC: 0 });
    const h = d.hito_id != null ? F.hitos.find(x => x.id === d.hito_id) : null; if (h) h.estado = 'pendiente';
    return { sigue: 'Si el cliente ya la recibió, avísale. La buena es un borrador nuevo, con número nuevo; su enlace de pago, si tenía, hay que desactivarlo.', numero: d.numero, anulada: true,
      ...(d.factura_id ? { asiento: `2026-${String(++F.asi).padStart(6, '0')}`, nota_credito: d.nota_credito, fecha_contable: HOY } : { sin_asiento: true }), hito_id: d.hito_id, documento: d.id, hito_estado: h ? 'pendiente' : null };
  },
  fn_emision_obra: a => {
    const p = a.p || {};
    if (!fObra(p.proyecto_id)) return errF('22023', 'No existe esa obra.');
    if (p.retencion_pct === null || p.retencion_pct === undefined) delete F.retObra[p.proyecto_id];
    else { const t = s2c(p.retencion_pct); if (!(t >= 0) || t >= 1000000) return errF('MX005', 'La retención va de 0 a menos de 100 (10 = 10 %), con dos decimales como mucho.'); F.retObra[p.proyecto_id] = t / 10000; }
    const r = fRetDe(p.proyecto_id);
    return { nota: p.nota || null, retencion: { pct: r.pct, origen: r.origen }, actualizado: new Date().toISOString(), proyecto_id: p.proyecto_id, retencion_pct: F.retObra[p.proyecto_id] == null ? null : F.retObra[p.proyecto_id], actualizado_por: UID };
  },
  fn_emision_config: a => {
    const p = a.p || {};
    const sobra = Object.keys(p).filter(k => !['corte', 'serie_formato', 'terminos_dias', 'terminos_texto', 'empresa', 'como_pagar', 'ach', 'tarjeta_pct', 'cuenta_recargo', 'pdf_dias'].includes(k));
    if (sobra.length) return errF('22023', `Clave desconocida en los ajustes: ${sobra.join(', ')}. Las que hay: corte, serie_formato, terminos_dias, terminos_texto, empresa, como_pagar, ach, tarjeta_pct, cuenta_recargo y pdf_dias.`);
    if (p.corte !== undefined && !/^\d{4}-\d{2}-\d{2}$/.test(String(p.corte))) return errF('22007', 'El corte es una fecha AAAA-MM-DD (por ejemplo 2027-01-01).');
    if (p.corte !== undefined && F.docs.some(d => d.estado === 'emitida') && p.corte > F.docs.filter(d => d.estado === 'emitida').map(d => d.fecha).sort()[0]) return errF('MX008', `Ya hay facturas emitidas por la app desde el ${fDia(F.docs.filter(d => d.estado === 'emitida').map(d => d.fecha).sort()[0])}: el corte no se pone después de esa fecha.`);
    if (p.tarjeta_pct != null) return errF('MX008', 'La tarjeta todavía no se puede encender: lo que el cliente pagara de más por el recargo, los cobros en línea lo dejarían como un anticipo de la obra (un saldo a su favor), no como un ingreso, y el libro quedaría mal. Queda apagada hasta que eso se arregle y se confirmen con Stripe y con el CPA las reglas del recargo. Mientras, el pago en línea es por cuenta de banco (ACH).');
    if (p.terminos_dias !== undefined && !(Number.isInteger(p.terminos_dias) && p.terminos_dias >= 0 && p.terminos_dias <= 120)) return errF('22023', 'Los términos van de 0 (al recibirla) a 120 días.');
    for (const k of ['corte', 'serie_formato', 'terminos_dias', 'terminos_texto', 'como_pagar', 'ach', 'pdf_dias']) if (p[k] !== undefined) F.config[k] = p[k];
    if (p.empresa !== undefined) F.config.empresa = p.empresa;
    F.config.actualizado = new Date().toISOString();
    return { ...F.config, tarjeta_lista: false };
  },
  fn_emision_envio: a => {
    const d = F.docs.find(x => x.id === a.p_documento); if (!d) return errF('22023', 'No existe ese documento.');
    const e = a.p_envio || {}, medio = e.medio || 'correo';
    if (d.estado !== 'emitida') return errF('MX008', 'Un borrador no se manda: se emite primero.');
    if (d.anulado_el) return errF('MX008', `La factura ${d.numero} está anulada: ya no se manda.`);
    if (!String(e.para || '').trim()) return errF('22023', 'Di a quién se mandó (para): en un correo, su dirección (o varias, separadas por comas); en mano, quién la recibió.');
    if (e.resend_id) { const ya = d.envios.find(x => x.resend_id === e.resend_id); if (ya) return { envio: { n: ya.n, id: ya.id, para: ya.para, medio: ya.medio, enviado_el: ya.enviado_el }, numero: d.numero, reenvio: ya.n > 1, documento: d.id, ya_estaba: true }; }
    if (medio === 'correo' && !d.pdfs.length) return errF('MX008', `La factura ${d.numero} todavía no tiene su PDF registrado: primero el PDF, después el correo.`);
    const x = { n: d.envios.length + 1, cc: e.cc || null, id: fId(), nota: e.nota || null, para: e.para, medio, asunto: e.asunto || null, pdf_id: medio === 'correo' ? (e.pdf_id || d.pdfs[d.pdfs.length - 1].id) : (d.pdfs.length ? d.pdfs[d.pdfs.length - 1].id : null), resend_id: e.resend_id || null, enviado_el: new Date().toISOString() };
    d.envios.push(x);
    return { envio: { n: x.n, id: x.id, para: x.para, medio: x.medio, enviado_el: x.enviado_el }, numero: d.numero, reenvio: x.n > 1, documento: d.id, ya_estaba: false };
  },
  fn_emision_pago: a => {
    const d = F.docs.find(x => x.id === a.p_documento); if (!d) return errF('22023', 'No existe ese documento.');
    if (d.estado !== 'emitida') return errF('MX008', 'Un borrador no tiene enlace de pago: se emite primero.');
    const e = F.enlaces.filter(x => x.doc === d.id && ['creando', 'activo'].includes(x.estado)).pop();
    const no = d.anulado_el ? 'La factura está anulada: no se cobra.' : d.forma === 'retencion' ? 'La factura de la retención no lleva enlace propio: se cobra por cheque o transferencia, o con el enlace «con la retención» de cada factura, desde Cobros en línea.'
      : !F.config.ach ? 'El pago en línea está apagado en los ajustes de facturación.' : d.saldoC <= 0 ? 'La factura ya no debe nada en el libro.' : null;
    const nombre = F.config.empresa.nombre || 'Invoice';
    return Object.fromEntries(Object.entries({ saldo: d.saldoC / 100, numero: d.numero, stripe: no ? null : { monto: d.saldoC / 100, moneda: 'usd', nombre: `Invoice ${d.numero} · ${nombre}`, metodos: ['us_bank_account'], centavos: d.saldoC, descripcion: `Invoice ${d.numero} — ${nombre}`, un_solo_uso: true, con_retencion: false },
      a_pagar: d.a_pagar / 100, enlace: e ? { id: e.id, url: e.url, vale: e.estado === 'activo' && e.monto === d.saldoC, monto: e.monto / 100, estado: e.estado, creado_el: e.creado_el, con_retencion: false } : null,
      tarjeta: { por_que: 'La tarjeta está apagada: los cobros en línea dejarían el recargo como un anticipo de la obra, no como un ingreso. Se enciende cuando eso se arregle y se confirmen con Stripe y con el CPA las reglas del recargo.', ofrecida: false },
      en_linea: !no, documento: d.id, por_que_no: no, factura_id: d.factura_id, saldo_retencion: d.saldoRetC / 100 }).filter(([, v]) => v !== null && v !== undefined));
  }
};
const MES_EN_F = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
// las vistas (security_invoker: solo el dueño ve filas)
function fEstadoVista() {
  const cfg = F.config, porApp = HOY >= cfg.corte, em = F.docs.filter(d => d.estado === 'emitida');
  const falta = [!String(cfg.empresa.nombre || '').trim() ? 'empresa' : null, !cfg.como_pagar.trim() ? 'como_pagar' : null].filter(Boolean);
  const diasCorte = Math.max(0, Math.round((new Date(cfg.corte + 'T12:00:00Z') - new Date(HOY + 'T12:00:00Z')) / 86400000));
  // (como la base: el año de HOY, también antes del corte; fn_emision_pegado sí usa el año del corte)
  const anioSig = HOY.slice(0, 4);
  return [{ hoy: HOY, corte: cfg.corte, por_la_app: porApp, camino: porApp ? 'app' : 'quickbooks',
    texto: porApp ? `Desde el ${fDia(cfg.corte)} las facturas se emiten aquí, con su número de la serie del año.` : `Hasta el ${fDia(fMas(cfg.corte, -1))} las facturas salen por QuickBooks (el 🧾 de siempre). Aquí se pueden preparar borradores para probar; se podrán emitir desde el ${fDia(cfg.corte)}.`,
    dias_para_el_corte: diasCorte, serie_formato: cfg.serie_formato, siguiente_numero: `MXP-${anioSig}-${String(F.seq + 1).padStart(4, '0')}`, terminos_dias: cfg.terminos_dias, falta, puede_emitir: porApp && !falta.length,
    pago_en_linea: cfg.ach, tarjeta: false, borradores: F.docs.filter(d => d.estado === 'borrador').length, emitidas: em.filter(d => !d.anulado_el).length, anuladas: em.filter(d => d.anulado_el).length,
    sin_pdf: em.filter(d => !d.anulado_el && !d.pdfs.length).length, sin_mandar: em.filter(d => !d.anulado_el && !d.envios.length).length }];
}
const fDocsVista = () => F.docs.map(d => ({ id: d.id, estado: fEstado(d), forma: d.forma, proyecto_id: d.proyecto_id, obra: fObra(d.proyecto_id).obra, cliente: (d.cliente || {}).nombre || null, a_contratista: d.a_contratista,
  hito_id: d.hito_id, hito: d.hito_id != null ? F.hitos.find(x => x.id === d.hito_id).titulo : null, es_deposito: !!d.es_deposito, numero: d.numero || null, fecha: d.fecha || null, vence: d.vence || null, monto: d.monto / 100,
  retencion_pct: d.retencion_pct, retencion: d.retencion / 100, a_pagar: d.a_pagar / 100, factura_id: d.factura_id || null, asiento: d.asiento || null, saldo: d.estado === 'emitida' && d.factura_id ? d.saldoC / 100 : null,
  saldo_retencion: d.estado === 'emitida' && d.factura_id ? d.saldoRetC / 100 : null, nota_credito: d.nota_credito || null, anulado_el: d.anulado_el || null, anulado_motivo: d.anulado_motivo || null, pdfs: d.pdfs.length,
  pdf_ruta: d.pdfs.length ? d.pdfs[d.pdfs.length - 1].ruta : null, pdf_el: d.pdfs.length ? d.pdfs[d.pdfs.length - 1].creado_el : null, envios: d.envios.length, enviado_el: d.envios.length ? d.envios[d.envios.length - 1].enviado_el : null,
  enviado_a: d.envios.length ? d.envios[d.envios.length - 1].para : null, visto: d.estado === 'borrador' ? fVisto(d) : null, creado_el: d.creado_el, actualizado_el: d.actualizado_el, emitido_el: d.emitido_el || null }));
const fObrasVista = () => Object.entries(F_OBRAS).map(([id, o]) => {
  const em = F.docs.filter(d => d.proyecto_id === id && d.estado === 'emitida' && !d.anulado_el && d.forma !== 'retencion');
  const fac = em.reduce((s, d) => s + d.monto, 0), hs = F.hitos.filter(h => h.p === id).sort((x, y) => x.orden - y.orden), r = fRetDe(id);
  return { proyecto_id: id, obra: o.obra, tipo: o.tipo, estado: o.estado, cliente: o.cliente, a_contratista: o.a_contratista, contrato: o.contrato == null ? null : o.contrato / 100, facturado: fac / 100, facturas: em.length,
    por_facturar: o.contrato == null ? null : (o.contrato - fac) / 100, retencion_pct: r.pct, retencion_origen: r.origen, retenido: em.reduce((s, d) => s + d.saldoRetC, 0) / 100,
    hitos_pendientes: hs.filter(h => h.estado === 'pendiente').length, hitos_pendientes_monto: hs.filter(h => h.estado === 'pendiente').reduce((s, h) => s + h.monto, 0) / 100,
    hitos: hs.map(h => { const f = F.docs.find(d => d.hito_id === h.id && d.estado === 'emitida' && !d.anulado_el), b = F.docs.find(d => d.hito_id === h.id && d.estado === 'borrador');
      return { id: h.id, monto: h.monto / 100, puede: h.estado === 'pendiente' && !f && !b, estado: h.estado, titulo: h.titulo, factura: f ? f.numero : null, borrador: b ? b.id : null, es_deposito: h.dep }; }),
    borradores: F.docs.filter(d => d.proyecto_id === id && d.estado === 'borrador').length, ingreso_listo: true };
});
function fControl() {
  const em = F.docs.filter(d => d.estado === 'emitida'), vivas = em.filter(d => !d.anulado_el && d.factura_id), cfg = F.config;
  const faltaE = [!String(cfg.empresa.nombre || '').trim() ? 'los datos de la empresa' : null, !cfg.como_pagar.trim() ? 'el texto «How to pay»' : null].filter(Boolean).join(' y ');
  const sinPdf = F.avisoSinPdf ? em.filter(d => !d.anulado_el) : [];
  const f = (orden, cuadre, nivel, ok, detalle) => ({ ok, nivel, orden, cuadre, detalle });
  return [
    f(10, 'facturas: cada factura emitida por la app = su asiento, al centavo', 'cuadre', !F.ctlRojo, F.ctlRojo ? 'la factura MXP-2026-0001 (prueba): su asiento lleva $1,111.11 por cobrar y debía llevar $1,111.12 → el libro y la factura no dicen lo mismo: no la toques a mano; avisa.'
      : `${vivas.length} factura(s) viva(s) emitida(s) por la app: cada una está en el libro con su asiento, al centavo (lo que se cobra ahora más lo retenido es su monto).`),
    f(20, 'facturas: la serie de cada año, sin huecos ni repetidos', 'cuadre', true, em.length ? `Cada año va seguido desde el 1 y su contador está en el último: ${HOY.slice(0, 4)}, ${F.seq} número(s).` : 'Todavía no se ha emitido ninguna factura por la app: la serie empieza en el 1.'),
    f(30, 'facturas: cada documento emitido sigue sellado', 'cuadre', true, `${em.length} documento(s) emitido(s): su contenido es el que se selló, sus líneas suman su monto y su fila de facturas dice lo mismo.`),
    f(40, 'facturas: ningún hito facturado dos veces', 'cuadre', true, 'Ningún hito tiene dos facturas vivas con alguna emitida por la app.'),
    f(50, 'facturas: cada PDF registrado sigue en su sitio', 'aviso', true, `${em.reduce((s, d) => s + d.pdfs.length, 0)} PDF registrado(s): todos siguen en el bucket facturas y miden lo que se registró (su sha256 queda guardado para comparar la copia que tenga el cliente).`),
    f(60, `facturas: ninguna emitida hace más de ${cfg.pdf_dias} día(s) sin su PDF`, 'aviso', !sinPdf.length, sinPdf.length ? `${sinPdf.map(d => `${d.numero} (del ${fDia(d.fecha)})`).join(', ')} → están emitidas y en el libro, pero sin su PDF: ábrelas en Facturación y genera el PDF.` : 'Cada factura emitida tiene su PDF (o es de estos días).'),
    f(62, `facturas: ninguna emitida hace más de ${cfg.pdf_dias} día(s) sin mandar`, 'aviso', true, 'Cada factura emitida se mandó o se entregó (o es de estos días).'),
    f(70, 'facturas: ninguna retención que parezca un porcentaje', 'aviso', true, 'Ninguna factura hecha fuera de la app trae una retención entre 0 y 100 que no cuadre con el porcentaje de su obra.'),
    f(72, 'facturas: desde el corte, todas salen de la app', 'aviso', true, `Ninguna factura fechada desde el ${fDia(cfg.corte)} se hizo fuera de la app.`),
    f(75, 'facturas: ninguna anulación a medias, ningún hito con dos facturas de antes', 'aviso', true, 'Toda factura de la app anulada en el libro está cerrada aquí, ninguna factura de la retención reclama lo de una anulada, y ningún hito trae dos facturas vivas de antes.'),
    f(80, 'facturas: el pago en línea, solo por cuenta de banco', 'aviso', true, 'Ninguna factura de la app se cobró con tarjeta, y el porcentaje de la tarjeta está vacío (apagada).'),
    f(85, 'facturas: los datos de la empresa y el «How to pay»', 'aviso', !faltaE || HOY < fMas(cfg.corte, -14), !faltaE ? 'Los datos de la empresa y el «How to pay» están puestos.' : HOY < fMas(cfg.corte, -14) ? `Faltan ${faltaE} en los ajustes de facturación; se piden desde dos semanas antes del corte (${fDia(cfg.corte)}).`
      : `Faltan ${faltaE} en los ajustes de facturación → sin eso no se puede emitir ninguna factura: ponlos en Facturación → Ajustes (en inglés: los ve el cliente).`),
    f(90, 'facturas: protecciones de la capa', 'cuadre', true, 'Solo la función del número corre con los permisos del dueño de la base (es de trigger y nadie la ejecuta suelta); ninguna la ejecutan anon ni service_role; las tablas con RLS y su guarda; las vistas security_invoker.')
  ];
}
const C11_VISTAS = { v_emision_estado: fEstadoVista, v_emision_documentos: fDocsVista, v_emision_obras: fObrasVista, v_emision_control: fControl, emision_config: () => [{ ...F.config }] };
// el aviso de la función cuando el «How to pay» habla de un enlace y el PDF va sin él (index.ts: hablaDeEnlace)
const F_HABLA_DE_ENLACE = /\b(link|links|click|button|stripe|qr)\b|\bpay(ing)? online\b|\bonline payment/i;
const F_AVISO_ENLACE = 'El «How to pay» de esta factura habla de un enlace de pago y este PDF va sin él. Para las próximas, cámbialo en Facturas → Ajustes para que sirva con enlace y sin él: cuando una factura lo lleva, el PDF y el correo añaden solos el enlace, lo que cobra y su código QR.';
// La función de borde `facturas` (supabase/functions/facturas), con la forma de sus respuestas: { ok, … } o { ok: false, codigo, error, datos? }.
// Pide el dueño con aal2 (lo lee del JWT). F.fnFalla: la siguiente respuesta mala ({ estado, cuerpo }).
function funcionFacturas(b, auth) {
  let aal = null; try { aal = JSON.parse(Buffer.from(String(auth).replace(/^Bearer /, '').split('.')[1], 'base64url').toString()).aal; } catch { /* sin sesión */ }
  const V = { version: 'facturas 2026-11-12.2' };
  if (b.accion === 'salud') return { cuerpo: { ...V, ok: true, funcion: 'facturas', resend: true, stripe: 'real', falta: [] } };
  if (aal !== 'aal2') return { estado: 403, cuerpo: { ...V, ok: false, codigo: 'MFA', error: 'Falta el código del teléfono: entra otra vez con él (las facturas lo piden).' } };
  if (F.fnFalla) { const f = F.fnFalla; F.fnFalla = null; return { estado: f.estado, cuerpo: { ...V, ok: false, ...f.cuerpo } }; }
  const d = F.docs.find(x => x.id === b.documento);
  if (!d) return { estado: 409, cuerpo: { ...V, ok: false, codigo: '22023', error: 'No existe ese documento.' } };
  if (d.estado === 'borrador') return { estado: 409, cuerpo: { ...V, ok: false, codigo: 'MX008', error: 'Es un borrador: el PDF es de la factura emitida. Emítela primero.' } };
  if (d.anulado_el) return { estado: 409, cuerpo: { ...V, ok: false, codigo: 'MX008', error: `La factura ${d.numero} está anulada (nota de crédito ${d.nota_credito || '—'}): ya no se le hace PDF ni se manda.` } };
  const hacerPdf = () => {
    const conEnlace = F.config.ach && d.forma !== 'retencion' && d.saldoC > 0 && !b.sin_enlace;
    let e = null;
    if (conEnlace) {
      e = F.enlaces.filter(x => x.doc === d.id && x.estado === 'activo').pop();
      if (e && e.monto !== d.saldoC) { e.estado = 'desactivado'; e = null; }
      if (!e) { F.pdfN += 1; e = { id: `e1100000-0000-4000-8000-${String(F.pdfN).padStart(12, '0')}`, doc: d.id, url: `https://buy.stripe.com/test_plink_C11PANTALLA${F.pdfN}`, monto: d.saldoC, estado: 'activo', creado_el: new Date().toISOString() }; F.enlaces.push(e); }
    }
    const firma = sha(`${d.huella}|${e ? e.url : ''}`), ya = d.pdfs.find(p => p.sha256 === firma);
    if (ya) return { pdf: ya, ya_estaba: true, enlace: e };
    const p = { n: d.pdfs.length + 1, id: fId(), pago: e ? { url: e.url, monto: e.monto / 100, metodos: ['us_bank_account'], enlace_id: e.id } : {}, ruta: `${d.fecha.slice(0, 4)}/${d.numero}/${d.numero}-${firma.slice(0, 12)}.pdf`, bytes: 148213 + d.pdfs.length, sha256: firma, creado_el: new Date().toISOString() };
    d.pdfs.push(p);
    return { pdf: p, ya_estaba: false, enlace: e };
  };
  const firmada = ruta => `https://zeogjvwcmstmkwxjvykz.supabase.co/storage/v1/object/sign/facturas/${ruta}?token=prueba`;
  // como index.ts: el PDF recién registrado es lo que devuelve fn_emision_pdf (sin «pago»); el que ya estaba, la fila de fn_emision_documento
  const fPdfResp = r => r.ya_estaba ? r.pdf : (({ pago, ...x }) => x)(r.pdf);
  const fEnlaceResp = e => e ? { enlace_id: e.id, url: e.url, metodos: ['us_bank_account'], monto: e.monto / 100 } : null;
  if (b.accion === 'pdf') {
    const r = hacerPdf();
    return { cuerpo: { ...V, ok: true, documento: d.id, numero: d.numero, pdf: fPdfResp(r), ya_estaba: r.ya_estaba, enlace: fEnlaceResp(r.enlace),
      avisos: [...(b.sin_enlace ? ['Va sin enlace de pago en línea: lo pediste así.'] : []), ...(!r.enlace && F_HABLA_DE_ENLACE.test(String((d.contenido || {}).como_pagar || '')) ? [F_AVISO_ENLACE] : [])], url: firmada(r.pdf.ruta) } };
  }
  if (b.accion === 'ver') {
    const p = b.pdf_id ? d.pdfs.find(x => x.id === b.pdf_id) : d.pdfs[d.pdfs.length - 1];
    if (!p) return { estado: 409, cuerpo: { ...V, ok: false, codigo: 'MX008', error: 'Esa factura todavía no tiene PDF: hazlo primero.' } };
    return { cuerpo: { ...V, ok: true, documento: d.id, numero: d.numero, pdf: p, url: firmada(p.ruta) } };
  }
  if (b.accion === 'enviar') {
    const r = hacerPdf();
    const para = String(b.para || (d.contenido.cliente || {}).correo || '').trim().toLowerCase();
    if (!para) return { estado: 400, cuerpo: { ...V, ok: false, codigo: 'FORMA', error: 'Falta a quién mandarla: la factura no trae el correo del cliente. Escríbelo (para).' } };
    const cc = ['zz.edgar@c11-pruebas.invalid', ...String(b.cc || '').split(',').map(x => x.trim().toLowerCase()).filter(Boolean)].join(', ');
    const asunto = b.asunto || `Invoice ${d.numero} from ${F.config.empresa.nombre}`;
    F.resendN += 1;
    const rid = `re_c11_pantalla_${F.resendN}`;
    if (F.sinApuntar) { F.sinApuntar = false; return { estado: 500, cuerpo: { ...V, ok: false, codigo: 'SIN_APUNTAR', error: `El correo salió (Resend ${rid}) pero no quedó apuntado en la factura: La base estaba ocupada (prueba). Toca «Apuntar el envío» (no se vuelve a mandar).`, datos: { resend_id: rid, para, cc, asunto, pdf_id: r.pdf.id } } }; }
    const reg = C11_FN.fn_emision_envio({ p_documento: d.id, p_envio: { medio: 'correo', para, cc, asunto, resend_id: rid, pdf_id: r.pdf.id } });
    return { cuerpo: { ...V, ok: true, documento: d.id, numero: d.numero, envio: reg.envio, reenvio: reg.reenvio, ya_estaba: false, resend_id: rid, para, cc, asunto, pdf: fPdfResp(r), enlace: fEnlaceResp(r.enlace), avisos: [] } };
  }
  return { estado: 400, cuerpo: { ...V, ok: false, codigo: 'ACCION', error: `Acción desconocida: «${b.accion}». Las que hay: pdf, enviar, ver y salud.` } };
}


// ---- el WIP (c12, fase 10): la forma EXACTA de fn_wip_resumen, v_wip_schedule (sus 47 columnas), fn_wip_control (17 filas),
// fn_wip_cierre (174 a 177), v_wip_obras, v_wip_ajustes, v_wip_revisiones, wip_config y de las respuestas de fn_wip_revisar,
// fn_wip_antes_propuesta, fn_wip_antes, fn_wip_obra, fn_wip_postear, fn_wip_deshacer y fn_wip_config, con sus textos y sus
// errores (docs/conta/c12-wip.sql; sacados del banco u12a del 12-nov). La base de mentira calcula como la base, en centavos
// enteros: el % sobre el costo topado, el ganado = precio × costo topado ÷ estimado redondeado UNA vez (medio centavo hacia
// arriba), sub y sobre, la provisión = lo que falta por reconocer, las líneas del asiento con sus memos, la huella del ajuste y
// «qué cambió» cuando ya no está al día. Datos inventados («C12 PRUEBA», «ZZ»): A sub-facturada, B sobre-facturada, C con
// pérdida, D ya andaba antes del libro (tickets, horas y una factura de antes), S de servicio (no lleva WIP). Sin estado.c12,
// 404 (PGRST205 en las vistas, PGRST202 en las funciones); con estado.c12NoDueno, el equipo: vistas vacías y 42501.
const W_OB = {
  'c12-prueba-a': { obra: 'C12 PRUEBA Obra A', cliente: 'ZZ Cliente A', tipo: 'comercial', estado: 'ejecucion', contrato: 1000000 },
  'c12-prueba-b': { obra: 'C12 PRUEBA Obra B', cliente: 'ZZ Cliente B', tipo: 'residencial', estado: 'ejecucion', contrato: 2000000 },
  'c12-prueba-c': { obra: 'C12 PRUEBA Obra C', cliente: 'ZZ Cliente C', tipo: 'comercial', estado: 'ejecucion', contrato: 1000000 },
  'c12-prueba-d': { obra: 'C12 PRUEBA Obra D', cliente: 'ZZ Cliente D', tipo: 'residencial', estado: 'ejecucion', contrato: 1850000, deAntes: 'facturas, horas, tickets',
    prop: { tickets: [1, 31000], externos: [0, 0], horas: [16, 42000], facturas: [1, 150000] } },
  'c12-prueba-s': { obra: 'C12 PRUEBA Taller S', cliente: 'ZZ Cliente S', tipo: 'servicio', estado: 'ejecucion', contrato: null }
};
const W_INGRESO = { residencial: '4010', comercial: '4020', servicio: '4030' };
const W_CNOM = { 1200: 'Costo y utilidad en exceso de facturación', 2400: 'Facturación en exceso de costo', 2410: 'Provisión por pérdida en contratos', 5950: 'Pérdida en contrato',
  4010: 'Contrato — residencial', 4020: 'Contrato — comercial', 4030: 'Servicio y T&M' };
const W_MESES = [{ periodo: '2026-10', desde: '2026-10-01', hasta: '2026-10-31' }, { periodo: '2026-11', desde: '2026-11-01', hasta: '2026-11-30' }, { periodo: '2026-12', desde: '2026-12-01', hasta: '2026-12-31' }];
const W = {};
function wReset() {
  Object.assign(W, {
    // el costo y lo facturado del libro de cada obra, por mes (centavos); a la fecha de un mes: la suma hasta ese mes
    libro: { 'c12-prueba-a': { costo: { '2026-10': 300000 }, fact: { '2026-10': 200000 } }, 'c12-prueba-b': { costo: { '2026-10': 200000 }, fact: { '2026-10': 800000 } },
      'c12-prueba-c': { costo: { '2026-10': 550000 }, fact: {} }, 'c12-prueba-d': { costo: { '2026-10': 32000 }, fact: {} }, 'c12-prueba-s': { costo: { '2026-10': 10000 }, fact: { '2026-10': 25000 } } },
    rev: [], antes: {}, marca: {}, ajustes: [], cerrados: new Set(), n: 6, id: 0, cuadre10: false, conteoMal: false, horas170: false,
    cfg: { id: 1, exigir_desde: '2026-11', actualizado: '2026-11-12T02:49:50.056895+00:00', actualizado_por: null }
  });
}
wReset();
const wId = pre => { W.id += 1; return `${pre}-0000-4000-8000-${String(W.id).padStart(12, '0')}`; };
const wD = c => c == null ? null : c / 100;
const wUsd = c => c == null ? '—' : `${c < 0 ? '-' : ''}$${(Math.abs(c) / 100).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
const W_MESN = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
const wMes = p => { const m = /^(\d{4})-(\d{2})$/.exec(String(p || '')); return m ? `${W_MESN[Number(m[2]) - 1]} de ${m[1]}` : String(p); };
const wCap = s => s.charAt(0).toUpperCase() + s.slice(1);
const wSig = iso => { const d = new Date(iso + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + 1); return d.toISOString().slice(0, 10); };
// round(a × b ÷ c) en centavos, una vez, medio centavo hacia arriba (valores no negativos), y un % con dos decimales (round(100 × a ÷ b, 2))
const wRound = (ab, c) => Number((2n * BigInt(ab) + BigInt(c)) / (2n * BigInt(c)));
const wPctN = (a, b) => wRound(10000 * a, b) / 100;
const wPctT = (a, b) => String(wPctN(a, b));   // trim_scale: 50, 66.67, 8.75
const wErr = (code, message, status) => ({ status: status || 400, error: { code, message, hint: null, details: null } });
const wPer = p => W_MESES.find(x => x.periodo === p);
const W_ACTIVA = ['aprobado', 'ejecucion', 'pausa'], W_TERM = ['completado', 'cancelado', 'cerrado', 'terminado'];
// v_wip_obras: la regla (de precio fijo con contrato; de servicio o sin contrato, no) y la marca de Edgar
function wObra(pid) {
  const o = W_OB[pid], mk = W.marca[pid], an = W.antes[pid];
  const lleva = mk ? mk.modo === 'contrato' : o.tipo !== 'servicio' && o.contrato != null;
  const motivo = mk && mk.modo === 'tm' ? 'Marcada como de servicio o por tiempo y material: no lleva WIP; su ingreso es lo facturado.'
    : mk && mk.modo === 'contrato' && o.contrato == null ? 'Marcada como de precio fijo, pero su ficha no tiene contrato: ponlo para poder revisarla.'
    : mk && mk.modo === 'contrato' ? 'Marcada como de precio fijo: lleva WIP.'
    : o.tipo === 'servicio' ? 'Es de servicio: no lleva WIP; su ingreso es lo facturado.'
    : o.contrato == null ? 'No tiene contrato en su ficha: sin precio fijo no hay avance que medir; su ingreso es lo facturado.'
    : 'De precio fijo (residencial o comercial con contrato en su ficha): lleva WIP.';
  return { proyecto_id: pid, obra: o.obra, cliente: o.cliente, tipo: o.tipo, obra_estado: o.estado, activa: W_ACTIVA.includes(o.estado), terminada: W_TERM.includes(o.estado), completado_el: null,
    contrato: wD(o.contrato), marca: mk ? mk.modo : null, marca_nota: mk ? mk.nota : null, lleva_wip: lleva, motivo, cuenta_ingreso: W_INGRESO[o.tipo] || null,
    de_antes: !!o.deAntes, de_antes_por: o.deAntes || null, antes_id: an ? an.id : null, antes_costo: an ? wD(an.costo) : null, antes_facturado: an ? wD(an.facturado) : null,
    antes_confirmado_el: an ? an.el : null, antes_confirmado_por: an ? UID : null, antes_nota: an ? an.nota : null };
}
const wLibro = (pid, periodo) => { const L = W.libro[pid] || {}, s = o => Object.entries(o || {}).filter(([m]) => m <= periodo).reduce((a, [, v]) => a + v, 0); return { costo: s(L.costo), fact: s(L.fact) }; };
const wRev = (pid, periodo) => W.rev.find(r => r.proyecto_id === pid && r.periodo === periodo && !r.sustituida_el);
const wRevAnt = (pid, periodo) => W.rev.filter(r => r.proyecto_id === pid && r.periodo < periodo && !r.sustituida_el).sort((a, b) => b.periodo.localeCompare(a.periodo))[0];
// fn_wip_calcular: una fila por obra que entra en el mes (con _c: lo mismo en centavos, para el plan y la huella; no sale)
function wCalc(periodo) {
  const nom = wMes(periodo), filas = [];
  for (const pid of Object.keys(W_OB)) {
    const ob = wObra(pid); if (!ob.lleva_wip) continue;
    const rv = wRev(pid, periodo), ant = wRevAnt(pid, periodo), lb = wLibro(pid, periodo), an = W.antes[pid];
    if (!(ob.activa || rv || (ob.terminada && ant && !ant.terminada))) continue;
    const calc = !!rv && !(ob.de_antes && !an), mov = lb.costo !== 0 || lb.fact !== 0 || ob.de_antes || !!an || !!rv;
    const term = !!(rv && rv.terminada), precio = rv ? rv.precio : null;
    const cF = calc ? lb.costo + (an ? an.costo : 0) : null, fF = calc ? lb.fact + (an ? an.facturado : 0) : null;
    const est = !calc ? null : term ? cF : rv.costo, tope = !calc ? null : term ? cF : Math.max(Math.min(cF, est), 0);
    const gan = !calc ? null : term ? precio : wRound(precio * tope, est), perd = !calc || term ? null : Math.max(est - precio, 0);
    const sub = calc ? Math.max(gan - fF, 0) : null, sobre = calc ? Math.max(fF - gan, 0) : null;
    const perdT = !calc ? null : term ? Math.max(cF - precio, 0) : perd, prov = !calc ? null : (term || perd === 0) ? 0 : Math.max(perd - (tope - gan), 0);
    const falta = [!rv ? 'revision' : null, ob.de_antes && !an ? 'antes' : null, !ob.cuenta_ingreso ? 'cuenta_ingreso' : null].filter(Boolean);
    const prop = rv ? rv.propuesta : ant && !ant.terminada ? ant.costo : null, propO = rv ? rv.propuesta_origen : ant && !ant.terminada ? 'mes_anterior' : null;
    const pctA = !calc ? null : term ? 100 : wPctN(tope, est);
    filas.push({ periodo, proyecto_id: pid, obra: ob.obra, cliente: ob.cliente, tipo: ob.tipo, obra_estado: ob.obra_estado, fuente: 'calculado',
      estado: !mov ? 'sin_movimiento' : falta.length ? 'pendiente' : 'lista', falta: !mov ? [] : falta,
      falta_texto: !mov ? 'Sin costo ni facturas todavía: no hay nada que medir.' : !falta.length ? null : [
        !rv && ob.contrato == null ? 'Su ficha no tiene contrato: ponlo (o dilo al revisar) para poder revisarla.' : !rv ? `Falta revisar su costo estimado en ${nom}.` : null,
        ob.de_antes && !an ? `Ya andaba antes del libro (tiene de antes: ${ob.de_antes_por}): falta confirmar su costo y lo facturado de antes; hasta entonces no entra en el ajuste.` : null,
        !ob.cuenta_ingreso ? `Su tipo de obra (${ob.tipo || 'sin tipo'}) no tiene cuenta de ingreso confirmada: sin ella no se sabe contra qué renglón va el ajuste.` : null].filter(Boolean).join(' '),
      en_ajuste: mov && !falta.length, terminada: term, precio_contrato: wD(precio), precio_ficha: ob.contrato, costo_estimado: wD(est), utilidad_estimada: calc ? wD(precio - est) : null,
      costo_libro: wD(lb.costo), costo_antes: calc ? wD(an ? an.costo : 0) : an ? wD(an.costo) : null, costo_fecha: wD(cF), pct_avance: pctA,
      pct_real: !calc ? null : term ? 100 : wPctN(cF, est), pasa_de_100: calc && !term && cF > est, ingreso_ganado: wD(gan), facturado_libro: wD(lb.fact),
      facturado_antes: calc ? wD(an ? an.facturado : 0) : an ? wD(an.facturado) : null, facturado_fecha: wD(fF), sub_facturado: wD(sub), sobre_facturado: wD(sobre),
      costo_para_terminar: calc ? wD(Math.max(est - cF, 0)) : null, utilidad_fecha: calc ? wD(gan - cF) : null, perdida_total: wD(perdT), perdida_provision: wD(prov),
      cuenta_ingreso: ob.cuenta_ingreso, ingreso_otro: 0, de_antes: ob.de_antes, antes_confirmado: !!an, antes_id: an ? an.id : null,
      revision_id: rv ? rv.id : null, revisado_el: rv ? rv.el : null, revisado_por: rv ? UID : null, revision_origen: rv ? rv.origen : null, revision_nota: rv ? rv.nota : null,
      propuesta_costo_estimado: wD(prop), propuesta_origen: propO,
      propuesta_nota: rv ? null : ob.terminada ? 'La app la tiene como terminada: si terminó en este mes, revísala como terminada (100 %); si seguía en obra al cierre del mes, revisa su costo estimado.'
        : propO === 'mes_anterior' ? `Lo que revisaste en ${wMes(ant.periodo)}.` : 'Sin propuesta. No hay estimado: faltan las horas estimadas y el presupuesto de material.',
      propuesta_terminada: !rv && ob.terminada,
      avisos: !calc ? [] : [
        !term && cF > est ? `Lleva ${wUsd(cF)} de costo y su costo estimado revisado es ${wUsd(est)} (${wPctT(cF, est)} %): el avance se topa en 100 %. Sube el costo estimado o deja escrito por qué.` : null,
        !term && perd > 0 ? `Va con pérdida: el costo estimado (${wUsd(est)}) pasa del precio (${wUsd(precio)}) por ${wUsd(perd)}. De esa pérdida, ${wUsd(Math.min(tope - gan, perd))} ya está en su resultado por el avance y ${wUsd(prov)} se provisiona este mes: la pérdida completa queda reconocida.` : null,
        term && cF > precio ? `Terminó con pérdida: costó ${wUsd(cF)} y su precio es ${wUsd(precio)}.` : null,
        fF > precio ? `Lo facturado (${wUsd(fF)}) pasa del contrato (${wUsd(precio)}): ¿falta una orden de cambio en el contrato de la ficha?` : null,
        W_OB[pid].contrato !== precio ? `El contrato de la ficha (${W_OB[pid].contrato == null ? 'vacío' : wUsd(W_OB[pid].contrato)}) no es el que se usó al revisar (${wUsd(precio)}): si cambió en este mes, revísala otra vez.` : null].filter(Boolean),
      _c: { precio, est, term, cF, fF, gan, sub, sobre, perdT, prov, pct: pctA == null ? null : String(pctA) } });
  }
  return filas.sort((a, b) => a.obra.localeCompare(b.obra) || a.proyecto_id.localeCompare(b.proyecto_id));
}
const wSinInt = f => Object.fromEntries(Object.entries(f).filter(([k]) => !k.startsWith('_')));
const wFirma = f => [f.proyecto_id, f._c.precio, f._c.est, f._c.term, f._c.cF, f._c.fF, f._c.gan, f._c.sub, f._c.sobre, f._c.prov, f.cuenta_ingreso].join('|');
// fn_wip_plan: las filas, las líneas del asiento (por obra, en su orden), la huella y los totales de las obras listas (centavos)
function wPlan(periodo) {
  const filas = wCalc(periodo), nom = wMes(periodo), lineas = [], listas = filas.filter(f => f.en_ajuste);
  for (const f of listas) {
    const c = f._c, L = (cuenta, monto, memo) => { if (monto) lineas.push({ cuenta, monto, proyecto_id: f.proyecto_id, memo }); };
    L('1200', c.sub, `WIP de ${nom}: sub-facturado · ganado ${wUsd(c.gan)} (${c.pct} %) − facturado ${wUsd(c.fF)}`);
    L(f.cuenta_ingreso, -c.sub, `WIP de ${nom}: ingreso ganado y todavía no facturado`);
    L(f.cuenta_ingreso, c.sobre, `WIP de ${nom}: facturado por encima de lo ganado`);
    L('2400', -c.sobre, `WIP de ${nom}: sobre-facturado · facturado ${wUsd(c.fF)} − ganado ${wUsd(c.gan)} (${c.pct} %)`);
    L('5950', c.prov, `WIP de ${nom}: pérdida de la obra ${wUsd(c.perdT)} (costo estimado ${wUsd(c.est)} − precio ${wUsd(c.precio)}); falta por reconocer ${wUsd(c.prov)}`);
    L('2410', -c.prov, `WIP de ${nom}: provisión por la pérdida que falta por reconocer`);
  }
  const s = k => listas.reduce((a, f) => a + (f._c[k] || 0), 0);
  const tot = { obras: listas.length, precio: s('precio'), est: s('est'), cF: s('cF'), fF: s('fF'), gan: s('gan'), sub: s('sub'), sobre: s('sobre'), perdT: s('perdT'), prov: s('prov'),
    obras_sub: listas.filter(f => f._c.sub > 0).length, obras_sobre: listas.filter(f => f._c.sobre > 0).length };
  return { filas, listas, lineas, tot, huella: listas.map(wFirma).sort().join('\n') };
}
const wPos = c => [c.sub > 0 ? 'sub-facturado ' + wUsd(c.sub) : c.sobre > 0 ? 'sobre-facturado ' + wUsd(c.sobre) : 'sin diferencia', c.prov > 0 ? 'pérdida ' + wUsd(c.prov) : null].filter(Boolean).join(' y ');
const wVivo = periodo => W.ajustes.find(x => x.periodo === periodo && !x.deshecho_el);
// fn_wip_ajuste_estado: vivo, al día (su huella es la de hoy) y, si no, qué cambió obra por obra
function wEstado(periodo, plan) {
  const a = wVivo(periodo), nlin = plan.lineas.length;
  if (!a) return { vivo: false, al_dia: nlin === 0, lineas_hoy: nlin, por_fuera: false };
  const al = a.huella === plan.huella;
  let cambios = null;
  if (!al) {
    const it = [];
    for (const n of plan.listas) { const o = a.foto.find(x => x.proyecto_id === n.proyecto_id && x.en_ajuste); if (!o) it.push([n.obra, `entra ${n.obra} (${wPos(n._c)})`]); else if (wFirma(o) !== wFirma(n)) it.push([n.obra, wPos(o._c) !== wPos(n._c) ? `${n.obra} pasa de ${wPos(o._c)} a ${wPos(n._c)}` : `${n.obra} cambia su cálculo (${wPos(n._c)})`]); }
    for (const o of a.foto.filter(x => x.en_ajuste)) if (!plan.listas.some(n => n.proyecto_id === o.proyecto_id)) it.push([o.obra, `sale ${o.obra} (estaba ${wPos(o._c)})`]);
    cambios = it.sort((x, y) => x[0].localeCompare(y[0])).map(x => x[1]).join('; ');
  }
  return { id: a.id, vivo: true, fecha: a.fecha, obras: a.obras, al_dia: al, numero: a.numero, cambios, perdida: wD(a.perdida), reverso: null, creado_el: a.creado_el, por_fuera: false, asiento_id: a.asiento_id,
    creado_por: UID, lineas_hoy: nlin, reverso_auto: { id: a.auto.id, fecha: a.auto.fecha, numero: a.auto.numero }, sub_facturado: wD(a.sub), sobre_facturado: wD(a.sobre) };
}
const wToca = () => (W_MESES.find(p => p.hasta < HOY && !W.cerrados.has(p.periodo)) || W_MESES.find(p => p.desde <= HOY && HOY <= p.hasta) || W_MESES[0]).periodo;
const wNomObra = pid => (W_OB[pid] || {}).obra || pid;
const wLineasOut = ls => ls.map(l => ({ memo: l.memo, obra: wNomObra(l.proyecto_id), monto: wD(l.monto), cuenta: l.cuenta, proyecto_id: l.proyecto_id, cuenta_nombre: W_CNOM[l.cuenta] }));
// fn_wip_resumen
function wResumen(periodo) {
  const per = wPer(periodo); if (!per) return wErr('MX002', `No existe el mes «${periodo || ''}» (va como AAAA-MM).`);
  const nom = wMes(per.periodo), cerr = W.cerrados.has(per.periodo), term = per.hasta < HOY, exig = !!W.cfg.exigir_desde && per.periodo >= W.cfg.exigir_desde;
  let filas, est, lin, puede = false, porq = null, tot;
  if (cerr) {
    const a = wVivo(per.periodo);
    filas = a ? a.foto : [];
    est = a ? { id: a.id, vivo: true, fecha: a.fecha, obras: a.obras, al_dia: true, numero: a.numero, perdida: wD(a.perdida), creado_el: a.creado_el, por_fuera: false, asiento_id: a.asiento_id, creado_por: UID,
      reverso_auto: { id: a.auto.id, fecha: a.auto.fecha, numero: a.auto.numero }, sub_facturado: wD(a.sub), sobre_facturado: wD(a.sobre) } : { vivo: false, al_dia: true, por_fuera: false, lineas_hoy: 0 };
    lin = a ? wLineasOut(a.lineasAs) : [];
    porq = `${wCap(nom)} ya está cerrado: su WIP es el que se posteó.`;
  } else {
    const plan = wPlan(per.periodo); filas = plan.filas; est = wEstado(per.periodo, plan); lin = wLineasOut(plan.lineas);
    if (!term) porq = `${wCap(nom)} todavía no termina (su último día es el ${fDia(per.hasta)}): el ajuste se postea con el mes terminado.`;
    else if (est.vivo && est.al_dia) porq = `El ajuste de ${nom} ya está posteado y al día (asiento ${est.numero}).`;
    else if (!est.vivo && est.lineas_hoy === 0) porq = `En ${nom} hoy no hay nada que ajustar.`;
    else puede = true;
  }
  const L = filas.filter(f => f.en_ajuste), s = k => L.reduce((a, f) => a + (f._c[k] || 0), 0);
  const ob = { total: filas.length + (W.conteoMal ? 1 : 0), listas: filas.filter(f => f.estado === 'lista').length, pendientes: filas.filter(f => f.estado === 'pendiente').length,
    por_revisar: filas.filter(f => f.estado === 'pendiente' && f.falta.includes('revision')).length, sin_movimiento: filas.filter(f => f.estado === 'sin_movimiento').length,
    sin_cuenta_ingreso: filas.filter(f => f.estado === 'pendiente' && f.falta.includes('cuenta_ingreso')).length, por_confirmar_antes: filas.filter(f => f.estado === 'pendiente' && f.falta.includes('antes')).length };
  tot = { obras: L.length, pct_avance: s('precio') > 0 ? wPctN(s('gan'), s('precio')) : null, costo_fecha: wD(s('cF')), perdida_total: wD(s('perdT')), sub_facturado: wD(s('sub')), costo_estimado: wD(s('est')),
    ingreso_ganado: wD(s('gan')), utilidad_fecha: wD(s('gan') - s('cF')), facturado_fecha: wD(s('fF')), precio_contrato: wD(s('precio')), sobre_facturado: wD(s('sobre')), perdida_provision: wD(s('prov')),
    utilidad_estimada: wD(s('precio') - s('est')), costo_para_terminar: wD(L.reduce((a, f) => a + Math.max(f._c.est - f._c.cF, 0), 0)) };
  const nota = cerr ? porq : est.vivo && !est.al_dia ? `El ajuste posteado de ${nom} (asiento ${est.numero}) ya no es el de hoy: ${est.cambios}. Vuelve a postearlo: se reversa y entra el nuevo.`
    : ob.pendientes > 0 ? `${ob.pendientes} obra(s) no entran todavía: ${ob.por_revisar} por revisar y ${ob.por_confirmar_antes} sin lo de antes del libro confirmado.` : porq;
  return { nota, desde: per.desde, hasta: per.hasta, obras: ob, ajuste: est, fuente: cerr ? 'posteado' : 'calculado', lineas: lin, nombre: nom, cerrado: cerr, exigido: exig, periodo: per.periodo, totales: tot,
    terminado: term, por_que_no: porq, exigir_desde: W.cfg.exigir_desde, puede_postear: puede, reverso_fecha: wSig(per.hasta), puede_deshacer: !cerr && !!est.vivo };
}
// el schedule de un mes (v_wip_schedule / fn_wip_schedule): lo calculado hoy, o la foto del ajuste de un mes cerrado
const wSchedule = periodo => (W.cerrados.has(periodo) ? (wVivo(periodo) ? wVivo(periodo).foto.map(f => ({ ...f, fuente: 'posteado', precio_ficha: null })) : []) : wCalc(periodo)).map(wSinInt);
// fn_wip_control: siempre 17 filas, con sus textos
function wControl(periodo) {
  const per = wPer(periodo) || W_MESES[0], nom = wMes(per.periodo), mnom = wCap(nom), cerr = W.cerrados.has(per.periodo);
  const noap = `No aplica: ${nom} ya está cerrado; su WIP es el que se posteó.`;
  const exige = !!W.cfg.exigir_desde && per.periodo >= W.cfg.exigir_desde, termino = per.hasta < HOY;
  const cuando = !exige && !W.cfg.exigir_desde ? `En ${nom} el WIP todavía no se exige para cerrar (no se ha dicho desde qué mes).` : !exige ? `En ${nom} el WIP todavía no se exige para cerrar (se exige desde ${wMes(W.cfg.exigir_desde)}).`
    : !termino ? `${mnom} termina el ${fDia(per.hasta)}: se hace al cerrar el mes.` : null;
  const plan = cerr ? null : wPlan(per.periodo), est = cerr ? null : wEstado(per.periodo, plan), filas = cerr ? [] : plan.filas, t = cerr ? null : plan.tot;
  const R = (orden, cuadre, nivel, ok, detalle) => ({ ok, nivel, orden, cuadre, detalle });
  const vivos = W.ajustes.filter(a => !a.deshecho_el).length;
  const conMov = filas.filter(f => f.estado !== 'sin_movimiento'), sinRev = conMov.filter(f => f.falta.includes('revision'));
  const vA = cerr ? wVivo(per.periodo) : null;
  let ok50 = true, d50;
  if (cerr) d50 = vA ? `${mnom} está cerrado con su ajuste de WIP (asiento ${vA.numero}): sub-facturado ${wUsd(vA.sub)}, sobre-facturado ${wUsd(vA.sobre)}, pérdida ${wUsd(vA.perdida)}.` : `${mnom} está cerrado sin ajuste de WIP.`;
  else if (est.vivo && est.al_dia) d50 = `El ajuste de ${nom} está posteado y al día (asiento ${est.numero}, del ${fDia(est.fecha)}; se deshace solo el ${fDia(est.reverso_auto.fecha)}): sub-facturado ${wUsd(Math.round(est.sub_facturado * 100))}, sobre-facturado ${wUsd(Math.round(est.sobre_facturado * 100))} y pérdida ${wUsd(Math.round(est.perdida * 100))}, en ${est.obras} obra(s).`;
  else if (est.vivo) { ok50 = false; d50 = `El ajuste posteado de ${nom} (asiento ${est.numero}) ya no es el que da el WIP de hoy: ${est.cambios}. Vuelve a postearlo: se reversa y entra el nuevo.`; }
  else if (!plan.lineas.length) d50 = t.obras === 0 ? `En ${nom} no hay ninguna obra lista para el ajuste: nada que postear.` : `En ${nom} no hay nada que ajustar: en las ${t.obras} obra(s) listas lo ganado es lo facturado.`;
  else { ok50 = !!cuando; d50 = `${cuando ? cuando + ' Hoy daría' : 'Falta postear'} el ajuste de WIP de ${nom}: sub-facturado ${wUsd(t.sub)} en ${t.obras_sub} obra(s), sobre-facturado ${wUsd(t.sobre)} en ${t.obras_sobre}, y pérdida por reconocer ${wUsd(t.prov)}.`; }
  const p60 = filas.filter(f => f.pasa_de_100 && !String(f.revision_nota || '').trim()), p125 = filas.filter(f => f.pasa_de_100 && String(f.revision_nota || '').trim());
  const sinAntes = filas.filter(f => f.falta.includes('antes')), conPerd = filas.filter(f => f.en_ajuste && f._c.perdT > 0);
  return [
    R(10, 'wip: en las cuentas del WIP solo está el ajuste del mes', 'cuadre', !W.cuadre10, !W.cuadre10 ? 'En las cuentas del WIP (sub-facturado, sobre-facturado, la provisión por pérdida y su gasto) no hay más saldo que el de los ajustes del WIP.'
      : 'Hay saldo en las cuentas del WIP que no viene de un ajuste: $500.00 en la 1200 de C12 PRUEBA Obra A. Esas cuentas las lleva el ajuste del mes: si es un asiento a mano, revérsalo; si lo pidió el contador (un saldo inicial), avisa antes de cerrar.'),
    R(20, 'wip: cada ajuste es su asiento, y el saldo por obra es el del ajuste', 'cuadre', true, `${vivos} ajuste(s) vivo(s), cada uno con su asiento vivo y sus líneas iguales a su foto; y al ${fDia(per.hasta)} el saldo por obra de sub-facturado, sobre-facturado y provisión es el de su ajuste.`),
    R(30, 'wip: lo facturado a la fecha = las facturas del libro', 'cuadre', true, cerr ? noap : `En las ${filas.length} obra(s) del WIP de ${nom}, lo facturado que usa el WIP es lo que dicen sus facturas en el libro (las anuladas, con su nota de crédito restando), sin los ajustes.`),
    R(40, 'wip: cada obra con su costo estimado revisado en el mes', 'cuadre', cerr || !sinRev.length || !!cuando, cerr ? noap : !conMov.length ? `En ${nom} no hay obras de precio fijo con movimiento.`
      : !sinRev.length ? `Las ${conMov.length} obra(s) de precio fijo con movimiento tienen su costo estimado revisado en ${nom}.` : cuando ? `${cuando} Hoy faltan por revisar ${sinRev.length} de ${conMov.length}: ${sinRev.map(f => f.obra).join(', ')}.`
      : `Faltan por revisar ${sinRev.length} de las ${conMov.length} obra(s) de precio fijo con movimiento en ${nom}: ${sinRev.map(f => f.obra).join(', ')}.`),
    R(50, 'wip: el ajuste del mes posteado y al día', 'cuadre', ok50, d50),
    R(60, 'wip: ninguna obra con más costo que su estimado sin nota', 'cuadre', cerr || !p60.length, cerr ? noap : !p60.length ? `En ${nom} ninguna obra lleva más costo que su estimado revisado sin que esté escrito por qué.`
      : `${p60.length} obra(s) llevan más costo que su estimado revisado, sin nota: ${p60.map(f => `${f.obra} (lleva ${wUsd(f._c.cF)} y su estimado es ${wUsd(f._c.est)}: ${wPctT(f._c.cF, f._c.est)} %)`).join('; ')}. Sube su costo estimado (o escribe por qué): con el avance topado en 100 % se gana el precio entero y una pérdida no se ve.`),
    R(90, 'wip: las protecciones de la capa', 'cuadre', true, 'Nada del WIP corre con permisos de más, nada es para la llave pública ni la de servicio, las tablas tienen su candado de solo-dueño y sus guardas encendidas, y las vistas leen con los permisos de quien mira.'),
    R(110, 'wip: obras que ya andaban sin lo de antes confirmado', 'aviso', cerr || !sinAntes.length, cerr ? noap : !sinAntes.length ? `En ${nom} ninguna obra del WIP espera que se confirme lo de antes del libro.`
      : `${sinAntes.length} obra(s) ya andaban antes del libro y no tienen confirmado su costo y lo facturado de antes: ${sinAntes.map(f => f.obra).join(', ')}. Mientras tanto NO entran en el ajuste de ${nom} (su ingreso sigue siendo lo facturado). Confírmalo una vez por obra.`),
    R(120, 'wip: obras con pérdida', 'aviso', cerr || !conPerd.length, cerr ? noap : !conPerd.length ? `En ${nom} ninguna obra del WIP va con pérdida.`
      : `${conPerd.length} obra(s) van con pérdida en ${nom}: ${conPerd.map(f => `${f.obra} (pérdida ${wUsd(f._c.perdT)}; provisionado ${wUsd(f._c.prov)})`).join('; ')}. La pérdida completa queda reconocida este mes.`),
    R(125, 'wip: obras topadas en 100 %', 'aviso', cerr || !p125.length, cerr ? noap : !p125.length ? `En ${nom} ninguna obra está topada en 100 %.`
      : `${p125.length} obra(s) llevan más costo que su estimado y van topadas en 100 %, con su nota: ${p125.map(f => `${f.obra} (${wPctT(f._c.cF, f._c.est)} %: ${f.revision_nota})`).join('; ')}.`),
    R(130, 'wip: el contrato de la ficha cambió después de revisar', 'aviso', true, cerr ? noap : `En ${nom} cada obra revisada usa el contrato que hoy dice su ficha.`),
    R(140, 'wip: facturado por encima del contrato', 'aviso', true, cerr ? noap : `En ${nom} ninguna obra del WIP tiene facturado más que su contrato.`),
    R(150, 'wip: ingreso de una obra que no es factura ni ajuste', 'aviso', true, cerr ? noap : `En ${nom} todo el ingreso de las obras del WIP viene de sus facturas.`),
    R(160, 'wip: obras terminadas con movimiento en el mes, fuera del WIP', 'aviso', true, cerr ? noap : `En ${nom} ninguna obra terminada de precio fijo tiene costo o facturas fuera del WIP.`),
    R(165, 'wip: obras activas sin contrato que no son de servicio', 'aviso', true, cerr ? noap : 'Toda obra activa con movimiento que no es de servicio tiene su contrato en la ficha (o su marca).'),
    R(170, 'wip: horas sin costo en el libro', 'aviso', cerr || !W.horas170, cerr ? noap : !W.horas170 ? 'Ninguna obra del WIP tiene hoy horas sin costo en el libro.'
      : '1 obra(s) del WIP tienen hoy horas reportadas que no están en el libro (sin pago repartido): C12 PRUEBA Obra D (8 h). Su costo a la fecha va corto y su avance también. Reparte los pagos de mano de obra pendientes.'),
    R(180, 'wip: la suma de los hitos no es el contrato', 'aviso', true, cerr ? noap : 'En cada obra del WIP con hitos, sus hitos suman el contrato de la ficha.')
  ];
}
// fn_wip_cierre: las cuatro filas que pide el cierre (c9)
function wCierre(periodo) {
  const c = wControl(periodo), cu = c.filter(f => f.nivel === 'cuadre' && f.orden !== 40 && f.orden !== 50), av = c.filter(f => f.nivel === 'aviso');
  const r1 = cu.filter(f => !f.ok), r4 = av.filter(f => !f.ok), f40 = c.find(f => f.orden === 40), f50 = c.find(f => f.orden === 50);
  return [
    { ok: !r1.length, ir_a: 'wip', nivel: 'detiene', orden: 174, control: 'wip: los cuadres del WIP (c12)', detalle: r1.length ? r1.map(f => f.detalle).join(' · ') : `Los ${cu.length}, en verde.`,
      que_hacer: r1.length ? 'El detalle dice qué: Contabilidad → WIP. Un asiento a mano en las cuentas del WIP se reversa; un ajuste que no cuadra se vuelve a postear.' : null },
    { ok: f40.ok, ir_a: 'wip', nivel: 'detiene', orden: 175, control: 'wip: cada obra con su costo estimado revisado', detalle: f40.detalle,
      que_hacer: f40.ok ? null : 'En Contabilidad → WIP, revisa cada obra de la lista: confirma lo propuesto con un toque, o pon su costo total estimado con su nota.' },
    { ok: f50.ok, ir_a: 'wip', nivel: 'detiene', orden: 176, control: 'wip: el ajuste del mes posteado y al día', detalle: f50.detalle,
      que_hacer: f50.ok ? null : 'En Contabilidad → WIP, toca «Postear el ajuste» (si ya estaba posteado, lo rehace con lo de hoy).' },
    { ok: !r4.length, ir_a: 'wip', nivel: 'aviso', orden: 177, control: 'wip: sus avisos (c12)', detalle: r4.length ? r4.map(f => f.detalle).join(' · ') : `Los ${av.length}, en verde.`,
      que_hacer: r4.length ? 'No detienen el cierre. El detalle dice qué mirar: Contabilidad → WIP.' : null }
  ];
}
// un monto que llega como texto (fn_wip_monto): MX005 con lo que está mal; devuelve centavos
function wMonto(t, que, cero) {
  const Q = que.charAt(0).toUpperCase() + que.slice(1), s = String(t == null ? '' : t).trim();
  if (!s) return wErr('MX005', `Falta ${que}.`);
  if (!/^-?\d+(\.\d+)?$/.test(s)) return wErr('MX005', `${Q}: «${t}» no es un monto.`);
  if ((s.split('.')[1] || '').replace(/0+$/, '').length > 2) return wErr('MX005', `${Q}: ${t} trae más de dos decimales; el libro va en centavos.`);
  const c = Math.round(Number(s) * 100);
  if (c < 0 || (c === 0 && !cero)) return wErr('MX005', `${Q}: ${t}. Va en positivo${cero ? ' (o cero)' : ', mayor que cero'}.`);
  return c;
}
const wEsErr = x => x && typeof x === 'object' && x.error;
const wSobra = (p, ok) => Object.keys(p).filter(k => !ok.includes(k)).sort().join(', ');
// lo de antes del libro, propuesto desde los papeles de la app (fn_wip_antes_propuesta)
function wAntesProp(pid) {
  const o = W_OB[pid], pr = o.prop || { tickets: [0, 0], externos: [0, 0], horas: [0, 0], facturas: [0, 0] }, an = W.antes[pid];
  const total = pr.tickets[1] + pr.externos[1] + pr.horas[1];
  const notas = [];
  if (pr.horas[0] > 0) notas.push(`Las ${pr.horas[0]} h de la cuadrilla de antes van a la tarifa de HOY de «Costos del equipo» (no guarda historia), sin carga encima.`);
  notas.push('Lo que no pasó por la app (un pago sin ticket, la tarjeta, un sub pagado por fuera) no está aquí: compáralo con el costo y lo facturado de esa obra en QuickBooks al 30 de septiembre, y si no coincide pon lo de QuickBooks con su nota.');
  return { obra: o.obra, costo: { horas: { horas: pr.horas[0], monto: wD(pr.horas[1]), del_dueno: 0, sin_tarifa: 0, de_antes_de_la_app: null }, total: wD(total), tickets: { n: pr.tickets[0], monto: wD(pr.tickets[1]) },
      trabajos_externos: { n: pr.externos[0], monto: wD(pr.externos[1]) } }, hasta: '2026-09-30', notas, de_antes: !!o.deAntes,
    facturado: { total: wD(pr.facturas[1]), facturas: { n: pr.facturas[0], monto: wD(pr.facturas[1]) } },
    confirmado: an ? { id: an.id, nota: an.nota, costo: wD(an.costo), facturado: wD(an.facturado), confirmado_el: an.el, confirmado_por: UID } : null,
    libro_desde: '2026-10-01', proyecto_id: pid, de_antes_por: o.deAntes || null, _c: { costo: total, fact: pr.facturas[1] } };
}
const wConfig = () => ({ nota: W.cfg.exigir_desde ? `El cierre exige el WIP (cada obra revisada y el ajuste posteado) desde ${wMes(W.cfg.exigir_desde)}; los meses anteriores no se frenan por él.` : 'El cierre todavía no exige el WIP en ningún mes: se puede revisar y postear, pero no detiene.',
  actualizado: W.cfg.actualizado, exigir_desde: W.cfg.exigir_desde, actualizado_por: W.cfg.actualizado_por, exigir_desde_nombre: W.cfg.exigir_desde ? wMes(W.cfg.exigir_desde) : null });
const wNum = () => { W.n += 1; return `2026-${String(W.n).padStart(6, '0')}`; };
const W_FN = {
  fn_wip_resumen: a => wResumen(a.p_periodo || wToca()),
  fn_wip_control: a => wControl(a.p_periodo || wToca()),
  fn_wip_cierre: a => wCierre(a.p_periodo),
  fn_wip_schedule: a => wSchedule(a.p_periodo || wToca()),
  fn_wip_config(a) {
    const p = a.p;
    if (p == null) return wConfig();
    if (typeof p !== 'object' || Array.isArray(p)) return wErr('22023', 'La configuración llega como un objeto JSON: {"exigir_desde": "2026-11"}.');
    const sob = wSobra(p, ['exigir_desde']); if (sob) return wErr('22023', `Clave desconocida en la configuración del WIP: ${sob}. La única es exigir_desde.`);
    if ('exigir_desde' in p) {
      const v = p.exigir_desde == null || p.exigir_desde === '' ? null : String(p.exigir_desde);
      if (v && !/^\d{4}-(0[1-9]|1[0-2])$/.test(v)) return wErr('22023', `«${v}» no es un mes del libro: va como AAAA-MM (por ejemplo 2026-11), o vacío para no exigir el WIP todavía.`);
      Object.assign(W.cfg, { exigir_desde: v, actualizado: new Date().toISOString(), actualizado_por: UID });
    }
    return wConfig();
  },
  fn_wip_antes_propuesta: a => W_OB[a.p_proyecto] ? wSinInt(wAntesProp(a.p_proyecto)) : wErr('MX008', `No existe la obra «${a.p_proyecto || ''}».`),
  fn_wip_antes(a) {
    const p = a.p;
    if (!p || typeof p !== 'object' || Array.isArray(p)) return wErr('22023', 'Lo de antes llega como un objeto JSON: {"costo": "…", "facturado": "…", "nota": "…"}.');
    const sob = wSobra(p, ['costo', 'facturado', 'nota']); if (sob) return wErr('22023', `Clave desconocida en lo de antes del libro: ${sob}.`);
    if (!W_OB[a.p_proyecto]) return wErr('MX008', `No existe la obra «${a.p_proyecto || ''}».`);
    const pr = wAntesProp(a.p_proyecto), c = wMonto(p.costo, 'el costo de antes del libro', true); if (wEsErr(c)) return c;
    const f = wMonto(p.facturado, 'lo facturado antes del libro', true); if (wEsErr(f)) return f;
    const nota = String(p.nota || '').trim() || null;
    if ((c !== pr._c.costo || f !== pr._c.fact) && !nota) return wErr('22023', `Estos números (costo ${wUsd(c)}, facturado ${wUsd(f)}) no son los que salen de los papeles de la app (costo ${wUsd(pr._c.costo)}, facturado ${wUsd(pr._c.fact)}): di de dónde salen en la nota (por ejemplo, «costo por obra de QuickBooks al 30 de septiembre»).`);
    const viva = W.antes[a.p_proyecto];
    if (viva && viva.costo === c && viva.facturado === f && viva.nota === nota) return { nota: 'Lo de antes del libro ya estaba confirmado con esos mismos números.', costo: wD(c), antes_id: viva.id, facturado: wD(f), ya_estaba: true, proyecto_id: a.p_proyecto };
    W.antes[a.p_proyecto] = { id: wId('a1200000'), costo: c, facturado: f, nota, el: new Date().toISOString() };
    const abiertos = W.ajustes.filter(x => !x.deshecho_el && !W.cerrados.has(x.periodo)).map(x => wMes(x.periodo)).join(', ');
    return { nota: `Confirmado lo de antes del libro de «${pr.obra}»: costo ${wUsd(c)} y facturado ${wUsd(f)}.${abiertos ? ` El ajuste de ${abiertos} ya estaba posteado: mira si sigue al día y, si no, vuelve a postearlo.` : ''}`,
      costo: wD(c), antes_id: W.antes[a.p_proyecto].id, facturado: wD(f), propuesta: (({ confirmado, ...x }) => x)(wSinInt(pr)), sustituye: viva ? viva.id : null, ya_estaba: false, proyecto_id: a.p_proyecto };
  },
  fn_wip_obra(a) {
    const p = a.p;
    if (!p || typeof p !== 'object' || Array.isArray(p)) return wErr('22023', 'La marca llega como un objeto JSON: {"modo": "contrato" | "tm" | "auto", "nota": "…"}.');
    const sob = wSobra(p, ['modo', 'nota']); if (sob) return wErr('22023', `Clave desconocida en la marca de la obra: ${sob}.`);
    if (!['contrato', 'tm', 'auto'].includes(p.modo)) return wErr('22023', 'El modo es «contrato» (de precio fijo: lleva WIP), «tm» (de servicio o por tiempo y material: no lo lleva) o «auto» (la regla).');
    if (!W_OB[a.p_proyecto]) return wErr('MX008', `No existe la obra «${a.p_proyecto || ''}».`);
    const nota = String(p.nota || '').trim() || null;
    if (p.modo !== 'auto' && !nota) return wErr('22023', 'Di por qué en la nota (por ejemplo, «servicio con precio cerrado» o «se factura por horas»): queda escrito con la marca.');
    if (p.modo === 'auto') delete W.marca[a.p_proyecto]; else W.marca[a.p_proyecto] = { modo: p.modo, nota };
    const o = wObra(a.p_proyecto);
    return { nota: `${o.motivo} Si el ajuste de un mes abierto ya estaba posteado, vuelve a postearlo.`, obra: o, proyecto_id: a.p_proyecto };
  },
  fn_wip_revisar(a) {
    const p = a.p;
    if (!p || typeof p !== 'object' || Array.isArray(p)) return wErr('22023', 'La revisión llega como un objeto JSON: {"confirmar": true}, {"costo_estimado": "…", "nota": "…"} o {"terminada": true}.');
    const sob = wSobra(p, ['confirmar', 'costo_estimado', 'nota', 'terminada', 'precio_contrato']); if (sob) return wErr('22023', `Clave desconocida en la revisión: ${sob}.`);
    const per = wPer(a.p_periodo); if (!per) return wErr('MX002', `No existe el mes «${a.p_periodo || ''}» (va como AAAA-MM).`);
    const nom = wMes(per.periodo), Nom = wCap(nom);
    if (W.cerrados.has(per.periodo)) return wErr('MX002', `${Nom} ya está cerrado: su WIP no se toca. Lo que haya cambiado se revisa en el mes abierto.`);
    if (per.desde > HOY) return wErr('MX002', `${Nom} todavía no empieza (hoy es ${fDia(HOY)} en Miami): una obra se revisa en el mes que se está cerrando.`);
    if (!W_OB[a.p_proyecto]) return wErr('MX008', `No existe la obra «${a.p_proyecto || ''}».`);
    const o = wObra(a.p_proyecto);
    if (!o.lleva_wip) return wErr('MX008', `«${o.obra}» no lleva WIP. ${o.motivo} Si de verdad es de precio fijo, márcala antes (modo «contrato»).`);
    const term = p.terminada === true, conf = p.confirmar === true, nota = String(p.nota || '').trim() || null;
    let dado = null;
    if (String(p.costo_estimado == null ? '' : p.costo_estimado).trim()) { dado = wMonto(p.costo_estimado, 'el costo total estimado'); if (wEsErr(dado)) return dado; }
    if (term && (conf || dado != null)) return wErr('22023', 'Una obra terminada no lleva costo estimado ni propuesta que confirmar: su costo final es el que lleva. Manda solo {"terminada": true}.');
    const ficha = W_OB[a.p_proyecto].contrato;
    let precio = ficha;
    if (String(p.precio_contrato == null ? '' : p.precio_contrato).trim()) { precio = wMonto(p.precio_contrato, 'el precio del contrato'); if (wEsErr(precio)) return precio; }
    if (precio == null) return wErr('MX008', `«${o.obra}» no tiene contrato en su ficha: ponlo en la obra, o dilo en la revisión (precio_contrato) con su nota.`);
    if (ficha !== precio && !nota) return wErr('22023', `El precio que pones (${wUsd(precio)}) no es el contrato de la ficha (${ficha == null ? 'vacío' : wUsd(ficha)}): deja escrito por qué en la nota (por ejemplo, «orden de cambio 2 firmada, falta en la ficha»).`);
    const f = wCalc(per.periodo).find(x => x.proyecto_id === a.p_proyecto) || null;
    const prop = f && f.propuesta_costo_estimado != null ? Math.round(f.propuesta_costo_estimado * 100) : null;
    let costo, origen;
    if (term) {
      if (!o.terminada) return wErr('MX008', `La app tiene «${o.obra}» como «${o.obra_estado}», no como terminada: márcala completada en su ficha y revísala como terminada, o revisa su costo estimado.`);
      costo = null; origen = 'terminada';
    } else if (conf) {
      if (prop == null) return wErr('MX008', `No hay una propuesta que confirmar para «${o.obra}» en ${nom} (ni revisión anterior ni un estimado completo): escribe su costo total estimado.`);
      if (dado != null && dado !== prop) return wErr('MX008', `La propuesta de «${o.obra}» ya no es la que viste (${wUsd(dado)}; ahora es ${wUsd(prop)}): vuelve a mirar antes de confirmar.`);
      costo = prop; origen = f.propuesta_origen || 'a_mano';
    } else {
      if (dado == null) return wErr('22023', 'Falta el costo total estimado (costo_estimado), o confirmar lo propuesto (confirmar), o decir que la obra terminó (terminada).');
      costo = dado; origen = prop != null && prop === costo ? (f.propuesta_origen || 'a_mano') : 'a_mano';
      if (origen === 'a_mano' && prop != null && !nota) return wErr('22023', `Cambias el costo estimado de «${o.obra}» de ${wUsd(prop)} (${f.propuesta_origen === 'mes_anterior' ? 'lo del mes anterior' : f.propuesta_origen === 'estimado' ? 'su estimado' : 'lo propuesto'}) a ${wUsd(costo)}: deja escrito por qué en la nota.`);
    }
    if (!term) {
      const lb = wLibro(a.p_proyecto, per.periodo), an = W.antes[a.p_proyecto], cf = lb.costo + (an ? an.costo : 0);
      if (cf > costo && !nota) return wErr('22023', `El costo estimado (${wUsd(costo)}) es menor que lo que «${o.obra}» ya lleva al ${fDia(per.hasta)} (${wUsd(cf)}): daría ${wPctT(cf, costo)} % de avance. Súbelo, o deja escrito por qué en la nota.`);
    }
    const viva = wRev(a.p_proyecto, per.periodo);
    let id;
    if (viva && viva.precio === precio && viva.costo === costo && viva.terminada === term && viva.nota === nota) id = viva.id;
    else {
      if (viva) viva.sustituida_el = new Date().toISOString();
      id = wId('b1200000');
      W.rev.push({ id, proyecto_id: a.p_proyecto, periodo: per.periodo, precio, ficha, costo, terminada: term, origen, propuesta: f ? prop : null, propuesta_origen: f ? f.propuesta_origen : null, nota, el: new Date().toISOString(), sustituida_el: null });
    }
    const fila = wCalc(per.periodo).find(x => x.proyecto_id === a.p_proyecto);
    const est = wEstado(per.periodo, wPlan(per.periodo));
    return { fila: fila ? wSinInt(fila) : null, nota: est.vivo && !est.al_dia ? `Revisada. El ajuste de ${nom} ya estaba posteado (asiento ${est.numero}) y con esto ya no está al día: vuelve a postearlo (se reversa y entra el nuevo).`
        : fila && fila.estado === 'pendiente' ? 'Revisada. ' + (fila.falta_texto || '') : 'Revisada.',
      ajuste: { vivo: est.vivo, al_dia: est.al_dia, numero: est.numero || null, cambios: est.cambios || null }, origen, periodo: per.periodo, ya_estaba: !!viva && viva.id === id, proyecto_id: a.p_proyecto, revision_id: id };
  },
  fn_wip_postear(a) {
    const per = wPer(a.p_periodo); if (!per) return wErr('MX002', `No existe el mes «${a.p_periodo || ''}» (va como AAAA-MM).`);
    const nom = wMes(per.periodo), Nom = wCap(nom);
    if (W.cerrados.has(per.periodo)) return wErr('MX002', `${Nom} ya está cerrado: su ajuste de WIP no se toca (si lo tuvo, ya se deshizo solo el día 1). Lo que haya cambiado entra en el ajuste del mes abierto.`);
    if (per.hasta >= HOY) return wErr('MX002', `${Nom} todavía no termina (su último día es el ${fDia(per.hasta)}; hoy es ${fDia(HOY)} en Miami): el ajuste del WIP se postea con el mes terminado, desde el ${fDia(wSig(per.hasta))}. Hasta entonces siguen entrando costos y facturas.`);
    const plan = wPlan(per.periodo), est = wEstado(per.periodo, plan), t = plan.tot;
    const fuera = plan.filas.filter(f => f.estado === 'pendiente').map(f => ({ obra: f.obra, falta: f.falta, falta_texto: f.falta_texto, proyecto_id: f.proyecto_id }));
    let rehecho = null, sust = null;
    if (est.vivo) {
      const v = wVivo(per.periodo);
      if (est.al_dia) return { nota: `El ajuste de WIP de ${nom} ya estaba posteado y sigue al día (asiento ${v.numero}): no se duplica.`, fuera, obras: v.obras, lineas: v.lineas,
        asiento: { id: v.asiento_id, fecha: v.fecha, numero: v.numero }, perdida: wD(v.perdida), periodo: per.periodo, reverso: { id: v.auto.id, fecha: v.auto.fecha, numero: v.auto.numero },
        posteado: true, ajuste_id: v.id, ya_estaba: true, sub_facturado: wD(v.sub), sobre_facturado: wD(v.sobre) };
      const motivo = `El WIP de ${nom} cambió después de postear su ajuste (${v.numero}): ${est.cambios || 'cambió su cálculo'}.${a.p_motivo ? ' ' + a.p_motivo : ''}`;
      const rn = wNum(), anula = v.auto.numero;
      Object.assign(v, { deshecho_el: new Date().toISOString(), deshecho_motivo: motivo, reverso_numero: rn, reverso_id: wId('c1200000') });
      sust = v.id; rehecho = { motivo, numero: v.numero, reverso: { id: v.reverso_id, numero: rn }, ajuste_id: v.id, por_fuera: false, anula_reverso_automatico: anula };
    }
    if (!plan.lineas.length) return { nota: rehecho ? `El ajuste anterior de ${nom} (asiento ${rehecho.numero}) se deshizo, y hoy no hay nada que ajustar.` : t.obras === 0 ? `En ${nom} ninguna obra está lista para el ajuste${fuera.length ? ` (${fuera.length} pendiente(s): les falta su revisión o lo de antes del libro)` : ''}.` : `En ${nom} no hay nada que ajustar: en las ${t.obras} obra(s) listas lo ganado es lo facturado, al centavo.`,
      fuera, obras: t.obras, periodo: per.periodo, rehecho, posteado: false, ya_estaba: false };
    const numero = wNum(), auto = { id: wId('d1200000'), numero: wNum(), fecha: wSig(per.hasta) };
    const aj = { id: wId('e1200000'), periodo: per.periodo, asiento_id: wId('f1200000'), numero, fecha: per.hasta, auto, obras: t.obras, lineas: plan.lineas.length, lineasAs: plan.lineas,
      sub: t.sub, sobre: t.sobre, perdida: t.prov, huella: plan.huella, foto: plan.filas, sustituye_a: sust, motivo: a.p_motivo || null, creado_el: new Date().toISOString(), deshecho_el: null };
    W.ajustes.push(aj);
    return { nota: `${rehecho ? 'Rehecho' : 'Posteado'} el ajuste de WIP de ${nom}: asiento ${numero}, con ${t.obras} obra(s) (sub-facturado ${wUsd(t.sub)}, sobre-facturado ${wUsd(t.sobre)}, pérdida ${wUsd(t.prov)}). Se deshace solo el ${fDia(auto.fecha)} (asiento ${auto.numero}).${fuera.length ? ` ${fuera.length} obra(s) no entraron: les falta su revisión o lo de antes del libro.` : ''}`,
      fuera, obras: t.obras, lineas: plan.lineas.length, asiento: { id: aj.asiento_id, fecha: per.hasta, numero }, perdida: wD(t.prov), periodo: per.periodo, rehecho, reverso: { id: auto.id, fecha: auto.fecha, numero: auto.numero },
      posteado: true, ajuste_id: aj.id, ya_estaba: false, sub_facturado: wD(t.sub), sobre_facturado: wD(t.sobre) };
  },
  fn_wip_deshacer(a) {
    const per = wPer(a.p_periodo); if (!per) return wErr('MX002', `No existe el mes «${a.p_periodo || ''}» (va como AAAA-MM).`);
    const nom = wMes(per.periodo), Nom = wCap(nom), motivo = String(a.p_motivo || '').trim();
    if (!motivo) return wErr('22023', 'Deshacer un ajuste de WIP pide su motivo: queda escrito en el reverso.');
    if (W.cerrados.has(per.periodo)) return wErr('MX002', `${Nom} ya está cerrado: su ajuste de WIP ya se deshizo solo el día 1 y no hay nada que deshacer.`);
    const v = wVivo(per.periodo); if (!v) return wErr('MX008', `${Nom} no tiene un ajuste de WIP vivo que deshacer.`);
    const rn = wNum();
    Object.assign(v, { deshecho_el: new Date().toISOString(), deshecho_motivo: motivo, reverso_numero: rn, reverso_id: wId('c1200000') });
    return { nota: `Deshecho el ajuste de WIP de ${nom}: el asiento ${v.numero} se reversó con ${rn}, y su reverso del día 1 quedó anulado. El libro vuelve a lo facturado.`,
      asiento: { id: v.asiento_id, numero: v.numero }, periodo: per.periodo, reverso: { id: v.reverso_id, numero: rn }, ajuste_id: v.id, por_fuera: false, anula_reverso_automatico: v.auto.numero };
  }
};
const W_VISTAS = {
  v_wip_schedule: () => W_MESES.filter(p => p.desde <= HOY).flatMap(p => wSchedule(p.periodo)),
  v_wip_obras: () => Object.keys(W_OB).map(wObra).sort((a, b) => a.obra.localeCompare(b.obra)),
  v_wip_control: () => wControl(wToca()),
  v_wip_ajustes: () => W.ajustes.map(x => ({ vivo: !x.deshecho_el, fecha: x.fecha, obras: x.obras, lineas: x.lineas, motivo: x.motivo, numero: x.numero, perdida: wD(x.perdida), periodo: x.periodo, ajuste_id: x.id,
    creado_el: x.creado_el, por_fuera: false, asiento_id: x.asiento_id, creado_por: UID, reverso_id: x.reverso_id || null, deshecho_el: x.deshecho_el, sustituye_a: x.sustituye_a, deshecho_por: x.deshecho_el ? UID : null,
    sub_facturado: wD(x.sub), periodo_nombre: wMes(x.periodo), reverso_numero: x.reverso_numero || null, deshecho_motivo: x.deshecho_motivo || null, reverso_auto_id: x.auto.id, sobre_facturado: wD(x.sobre),
    creado_por_nombre: 'Edgar Prueba', reverso_auto_fecha: x.auto.fecha, deshecho_por_nombre: x.deshecho_el ? 'Edgar Prueba' : null, reverso_auto_numero: x.auto.numero })),
  v_wip_revisiones: () => W.rev.map(r => ({ nota: r.nota, obra: wNomObra(r.proyecto_id), origen: r.origen, periodo: r.periodo, vigente: !r.sustituida_el, propuesta: wD(r.propuesta), terminada: r.terminada,
    proyecto_id: r.proyecto_id, revisado_el: r.el, revision_id: r.id, precio_ficha: wD(r.ficha), revisado_por: UID, sustituida_el: r.sustituida_el, costo_estimado: wD(r.costo), periodo_nombre: wMes(r.periodo),
    precio_contrato: wD(r.precio), propuesta_origen: r.propuesta_origen, revisado_por_nombre: 'Edgar Prueba' })),
  wip_config: () => [{ id: 1, actualizado: W.cfg.actualizado, exigir_desde: W.cfg.exigir_desde, actualizado_por: W.cfg.actualizado_por }]
};
const W_NO_DUENO = 'El WIP (lo ganado, lo facturado y el margen de cada obra) lo ve y lo toca solo Edgar (el dueño).';
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
  iaFallas: [], iaVuelo: 0, iaVueloMax: 0, iaSolaPref: '0', iaNiega: false,
  // (fase 8) c9 pegado o no: sin él, sus vistas contestan 404 (PGRST205), sus funciones también (PGRST202) y el bucket «cierres» no existe
  c9: false,
  // (fase 9) c10 pegado o no: sin él, sus vistas y jornal_config contestan 404 (PGRST205) y sus funciones también (PGRST202)
  c10: false,
  // (fase 10) c11 pegado o no (sin él, sus vistas y emision_config 404 y sus funciones también); la función de borde `facturas`
  // desplegada o no (sin ella, 404); y c11App: la obra de prueba con sus hitos también en la app (proyectos, hitos) para el 🧾
  // y c11EstadoFalla: v_emision_estado contesta 500 (un statement timeout) para ver que el 🧾 no adivina
  c11: false, c11Fn: true, c11App: false, c11EstadoFalla: false,
  // (fase 10) c12 pegado o no (sin él, sus vistas y wip_config 404 y sus funciones también); y el equipo (no dueño): vistas vacías y 42501
  c12: false, c12NoDueno: false };
const llamadas = [], lecturas = []; // lecturas: cada GET a /rest/v1/<vista>?… tal como lo pidió la pantalla
function tabla(nombre, q) {
  let filas = T[nombre] || [];
  // (fase 8) las vistas y tablas de c9; el mayor de la apertura y la línea de la IA de octubre; el asiento del pago al IRS
  if (C9_VISTAS[nombre]) filas = C9_VISTAS[nombre]();
  // (fase 9) las vistas de c10; con c10 la bandeja trae los cuatro Zelle de la cuadrilla (los repartidos salen) y el libro las líneas de la obra A
  if (C10_VISTAS[nombre]) filas = estado.c10 ? C10_VISTAS[nombre]() : [];
  // (fase 10) las vistas de c11 y su configuración; con c11App, la obra A de las facturas y sus hitos también en la app
  if (C11_VISTAS[nombre]) filas = estado.c11 ? C11_VISTAS[nombre]() : [];
  // (fase 10) las vistas del WIP (c12) y su configuración: el equipo las ve vacías
  if (W_VISTAS[nombre]) filas = estado.c12 && !estado.c12NoDueno ? W_VISTAS[nombre]() : [];
  if (nombre === 'proyectos' && estado.c11App) filas = filas.concat([{ id: 'c11-prueba-a', nombre: 'C11 PRUEBA Oficina Uno', estado: 'ejecucion', tipo: 'comercial', cliente: 'ZZ Cliente Uno', cliente_email: 'zz.uno@c11-pruebas.invalid' }]);
  if (nombre === 'hitos' && estado.c11App) filas = F.hitos.filter(h => h.p === 'c11-prueba-a').map(h => ({ id: h.id, proyecto_id: h.p, titulo: h.titulo, condicion: h.condicion, monto: h.monto / 100, estado: h.estado, orden: h.orden, es_deposito: h.dep }));
  if (nombre === 'finanzas_proyecto' && estado.c11App) filas = filas.concat([{ proyecto_id: 'c11-prueba-a', contrato: 18500.55, cobrado: 0 }]);
  if (nombre === 'v_banco_bandeja' && estado.c10) filas = filas.concat(J.movs.filter(m => !J.fuera.has(m.movimiento_id)));
  if (nombre === 'v_libro' && estado.c10) filas = filas.concat(J.libro);
  if (nombre === 'cuentas' && estado.c10) filas = filas.concat([['5200', 'Subcontratos', 'costo', 'obligatoria'], ['5010', 'Mano de obra (nómina)', 'costo', 'opcional'], ['7900', 'Otros gastos', 'otro_gasto', 'prohibida']].map(([codigo, nombre, tipo, regla_obra]) => ({ codigo, nombre, tipo, regla_obra, imputable: true, activa: true })));
  if (nombre === 'v_mayor' && estado.c9) filas = filas.concat(C9_MAYOR);
  if (nombre === 'asientos' && estado.c9) filas = C9_ASIENTOS;
  // las cuentas de activo fijo (15xx) y su contra-cuenta 1590, que el alta no ofrece
  if (nombre === 'cuentas' && estado.c9) filas = filas.concat([['1510', 'Vehículos'], ['1520', 'Herramienta y equipo'], ['1590', 'Depreciación acumulada']].map(([codigo, nombre]) => ({ codigo, nombre, tipo: 'activo', regla_obra: 'prohibida', imputable: true, activa: true })));
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
    const m = /^(not\.in|eq|is|lte|gte|in)\.(.*)$/.exec(v); if (!m) continue;
    const lista = m[1] === 'in' || m[1] === 'not.in' ? m[2].replace(/^\(|\)$/g, '').split(',') : null;
    filas = filas.filter(f => m[1] === 'not.in' ? !lista.includes(String(f[k])) : m[1] === 'in' ? lista.includes(String(f[k])) : m[1] === 'eq' ? String(f[k]) === m[2] : m[1] === 'is' ? (m[2] === 'null' ? f[k] == null : f[k] === (m[2] === 'true')) : m[1] === 'lte' ? String(f[k]) <= m[2] : String(f[k]) >= m[2]);
  }
  return filas;
}
function rpc(fn, a) {
  // (fase 8) las funciones de c9: sin c9 pegado, PostgREST no las encuentra
  if (C9_FN[fn]) return estado.c9 ? C9_FN[fn](a) : { status: 404, error: { code: 'PGRST202', message: `Could not find the function public.${fn} in the schema cache`, details: null, hint: null } };
  // (fase 10) las funciones de c11: sin c11 pegado, PostgREST no las encuentra
  if (C11_FN[fn]) return estado.c11 ? C11_FN[fn](a) : { status: 404, error: { code: 'PGRST202', message: `Could not find the function public.${fn} in the schema cache`, details: null, hint: null } };
  // (fase 10) las funciones del WIP (c12): sin c12 pegado, PostgREST no las encuentra; al equipo, 42501
  if (W_FN[fn]) return !estado.c12 ? { status: 404, error: { code: 'PGRST202', message: `Could not find the function public.${fn} in the schema cache`, details: null, hint: null } }
    : estado.c12NoDueno ? { status: 403, error: { code: '42501', message: W_NO_DUENO, details: null, hint: null } } : W_FN[fn](a);
  // (fase 9) las funciones de c10: sin c10 pegado, PostgREST no las encuentra
  if (C10_FN[fn]) return estado.c10 ? C10_FN[fn](a) : { status: 404, error: { code: 'PGRST202', message: `Could not find the function public.${fn} in the schema cache`, details: null, hint: null } };
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
    // (fase 10) la función de borde `facturas` (el PDF, el correo, ver); sin desplegar, 404 como Supabase
    if (u.pathname === '/functions/v1/facturas') {
      let b = {}; try { b = JSON.parse(req.postData() || '{}'); } catch { /* vacío */ }
      const auth = req.headers()['authorization'] || '';
      llamadas.push({ fn: 'facturas:' + b.accion, args: b, auth });
      if (!estado.c11Fn) return route.fulfill({ status: 404, headers: CORS, contentType: 'application/json', body: JSON.stringify({ code: 'NOT_FOUND', message: 'Requested function was not found' }) });
      const r = funcionFacturas(b, auth);
      return route.fulfill({ status: r.estado || 200, headers: CORS, contentType: 'application/json', body: JSON.stringify(r.cuerpo) });
    }
    // (fase 10) el 🧾 por QuickBooks (la función qb, de la otra sesión): se apunta y contesta como si la hubiera creado
    if (u.pathname === '/functions/v1/qb') {
      let b = {}; try { b = JSON.parse(req.postData() || '{}'); } catch { /* vacío */ }
      llamadas.push({ fn: 'qb:' + b.accion, args: b });
      return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify({ ok: true, doc: '1201', enviada: false }) });
    }
    if (u.pathname === '/functions/v1/stripe') {
      let b = {}; try { b = JSON.parse(req.postData() || '{}'); } catch { /* vacío */ }
      const auth = req.headers()['authorization'] || '';
      llamadas.push({ fn: 'stripe:' + b.accion, args: b, auth });
      // (fase 10) desactivar el enlace de una factura de la app que se anuló
      const fe = estado.c11 && b.accion === 'desactivar_enlace' ? F.enlaces.find(x => x.id === b.enlace) : null;
      if (fe) { fe.estado = 'desactivado'; return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify({ ok: true, enlace: { id: fe.id, estado: 'desactivado' } }) }); }
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
    // (fase 8) Storage, el bucket privado «cierres»: subir (nada se pisa: 409 si ya está) y firmar para bajar
    if (u.pathname.startsWith('/storage/v1/object/cierres/') && req.method() === 'POST') {
      const ruta = decodeURIComponent(u.pathname.slice('/storage/v1/object/cierres/'.length)), buf = req.postDataBuffer() || Buffer.alloc(0);
      llamadas.push({ fn: 'storage:subir-cierre', args: { ruta, bytes: buf.length, tipo: req.headers()['content-type'] || '', upsert: req.headers()['x-upsert'] || '' } });
      if (!estado.c9) return route.fulfill({ status: 400, headers: CORS, contentType: 'application/json', body: JSON.stringify({ statusCode: '404', error: 'Bucket not found', message: 'Bucket not found' }) });
      if (C9.objetos.has(ruta)) return route.fulfill({ status: 409, headers: CORS, contentType: 'application/json', body: JSON.stringify({ statusCode: '409', error: 'Duplicate', message: 'The resource already exists' }) });
      C9.objetos.set(ruta, { bytes: buf.length, sha256: sha(buf), tipo: req.headers()['content-type'] || '', texto: buf.toString('utf8') });
      return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify({ Key: 'cierres/' + ruta, Id: 'obj-' + C9.objetos.size }) });
    }
    if (u.pathname === '/storage/v1/object/sign/cierres' && req.method() === 'POST') {
      let b = {}; try { b = JSON.parse(req.postData() || '{}'); } catch { /* vacío */ }
      llamadas.push({ fn: 'storage:firmar-cierres', args: b });
      return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify((b.paths || []).map(ruta => C9.objetos.has(ruta) ? { path: ruta, signedURL: '/object/sign/cierres/' + ruta + '?token=prueba', error: null } : { path: ruta, signedURL: null, error: 'Object not found' })) });
    }
    // (fase 9) c10 sin pegar: sus vistas y jornal_config no existen (la lectura se anota igual)
    if (!estado.c10 && /^\/rest\/v1\/(v_jornal_pendientes|v_jornal_repartos|v_jornal_personas|v_jornal_control|v_margen_obra|v_margen_control|jornal_config)$/.test(u.pathname)) {
      const v = u.pathname.slice('/rest/v1/'.length);
      lecturas.push(v + u.search);
      return route.fulfill({ status: 404, headers: CORS, contentType: 'application/json', body: JSON.stringify({ code: 'PGRST205', message: `Could not find the table 'public.${v}' in the schema cache`, details: null, hint: null }) });
    }
    // (fase 10) c11 sin pegar: sus vistas y emision_config no existen (la lectura se anota igual)
    if (!estado.c11 && /^\/rest\/v1\/(v_emision_estado|v_emision_documentos|v_emision_obras|v_emision_control|emision_config)$/.test(u.pathname)) {
      const v = u.pathname.slice('/rest/v1/'.length);
      lecturas.push(v + u.search);
      return route.fulfill({ status: 404, headers: CORS, contentType: 'application/json', body: JSON.stringify({ code: 'PGRST205', message: `Could not find the table 'public.${v}' in the schema cache`, details: null, hint: null }) });
    }
    // (fase 10) v_emision_estado que contesta 500 (la base ocupada: un statement timeout)
    if (estado.c11 && estado.c11EstadoFalla && u.pathname === '/rest/v1/v_emision_estado') {
      lecturas.push('v_emision_estado' + u.search);
      return route.fulfill({ status: 500, headers: CORS, contentType: 'application/json', body: JSON.stringify({ code: '57014', message: 'canceling statement due to statement timeout', details: null, hint: null }) });
    }
    // (fase 10) c12 sin pegar: sus vistas y wip_config no existen (la lectura se anota igual)
    if (!estado.c12 && /^\/rest\/v1\/(v_wip_schedule|v_wip_obras|v_wip_control|v_wip_ajustes|v_wip_revisiones|wip_config)$/.test(u.pathname)) {
      const v = u.pathname.slice('/rest/v1/'.length);
      lecturas.push(v + u.search);
      return route.fulfill({ status: 404, headers: CORS, contentType: 'application/json', body: JSON.stringify({ code: 'PGRST205', message: `Could not find the table 'public.${v}' in the schema cache`, details: null, hint: null }) });
    }
    if (!estado.c9 && /^\/rest\/v1\/(v_cierre_estado|v_cierres|v_ronda_ultima|v_activos_fijos|v_reserva_impuestos|v_dr15_mes|cierre_config|reserva_estimados)$/.test(u.pathname)) {
      const v = u.pathname.slice('/rest/v1/'.length);
      lecturas.push(v + u.search);
      return route.fulfill({ status: 404, headers: CORS, contentType: 'application/json', body: JSON.stringify({ code: 'PGRST205', message: `Could not find the table 'public.${v}' in the schema cache`, details: null, hint: null }) });
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
const PAGS = ['resumen', 'bancos', 'bandeja', 'conciliar', 'movimientos', 'estados', 'obras', 'wip', 'cierre', 'facturas', 'cobros', 'conexiones'];
// (fase 8) la lista de respaldo de js/app.js (CONTA_PAGINAS_FIJAS, por si conta.js no cargó) trae las mismas doce, «cierre», (fase 9) «obras» y (fase 10) «facturas» y «wip» incluidas
const PAGS_APP = PAGS;
// cambiar de página por su pestaña: en la computadora (≥ 1024 px) las pestañas están escondidas (las enseña el lateral de app.js), así que el clic es del DOM
const titulo2 = async pg => (await pg.locator('#titulo-vista').textContent()).trim();
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
  ok('…y la pestaña «Contabilidad» en el lateral con las 10 páginas como subtítulos (conta-<k>, los que da MXP_CONTA.paginas(): «Costo por obra» y «Cierre del mes» incluidas), y el botón de la barra de abajo', (await p.locator('#lateral [data-lat="conta"]').count()) === 1 &&
    JSON.stringify(await p.locator('#lateral [data-lat^="conta-"]').evaluateAll(bs => bs.map(b => b.dataset.lat))) === JSON.stringify(PAGS.map(k => 'conta-' + k)) && (await p.locator('#nav-abajo button[data-nav="conta"]').getAttribute('hidden')) === null);

  // ---- La portada («Resumen»): control antes de pintar, las fichas y «Qué atender» ----
  let n = llamadas.length; let nLect = lecturas.length;
  await p.locator('#btn-conta').evaluate(b => b.click());
  await p.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 });
  ok('Al entrar, la vista de la contabilidad se ve, la página es «Resumen» (la portada) y la pestaña «resumen» está marcada', await p.locator('#vista-conta').isVisible() && (await p.locator('#titulo-vista').textContent()).trim() === 'Resumen' && (await p.locator('.ct-tab[data-pag="resumen"][aria-current="page"]').count()) === 1, await p.locator('#titulo-vista').textContent());
  const pags = await p.evaluate(() => window.MXP_CONTA.paginas().map(x => [x.k, x.nombre, /^<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"/.test(x.svg) && /<\/svg>$/.test(x.svg)]));
  ok('MXP_CONTA.paginas() da las 12 páginas en su orden (Costo por obra después de Estados y, desde la fase 10, el WIP entre Costo por obra y Cierre del mes, y Facturas antes de Cobros en línea), con su nombre y un svg del estilo del menú', JSON.stringify(pags.map(x => x[0])) === JSON.stringify(PAGS) && pags.every(x => x[2]) && pags.map(x => x[1]).join('|') === 'Resumen|Bancos y tarjetas|Bandeja|Conciliar|Movimientos|Estados financieros|Costo por obra|WIP (obra en curso)|Cierre del mes|Facturas|Cobros en línea|Conexiones y seguridad', JSON.stringify(pags));
  ok('La página no repite el título que ya pone la barra de la app: la cabecera trae la línea de cifras y, como aria-label, el nombre', (await p.locator('.ct-pag-h').count()) === 0 && (await p.locator('.ct-pag-cab').getAttribute('aria-label')) === 'Resumen' && (await p.locator('.ct-pag-sub').count()) === 1);
  {
    // la lista de respaldo de app.js (por si conta.js no cargó) lleva los mismos trazos que ICONOS de conta.js: el lateral y las pestañas nunca enseñan iconos distintos para la misma página
    const appJs = fs.readFileSync(path.join(ROOT, 'js', 'app.js'), 'utf8'), contaJs = fs.readFileSync(path.join(ROOT, 'js', 'conta.js'), 'utf8');
    const fijos = Object.fromEntries([...appJs.matchAll(/\{ k: "(\w+)", nombre: "[^"]+", svg: SVG_MENU\('([^']*)'\) \}/g)].map(m => [m[1], m[2]]));
    const iconos = Object.fromEntries([...contaJs.matchAll(/^\s+(\w+): svgMenu\('([^']*)'\),?$/gm)].map(m => [m[1], m[2]]));
    ok('La lista de respaldo CONTA_PAGINAS_FIJAS de app.js trae las 12 páginas en el mismo orden y con los mismos trazos que ICONOS de conta.js («Costo por obra», «WIP», «Cierre del mes» y «Facturas» incluidas)', JSON.stringify(Object.keys(fijos)) === JSON.stringify(PAGS_APP) && PAGS_APP.every(k => fijos[k] && fijos[k] === iconos[k]), PAGS_APP.filter(k => fijos[k] !== iconos[k]).join(',') || Object.keys(fijos).join(','));
  }
  ok('En la computadora (1280 px) las pestañas de arriba van escondidas (las enseña el lateral), pero siguen en el DOM con sus 12 páginas', (await p.locator('.ct-tabs').evaluate(e => getComputedStyle(e).display)) === 'none' && (await p.locator('.ct-tab').count()) === PAGS.length && JSON.stringify(await p.locator('.ct-tab').evaluateAll(bs => bs.map(b => b.dataset.pag))) === JSON.stringify(PAGS));
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
  // (fase 8) lo más viejo de la bandeja es del 2 oct: desde el 2 nov pasa de 30 días y «Qué atender» lo dice primero (→ Bandeja). La prueba
  // lo tenía fijo en dos filas y empezó a fallar sola el 2 nov: ahora cuenta con esa fila cuando toca
  const atnBandeja = diasViejo > 30 ? 1 : 0;
  ok('«Qué atender»: (lo de más de 30 días en la bandeja, si toca), el código del teléfono no activo (→ Conexiones) y la cuenta de Plaid sin fijar (→ Conexiones); nada de Stripe (su control está en verde) ni de la ronda (sin c9)', atn.length === 2 + atnBandeja && (!atnBandeja || /más de 30 días en la bandeja/.test(atn[0])) && /El código del teléfono .*no está activo/.test(atn[atnBandeja]) && /Platypus Bank: 1 cuenta del banco sin fijar/.test(atn[atnBandeja + 1]) && (await p.locator('#ct-atender .ct-atn button[data-ir="conexiones"]').count()) === 2, atn.join(' | '));
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
  ok('Las pestañas van en el orden del menú: Resumen, Bancos, Bandeja, Conciliar, Movimientos, Estados, Obras, WIP, Cierre, Facturas, Cobros, Conexiones (cada una con su icono)', JSON.stringify(await p.locator('.ct-tab').evaluateAll(bs => bs.map(b => b.dataset.pag))) === JSON.stringify(PAGS) && (await p.locator('.ct-tab svg').count()) === PAGS.length && /Estados/.test(await p.locator('.ct-tab').nth(5).textContent()) && /Obras/.test(await p.locator('.ct-tab').nth(6).textContent()) && /WIP/.test(await p.locator('.ct-tab').nth(7).textContent()) && /Cierre/.test(await p.locator('.ct-tab').nth(8).textContent()));
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
    ok('Teléfono (390 px): las 12 pestañas van arriba, a la vista, deslizan con tope (scroll-snap)', tabsTel.display !== 'none' && tabsTel.n === PAGS.length && tabsTel.desliza && /x/.test(tabsTel.snap), JSON.stringify(tabsTel));
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

  // ---- El cierre del mes (c9, fase 8): la ronda en «Qué atender», la revisión con lo que detiene y su ir_a, el botón apagado y
  // encendido, la confirmación mal escrita que no cierra, cerrar → el export subido y registrado con su sha256 (y la huella
  // del mayor que el README enseña a comprobar, recalculada aquí desde el CSV), descargar, imprimir, MX010, la huella que no
  // coincide (no exporta) y «Volver a exportar», los activos (alta, depreciar, baja), la reserva sin y con %, el DR-15, el
  // historial, los ajustes, sin c9, la falla ruidosa de la revisión, y el teléfono, el iPad y la computadora ----
  {
    estado.c9 = true; c9Reset();
    const MES_C = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    const fLarga = iso => { const [a, m, d] = iso.split('-').map(Number); return `${d} ${MES_C[m]} ${a}`; };
    const conCodigo = si => { estado.mfaFactores = si ? [{ id: 'f-1', friendly_name: 'Teléfono de Edgar', factor_type: 'totp', status: 'verified' }] : []; estado.sesionAal = si ? 'aal2' : undefined; };
    const abrirCtx = async (w, codigo) => {
      conCodigo(codigo);
      const cx = await b.newContext({ viewport: { width: w, height: w < 700 ? 844 : 1000 }, deviceScaleFactor: w < 1024 ? 2 : 1, isMobile: w < 1024, hasTouch: w < 1024, serviceWorkers: 'block' });
      await simular(cx, 'dueno');
      const q = await cx.newPage(); q.on('pageerror', e => errs.push(`cierre ${w}: ` + String(e).slice(0, 160)));
      await q.goto('http://localhost:8873/index.html'); await q.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await q.waitForTimeout(800);
      await q.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
      await q.locator('#btn-conta').evaluate(x => x.click()); await q.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 }); await pintado(q);
      return { cx, q };
    };
    const cie = async (q, sub, periodo) => { await q.evaluate(([s, pe]) => window.MXP_CONTA.ir('cierre', Object.assign({}, s ? { sub: s } : {}, pe ? { periodo: pe } : {})), [sub || null, periodo || null]); await pintado(q); };
    // la última ronda: el asiento de apertura falta (detiene) y la reserva sin % (aviso); dos en verde
    C9.ronda = [
      { id: 898, periodo: '2026-09-APERTURA', orden: 20, control: 'apertura: su asiento de apertura está vivo', nivel: 'detiene', ok: false, detalle: 'Falta el asiento de apertura del 2026-09-30 (o se reversó): cerrada vacía, la balanza de QuickBooks ya no tendría dónde entrar (c2).', que_hacer: 'Carga la balanza de QuickBooks al 30-sep (fn_apertura_balanza_cargar), mapea sus cuentas y postéala (fn_apertura, c4); después audítala.', ir_a: 'estados' },
      { id: 899, periodo: '2026-09-APERTURA', orden: 30, control: 'cuadre: debe = haber en el período', nivel: 'detiene', ok: true, detalle: '1 asiento y 2 líneas en la apertura (30-sep-2026): debe $25,000.00 = haber $25,000.00.', que_hacer: null, ir_a: 'conexiones' },
      { id: 1144, periodo: null, orden: 220, control: 'reserva: 1030', nivel: 'aviso', ok: false, detalle: 'Falta el % que fije el CPA: cuando lo diga, guárdalo en Cierre → ajustes (fn_cierre_config, reserva_pct) y aquí saldrá cuánto transferir a la reserva (1030).', que_hacer: 'Pregunta al CPA el % y guárdalo en Cierre → ajustes.', ir_a: 'cierre' },
      { id: 1145, periodo: null, orden: 222, control: 'reserva: próximo estimado', nivel: 'aviso', ok: true, detalle: 'El próximo impuesto estimado vence el 2027-01-15.', que_hacer: null, ir_a: 'cierre' }
    ];
    // ---- sin el código del teléfono (1280 px) ----
    let { cx, q } = await abrirCtx(1280, false);
    let n0 = llamadas.length, l0 = lecturas.length;
    const atnC = await q.locator('#ct-atender .ct-atn').allTextContents();
    const atnRonda = atnC.filter(t => /La ronda/.test(t));
    ok('Cierre · la ronda en «Qué atender»: el Resumen lee v_ronda_ultima y pinta sus 2 rojos (lo que detiene primero, con su período y su detalle), cada uno con un botón «Cierre»',
      atnRonda.length === 2 && /^La ronda de hoy · la apertura: Apertura: su asiento de apertura está vivo \(detiene el cierre\)\.Falta el asiento de apertura del 2026-09-30/.test(atnRonda[0]) && /^La ronda de hoy: Reserva: 1030\./.test(atnRonda[1]) &&
      (await q.locator('#ct-atender button[data-ir="cierre"]').count()) === 2 && (await q.locator('#ct-atender button[data-ir="cierre"]').first().textContent()).trim() === 'Cierre', atnC.join(' | '));
    await foto(q, 'cierre-0-resumen-ronda');
    n0 = llamadas.length; l0 = lecturas.length;
    await q.locator('#ct-atender button[data-ir="cierre"]').first().click(); await q.waitForSelector('#ct-cie-rev', { timeout: 12000 }); await pintado(q);
    ok('…y su botón abre «Cierre del mes» (el título de la app, la pestaña y el subtítulo del lateral encendidos)', (await q.locator('#titulo-vista').textContent()).trim() === 'Cierre del mes' && (await q.locator('.ct-tab[data-pag="cierre"][aria-current="page"]').count()) === 1 && (await q.locator('#lateral [data-lat="conta-cierre"][aria-current="page"]').count()) === 1);
    const rev0 = desde(n0).filter(l => l.fn === 'fn_cierre_revisar');
    ok('Cierre · al abrir: lee v_cierre_estado, pide fn_cierre_revisar del período que toca (la apertura) y vuelve a leer v_cierre_estado (la foto que la base acaba de guardar) y la ronda', rev0.length === 1 && rev0[0].args.p_periodo === '2026-09-APERTURA' && Object.keys(rev0[0].args).join() === 'p_periodo' &&
      lecturas.slice(l0).filter(l => /^v_cierre_estado\?/.test(l)).length === 2 && lecturas.slice(l0).some(l => /^v_ronda_ultima\?/.test(l)), JSON.stringify(rev0.map(x => x.args)));
    const per = await q.locator('.ct-cie-per').allTextContents();
    ok('Cierre · los períodos: la apertura «Toca cerrar» (1 cosa lo detiene · 3 avisos), octubre «Abierto» sin revisar, y los meses que aún no empiezan no salen', per.length === C9_PER.filter(p => p.desde <= HOY).length && /La apertura \(30-sep-2026\)\s*Toca cerrar\s*1 cosa lo detiene · 3 avisos/.test(per[0]) && /Octubre de 2026\s*Abierto\s*sin revisar todavía/.test(per[1]), per.join(' | '));
    ok('Cierre · la cabecera dice qué toca: «Toca cerrar la apertura (30-sep-2026) · 1 cosa lo detiene · 3 avisos»', /Toca cerrar la apertura \(30-sep-2026\) · 1 cosa lo detiene · 3 avisos/.test(await texto(q, '.ct-pag-sub')), await texto(q, '.ct-pag-sub'));
    const det0 = await q.locator('#ct-cie-rev .ct-cie-item.detiene').allTextContents();
    ok('Cierre · lo que detiene, arriba y en rojo: el control con su detalle en llano, «Qué hacer» y el botón a la página que lo arregla (ir_a → Estados)', det0.length === 1 && /Apertura: su asiento de apertura está vivo/.test(det0[0]) && /Falta el asiento de apertura del 2026-09-30/.test(det0[0]) && /Qué hacer: Carga la balanza de QuickBooks/.test(det0[0]) &&
      (await q.locator('#ct-cie-rev .ct-cie-item.detiene button[data-ir="estados"]').textContent()).trim() === 'Estados', det0.join(' | '));
    const nAv = await q.locator('#ct-cie-avisos > .ct-cie-lista > .ct-cie-item.aviso').count(), nVer = await q.locator('#ct-cie-avisos .ct-cie-verdes .ct-cie-item.ok').count();
    ok('Cierre · los avisos aparte (3 en ámbar, cada uno con su página: Estados, Cobros, Bandeja) y lo que está en verde plegado (6)', nAv === 3 && nVer === 6 && (await q.locator('#ct-cie-avisos details.ct-cie-verdes').getAttribute('open')) === null &&
      (await q.locator('#ct-cie-avisos > .ct-cie-lista button[data-ir]').evaluateAll(bs => bs.map(x => x.dataset.ir).join())) === 'estados,cobros,bandeja', `${nAv} avisos · ${nVer} en verde`);
    ok('Cierre · «Cerrar la apertura» apagado mientras algo detiene, y dice por qué', await q.locator('#ct-cie-cerrar').isDisabled() && (await q.locator('#ct-cie-cerrar').textContent()).trim() === 'Cerrar la apertura' && /Se enciende cuando no quede nada en rojo arriba \(1 cosa\)/.test(await q.locator('#ct-cie-porque').textContent()));
    ok('Cierre · la ronda en la página: cuándo corrió, qué revisó y sus rojos con su nivel (detiene / aviso)', /Corrió el 6 nov 2026 06:45 · revisó la apertura · 4 controles: 1 detiene y 1 aviso en rojo/.test(await texto(q, '#ct-cie-ronda .ct-nota')) && (await q.locator('#ct-cie-ronda .ct-cie-item').count()) === 2 &&
      /detiene/.test(await texto(q, '#ct-cie-ronda .ct-cie-item.detiene .ct-pill')) && (await q.locator('#ct-cie-ronda .ct-cie-item.aviso button[data-cie-ir="reserva"]').count()) === 1, await texto(q, '#ct-cie-ronda .ct-nota'));
    await foto(q, 'cierre-1-revision-apertura');
    await q.locator('#ct-cie-rev button[data-ir="estados"]').click(); await q.waitForSelector('#ct-est-barra', { timeout: 8000 });
    ok('Cierre · el botón del control lleva a la página que lo arregla (Estados financieros)', (await q.locator('#titulo-vista').textContent()).trim() === 'Estados financieros');
    // la apertura ya tiene su asiento: nada detiene, pero sin el código del teléfono el botón sigue apagado
    C9.rojos.aperturaViva = false;
    await tab(q, 'cierre'); await q.waitForSelector('#ct-cie-rev', { timeout: 12000 }); await pintado(q);
    ok('Cierre · nada en rojo pero sin el código del teléfono: «Nada detiene…» y el botón sigue apagado, diciendo que falta el código', (await q.locator('#ct-cie-rev .ct-cie-item.detiene').count()) === 0 && /Nada detiene el cierre de la apertura/.test(await texto(q, '#ct-cie-rev')) &&
      await q.locator('#ct-cie-cerrar').isDisabled() && /activa el código del teléfono/.test(await q.locator('#ct-cie-porque').textContent()));
    // falla ruidosa: v_cierre_estado no dice lo mismo que la revisión
    C9.estadoMal = true; n0 = llamadas.length;
    await q.locator('#ct-cie-revisar').click(); await q.waitForTimeout(200); await pintado(q);
    ok('Cierre · falla ruidosa: «Volver a revisar» pide otra revisión; si v_cierre_estado no dice lo que trajo, rojo con el detalle (1 / 3 contra 0 / 3), sin botón de cerrar y con los apartados a mano', desde(n0).some(l => l.fn === 'fn_cierre_revisar') && /La revisión guardada no coincide/.test(await texto(q, '.ct-rojo h2')) &&
      /1 \/ 3/.test(await texto(q, '.ct-rojo')) && /0 \/ 3/.test(await texto(q, '.ct-rojo')) && (await q.locator('#ct-cie-cerrar').count()) === 0 && (await q.locator('.ct-cie-subs .ct-chip').count()) === 6);
    C9.estadoMal = false;
    // sin c9 pegado
    estado.c9 = false;
    await cie(q, 'cierre');
    ok('Cierre · sin c9 pegado: «Falta el cierre en la base» en llano (qué pegar y dónde), sin cifras ni botones de cerrar', /Falta el cierre en la base/.test(await texto(q, '.ct-rojo h2')) && /c9-cierre\.sql/.test(await texto(q, '.ct-rojo')) && (await q.locator('.ct-cie-per, #ct-cie-cerrar').count()) === 0);
    await cie(q, 'activos');
    ok('…igual en cualquier apartado (Activos fijos)', /Falta el cierre en la base/.test(await texto(q, '.ct-rojo h2')));
    estado.c9 = true;
    await cx.close();

    // ---- con el código del teléfono (aal2), 1280 px: cerrar la apertura y exportarla ----
    ({ cx, q } = await abrirCtx(1280, true));
    await cie(q, 'cierre');
    ok('Cierre · con el código y nada en rojo, «Cerrar la apertura» se enciende y avisa que se pide escribir la frase', !(await q.locator('#ct-cie-cerrar').isDisabled()) && /se pide escribir «CERRAR LA APERTURA»/.test(await q.locator('#ct-cie-porque').textContent()));
    await q.locator('#ct-cie-cerrar').click(); await q.waitForSelector('.ct-cie-confirma', { timeout: 5000 });
    ok('Cierre · la confirmación fuerte: «no se deshace», qué pasa después (nadie escribe, lo tardío al mes abierto, el export), la frase exacta resaltada y su botón rojo apagado', /cerrarlo no se deshace/.test(await texto(q, '.ct-cie-confirma .ct-form-t')) && (await q.locator('.ct-cie-conse li').count()) === 3 &&
      (await q.locator('.ct-cie-frase').textContent()) === 'CERRAR LA APERTURA' && await q.locator('#ct-cie-confirmar').isDisabled() && (await q.locator('#ct-cie-confirmar').evaluate(x => x.classList.contains('ct-cie-peligro'))));
    await foto(q, 'cierre-2-confirmacion');
    n0 = llamadas.length;
    await q.fill('.ct-cie-confirma input[name="confirmo"]', 'cerrar la apertura');
    const apagadoMal = await q.locator('#ct-cie-confirmar').isDisabled();
    await q.locator('.ct-cie-confirma').evaluate(f => f.requestSubmit()); await q.waitForTimeout(250);
    ok('Cierre · la frase mal escrita («cerrar la apertura») no cierra: el botón sigue apagado y, aunque se fuerce el envío, se explica y no se manda nada a la base', apagadoMal && /Escribe exactamente «CERRAR LA APERTURA»/.test(await texto(q, '#ct-cie-rev .ct-error')) &&
      !desde(n0).some(l => l.fn === 'fn_cierre_cerrar') && C9.estado['2026-09-APERTURA'] === 'abierto');
    await q.fill('.ct-cie-confirma input[name="confirmo"]', '  CERRAR LA APERTURA ');
    ok('…escrita exacta (los espacios de los lados no cuentan, como en la base), el botón rojo se enciende: «Cerrar la apertura para siempre»', !(await q.locator('#ct-cie-confirmar').isDisabled()) && (await q.locator('#ct-cie-confirmar').textContent()).trim() === 'Cerrar la apertura para siempre' && (await q.locator('#ct-cie-rev .ct-error').count()) === 0);
    n0 = llamadas.length;
    await q.locator('#ct-cie-confirmar').click();
    await esperarLlamada(q, n0, 'fn_cierre_export'); await q.waitForTimeout(200); await pintado(q);
    const cer = desde(n0).find(l => l.fn === 'fn_cierre_cerrar');
    const subidas = desde(n0).filter(l => l.fn === 'storage:subir-cierre'), reg = desde(n0).find(l => l.fn === 'fn_cierre_export');
    ok('Cierre · cerrar manda fn_cierre_cerrar con el período y la frase exacta, y la base lo cierra', !!cer && JSON.stringify(cer.args) === JSON.stringify({ p_periodo: '2026-09-APERTURA', p_confirmo: 'CERRAR LA APERTURA' }) && C9.estado['2026-09-APERTURA'] === 'cerrado', JSON.stringify(cer && cer.args));
    const carpeta = subidas.length ? subidas[0].args.ruta.replace(/[^/]+$/, '') : '';
    ok('Cierre · justo después, el export en el navegador: mayor, balanza, estados y README subidos al bucket «cierres» en <periodo>/<fecha-hora de Miami>/, sin pisar nada (x-upsert false)', subidas.length === 4 && /^2026-09-APERTURA\/\d{4}-\d{2}-\d{2}_\d{6}\/$/.test(carpeta) &&
      JSON.stringify(subidas.map(x => x.args.ruta.slice(carpeta.length))) === JSON.stringify(['mayor-2026-09-APERTURA.csv', 'balanza-2026-09-APERTURA.csv', 'estados-2026-09-APERTURA.html', 'README-2026-09-APERTURA.txt']) &&
      subidas.every(x => x.args.upsert === 'false' && /charset=utf-8/.test(x.args.tipo)), JSON.stringify(subidas.map(x => x.args.ruta)));
    const regArch = reg ? reg.args.p_archivos : [];
    ok('…y registrado con fn_cierre_export(p_periodo, p_archivos): cada archivo con su ruta, el sha256 de los bytes que llegaron al bucket, su tamaño y su tipo', !!reg && Object.keys(reg.args).join() === 'p_periodo,p_archivos' && reg.args.p_periodo === '2026-09-APERTURA' && regArch.length === 4 &&
      regArch.every(f => C9.objetos.has(f.ruta) && C9.objetos.get(f.ruta).sha256 === f.sha256 && C9.objetos.get(f.ruta).bytes === f.bytes && Object.keys(f).join() === 'ruta,sha256,bytes,tipo') && C9.cierres['2026-09-APERTURA'].export_archivos.length === 4, JSON.stringify(regArch).slice(0, 300));
    // el CSV del mayor, leído como lo leería el CPA, y la receta del README sobre él
    const leerCsv = t => { const filas = []; let f = [], c = '', dentro = false;
      for (let i = 0; i < t.length; i++) { const ch = t[i];
        if (dentro) { if (ch === '"') { if (t[i + 1] === '"') { c += '"'; i++; } else dentro = false; } else c += ch; }
        else if (ch === '"') dentro = true; else if (ch === ',') { f.push(c); c = ''; } else if (ch === '\n') { f.push(c); filas.push(f); f = []; c = ''; } else if (ch !== '\r') c += ch; }
      if (c || f.length) { f.push(c); filas.push(f); } return filas; };
    const receta = txt => { const [cab, ...lin] = leerCsv(txt.replace(/^﻿/, '')); const col = k => cab.indexOf(k);
      return { cab, lin, texto: [...lin].sort((x, y) => x[col('fecha')].localeCompare(y[col('fecha')]) || x[col('cadena_pos')] - y[col('cadena_pos')] || x[col('orden')] - y[col('orden')])
        .map(r => ['numero', 'fecha', 'orden', 'cuenta', 'monto', 'proyecto_id', 'cost_code', 'memo'].map(k => r[col(k)]).join('|')).join('\n'), col }; };
    const mAp = C9.objetos.get(carpeta + 'mayor-2026-09-APERTURA.csv'), rAp = mAp ? receta(mAp.texto) : { cab: [], lin: [], texto: '', col: () => -1 };
    ok('Cierre · el CSV del mayor: por cuenta, con saldo corrido, procedencia, sello de la IA y papel; el memo con coma y comillas bien escapado; y la receta del README sobre el CSV da la huella que la base guardó al cerrar', ['saldo_corrido', 'procedencia', 'sello_ia', 'origen_tabla', 'documento_ruta', 'cadena_pos'].every(k => rAp.cab.includes(k)) && rAp.lin.length === 2 &&
      rAp.lin.some(r => r[rAp.col('memo')] === 'Balanza de QuickBooks, 30-sep "apertura"') && rAp.lin.every(r => /^-?\d+\.\d{2}$/.test(r[rAp.col('monto')])) && sha(Buffer.from(rAp.texto, 'utf8')) === C9.cierres['2026-09-APERTURA'].hash_mayor, rAp.texto);
    const leeme = (C9.objetos.get(carpeta + 'README-2026-09-APERTURA.txt') || {}).texto || '';
    ok('…el README lleva la huella del mayor (de cierres), el sha256 de los otros tres archivos, la receta para comprobarla sin la app y que el correo llega después; la balanza cierra con su TOTAL', leeme.includes(C9.cierres['2026-09-APERTURA'].hash_mayor) && regArch.slice(0, 3).every(f => leeme.includes(f.sha256 + '  ' + f.ruta.split('/').pop())) &&
      /shasum -a 256/.test(leeme) && /numero\|fecha\|orden\|cuenta\|monto\|proyecto_id\|cost_code\|memo/.test(leeme) && /llega después/.test(leeme) && /TOTAL,debe = haber; los saldos suman 0,0\.00,25000\.00,25000\.00,0\.00/.test((C9.objetos.get(carpeta + 'balanza-2026-09-APERTURA.csv') || {}).texto || ''));
    const estAp = (C9.objetos.get(carpeta + 'estados-2026-09-APERTURA.html') || {}).texto || '';
    ok('…y los estados, en una página lista para imprimir a PDF, con el período, la huella y la balanza', /<title>Estados 2026-09-APERTURA · Max Power<\/title>/.test(estAp) && estAp.includes(C9.cierres['2026-09-APERTURA'].hash_mayor) && /Balanza de comprobación/.test(estAp) && !/<script/i.test(estAp));
    ok('Cierre · tras el export: la apertura «Cerrado» con su huella entera, «Exportado el … · 4 archivos en cierres/2026-09-APERTURA/», «Descargar el cierre», «Imprimir los estados» y el correo dicho en llano', /Cerrado/.test(await texto(q, '#ct-cie-rev .ct-cab .ct-pill')) && (await texto(q, '.ct-cie-huella')).includes(C9.cierres['2026-09-APERTURA'].hash_mayor) &&
      /Exportado el .* · 4 archivos en cierres\/2026-09-APERTURA\//.test(await texto(q, '#ct-cie-export')) && (await q.locator('#ct-cie-export [data-cie-descargar="2026-09-APERTURA"]').count()) === 1 && /función «correo» todavía no tiene esa acción/.test(await texto(q, '#ct-cie-export')), await texto(q, '#ct-cie-export'));
    await foto(q, 'cierre-3-exportado');
    n0 = llamadas.length;
    await q.locator('[data-cie-descargar="2026-09-APERTURA"]').click(); await q.waitForSelector('.ct-cie-archivo[href]', { timeout: 5000 });
    const firma = desde(n0).find(l => l.fn === 'storage:firmar-cierres'), hrefs = await q.locator('.ct-cie-archivo').evaluateAll(as => as.map(a => a.getAttribute('href')));
    ok('Cierre · «Descargar el cierre» firma las 4 rutas del export (una hora, como las fotos) y da un enlace por archivo, con su nombre para guardarlo', !!firma && firma.args.expiresIn === 3600 && JSON.stringify(firma.args.paths) === JSON.stringify(regArch.map(f => f.ruta)) && hrefs.length === 4 &&
      hrefs.every((h, i) => h.includes('/storage/v1/object/sign/cierres/' + regArch[i].ruta + '?token=prueba&download=' + encodeURIComponent(regArch[i].ruta.split('/').pop()))), JSON.stringify(hrefs).slice(0, 300));
    const [pop] = await Promise.all([cx.waitForEvent('page', { timeout: 8000 }), q.locator('#ct-cie-export [data-cie-imprimir="2026-09-APERTURA"]').click()]);
    await pop.waitForFunction(() => /Estados 2026-09-APERTURA/.test(document.title), null, { timeout: 8000 }).catch(() => {});
    ok('Cierre · «Imprimir los estados (PDF)» abre los estados en una ventana con la ventana de imprimir (el camino de imprimir de la app)', /Estados 2026-09-APERTURA · Max Power/.test(await pop.title()));
    await pop.close();

    // ---- octubre: lo que detiene, los activos (alta → el 92 en rojo → depreciar → baja), la reserva y el DR-15 ----
    await q.locator('[data-cie-periodo="2026-10"]').click(); await pintado(q);
    const detO = await q.locator('#ct-cie-rev .ct-cie-item.detiene').evaluateAll(xs => xs.map(x => x.dataset.orden));
    ok('Cierre · octubre (ahora el que toca): 3 cosas lo detienen (el banco sin clasificar → Bandeja, sin conciliar y sin archivos al 31 → Conciliar) y «Cerrar octubre 2026» apagado', JSON.stringify(detO) === '["40","50","111"]' && (await q.locator('#ct-cie-rev .ct-cie-item.detiene button[data-ir="bandeja"]').count()) === 1 &&
      (await q.locator('#ct-cie-rev .ct-cie-item.detiene button[data-ir="conciliar"]').count()) === 2 && await q.locator('#ct-cie-cerrar').isDisabled() && (await q.locator('#ct-cie-cerrar').textContent()).trim() === 'Cerrar octubre 2026', JSON.stringify(detO));
    await cie(q, 'activos');
    ok('Activos · sin activos: el vacío dice que se cargan con la cédula del CPA (con lo que traían en QuickBooks), y «Dar de alta un activo»', /Se cargan con la cédula del CPA \(la de 2025 más las altas de 2026\), cada uno con la depreciación que ya traía en QuickBooks/.test(await texto(q, '#ct-cie-activos .ct-af-vacio')) && (await q.locator('#ct-af-alta').count()) === 1 && (await q.locator('#ct-af-depreciar').count()) === 0);
    await q.locator('#ct-af-alta').click(); await q.waitForSelector('#ct-cie-activos form', { timeout: 5000 });
    const ops15 = await q.locator('#ct-cie-activos select[name="cuenta"] option').evaluateAll(os => os.map(o => o.value).filter(Boolean));
    ok('Activos · el alta ofrece solo las cuentas 15xx (nunca 1590, la depreciación acumulada) y el método del CPA ya elegido', JSON.stringify(ops15) === '["1510","1520"]' && (await q.locator('#ct-cie-activos select[name="metodo"]').inputValue()) === 'linea_recta', JSON.stringify(ops15));
    n0 = llamadas.length;
    await q.locator('#ct-cie-activos form button[type="submit"]').click(); await q.waitForTimeout(200);
    ok('Activos · sin descripción no se manda nada y se dice qué falta, con un ejemplo', /Falta qué es el activo/.test(await texto(q, '#ct-cie-activos .ct-error')) && !desde(n0).some(l => l.fn === 'fn_activo_alta'));
    await q.fill('#ct-cie-activos input[name="descripcion"]', 'Camioneta Ford F-150 2024');
    await q.fill('#ct-cie-activos input[name="placa_serie"]', '1FTFW1E5XPFA12345');
    await q.selectOption('#ct-cie-activos select[name="cuenta"]', '1510');
    await q.fill('#ct-cie-activos input[name="fecha_servicio"]', '2026-09-30');
    await q.fill('#ct-cie-activos input[name="costo"]', '$48,000');
    await q.fill('#ct-cie-activos input[name="residual"]', '8,000.00');
    await q.fill('#ct-cie-activos input[name="vida_meses"]', '60');
    await q.fill('#ct-cie-activos input[name="notas"]', 'cédula del CPA, f12');
    n0 = llamadas.length;
    await q.locator('#ct-cie-activos form button[type="submit"]').click(); await esperarLlamada(q, n0, 'fn_activo_alta'); await pintado(q);
    const alta = desde(n0).find(l => l.fn === 'fn_activo_alta');
    const ordenado = o => JSON.stringify(Object.keys(o || {}).sort().reduce((x, k) => (x[k] = o[k], x), {}));
    ok('Activos · el alta manda fn_activo_alta({p}) con las claves del contrato: los montos limpios ($ y comas fuera), la vida en meses como número y el método', !!alta && Object.keys(alta.args).join() === 'p' &&
      ordenado(alta.args.p) === ordenado({ descripcion: 'Camioneta Ford F-150 2024', cuenta: '1510', fecha_servicio: '2026-09-30', costo: '48000', metodo: 'linea_recta', placa_serie: '1FTFW1E5XPFA12345', residual: '8000.00', vida_meses: 60, notas: 'cédula del CPA, f12' }), JSON.stringify(alta && alta.args));
    const filaAf = await texto(q, '#ct-cie-activos tr.ct-af');
    ok('Activos · la lista (v_activos_fijos): el activo con su serie y cuenta, el costo, lo acumulado, el valor en libros y la cuota al mes', /Camioneta Ford F-150 2024/.test(filaAf) && /1FTFW1E5XPFA12345 · 1510 Vehículos · línea recta, 60 meses/.test(filaAf) && /\$48,000\.00/.test(filaAf) && /\$666\.67/.test(filaAf) && /0 meses en el libro/.test(filaAf), filaAf);
    ok('Activos · falta el asiento de octubre: «Falta la depreciación de octubre de 2026: $666.67 en 1 activo» con «Depreciar octubre de 2026»', /Falta la depreciación de octubre de 2026: \$666\.67 en 1 activo/.test(await texto(q, '.ct-af-dep')) && (await q.locator('#ct-af-depreciar').textContent()).trim() === 'Depreciar octubre de 2026' &&
      desde(n0).some(l => l.fn === 'fn_depreciacion_plan' && l.args.p_periodo === '2026-10'));
    await cie(q, 'cierre');
    ok('Cierre · con el activo vivo, octubre suma «la depreciación del mes posteada» a lo que detiene, con su botón a Activos fijos', (await q.locator('#ct-cie-rev .ct-cie-item.detiene[data-orden="92"] button[data-cie-ir="activos"]').count()) === 1);
    await q.locator('#ct-cie-rev .ct-cie-item.detiene[data-orden="92"] button[data-cie-ir="activos"]').click(); await pintado(q);
    ok('…y ese botón abre el apartado de los activos', (await q.locator('.ct-cie-subs [data-cie-sub="activos"][aria-pressed="true"]').count()) === 1 && (await q.locator('#ct-af-depreciar').count()) === 1);
    n0 = llamadas.length;
    await q.locator('#ct-af-depreciar').click(); await esperarLlamada(q, n0, 'fn_depreciacion_mes'); await pintado(q);
    const dep = desde(n0).find(l => l.fn === 'fn_depreciacion_mes');
    ok('Activos · «Depreciar octubre de 2026» manda fn_depreciacion_mes(2026-10); la base lo postea y la pantalla enseña su nota, el activo con $666.67 acumulados y $47,333.33 en libros, y ya no pide depreciar', !!dep && JSON.stringify(dep.args) === '{"p_periodo":"2026-10"}' &&
      /Posteada la depreciación de octubre de 2026: \$666\.67 en 1 activo\(s\) \(asiento 2026-000004/.test(await texto(q, '#ct-cie-activos')) && /\$47,333\.33/.test(await texto(q, '#ct-cie-activos tr.ct-af')) && /1 mes en el libro/.test(await texto(q, '#ct-cie-activos tr.ct-af')) &&
      (await q.locator('#ct-af-depreciar').count()) === 0 && /La depreciación de octubre de 2026 ya está en el libro/.test(await texto(q, '#ct-cie-activos')));
    await q.locator('#ct-cie-activos [data-af-baja]').click(); await q.waitForSelector('#ct-cie-activos form textarea[name="motivo"]', { timeout: 5000 });
    ok('Activos · «Dar de baja» pide la fecha (hoy, de entrada) y el motivo', (await q.locator('#ct-cie-activos input[name="fecha"]').inputValue()) === HOY);
    await q.fill('#ct-cie-activos textarea[name="motivo"]', 'Se vendió la camioneta');
    n0 = llamadas.length;
    await q.locator('#ct-cie-activos form button[type="submit"]').click(); await esperarLlamada(q, n0, 'fn_activo_baja'); await pintado(q);
    const baja = desde(n0).find(l => l.fn === 'fn_activo_baja');
    ok('Activos · la baja manda fn_activo_baja(p_id, p_fecha, p_motivo) y la fila lo dice, con lo que la base pide: el asiento de la baja va a mano', !!baja && JSON.stringify(baja.args) === JSON.stringify({ p_id: C9.activos[0].id, p_fecha: HOY, p_motivo: 'Se vendió la camioneta' }) &&
      new RegExp('Dado de baja el ' + fLarga(HOY) + ': Se vendió la camioneta').test(await texto(q, '#ct-cie-activos tr.ct-af')) && /Hasta que apuntes el asiento de la baja \(Dr 1590/.test(await texto(q, '#ct-cie-activos tr.ct-af')) && (await q.locator('#ct-cie-activos [data-af-baja]').count()) === 0, JSON.stringify(baja && baja.args));
    await foto(q, 'cierre-4-activos');
    // la reserva
    await cie(q, 'reserva');
    const prox = c9Proximo();
    ok('Reserva · sin el %: «Falta el % que fije el CPA», el mensaje de la base, ninguna cifra inventada (el % dice «falta», sin objetivo) y el próximo estimado con su fecha', /Falta el % que fije el CPA/.test(await texto(q, '.ct-res-titular')) && /guárdalo en Cierre → ajustes/.test(await texto(q, '#ct-cie-reserva')) &&
      /falta/.test(await texto(q, '#ct-cie-reserva .ct-kpi >> nth=1')) && /sin objetivo todavía/.test(await texto(q, '#ct-cie-reserva .ct-kpi >> nth=3')) && new RegExp('Próximo estimado: ' + fLarga(prox)).test(await texto(q, '.ct-res-prox')), await texto(q, '.ct-res-titular'));
    await q.locator('#ct-res-pct').click(); await q.waitForSelector('#ct-cie-reserva form input[name="pct"]', { timeout: 5000 });
    await q.fill('#ct-cie-reserva form input[name="pct"]', '25 %');
    n0 = llamadas.length;
    await q.locator('#ct-cie-reserva form button[type="submit"]').click(); await esperarLlamada(q, n0, 'fn_cierre_config'); await pintado(q);
    const cfgR = desde(n0).find(l => l.fn === 'fn_cierre_config');
    ok('Reserva · «Guardar el % del CPA» manda fn_cierre_config({p: {reserva_pct: 25}}) y la reserva dice «Transfiere $3,275.00 a la reserva (1030)» con su porqué', !!cfgR && JSON.stringify(cfgR.args) === '{"p":{"reserva_pct":25}}' && (await texto(q, '.ct-res-titular')) === 'Transfiere $3,275.00 a la reserva (1030)' && /el 25\.00 % son \$3,275\.00/.test(await texto(q, '#ct-cie-reserva')), JSON.stringify(cfgR && cfgR.args));
    const anio = Number(HOY.slice(0, 4));
    const marcar = async () => {
      await q.locator('#ct-res-marcar').click(); await q.waitForSelector('#ct-cie-reserva form input[name="numero"]', { timeout: 5000 });
      await q.fill('#ct-cie-reserva form input[name="numero"]', '2026-000005'); await q.fill('#ct-cie-reserva form input[name="nota"]', 'Q3 2026, IRS'); await q.fill('#ct-cie-reserva form input[name="anio"]', String(anio));
      await q.locator('#ct-cie-reserva form button[type="submit"]').click();
    };
    n0 = llamadas.length; l0 = lecturas.length;
    await marcar(); await esperarLlamada(q, n0, 'fn_reserva_estimado_marcar'); await pintado(q);
    const mar = desde(n0).find(l => l.fn === 'fn_reserva_estimado_marcar');
    ok('Reserva · «Marcar un pago como estimado» busca el asiento por su número y manda fn_reserva_estimado_marcar(p_asiento, p_nota, p_anio_fiscal); la reserva baja a «Transfiere $2,075.00» y el pago sale en la lista', lecturas.slice(l0).some(l => /^asientos\?.*numero=eq\.2026-000005/.test(l)) && !!mar &&
      JSON.stringify(mar.args) === JSON.stringify({ p_asiento: C9_ASIENTOS[0].id, p_nota: 'Q3 2026, IRS', p_anio_fiscal: anio }) && (await texto(q, '.ct-res-titular')) === 'Transfiere $2,075.00 a la reserva (1030)' && (await q.locator('#ct-cie-estimados .ct-res-est').count()) === 1, JSON.stringify(mar && mar.args));
    n0 = llamadas.length;
    await marcar(); await esperarLlamada(q, n0, 'fn_reserva_estimado_marcar'); await q.waitForTimeout(200);
    ok('Reserva · marcar dos veces el mismo pago: la base dice que no (MX008) y la pantalla lo enseña en la forma, sin repintar', /El asiento 2026-000005 ya está marcado como estimado pagado/.test(await texto(q, '#ct-cie-reserva .ct-error')) && C9.estimados.length === 1);
    await q.locator('#ct-cie-estimados [data-res-anular]').click(); await q.waitForSelector('#ct-cie-estimados form textarea[name="motivo"]', { timeout: 5000 });
    await q.fill('#ct-cie-estimados form textarea[name="motivo"]', 'Era el pago del 1120-S, no un estimado');
    n0 = llamadas.length;
    await q.locator('#ct-cie-estimados form button[type="submit"]').click(); await esperarLlamada(q, n0, 'fn_reserva_estimado_anular'); await pintado(q);
    const anu = desde(n0).find(l => l.fn === 'fn_reserva_estimado_anular');
    ok('Reserva · «Anular» manda fn_reserva_estimado_anular(p_id, p_motivo): el estimado queda en «Anulados» y la reserva vuelve a «Transfiere $3,275.00»', !!anu && JSON.stringify(anu.args) === JSON.stringify({ p_id: C9.estimados[0].id, p_motivo: 'Era el pago del 1120-S, no un estimado' }) &&
      (await texto(q, '.ct-res-titular')) === 'Transfiere $3,275.00 a la reserva (1030)' && (await q.locator('#ct-cie-estimados > .ct-cie-lista .ct-res-est').count()) === 0 && (await q.locator('#ct-cie-estimados .ct-cie-verdes .ct-res-est.anulado').count()) === 1);
    await foto(q, 'cierre-5-reserva');
    // el DR-15
    await cie(q, 'dr15');
    const dr = await q.locator('#ct-cie-dr15 tbody tr').evaluateAll(trs => trs.map(t => t.dataset.periodo));
    ok('DR-15 · una fila por mes ya empezado (el más reciente arriba): el use tax con su base y lo de 2300, y las ventas gravables y el sales tax cobrado como «aún no se sabe», con la nota en llano', JSON.stringify(dr) === JSON.stringify(C9_PER.filter(p => p.tipo === 'mes' && p.desde <= HOY).map(p => p.periodo).reverse()) &&
      /\$840\.00\s*2 compras/.test(await texto(q, '#ct-cie-dr15 tr[data-periodo="2026-10"]')) && (await q.locator('#ct-cie-dr15 tr[data-periodo="2026-10"] .ct-cie-nose').count()) === 2 && /llegan con f10/.test(await texto(q, '#ct-cie-dr15')) && /no es un cero/.test(await texto(q, '#ct-cie-dr15')), JSON.stringify(dr));
    await cx.close();

    // ---- el teléfono (390), el iPad (820) y la computadora (1280): cada apartado sin desplazamiento lateral ----
    for (const w of [390, 820, 1280]) {
      ({ cx, q } = await abrirCtx(w, true));
      const mal = []; let tabla = null;
      for (const s of ['cierre', 'activos', 'reserva', 'dr15', 'historial', 'ajustes']) {
        await cie(q, s, s === 'cierre' ? '2026-10' : null); await q.waitForTimeout(150);
        const m = await q.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: window.innerWidth, rojo: !!document.querySelector('#conta-raiz .ct-rojo'), thead: (() => { const t = document.querySelector('.ct-cie-tabla thead'); return t ? getComputedStyle(t).display : null; })() }));
        if (s === 'dr15') tabla = m.thead;
        if (m.sw > m.iw + 1 || m.rojo) mal.push(`${s}: ${m.sw} > ${m.iw}${m.rojo ? ' (rojo)' : ''}`);
        await foto(q, `cierre-${w}-${s}`);
      }
      // la apertura cerrada y exportada, con su descarga abierta; y la confirmación abierta (octubre, con lo que detiene apagado de mentira)
      await cie(q, 'cierre', '2026-09-APERTURA');
      await q.locator('[data-cie-descargar="2026-09-APERTURA"]').click(); await q.waitForSelector('.ct-cie-archivo[href]', { timeout: 5000 }).catch(() => {});
      const mc = await q.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: window.innerWidth }));
      if (mc.sw > mc.iw + 1) mal.push(`cerrado: ${mc.sw} > ${mc.iw}`);
      await foto(q, `cierre-${w}-cerrado`);
      // (las siete columnas del DR-15 y de los activos no caben en el iPad: se apilan hasta 1023 px, de tres en tres)
      ok(`Cierre · ${w} px: los seis apartados y el período cerrado con su descarga, sin desplazamiento lateral ni rojos${w < 1024 ? ' (y la tabla del DR-15 apilada: sin cabecera)' : ' (la tabla del DR-15 con su cabecera)'}`, !mal.length && (w < 1024 ? tabla === 'none' : tabla !== 'none' && tabla !== null), mal.join(' | ') || tabla);
      if (w === 390) {
        const tv = await q.evaluate(() => { const t = document.querySelector('.ct-tabs'), a = t.querySelector('.ct-tab[aria-current="page"]'), T = t.getBoundingClientRect(), A = a.getBoundingClientRect(); return { pag: a.dataset.pag, izq: Math.round(A.left - T.left), der: Math.round(T.right - A.right) }; });
        ok('Teléfono · la pestaña «Cierre» se ve entera dentro de la tira de pestañas', tv.pag === 'cierre' && tv.izq >= 14 && tv.der >= 14, JSON.stringify(tv));
        Object.assign(C9.rojos, { banco40: false, conc50: false, archivos111: false });
        await cie(q, 'cierre', '2026-10');
        await q.locator('#ct-cie-cerrar').click(); await q.waitForSelector('.ct-cie-confirma', { timeout: 5000 });
        await q.fill('.ct-cie-confirma input[name="confirmo"]', 'CERRAR OCTUBRE 2026');
        const mf = await q.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: window.innerWidth, b: Math.round(document.querySelector('#ct-cie-confirmar').getBoundingClientRect().right) }));
        ok('Teléfono · la confirmación de «Cerrar octubre 2026» cabe en 390 px (la frase, el campo y el botón rojo)', mf.sw <= mf.iw + 1 && mf.b <= mf.iw, JSON.stringify(mf));
        await foto(q, 'cierre-390-confirmacion');
        Object.assign(C9.rojos, { banco40: true, conc50: true, archivos111: true });
      }
      await cx.close();
    }

    // ---- 1280 px otra vez: MX010, la huella que no coincide y «Volver a exportar», el historial y los ajustes ----
    ({ cx, q } = await abrirCtx(1280, true));
    Object.assign(C9.rojos, { banco40: false, conc50: false, archivos111: false });
    await cie(q, 'cierre', '2026-10');
    ok('Cierre · octubre sin nada en rojo: «Cerrar octubre 2026» encendido', !(await q.locator('#ct-cie-cerrar').isDisabled()) && (await q.locator('#ct-cie-rev .ct-cie-item.detiene').count()) === 0);
    const cerrarOct = async () => {
      await q.locator('#ct-cie-cerrar').click(); await q.waitForSelector('.ct-cie-confirma', { timeout: 5000 });
      await q.fill('.ct-cie-confirma input[name="confirmo"]', 'CERRAR OCTUBRE 2026'); await q.locator('#ct-cie-confirmar').click();
    };
    C9.mx010 = true; n0 = llamadas.length;
    await cerrarOct(); await esperarLlamada(q, n0, 'fn_cierre_cerrar'); await q.waitForSelector('#ct-cie-error', { timeout: 8000 }).catch(() => {}); await pintado(q);
    const e10 = await texto(q, '#ct-cie-error');
    ok('Cierre · MX010 (la base, al cerrar con el libro quieto, encontró algo nuevo): «No se cerró», la frase de la base, la lista en llano con «Qué hacer», lo que pasó en palabras y sin la consulta SQL de la pista (es para el SQL Editor); octubre sigue abierto y la revisión ya lo trae en rojo',
      /No se cerró\. No se cierra octubre de 2026: 1 cosa\(s\) lo detienen\./.test(e10) && /40\) banco: todo lo del mes casado o clasificado: 7 movimiento\(s\)/.test(e10) && /Qué hacer: Abre la Bandeja/.test(e10) && /entró o cambió después de la revisión/.test(e10) && !/La base dice|fn_cierre_revisar|select \*/.test(e10) &&
      C9.estado['2026-10'] === 'abierto' && (await q.locator('#ct-cie-rev .ct-cie-item.detiene[data-orden="40"]').count()) === 1 && await q.locator('#ct-cie-cerrar').isDisabled() && desde(n0).filter(l => l.fn === 'fn_cierre_revisar').length >= 1, e10);
    await foto(q, 'cierre-6-mx010');
    C9.rojos.banco40 = false; C9.hashMal = true;
    await q.locator('#ct-cie-revisar').click(); await q.waitForTimeout(200); await pintado(q);
    n0 = llamadas.length;
    await cerrarOct(); await esperarLlamada(q, n0, 'fn_cierre_cerrar'); await q.waitForSelector('.ct-cie-export-err', { timeout: 10000 }).catch(() => {}); await pintado(q);
    ok('Cierre · la huella que no coincide: octubre se cierra, pero si el mayor que baja no da la huella guardada al cerrar, no sube nada ni registra, lo dice en llano y queda «Volver a exportar»', C9.estado['2026-10'] === 'cerrado' &&
      !desde(n0).some(l => l.fn === 'storage:subir-cierre' || l.fn === 'fn_cierre_export') && /no da la huella que la base guardó al cerrar/.test(await texto(q, '.ct-cie-export-err')) && (await q.locator('[data-cie-exportar="2026-10"]').count()) === 1, await texto(q, '#ct-cie-export'));
    C9.hashMal = false; C9.cierres['2026-10'].hash_mayor = c9Huella('2026-10').hash;
    n0 = llamadas.length;
    await q.locator('[data-cie-exportar="2026-10"]').click(); await esperarLlamada(q, n0, 'fn_cierre_export'); await q.waitForTimeout(200); await pintado(q);
    const subOct = desde(n0).filter(l => l.fn === 'storage:subir-cierre'), carpOct = subOct.length ? subOct[0].args.ruta.replace(/[^/]+$/, '') : '';
    const mOct = C9.objetos.get(carpOct + 'mayor-2026-10.csv'), rOct = mOct ? receta(mOct.texto) : { lin: [], texto: '', col: () => -1 };
    ok('Cierre · «Volver a exportar» (octubre cerrado sin export): sube sus 4 archivos a su carpeta y los registra; su CSV lleva la línea de la IA con su sello y da la huella del cierre', subOct.length === 4 && /^2026-10\/\d{4}-\d{2}-\d{2}_\d{6}\/$/.test(carpOct) && desde(n0).some(l => l.fn === 'fn_cierre_export' && l.args.p_periodo === '2026-10') &&
      rOct.lin.length === 9 && rOct.lin.some(r => r[rOct.col('sello_ia')] === 'IA (aprobada por Edgar)' && r[rOct.col('procedencia')] === 'IA aprobada') && sha(Buffer.from(rOct.texto, 'utf8')) === C9.cierres['2026-10'].hash_mayor && /Exportado el/.test(await texto(q, '#ct-cie-export')), `${subOct.length} · ${rOct.lin.length}`);
    await cie(q, 'historial');
    const hist = await q.locator('.ct-hist').evaluateAll(xs => xs.map(x => x.dataset.periodo));
    ok('Historial · los dos cierres, el más reciente arriba: período, quién y cuándo, la huella corta, exportado y «Descargar» (v_cierres)', JSON.stringify(hist) === '["2026-10","2026-09-APERTURA"]' && /Cerrado el .* por Edgar Prueba/.test(await texto(q, '.ct-hist >> nth=0')) &&
      (await texto(q, '.ct-hist >> nth=0')).includes(C9.cierres['2026-10'].hash_mayor.slice(0, 12)) && (await q.locator('.ct-hist [data-cie-descargar]').count()) === 2 && (await q.locator('.ct-hist .ct-pill.ok', { hasText: 'exportado' }).count()) === 2, JSON.stringify(hist));
    n0 = llamadas.length;
    await q.locator('.ct-hist[data-periodo="2026-10"] [data-cie-descargar]').click(); await q.waitForSelector('.ct-hist[data-periodo="2026-10"] .ct-cie-archivo[href]', { timeout: 5000 });
    ok('Historial · «Descargar» de un cierre firma sus archivos ahí mismo', desde(n0).some(l => l.fn === 'storage:firmar-cierres' && l.args.paths.every(r => r.startsWith('2026-10/'))) && (await q.locator('.ct-hist[data-periodo="2026-10"] .ct-cie-archivo').count()) === 4);
    await cie(q, 'ajustes');
    n0 = llamadas.length;
    await q.locator('#ct-cie-ajustes-form button[type="submit"]').click(); await q.waitForTimeout(200);
    ok('Ajustes · sin cambios no se manda nada («No cambiaste nada»)', /No cambiaste nada/.test(await texto(q, '#ct-cie-ajustes .ct-error')) && !desde(n0).some(l => l.fn === 'fn_cierre_config'));
    await q.locator('#ct-cie-ajustes input[name="aviso_push"]').uncheck();
    await q.locator('#ct-cie-ajustes-form button[type="submit"]').click(); await esperarLlamada(q, n0, 'fn_cierre_config'); await pintado(q);
    const aj = desde(n0).find(l => l.fn === 'fn_cierre_config');
    ok('Ajustes · apagar los avisos al teléfono manda solo lo que cambió (fn_cierre_config({p: {aviso_push: false}})) y la cabecera lo dice', !!aj && JSON.stringify(aj.args) === '{"p":{"aviso_push":false}}' && /avisos al teléfono no/.test(await texto(q, '.ct-pag-sub')) && /reserva 25 %/.test(await texto(q, '.ct-pag-sub')), JSON.stringify(aj && aj.args));
    await cx.close();
    conCodigo(false); estado.c9 = false;
  }

  // ---- La mano de obra y el costo por obra (c10, fase 9): «Qué atender», la tarjeta «Mano de obra · persona» de la Bandeja
  // (el período en un toque que recalcula, otras fechas, el total que es el pago, la tarifa, sin horas, «Así es» con la huella,
  // la huella cambiada que recalcula, el motivo que pide el banco, la cuenta de lo sin obra, la propuesta de la IA rechazada,
  // «No es mano de obra», el alta desde un pago normal), «Costo por obra» (lo que falta por configurar, la lista, una obra con
  // lo real y lo estándar separados, la cobertura, los CO, la fase, el vacío del cost code, bajar a los asientos, el margen que
  // no cuadra), los repartos con «Deshacer», las personas, sin el código, sin c10, y el teléfono, el iPad y la computadora ----
  {
    estado.c10 = true; jReset();
    const conCodigo = si => { estado.mfaFactores = si ? [{ id: 'f-1', friendly_name: 'Teléfono de Edgar', factor_type: 'totp', status: 'verified' }] : []; estado.sesionAal = si ? 'aal2' : undefined; };
    const abrirCtx = async (w, codigo) => {
      conCodigo(codigo);
      const cx = await b.newContext({ viewport: { width: w, height: w < 700 ? 844 : 1000 }, deviceScaleFactor: w < 1024 ? 2 : 1, isMobile: w < 1024, hasTouch: w < 1024, serviceWorkers: 'block' });
      await simular(cx, 'dueno');
      const q = await cx.newPage(); q.on('pageerror', e => errs.push(`c10 ${w}: ` + String(e).slice(0, 160)));
      await q.goto('http://localhost:8873/index.html'); await q.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await q.waitForTimeout(800);
      await q.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
      await q.locator('#btn-conta').evaluate(x => x.click()); await q.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 }); await pintado(q);
      return { cx, q };
    };
    const ve = async (q, k, op) => { await q.evaluate(([k, o]) => window.MXP_CONTA.ir(k, o || {}), [k, op || null]); await pintado(q); };
    const tarjeta = q => id => q.locator(`.ct-mov[data-id="${id}"]`);
    const ultima = (n0, fn) => desde(n0).filter(l => l.fn === fn).pop();
    let { cx, q } = await abrirCtx(1280, true);
    const card = tarjeta(q);
    // ---- «Qué atender» ----
    let atn = await q.locator('#ct-atender .ct-atn').allTextContents();
    ok('Mano de obra · «Qué atender» dice cuántos pagos de mano de obra esperan su reparto (3 · $2,060.00) con su botón «Bandeja»', atn.some(t => /^3 pagos de mano de obra esperan su reparto por horas \(\$2,060\.00\)/.test(t)) &&
      (await q.locator('#ct-atender .ct-atn', { hasText: 'pagos de mano de obra' }).locator('button[data-ir="bandeja"]').count()) === 1, atn.join(' | '));
    await foto(q, 'c10-0-resumen');
    // ---- la Bandeja: la tarjeta de Zzana (el lunes 2-nov paga la semana anterior: 37 h en 6 obras) ----
    let n0 = llamadas.length;
    await ve(q, 'bandeja');
    ok('Bandeja · la franja: «3 pagos de mano de obra esperan su reparto por horas · $2,060.00» con «Ver solo esos»', /3 pagos de mano de obra esperan su reparto por horas · \$2,060\.00/.test(await texto(q, '#ct-jr-franja')) && (await q.locator('#ct-jr-ver').count()) === 1, await texto(q, '#ct-jr-franja'));
    let cA = await fila(q, J_MOV.ana);
    const tfoot = async c => (await c.locator('.ct-jr-tabla tfoot').innerText()).replace(/\s+/g, ' ');
    ok('Bandeja · el Zelle de Zzana sale como «Mano de obra · Zzana C10 PRUEBA»: la tabla con 7 líneas (6 obras; la A con y sin CO), sin «Según la IA» ni las opciones de siempre',
      /Mano de obra · Zzana C10 PRUEBA/.test(await texto(q, `.ct-mov[data-id="${J_MOV.ana}"] .ct-f-motivo`)) && /Mano de obra · Zzana C10 PRUEBA/.test(await cA.locator('.ct-jr-cab h3').textContent()) &&
      (await cA.locator('.ct-jr-tabla tbody tr').count()) === 7 && (await cA.locator('.ct-jr-tabla tbody tr', { hasText: 'CO #1' }).count()) === 1 &&
      (await cA.locator('[data-op], [data-otra], [data-ia]').count()) === 0, await cA.locator('.ct-jr-tabla').textContent());
    ok('…el total cuadra con el pago: «Total · 6 obras · 37 h · $940.00» y «El total es el pago: $940.00»', /Total · 6 obras 37 h \$940\.00/.test(await tfoot(cA)) && /El total es el pago: \$940\.00/.test(await cA.locator('.ct-jr-cuadra').textContent()), await tfoot(cA));
    ok('…el período: «Semana anterior» marcada (26 oct – 1 nov) y el texto de la base («del 26 de octubre al 1 de noviembre de 2026»)', (await cA.locator('[data-jr-per="anterior"]').getAttribute('aria-pressed')) === 'true' && /26 oct – 1 nov/.test(await cA.locator('[data-jr-per="anterior"]').textContent()) &&
      /del 26 de octubre al 1 de noviembre de 2026/.test(await cA.locator('.ct-jr-que').textContent()) && /2 nov – 8 nov/.test(await cA.locator('[data-jr-per="esta"]').textContent()));
    ok('…«Sale a $25.41 la hora (su tarifa: $25.00)», sin ámbar (no se aleja), y el aviso de la base en llano (la obra F terminada)', /Sale a \$25\.41 la hora \(su tarifa: \$25\.00\)/.test(await cA.locator('.ct-jr-tarifa').textContent()) && !(await cA.locator('.ct-jr-tarifa.lejos').count()) &&
      /C10 PRUEBA Obra F \(terminada\)\. Su parte va a esa obra igual/.test(await cA.locator('[data-aviso="obra_terminada"]').textContent()) && (await cA.locator('.ct-jr-tabla tbody tr', { hasText: 'Obra F' }).locator('.ct-pill', { hasText: 'terminada' }).count()) === 1);
    ok('v2 · el aviso «Horas de otro mes» sale con el texto de la base y como información (sin ámbar): «37 h de este pago ($940.00) se trabajaron en octubre de 2026 y el asiento entra el 2-nov-2026…»',
      /^37 h de este pago \(\$940\.00\) se trabajaron en octubre de 2026 y el asiento entra el 2-nov-2026: su costo queda en noviembre de 2026/.test(await cA.locator('[data-aviso="otro_mes"]').textContent()) &&
      (await cA.locator('[data-aviso="otro_mes"].ct-jr-info').count()) === 1 && (await cA.locator('[data-aviso="otro_mes"].warn').count()) === 0, await cA.locator('.ct-jr-avisos').textContent());
    ok('…y la Bandeja no pidió la propuesta (la tarjeta sale de la lista de pagos reconocidos, con su huella)', !desde(n0).some(l => l.fn === 'fn_jornal_propuesta') && lecturas.some(l => /^v_jornal_pendientes\?select=\*/.test(l)));
    await foto(q, 'c10-1-bandeja-tarjeta');
    // cambiar el período recalcula: esta semana (sin horas), otras fechas (23.25 h en 4 líneas) y otra vez la semana anterior
    n0 = llamadas.length;
    await cA.locator('[data-jr-per="esta"]').click(); await esperarLlamada(q, n0, 'fn_jornal_propuesta'); await pintado(q);
    cA = card(J_MOV.ana);
    let pr = ultima(n0, 'fn_jornal_propuesta');
    ok('Período · «Esta semana» pide fn_jornal_propuesta(movimiento, 2-nov, 8-nov) y la tarjeta dice que no hay horas: sin tabla, «Así es» apagado y la salida de «No es mano de obra»',
      !!pr && pr.args.p_movimiento === J_MOV.ana && pr.args.p_desde === '2026-11-02' && pr.args.p_hasta === '2026-11-08' && JSON.stringify(pr.args.p_opciones) === '{}' &&
      (await cA.locator('[data-jr-per="esta"]').getAttribute('aria-pressed')) === 'true' && /Sin horas reportadas del 2 al 8 de noviembre de 2026/.test(await cA.locator('.ct-jr-vacio').textContent()) &&
      (await cA.locator('.ct-jr-tabla').count()) === 0 && await cA.locator('[data-jr-asi]').isDisabled() && (await cA.locator('[data-jr-no]').count()) === 1 && (await cA.locator('[data-aviso="sin_horas"]').count()) === 1, JSON.stringify(pr && pr.args));
    await foto(q, 'c10-2-sin-horas');
    n0 = llamadas.length;
    await cA.locator('[data-jr-per="otras"]').click();
    await cA.locator('[data-jr-fechas] input[name="desde"]').fill('2026-10-26'); await cA.locator('[data-jr-fechas] input[name="hasta"]').fill('2026-10-28');
    await cA.locator('[data-jr-fechas] button[type="submit"]').click(); await esperarLlamada(q, n0, 'fn_jornal_propuesta'); await pintado(q);
    cA = card(J_MOV.ana); pr = ultima(n0, 'fn_jornal_propuesta');
    ok('Período · «Otras fechas» (26 al 28-oct) manda esas fechas y repinta: 4 líneas, 23.25 h, el total sigue siendo el pago y «Otras fechas» queda marcado', !!pr && pr.args.p_desde === '2026-10-26' && pr.args.p_hasta === '2026-10-28' &&
      (await cA.locator('.ct-jr-tabla tbody tr').count()) === 4 && /23\.25 h \$940\.00/.test(await tfoot(cA)) && (await cA.locator('[data-jr-per="otras"]').getAttribute('aria-pressed')) === 'true', await tfoot(cA));
    n0 = llamadas.length;
    await cA.locator('[data-jr-per="anterior"]').click(); await esperarLlamada(q, n0, 'fn_jornal_propuesta'); await pintado(q);
    cA = card(J_MOV.ana);
    const vistoA = jCalc(J_MOV.ana, '2026-10-26', '2026-11-01').visto;
    ok('Período · otra vez «Semana anterior»: las 7 líneas y los 37 h', (await cA.locator('.ct-jr-tabla tbody tr').count()) === 7 && /37 h \$940\.00/.test(await tfoot(cA)));
    ok('v2 · la propuesta dice cuántos reportes aprobará «Así es» (8) y lo que la IA tenía para el pago (proponía 5100 → C10 PRUEBA Obra B): se cierra sola al aceptar',
      /Al aceptar quedan aprobados 8 reportes de horas/.test(await cA.locator('.ct-jr-aprueba').textContent()) && /5100 → C10 PRUEBA Obra B.*se cierra sola/.test(await cA.locator('.ct-jr-iaprop').textContent()), await cA.locator('.ct-jr-iaprop').textContent());
    // «Así es» con la huella cambiada (alguien reportó 3 h más entre medias): nada se hace, se recalcula y se enseña otra vez
    J.mx011 = true; n0 = llamadas.length;
    await cA.locator('[data-jr-asi]').click(); await esperarLlamada(q, n0, 'fn_jornal_aplicar'); await q.waitForTimeout(200); await pintado(q);
    cA = card(J_MOV.ana);
    const ap1 = ultima(n0, 'fn_jornal_aplicar');
    ok('«Así es» manda fn_jornal_aplicar con el movimiento, las fechas y la HUELLA que vio (p_visto), sin opciones', !!ap1 && ap1.args.p_movimiento === J_MOV.ana && ap1.args.p_desde === '2026-10-26' && ap1.args.p_hasta === '2026-11-01' && ap1.args.p_visto === vistoA && JSON.stringify(ap1.args.p_opciones) === '{}', JSON.stringify(ap1 && ap1.args));
    ok('Huella cambiada (MX011) · no se repartió nada: la pantalla vuelve a pedir la propuesta de esas fechas, lo dice («Las horas cambiaron…») y enseña lo de ahora (la B con 4.5 h, 40 h)', J.repartos.length === 0 &&
      desde(n0).filter(l => l.fn === 'fn_jornal_propuesta').length === 1 && /Las horas cambiaron entre que miraste y que tocaste/.test(await cA.locator('.ct-jr-nota').textContent()) &&
      /4\.5 h/.test(await cA.locator('.ct-jr-tabla tbody tr', { hasText: 'Obra B' }).textContent()) && /40 h \$940\.00/.test(await tfoot(cA)), await tfoot(cA));
    await foto(q, 'c10-3-huella-cambiada');
    // el banco frena («…dilo en el motivo»): sale el campo, y el segundo «Así es» manda el motivo con la MISMA huella
    J.pideMotivo = true; n0 = llamadas.length;
    await cA.locator('[data-jr-asi]').click(); await esperarLlamada(q, n0, 'fn_jornal_aplicar'); await q.waitForTimeout(200); await pintado(q);
    const vistoA2 = ultima(n0, 'fn_jornal_aplicar').args.p_visto;
    ok('El banco pide el motivo (MX008 «…dilo en el motivo»): su frase, el campo del motivo a la vista y nada repartido', J.repartos.length === 0 && /dilo en el motivo/.test(await cA.locator('.ct-jr-res').textContent()) && await cA.locator('.ct-jr-motivo').isVisible() && vistoA2 !== vistoA);
    await cA.locator('.ct-jr-motivo textarea').fill('Es su semana: el cheque 1234 es otra cosa');
    n0 = llamadas.length;
    await cA.locator('[data-jr-asi]').click(); await esperarLlamada(q, n0, 'fn_jornal_aplicar'); await q.waitForTimeout(250); await pintado(q);
    const ap3 = ultima(n0, 'fn_jornal_aplicar');
    ok('…con el motivo: la misma huella y p_opciones.motivo; repartido (1 reparto de $940.00 en 7 líneas), la tarjeta se va y la franja dice 2', !!ap3 && ap3.args.p_visto === vistoA2 && ap3.args.p_opciones.motivo === 'Es su semana: el cheque 1234 es otra cosa' &&
      J.repartos.length === 1 && J.repartos[0].monto === 940 && J.repartos[0].lineas.length === 7 && (await card(J_MOV.ana).count()) === 0 && /2 pagos de mano de obra esperan/.test(await texto(q, '#ct-jr-franja')), JSON.stringify(ap3 && ap3.args.p_opciones));
    J.pideMotivo = false;
    const cad = ultima(n0, 'contador:caducar');
    ok('v2 · lo de la IA que el pago tenía abierto (una aprobada cuyo asiento ya no vive) se cierra tras el reparto: «caducar» por la función «contador», con su motivo; nada queda abierto',
      !!cad && cad.args.propuesta === J_IA2 && /mano de obra/i.test(cad.args.motivo) && J.ia[1].estado === 'caducada' && !desde(n0).some(l => l.fn === 'contador:rechazar') && (await q.locator('#ct-jr-ia').count()) === 0, JSON.stringify(cad && cad.args));
    // Zzbeto: 2 h sin obra y sin cuenta para ellas → se pide UNA vez; luego «Así es» y la propuesta de la IA se rechaza
    let cB = await fila(q, J_MOV.beto);
    ok('Lo sin obra · la tarjeta de Zzbeto (viernes 6-nov: «Esta semana») enseña «Sin obra · 2 h · $50.00 · falta decir a qué cuenta va», pide la cuenta y no deja «Así es»; el total sigue siendo $600.00',
      (await cB.locator('[data-jr-per="esta"]').getAttribute('aria-pressed')) === 'true' && /Sin obra\s*falta decir a qué cuenta va\s*2 h\s*\$50\.00/.test((await cB.locator('.ct-jr-sinobra').textContent()).replace(/\s+/g, ' ').replace(/ (?=\d)/g, ' ')) &&
      (await cB.locator('[data-jr-cuenta] select option[value="7900"]').count()) === 1 && (await cB.locator('[data-jr-cuenta] select option[value="5010"]').count()) === 0 && (await cB.locator('[data-jr-cuenta] select option[value="5200"]').count()) === 0 &&
      await cB.locator('[data-jr-asi]').isDisabled() && /24 h \$600\.00/.test(await tfoot(cB)), await cB.locator('.ct-jr-sinobra').textContent());
    await foto(q, 'c10-4-sin-obra');
    n0 = llamadas.length;
    await cB.locator('[data-jr-cuenta] select').selectOption('7900'); await cB.locator('[data-jr-cuenta] button[type="submit"]').click();
    await esperarLlamada(q, n0, 'fn_jornal_propuesta'); await pintado(q);
    cB = card(J_MOV.beto);
    const cfg1 = ultima(n0, 'fn_jornal_config');
    ok('…«Guardar la cuenta» manda fn_jornal_config({p: {cuenta_sin_obra: "7900"}}), recalcula y ya deja «Así es» (lo sin obra va a 7900)', !!cfg1 && JSON.stringify(cfg1.args) === '{"p":{"cuenta_sin_obra":"7900"}}' && J.config.cuenta_sin_obra === '7900' &&
      !(await cB.locator('[data-jr-asi]').isDisabled()) && /va a 7900/.test(await cB.locator('.ct-jr-sinobra').textContent()) && (await cB.locator('[data-jr-cuenta]').count()) === 0, JSON.stringify(cfg1 && cfg1.args));
    n0 = llamadas.length; J.iaFalla = 1;
    await cB.locator('[data-jr-asi]').click(); await esperarLlamada(q, n0, 'contador:rechazar'); await q.waitForTimeout(250); await pintado(q);
    await q.waitForSelector('#ct-jr-ia', { timeout: 5000 });
    const rej = ultima(n0, 'contador:rechazar'), tIA = await texto(q, '#toast');
    ok('La IA (c8) tenía una propuesta para ese pago: tras repartirlo, la pantalla la rechaza por la función «contador» (con su id y el motivo)', J.repartos.length === 2 && !!rej && rej.args.propuesta === J_IA && /mano de obra/i.test(rej.args.motivo) && (await card(J_MOV.beto).count()) === 0, JSON.stringify(rej && rej.args));
    ok('v2 · si la función no contesta, NO SE PIERDE: el aviso lo dice en llano («quedó abierta… se vuelve a intentar solo cada vez que abras la Bandeja»), en rojo, y no se reintenta en esa misma pintada',
      /la propuesta de la IA para este pago quedó abierta \(la IA contable no contestó\)\. Se vuelve a intentar solo cada vez que abras la Bandeja/.test(tIA) && /error/.test(await q.locator('#toast').getAttribute('class')) &&
      desde(n0).filter(l => l.fn === 'contador:rechazar').length === 1 && J.ia[0].estado === 'pendiente', tIA);
    ok('v2 · …la franja lo dice («1 propuesta de la IA sigue abierta en pagos ya repartidos por horas (proponía 5200 → C10 PRUEBA Obra A): la IA contable no contestó…», puede frenar el cierre) con «Reintentar ahora»',
      /1 propuesta de la IA sigue abierta en pagos ya repartidos por horas \(proponía 5200 → C10 PRUEBA Obra A\): la IA contable no contestó al cerrarlas/.test(await texto(q, '#ct-jr-ia')) && /frenar el cierre del mes/.test(await texto(q, '#ct-jr-ia')) &&
      (await q.locator('#ct-jr-ia-reintentar').count()) === 1 && !/fn_|v_jornal|MX0/.test(await texto(q, '#ct-jr-ia')), await texto(q, '#ct-jr-ia'));
    n0 = llamadas.length;
    await q.locator('#ct-jr-ia-reintentar').click(); await esperarLlamada(q, n0, 'contador:rechazar');
    await q.waitForFunction(() => !document.getElementById('ct-jr-ia'), null, { timeout: 5000 }).catch(() => {});
    ok('v2 · «Reintentar ahora» la rechaza otra vez por la función y, al cerrarse, la franja ya no la nombra y el aviso dice «cerrada»', J.ia[0].estado === 'rechazada' && (await q.locator('#ct-jr-ia').count()) === 0 && /cerrada/.test(await texto(q, '#toast')), await texto(q, '#toast'));
    // lo que el control de la base enseña como abierto (el 80) va a «Qué atender» con su botón a la Bandeja; al abrirla, se cierra sola
    J.ia[0].estado = 'pendiente';
    await ve(q, 'resumen');
    atn = await q.locator('#ct-atender .ct-atn').allTextContents();
    ok('v2 · «Qué atender»: el aviso 80 del jornal (una propuesta de la IA abierta en un pago repartido) con el detalle de la base y su botón «Bandeja»',
      atn.some(t => /^Mano de obra: ninguna propuesta de la IA abierta en un pago ya repartido\.el pago del 2026-11-06 a Zzbeto C10 PRUEBA \(\$600\.00\): su propuesta de la IA sigue pendiente/.test(t)) &&
      (await q.locator('#ct-atender .ct-atn', { hasText: 'ninguna propuesta de la IA' }).locator('button[data-ir="bandeja"]').count()) === 1, atn.join(' | '));
    n0 = llamadas.length;
    await ve(q, 'bandeja'); await esperarLlamada(q, n0, 'contador:rechazar');
    await q.waitForFunction(() => !document.getElementById('ct-jr-ia'), null, { timeout: 5000 }).catch(() => {});
    ok('v2 · al abrir la Bandeja, lo que la base sigue dando por abierto (fn_jornal_ia) se cierra solo: «rechazar» con su motivo, sin tocar nada', desde(n0).some(l => l.fn === 'fn_jornal_ia') &&
      (ultima(n0, 'contador:rechazar') || { args: {} }).args.propuesta === J_IA && J.ia[0].estado === 'rechazada' && (await q.locator('#ct-jr-ia').count()) === 0);
    J.ia[0].estado = 'pendiente'; J.iaFalla = 1; n0 = llamadas.length;
    await ve(q, 'bandeja'); await esperarLlamada(q, n0, 'contador:rechazar');
    await q.waitForFunction(() => /no contestó/.test((document.getElementById('ct-jr-ia') || {}).textContent || ''), null, { timeout: 5000 }).catch(() => {});
    ok('v2 · …y si la función sigue sin contestar, la franja lo vuelve a decir y nada se pierde (la próxima vez se reintenta)', J.ia[0].estado === 'pendiente' && /sigue abierta.*no contestó/.test(await texto(q, '#ct-jr-ia')));
    await foto(q, 'c10-4b-ia-abierta');
    J.iaFalla = 0; n0 = llamadas.length;
    await ve(q, 'bandeja'); await esperarLlamada(q, n0, 'contador:rechazar');
    await q.waitForFunction(() => !document.getElementById('ct-jr-ia'), null, { timeout: 5000 }).catch(() => {});
    ok('v2 · …y en cuanto contesta, la siguiente vez que se abre la Bandeja queda cerrada', J.ia[0].estado === 'rechazada' && (await q.locator('#ct-jr-ia').count()) === 0);
    // horas tardías: una hora del 31-oct reportada después de repartir esa semana; el pago siguiente de Zzana la ofrece
    J.horas.push({ id: -1010000098, u: J_PER.ana, fecha: '2026-10-31', p: 'c10-prueba-h', co: null, fase: 'rough', horas: 2 });
    await ve(q, 'bandeja');
    let cT = await fila(q, J_MOV.ana2);
    const btT = cT.locator('[data-jr-tardias]');
    ok('v2 · horas tardías: el pago del 9-nov de Zzana trae el aviso de la base (2 h del 31-oct en la obra H, de una semana ya repartida) en ámbar, con «Repartir también esas horas (31 oct – 8 nov)»',
      /Zzana C10 PRUEBA tiene 2 h de una semana ya repartida que no están en ningún reparto.*2 h del 31-oct en C10 PRUEBA Obra H \(semana del pago del 2-nov\)/.test(await cT.locator('[data-aviso="horas_tardias"]').textContent()) &&
      (await cT.locator('[data-aviso="horas_tardias"].warn').count()) === 1 && (await btT.getAttribute('data-desde')) === '2026-10-31' && (await btT.getAttribute('data-hasta')) === '2026-11-08' && /31 oct – 8 nov/.test(await btT.textContent()));
    n0 = llamadas.length;
    await btT.click(); await esperarLlamada(q, n0, 'fn_jornal_propuesta'); await pintado(q);
    cT = card(J_MOV.ana2); pr = ultima(n0, 'fn_jornal_propuesta');
    ok('v2 · …tocarlo pide la propuesta con esas fechas (31-oct a 8-nov): la tarjeta enseña esas 2 h en la obra H por el pago entero, lo dice, y avisa que se pisa con el reparto de esa semana',
      !!pr && pr.args.p_desde === '2026-10-31' && pr.args.p_hasta === '2026-11-08' && (await cT.locator('.ct-jr-tabla tbody tr').count()) === 1 && /Obra H/.test(await cT.locator('.ct-jr-tabla tbody').textContent()) &&
      /2 h \$520\.00/.test(await tfoot(cT)) && /quedaron fuera de su semana/.test(await cT.locator('.ct-jr-nota').textContent()) && (await cT.locator('[data-aviso="se_pisa"]').count()) === 1 && (await cT.locator('[data-aviso="horas_tardias"]').count()) === 0,
      JSON.stringify(pr && pr.args));
    await foto(q, 'c10-4c-tardias');
    // el lunes 9-nov a Zzana: sin horas esa semana → «No es mano de obra» devuelve la tarjeta de siempre, y se puede volver
    let cN = await fila(q, J_MOV.ana2);
    await cN.locator('[data-jr-no]').click(); await q.waitForTimeout(150);
    cN = card(J_MOV.ana2);
    ok('«No es mano de obra» devuelve la tarjeta de siempre (sus opciones y «Otra cosa…»), sin llamar a la base, con el enlace para volver', (await cN.locator('[data-jr-bloque]').count()) === 0 && (await cN.locator('[data-otra]').count()) === 1 && (await cN.locator('[data-op]').count()) === 1 &&
      (await cN.locator('[data-jr-volver]').count()) === 1 && !/Mano de obra/.test(await texto(q, `.ct-mov[data-id="${J_MOV.ana2}"] .ct-f-motivo`)));
    await cN.locator('[data-jr-volver]').click(); await q.waitForTimeout(150);
    ok('…y «Sí es mano de obra» la trae otra vez', (await card(J_MOV.ana2).locator('[data-jr-bloque]').count()) === 1);
    // un Zelle normal a alguien sin dar de alta: «Repartir por sus horas» → elegirla de la cuadrilla → su tarjeta (con la tarifa en ámbar)
    let cC = await fila(q, J_MOV.carla);
    ok('Alta · el Zelle a Zzcarla (sin dar de alta) es un movimiento normal con el enlace discreto «Repartir por sus horas»', (await cC.locator('[data-jr-bloque]').count()) === 0 && (await cC.locator('[data-jr-alta]').count()) === 1 && (await cC.locator('[data-otra]').count()) === 1);
    await cC.locator('[data-jr-alta]').click(); await cC.locator('.ct-form select[name="usuario"]').waitFor({ timeout: 5000 });
    ok('…abre la cuadrilla (solo quien tiene horas y no está dado de alta): Zzcarla', JSON.stringify(await cC.locator('.ct-form select[name="usuario"] option').evaluateAll(os => os.map(o => o.value).filter(Boolean))) === JSON.stringify([J_PER.carla]));
    await foto(q, 'c10-5-alta');
    n0 = llamadas.length;
    await cC.locator('.ct-form select[name="usuario"]').selectOption(J_PER.carla); await cC.locator('.ct-form button[type="submit"]').click();
    await esperarLlamada(q, n0, 'fn_jornal_persona'); await q.waitForTimeout(200); await pintado(q);
    const alta = ultima(n0, 'fn_jornal_persona');
    cC = await fila(q, J_MOV.carla);
    ok('…manda fn_jornal_persona({p: {usuario_id, movimiento_id, activa: true}}) (la base saca el patrón del pago) y el pago sale ya como «Mano de obra · Zzcarla»', !!alta && alta.args.p.usuario_id === J_PER.carla && alta.args.p.movimiento_id === J_MOV.carla && alta.args.p.activa === true &&
      (await cC.locator('[data-jr-bloque]').count()) === 1 && /Mano de obra · Zzcarla C10 PRUEBA/.test(await cC.locator('.ct-jr-cab h3').textContent()), JSON.stringify(alta && alta.args));
    ok('v2 · el aviso del alta es la nota de la base sin las marcas del patrón («…reconocidos con «C10 PRUEBA ZZCARLA»»)', /Zzcarla C10 PRUEBA: 1 pago\(s\) pendientes reconocidos con «C10 PRUEBA ZZCARLA»/.test(await texto(q, '#toast')) && !/\\[mM]/.test(await texto(q, '#toast')), await texto(q, '#toast'));
    ok('Tarifa · a Zzcarla le sale a $25.00 la hora y su tarifa es $18.00: la línea va en ámbar y el aviso de la base lo dice', (await cC.locator('.ct-jr-tarifa.lejos').count()) === 1 && /Sale a \$25\.00 la hora \(su tarifa: \$18\.00\)/.test(await cC.locator('.ct-jr-tarifa').textContent()) &&
      (await cC.locator('[data-aviso="tarifa_lejos"]').count()) === 1 && !(await cC.locator('[data-jr-asi]').isDisabled()));
    await foto(q, 'c10-6-tarifa-lejos');
    // ---- Costo por obra ----
    n0 = llamadas.length; let l0 = lecturas.length;
    await ve(q, 'obras');
    ok('Costo por obra · se abre con su título, su pestaña y su subtítulo del lateral encendidos', (await q.locator('#titulo-vista').textContent()).trim() === 'Costo por obra' && (await q.locator('.ct-tab[data-pag="obras"][aria-current="page"]').count()) === 1 && (await q.locator('#lateral [data-lat="conta-obras"][aria-current="page"]').count()) === 1);
    ok('…lee el control del margen antes que las obras, las obras y la configuración', lecturas.slice(l0).some(l => /^v_margen_control\?/.test(l)) && lecturas.slice(l0).some(l => /^v_margen_obra\?/.test(l)) && lecturas.slice(l0).some(l => /^jornal_config\?/.test(l)));
    ok('Configurar · «Lo que falta por configurar»: el burden estándar (falta) con su frase, y la cuenta de lo sin obra ya en 7900', /Lo que falta por configurar/.test(await texto(q, '#ct-ob-config h2')) && (await q.locator('#ct-ob-config .ct-campo', { hasText: 'Burden' }).locator('.ct-pill', { hasText: 'falta' }).count()) === 1 &&
      /si no aplica, pon 0/i.test(await texto(q, '#ct-ob-config')) && (await q.locator('#ct-ob-config select[name="cuenta_sin_obra"]').inputValue()) === '7900');
    const filasOb = async () => q.locator('#ct-ob-filas .ct-ob-fila').evaluateAll(xs => xs.map(x => x.dataset.ob));
    const senal = async id => q.locator(`[data-ob="${id}"] .ct-ob-senal`).evaluate(e => [...e.childNodes].map(n => n.textContent.trim()).filter(Boolean).join(' '));
    ok('Lista · «Activas» (3): la A, la B y la G; la A con contrato $12,000.00, costo real $1,804.69 y margen 63.9 %', JSON.stringify(await filasOb()) === '["c10-prueba-a","c10-prueba-b","c10-prueba-g"]' &&
      /\$12,000\.00/.test(await texto(q, '[data-ob="c10-prueba-a"]')) && /\$1,804\.69/.test(await texto(q, '[data-ob="c10-prueba-a"]')) && /63\.9 %/.test(await texto(q, '[data-ob="c10-prueba-a"]')), await texto(q, '#ct-ob-filas'));
    ok('v2 · sin el burden la A no da veredicto: «falta el estándar» y por qué (la base deja la diferencia vacía), nunca «dentro» ni «se pasa»', /^falta el estándar Falta fijar el burden estándar/.test(await senal('c10-prueba-a')) && !/dentro|se pasa/.test(await senal('c10-prueba-a')), await senal('c10-prueba-a'));
    ok('v2 · la B (nada estimado): «sin estimado» y qué falta («Faltan las horas estimadas y el presupuesto de material.»)', /^sin estimado Faltan las horas estimadas y el presupuesto de material\.$/.test(await senal('c10-prueba-b')), await senal('c10-prueba-b'));
    ok('v2 · la G (estimado a medias: horas sí, material no, y ya lleva material): «estimado incompleto» con lo que falta, sin «se pasa» ni «dentro»',
      /^estimado incompleto No tiene presupuesto de material y ya lleva \$300\.00 de material en el libro\.$/.test(await senal('c10-prueba-g')) && (await q.locator('[data-ob="c10-prueba-g"] .ct-ob-senal .ct-pill.warn').count()) === 1, await senal('c10-prueba-g'));
    ok('v2 · una obra sin nada facturado en el libro dice «sin facturar en el libro» en vez de un «—» rojo, con el margen en dólares debajo', (await q.locator('[data-ob="c10-prueba-b"] .ct-ob-sinfac').count()) === 1 &&
      /sin facturar en el libro\s*−\$38\.11/.test(await texto(q, '[data-ob="c10-prueba-b"] [data-col="Margen"]')) && (await q.locator('[data-ob="c10-prueba-b"] [data-col="Margen"] .bad-txt').count()) === 0, await texto(q, '[data-ob="c10-prueba-b"] [data-col="Margen"]'));
    await foto(q, 'c10-7-obras-lista');
    await q.locator('[data-ob-filtro="terminadas"]').click();
    ok('Lista · «Terminadas»: la F, con «parcial»', JSON.stringify(await filasOb()) === '["c10-prueba-f"]' && (await q.locator('[data-ob="c10-prueba-f"] .ct-pill', { hasText: 'parcial' }).count()) === 1);
    await q.locator('[data-ob-filtro="todas"]').click(); await q.fill('#ct-ob-buscar', 'obra b');
    ok('Lista · buscar «obra b» en todas: solo la B', JSON.stringify(await filasOb()) === '["c10-prueba-b"]');
    await q.fill('#ct-ob-buscar', ''); await q.locator('[data-ob-filtro="activas"]').click();
    n0 = llamadas.length;
    await q.locator('#ct-ob-config input[name="burden"]').fill('10'); await q.locator('#ct-ob-config-form button[type="submit"]').click(); await esperarLlamada(q, n0, 'fn_jornal_config'); await pintado(q);
    const cfg2 = ultima(n0, 'fn_jornal_config');
    ok('Configurar · el burden 10 manda solo lo que cambió (fn_jornal_config({p: {burden_estandar_pct: 10}})) y la tarjeta queda plegada como «Ajustes»', !!cfg2 && JSON.stringify(cfg2.args) === '{"p":{"burden_estandar_pct":10}}' &&
      (await q.locator('#ct-ob-config.falta').count()) === 0 && /burden estándar 10 % · lo sin obra a 7900/.test(await texto(q, '#ct-ob-config summary')), JSON.stringify(cfg2 && cfg2.args));
    ok('…con el burden, la A ya compara: «+ $422.40 estándar» y «dentro: sobran $4,622.91»; la G sigue sin veredicto («estimado incompleto»)', /\$1,804\.69\s*\+ \$422\.40 estándar/.test(await texto(q, '[data-ob="c10-prueba-a"]')) &&
      /^dentro: sobran \$4,622\.91$/.test(await senal('c10-prueba-a')) && /^estimado incompleto/.test(await senal('c10-prueba-g')), await senal('c10-prueba-a'));
    // una obra: estimado contra real, lo real y lo estándar separados
    n0 = llamadas.length;
    await q.locator('[data-ob="c10-prueba-a"]').click(); await esperarLlamada(q, n0, 'fn_margen_obra'); await pintado(q);
    const mo = ultima(n0, 'fn_margen_obra');
    ok('Obra · tocar la A pide fn_margen_obra("c10-prueba-a") y la abre (título «Costo · C10 PRUEBA Obra A», «←» de la app visible)', !!mo && JSON.stringify(mo.args) === '{"p_proyecto":"c10-prueba-a"}' && /Costo · C10 PRUEBA Obra A/.test(await titulo2(q)) && (await q.locator('#ct-ob-det').count()) === 1);
    const conc = async () => q.locator('#ct-ob-conceptos tbody tr').evaluateAll(trs => trs.map(t => t.innerText.replace(/\s+/g, ' ').trim()));
    const cc = await conc();
    ok('Obra · estimado contra real por concepto: Material $2,500.00 / $750.25 / +$1,749.75; la mano de obra con su total $841.59 y DOS filas aparte: la real ($419.19, «real») y la estándar ($422.40, «estándar, no real»)',
      cc.some(t => /^Material \$2,500\.00 \$750\.25 — \+\$1,749\.75$/.test(t)) && cc.some(t => /^Mano de obra \$4,350\.00 \$419\.19 \$422\.40 \+\$3,508\.41$/.test(t)) &&
      cc.some(t => /^Mano de obra real \(pagada y repartida\) real/.test(t) && /\$419\.19/.test(t)) && cc.some(t => /^Mano de obra estándar, no real estándar, no real/.test(t) && /\$422\.40/.test(t)) &&
      (await q.locator('#ct-ob-conceptos tr.ct-ob-est .ct-pill', { hasText: 'estándar, no real' }).count()) === 1 && (await q.locator('#ct-ob-conceptos tr.ct-ob-est [data-bajar]').count()) === 0, cc.join(' | '));
    ok('Obra · el total ($6,850.00 estimado, $1,804.69 real, $422.40 estándar, +$4,622.91), lo facturado ($12,000.00 contra $5,000.00) y el margen (42.9 % contra 63.9 %)', cc.some(t => /^Costo de la obra \$6,850\.00 \$1,804\.69 \$422\.40 \+\$4,622\.91$/.test(t)) &&
      cc.some(t => /^Facturado \(en el libro\) \$12,000\.00 \$5,000\.00/.test(t)) && cc.some(t => /^Margen \$5,150\.00 ?42\.9 % \$3,195\.31 ?63\.9 %/.test(t)), cc.join(' | '));
    ok('Obra · la cobertura («16.5 h con pago real · 16 h a estándar · 16 h sin aprobar») y las horas contra las estimadas («32.5 h reales de 120 h estimadas (27 %)», con su barra)',
      /16\.5 h con pago real · 16 h a estándar · 16 h sin aprobar/.test(await texto(q, '.ct-ob-cobertura')) && /32\.5 h reales de 120 h estimadas \(27 %\)/.test(await texto(q, '.ct-ob-horas')) && (await q.locator('.ct-ob-barra-h span').count()) === 1, await texto(q, '.ct-ob-cobertura'));
    ok('Obra · los avisos de la base en llano (1 pago sin repartir, las 16 h a estándar)', /siguen sin repartir en la Bandeja/.test(await texto(q, '#ct-ob-det')) && /16 h van a estándar/.test(await texto(q, '#ct-ob-det')));
    ok('Obra · los CO aparte (Base 26 h y CO #1 6.5 h con $465.14), por fase (rough y trim), por cuenta (la 5200 dos veces: el subcontrato de verdad y los «jornales»), quién trabajó (2) y el reparto con su asiento',
      (await q.locator('#ct-ob-co tbody tr').count()) === 2 && /CO #1.*6\.5 h.*\$465\.14/s.test(await texto(q, '#ct-ob-co tbody tr >> nth=1')) && (await q.locator('#ct-ob-fase tbody tr').count()) === 2 &&
      (await q.locator('#ct-ob-cuentas tbody tr', { hasText: '5200' }).count()) === 2 && (await q.locator('#ct-ob-cuentas .ct-pill', { hasText: 'jornales' }).count()) === 1 && (await q.locator('#ct-ob-quien tbody tr').count()) === 2 &&
      (await q.locator('#ct-ob-repartos .ct-asiento-btn').count()) === 1);
    ok('Obra · por cost code: el vacío dicho en llano («Todavía no hay nada capturado con código…»), sin tabla ni ceros', /Todavía no hay nada capturado con código en esta obra/.test(await texto(q, '#ct-ob-cc')) && (await q.locator('#ct-ob-cc table').count()) === 0);
    await foto(q, 'c10-8-obra');
    // bajar a los asientos: el material (2 líneas, sin el asiento del jornal) y la mano de obra real (el asiento del jornal)
    l0 = lecturas.length;
    await q.locator('#ct-ob-conceptos tr', { hasText: 'Material' }).locator('[data-bajar]').click(); await q.waitForSelector('#ct-ob-bajada', { timeout: 5000 }); await pintado(q);
    const lb = lecturas.slice(l0).filter(l => /^v_libro\?/.test(l));
    ok('Bajar · el real del material lee v_libro con la llave de la base (cuenta 5100, la obra, sin el asiento del jornal) y enseña sus 2 líneas, que suman $750.25 «lo mismo que la cifra»', lb.length === 1 &&
      /cuenta=eq\.5100/.test(lb[0]) && /proyecto_id=eq\.c10-prueba-a/.test(lb[0]) && /asiento_id=not\.in\.\(1b0d2ea3-e7a3-4620-8f9b-958ad9a6acaf\)/.test(lb[0]) &&
      (await q.locator('#ct-ob-bajada tbody tr').count()) === 2 && /suman \$750\.25: lo mismo que la cifra/.test(await texto(q, '#ct-ob-bajada .ct-aviso.ok')) && (await q.locator('#ct-ob-bajada .ct-asiento-btn').count()) === 2, lb.join(' | '));
    await foto(q, 'c10-9-bajar');
    ok('Bajar · «←» de la app vuelve a la obra', await q.evaluate(() => window.MXP_CONTA.atras()) && (await pintado(q), (await q.locator('#ct-ob-det').count()) === 1));
    l0 = lecturas.length;
    await q.locator('#ct-ob-conceptos tr.ct-ob-detalle', { hasText: 'Mano de obra real' }).locator('[data-bajar]').click(); await q.waitForSelector('#ct-ob-bajada', { timeout: 5000 }); await pintado(q);
    ok('Bajar · la mano de obra real: sus dos pedazos (las líneas del jornal por su asiento y la nómina 50xx, que no hay) suman $419.19, y el asiento 2026-000004 se abre en Estados', lecturas.slice(l0).filter(l => /^v_libro\?/.test(l)).length === 2 &&
      (await q.locator('#ct-ob-bajada tbody tr').count()) === 2 && /suman \$419\.19/.test(await texto(q, '#ct-ob-bajada .ct-aviso.ok')) && (await q.locator('#ct-ob-bajada .ct-asiento-btn', { hasText: '2026-000004' }).count()) === 2);
    await q.locator('#ct-ob-volver').click(); await pintado(q);
    await q.locator('#ct-ob-conceptos tr', { hasText: 'Facturado' }).locator('[data-bajar]').click(); await q.waitForSelector('#ct-ob-bajada', { timeout: 5000 }); await pintado(q);
    ok('Bajar · lo facturado baja con su signo (−1 sobre el haber de 4020): $5,000.00, lo mismo que la cifra', /suma \$5,000\.00: lo mismo que la cifra/.test(await texto(q, '#ct-ob-bajada .ct-aviso.ok')));
    // una cifra que no suma lo que baja: rojo
    J.libro.push({ ...J.libro[0], asiento_id: 'c1a00000-0000-4000-8000-0000000000ff', numero: '2026-000199', orden: 2, monto: 10, debe: 10 });
    await q.locator('#ct-ob-volver').click(); await pintado(q);
    await q.locator('#ct-ob-conceptos tr', { hasText: 'Material' }).locator('[data-bajar]').click(); await q.waitForSelector('#ct-ob-bajada', { timeout: 5000 }); await pintado(q);
    ok('Bajar · si lo que baja no suma la cifra, lo dice en rojo («no cuadra…»)', /Lo que baja suma \$760\.25 y la cifra dice \$750\.25: no cuadra/.test(await texto(q, '#ct-ob-bajada .ct-aviso.bad')));
    J.libro.pop();
    await q.locator('#ct-ob-bajada .ct-asiento-btn').first().click(); await q.waitForTimeout(400);
    ok('Bajar · tocar un asiento abre Estados en ese asiento', await q.evaluate(() => window.MXP_CONTA._estado.pagina === 'estados' && !!window.MXP_CONTA._estado.est.asiento));
    // (v2) la G: el estimado incompleto, dicho arriba y en el total; sin margen estimado ni diferencia
    await ve(q, 'obras', { sel: 'c10-prueba-g' });
    const ccG = await conc();
    ok('v2 · obra G: arriba dice qué le falta al estimado (el texto de la base) y el margen real «sin facturar en el libro»', /Estimado incompleto: no tiene presupuesto de material y ya lleva \$300\.00 de material en el libro\. No da un total que comparar/.test(await texto(q, '#ct-ob-det .ct-ob-faltaest')) &&
      /sin facturar en el libro/.test(await texto(q, '#ct-ob-det .ct-kpi')), await texto(q, '#ct-ob-det .ct-jr-avisos'));
    ok('v2 · …su total no tiene estimado ni diferencia (con la nota de la base) y el margen estimado sale «—» con «sin estimado completo»', ccG.some(t => /^Costo de la obra Estimado incompleto: .* — \$300\.00 \$158\.40 —$/.test(t)) &&
      ccG.some(t => /^Margen — ?sin estimado completo/.test(t)), ccG.join(' | '));
    await foto(q, 'c10-8b-obra-incompleta');
    // la F: terminada y parcial
    await ve(q, 'obras', { sel: 'c10-prueba-f' });
    ok('Obra F · «parcial» con el porqué de la base y que lo de antes del 1 oct 2026 está en QuickBooks', (await q.locator('#ct-ob-det .ct-pill', { hasText: 'parcial' }).count()) === 1 && /Parcial: ya andaba antes del libro.*está en QuickBooks/.test(await texto(q, '#ct-ob-det .ct-aviso.warn')));
    // el margen que no cuadra: la página no pinta cifras
    J.margenRojo = true;
    await ve(q, 'obras');
    ok('Falla ruidosa · un cuadre del margen en rojo: «El costo por obra no cuadra» con su detalle, y ninguna obra ni cifra pintada', /El costo por obra no cuadra/.test(await texto(q, '#ct-ob-cuerpo .ct-rojo h2')) && /Las obras suman \$3,444\.42 de costo y el mayor \(cuentas de costo con obra\) \$3,498\.92: diferencia -\$54\.50/.test(await texto(q, '#ct-ob-cuerpo .ct-rojo')) && (await q.locator('.ct-ob-fila').count()) === 0);
    J.margenRojo = false;
    // ---- Repartos: el historial con «Deshacer» ----
    await ve(q, 'obras', { sub: 'repartos' });
    ok('Repartos · los dos repartos (el más nuevo arriba), cada uno con su persona, su monto, su período, su asiento y «Deshacer»', (await q.locator('.ct-rep').count()) === 2 && /Zzbeto C10 PRUEBA · \$600\.00/.test(await texto(q, '.ct-rep >> nth=0')) &&
      /Zzana C10 PRUEBA · \$940\.00/.test(await texto(q, '.ct-rep >> nth=1')) && (await q.locator('.ct-rep [data-deshacer]').count()) === 2 && (await q.locator('.ct-rep .ct-asiento-btn').count()) === 2);
    await foto(q, 'c10-10-repartos');
    const rAna = q.locator(`.ct-rep[data-reparto="${J.repartos[0].reparto_id}"]`);
    await rAna.locator('[data-deshacer]').click(); await rAna.locator('.ct-form textarea[name="motivo"]').waitFor({ timeout: 5000 });
    n0 = llamadas.length;
    await rAna.locator('.ct-form button[type="submit"]').click(); await q.waitForTimeout(150);
    ok('Deshacer · sin motivo no se manda nada (el motivo es obligatorio)', !desde(n0).some(l => l.fn === 'fn_jornal_deshacer') && (await rAna.locator('.ct-error').count()) === 1);
    await rAna.locator('.ct-form textarea[name="motivo"]').fill('Las fechas estaban mal');
    await rAna.locator('.ct-form button[type="submit"]').click(); await esperarLlamada(q, n0, 'fn_jornal_deshacer'); await pintado(q);
    const des = ultima(n0, 'fn_jornal_deshacer');
    ok('Deshacer · con motivo manda fn_jornal_deshacer(reparto, motivo); el reparto queda «deshecho» con su motivo y su reverso, y el pago vuelve a la Bandeja', !!des && des.args.p_reparto === J.repartos[0].reparto_id && des.args.p_motivo === 'Las fechas estaban mal' &&
      (await q.locator(`.ct-rep[data-reparto="${J.repartos[0].reparto_id}"] .ct-pill`, { hasText: 'deshecho' }).count()) === 1 && /«Las fechas estaban mal».*reverso/.test(await texto(q, `.ct-rep[data-reparto="${J.repartos[0].reparto_id}"]`)) &&
      jPendientes().some(f => f.movimiento_id === J_MOV.ana), JSON.stringify(des && des.args));
    // ---- Personas ----
    await ve(q, 'obras', { sub: 'personas' });
    ok('Personas · las tres de la cuadrilla, ya dadas de alta, con cómo las reconoce el banco («PRUEBA ZZANA») y sus pagos', (await q.locator('.ct-per').count()) === 3 && /Se reconoce por «PRUEBA ZZANA»/.test(await texto(q, `.ct-per[data-usuario="${J_PER.ana}"]`)) &&
      (await q.locator('.ct-per [data-per-baja]').count()) === 3);
    await foto(q, 'c10-11-personas');
    n0 = llamadas.length;
    await q.locator(`.ct-per[data-usuario="${J_PER.carla}"] [data-per-baja]`).click(); await esperarLlamada(q, n0, 'fn_jornal_persona'); await pintado(q);
    const baja = ultima(n0, 'fn_jornal_persona');
    ok('Personas · «Dar de baja» manda fn_jornal_persona({p: {usuario_id, activa: false}}) y queda «de baja» con «Volver a dar de alta»', !!baja && JSON.stringify(baja.args) === JSON.stringify({ p: { usuario_id: J_PER.carla, activa: false } }) &&
      (await q.locator(`.ct-per[data-usuario="${J_PER.carla}"] [data-per-vuelve]`).count()) === 1);
    n0 = llamadas.length;
    await q.locator(`.ct-per[data-usuario="${J_PER.ana}"] [data-per-patron]`).click(); await q.locator(`.ct-per[data-usuario="${J_PER.ana}"] input[name="patron"]`).fill('C10 PRUEBA ZZANA');
    await q.locator(`.ct-per[data-usuario="${J_PER.ana}"] .ct-form button[type="submit"]`).click(); await esperarLlamada(q, n0, 'fn_jornal_persona'); await pintado(q);
    const pat = ultima(n0, 'fn_jornal_persona');
    ok('Personas · «Cambiar el patrón» manda el que escribió Edgar', !!pat && pat.args.p.usuario_id === J_PER.ana && pat.args.p.patron === 'C10 PRUEBA ZZANA', JSON.stringify(pat && pat.args));
    ok('v2 · …y el aviso de la app es la nota de la base («…reconocidos con «C10 PRUEBA ZZANA»»), sin «Ojo»', /Zzana C10 PRUEBA: 2 pago\(s\) pendientes reconocidos con «C10 PRUEBA ZZANA»\.$/.test((await texto(q, '#toast')).trim()), await texto(q, '#toast'));
    n0 = llamadas.length;
    await q.locator(`.ct-per[data-usuario="${J_PER.ana}"] [data-per-patron]`).click(); await q.locator(`.ct-per[data-usuario="${J_PER.ana}"] input[name="patron"]`).fill('C10 PRUEBA');
    await q.locator(`.ct-per[data-usuario="${J_PER.ana}"] .ct-form button[type="submit"]`).click(); await esperarLlamada(q, n0, 'fn_jornal_persona'); await pintado(q);
    const tPat = await texto(q, '#toast');
    ok('v2 · un patrón sin su nombre y que casa con pagos a varios: los avisos de la base salen en el aviso de la app, en ámbar/rojo («Ojo: El patrón «C10 PRUEBA» no lleva el nombre de Zzana…», «…de 3 formas distintas…»)',
      /Ojo: El patrón «C10 PRUEBA» no lleva el nombre de Zzana C10 PRUEBA \(«ZZANA»\)/.test(tPat) && /casa con pagos que el banco describe de 3 formas distintas/.test(tPat) && /error/.test(await q.locator('#toast').getAttribute('class')), tPat);
    J.personas.find(x => x.usuario_id === J_PER.ana).patron = '\\mPRUEBA ZZANA\\M';
    // ---- «Qué atender» con un rojo del jornal ----
    J.ctlRojo = true;
    await ve(q, 'resumen');
    atn = await q.locator('#ct-atender .ct-atn').allTextContents();
    ok('«Qué atender» · un cuadre del jornal en rojo sale con su detalle y su botón «Obras» (a los repartos)', atn.some(t => /^Mano de obra: ningún reparto aplicado con su asiento reversado o su pago suelto \(no cuadra\)\.el reparto del pago del 2026-11-02 a Zzana C10 PRUEBA/.test(t)) &&
      (await q.locator('#ct-atender .ct-atn', { hasText: 'Mano de obra: ningún reparto' }).locator('button[data-ir="obras"][data-ir-sub="repartos"]').count()) === 1, atn.join(' | '));
    await ve(q, 'bandeja');
    ok('…y la Bandeja lo dice arriba, en su franja', /Ningún reparto aplicado con su asiento reversado o su pago suelto/.test(await texto(q, '#ct-jr-franja .ct-aviso.bad')));
    J.ctlRojo = false;
    await cx.close();

    // ---- sin el código del teléfono: la tarjeta se ve, «Así es» no ----
    J.ia[0].estado = 'pendiente';
    ({ cx, q } = await abrirCtx(1280, false));
    const nS = llamadas.length;
    await ve(q, 'bandeja');
    const cS = await fila(q, J_MOV.ana);
    ok('Sin el código del teléfono · la tarjeta se ve entera pero «Así es» va apagado y lo dice («pide entrar con el código del teléfono»)', (await cS.locator('.ct-jr-tabla tbody tr').count()) === 7 && await cS.locator('[data-jr-asi]').isDisabled() && /pide entrar con el código del teléfono/.test(await cS.textContent()));
    ok('v2 · …y lo de la IA abierto en un pago repartido no se intenta cerrar (la función pide el código): la franja dice que entre con él', /sigue abierta.*entra con el código del teléfono/.test(await texto(q, '#ct-jr-ia')) && !desde(nS).some(l => /^contador:/.test(l.fn)), await texto(q, '#ct-jr-ia'));
    await ve(q, 'obras', { sub: 'repartos' });
    await q.locator('.ct-rep [data-deshacer]').first().click(); await q.waitForTimeout(150);
    J.ia[0].estado = 'rechazada';
    ok('…y «Deshacer» un reparto tampoco: lo dice y no abre el motivo', /primero activa el código del teléfono/.test(await texto(q, '.ct-rep >> nth=0')) && (await q.locator('.ct-rep textarea[name="motivo"]').count()) === 0);
    await cx.close();

    // ---- el teléfono (390), el iPad (820) y la computadora (1280): sin desplazamiento lateral ----
    for (const w of [390, 820, 1280]) {
      ({ cx, q } = await abrirCtx(w, true));
      const mal = [];
      const mide = async nombre => { const m = await q.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: window.innerWidth, rojo: !!document.querySelector('#conta-raiz .ct-rojo') })); if (m.sw > m.iw + 1 || m.rojo) mal.push(`${nombre}: ${m.sw} > ${m.iw}${m.rojo ? ' (rojo)' : ''}`); await foto(q, `c10-${w}-${nombre}`); };
      await ve(q, 'bandeja'); await fila(q, J_MOV.ana); await q.waitForTimeout(150); await mide('bandeja');
      if (w === 390) {
        const anchos = await q.evaluate(id => { const c = document.querySelector(`.ct-mov[data-id="${id}"] .ct-jr-tabla`); const r = c.getBoundingClientRect(); return { der: Math.round(r.right), iw: window.innerWidth }; }, J_MOV.ana);
        ok('Teléfono · la tabla del reparto (obra, horas, dólares) cabe en 390 px sin apilarse', anchos.der <= anchos.iw, JSON.stringify(anchos));
      }
      await fila(q, J_MOV.carla); await q.waitForTimeout(150); await mide('bandeja-tarifa');
      await ve(q, 'obras'); await mide('obras');
      await ve(q, 'obras', { sel: 'c10-prueba-a' }); await mide('obra');
      await q.locator('#ct-ob-conceptos tr', { hasText: 'Material' }).locator('[data-bajar]').click(); await q.waitForSelector('#ct-ob-bajada', { timeout: 5000 }); await pintado(q); await mide('bajar');
      await ve(q, 'obras', { sub: 'repartos' }); await mide('repartos');
      await ve(q, 'obras', { sub: 'personas' }); await mide('personas');
      ok(`Mano de obra y costo por obra · ${w} px: la Bandeja con la tarjeta, la lista, la obra, lo bajado, los repartos y las personas, sin desplazamiento lateral ni rojos`, !mal.length, mal.join(' | '));
      if (w === 390) {
        const tv = await q.evaluate(() => { const t = document.querySelector('.ct-tabs'), a = t.querySelector('.ct-tab[aria-current="page"]'), T = t.getBoundingClientRect(), A = a.getBoundingClientRect(); return { pag: a.dataset.pag, izq: Math.round(A.left - T.left), der: Math.round(T.right - A.right) }; });
        ok('Teléfono · la pestaña «Obras» se ve entera dentro de la tira de pestañas', tv.pag === 'obras' && tv.izq >= 14 && tv.der >= 14, JSON.stringify(tv));
      }
      await cx.close();
    }

    // ---- sin c10: la Bandeja de siempre y «Costo por obra» lo dice en llano ----
    estado.c10 = false;
    ({ cx, q } = await abrirCtx(1280, true));
    await ve(q, 'bandeja');
    ok('Sin c10 · la Bandeja es la de siempre (sin franja ni tarjetas de mano de obra) y no se pone en rojo', (await q.locator('#ct-jr-franja').count()) === 0 && (await q.locator('[data-jr-bloque]').count()) === 0 && (await q.locator('#conta-raiz .ct-rojo').count()) === 0);
    await ve(q, 'obras');
    ok('Sin c10 · «Costo por obra» dice en llano que falta c10-costo-obra.sql (con «Reintentar»)', /Falta el costo por obra en la base/.test(await texto(q, '#ct-ob-cuerpo .ct-rojo h2')) && /c10-costo-obra\.sql/.test(await texto(q, '#ct-ob-cuerpo .ct-rojo')) && (await q.locator('#ct-reintentar').count()) === 1);
    await cx.close();
    conCodigo(false);
  }

  // ---- Las facturas (c11, fase 10): antes del corte (arriba lo dice, lo que falta, borradores para probar y «Emitir»
  // apagado), Ajustes (la empresa y el «How to pay»), desde el corte: por facturar (los hitos, la retención de la obra,
  // por porcentaje, T&M), el borrador con sus avisos y su vista previa EN INGLÉS, cambiarlo y refrescarlo, emitir con el
  // código del teléfono (la confirmación escrita, el «visto», MX011), la emitida (lo que debe hoy, el PDF con su enlace solo
  // por cuenta de banco, el PDF sin enlace si Stripe no deja, mandar, reenviar, el correo que no se apuntó, en mano), la
  // lista, tirar un borrador, el texto que parece español, anular con nota de crédito y desactivar su enlace, el 🧾 de un
  // hito desde la ficha de la obra (antes del corte, a QuickBooks; desde el corte, aquí), sin la función, sin c11, el rojo
  // del control, y el teléfono, el iPad y la computadora sin desplazamiento lateral ----
  {
    estado.c11 = true; estado.c11Fn = true; fReset({ antes: true, sinEmpresa: true });
    const conCodigo = si => { estado.mfaFactores = si ? [{ id: 'f-1', friendly_name: 'Teléfono de Edgar', factor_type: 'totp', status: 'verified' }] : []; estado.sesionAal = si ? 'aal2' : undefined; };
    const abrirCtx = async (w, codigo) => {
      conCodigo(codigo);
      const cx = await b.newContext({ viewport: { width: w, height: w < 700 ? 844 : 1000 }, deviceScaleFactor: w < 1024 ? 2 : 1, isMobile: w < 1024, hasTouch: w < 1024, serviceWorkers: 'block' });
      await simular(cx, 'dueno');
      const q = await cx.newPage(); q.on('pageerror', e => errs.push(`c11 ${w}: ` + String(e).slice(0, 160)));
      await q.goto('http://localhost:8873/index.html'); await q.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await q.waitForTimeout(800);
      await q.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
      await q.locator('#btn-conta').evaluate(x => x.click()); await q.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 }); await pintado(q);
      return { cx, q };
    };
    const ve = async (q, k, op) => { await q.evaluate(([k, o]) => window.MXP_CONTA.ir(k, o || {}), [k, op || null]); await pintado(q); };
    const ultima = (n0, fn) => desde(n0).filter(l => l.fn === fn).pop();
    const docCard = q => q.locator('#ct-fac-doc');
    const toca = async (q, sel) => { await q.locator(sel).first().evaluate(x => x.click()); await pintado(q); };
    let { cx, q } = await abrirCtx(1280, true);

    // ---- antes del corte, sin los datos de la empresa ----
    let n0 = llamadas.length;
    await ve(q, 'facturas');
    ok('Facturas · está en el menú (pestaña y lateral) y la página lee el estado del corte y el control antes de pintar', (await q.locator('.ct-tab[data-pag="facturas"]').count()) === 1 && (await q.locator('#lateral [data-lat="conta-facturas"]').count()) === 1 &&
      lecturas.some(l => l.startsWith('v_emision_estado')) && lecturas.some(l => l.startsWith('v_emision_control')) && (await titulo2(q)) === 'Facturas');
    let arriba = await texto(q, '#ct-fac-corte');
    ok('Antes del corte · arriba, en llano: «Hasta el corte se factura por QuickBooks», el texto de la base (hasta el 31-dic-2026 por QuickBooks, borradores para probar, se emitirá desde el 1-ene-2027) y cuántos días faltan',
      /Hasta el corte se factura por QuickBooks/.test(arriba) && /Hasta el 31-dic-2026 las facturas salen por QuickBooks \(el 🧾 de siempre\)\. Aquí se pueden preparar borradores para probar; se podrán emitir desde el 1-ene-2027\./.test(arriba) && /faltan \d+ días/.test(arriba), arriba);
    ok('…y lo que falta para emitir: «los datos de la empresa y el «How to pay»», con «Ponerlos en Ajustes»', /Para emitir faltan los datos de la empresa y el «How to pay»/.test(arriba) && (await q.locator('[data-fac-ir-ajustes]').count()) === 1, arriba);
    ok('…la lista vacía dice por dónde se empieza (sin pintar ceros) y el control no tiene rojos', /Todavía ninguna factura de la app\. Empieza en «Por facturar»/.test(await texto(q, '#ct-fac-filas')) && (await q.locator('#conta-raiz .ct-rojo').count()) === 0);
    ok('…y antes del corte no promete un número (la base lo da con el año de hoy; la primera de verdad lleva el del corte): «se numeran desde el corte (1 ene 2027)»',
      /se numeran desde el corte \(1 ene 2027\)/.test(await texto(q, '.ct-pag-sub')) && !/la siguiente/.test(await texto(q, '.ct-pag-sub')), await texto(q, '.ct-pag-sub'));
    await foto(q, 'c11-0-antes-del-corte');
    // por facturar → el hito Rough-in → su borrador
    await toca(q, '[data-fac-sub="obras"]');
    const obraA = q.locator('.ct-fac-obra[data-obra="c11-prueba-a"]');
    ok('Por facturar · cada obra con su contrato, lo facturado, lo que falta y su retención (10 %, de la obra), sus hitos con «Facturar», y por porcentaje / T&M',
      (await q.locator('.ct-fac-obra').count()) === 3 && /\$18,500\.55/.test(await obraA.textContent()) && /Retención: 10 %/.test(await obraA.locator('.ct-fac-ret').textContent()) && /la de la obra/.test(await obraA.locator('.ct-fac-ret').textContent()) &&
      (await obraA.locator('[data-fac-hito]').count()) === 2 && (await obraA.locator('[data-fac-pct]').count()) === 1 && (await obraA.locator('[data-fac-tm]').count()) === 1, await obraA.textContent());
    ok('…la obra terminada (Taller Cuatro) sale solo con «Todas», y la del contratista lo dice', !(await q.locator('.ct-fac-obra[data-obra="c11-prueba-d"]').count()) && /se le factura al contratista/.test(await texto(q, '.ct-fac-obra[data-obra="c11-prueba-c"]')));
    n0 = llamadas.length;
    await obraA.locator('[data-fac-hito="-1110000001"]').click(); await pintado(q);
    let lb = ultima(n0, 'fn_emision_borrador');
    ok('Facturar un hito llama a fn_emision_borrador({forma: hito, hito_id}) y abre el borrador', lb && JSON.stringify(lb.args) === JSON.stringify({ p: { forma: 'hito', hito_id: -1110000001 } }) && (await docCard(q).count()) === 1 && /^Borrador/.test(await docCard(q).locator('h2').textContent()), lb && JSON.stringify(lb.args));
    let doc = docCard(q);
    ok('Borrador antes del corte · sus avisos con el texto de la base (el corte y lo que falta frenan, en rojo) y «Emitir la factura» apagado diciendo por qué',
      (await doc.locator('[data-aviso="antes_del_corte"].bad').count()) === 1 && /se podrá emitir desde el 1-ene-2027/.test(await doc.locator('[data-aviso="antes_del_corte"]').textContent()) &&
      (await doc.locator('[data-aviso="falta_empresa"].bad').count()) === 1 && (await doc.locator('[data-aviso="falta_como_pagar"].bad').count()) === 1 && await doc.locator('[data-fac-emitir]').isDisabled() && /No se emite todavía: lo que está en rojo lo frena \(3 cosas\)/.test(await doc.locator('.ct-fac-porque').textContent()));
    ok('…los montos los da la base: $1,234.57, retención $123.46 (10 % · la de la obra), a pagar $1,111.11', /\$1,234\.57/.test(await doc.locator('.ct-kpis').textContent()) && /\$123\.46/.test(await doc.locator('.ct-kpis').textContent()) && /10 % · la de la obra/.test(await doc.locator('.ct-kpis').textContent()) && /\$1,111\.11/.test(await doc.locator('.ct-kpis').textContent()));
    let previa = await texto(q, '#ct-fac-previa .ct-fx');
    ok('…y la vista previa EN INGLÉS (lang="en"), como el PDF: INVOICE, DRAFT (sin número), Due on receipt, Progress billing #1, Bill to / Project / Contract status, la línea, «Less retainage held (10%) -$123.46» y «Amount due $1,111.11»',
      (await q.locator('#ct-fac-previa .ct-fx[lang="en"]').count()) === 1 && /INVOICE/.test(previa) && /DRAFT/.test(previa) && /Due on receipt/.test(previa) && /Progress billing #1/.test(previa) && /Bill to/i.test(previa) && /ZZ Cliente Uno/.test(previa) &&
      /Contract status/i.test(previa) && /C11 PRUEBA Rough-in/.test(previa) && /Due upon passing the rough-in inspection/.test(previa) && /Less retainage held \(10%\)\s*-\$123\.46/.test(previa) && /Amount due\s*\$1,111\.11/.test(previa) && /falta el «How to pay» en Ajustes/.test(previa), previa.slice(0, 900));
    await foto(q, 'c11-1-borrador-antes');
    // Ajustes: la empresa y el How to pay
    await ve(q, 'facturas', { sub: 'ajustes' });
    const aj = q.locator('#ct-fac-ajustes-form');
    await aj.locator('[name="e_nombre"]').fill(F_EMPRESA.nombre); await aj.locator('[name="e_licencia"]').fill(F_EMPRESA.licencia); await aj.locator('[name="e_direccion"]').fill(F_EMPRESA.direccion);
    await aj.locator('[name="e_telefono"]').fill(F_EMPRESA.telefono); await aj.locator('[name="e_correo"]').fill(F_EMPRESA.correo); await aj.locator('[name="e_web"]').fill(F_EMPRESA.web);
    // el «How to pay» que habla de un enlace avisa mientras se escribe (en las facturas sin enlace apuntaría a nada); el de la casa, no
    await aj.locator('[name="como_pagar"]').fill('Bank transfer (ACH): use the secure link in the email.');
    const avisoLink = await q.locator('#ct-fac-como-aviso').isVisible();
    await aj.locator('[name="como_pagar"]').fill(F_COMO_PAGAR);
    ok('Ajustes · el «How to pay» dice que sale en TODAS las facturas (con enlace y sin él) y avisa, mientras se escribe, si habla de un enlace («the secure link»); el de la casa no avisa',
      avisoLink && !(await q.locator('#ct-fac-como-aviso').isVisible()) && /Sale igual en TODAS las facturas/.test(await texto(q, '#ct-fac-ajustes-form')) && /habla de un enlace de pago/.test(await q.locator('#ct-fac-como-aviso').textContent()));
    ok('Ajustes · la tarjeta sale apagada con su porqué (el recargo quedaría de anticipo; se confirma con Stripe y con el CPA) y el pago por cuenta de banco marcado', /La tarjeta está apagada/.test(await texto(q, '.ct-fac-tarjeta')) && /con Stripe y con el CPA/.test(await texto(q, '.ct-fac-tarjeta')) && await aj.locator('[name="ach"]').isChecked());
    n0 = llamadas.length;
    await aj.locator('button[type="submit"]').click(); await pintado(q);
    const lc = ultima(n0, 'fn_emision_config');
    ok('…«Guardar los ajustes» manda SOLO lo que cambió a fn_emision_config: la empresa entera y el «How to pay»', lc && JSON.stringify(Object.keys(lc.args.p).sort()) === '["como_pagar","empresa"]' && lc.args.p.empresa.nombre === F_EMPRESA.nombre && lc.args.p.como_pagar === F_COMO_PAGAR, lc && JSON.stringify(lc.args));
    ok('…y arriba ya no dice que falte nada', !/Para emitir falta/.test(await texto(q, '#ct-fac-corte')));
    // el corte: desde hoy (Ajustes → El corte y el número)
    await q.locator('.ct-fac-avanzado summary').click();
    await q.locator('#ct-fac-ajustes-form [name="corte"]').fill(HOY);
    n0 = llamadas.length;
    await q.locator('#ct-fac-ajustes-form button[type="submit"]').click(); await pintado(q);
    ok('…mover el corte a hoy manda {corte} y arriba dice «Se factura aquí» con el texto de la base', JSON.stringify(ultima(n0, 'fn_emision_config').args) === JSON.stringify({ p: { corte: HOY } }) && /Se factura aquí/.test(await texto(q, '#ct-fac-corte')) && /las facturas se emiten aquí, con su número de la serie del año/.test(await texto(q, '#ct-fac-corte')));

    // ---- desde el corte: el borrador se puede emitir ----
    const idA = F.docs[0].id;
    await ve(q, 'facturas', { doc: idA });
    doc = docCard(q);
    ok('Desde el corte · el mismo borrador ya no tiene frenos: «Nada lo frena» y «Emitir la factura» encendido', /Nada lo frena: se puede emitir/.test(await doc.textContent()) && !(await doc.locator('[data-fac-emitir]').isDisabled()));
    ok('«←» de la app cierra la factura y vuelve a donde se estaba (aquí, Ajustes)', await q.evaluate(() => window.MXP_CONTA.atras()) === true && (await (async () => { await pintado(q); return q.locator('#ct-fac-doc').count(); })()) === 0 && (await q.locator('#ct-fac-ajustes').count()) === 1 && (await titulo2(q)) === 'Facturas');
    await ve(q, 'facturas', { doc: idA });
    // cambiar: la descripción, la retención y las notas (en inglés)
    await toca(q, '#ct-fac-doc [data-fac-cambiar]');
    const fb = q.locator('#ct-fac-doc .ct-form form');
    await fb.locator('[name="descripcion"]').fill('Rough-in, first floor'); await fb.locator('[name="notas"]').fill('Thank you for your business.');
    n0 = llamadas.length;
    await fb.locator('button[type="submit"]').click(); await pintado(q);
    lb = ultima(n0, 'fn_emision_borrador');
    ok('Cambiar · solo lo que cambió va a fn_emision_borrador (documento, descripcion, notas) y la vista previa lo enseña', lb && JSON.stringify(lb.args) === JSON.stringify({ p: { documento: idA, descripcion: 'Rough-in, first floor', notas: 'Thank you for your business.' } }) &&
      /Rough-in, first floor/.test(await texto(q, '#ct-fac-previa')) && /Thank you for your business\./.test(await texto(q, '#ct-fac-previa')), lb && JSON.stringify(lb.args));
    // con el código: la confirmación escrita
    await toca(q, '#ct-fac-doc [data-fac-emitir]');
    const fe = q.locator('#ct-fac-doc .ct-form');
    ok('Emitir · pide confirmarlo por escrito y dice en llano que después no se cambia (el siguiente número, el monto, la nota de crédito si sale mal)', /Después ya no se cambia/.test(await fe.textContent()) && /MXP-\d{4}-0001/.test(await fe.textContent()) && /nota de crédito/.test(await fe.textContent()) && (await fe.locator('[name="si"]').count()) === 1, await fe.textContent());
    n0 = llamadas.length;
    await fe.locator('button[type="submit"]').click(); await q.waitForTimeout(150);
    ok('…sin marcar «La revisé y se emite así» no llama a la base y lo dice', !ultima(n0, 'fn_emision_emitir') && /Marca que la revisaste/.test(await fe.textContent()));
    // MX011: el hito cambió entre que se vio y se tocó
    const hA = F.hitos.find(h => h.id === -1110000001); hA.monto = 123500;
    await fe.locator('[name="si"]').check(); await fe.locator('button[type="submit"]').click(); await pintado(q);
    const le = ultima(n0, 'fn_emision_emitir');
    ok('MX011 · el hito cambió entre que se vio y se tocó: se mandó el «visto» que se enseñó, la base no emitió nada (lo dice con su texto) y la pantalla se vuelve a leer con el aviso «hito_cambio» y «Refrescar el borrador»',
      le && le.args.p_documento === idA && /^[0-9a-f]{32}$/.test(le.args.p_visto) && F.docs[0].estado === 'borrador' && /ahora vale \$1,235\.00 y este borrador dice \$1,234\.57/.test(await texto(q, '#ct-fac-doc > .ct-aviso')) && (await q.locator('#ct-fac-doc [data-aviso="hito_cambio"]').count()) === 1 && (await q.locator('#ct-fac-doc [data-fac-refrescar]').count()) === 1, await texto(q, '#ct-fac-doc .ct-aviso'));
    hA.monto = 123457;
    n0 = llamadas.length;
    await toca(q, '#ct-fac-doc [data-fac-refrescar]');
    ok('…«Refrescar el borrador» llama a fn_emision_borrador solo con el documento y el aviso se va', JSON.stringify(ultima(n0, 'fn_emision_borrador').args) === JSON.stringify({ p: { documento: idA } }) && !(await q.locator('#ct-fac-doc [data-aviso="hito_cambio"]').count()));
    // MX011 de verdad: los ajustes que salen en la factura cambian (otra pestaña) entre que se ve y se toca
    await toca(q, '#ct-fac-doc [data-fac-emitir]');
    await q.locator('#ct-fac-doc .ct-form [name="si"]').check();
    F.config.terminos_texto = 'Balances past due accrue 1.5% per month.';
    n0 = llamadas.length;
    await q.locator('#ct-fac-doc .ct-form button[type="submit"]').click(); await pintado(q);
    ok('MX011 · cambiaron los ajustes en otra pestaña: «El borrador ya no es el que viste…» y no se emitió nada; la vista previa ya trae los términos nuevos',
      !!ultima(n0, 'fn_emision_emitir') && F.docs[0].estado === 'borrador' && /El borrador ya no es el que viste/.test(await texto(q, '#ct-fac-doc > .ct-aviso')) && /Balances past due accrue 1\.5% per month\./.test(await texto(q, '#ct-fac-previa')));
    await toca(q, '#ct-fac-doc [data-fac-emitir]');
    const visto = await q.evaluate(id => fetch('https://zeogjvwcmstmkwxjvykz.supabase.co/rest/v1/rpc/fn_emision_documento', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ p_documento: id }) }).then(r => r.json()).then(j => j.visto), idA);
    await q.locator('#ct-fac-doc .ct-form [name="si"]').check();
    n0 = llamadas.length;
    await q.locator('#ct-fac-doc .ct-form button[type="submit"]').click(); await pintado(q);
    const le2 = ultima(n0, 'fn_emision_emitir');
    doc = docCard(q);
    ok('Emitir · con la casilla: fn_emision_emitir(documento, el visto de lo que se ve, {}) y la factura queda emitida: MXP-…-0001, «emitida», el asiento y «Ahora, el PDF y mandarla»',
      le2 && le2.args.p_visto === visto && JSON.stringify(le2.args.p_opciones) === '{}' && /MXP-\d{4}-0001/.test(await doc.locator('h2').textContent()) && /emitida/.test(await doc.locator('.ct-cab .ct-pill').textContent()) && /asiento 2026-000002/.test(await doc.textContent()) && /Ahora, el PDF y mandarla/.test(await doc.textContent()), le2 && JSON.stringify(le2.args));
    ok('…lo que debe hoy en el libro ($1,111.11 y $123.46 de retención), «Todavía sin PDF», «Sin mandar», y el pago en línea por cuenta de banco (la tarjeta, apagada)',
      /Debe hoy\s*\$1,111\.11/.test(await doc.locator('.ct-kpis').textContent()) && /\$123\.46 de retención/.test(await doc.locator('.ct-kpis').textContent()) && /Todavía sin PDF/.test(await doc.textContent()) && /Sin mandar todavía/.test(await doc.textContent()) && /Se paga en línea por cuenta de banco \(ACH\)/.test(await doc.textContent()) && /La tarjeta, apagada/.test(await doc.textContent()));
    const congelado = await texto(q, '#ct-fac-previa .ct-fx');
    ok('…y la vista es lo que recibió el cliente (el contenido congelado): «No. MXP-…-0001», ya sin DRAFT', /No\. MXP-\d{4}-0001/.test(congelado) && !/DRAFT/.test(congelado) && /Please reference invoice MXP-\d{4}-0001/.test(congelado), congelado.slice(0, 300));
    await foto(q, 'c11-2-emitida');
    // el PDF: con su enlace de pago (solo cuenta de banco)
    n0 = llamadas.length;
    await toca(q, '#ct-fac-doc [data-fac-pdf]');
    const lp = ultima(n0, 'facturas:pdf');
    doc = docCard(q);
    ok('Hacer el PDF · llama a la función facturas («pdf» con el documento, con la sesión en aal2) y queda «PDF 1 · el que vale», con enlace de pago (solo cuenta de banco) por $1,111.11, y «ver el PDF»',
      lp && JSON.stringify(lp.args) === JSON.stringify({ accion: 'pdf', documento: idA }) && /^Bearer /.test(lp.auth) && /PDF 1/.test(await doc.locator('#ct-fac-pdfs').textContent()) && /el que vale/.test(await doc.locator('#ct-fac-pdfs').textContent()) &&
      /con enlace de pago \(solo cuenta de banco\) por \$1,111\.11/.test(await doc.locator('#ct-fac-pdfs').textContent()) && /token=prueba/.test(await doc.locator('.ct-fac-enlace').getAttribute('href')), lp && JSON.stringify(lp.args));
    // Stripe no deja dejar el enlace solo por cuenta de banco: el error en llano y «Hacer el PDF sin enlace de pago»
    F.fnFalla = { estado: 502, cuerpo: { codigo: 'STRIPE_ACH', error: 'Stripe no dejó el enlace solo por cuenta de banco (prueba): no se imprimió ningún enlace.' } };
    await toca(q, '#ct-fac-doc [data-fac-pdf]');
    ok('Stripe no deja el enlace solo por cuenta de banco · el error en llano y «Hacer el PDF sin enlace de pago»', /no se imprimió ningún enlace/.test(await texto(q, '#ct-fac-doc .ct-fac-res')) && (await q.locator('#ct-fac-doc [data-fac-sinenlace]').count()) === 1);
    n0 = llamadas.length;
    await toca(q, '#ct-fac-doc [data-fac-sinenlace]');
    ok('…que pide el PDF con sin_enlace: true (PDF 2, «sin enlace de pago») y lo dice arriba', JSON.stringify(ultima(n0, 'facturas:pdf').args) === JSON.stringify({ accion: 'pdf', documento: idA, sin_enlace: true }) && /PDF 2/.test(await texto(q, '#ct-fac-pdfs')) && /sin enlace de pago/.test(await texto(q, '#ct-fac-pdfs')) && /lo pediste así/.test(await texto(q, '#ct-fac-doc')));
    // mandar por correo
    await toca(q, '#ct-fac-doc [data-fac-mandar]');
    const fm = q.locator('#ct-fac-doc .ct-form');
    ok('Mandar · la forma trae el correo del cliente, el asunto en inglés y dice que a Edgar le llega copia', (await fm.locator('[name="para"]').inputValue()) === 'zz.uno@c11-pruebas.invalid' && /^Invoice MXP-\d{4}-0001 from ZZ Electric C11 PRUEBA, Inc\.$/.test(await fm.locator('[name="asunto"]').inputValue()) && /A ti te llega copia/.test(await fm.textContent()));
    await fm.locator('[name="mensaje"]').fill('The rough-in inspection passed today.');
    n0 = llamadas.length;
    await fm.locator('button[type="submit"]').click(); await pintado(q);
    const lm = ultima(n0, 'facturas:enviar');
    ok('…llama a la función facturas («enviar» con para, asunto y el mensaje) y el envío queda: «Correo a zz.uno@…» con la copia a Edgar y el id de Resend', lm && lm.args.para === 'zz.uno@c11-pruebas.invalid' && lm.args.mensaje === 'The rough-in inspection passed today.' &&
      /Correo a zz\.uno@c11-pruebas\.invalid/.test(await texto(q, '#ct-fac-envios')) && /copia zz\.edgar@c11-pruebas\.invalid/.test(await texto(q, '#ct-fac-envios')) && /Resend re_c11_pantalla_1/.test(await texto(q, '#ct-fac-envios')) && /Reenviar por correo/.test(await texto(q, '#ct-fac-envios')), lm && JSON.stringify(lm.args));
    // el correo sale y no se apunta: «Apuntar el envío» con su id de Resend
    F.sinApuntar = true;
    await toca(q, '#ct-fac-doc [data-fac-mandar]');
    await q.locator('#ct-fac-doc .ct-form button[type="submit"]').click(); await pintado(q);
    ok('El correo salió y no se apuntó · el error lo dice y ofrece «Apuntar el envío» (no se vuelve a mandar)', /no quedó apuntado/.test(await texto(q, '#ct-fac-doc .ct-fac-res')) && (await q.locator('#ct-fac-doc [data-fac-apuntar]').count()) === 1);
    n0 = llamadas.length;
    await toca(q, '#ct-fac-doc [data-fac-apuntar]');
    const la = ultima(n0, 'fn_emision_envio');
    ok('…«Apuntar el envío» llama a fn_emision_envio con el id de Resend que dio la función (medio correo) y sale «Reenvío»', la && la.args.p_envio.resend_id === 're_c11_pantalla_2' && la.args.p_envio.medio === 'correo' && /Reenvío a zz\.uno@/.test(await texto(q, '#ct-fac-envios')) && !desde(n0).some(l => l.fn === 'facturas:enviar'), la && JSON.stringify(la.args));
    // en mano
    await toca(q, '#ct-fac-doc [data-fac-mano]');
    await q.locator('#ct-fac-doc .ct-form [name="para"]').fill('ZZ Recepción C11 PRUEBA');
    n0 = llamadas.length;
    await q.locator('#ct-fac-doc .ct-form button[type="submit"]').click(); await pintado(q);
    ok('Entregada en mano · fn_emision_envio({medio: en_mano, para}) y sale «En mano a …»', JSON.stringify(ultima(n0, 'fn_emision_envio').args.p_envio) === JSON.stringify({ medio: 'en_mano', para: 'ZZ Recepción C11 PRUEBA' }) && /En mano a ZZ Recepción C11 PRUEBA/.test(await texto(q, '#ct-fac-envios')));
    await foto(q, 'c11-3-pdf-y-envios');
    // ya entró un pago de $100.00: el PDF nuevo trae un enlace que cobra lo que el libro debe hoy ($1,011.11), y la vista (como el
    // PDF) dice en grande «Balance due today $1,011.11» —lo mismo que el enlace— y deja la factura como «Invoice amount due»
    const dP = F.docs.find(d => d.id === idA); dP.saldoC -= 10000;
    await toca(q, '#ct-fac-doc [data-fac-pdf]');
    let fxP = await texto(q, '#ct-fac-previa .ct-fx');
    ok('Un pago parcial y otro PDF · el enlace nuevo cobra $1,011.11 y la vista dice «Balance due today $1,011.11», «Invoice amount due $1,111.11» y «Pay $1,011.11 online…», sin otro «Amount due»',
      /con enlace de pago \(solo cuenta de banco\) por \$1,011\.11/.test(await texto(q, '#ct-fac-pdfs')) && /Balance due today\s*\$1,011\.11/.test(fxP) && /Invoice amount due\s*\$1,111\.11/.test(fxP) && /Pay \$1,011\.11 online by bank transfer \(ACH\)/.test(fxP) &&
      /payments already received are deducted/.test(fxP) && !/Amount due\s*\$/.test(fxP.replace(/Invoice amount due/g, '')), fxP.slice(-700));
    await foto(q, 'c11-3b-saldo-de-hoy');
    dP.saldoC += 10000;
    await toca(q, '#ct-fac-doc [data-fac-pdf]');
    fxP = await texto(q, '#ct-fac-previa .ct-fx');
    ok('…y con el pago deshecho, el PDF de después vuelve a «Amount due $1,111.11» (enlace por lo mismo que la factura)', /Amount due\s*\$1,111\.11/.test(fxP) && !/Balance due today/.test(fxP), fxP.slice(-500));
    // la lista
    await ve(q, 'facturas', { sub: 'facturas' });
    const filaA = q.locator(`.ct-fac-fila[data-doc="${idA}"]`);
    ok('La lista · la emitida con su número, obra y cliente, «Hito «…»», monto $1,234.57 con su retención, a pagar $1,111.11, «debe $1,111.11», PDF y «mandada a …» (3 envíos)',
      /MXP-\d{4}-0001/.test(await filaA.textContent()) && /C11 PRUEBA Oficina Uno · ZZ Cliente Uno/.test(await filaA.textContent()) && /\$1,234\.57/.test(await filaA.textContent()) && /retención \$123\.46/.test(await filaA.textContent()) &&
      /debe \$1,111\.11/.test(await filaA.textContent()) && /PDF/.test(await filaA.locator('[data-col="PDF y envío"]').textContent()) && /\(3 envíos\)/.test(await filaA.textContent()), await filaA.textContent());
    ok('…arriba la cuenta de la base (1 emitida · 0 borradores · la siguiente MXP-…-0002) y «Emitidas (1)»', /1 emitida · 0 borradores · la siguiente, MXP-\d{4}-0002/.test(await texto(q, '.ct-pag-sub')) && /Emitidas \(1\)/.test(await texto(q, '[data-fac-filtro="emitida"]')));

    // ---- por porcentaje: el % del contrato; y la retención de la obra ----
    await ve(q, 'facturas', { sub: 'obras' });
    await q.locator('.ct-fac-obra[data-obra="c11-prueba-a"] [data-fac-pct]').click();
    await q.locator('.ct-fac-obra[data-obra="c11-prueba-a"] .ct-form [name="porcentaje"]').fill('30');
    n0 = llamadas.length;
    await q.locator('.ct-fac-obra[data-obra="c11-prueba-a"] .ct-form button[type="submit"]').click(); await pintado(q);
    doc = docCard(q);
    ok('Por porcentaje · fn_emision_borrador({forma: porcentaje, proyecto_id, porcentaje: "30"}) y el borrador: 30 % del contrato ($18,500.55), $5,550.17 con su retención, y el aviso de la base que no frena (la obra tiene hitos)',
      JSON.stringify(ultima(n0, 'fn_emision_borrador').args) === JSON.stringify({ p: { forma: 'porcentaje', proyecto_id: 'c11-prueba-a', porcentaje: '30' } }) && /30 % del contrato \(\$18,500\.55\)/.test(await doc.textContent()) && /\$5,550\.17/.test(await doc.locator('.ct-kpis').textContent()) &&
      (await doc.locator('[data-aviso="obra_con_hitos"].warn').count()) === 1 && !(await doc.locator('[data-fac-emitir]').isDisabled()) && /Progress billing — 30% of contract amount \(\$18,500\.55\)/.test(await texto(q, '#ct-fac-previa')));
    const idP = F.docs[F.docs.length - 1].id;
    await toca(q, '#ct-fac-doc [data-fac-tirar]');
    n0 = llamadas.length;
    await q.locator('#ct-fac-doc .ct-form button[type="submit"]').click(); await pintado(q);
    ok('Tirar el borrador · pregunta, llama a fn_emision_descartar y vuelve a la lista sin él', JSON.stringify(ultima(n0, 'fn_emision_descartar').args) === JSON.stringify({ p_documento: idP }) && (await q.locator('#ct-fac-lista').count()) === 1 && !F.docs.some(d => d.id === idP));
    await ve(q, 'facturas', { sub: 'obras' });
    await q.locator('.ct-fac-obra[data-obra="c11-prueba-c"] [data-fac-ret]').click();
    await q.locator('.ct-fac-obra[data-obra="c11-prueba-c"] .ct-form [name="retencion_pct"]').fill('5');
    n0 = llamadas.length;
    await q.locator('.ct-fac-obra[data-obra="c11-prueba-c"] .ct-form button[type="submit"]').click(); await pintado(q);
    ok('La retención de la obra · fn_emision_obra({proyecto_id, retencion_pct: "5", nota: null}) y la obra dice «5 % (la de la obra)»', JSON.stringify(ultima(n0, 'fn_emision_obra').args) === JSON.stringify({ p: { proyecto_id: 'c11-prueba-c', retencion_pct: '5', nota: null } }) && /Retención: 5 %/.test(await texto(q, '.ct-fac-obra[data-obra="c11-prueba-c"] .ct-fac-ret')));

    // ---- T&M: dos líneas, una en español (la base lo frena hasta confirmarlo) ----
    await q.locator('.ct-fac-obra[data-obra="c11-prueba-b"] [data-fac-tm]').click();
    const ft = q.locator('.ct-fac-obra[data-obra="c11-prueba-b"] .ct-form form');
    await ft.locator('.ct-fac-linea').first().locator('[name="descripcion"]').fill('Electrician labor');
    await ft.locator('.ct-fac-linea').first().locator('[name="cantidad"]').fill('8');
    await ft.locator('.ct-fac-linea').first().locator('[name="precio"]').fill('$85.00');
    await ft.locator('[data-otra-linea]').click();
    const l2 = ft.locator('.ct-fac-linea').nth(1);
    await l2.locator('[name="descripcion"]').fill('Materiales de la obra'); await l2.locator('[name="tipo"]').selectOption('material'); await l2.locator('[name="cantidad"]').fill('1'); await l2.locator('[name="precio"]').fill('412.37');
    n0 = llamadas.length;
    await ft.locator('button[type="submit"]').click(); await pintado(q);
    lb = ultima(n0, 'fn_emision_borrador');
    doc = docCard(q);
    ok('T&M · las líneas van como TEXTO, sin «$» (la base valida y calcula): 8 hr × 85.00 y 1 × 412.37; el borrador suma $1,092.37 (lo dice la base)',
      lb && JSON.stringify(lb.args.p.lineas) === JSON.stringify([{ descripcion: 'Electrician labor', tipo: 'horas', cantidad: '8', precio: '85.00', unidad: 'hr' }, { descripcion: 'Materiales de la obra', tipo: 'material', cantidad: '1', precio: '412.37' }]) && /\$1,092\.37/.test(await doc.locator('.ct-kpis').textContent()), lb && JSON.stringify(lb.args));
    ok('…la vista previa T&M en inglés (QTY / RATE / AMOUNT: «8 hr», $85.00, $680.00) y «Time & materials»', /Time & materials/.test(await texto(q, '#ct-fac-previa')) && /8 hr/.test(await texto(q, '#ct-fac-previa .ct-fx-lineas')) && /\$85\.00/.test(await texto(q, '#ct-fac-previa .ct-fx-lineas')) && /\$680\.00/.test(await texto(q, '#ct-fac-previa .ct-fx-lineas')));
    ok('…el texto que parece español frena con el aviso de la base, pero «Emitir» se deja tocar para confirmarlo', (await doc.locator('[data-aviso="en_espanol"].bad').count()) === 1 && !(await doc.locator('[data-fac-emitir]').isDisabled()));
    await foto(q, 'c11-4-tm-espanol');
    await toca(q, '#ct-fac-doc [data-fac-emitir]');
    ok('…y la confirmación pide además «Lo que parece español está bien así»', (await q.locator('#ct-fac-doc .ct-form [name="idioma"]').count()) === 1);
    await q.locator('#ct-fac-doc .ct-form [name="si"]').check(); await q.locator('#ct-fac-doc .ct-form [name="idioma"]').check();
    n0 = llamadas.length;
    await q.locator('#ct-fac-doc .ct-form button[type="submit"]').click(); await pintado(q);
    ok('…con las dos casillas: p_opciones = {idioma_revisado: true} y se emite la MXP-…-0002', JSON.stringify(ultima(n0, 'fn_emision_emitir').args.p_opciones) === '{"idioma_revisado":true}' && /MXP-\d{4}-0002/.test(await texto(q, '#ct-fac-doc h2')));
    const idT = F.docs.find(d => d.forma === 'tm').id;
    await toca(q, '#ct-fac-doc [data-fac-pdf]');

    // ---- anular con nota de crédito, y desactivar su enlace ----
    await toca(q, '#ct-fac-doc [data-fac-anular]');
    n0 = llamadas.length;
    await q.locator('#ct-fac-doc .ct-form [name="motivo"]').fill('x');
    await q.locator('#ct-fac-doc .ct-form button[type="submit"]').click(); await q.waitForTimeout(150);
    ok('Anular · dice que no se borra (nota de crédito) y pide el motivo (tres letras)', /no se borra; se hace su nota de crédito/.test(await texto(q, '#ct-fac-doc .ct-form')) && /al menos tres letras/.test(await texto(q, '#ct-fac-doc .ct-form')) && !ultima(n0, 'fn_emision_anular'));
    await q.locator('#ct-fac-doc .ct-form [name="motivo"]').fill('ZZ prueba: se facturó a la obra equivocada');
    await q.locator('#ct-fac-doc .ct-form button[type="submit"]').click(); await pintado(q);
    doc = docCard(q);
    ok('…fn_emision_anular(documento, motivo, null) y la factura sale «anulada» con su nota de crédito, su motivo y lo que sigue (avisar al cliente; la buena, con número nuevo)',
      JSON.stringify(ultima(n0, 'fn_emision_anular').args) === JSON.stringify({ p_documento: idT, p_motivo: 'ZZ prueba: se facturó a la obra equivocada', p_fecha: null }) && /anulada/.test(await doc.locator('.ct-cab .ct-pill').textContent()) &&
      /nota de crédito NC-2026-0001/.test(await doc.textContent()) && /se facturó a la obra equivocada/.test(await doc.textContent()) && /La buena es un borrador nuevo, con número nuevo/.test(await doc.textContent()) && !(await doc.locator('[data-fac-pdf], [data-fac-mandar], [data-fac-anular]').count()));
    ok('…su enlace de pago seguía activo: lo dice y ofrece «Desactivar el enlace»', (await doc.locator('[data-fac-baja]').count()) === 1);
    n0 = llamadas.length;
    await toca(q, '#ct-fac-doc [data-fac-baja]');
    const ld = ultima(n0, 'stripe:desactivar_enlace');
    ok('…que llama a la función stripe (desactivar_enlace con el enlace y el motivo) y desaparece', ld && ld.args.enlace === F.enlaces.find(e => e.doc === idT).id && /se anuló/.test(ld.args.motivo) && !(await q.locator('#ct-fac-doc [data-fac-baja]').count()), ld && JSON.stringify(ld.args));
    await foto(q, 'c11-5-anulada');

    // ---- la del contratista desde la ficha (el contrato de MXP_CONTA.facturar): el borrador de su hito, con su aviso ----
    await q.evaluate(() => window.MXP_CONTA.facturar({ hito: -1110000005, proyecto: 'c11-prueba-c', obra: 'C11 PRUEBA Nave Tres' }));
    n0 = llamadas.length;
    await ve(q, 'facturas');
    ok('MXP_CONTA.facturar({hito}) + ir("facturas") (lo que hace el 🧾 desde el corte) abre el borrador de ese hito, a nombre del contratista y con su retención (5 %)', JSON.stringify(ultima(n0, 'fn_emision_borrador').args) === JSON.stringify({ p: { forma: 'hito', hito_id: -1110000005 } }) &&
      /C11 PRUEBA Nave Tres/.test(await texto(q, '#ct-fac-doc h2')) && /ZZ Contractor C11 PRUEBA, LLC \(el contratista\)/.test(await texto(q, '#ct-fac-doc')) && /5 % · la de la obra/.test(await texto(q, '#ct-fac-doc .ct-kpis')) && /Attn: ZZ Project Manager/.test(await texto(q, '#ct-fac-previa')));
    const idC = F.docs.find(d => d.hito_id === -1110000005).id;
    await q.evaluate(() => window.MXP_CONTA.facturar({ hito: -1110000005 }));
    await ve(q, 'facturas');
    ok('…otra vez el mismo hito: el MISMO borrador (la base no hace otro)', F.docs.filter(d => d.hito_id === -1110000005).length === 1 && (await q.locator('#ct-fac-doc').getAttribute('data-doc')) === idC);
    await q.evaluate(() => window.MXP_CONTA.facturar({ hito: -1110000001 }));
    await ve(q, 'facturas');
    ok('…un hito que ya se facturó: no se prepara nada y lo dice la base («ya se facturó: factura MXP-…-0001»), con «Ver la obra»', /ya se facturó: factura MXP-\d{4}-0001/.test(await texto(q, '#ct-fac-pedido')) && (await q.locator('#ct-fac-a-obras').count()) === 1);

    // ---- el rojo del control y sin la función ----
    F.ctlRojo = true;
    await ve(q, 'facturas');
    ok('Falla ruidosa · un cuadre del control en rojo: la página no pinta ninguna cifra y dice cuál y por qué', /La facturación no cuadra/.test(await texto(q, '#ct-fac-cuerpo .ct-rojo h2')) && /su asiento lleva \$1,111\.11 por cobrar/.test(await texto(q, '#ct-fac-cuerpo .ct-rojo')) && !(await q.locator('#ct-fac-lista').count()));
    F.ctlRojo = false; F.avisoSinPdf = true;
    await ve(q, 'facturas', { sub: 'facturas' });
    ok('…un aviso del control (sin PDF) sale arriba, en ámbar, y la lista se pinta igual', /ninguna emitida hace más de 2 día\(s\) sin su PDF/i.test(await texto(q, '#ct-fac-arriba')) && (await q.locator('#ct-fac-lista').count()) === 1);
    F.avisoSinPdf = false;
    estado.c11Fn = false;
    await ve(q, 'facturas', { doc: idA });
    await toca(q, '#ct-fac-doc [data-fac-pdf]');
    ok('Sin la función «facturas» desplegada · lo dice en llano (y que se puede entregar en mano)', /no está desplegada/.test(await texto(q, '#ct-fac-doc .ct-fac-res')) && /en mano/.test(await texto(q, '#ct-fac-doc .ct-fac-res')));
    estado.c11Fn = true;
    await cx.close();

    // ---- sin el código del teléfono: se ve todo, pero emitir, el PDF, mandar y anular lo piden ----
    ({ cx, q } = await abrirCtx(1280, false));
    const bS = C11_FN.fn_emision_borrador({ p: { forma: 'hito', hito_id: -1110000002 } });
    await ve(q, 'facturas', { doc: bS.documento.id });
    await toca(q, '#ct-fac-doc [data-fac-emitir]');
    ok('Sin el código del teléfono · el borrador se ve, pero «Emitir» lo pide (no abre la confirmación)', /pide el código del teléfono/.test(await texto(q, '#ct-fac-doc .ct-form')) && !(await q.locator('#ct-fac-doc .ct-form [name="si"]').count()));
    n0 = llamadas.length;
    await ve(q, 'facturas', { doc: idA });
    await toca(q, '#ct-fac-doc [data-fac-pdf]');
    ok('…y el PDF tampoco llama a la función: lo dice', /activa el código del teléfono/.test(await texto(q, '#ct-fac-doc .ct-fac-res')) && !desde(n0).some(l => /^facturas:/.test(l.fn)));
    await cx.close();

    // ---- el 🧾 de un hito en la ficha de la obra (js/app.js): antes del corte, a QuickBooks; desde el corte, aquí ----
    estado.c11App = true;
    for (const [corte, va] of [['2027-01-01', 'qb'], [HOY, 'app']]) {
      F.config.corte = corte;
      ({ cx, q } = await abrirCtx(390, true));
      await q.evaluate(() => { window.confirm = () => true; });
      n0 = llamadas.length;
      // la ficha de la obra (la de la app: proyectos e hitos de la base de mentira): Proyectos → la obra → «Abrir la ficha completa» → su pestaña de dinero
      await q.locator('#nav-abajo [data-nav="proyectos"]').evaluate(x => x.click()); await q.waitForTimeout(400);
      await q.locator('#proy-chips .chipb[data-obra="c11-prueba-a"]').evaluate(x => x.click()).catch(() => {}); await q.waitForTimeout(300);
      await q.locator('#proy-ficha').evaluate(x => x.click()).catch(() => {}); await q.waitForTimeout(400);
      const btn = q.locator('#detalle .hito-facturar[data-hito="-1110000002"]');
      if (!(await btn.count())) { await q.locator('#detalle .ficha-tab[data-pestana="dinero"]').evaluate(x => x.click()).catch(() => {}); await q.waitForTimeout(300); }
      if (!(await btn.count())) { ok(`El 🧾 de la ficha (${va === 'qb' ? 'antes' : 'desde'} del corte) · la prueba no llegó al hito en la ficha de la obra`, false, await q.evaluate(() => (document.querySelector('#detalle') || {}).textContent || '').then(t => t.slice(0, 300))); await cx.close(); continue; }
      await btn.evaluate(x => x.click()); await q.waitForTimeout(500);
      // (QuickBooks pregunta antes de crear la factura: se acepta la ventana de la app)
      if (va === 'qb') { await q.locator('dialog[open] button[value="si"]').click({ timeout: 3000 }).catch(() => {}); await q.waitForTimeout(800); }
      if (va === 'qb') {
        ok('El 🧾 de la ficha antes del corte · lee el camino (v_emision_estado) y va a QuickBooks como siempre (la función qb), sin abrir Contabilidad', lecturas.some(l => l.startsWith('v_emision_estado?select=camino')) && desde(n0).some(l => l.fn === 'qb:factura') && !desde(n0).some(l => l.fn === 'fn_emision_borrador'), desde(n0).map(l => l.fn).join(','));
      } else {
        await pintado(q);
        ok('El 🧾 de la ficha desde el corte · no llama a qb: abre Contabilidad → Facturas con el borrador de ese hito (fn_emision_borrador con su hito_id)', !desde(n0).some(l => l.fn === 'qb:factura') && JSON.stringify((ultima(n0, 'fn_emision_borrador') || {}).args) === JSON.stringify({ p: { forma: 'hito', hito_id: -1110000002 } }) &&
          (await q.locator('#ct-fac-doc').count()) === 1 && /C11 PRUEBA Trim-out/.test(await texto(q, '#ct-fac-doc')), desde(n0).map(l => l.fn).join(','));
      }
      await cx.close();
    }
    // ---- el 🧾 ANTE LA DUDA: la base no contesta bien (un 500 en v_emision_estado). Sin un corte ya visto en este teléfono,
    // no se factura (ni QuickBooks ni la app); con un corte visto que todavía no llega, QuickBooks como siempre; con uno visto
    // que ya pasó, tampoco se factura. Y sin c11 (la vista no existe, 404), QuickBooks como antes de pegarla ----
    {
      ({ cx, q } = await abrirCtx(390, true));
      await q.evaluate(() => { window.confirm = () => true; });
      const tocar = async () => {
        await q.evaluate(() => { const t = document.getElementById('toast'); if (t) { t.textContent = ''; t.hidden = true; } });
        await q.locator('#nav-abajo [data-nav="proyectos"]').evaluate(x => x.click()); await q.waitForTimeout(400);
        await q.locator('#proy-chips .chipb[data-obra="c11-prueba-a"]').evaluate(x => x.click()).catch(() => {}); await q.waitForTimeout(300);
        await q.locator('#proy-ficha').evaluate(x => x.click()).catch(() => {}); await q.waitForTimeout(400);
        const btn = q.locator('#detalle .hito-facturar[data-hito="-1110000002"]');
        if (!(await btn.count())) { await q.locator('#detalle .ficha-tab[data-pestana="dinero"]').evaluate(x => x.click()).catch(() => {}); await q.waitForTimeout(300); }
        if (!(await btn.count())) return null;
        await btn.evaluate(x => x.click()); await q.waitForTimeout(500);
        await q.locator('dialog[open] button[value="si"]').click({ timeout: 1500 }).catch(() => {}); await q.waitForTimeout(600);
        return await q.evaluate(() => { const t = document.getElementById('toast'); return t && !t.hidden ? t.textContent : ''; });
      };
      const corteVisto = () => q.evaluate(() => { try { return localStorage.getItem('mxp_factura_corte'); } catch { return 'sin almacenamiento'; } });
      const fue = () => { const d = desde(n0); return d.some(l => l.fn === 'qb:factura') ? 'qb' : d.some(l => l.fn === 'fn_emision_borrador') ? 'app' : 'nada'; };
      estado.c11EstadoFalla = true; F.config.corte = '2027-01-01'; n0 = llamadas.length;
      let t = await tocar();
      ok('El 🧾 ante la duda · v_emision_estado contesta 500 y este teléfono no ha visto ningún corte: no se factura (ni QuickBooks ni la app) y lo dice', t !== null && fue() === 'nada' && /no se facturó nada/.test(t) && (await corteVisto()) === null, `${fue()} · ${t}`);
      estado.c11EstadoFalla = false; n0 = llamadas.length;
      t = await tocar();
      ok('…la base contesta: antes del corte va a QuickBooks y el teléfono apunta el corte que vio (2027-01-01)', fue() === 'qb' && (await corteVisto()) === '2027-01-01', `${fue()} · ${await corteVisto()}`);
      estado.c11EstadoFalla = true; n0 = llamadas.length;
      t = await tocar();
      ok('…otro 500 con el corte visto todavía por llegar: QuickBooks como siempre (antes del corte no hay duda)', fue() === 'qb', `${fue()} · ${t}`);
      estado.c11EstadoFalla = false; F.config.corte = HOY; n0 = llamadas.length;
      t = await tocar();
      await pintado(q);
      ok('…el corte movido a hoy: el 🧾 abre el borrador en Contabilidad y el teléfono apunta el corte nuevo', fue() === 'app' && (await corteVisto()) === HOY, `${fue()} · ${await corteVisto()}`);
      estado.c11EstadoFalla = true; n0 = llamadas.length;
      t = await tocar();
      ok('…otro 500 con el corte visto ya pasado: NO va a QuickBooks (quedaría fuera de la serie): no se factura y lo dice', fue() === 'nada' && /no se facturó nada/.test(t), `${fue()} · ${t}`);
      estado.c11EstadoFalla = false; estado.c11 = false; n0 = llamadas.length;
      t = await tocar();
      ok('…sin c11 en la base (la vista no existe: 404): QuickBooks, como antes de pegarla', fue() === 'qb', `${fue()} · ${t}`);
      estado.c11 = true;
      await cx.close();
    }
    estado.c11App = false;

    // ---- el teléfono (390), el iPad (820) y la computadora (1280): sin desplazamiento lateral ----
    for (const w of [390, 820, 1280]) {
      ({ cx, q } = await abrirCtx(w, true));
      const mal = [];
      const mide = async nombre => { const m = await q.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: window.innerWidth, rojo: !!document.querySelector('#conta-raiz .ct-rojo') })); if (m.sw > m.iw + 1 || m.rojo) mal.push(`${nombre}: ${m.sw} > ${m.iw}${m.rojo ? ' (rojo)' : ''}`); await foto(q, `c11-${w}-${nombre}`); };
      await ve(q, 'facturas', { sub: 'facturas' }); await mide('lista');
      await ve(q, 'facturas', { sub: 'obras' }); await mide('obras');
      await q.locator('.ct-fac-obra[data-obra="c11-prueba-b"] [data-fac-tm]').click(); await q.waitForTimeout(150); await mide('obras-tm');
      await ve(q, 'facturas', { sub: 'ajustes' }); await mide('ajustes');
      await ve(q, 'facturas', { doc: F.docs.find(d => d.estado === 'borrador').id }); await mide('borrador');
      await ve(q, 'facturas', { doc: idA }); await mide('emitida');
      await toca(q, '#ct-fac-doc [data-fac-mandar]'); await mide('mandar');
      await ve(q, 'facturas', { doc: idT }); await mide('anulada');
      if (w === 390) {
        const fx = await q.evaluate(() => { const a = document.querySelector('#ct-fac-previa .ct-fx'), r = a.getBoundingClientRect(); return { der: Math.round(r.right), iw: window.innerWidth, sw: a.scrollWidth, cw: a.clientWidth }; });
        ok('Teléfono · la factura en inglés cabe en 390 px (las tres cajas apiladas, la tabla sin salirse)', fx.der <= fx.iw && fx.sw <= fx.cw + 1, JSON.stringify(fx));
        const tv = await q.evaluate(() => { const t = document.querySelector('.ct-tabs'), a = t.querySelector('.ct-tab[aria-current="page"]'), T = t.getBoundingClientRect(), A = a.getBoundingClientRect(); return { pag: a.dataset.pag, izq: Math.round(A.left - T.left), der: Math.round(T.right - A.right) }; });
        ok('Teléfono · la pestaña «Facturas» se ve entera dentro de la tira de pestañas', tv.pag === 'facturas' && tv.izq >= 14 && tv.der >= 14, JSON.stringify(tv));
      }
      ok(`Facturas · ${w} px: la lista, por facturar (con la forma T&M), ajustes, el borrador, la emitida (y mandar) y la anulada, sin desplazamiento lateral ni rojos`, !mal.length, mal.join(' | '));
      await cx.close();
    }

    // ---- sin c11: lo dice en llano ----
    estado.c11 = false;
    ({ cx, q } = await abrirCtx(1280, true));
    await ve(q, 'facturas');
    ok('Sin c11 · «Facturas» dice en llano que falta c11-emision.sql (y que hasta entonces se factura por QuickBooks), con «Reintentar»', /Falta la facturación en la base/.test(await texto(q, '#ct-fac-cuerpo .ct-rojo h2')) && /c11-emision\.sql/.test(await texto(q, '#ct-fac-cuerpo .ct-rojo')) && /QuickBooks/.test(await texto(q, '#ct-fac-cuerpo .ct-rojo')) && (await q.locator('#ct-reintentar').count()) === 1);
    await cx.close();
    conCodigo(false);
  }

  // ---- El WIP (c12, fase 10): la página «WIP» (el mes que toca y lo que le falta, lo de antes del libro de la obra que ya
  // andaba —el desglose de dónde sale cada número, confirmarlo—, revisar cada obra —un monto mal escrito, la nota que pide la
  // base, el número nuevo—, el resumen con los totales de la base, el schedule con su total, POSTEAR con el código del teléfono
  // diciendo qué va por obra y que se deshace solo el día 1, «ya no está al día» y rehacerlo, deshacer con su motivo, otro mes
  // con «Sigue igual» en un toque, la propuesta que cambió en otra pestaña (MX008), terminada, la obra pasada de su estimado, un
  // mes cerrado que solo se lee), «Obras» (cuáles llevan WIP, la marca con su nota, lo de antes con otros números), «Historial»,
  // «Ajustes» (desde qué mes lo exige el cierre), la misma revisión dentro de «Cierre del mes» (las filas 174 a 177 en su
  // lista con su botón al WIP del mes, revisar y postear desde ahí), la falla ruidosa (un cuadre en rojo; el resumen y el
  // schedule contando distinto), sin c12, el equipo (42501), sin el código del teléfono, y 390/820/1280 sin desplazamiento lateral ----
  {
    estado.c12 = true; estado.c12NoDueno = false; wReset();
    const conCodigo = si => { estado.mfaFactores = si ? [{ id: 'f-1', friendly_name: 'Teléfono de Edgar', factor_type: 'totp', status: 'verified' }] : []; estado.sesionAal = si ? 'aal2' : undefined; };
    const abrirCtx = async (w, codigo) => {
      conCodigo(codigo);
      const cx = await b.newContext({ viewport: { width: w, height: w < 700 ? 844 : 1000 }, deviceScaleFactor: w < 1024 ? 2 : 1, isMobile: w < 1024, hasTouch: w < 1024, serviceWorkers: 'block' });
      await simular(cx, 'dueno');
      const q = await cx.newPage(); q.on('pageerror', e => errs.push(`c12 ${w}: ` + String(e).slice(0, 160)));
      await q.goto('http://localhost:8873/index.html'); await q.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await q.waitForTimeout(800);
      await q.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
      await q.locator('#btn-conta').evaluate(x => x.click()); await q.waitForSelector('#conta-raiz .ct-ficha', { timeout: 8000 }); await pintado(q);
      return { cx, q };
    };
    const ve = async (q, k, op) => { await q.evaluate(([k, o]) => window.MXP_CONTA.ir(k, o || {}), [k, op || null]); await pintado(q); };
    const ultima = (n0, fn) => desde(n0).filter(l => l.fn === fn).pop();
    const toca = async (q, sel) => { await q.locator(sel).first().evaluate(x => x.click()); await pintado(q); };
    const ob = (q, id) => q.locator(`#ct-wip-rev [data-wip-obra="${id}"]`);
    // el texto como se lee (innerText: las celdas y los bloques separados; lo plegado no cuenta), en una línea
    const txt = async loc => (await loc.evaluateAll(es => es.map(x => x.innerText).join(' '))).replace(/\s+/g, ' ').trim();
    const enviar = async (q, form) => { await form.locator('button[type="submit"]').evaluate(x => x.click()); await pintado(q); };
    let { cx, q } = await abrirCtx(1280, true);

    // ---- el mes que toca, sin nada revisado ----
    let n0 = llamadas.length;
    await ve(q, 'wip');
    let r0 = ultima(n0, 'fn_wip_resumen'), c0 = ultima(n0, 'fn_wip_control');
    ok('WIP · está en el menú entre «Costo por obra» y «Cierre del mes» (pestaña y lateral) y la página pide fn_wip_resumen sin mes (el que toca), v_wip_schedule FILTRADA por ese mes y fn_wip_control del mes antes de pintar',
      /"obras","wip","cierre"/.test(JSON.stringify(await q.locator('.ct-tab').evaluateAll(bs => bs.map(x => x.dataset.pag)))) && (await q.locator('#lateral [data-lat="conta-wip"]').count()) === 1 && (await titulo2(q)) === 'WIP (obra en curso)' &&
      r0 && JSON.stringify(r0.args) === '{"p_periodo":null}' && lecturas.some(l => /^v_wip_schedule\?select=\*&periodo=eq\.2026-10/.test(l)) && c0 && JSON.stringify(c0.args) === '{"p_periodo":"2026-10"}', r0 && JSON.stringify(r0.args));
    let res = await txt(q.locator('#ct-wip-res'));
    ok('El mes que toca (Octubre de 2026): en llano cuántas obras y qué les falta, la nota de la base, «nada que postear», desde qué mes lo exige el cierre, y sin cifras (ninguna obra lista)',
      /Octubre de 2026/.test(res) && /4 obras de precio fijo en el WIP: 4 por revisar, 1 sin lo de antes confirmado\. El cierre lo exige desde noviembre de 2026\./.test(res) && /4 obra\(s\) no entran todavía: 4 por revisar y 1 sin lo de antes del libro confirmado\./.test(res) &&
      /nada que postear/.test(res) && /En octubre de 2026 hoy no hay nada que ajustar\./.test(res) && (await q.locator('#ct-wip-res .ct-kpi').count()) === 0 && /Ninguna obra lista todavía/.test(res), res);
    let tA = await txt(ob(q, 'c12-prueba-a')), tD = await txt(ob(q, 'c12-prueba-d'));
    ok('La revisión de octubre: las 4 obras de precio fijo (la de servicio no sale), cada una con lo que lleva gastado y lo que le falta; sin propuesta, «Poner su costo estimado» con la nota de la base; la que ya andaba, «Lo de antes del libro» con su porqué',
      (await q.locator('#ct-wip-rev [data-wip-obra]').count()) === 4 && !(await q.locator('[data-wip-obra="c12-prueba-s"]').count()) && /Lleva \$3,000\.00 en el libro · sin costo estimado todavía/.test(tA) && /falta revisar/.test(tA) &&
      (await ob(q, 'c12-prueba-a').locator('[data-wip-otro]').textContent()) === 'Poner su costo estimado' && /Sin propuesta\. No hay estimado: faltan las horas estimadas y el presupuesto de material\./.test(tA) &&
      (await ob(q, 'c12-prueba-d').locator('[data-wip-antes]').count()) === 1 && /Lleva \$320\.00 en el libro y lo de antes del libro, sin confirmar/.test(tD) && /falta revisar · falta lo de antes/.test(tD) &&
      /Ya andaba antes del libro \(tiene de antes: facturas, horas, tickets\): falta confirmar su costo y lo facturado de antes; hasta entonces no entra en el ajuste\./.test(tD), tA + ' || ' + tD);
    ok('…y los avisos de la base que no frenan van abajo (la obra que ya andaba sin lo de antes)', /Obras que ya andaban sin lo de antes confirmado: 1 obra\(s\) ya andaban antes del libro/.test(await txt(q.locator('#ct-wip-avisos'))));
    await foto(q, 'c12-0-mes-sin-revisar');

    // ---- lo de antes del libro de D: el desglose y confirmarlo ----
    n0 = llamadas.length;
    await ob(q, 'c12-prueba-d').locator('[data-wip-antes]').click(); await q.waitForSelector('[data-wip-obra="c12-prueba-d"] .ct-wip-antes', { timeout: 5000 });
    const ant = await txt(ob(q, 'c12-prueba-d').locator('.ct-wip-antes'));
    ok('Lo de antes del libro · fn_wip_antes_propuesta({p_proyecto}) y de dónde sale cada número: 1 ticket $310.00, 0 trabajos externos, 16 h a la tarifa de hoy $420.00 → costo $730.00; 1 factura $1,500.00 → facturado $1,500.00; con las notas de la base',
      JSON.stringify((ultima(n0, 'fn_wip_antes_propuesta') || {}).args) === '{"p_proyecto":"c12-prueba-d"}' && /hasta el 30 sep 2026 \(el libro empieza el 1 oct 2026\)/.test(ant) && /Tickets · 1 ticket \$310\.00/.test(ant) && /Trabajos externos · 0 \$0\.00/.test(ant) &&
      /Horas de la cuadrilla · 16 h a la tarifa de hoy \$420\.00/.test(ant) && /Costo de antes \$730\.00/.test(ant) && /Facturas · 1 factura \$1,500\.00/.test(ant) && /Facturado antes \$1,500\.00/.test(ant) &&
      /tarifa de HOY de «Costos del equipo»/.test(ant) && /QuickBooks al 30 de septiembre/.test(ant) && /Confirmar: costo \$730\.00 y facturado \$1,500\.00/.test(ant), ant);
    await foto(q, 'c12-1-lo-de-antes');
    await ob(q, 'c12-prueba-d').locator('[data-antes-si]').click(); await pintado(q);
    let la = ultima(n0, 'fn_wip_antes');
    tD = await txt(ob(q, 'c12-prueba-d'));
    ok('…«Confirmar» manda los números de la propuesta como texto: fn_wip_antes({p_proyecto, p: {costo: "730.00", facturado: "1500.00"}}); arriba la nota de la base, y D ya solo pide su revisión (lleva $320.00 en el libro y $730.00 de antes)',
      la && JSON.stringify(la.args) === JSON.stringify({ p_proyecto: 'c12-prueba-d', p: { costo: '730.00', facturado: '1500.00' } }) && /Confirmado lo de antes del libro de «C12 PRUEBA Obra D»: costo \$730\.00 y facturado \$1,500\.00\./.test(await txt(q.locator('.ct-wip-nota'))) &&
      !(await ob(q, 'c12-prueba-d').locator('[data-wip-antes]').count()) && /Lleva \$320\.00 en el libro y \$730\.00 de antes del libro/.test(tD), la && JSON.stringify(la.args));

    // ---- revisar A: un monto mal escrito, menos de lo que lleva sin nota (la base), y su número ----
    await ob(q, 'c12-prueba-a').locator('[data-wip-otro]').click();
    let fA = ob(q, 'c12-prueba-a').locator('.ct-form form');
    await fA.locator('[name="costo"]').fill('abc'); await fA.locator('button[type="submit"]').click(); await q.waitForTimeout(150);
    ok('Revisar · la forma pide el costo TOTAL estimado (desde el inicio hasta terminarla); un monto mal escrito no se manda', !ultima(n0, 'fn_wip_revisar') && /costo TOTAL estimado de «C12 PRUEBA Obra A» en octubre de 2026/.test(await txt(fA)) &&
      /con dos decimales como mucho/.test(await txt(ob(q, 'c12-prueba-a').locator('.ct-form'))));
    await fA.locator('[name="costo"]').fill('2,500'); await enviar(q, fA);
    let lr = ultima(n0, 'fn_wip_revisar');
    ok('…menos de lo que ya lleva y sin nota: lo manda como texto («2500») y la base lo frena (22023) con su texto, sin revisar nada',
      lr && JSON.stringify(lr.args) === JSON.stringify({ p_proyecto: 'c12-prueba-a', p_periodo: '2026-10', p: { costo_estimado: '2500' } }) && !W.rev.length &&
      /El costo estimado \(\$2,500\.00\) es menor que lo que «C12 PRUEBA Obra A» ya lleva al 31-oct-2026 \(\$3,000\.00\): daría 120 % de avance\. Súbelo, o deja escrito por qué en la nota\./.test(await txt(ob(q, 'c12-prueba-a').locator('.ct-form'))), lr && JSON.stringify(lr.args));
    await fA.locator('[name="costo"]').fill('6,000.00'); await enviar(q, fA);
    lr = ultima(n0, 'fn_wip_revisar'); tA = await txt(ob(q, 'c12-prueba-a'));
    ok('…con $6,000.00: fn_wip_revisar({p_proyecto, p_periodo: "2026-10", p: {costo_estimado: "6000.00"}}) y A queda revisada: lleva $3,000.00 · costo total estimado $6,000.00 · 50 % hecho; ganado $5,000.00, facturado $2,000.00 → vas $3,000.00 por detrás',
      lr && JSON.stringify(lr.args) === JSON.stringify({ p_proyecto: 'c12-prueba-a', p_periodo: '2026-10', p: { costo_estimado: '6000.00' } }) && /revisada/.test(tA) && /Lleva \$3,000\.00 gastados · costo total estimado \$6,000\.00 · 50 % hecho/.test(tA) &&
      /Precio \$10,000\.00 · ganado \$5,000\.00 · facturado \$2,000\.00 → vas \$3,000\.00 por detrás: hecho y todavía sin facturar/.test(tA) && /un número a mano/.test(tA) && (await ob(q, 'c12-prueba-a').locator('[data-wip-otro]').textContent()) === 'Cambiar la revisión', tA);
    const revisa = async (id, costo, nota) => { await ob(q, id).locator('[data-wip-otro]').click(); const f = ob(q, id).locator('.ct-form form'); await f.locator('[name="costo"]').fill(costo); if (nota) await f.locator('[name="nota"]').fill(nota); await enviar(q, f); };
    await revisa('c12-prueba-b', '10000', 'ZZ: el bid'); await revisa('c12-prueba-c', '11000', 'ZZ: subió el material'); await revisa('c12-prueba-d', '12000', 'ZZ: estimado de prueba');
    const tC = await txt(ob(q, 'c12-prueba-c'));
    ok('B, C y D revisadas con su nota · C (costo estimado sobre el precio) se marca «con pérdida» con el aviso de la base; B «vas $4,000.00 por delante»',
      W.rev.length === 4 && /con pérdida/.test(tC) && /Va con pérdida: el costo estimado \(\$11,000\.00\) pasa del precio \(\$10,000\.00\) por \$1,000\.00\. De esa pérdida, \$500\.00 ya está en su resultado por el avance y \$500\.00 se provisiona este mes/.test(tC) &&
      /vas \$4,000\.00 por delante: facturado de más/.test(await txt(ob(q, 'c12-prueba-b'))) && /«ZZ: subió el material»/.test(tC), tC);
    res = await txt(q.locator('#ct-wip-res'));
    ok('El resumen con los totales DE LA BASE (la pantalla no suma): precio $58,500.00, costo a la fecha $11,550.00 de $39,000.00, ganado $15,618.75 (26.7 % hecho), facturado $11,500.00; por detrás $8,118.75 (3 obras · 1200), por delante $4,000.00 (1 obra · 2400), la pérdida $1,000.00 (se provisionan $500.00) y «Postear el ajuste de WIP»',
      /Precio de los contratos \$58,500\.00 4 obras listas/.test(res) && /Costo a la fecha \$11,550\.00 de \$39,000\.00 estimados/.test(res) && /Ganado \$15,618\.75 26\.7 % hecho/.test(res) && /Facturado \$11,500\.00/.test(res) &&
      /Vas por detrás \(hecho y sin facturar\) \$8,118\.75 3 obras · va a 1200/.test(res) && /Vas por delante \(facturado de más\) \$4,000\.00 1 obra · va a 2400/.test(res) && /Pérdida de las obras que pierden \$1,000\.00 este mes se provisionan \$500\.00/.test(res) &&
      /sin postear/.test(res) && (await q.locator('#ct-wip-posteo [data-wip-postear]').textContent()) === 'Postear el ajuste de WIP', res);
    const sch = await q.locator('#ct-wip-sch > .ct-ob-tabla-env tbody tr').evaluateAll(trs => trs.map(t => t.innerText.replace(/\s+/g, ' ').trim()));
    ok('El schedule (formato de la afianzadora): una fila por obra —precio, costo estimado, costo a la fecha, % hecho, ganado, facturado y de qué lado va— y el total de la base',
      sch.length === 5 && /C12 PRUEBA Obra A.*\$10,000\.00 \$6,000\.00 \$3,000\.00 50 % \$5,000\.00 \$2,000\.00 \$3,000\.00 por detrás/.test(sch[0]) && /C12 PRUEBA Obra B.*\$4,000\.00 por delante/.test(sch[1]) && /C12 PRUEBA Obra C.*pierde \$1,000\.00/.test(sch[2]) &&
      /C12 PRUEBA Obra D.*\$18,500\.00 \$12,000\.00 \$1,050\.00 8\.75 % \$1,618\.75 \$1,500\.00 \$118\.75 por detrás/.test(sch[3]) && /^Total · 4 obras en el ajuste \$58,500\.00 \$39,000\.00 \$11,550\.00 26\.7 % \$15,618\.75 \$11,500\.00 \$8,118\.75 por detrás \$4,000\.00 por delante/.test(sch[4]), sch.join(' | '));
    ok('…y plegado, «Lo que iría al libro hoy (10 líneas)», por obra, con Debe y Haber', /Lo que iría al libro hoy \(10 líneas\)/.test(await txt(q.locator('#ct-wip-libro summary'))) && (await q.locator('#ct-wip-libro .ct-wip-asl ul li').count()) === 10);
    await foto(q, 'c12-2-mes-revisado');

    // ---- postear: qué va por obra, que se deshace solo el día 1, y el asiento ----
    n0 = llamadas.length;
    await q.locator('#ct-wip-posteo [data-wip-postear]').click(); await q.waitForTimeout(200);
    const fp = await txt(q.locator('#ct-wip-posteo .ct-form')), fpTodo = (await q.locator('#ct-wip-posteo .ct-form').textContent()).replace(/\s+/g, ' ');
    ok('Postear · antes de mandar dice en llano qué va por obra (A: vas $3,000.00 por detrás…; B: por delante…; C: …y pierde $1,000.00: se provisionan $500.00), las líneas (Debe / Haber), que es UN asiento del 31 oct 2026 y que se deshace solo el 1 nov 2026; todavía no llama',
      /Se postea un asiento del 31 oct 2026, con 4 obras:/.test(fp) && /C12 PRUEBA Obra A: vas \$3,000\.00 por detrás: hecho y todavía sin facturar\./.test(fp) && /C12 PRUEBA Obra B: vas \$4,000\.00 por delante: facturado de más\./.test(fp) &&
      /C12 PRUEBA Obra C: vas \$5,000\.00 por detrás: hecho y todavía sin facturar; y pierde \$1,000\.00: se provisionan \$500\.00\./.test(fp) && /Se deshace solo el 1 nov 2026/.test(fp) && /Las 10 líneas del asiento/.test(fp) && /1200 Costo y utilidad en exceso de facturación/.test(fpTodo) &&
      /Debe \$3,000\.00/.test(fpTodo) && /2400 Facturación en exceso de costo/.test(fpTodo) && /Haber \$4,000\.00/.test(fpTodo) && !ultima(n0, 'fn_wip_postear'), fp);
    await foto(q, 'c12-3-postear');
    await enviar(q, q.locator('#ct-wip-posteo .ct-form form'));
    let lp = ultima(n0, 'fn_wip_postear');
    res = await txt(q.locator('#ct-wip-res'));
    ok('…«Postear el ajuste»: fn_wip_postear({p_periodo: "2026-10", p_motivo: null}); arriba la nota de la base (asiento 2026-000007, se deshace solo el 1-nov-2026 con 2026-000008) y el resumen «ajuste posteado» con su asiento y «Deshacer» (ya no «Postear»)',
      lp && JSON.stringify(lp.args) === JSON.stringify({ p_periodo: '2026-10', p_motivo: null }) &&
      /Posteado el ajuste de WIP de octubre de 2026: asiento 2026-000007, con 4 obra\(s\) \(sub-facturado \$8,118\.75, sobre-facturado \$4,000\.00, pérdida \$500\.00\)\. Se deshace solo el 1-nov-2026 \(asiento 2026-000008\)\./.test(await txt(q.locator('.ct-wip-nota'))) &&
      /ajuste posteado/.test(res) && /Ajuste posteado: asiento 2026-000007 del 31 oct 2026; se deshace solo el 1 nov 2026 \(2026-000008\)\./.test(res) && /El ajuste de octubre de 2026 ya está posteado y al día \(asiento 2026-000007\)\./.test(res) &&
      (await q.locator('#ct-wip-posteo [data-wip-deshacer]').count()) === 1 && !(await q.locator('#ct-wip-posteo [data-wip-postear]').count()), lp && JSON.stringify(lp.args));
    await foto(q, 'c12-4-posteado');
    // el número del asiento lleva al asiento en Estados
    await q.locator('#ct-wip-posteo .ct-asiento-btn').first().evaluate(x => x.click()); await q.waitForTimeout(400);
    ok('…el número del asiento abre ese asiento en «Estados financieros»', (await q.evaluate(() => [window.MXP_CONTA._estado.pagina, window.MXP_CONTA._estado.est.asiento])).join() === 'estados,' + W.ajustes[0].asiento_id);

    // ---- después de postear llega un costo: ya no está al día, y «Volver a postear» lo rehace ----
    W.libro['c12-prueba-a'].costo['2026-10'] += 100000;
    n0 = llamadas.length;
    await ve(q, 'wip');
    res = await txt(q.locator('#ct-wip-res'));
    ok('Llega un costo a A después de postear · en rojo, con lo que cambió (A pasa de sub-facturado $3,000.00 a sub-facturado $4,666.67), sin repetirlo, y «Volver a postear el ajuste»',
      /el ajuste ya no está al día/.test(res) && (await q.locator('#ct-wip-res [data-cuadre="50"].bad').count()) === 1 &&
      /El ajuste posteado de octubre de 2026 \(asiento 2026-000007\) ya no es el que da el WIP de hoy: C12 PRUEBA Obra A pasa de sub-facturado \$3,000\.00 a sub-facturado \$4,666\.67\. Vuelve a postearlo: se reversa y entra el nuevo\./.test(res) &&
      !(await q.locator('#ct-wip-res .ct-wip-rnota').count()) && (await q.locator('#ct-wip-posteo [data-wip-postear]').textContent()) === 'Volver a postear el ajuste', res);
    await q.locator('#ct-wip-posteo [data-wip-postear]').click(); await q.waitForTimeout(200);
    ok('…la confirmación dice que el posteado se reversa y entra este', /El ajuste que está posteado \(asiento 2026-000007\) ya no es el de hoy: se reversa dentro de octubre de 2026 y entra este\./.test(await txt(q.locator('#ct-wip-posteo .ct-form'))) && /Volver a postear/.test(await txt(q.locator('#ct-wip-posteo .ct-form button[type="submit"]'))));
    await enviar(q, q.locator('#ct-wip-posteo .ct-form form'));
    ok('…fn_wip_postear lo rehace y la nota de la base lo dice (asiento 2026-000010, sub-facturado $9,785.42)', !!ultima(n0, 'fn_wip_postear') && /Rehecho el ajuste de WIP de octubre de 2026: asiento 2026-000010, con 4 obra\(s\) \(sub-facturado \$9,785\.42, sobre-facturado \$4,000\.00, pérdida \$500\.00\)/.test(await txt(q.locator('.ct-wip-nota'))) && /ajuste posteado/.test(await txt(q.locator('#ct-wip-res .ct-cab'))));

    // ---- deshacer: con su motivo ----
    n0 = llamadas.length;
    await q.locator('#ct-wip-posteo [data-wip-deshacer]').click(); await q.waitForTimeout(150);
    let fx = q.locator('#ct-wip-posteo .ct-form form');
    await fx.locator('[name="motivo"]').fill('no'); await fx.locator('button[type="submit"]').click(); await q.waitForTimeout(150);
    ok('Deshacer · dice que se reversa (no se borra) y pide el motivo: dos letras no bastan y no llama', !ultima(n0, 'fn_wip_deshacer') && /se reversa con otro asiento \(no se borra\), su reverso del día 1 queda anulado/.test(await txt(q.locator('#ct-wip-posteo .ct-form'))) && /al menos tres letras/.test(await txt(q.locator('#ct-wip-posteo .ct-form'))));
    await fx.locator('[name="motivo"]').fill('ZZ prueba: deshacer el ajuste'); await enviar(q, fx);
    const ld = ultima(n0, 'fn_wip_deshacer');
    ok('…con su motivo: fn_wip_deshacer({p_periodo, p_motivo}); la nota de la base (2026-000010 reversado con 2026-000012) y el mes otra vez «sin postear»',
      ld && JSON.stringify(ld.args) === JSON.stringify({ p_periodo: '2026-10', p_motivo: 'ZZ prueba: deshacer el ajuste' }) && /Deshecho el ajuste de WIP de octubre de 2026: el asiento 2026-000010 se reversó con 2026-000012, y su reverso del día 1 quedó anulado\. El libro vuelve a lo facturado\./.test(await txt(q.locator('.ct-wip-nota'))) &&
      /sin postear/.test(await txt(q.locator('#ct-wip-res .ct-cab'))) && (await q.locator('#ct-wip-posteo [data-wip-postear]').count()) === 1, ld && JSON.stringify(ld.args));
    await toca(q, '#ct-wip-posteo [data-wip-postear]'); await enviar(q, q.locator('#ct-wip-posteo .ct-form form'));   // (otra vez posteado: el cierre lo mira)

    // ---- noviembre (no ha terminado): «Sigue igual» en un toque; la propuesta que cambió en otra pestaña ----
    n0 = llamadas.length;
    await q.selectOption('#ct-wip-mes', '2026-11'); await pintado(q);
    tA = await txt(ob(q, 'c12-prueba-a'));
    ok('Otro mes · el selector trae los meses ya empezados y pide fn_wip_resumen({p_periodo: "2026-11"}); cada obra propone lo del mes anterior («Sigue igual: $6,000.00», «Lo que revisaste en octubre de 2026.») y, sin terminar el mes, no hay «Postear» y dice por qué',
      JSON.stringify((ultima(n0, 'fn_wip_resumen') || {}).args) === '{"p_periodo":"2026-11"}' && JSON.stringify(await q.locator('#ct-wip-mes option').evaluateAll(os => os.map(o => o.value))) === '["2026-11","2026-10"]' &&
      /la vez pasada: \$6,000\.00/.test(tA) && (await ob(q, 'c12-prueba-a').locator('[data-wip-igual]').textContent()) === 'Sigue igual: $6,000.00' && /Lo que revisaste en octubre de 2026\./.test(tA) &&
      !(await q.locator('#ct-wip-posteo [data-wip-postear]').count()) && /Noviembre de 2026 todavía no termina \(su último día es el 30-nov-2026\): el ajuste se postea con el mes terminado\./.test(await txt(q.locator('#ct-wip-posteo'))) && /en curso/.test(await txt(q.locator('#ct-wip-res .ct-cab'))), tA);
    await ob(q, 'c12-prueba-a').locator('[data-wip-igual]').click(); await pintado(q);
    lr = ultima(n0, 'fn_wip_revisar');
    ok('…«Sigue igual» es un toque: fn_wip_revisar({p_proyecto, p_periodo: "2026-11", p: {confirmar: true, costo_estimado: "6000.00"}}) (con el número que se vio) y A queda revisada («confirmó lo del mes anterior»)',
      lr && JSON.stringify(lr.args) === JSON.stringify({ p_proyecto: 'c12-prueba-a', p_periodo: '2026-11', p: { confirmar: true, costo_estimado: '6000.00' } }) && /confirmó lo del mes anterior/.test(await txt(ob(q, 'c12-prueba-a'))), lr && JSON.stringify(lr.args));
    W_FN.fn_wip_revisar({ p_proyecto: 'c12-prueba-b', p_periodo: '2026-10', p: { costo_estimado: '12000.00', nota: 'ZZ: subió (en otra pestaña)' } });
    await ob(q, 'c12-prueba-b').locator('[data-wip-igual]').click(); await pintado(q);
    ok('…si la propuesta cambió entretanto (otra pestaña), la base dice MX008 y la página se vuelve a leer con el aviso arriba y el número de hoy («Sigue igual: $12,000.00»), sin revisar nada',
      /La propuesta de «C12 PRUEBA Obra B» ya no es la que viste \(\$10,000\.00; ahora es \$12,000\.00\): vuelve a mirar antes de confirmar\./.test(await txt(q.locator('.ct-wip-nota.warn'))) &&
      (await ob(q, 'c12-prueba-b').locator('[data-wip-igual]').textContent()) === 'Sigue igual: $12,000.00' && !W.rev.some(r => r.proyecto_id === 'c12-prueba-b' && r.periodo === '2026-11'));
    // terminada: la app la tiene completada → «Terminó en noviembre» (100 %)
    W_OB['c12-prueba-c'].estado = 'completado';
    await ve(q, 'wip', { periodo: '2026-11' });
    ok('Una obra que la app ya tiene terminada · «Terminó en noviembre» con el porqué de la base', (await ob(q, 'c12-prueba-c').locator('[data-wip-terminada]').textContent()) === 'Terminó en noviembre' && /La app la tiene como terminada: si terminó en este mes, revísala como terminada \(100 %\)/.test(await txt(ob(q, 'c12-prueba-c'))));
    await ob(q, 'c12-prueba-c').locator('[data-wip-terminada]').click(); await q.waitForTimeout(150);
    ok('…pregunta antes (100 % hecho, su costo final es el que lleva, lo que falte por facturar queda por detrás)', /¿«C12 PRUEBA Obra C» terminó en noviembre de 2026\? Se revisa como terminada: 100 % hecho/.test(await txt(ob(q, 'c12-prueba-c').locator('.ct-form'))));
    n0 = llamadas.length;
    await enviar(q, ob(q, 'c12-prueba-c').locator('.ct-form form'));
    ok('…«Sí, terminó»: fn_wip_revisar({…, p: {terminada: true}}) y queda «terminada: 100 % hecho», sin pérdida provisionada', JSON.stringify((ultima(n0, 'fn_wip_revisar') || {}).args) === JSON.stringify({ p_proyecto: 'c12-prueba-c', p_periodo: '2026-11', p: { terminada: true } }) &&
      /terminada: 100 % hecho/.test(await txt(ob(q, 'c12-prueba-c'))) && /Precio \$10,000\.00 · ganado \$10,000\.00 · facturado \$0\.00 → vas \$10,000\.00 por detrás/.test(await txt(ob(q, 'c12-prueba-c'))));
    W_OB['c12-prueba-c'].estado = 'ejecucion';
    // la obra que lleva más de su estimado (con su nota): «pasa de 100 %», topada
    await ob(q, 'c12-prueba-d').locator('[data-wip-otro]').click();
    { const f = ob(q, 'c12-prueba-d').locator('.ct-form form'); await f.locator('[name="costo"]').fill('500'); await f.locator('[name="nota"]').fill('ZZ: casi terminada'); await enviar(q, f); }
    const tD2 = await txt(ob(q, 'c12-prueba-d'));
    ok('Más costo que su estimado (con nota) · «pasa de 100 %», el avance topado en 100 % (de verdad 210 %) con la barra en rojo, y el aviso de la base', /pasa de 100 %/.test(tD2) && /100 % hecho \(de verdad 210 %\)/.test(tD2) &&
      /Lleva \$1,050\.00 de costo y su costo estimado revisado es \$500\.00 \(210 %\): el avance se topa en 100 %\./.test(tD2) && (await ob(q, 'c12-prueba-d').locator('.ct-ob-barra-h.pasa').count()) === 1, tD2);
    await foto(q, 'c12-5-noviembre');

    // ---- un mes cerrado solo se lee ----
    W.cerrados.add('2026-10');
    await ve(q, 'wip', { periodo: '2026-10' });
    res = await txt(q.locator('#ct-wip-res'));
    ok('Un mes cerrado · «cerrado · solo se lee», la foto de lo que se posteó (fuente «posteado»), sin botones de revisar, postear ni deshacer',
      /cerrado · solo se lee/.test(res) && /Octubre de 2026 ya está cerrado: su WIP es el que se posteó\./.test(res) && /lo que se posteó/.test(await txt(q.locator('#ct-wip-sch .ct-cab'))) && /Lo que se posteó \(\d+ líneas\)/.test(await txt(q.locator('#ct-wip-libro summary'))) &&
      !(await q.locator('#ct-wip-rev [data-wip-otro], #ct-wip-rev [data-wip-igual], #ct-wip-rev [data-wip-antes], #ct-wip-posteo [data-wip-postear], #ct-wip-posteo [data-wip-deshacer]').count()) && (await q.locator('#ct-wip-rev [data-wip-obra]').count()) === 4, res);
    W.cerrados.delete('2026-10');

    // ---- Obras: cuáles llevan WIP, la marca con su nota, lo de antes con otros números ----
    n0 = llamadas.length;
    await ve(q, 'wip', { sub: 'obras' });
    ok('Obras · v_wip_obras: «Llevan WIP (4)», «No llevan (1)», «Todas (5)»; D dice lo de antes confirmado (costo $730.00, facturado $1,500.00)', lecturas.some(l => l.startsWith('v_wip_obras')) &&
      /Llevan WIP \(4\)/.test(await txt(q.locator('[data-wip-filtro="llevan"]'))) && /No llevan \(1\)/.test(await txt(q.locator('[data-wip-filtro="no"]'))) && /Todas \(5\)/.test(await txt(q.locator('[data-wip-filtro="todas"]'))) &&
      /Lo de antes del libro, confirmado el .*: costo \$730\.00 y facturado \$1,500\.00\./.test(await txt(q.locator('[data-wip-ob="c12-prueba-d"]'))));
    await toca(q, '[data-wip-filtro="no"]');
    ok('…«No llevan»: el taller de servicio con el porqué de la base', (await q.locator('[data-wip-ob]').count()) === 1 && /Es de servicio: no lleva WIP; su ingreso es lo facturado\./.test(await txt(q.locator('[data-wip-ob="c12-prueba-s"]'))));
    await q.locator('[data-wip-ob="c12-prueba-s"] [data-wip-marca]').click(); await q.waitForTimeout(150);
    let fm = q.locator('[data-wip-ob="c12-prueba-s"] .ct-form form');
    await fm.locator('[name="modo"]').selectOption('contrato'); await enviar(q, fm);
    ok('La marca · «Lleva WIP» sin nota: la base pide la nota (22023) y la forma lo dice', JSON.stringify((ultima(n0, 'fn_wip_obra') || {}).args) === JSON.stringify({ p_proyecto: 'c12-prueba-s', p: { modo: 'contrato' } }) && /Di por qué en la nota/.test(await txt(q.locator('[data-wip-ob="c12-prueba-s"] .ct-form'))));
    await fm.locator('[name="nota"]').fill('ZZ: precio cerrado'); await enviar(q, fm);
    ok('…con la nota: fn_wip_obra({p_proyecto, p: {modo: "contrato", nota}}) y la nota de la base (su ficha no tiene contrato: hay que ponerlo)', JSON.stringify((ultima(n0, 'fn_wip_obra') || {}).args) === JSON.stringify({ p_proyecto: 'c12-prueba-s', p: { modo: 'contrato', nota: 'ZZ: precio cerrado' } }) &&
      /Marcada como de precio fijo, pero su ficha no tiene contrato: ponlo para poder revisarla\. Si el ajuste de un mes abierto ya estaba posteado, vuelve a postearlo\./.test(await txt(q.locator('.ct-wip-nota'))));
    W_FN.fn_wip_obra({ p_proyecto: 'c12-prueba-s', p: { modo: 'auto' } });
    await ve(q, 'wip', { sub: 'obras' }); await toca(q, '[data-wip-filtro="llevan"]');
    await q.locator('[data-wip-ob="c12-prueba-d"] [data-wip-antes]').click(); await q.waitForSelector('[data-wip-ob="c12-prueba-d"] .ct-wip-antes', { timeout: 5000 });
    ok('…D: «Lo de antes del libro» enseña lo confirmado (el ok) junto a la propuesta', /Confirmado el .*: costo \$730\.00 y facturado \$1,500\.00/.test(await txt(q.locator('[data-wip-ob="c12-prueba-d"] .ct-wip-antes'))));
    await q.locator('[data-wip-ob="c12-prueba-d"] [data-antes-otro]').click(); await q.waitForTimeout(150);
    fm = q.locator('[data-wip-ob="c12-prueba-d"] .ct-form form');
    await fm.locator('[name="costo"]').fill('950'); await fm.locator('button[type="submit"]').click(); await q.waitForTimeout(150);
    ok('…«Poner otros números» trae los de la propuesta y pide de dónde salen: sin la nota no se manda', /Di de dónde salen esos números/.test(await txt(q.locator('[data-wip-ob="c12-prueba-d"] .ct-form'))) && (await fm.locator('[name="facturado"]').inputValue()) === '1500.00');
    n0 = llamadas.length;
    await fm.locator('[name="nota"]').fill('ZZ: lo de QuickBooks al 30-sep'); await enviar(q, fm);
    la = ultima(n0, 'fn_wip_antes');
    ok('…con la nota: fn_wip_antes({p_proyecto, p: {costo: "950", facturado: "1500.00", nota}}) y la nota de la base (con el aviso de que el ajuste posteado ya no está al día)', la && JSON.stringify(la.args) === JSON.stringify({ p_proyecto: 'c12-prueba-d', p: { costo: '950', facturado: '1500.00', nota: 'ZZ: lo de QuickBooks al 30-sep' } }) &&
      /Confirmado lo de antes del libro de «C12 PRUEBA Obra D»: costo \$950\.00 y facturado \$1,500\.00\. El ajuste de octubre de 2026 ya estaba posteado: mira si sigue al día y, si no, vuelve a postearlo\./.test(await txt(q.locator('.ct-wip-nota'))), la && JSON.stringify(la.args));
    W_FN.fn_wip_antes({ p_proyecto: 'c12-prueba-d', p: { costo: '730.00', facturado: '1500.00' } });

    // ---- Historial y Ajustes ----
    await ve(q, 'wip', { sub: 'historial' });
    const hi = await txt(q.locator('#ct-wip-ajustes')), hr = await txt(q.locator('#ct-wip-revisiones'));
    ok('Historial · los ajustes (el vivo y los deshechos, con su reverso y su motivo) y las revisiones (vigentes y sustituidas)', (await q.locator('#ct-wip-ajustes .ct-wip-hi').count()) === 3 && /vivo/.test(hi) && /deshecho/.test(hi) && /«ZZ prueba: deshacer el ajuste»/.test(hi) && /reverso 2026-000012/.test(hi) &&
      /se deshace solo el 1 nov 2026/.test(hi) && /C12 PRUEBA Obra B · octubre de 2026 sustituida/.test(hr) && /vigente/.test(hr) && (await q.locator('#ct-wip-revisiones .ct-wip-hi').count()) === W.rev.length, hi.slice(0, 400));
    n0 = llamadas.length;
    await ve(q, 'wip', { sub: 'ajustes' });
    ok('Ajustes · lee fn_wip_config() y dice desde qué mes lo exige el cierre (noviembre de 2026), con la nota de la base', JSON.stringify((ultima(n0, 'fn_wip_config') || {}).args) === '{}' && /El cierre exige el WIP \(cada obra revisada y el ajuste posteado\) desde noviembre de 2026/.test(await txt(q.locator('#ct-wip-cfg'))) && (await q.locator('#ct-wip-cfg-form select').inputValue()) === '2026-11');
    await q.locator('#ct-wip-cfg-form select').selectOption('2026-10'); await enviar(q, q.locator('#ct-wip-cfg-form'));
    const cfgEscrita = () => (desde(n0).filter(l => l.fn === 'fn_wip_config' && l.args.p).pop() || {}).args;   // (después de guardar, la página vuelve a leer con fn_wip_config({}))
    ok('…«desde octubre» manda fn_wip_config({p: {exigir_desde: "2026-10"}}) y la nota de la base lo dice', JSON.stringify(cfgEscrita()) === JSON.stringify({ p: { exigir_desde: '2026-10' } }) && /desde octubre de 2026; los meses anteriores no se frenan por él/.test(await txt(q.locator('.ct-wip-nota'))));
    await q.locator('#ct-wip-cfg-form select').selectOption(''); await enviar(q, q.locator('#ct-wip-cfg-form'));
    ok('…«Todavía no lo exige» manda {exigir_desde: null}', JSON.stringify(cfgEscrita()) === JSON.stringify({ p: { exigir_desde: null } }) && /El cierre todavía no exige el WIP en ningún mes/.test(await txt(q.locator('.ct-wip-nota'))));
    W_FN.fn_wip_config({ p: { exigir_desde: '2026-10' } });

    // ---- en «Cierre del mes»: la misma revisión, las filas 174 a 177 y postear desde ahí ----
    estado.c9 = true; c9Reset();
    W_OB['c12-prueba-e'] = { obra: 'C12 PRUEBA Obra E', cliente: 'ZZ Cliente E', tipo: 'comercial', estado: 'ejecucion', contrato: 500000 };
    W.libro['c12-prueba-e'] = { costo: { '2026-10': 100000 }, fact: {} };
    n0 = llamadas.length;
    await ve(q, 'cierre', { sub: 'cierre', periodo: '2026-10' });
    const orden = await q.evaluate(() => [...document.querySelectorAll('#ct-cie-cuerpo > section')].map(x => x.id));
    let cie = await txt(q.locator('#ct-wip-cie'));
    ok('Cierre del mes (octubre, que lo exige) · la tarjeta «El WIP de octubre de 2026» va entre lo que detiene y los avisos, con la misma revisión (E, nueva, por revisar) y «Volver a postear» (el posteado ya no está al día)',
      orden.indexOf('ct-wip-cie') === orden.indexOf('ct-cie-rev') + 1 && orden.indexOf('ct-cie-avisos') === orden.indexOf('ct-wip-cie') + 1 && /Para cerrar octubre de 2026: cada obra de precio fijo con su costo estimado revisado, y el ajuste posteado\./.test(cie) &&
      (await q.locator('#ct-wip-cie [data-wip-obra]').count()) === 5 && (await q.locator('#ct-wip-cie [data-wip-obra="c12-prueba-e"] [data-wip-otro]').count()) === 1 && (await q.locator('#ct-wip-cie [data-wip-postear]').count()) === 1, orden.join(',') + ' || ' + cie.slice(0, 300));
    const det = await txt(q.locator('#ct-cie-rev .ct-cie-lista'));
    ok('…y en la lista del cierre, como las demás, las filas del WIP que detienen (175 falta revisar E; 176 el ajuste ya no está al día), cada una con «Qué hacer» y su botón «WIP» al mismo mes',
      (await q.locator('#ct-cie-rev .ct-cie-item.detiene[data-orden="175"]').count()) === 1 && (await q.locator('#ct-cie-rev .ct-cie-item.detiene[data-orden="176"]').count()) === 1 &&
      /Faltan por revisar 1 de las 5 obra\(s\) de precio fijo con movimiento en octubre de 2026: C12 PRUEBA Obra E\./.test(det) && /Qué hacer: En Contabilidad → WIP, revisa cada obra de la lista/.test(det) &&
      (await q.locator('#ct-cie-rev [data-orden="175"] [data-wip-ir="2026-10"]').textContent()) === 'WIP' && (await q.locator('#ct-cie-avisos .ct-cie-item[data-orden="174"].ok').count()) === 1, det.slice(0, 500));
    await foto(q, 'c12-6-cierre');
    // revisar E desde el cierre: la página que se repinta es el cierre (vuelve a revisar), y la 175 pasa a verde
    await q.locator('#ct-wip-cie [data-wip-obra="c12-prueba-e"] [data-wip-otro]').click();
    { const f = q.locator('#ct-wip-cie [data-wip-obra="c12-prueba-e"] .ct-form form'); await f.locator('[name="costo"]').fill('4000'); await enviar(q, f); }
    ok('…revisar E desde el cierre: fn_wip_revisar y el cierre vuelve a revisar (fn_cierre_revisar): la 175 ya no detiene', JSON.stringify((ultima(n0, 'fn_wip_revisar') || {}).args) === JSON.stringify({ p_proyecto: 'c12-prueba-e', p_periodo: '2026-10', p: { costo_estimado: '4000' } }) &&
      desde(n0).filter(l => l.fn === 'fn_cierre_revisar').length >= 2 && (await q.locator('#ct-cie-rev .ct-cie-item[data-orden="175"]').count()) === 0 && (await q.locator('#ct-cie-avisos .ct-cie-item.ok[data-orden="175"]').count()) === 1 && (await q.evaluate(() => window.MXP_CONTA._estado.pagina)) === 'cierre');
    await q.locator('#ct-wip-cie [data-wip-postear]').click(); await q.waitForTimeout(150);
    ok('…«Volver a postear» desde el cierre dice qué entra (E, nueva) y que se deshace solo el día 1', /C12 PRUEBA Obra E: vas \$1,250\.00 por detrás/.test(await txt(q.locator('#ct-wip-cie .ct-form'))) && /Se deshace solo el 1 nov 2026/.test(await txt(q.locator('#ct-wip-cie .ct-form'))));
    await enviar(q, q.locator('#ct-wip-cie .ct-form form'));
    ok('…posteado desde el cierre: fn_wip_postear, el cierre vuelve a revisar y la 176 queda en verde; la tarjeta del WIP dice «ajuste posteado» con la nota de la base', !!ultima(n0, 'fn_wip_postear') && (await q.locator('#ct-cie-rev .ct-cie-item[data-orden="176"]').count()) === 0 &&
      (await q.locator('#ct-cie-avisos .ct-cie-item.ok[data-orden="176"]').count()) === 1 && /ajuste posteado/.test(await txt(q.locator('#ct-wip-cie .ct-cab'))) && /Rehecho el ajuste de WIP de octubre de 2026/.test(await txt(q.locator('#ct-wip-cie .ct-wip-nota'))));
    // la 177 (los avisos: la pérdida de C) lleva al WIP de octubre
    await q.locator('#ct-cie-avisos [data-orden="177"] [data-wip-ir]').evaluate(x => x.click()); await pintado(q);
    ok('…la fila 177 (sus avisos) lleva a «WIP» del MISMO mes (octubre)', (await titulo2(q)) === 'WIP (obra en curso)' && JSON.stringify((ultima(n0, 'fn_wip_resumen') || {}).args) === '{"p_periodo":"2026-10"}');
    await ve(q, 'cierre', { sub: 'cierre', periodo: '2026-09-APERTURA' });
    ok('…en la apertura no hay tarjeta del WIP (va por mes)', (await q.locator('#ct-cie-rev').count()) === 1 && !(await q.locator('#ct-wip-cie').count()));
    delete W_OB['c12-prueba-e']; delete W.libro['c12-prueba-e']; W.rev = W.rev.filter(r => r.proyecto_id !== 'c12-prueba-e');

    // ---- falla ruidosa: un cuadre en rojo; el resumen y el schedule contando distinto ----
    W.cuadre10 = true;
    await ve(q, 'wip', { periodo: '2026-10' });
    ok('Falla ruidosa · un cuadre del WIP en rojo (saldo a mano en 1200): «El WIP no cuadra» con su detalle y NINGUNA cifra ni obra', /El WIP no cuadra/.test(await txt(q.locator('#ct-wip-cuerpo .ct-rojo h2'))) && /Hay saldo en las cuentas del WIP que no viene de un ajuste: \$500\.00 en la 1200 de C12 PRUEBA Obra A/.test(await txt(q.locator('#ct-wip-cuerpo .ct-rojo'))) &&
      !(await q.locator('#ct-wip-cuerpo .ct-kpi, #ct-wip-cuerpo [data-wip-obra], #ct-wip-sch').count()));
    await ve(q, 'cierre', { sub: 'cierre', periodo: '2026-10' });
    ok('…en el cierre: la tarjeta del WIP en rojo sin cifras, y la 174 detiene en la lista', /no cuadra/.test(await txt(q.locator('#ct-wip-cie .ct-cab'))) && !(await q.locator('#ct-wip-cie [data-wip-obra]').count()) && (await q.locator('#ct-cie-rev .ct-cie-item.detiene[data-orden="174"]').count()) === 1);
    W.cuadre10 = false; W.conteoMal = true;
    await ve(q, 'wip', { periodo: '2026-10' });
    ok('…el resumen cuenta una obra más que el schedule: rojo («no cuentan lo mismo»), sin cifras', /El resumen y el schedule del WIP no cuentan lo mismo/.test(await txt(q.locator('#ct-wip-cuerpo .ct-rojo h2'))) && !(await q.locator('#ct-wip-cuerpo .ct-kpi').count()));
    W.conteoMal = false;
    // sin c12 y el equipo
    estado.c12 = false;
    await ve(q, 'wip');
    ok('Sin c12 · «WIP» dice en llano que falta c12-wip.sql (y volver a pegar c9), con «Reintentar»', /Falta el WIP en la base/.test(await txt(q.locator('#ct-wip-cuerpo .ct-rojo h2'))) && /c12-wip\.sql/.test(await txt(q.locator('#ct-wip-cuerpo .ct-rojo'))) && (await q.locator('#ct-reintentar').count()) === 1);
    await ve(q, 'cierre', { sub: 'cierre', periodo: '2026-10' });
    ok('…y el cierre sigue como antes: sin tarjeta del WIP y sin rojo', (await q.locator('#ct-cie-rev').count()) === 1 && !(await q.locator('#ct-wip-cie').count()) && !(await q.locator('#ct-cie-cuerpo > .ct-rojo').count()));
    estado.c12 = true; estado.c12NoDueno = true;
    await ve(q, 'wip');
    ok('El equipo (no dueño) · la base dice 42501: «El WIP es solo del dueño» con su texto, sin cifras', /El WIP es solo del dueño/.test(await txt(q.locator('#ct-wip-cuerpo .ct-rojo h2'))) && new RegExp(W_NO_DUENO.replace(/[()]/g, '\\$&')).test(await txt(q.locator('#ct-wip-cuerpo .ct-rojo'))) && !(await q.locator('#ct-wip-cuerpo .ct-kpi').count()));
    estado.c12NoDueno = false;
    await cx.close();

    // ---- sin el código del teléfono: postear y deshacer no se mandan ----
    W.libro['c12-prueba-c'].costo['2026-10'] += 50000;   // (otro costo: el ajuste vuelve a estar desfasado y hay que volver a postear)
    ({ cx, q } = await abrirCtx(820, false));
    n0 = llamadas.length;
    await ve(q, 'wip', { periodo: '2026-10' });
    await q.locator('#ct-wip-posteo [data-wip-postear]').click(); await q.waitForTimeout(150);
    ok('Sin el código del teléfono · «Volver a postear» dice que lo pide y no llama', /pide el código del teléfono/.test(await txt(q.locator('#ct-wip-posteo .ct-form'))) && !ultima(n0, 'fn_wip_postear'));
    await q.locator('#ct-wip-posteo [data-wip-deshacer]').click(); await q.waitForTimeout(150);
    ok('…«Deshacer» tampoco', /Deshacer el ajuste toca el libro: pide el código del teléfono/.test(await txt(q.locator('#ct-wip-posteo .ct-form'))) && !ultima(n0, 'fn_wip_deshacer'));
    await cx.close();

    // ---- el teléfono (390), el iPad (820) y la computadora (1280): sin desplazamiento lateral ----
    for (const w of [390, 820, 1280]) {
      ({ cx, q } = await abrirCtx(w, true));
      const mal = [];
      const mide = async nombre => { const m = await q.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: window.innerWidth, rojo: !!document.querySelector('#conta-raiz .ct-rojo') })); if (m.sw > m.iw + 1 || m.rojo) mal.push(`${nombre}: ${m.sw} > ${m.iw}${m.rojo ? ' (rojo)' : ''}`); await foto(q, `c12-${w}-${nombre}`); };
      await ve(q, 'wip', { sub: 'mes', periodo: '2026-10' }); await mide('mes');
      await q.locator('#ct-wip-posteo [data-wip-postear]').click(); await q.waitForTimeout(150); await q.locator('#ct-wip-posteo .ct-wip-lineas').evaluate(d => { d.open = true; }); await mide('postear');
      await q.locator('#ct-wip-libro details').evaluate(d => { d.open = true; }).catch(() => {}); await q.locator('#ct-wip-sch details').evaluate(d => { d.open = true; }).catch(() => {}); await mide('mes-abierto');
      await ve(q, 'wip', { sub: 'mes', periodo: '2026-11' }); await ob(q, 'c12-prueba-b').locator('[data-wip-otro]').click(); await q.waitForTimeout(150); await mide('noviembre-revisar');
      await ve(q, 'wip', { sub: 'obras' }); await q.locator('[data-wip-ob="c12-prueba-d"] [data-wip-antes]').click(); await q.waitForSelector('[data-wip-ob="c12-prueba-d"] .ct-wip-antes', { timeout: 5000 }); await mide('obras-antes');
      await ve(q, 'wip', { sub: 'historial' }); await mide('historial');
      await ve(q, 'wip', { sub: 'ajustes' }); await mide('ajustes');
      await ve(q, 'cierre', { sub: 'cierre', periodo: '2026-10' }); await mide('cierre');
      if (w === 390) {
        await ve(q, 'wip', { sub: 'mes', periodo: '2026-10' });
        const tv = await q.evaluate(() => { const t = document.querySelector('.ct-tabs'), a = t.querySelector('.ct-tab[aria-current="page"]'), T = t.getBoundingClientRect(), A = a.getBoundingClientRect(); return { pag: a.dataset.pag, izq: Math.round(A.left - T.left), der: Math.round(T.right - A.right) }; });
        ok('Teléfono · la pestaña «WIP» se ve entera dentro de la tira de pestañas', tv.pag === 'wip' && tv.izq >= 14 && tv.der >= 14, JSON.stringify(tv));
        const tb = await q.evaluate(() => { const t = document.querySelector('#ct-wip-sch table'), r = t.getBoundingClientRect(); return { der: Math.round(r.right), iw: window.innerWidth, apilada: getComputedStyle(t.querySelector('thead')).display === 'none' }; });
        ok('Teléfono · el schedule se apila (cada cifra con su etiqueta) y cabe en 390 px', tb.apilada && tb.der <= tb.iw, JSON.stringify(tb));
      }
      ok(`WIP · ${w} px: el mes (con postear abierto y lo plegado abierto), otro mes revisando, obras con lo de antes, historial, ajustes y el cierre con su WIP, sin desplazamiento lateral ni rojos`, !mal.length, mal.join(' | '));
      await cx.close();
    }
    estado.c9 = false; c9Reset(); estado.c12 = false; wReset(); conCodigo(false);
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
    // (fase 8) c9 pegado: «Cierre del mes» con lo que dejaron las escenas del cierre (la apertura y octubre cerrados y exportados, un activo dado de baja)
    estado.c9 = true;
    // (fase 9) c10 pegado: la Bandeja con los Zelle de la cuadrilla y «Costo por obra» con sus obras
    estado.c10 = true; jReset();
    // (fase 10) c11 pegado: «Facturas» con una emitida (con su PDF y su envío) y un borrador
    estado.c11 = true; fReset();
    // (fase 10) c12 pegado: «WIP» con octubre revisado (lo de antes de D confirmado) y su ajuste posteado
    estado.c12 = true; wReset();
    W_FN.fn_wip_antes({ p_proyecto: 'c12-prueba-d', p: { costo: '730.00', facturado: '1500.00' } });
    for (const [id, c, n] of [['c12-prueba-a', '6000', null], ['c12-prueba-b', '10000', 'ZZ: el bid'], ['c12-prueba-c', '11000', 'ZZ: subió el material'], ['c12-prueba-d', '12000', 'ZZ: estimado de prueba']])
      W_FN.fn_wip_revisar({ p_proyecto: id, p_periodo: '2026-10', p: n ? { costo_estimado: c, nota: n } : { costo_estimado: c } });
    W_FN.fn_wip_postear({ p_periodo: '2026-10' });
    { const bF = C11_FN.fn_emision_borrador({ p: { forma: 'hito', hito_id: -1110000001 } }); C11_FN.fn_emision_emitir({ p_documento: bF.documento.id, p_visto: bF.visto, p_opciones: {} });
      funcionFacturas({ accion: 'enviar', documento: bF.documento.id }, 'Bearer x.' + b64({ aal: 'aal2' }) + '.y'); C11_FN.fn_emision_borrador({ p: { forma: 'porcentaje', proyecto_id: 'c11-prueba-a', porcentaje: '30' } }); }
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
    estado.mfaFactores = []; estado.sesionAal = undefined; estado.stripeDeposito = false; estado.c8 = false; estado.c9 = false; estado.c10 = false; estado.c11 = false; estado.c12 = false; wReset(); iaReset();
  }
  ok('Sin errores de JavaScript en la página', errs.length === 0, errs.join(' | '));
  await b.close(); srv.close();
  console.log('pantalla.js · la pantalla del banco con la base simulada\n' + R.join('\n'));
  const mal = R.filter(l => l.startsWith('  ✗')).length;
  console.log(mal ? `\n${mal} comprobación(es) fallaron` : '\nTodo en orden');
  process.exit(mal ? 1 : 0);
})().catch(e => { console.error('El arnés se cayó:', e); console.log(R.join('\n')); process.exit(2); });
