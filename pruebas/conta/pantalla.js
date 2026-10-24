/* La pantalla del banco (js/conta.js) con la base simulada.
   Lo que se comprueba: que el equipo no ve la entrada y Edgar sí; que la
   pantalla pide el control antes de pintar y se pone en rojo si no cuadra
   (falla ruidosa); que cada botón de la bandeja llama a la función que dijo
   la base con sus argumentos y pide el motivo cuando toca; que el importador
   manda el archivo entero y casa hasta «completo»; que conciliar manda el
   saldo como texto y confirma; y que sin señal no pinta nada de memoria.
   Los datos son inventados (la forma es la de las vistas de c6).
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/conta/pantalla.js
   (con --fotos guarda capturas de cada pantalla en el temporal del sistema,
   o en FOTOS_DIR; sirven para mirarla sin entrar a producción)              */
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
const QR_FALSO = 'data:image/svg+xml;utf-8,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"><rect width="200" height="200" fill="#fff"/><rect x="20" y="20" width="60" height="60"/><rect x="120" y="20" width="60" height="60"/><rect x="20" y="120" width="60" height="60"/></svg>');
const hoyMiami = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());

const MOV = { a: '11111111-1111-4111-8111-111111111111', b: '22222222-2222-4222-8222-222222222222', c: '33333333-3333-4333-8333-333333333333' };
const PART = { p1: 'aaaaaaaa-0000-4000-8000-000000000001', p2: 'aaaaaaaa-0000-4000-8000-000000000002' };
const CONC_AP = 'cccccccc-0000-4000-8000-00000000000a', CONC_NEW = 'cccccccc-0000-4000-8000-00000000000b';
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
        { texto: 'Desde 1030 (Reserva de impuestos)', llamar: 'fn_banco_transferencia', pide_motivo: true, pide: ['p_motivo'], args: { p_movimiento: MOV.b, p_cuenta: '1030' } }
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
    ['6300', 'Vehículos', 'gasto', 'opcional'], ['7100', 'Intereses', 'otro_gasto', 'prohibida']
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
  ]
};
const estado = { controlMal: false, controlFilas: null, fallar: false, casarRondas: 0, concNueva: false, plaidFijada: false, plaidSinVista: false, plaidSinFijar: false, mfaFactores: [], sesionAal: undefined };
const llamadas = [];
function tabla(nombre, q) {
  let filas = T[nombre] || [];
  if (nombre === 'v_conciliacion' && estado.concNueva) filas = filas.concat([{
    conciliacion_id: CONC_NEW, cuenta: '2100-2013', cuenta_nombre: 'Amex Business Gold', fecha_corte: '2026-10-08', periodo: '2026-10', tipo: 'normal', estado: 'abierta', saldo_libros: -14624.26, saldo_statement: 14675.12, saldo_banco: -14675.12,
    depositos_transito: 0, cargos_circulacion: 50.86, sin_casar_banco: 0, n_transito: 1, n_sin_casar: 0, n_alarmas: 0, n_dudosas: 0, n_pide_motivo: 0, diferencia: 0, lista_para_confirmar: true, identidad: 'Libros -14624.26 = banco -14675.12 + (0.00 − 50.86) − 0.00 (cuadra)', falta: null }]);
  if (nombre === 'v_conciliacion_partidas' && estado.concNueva) filas = filas.concat([
    { conciliacion_id: CONC_NEW, cuenta: '2100-2013', fecha_corte: '2026-10-08', conciliacion_estado: 'abierta', grupo: 'en_libros_no_en_banco', partida_id: 'p-new', clase: 'cargo_en_circulacion', fecha: '2026-10-07', monto: -50.86, descripcion: 'Ticket del 7 oct', cheque: null, dias: 1, alarma: false, motivo: null, explicacion: 'Posteado el 7, el banco aún no lo trae.', asiento_numero: '2026-000009', resuelta_en: null, resuelta_por_movimiento: null },
    { conciliacion_id: CONC_NEW, cuenta: '2100-2013', fecha_corte: '2026-10-08', conciliacion_estado: 'abierta', grupo: 'casado', partida_id: null, clase: 'apertura', fecha: '2026-10-01', monto: -31.56, descripcion: 'GASOLINERA EJEMPLO', cheque: null, dias: null, alarma: false, motivo: null, explicacion: 'Casado por R0 apertura (automático).', asiento_numero: null, resuelta_en: null, resuelta_por_movimiento: null }
  ]);
  if (nombre === 'v_plaid_conexiones' && estado.plaidFijada) filas = filas.map(c => ({ ...c, cuentas_sin_fijar: 0, cuentas: c.cuentas.map(a => a.account_id === 'acc-corriente' ? { ...a, cuenta: '1010', propuesta: 'la que fijó Edgar' } : a) }));
  // order=col.desc,col2.asc como PostgREST
  const orden = (q.get('order') || '').split(',').filter(Boolean).map(s => s.split('.'));
  if (orden.length) filas = [...filas].sort((x, y) => { for (const [k, d] of orden) { const a = x[k], b = y[k]; if (a === b) continue; const r = a == null ? 1 : b == null ? -1 : (a > b ? 1 : -1); return d === 'desc' ? -r : r; } return 0; });
  // filtros eq./is. de PostgREST, los que usa la pantalla
  for (const [k, v] of q.entries()) {
    if (['select', 'order', 'limit'].includes(k)) continue;
    const m = /^(eq|is|lte|gte)\.(.*)$/.exec(v); if (!m) continue;
    filas = filas.filter(f => m[1] === 'eq' ? String(f[k]) === m[2] : m[1] === 'is' ? (m[2] === 'null' ? f[k] == null : f[k] === (m[2] === 'true')) : m[1] === 'lte' ? String(f[k]) <= m[2] : String(f[k]) >= m[2]);
  }
  return filas;
}
function rpc(fn, a) {
  if (estado.fallar && /^fn_banco_(casar_con|clasificar|transferencia|ignorar|duplicado)$/.test(fn)) return { error: { code: 'MX008', message: 'La base dijo que no (prueba)' } };
  if (fn === 'fn_banco_control') {
    const hoy = hoyMiami(), desde = hoy.slice(0, 8) + '01';
    const cuenta = v => v === 'v_banco_bandeja' ? T.v_banco_bandeja.filter(f => f.fecha <= hoy).length
      : v === 'v_banco_saldos' ? T.v_banco_saldos.length
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
// Plaid Link de mentira (cdn.plaid.com): «abrir» termina enseguida con éxito
const PLAID_FALSO = "window.Plaid = { create(cfg) { window.__plaidCfg = cfg; return { open() { window.__plaidAbierto = (window.__plaidAbierto || 0) + 1; setTimeout(() => cfg.onSuccess('public-sandbox-prueba', { institution: { name: 'Platypus Bank', institution_id: 'ins_1' } }), 50); }, exit() {}, destroy() {} }; } };";
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS' };
async function simular(ctx, rol) {
  await ctx.addInitScript(([s]) => { localStorage.setItem('mxp_sesion', JSON.stringify(s)); localStorage.removeItem('mxp_idioma'); }, [sesion()]);
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
    if (u.pathname.startsWith('/rest/v1/rpc/')) {
      const fn = u.pathname.slice('/rest/v1/rpc/'.length); let args = {};
      try { args = JSON.parse(req.postData() || '{}'); } catch { /* vacío */ }
      llamadas.push({ fn, args });
      const r = rpc(fn, args);
      if (r && r.error) return route.fulfill({ status: 400, headers: CORS, contentType: 'application/json', body: JSON.stringify(r.error) });
      if (r === null) return route.fulfill({ status: 204, headers: CORS });
      return route.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify(r) });
    }
    if (u.pathname.startsWith('/rest/v1/')) {
      const nombre = u.pathname.slice('/rest/v1/'.length);
      if (req.method() !== 'GET') return route.fulfill({ status: 201, headers: CORS, contentType: 'application/json', body: '[]' });
      let filas = tabla(nombre, u.searchParams);
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
const foto = async (p, nombre) => { if (FOTOS) await p.screenshot({ path: path.join(FOTOS, nombre + '.png'), fullPage: true }); };
const texto = async (p, sel) => (await p.locator(sel).allTextContents()).join(' ');

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
    ok('…ni la entrada en el lateral', (await p.locator('#lateral [data-lat="btn-conta"]').count()) === 0);
    await p.locator('#lateral [data-lat="mas"]').first().evaluate(b => b.click()); await p.waitForTimeout(300);
    ok('…ni la fila en «Más»', (await p.locator('#mas-filas [data-mas="conta"]').count()) === 0);
    await ctx.close();
  }
  // ---- Edgar ----
  const ctx = await b.newContext({ viewport: { width: 1280, height: 900 }, serviceWorkers: 'block' });
  await simular(ctx, 'dueno');
  const p = await ctx.newPage(); p.on('pageerror', e => errs.push('dueño: ' + String(e).slice(0, 160)));
  await p.goto('http://localhost:8873/index.html');
  await p.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await p.waitForTimeout(800);
  await p.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
  ok('Edgar tiene la loseta (escondida en Hoy, como las demás del dueño)', !(await p.locator('#btn-conta').getAttribute('hidden')) );
  ok('…y la entrada «Contabilidad» en el lateral', (await p.locator('#lateral [data-lat="btn-conta"]').count()) === 1);
  await p.locator('#lateral [data-lat="mas"]').first().evaluate(b => b.click()); await p.waitForTimeout(300);
  ok('…y la fila en «Más»', (await p.locator('#mas-filas [data-mas="conta"]').count()) === 1);

  // ---- Bancos y tarjetas: control antes de pintar ----
  let n = llamadas.length;
  await p.locator('#btn-conta').evaluate(b => b.click());
  await p.waitForSelector('#conta-raiz .ct-cuenta', { timeout: 8000 });
  ok('Al entrar, la vista de la contabilidad se ve y el título es «Bancos y tarjetas»', await p.locator('#vista-conta').isVisible() && (await p.locator('#titulo-vista').textContent()).trim() === 'Bancos y tarjetas');
  ok('Pinta una tarjeta por cuenta (4)', (await p.locator('.ct-cuenta').count()) === 4, await p.locator('.ct-cuenta').count());
  const ctrl = desde(n).find(l => l.fn === 'fn_banco_control');
  ok('Pidió el control con la vista que pinta (v_banco_saldos, período hoy)', !!ctrl && ctrl.args.p_periodo === 'hoy' && JSON.stringify(ctrl.args.p_vistas) === '["v_banco_saldos"]', JSON.stringify(ctrl && ctrl.args));
  ok('La Gold dice su deuda en libros ($14,624.26) y la del banco ($14,675.12 al 8 oct)', /\$14,624\.26/.test(await texto(p, '.ct-cuenta[data-cuenta="2100-2013"] .ct-val')) && /\$14,675\.12/.test(await texto(p, '.ct-cuenta[data-cuenta="2100-2013"] .ct-val')) && /8 oct 2026/.test(await texto(p, '.ct-cuenta[data-cuenta="2100-2013"]')));
  ok('El contador de la bandeja dice 3', (await p.locator('#ct-n-bandeja').textContent()).trim() === '3');
  await foto(p, '1-bancos');

  // ---- Falla ruidosa ----
  estado.controlMal = true;
  await p.locator('.ct-tab[data-pag="bancos"]').click(); await p.waitForSelector('.ct-rojo', { timeout: 8000 });
  await foto(p, '2-rojo');
  ok('Control en rojo: la pantalla se pone en rojo y no pinta ninguna cuenta', (await p.locator('.ct-cuenta').count()) === 0 && /no cuadra/.test(await texto(p, '.ct-rojo h2')) && /prueba/.test(await texto(p, '.ct-rojo')));
  estado.controlMal = false; estado.controlFilas = 99;
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('.ct-rojo', { timeout: 8000 }); await p.waitForTimeout(200);
  ok('Si la pantalla trae 4 y el control cuenta 99, también es rojo', /trajo 4 fila\(s\) y el control contó 99/.test(await texto(p, '.ct-rojo')));
  estado.controlFilas = null;
  await p.locator('#ct-reintentar').click(); await p.waitForSelector('.ct-cuenta', { timeout: 8000 });
  ok('Al cuadrar otra vez, vuelve a pintar', (await p.locator('.ct-cuenta').count()) === 4);

  // ---- Importar ----
  n = llamadas.length;
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

  // ---- La bandeja ----
  n = llamadas.length;
  await p.locator('.ct-tab[data-pag="bandeja"]').click(); await p.waitForSelector('.ct-mov', { timeout: 8000 });
  ok('La bandeja pinta los 3 movimientos y pidió su control (v_banco_bandeja)', (await p.locator('.ct-mov').count()) === 3 && desde(n).some(l => l.fn === 'fn_banco_control' && JSON.stringify(l.args.p_vistas) === '["v_banco_bandeja"]'));
  ok('El de más de 30 días va primero, con su alarma', (await p.locator('.ct-mov').first().getAttribute('data-id')) === MOV.c && /más de 30 días/.test(await texto(p, '.ct-mov >> nth=0')));
  const cardB = p.locator(`.ct-mov[data-id="${MOV.b}"]`);
  ok('El que tiene propuesta pinta un botón por opción (4) más «Otra cosa…»', (await cardB.locator('[data-op]').count()) === 4 && (await cardB.locator('[data-otra]').count()) === 1);
  await foto(p, '3-bandeja');
  ok('El sin ticket no tiene botones de la base, solo «Otra cosa…»', (await p.locator(`.ct-mov[data-id="${MOV.a}"] [data-op]`).count()) === 0);
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
  // la opción sin pide: un toque
  await p.waitForSelector(`.ct-mov[data-id="${MOV.b}"] [data-op="0"]`, { timeout: 8000 });
  n = llamadas.length;
  await p.locator(`.ct-mov[data-id="${MOV.b}"] [data-op="0"]`).click();
  await esperarLlamada(p, n, 'fn_banco_casar_con'); await p.waitForTimeout(400);
  const cc = desde(n).find(l => l.fn === 'fn_banco_casar_con');
  ok('La opción sin motivo llama de un toque: fn_banco_casar_con con la partida de apertura', !!cc && cc.args.p_movimiento === MOV.b && cc.args.p_con && cc.args.p_con.partida_apertura === PART.p1, JSON.stringify(cc && cc.args));
  // «Otra cosa…»: clasificar con obra
  n = llamadas.length;
  const cardA = p.locator(`.ct-mov[data-id="${MOV.a}"]`);
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
  await p.waitForSelector(`.ct-mov[data-id="${MOV.a}"] [data-otra]`, { timeout: 8000 });
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
  await p.waitForSelector(`.ct-mov[data-id="${MOV.a}"] [data-otra]`, { timeout: 8000 });
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
  await p.waitForSelector(`.ct-mov[data-id="${MOV.c}"] [data-op="0"]`, { timeout: 8000 });
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
  await p.locator('.ct-tab[data-pag="conciliar"]').click(); await p.waitForSelector('#ct-conc-form', { timeout: 8000 });
  ok('Conciliar lista la apertura confirmada y pidió su control', (await p.locator('[data-conc]').count()) === 1 && desde(n).some(l => l.fn === 'fn_banco_control' && JSON.stringify(l.args.p_vistas) === '["v_conciliacion"]'));
  await p.locator('#ct-conc-form select[name="cuenta"]').selectOption('2100-2013');
  ok('Al elegir la Gold, la fecha y el saldo salen del último archivo (8 oct, 14675.12)', (await p.inputValue('#ct-conc-form input[name="fecha"]')) === '2026-10-08' && (await p.inputValue('#ct-conc-form input[name="saldo"]')) === '14675.12');
  await p.fill('#ct-conc-form input[name="saldo"]', '14,675.12');
  n = llamadas.length;
  await p.locator('#ct-conc-form button[type=submit]').click();
  await p.waitForSelector('#ct-conf', { timeout: 8000 });
  const fc = desde(n).find(l => l.fn === 'fn_conciliar');
  ok('fn_conciliar recibe la cuenta, la fecha y el saldo COMO TEXTO, con su coma', !!fc && fc.args.p_cuenta === '2100-2013' && fc.args.p_fecha_corte === '2026-10-08' && fc.args.p_saldo_statement === '14,675.12', JSON.stringify(fc && fc.args));
  await foto(p, '5-conciliacion');
  ok('Abre la conciliación: título, identidad, las dos listas y «Confirmar» porque está lista', /Conciliación · Amex Business Gold/.test(await p.locator('#titulo-vista').textContent()) && /cuadra/.test(await texto(p, '.ct-nota')) && (await p.locator('.ct-partida').count()) >= 2);
  n = llamadas.length;
  await p.locator('#ct-conf').click(); await p.waitForTimeout(600);
  const cf = desde(n).find(l => l.fn === 'fn_conciliacion_confirmar');
  ok('«Confirmar» llama a fn_conciliacion_confirmar con la conciliación', !!cf && cf.args.p_conciliacion === CONC_NEW);
  // «←»: primero cierra la conciliación, después sale
  await p.locator('#btn-volver').click(); await p.waitForSelector('#ct-conc-form', { timeout: 8000 });
  ok('«←» con la conciliación abierta vuelve a la lista (sigue en la contabilidad)', await p.locator('#vista-conta').isVisible() && (await p.locator('#titulo-vista').textContent()).trim() === 'Conciliar');
  await p.locator('#btn-volver').click(); await p.waitForTimeout(400);
  ok('«←» otra vez sale de la contabilidad', await p.locator('#vista-conta').isHidden());

  // ---- Movimientos ----
  await p.locator('#btn-conta').evaluate(b => b.click()); await p.waitForSelector('.ct-tab', { timeout: 8000 });
  await p.locator('.ct-tab[data-pag="movimientos"]').click(); await p.waitForSelector('#ct-mov-cuenta', { timeout: 8000 });
  ok('Movimientos arranca en la primera cuenta (Chase, sin movimientos de prueba) y lo dice', (await p.inputValue('#ct-mov-cuenta')) === '1010' && /Nada con ese filtro/.test(await texto(p, '.ct-vacio')));
  await p.selectOption('#ct-mov-cuenta', '2100-2013'); await p.waitForSelector('.ct-tabla tbody tr', { timeout: 8000 });
  await foto(p, '6-movimientos');
  ok('Movimientos pinta la tabla de la cuenta (2 filas) con su estado', (await p.locator('.ct-tabla tbody tr').count()) === 2 && /casado/.test(await texto(p, '.ct-tabla')));

  // ---- El código del teléfono (segundo factor) ----
  n = llamadas.length;
  await p.locator('.ct-tab[data-pag="bancos"]').click(); await p.waitForSelector('#ct-mfa', { timeout: 8000 });
  ok('La tarjeta del código del teléfono dice «no activo» y «Conectar un banco» (Plaid) sale apagado', /no activo/.test(await texto(p, '#ct-mfa')) && await p.locator('#ct-plaid-conectar').isDisabled() && /Primero activa el código/.test(await texto(p, '#ct-plaid')));
  await p.locator('#ct-mfa-activar').click();
  await p.waitForSelector('#ct-mfa .ct-qr', { timeout: 8000 });
  const enr = desde(n).find(l => l.fn === 'auth:enrolar');
  ok('«Activar el código» pide el factor TOTP a Supabase Auth y enseña el QR y la clave', !!enr && enr.args.factor_type === 'totp' && enr.args.issuer === 'Max Power Panel' && (await p.locator('#ct-mfa .ct-qr').getAttribute('src')).startsWith('data:image/svg+xml') && /ABCDEFGHIJKLMNOP/.test(await texto(p, '#ct-mfa .ct-clave')), JSON.stringify(enr && enr.args));
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
  await p.locator('.ct-tab[data-pag="bancos"]').click(); await p.waitForSelector('#ct-plaid', { timeout: 8000 });
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
  await p.locator('.ct-tab[data-pag="bancos"]').click(); await p.waitForSelector('#ct-plaid', { timeout: 8000 });
  ok('Sin c7 en la base (la vista no existe), la tarjeta dice «sin instalar» y las cuentas se pintan igual', /sin instalar/.test(await texto(p, '#ct-plaid')) && (await p.locator('.ct-cuenta').count()) === 4, await texto(p, '#ct-plaid'));
  estado.plaidSinVista = false; estado.plaidFijada = false;
  n = llamadas.length;
  await p.waitForSelector('#ct-mfa-quitar', { timeout: 8000 });
  await p.locator('#ct-mfa-quitar').click();
  await p.locator('#ct-mfa .ct-form button[type=submit]').click();
  await p.waitForFunction(() => { const e = document.querySelector('#ct-mfa'); return e && /no activo/.test(e.textContent); }, null, { timeout: 8000 });
  ok('«Quitar el código» pregunta, lo quita en Supabase Auth y la tarjeta vuelve a «no activo»', desde(n).some(l => l.fn === 'auth:quitar') && await p.locator('#ct-plaid-conectar').isDisabled());

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

  // ---- Sin señal ----
  await ctx.setOffline(true);
  await p.locator('.ct-tab[data-pag="bancos"]').click(); await p.waitForSelector('.ct-rojo', { timeout: 8000 });
  ok('Sin señal: «Sin señal» en rojo, ninguna cuenta de memoria', /Sin señal/.test(await texto(p, '.ct-rojo h2')) && (await p.locator('.ct-cuenta').count()) === 0);
  await ctx.setOffline(false);
  await p.waitForSelector('.ct-cuenta', { timeout: 8000 }).catch(() => {});
  ok('Al volver la señal, reintenta sola', (await p.locator('.ct-cuenta').count()) === 4);

  if (FOTOS) {
    const tel = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, serviceWorkers: 'block' });
    await simular(tel, 'dueno');
    const q = await tel.newPage(); q.on('pageerror', e => errs.push('teléfono: ' + String(e).slice(0, 160)));
    await q.goto('http://localhost:8873/index.html'); await q.waitForSelector('#vista-app:not([hidden])', { timeout: 15000 }); await q.waitForTimeout(800);
    await q.evaluate(() => document.querySelectorAll('dialog[open]').forEach(d => d.close()));
    await q.locator('#btn-conta').evaluate(b => b.click()); await q.waitForSelector('.ct-cuenta', { timeout: 8000 }); await foto(q, '7-tel-bancos');
    await q.locator('.ct-tab[data-pag="bandeja"]').click(); await q.waitForSelector('.ct-mov', { timeout: 8000 });
    await q.locator(`.ct-mov[data-id="${MOV.b}"] [data-op="2"]`).click(); await q.waitForTimeout(200); await foto(q, '8-tel-bandeja');
    await tel.close();
  }
  ok('Sin errores de JavaScript en la página', errs.length === 0, errs.join(' | '));
  await b.close(); srv.close();
  console.log('pantalla.js · la pantalla del banco con la base simulada\n' + R.join('\n'));
  const mal = R.filter(l => l.startsWith('  ✗')).length;
  console.log(mal ? `\n${mal} comprobación(es) fallaron` : '\nTodo en orden');
  process.exit(mal ? 1 : 0);
})().catch(e => { console.error('El arnés se cayó:', e); console.log(R.join('\n')); process.exit(2); });
