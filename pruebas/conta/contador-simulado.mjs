/* contador-simulado.mjs — un Anthropic de mentira para probar la función de
   borde `contador` (c8, fase 7) sin salir a internet ni gastar un token.
   Habla como POST /v1/messages en lo que la función usa, y EXIGE la forma
   que pide el contrato (si la función se desvía, contesta 400 y la prueba lo
   ve):
     · x-api-key igual a la llave (si no, 401 authentication_error, con la
       llave enmascarada como hace Anthropic); anthropic-version con forma
       de fecha; content-type JSON.
     · model exactamente claude-opus-5-5 (otro → 404 not_found_error: solo
       Opus y Fable, y la función no cambia de modelo).
     · output_config.effort = low; output_config.format = {type: json_schema,
       schema: objeto}; max_tokens entero.
     · system es una lista y system[0] lleva cache_control {type: ephemeral}.
     · messages: un turno user cuyo content es un texto (el JSON del
       movimiento).
     · SIN thinking, SIN tool_choice, SIN fallbacks, SIN stream, SIN
       temperature/top_p/top_k (la regla de la casa: nada de fallbacks ni
       de parámetros que la API nueva rechaza).
   La respuesta trae la forma de Opus 5.5: un bloque thinking vacío delante
   (display omitted) y después el bloque text con el JSON del esquema; usage
   con input_tokens, output_tokens, cache_creation_input_tokens y
   cache_read_input_tokens. EL CACHÉ: la primera petición con un system dado
   (su sha256) devuelve cache_creation_input_tokens > 0 y las siguientes
   cache_read_input_tokens > 0, si el prefijo pasa del mínimo de la API (512
   tokens, estimados a 4 letras por token); por debajo, no cachea, como la de
   verdad. Un prefijo distinto es otro caché. Y como en la de verdad, el caché
   solo se puede leer cuando la petición que lo escribe ya contestó: las que
   llegan a la vez antes de eso lo escriben cada una (por eso la función manda
   la primera sola).

   QUÉ CONTESTA (por palabras clave en el mensaje del usuario, en mayúsculas;
   la primera que casa manda):
     REFUSAL   → stop_reason "refusal" (stop_details.category general_harms), sin contenido
     ROTO      → un texto que no es JSON (la función lo cuenta «inválida»)
     MAXTOKENS → stop_reason "max_tokens" con el JSON cortado
     INVALIDA  → un JSON válido con una cuenta que no existe (9999): la base lo rechaza
     CAIDO     → la PRIMERA vez con ese mensaje, 529 overloaded_error; la siguiente
                 contesta normal (así se prueba el reintento). /__caer {veces,
                 estado?} tumba las N peticiones siguientes, sean cuales sean,
                 con 529 (o el 429 o el 5xx que se le diga).
     HOME DEPOT, LOWE, CES , GRAYBAR, FERRETERIA → 5100 Material, pide_obra, 0.92
     WAWA, SHELL, CHEVRON, RACETRAC, EXXON, SUNOCO, SUNPASS, TOLL → 6300 combustible y vehículos, 0.9
     IRS, USATAXPYMT → 3200 con flag irs, 0.95
     AMAZON    → 6500 Oficina y software con flag use_tax, alternativa 5500, 0.6
     NETFLIX, SPOTIFY, PUBLIX, PERSONAL → 3200 con flag personal, alternativa 1130, 0.85
     ALLY, AUTO LOAN, FORD CREDIT → dos líneas: 2520 (80 %) + 7100 (20 %), 0.7
     DELL, BEST BUY, APPLE → 1530 Cómputo con flag capitalizable si |monto| ≥ 2,500; si no 6500, 0.75
     ZELLE, CHECK → 5200 Subcontratos, pide_obra, 0.45
     NFPA      → 6800 Licencias y cuotas, 0.8
     (nada)    → 7900 Otros gastos, 0.3
   Las cuentas son las de c1-plan-de-cuentas.sql; la base decide si se
   pueden proponer.

   EL CONTROL (solo 127.0.0.1):
     GET  /__peticiones  cada petición recibida: n, hora, las cabeceras (la
                         llave NUNCA: solo si estaba y si era la buena), el
                         cuerpo entero tal cual llegó, y lo que se contestó
                         (estado, stop_reason, usage, caché)
     GET  /__estado      {llamadas, creaciones, lecturas, prefijos:[sha256…],
                          caer, caidos, minimo_cache, lento, en_vuelo, max_en_vuelo}
     POST /__caer {veces, estado?}  las N siguientes contestan 529 (o el
                         estado dado: 429 rate_limit_error, 5xx api_error)
     POST /__lento {ms}  cada respuesta tarda eso (0 = al momento): así las
                         peticiones que la función manda a la vez se pisan
                         de verdad y se ve cuántas iban en vuelo
     POST /__reiniciar      borra las peticiones, el caché y los contadores
   Cada petición anotada lleva además en_vuelo (cuántas otras estaban sin
   contestar cuando llegó: la primera de la ráfaga, 0; las de tres en tres,
   hasta 2), llegada_ms y terminada_ms (reloj del simulador): con eso el e2e
   comprueba «la primera sola y después de tres en tres».
   Uso: node pruebas/conta/contador-simulado.mjs [puerto=8895]
   Llave: ANTHROPIC_API_KEY del entorno (o sk-ant-prueba). */
import http from 'node:http';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

export const MODELO = 'claude-opus-5-5';
export const MINIMO_CACHE = 512;   // tokens: por debajo la API de verdad no cachea
const tokens = (s) => Math.ceil(String(s ?? '').length / 4);
const sha256 = (s) => createHash('sha256').update(String(s)).digest('hex');

// La propuesta de mentira para un movimiento (lo que diría la IA), por las
// palabras clave de su descripción. p.monto en negativo = cargo.
export function proponerDeMentira(mov) {
  const d = `${mov.descripcion ?? ''} ${mov.memo ?? ''} ${mov.desc_norm ?? ''}`.toUpperCase();
  const monto = Math.abs(Number(mov.monto) || 0);
  const tiene = (...k) => k.some((x) => d.includes(x));
  const flags = (f = {}) => ({ capitalizable: false, use_tax: false, personal: false, irs: false, pide_obra: false, ...f });
  const una = (cuenta, motivo, confianza, f, alternativas = [], proyecto_id = null) =>
    ({ lineas: [{ cuenta, monto: null, proyecto_id }], motivo, confianza, flags: flags(f), alternativas });
  if (tiene('INVALIDA')) return una('9999', 'Una cuenta que no existe, a propósito: la base no la debe guardar.', 0.9);
  if (tiene('HOME DEPOT', 'LOWE', 'CES ', 'GRAYBAR', 'FERRETERIA')) {
    return una('5100', `El comercio (${(mov.descripcion ?? '').trim()}) vende material de obra: va a 5100 Material, y la cuenta pide obra, que el movimiento no dice.`, 0.92, { pide_obra: true });
  }
  if (tiene('WAWA', 'SHELL', 'CHEVRON', 'RACETRAC', 'EXXON', 'SUNOCO', 'SUNPASS', 'TOLL')) {
    return una('6300', `Gasolinera o peaje (${(mov.descripcion ?? '').trim()}) por ${monto.toFixed(2)}: combustible y vehículos, 6300.`, 0.9);
  }
  if (tiene('IRS', 'USATAXPYMT')) return una('3200', 'Un pago al IRS por el impuesto de Edgar no es gasto de la empresa: 3200, distribuciones al accionista.', 0.95, { irs: true });
  if (tiene('AMAZON')) {
    return una('6500', `Compra en Amazon por ${monto.toFixed(2)} sin impuesto visible: suministros de oficina (6500); si fue para una obra, 5500.`, 0.6, { use_tax: true },
               [{ cuenta: '5500', motivo: 'si lo comprado fue consumible de una obra' }]);
  }
  if (tiene('NETFLIX', 'SPOTIFY', 'PUBLIX', 'PERSONAL')) {
    return una('3200', `${(mov.descripcion ?? '').trim()} parece un cargo personal en la cuenta de la empresa: 3200 (o 1130 si Edgar lo devuelve).`, 0.85, { personal: true },
               [{ cuenta: '1130', motivo: 'si Edgar lo va a devolver a la empresa' }]);
  }
  if (tiene('ALLY', 'AUTO LOAN', 'FORD CREDIT')) {
    const capital = Math.round(monto * 0.8 * 100) / 100;
    return { lineas: [{ cuenta: '2520', monto: capital, proyecto_id: null }, { cuenta: '7100', monto: Math.round((monto - capital) * 100) / 100, proyecto_id: null }],
             motivo: `La cuota del préstamo del vehículo (${(mov.descripcion ?? '').trim()}): capital a 2520 e intereses a 7100, 80/20 estimado.`,
             confianza: 0.7, flags: flags(), alternativas: [] };
  }
  if (tiene('DELL', 'BEST BUY', 'APPLE')) {
    return monto >= 2500
      ? una('1530', `Equipo de cómputo por ${monto.toFixed(2)}, 2,500 o más y de más de un año de vida: activo fijo (1530), Edgar decide.`, 0.75, { capitalizable: true })
      : una('6500', `Equipo o accesorios de oficina por ${monto.toFixed(2)}: gasto de oficina (6500).`, 0.75);
  }
  if (tiene('ZELLE', 'CHECK')) return una('5200', 'Un pago a una persona desde la cuenta de la empresa: suele ser un subcontrato (5200), que pide obra; no sé cuál.', 0.45, { pide_obra: true });
  if (tiene('NFPA')) return una('6800', 'NFPA es la cuota de la asociación: licencias y cuotas (6800).', 0.8);
  return una('7900', `No reconozco el comercio (${(mov.descripcion ?? '').trim()}): otros gastos (7900) hasta que Edgar diga.`, 0.3);
}

export function crearSimulador({ llave = process.env.ANTHROPIC_API_KEY || 'sk-ant-prueba', puerto = 8895 } = {}) {
  const E = { peticiones: [], cache: new Set(), caidos: new Set(), caer: 0, caerEstado: 529, n: 0, creaciones: 0, lecturas: 0,
              lento: 0, enVuelo: 0, maxEnVuelo: 0 };
  // (como hace Anthropic en su 401, pero sin la cola: ni cuatro letras de la llave salen de aquí)
  const enmascarada = `${llave.slice(0, 7)}…`;
  const error = (estado, tipo, mensaje) => ({ estado, cuerpo: { type: 'error', error: { type: tipo, message: mensaje } } });
  const mal = (m) => error(400, 'invalid_request_error', m);

  // ---- la API ----------------------------------------------------------
  function mensajes(cab, p, anot) {
    if (!cab['x-api-key']) return error(401, 'authentication_error', 'x-api-key header is required');
    if (cab['x-api-key'] !== llave) return error(401, 'authentication_error', `invalid x-api-key: ${enmascarada}`);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(cab['anthropic-version'] ?? '')) return mal('anthropic-version header is required (YYYY-MM-DD)');
    if (!/^application\/json/.test(cab['content-type'] ?? '')) return mal('content-type must be application/json');
    if (!p || typeof p !== 'object') return mal('body must be a JSON object');
    if (p.model !== MODELO) return error(404, 'not_found_error', `model: ${p.model}`);
    if (!Number.isInteger(p.max_tokens) || p.max_tokens < 1) return mal('max_tokens: must be a positive integer');
    for (const k of ['thinking', 'tool_choice', 'fallbacks', 'temperature', 'top_p', 'top_k', 'tools', 'stream']) {
      if (p[k] !== undefined) return mal(`${k}: not supported here (el contrato de c8: sin ${k})`);
    }
    const oc = p.output_config;
    if (!oc || typeof oc !== 'object') return mal('output_config: required (effort y format)');
    if (oc.effort !== 'low') return mal(`output_config.effort: debe ser "low" (llegó ${JSON.stringify(oc.effort)})`);
    if (!oc.format || oc.format.type !== 'json_schema' || !oc.format.schema || typeof oc.format.schema !== 'object') return mal('output_config.format: {type: "json_schema", schema: {...}} required');
    if (oc.format.schema.additionalProperties !== false) return mal('output_config.format.schema: additionalProperties must be false');
    if (!Array.isArray(p.system) || !p.system.length) return mal('system: must be an array of text blocks');
    const s0 = p.system[0];
    if (!s0 || s0.type !== 'text' || typeof s0.text !== 'string') return mal('system[0]: {type: "text", text: "..."} required');
    if (!s0.cache_control || s0.cache_control.type !== 'ephemeral') return mal('system[0].cache_control: {type: "ephemeral"} required (el prefijo cachea)');
    if (!Array.isArray(p.messages) || p.messages.length !== 1 || p.messages[0].role !== 'user') return mal('messages: exactly one user turn expected here');
    const contenido = p.messages[0].content;
    if (typeof contenido !== 'string' || !contenido.trim()) return mal('messages[0].content: a text (the movement as JSON) expected');
    let mov = null;
    try { mov = JSON.parse(contenido); } catch { /* no era JSON: se clasifica por palabras igual */ }
    const texto = mov && typeof mov === 'object' ? mov : { descripcion: contenido };
    anot.movimiento_json = !!mov;
    anot.prefijo = { sha256: sha256(s0.text), tokens: tokens(s0.text), tiene_fecha: /\b20\d\d-\d\d-\d\d\b/.test(s0.text),
                     tiene_uuid: /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i.test(s0.text) };
    const d = contenido.toUpperCase();
    // la caída a propósito: la primera vez con este mensaje
    if (E.caer > 0) {
      E.caer--;
      anot.caida = `por /__caer (${E.caerEstado})`;
      return E.caerEstado === 429 ? error(429, 'rate_limit_error', 'Number of request tokens has exceeded your per-minute rate limit')
        : E.caerEstado === 529 ? error(529, 'overloaded_error', 'Overloaded') : error(E.caerEstado, 'api_error', 'Internal server error');
    }
    if (d.includes('CAIDO') && !E.caidos.has(sha256(contenido))) { E.caidos.add(sha256(contenido)); anot.caida = 'por CAIDO (la primera vez)'; return error(529, 'overloaded_error', 'Overloaded'); }
    // el caché del prefijo
    const largo = tokens(s0.text);
    let creacion = 0, lectura = 0;
    if (largo >= MINIMO_CACHE) {
      if (E.cache.has(anot.prefijo.sha256)) { lectura = largo; E.lecturas++; }
      else { anot.escribe_cache = anot.prefijo.sha256; creacion = largo; E.creaciones++; }
    }
    const entrada = tokens(contenido) + 12;
    const usage = (salida) => ({ input_tokens: entrada, output_tokens: salida, cache_creation_input_tokens: creacion, cache_read_input_tokens: lectura,
                                 cache_creation: { ephemeral_5m_input_tokens: creacion, ephemeral_1h_input_tokens: 0 }, service_tier: 'standard' });
    const id = `msg_SIM${String(++E.n).padStart(4, '0')}`;
    const base = { id, type: 'message', role: 'assistant', model: MODELO, stop_sequence: null };
    if (d.includes('REFUSAL')) {
      return { estado: 200, cuerpo: { ...base, content: [], stop_reason: 'refusal', stop_details: { category: 'general_harms' }, usage: usage(0) } };
    }
    const pensando = { type: 'thinking', thinking: '', signature: 'sim' };
    if (d.includes('ROTO')) {
      const txt = '{"lineas": [{"cuenta": "5100", esto no es JSON';
      return { estado: 200, cuerpo: { ...base, content: [pensando, { type: 'text', text: txt }], stop_reason: 'end_turn', stop_details: null, usage: usage(tokens(txt)) } };
    }
    const propuesta = proponerDeMentira(texto);
    const txt = JSON.stringify(propuesta);
    if (d.includes('MAXTOKENS')) {
      const corto = txt.slice(0, Math.floor(txt.length / 2));
      return { estado: 200, cuerpo: { ...base, content: [pensando, { type: 'text', text: corto }], stop_reason: 'max_tokens', stop_details: null, usage: usage(p.max_tokens) } };
    }
    return { estado: 200, cuerpo: { ...base, content: [pensando, { type: 'text', text: txt }], stop_reason: 'end_turn', stop_details: null, usage: usage(tokens(txt) + 40) } };
  }

  // ---- el control -----------------------------------------------------
  const control = {
    '/__peticiones'() { return { n: E.peticiones.length, peticiones: E.peticiones }; },
    '/__estado'() {
      return { llamadas: E.peticiones.length, creaciones: E.creaciones, lecturas: E.lecturas, prefijos: [...E.cache], caer: E.caer, caidos: E.caidos.size,
               minimo_cache: MINIMO_CACHE, modelo: MODELO, lento: E.lento, en_vuelo: E.enVuelo, max_en_vuelo: E.maxEnVuelo };
    },
    '/__caer'({ veces = 1, estado = 529 } = {}) {
      const e = Number(estado);
      E.caer = Number(veces);
      E.caerEstado = e === 429 || e >= 500 ? e : 529;
      return { caer: E.caer, estado: E.caerEstado };
    },
    '/__lento'({ ms = 0 } = {}) { E.lento = Math.max(0, Math.min(Number(ms) || 0, 30_000)); return { lento: E.lento }; },
    '/__reiniciar'() {
      E.peticiones = []; E.cache = new Set(); E.caidos = new Set(); E.caer = 0; E.caerEstado = 529; E.creaciones = 0; E.lecturas = 0;
      E.lento = 0; E.maxEnVuelo = 0;
      return { ok: true };
    },
  };

  const servidor = http.createServer(async (req, res) => {
    const enviar = (estado, cuerpo, cab = {}) => { res.writeHead(estado, { 'Content-Type': 'application/json', ...cab }); res.end(JSON.stringify(cuerpo)); };
    let crudo = '';
    for await (const trozo of req) crudo += trozo;
    const url = new URL(req.url, `http://127.0.0.1:${puerto}`);
    let enCurso = false; // (si algo revienta a medias, en_vuelo no se queda contado)
    try {
      if (url.pathname.startsWith('/__')) {
        const f = control[url.pathname];
        if (!f) return enviar(404, { error: 'control desconocido' });
        return enviar(200, f(crudo ? JSON.parse(crudo) : {}));
      }
      if (req.method !== 'POST' || url.pathname !== '/v1/messages') {
        return enviar(404, { type: 'error', error: { type: 'not_found_error', message: `Not found: ${req.method} ${url.pathname}` } });
      }
      let p = null;
      try { p = JSON.parse(crudo); } catch { /* se queda en null: 400 abajo */ }
      const cab = req.headers;
      // (cuántas iban sin contestar cuando llegó esta: la ráfaga de la función se ve aquí)
      const enVuelo = E.enVuelo++;
      enCurso = true;
      E.maxEnVuelo = Math.max(E.maxEnVuelo, E.enVuelo);
      // (la llave nunca se guarda: solo si vino y si era la buena)
      const anot = { n: E.peticiones.length + 1, hora: new Date().toISOString(), llegada_ms: Date.now(), en_vuelo: enVuelo, metodo: req.method, ruta: url.pathname,
                     cabeceras: { 'x-api-key': !cab['x-api-key'] ? 'ausente' : cab['x-api-key'] === llave ? 'ok' : 'mala',
                                  'anthropic-version': cab['anthropic-version'] ?? null, 'content-type': cab['content-type'] ?? null,
                                  'anthropic-beta': cab['anthropic-beta'] ?? null },
                     cuerpo: p };
      const r = mensajes(cab, p, anot);
      anot.respuesta = { estado: r.estado, stop_reason: r.cuerpo.stop_reason ?? null, usage: r.cuerpo.usage ?? null, error: r.cuerpo.error ?? null };
      E.peticiones.push(anot);
      const extra = r.estado === 529 || r.estado === 429 ? { 'retry-after': '2' } : {};
      const rid = `req_SIM${String(anot.n).padStart(4, '0')}`;
      if (E.lento) await new Promise((listo) => setTimeout(listo, E.lento));
      // (el prefijo queda en el caché cuando la que lo escribió contesta, no antes)
      if (anot.escribe_cache && r.estado === 200) E.cache.add(anot.escribe_cache);
      anot.terminada_ms = Date.now();
      E.enVuelo--;
      enCurso = false;
      return enviar(r.estado, r.cuerpo, { 'request-id': rid, ...extra });
    } catch (e) {
      if (enCurso) E.enVuelo--;
      return enviar(500, { type: 'error', error: { type: 'api_error', message: `simulado: ${e.message}` } });
    }
  });
  return { servidor, estado: E, escuchar: () => new Promise((r) => servidor.listen(puerto, '127.0.0.1', r)) };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const puerto = Number(process.argv[2] || 8895);
  const sim = crearSimulador({ puerto });
  await sim.escuchar();
  console.log(`listo ${puerto}`);
}
