/* stripe-simulado.mjs — un Stripe de mentira para probar la función de borde
   `stripe` (p1) sin salir a internet. Habla como la API de Stripe
   (2026-09-30.endive) en lo que la función usa, form-urlencoded con
   corchetes (metadata[factura]=…, expand[0]=…), con Idempotency-Key en los
   POST (la misma clave con el mismo cuerpo da la misma respuesta; con otro
   cuerpo, idempotency_error) y 404 resource_missing para lo que no conoce:
     POST /v1/payment_links            (price_data en línea, un solo uso)
     POST|GET /v1/payment_links/:id    GET /v1/payment_links
     GET /v1/checkout/sessions?payment_link=|payment_intent=
     GET /v1/payment_intents[/:id]     GET /v1/charges[?payment_intent=][/:id]
     GET /v1/refunds?payment_intent=   GET /v1/disputes?payment_intent=
     GET /v1/payouts[/:id][?created[gte]=]
     GET /v1/balance_transactions?payout=&limit=&starting_after=&expand[]=data.source
     GET /v1/events?types[]=&created[gte]=&delivery_success=   GET /v1/events/:id
   Los ids son deterministas (plink_SIM0001, cs_test_SIM0001, pi_SIM0001,
   ch_SIM0001 / py_SIM0001, re_, dp_, po_, txn_, evt_), todo en centavos y en
   modo de prueba (livemode false). Comisiones: tarjeta 2.9 % + 30 ¢, cuenta
   de banco (ACH) 0.8 % con tope de 500 ¢, disputa 1500 ¢, ACH fallido 400 ¢.
   La llegada de un depósito es la medianoche UTC de hoy.

   El CONTROL (POST con JSON, solo 127.0.0.1) mueve el mundo y devuelve los
   avisos (eventos completos, como Stripe los mandaría) SIN mandarlos: la
   prueba decide cuáles, cuántas veces y en qué orden.
     /__pagar {plink, medio:'tarjeta'|'ach', verificacion:'instantanea'|'microdepositos'}
     /__pago_suelto {monto, medio}     un pago que no salió de un enlace
     /__liquidar {pi}   /__fallar {pi, codigo}
     /__reembolsar {pi, monto}   /__reembolso_falla {re}
     /__disputa {pi, fase:'abrir'|'ganar'|'perder', monto?}
     /__fee {monto, descripcion}   /__bt {tipo, monto, categoria?}
     /__payout {conciliacion:'completed'|'in_progress'} (junta lo disponible)
     /__payout_conciliar {po}   /__payout_fallar {po, codigo}
     /__caer {veces}  (503)   /__sin_permiso {ruta, metodo?, rak, expand?} | {limpiar:true}
     /__no_entregado {evt | evts}   /__pagina {n}
     /__estado (las llamadas: método, ruta, Stripe-Version, Idempotency-Key,
                si llevaba Bearer —nunca la llave—, y el cuerpo)   /__eventos
   firmar(cuerpo, secreto, t) da la cabecera Stripe-Signature (y
   firmarConFalsa, con una v1 falsa delante, como en una rotación).
   Uso: node pruebas/conta/stripe-simulado.mjs [puerto=8892]
   Llave: STRIPE_SECRET_KEY del entorno (o rk_test_prueba). */
import http from 'node:http';
import { createHmac } from 'node:crypto';
import { fileURLToPath } from 'node:url';

export const VERSION = '2026-09-30.endive';

export function firmar(cuerpo, secreto, t = Math.floor(Date.now() / 1000)) {
  return `t=${t},v1=${createHmac('sha256', secreto).update(`${t}.${cuerpo}`).digest('hex')}`;
}
export function firmarConFalsa(cuerpo, secreto, t = Math.floor(Date.now() / 1000)) {
  const buena = createHmac('sha256', secreto).update(`${t}.${cuerpo}`).digest('hex');
  return `t=${t},v1=${'0'.repeat(64)},v1=${buena},v0=${'f'.repeat(64)}`;
}

// form-urlencoded con corchetes → objeto (a[b][0]=x, a[]=y)
export function leerFormulario(texto) {
  const raiz = {};
  for (const [k, v] of new URLSearchParams(texto)) {
    const m = k.match(/^([^[\]]+)((?:\[[^\]]*\])*)$/);
    if (!m) continue;
    const ruta = [m[1], ...[...m[2].matchAll(/\[([^\]]*)\]/g)].map((x) => x[1])];
    let o = raiz;
    for (let i = 0; i < ruta.length; i++) {
      let p = ruta[i];
      if (p === '') p = String(Object.keys(o).length);
      if (i === ruta.length - 1) o[p] = v;
      else { if (typeof o[p] !== 'object' || o[p] === null) o[p] = {}; o = o[p]; }
    }
  }
  const arreglar = (o) => {
    if (typeof o !== 'object' || o === null) return o;
    const ks = Object.keys(o);
    for (const k of ks) o[k] = arreglar(o[k]);
    if (ks.length && ks.every((k, i) => k === String(i))) return ks.map((k) => o[k]);
    return o;
  };
  return arreglar(raiz);
}

export function crearSimulador({ llave = process.env.STRIPE_SECRET_KEY || 'rk_test_prueba', puerto = 8892 } = {}) {
  const ahora = () => Math.floor(Date.now() / 1000);
  const hoyUTC = () => { const d = new Date(); return Math.floor(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) / 1000); };
  const cont = {};
  const nuevoId = (pre) => { cont[pre] = (cont[pre] || 0) + 1; return `${pre}_SIM${String(cont[pre]).padStart(4, '0')}`; };
  const E = {
    links: new Map(), sesiones: new Map(), pis: new Map(), cargos: new Map(), reembolsos: new Map(), disputas: new Map(),
    payouts: new Map(), bts: [], eventos: [], idem: new Map(), llamadas: [], caer: 0, sinPermiso: [], pagina: 100,
  };
  const enmascarada = `${llave.slice(0, 8)}${'*'.repeat(Math.max(llave.length - 12, 4))}${llave.slice(-4)}`;
  // Lo que se enseña (sin los campos internos _…), copiado
  const publico = (o) => JSON.parse(JSON.stringify(o, (k, v) => (k.startsWith('_') ? undefined : v)));
  const evento = (tipo, objeto, previos) => {
    const ev = { id: nuevoId('evt'), object: 'event', type: tipo, api_version: VERSION, created: ahora(), livemode: false,
                 data: { object: publico(objeto), ...(previos ? { previous_attributes: previos } : {}) }, pending_webhooks: 1,
                 request: { id: null, idempotency_key: null }, _entregado: true };
    E.eventos.push(ev);
    return publico(ev);
  };
  const bt = (tipo, monto, comision, fuente, categoria, estado = 'available') => {
    const b = { id: nuevoId('txn'), object: 'balance_transaction', type: tipo, amount: monto, fee: comision, net: monto - comision,
                fee_details: comision ? [{ type: 'stripe_fee', amount: comision, currency: 'usd', description: 'Stripe processing fees' }] : [],
                currency: 'usd', status: estado, available_on: estado === 'available' ? ahora() : ahora() + 4 * 86400, created: ahora(),
                reporting_category: categoria, source: fuente, _payout: null };
    E.bts.push(b);
    return b;
  };
  const comisionTarjeta = (m) => Math.round(m * 0.029) + 30;
  const comisionAch = (m) => Math.min(Math.round(m * 0.008), 500);
  const fallo = (estado, tipo, mensaje, extra = {}) => ({ estado, cuerpo: { error: { type: tipo, message: mensaje, ...extra } } });
  const noExiste = (id) => fallo(404, 'invalid_request_error', `No such object: '${id}'`, { code: 'resource_missing', param: 'id' });
  const listar = (todo, q, ruta) => {
    let datos = todo;
    if (q.starting_after) { const i = datos.findIndex((x) => x.id === q.starting_after); datos = i >= 0 ? datos.slice(i + 1) : []; }
    const lim = Math.min(Number(q.limit || 10), 100, E.pagina);
    return { estado: 200, cuerpo: { object: 'list', url: ruta, has_more: datos.length > lim, data: datos.slice(0, lim) } };
  };
  const expandir = (q) => [].concat(q.expand || []);
  const fuenteObj = (id) => {
    if (!id) return null;
    const o = E.cargos.get(id) || E.reembolsos.get(id) || E.disputas.get(id) || E.payouts.get(id);
    return o ? publico(o) : id;
  };
  const gte = (q, campo) => { const c = q[campo]; return c && typeof c === 'object' && c.gte !== undefined ? Number(c.gte) : null; };

  // ---- la API ----------------------------------------------------------
  function api(metodo, ruta, q, p) {
    let m;
    if (metodo === 'POST' && ruta === '/v1/payment_links') {
      const li = p.line_items?.[0];
      const pd = li?.price_data;
      if (!li || !pd) return fallo(400, 'invalid_request_error', 'You must provide either price or price_data.', { param: 'line_items[0]' });
      if (pd.currency !== 'usd') return fallo(400, 'invalid_request_error', 'Invalid currency.', { param: 'line_items[0][price_data][currency]' });
      const monto = Number(pd.unit_amount);
      if (!Number.isInteger(monto) || monto < 50 || String(pd.unit_amount) !== String(monto)) return fallo(400, 'invalid_request_error', 'Invalid unit_amount.', { param: 'line_items[0][price_data][unit_amount]' });
      if (!pd.product_data?.name) return fallo(400, 'invalid_request_error', 'Missing required param: line_items[0][price_data][product_data][name].');
      if (li.quantity !== '1') return fallo(400, 'invalid_request_error', 'Missing required param: line_items[0][quantity].');
      const tipos = [].concat(p.payment_method_types || []);
      if (!tipos.length || tipos.some((t) => !['us_bank_account', 'card'].includes(t))) return fallo(400, 'invalid_request_error', 'Invalid payment_method_types.');
      const limite = Number(p.restrictions?.completed_sessions?.limit);
      if (limite !== 1) return fallo(400, 'invalid_request_error', 'restrictions[completed_sessions][limit] tiene que ser 1 aquí.');
      const id = nuevoId('plink');
      const link = { id, object: 'payment_link', active: true, url: `http://127.0.0.1:${puerto}/pagar/${id}`, livemode: false, currency: 'usd',
                     metadata: p.metadata || {}, payment_intent_data: { metadata: p.payment_intent_data?.metadata || {}, description: p.payment_intent_data?.description || null },
                     restrictions: { completed_sessions: { count: 0, limit: limite } }, payment_method_types: tipos,
                     after_completion: p.after_completion || null, inactive_message: p.inactive_message || null, created: ahora(),
                     _monto: monto, _nombre: pd.product_data.name };
      E.links.set(id, link);
      return { estado: 200, cuerpo: publico(link) };
    }
    if ((m = ruta.match(/^\/v1\/payment_links\/([^/]+)$/))) {
      const link = E.links.get(m[1]);
      if (!link) return noExiste(m[1]);
      if (metodo === 'POST') {
        if (p.active !== undefined) {
          const antes = link.active;
          link.active = p.active === 'true';
          if (antes !== link.active) evento('payment_link.updated', link, { active: antes });
        }
      }
      return { estado: 200, cuerpo: publico(link) };
    }
    if (metodo !== 'GET') return fallo(404, 'invalid_request_error', `Unrecognized request URL (${metodo}: ${ruta}).`);
    if (ruta === '/v1/payment_links') return listar([...E.links.values()].reverse().map(publico), q, ruta);
    if (ruta === '/v1/checkout/sessions') {
      const todas = [...E.sesiones.values()].reverse().filter((s) => (!q.payment_link || s.payment_link === q.payment_link) && (!q.payment_intent || s.payment_intent === q.payment_intent));
      return listar(todas.map(publico), q, ruta);
    }
    if ((m = ruta.match(/^\/v1\/payment_intents\/([^/]+)$/))) { const o = E.pis.get(m[1]); return o ? { estado: 200, cuerpo: publico(o) } : noExiste(m[1]); }
    if (ruta === '/v1/payment_intents') return listar([...E.pis.values()].reverse().map(publico), q, ruta);
    if ((m = ruta.match(/^\/v1\/charges\/([^/]+)$/))) { const o = E.cargos.get(m[1]); return o ? { estado: 200, cuerpo: publico(o) } : noExiste(m[1]); }
    if (ruta === '/v1/charges') {
      const exp = expandir(q).includes('data.balance_transaction');
      const todos = [...E.cargos.values()].reverse().filter((c) => !q.payment_intent || c.payment_intent === q.payment_intent)
        .map((c) => { const x = publico(c); if (exp && x.balance_transaction) x.balance_transaction = publico(E.bts.find((b) => b.id === x.balance_transaction)); return x; });
      return listar(todos, q, ruta);
    }
    if (ruta === '/v1/refunds') return listar([...E.reembolsos.values()].reverse().filter((r) => !q.payment_intent || r.payment_intent === q.payment_intent).map(publico), q, ruta);
    if (ruta === '/v1/disputes') return listar([...E.disputas.values()].reverse().filter((d) => !q.payment_intent || d.payment_intent === q.payment_intent).map(publico), q, ruta);
    if ((m = ruta.match(/^\/v1\/payouts\/([^/]+)$/))) { const o = E.payouts.get(m[1]); return o ? { estado: 200, cuerpo: publico(o) } : noExiste(m[1]); }
    if (ruta === '/v1/payouts') {
      const desde = gte(q, 'created');
      return listar([...E.payouts.values()].reverse().filter((x) => desde === null || x.created >= desde).map(publico), q, ruta);
    }
    if (ruta === '/v1/balance') {
      const disp = E.bts.filter((b) => !b._payout && b.status === 'available').reduce((t, b) => t + b.net, 0);
      const pend = E.bts.filter((b) => !b._payout && b.status !== 'available').reduce((t, b) => t + b.net, 0);
      return { estado: 200, cuerpo: { object: 'balance', livemode: false, available: [{ amount: disp, currency: 'usd' }],
                                      pending: [{ amount: pend, currency: 'usd' }] } };
    }
    if (ruta === '/v1/balance_transactions') {
      const exp = expandir(q).includes('data.source');
      if (q.payout && !E.payouts.has(q.payout)) return noExiste(q.payout);
      if (q.payout && !E.payouts.get(q.payout).automatic) return fallo(400, 'invalid_request_error', 'Balance transaction history can only be filtered on automatic transfers, not manual.');
      const todos = [...E.bts].reverse().filter((b) => !q.payout || b._payout === q.payout)
        .map((b) => { const x = publico(b); if (exp) x.source = fuenteObj(b.source); return x; });
      return listar(todos, q, ruta);
    }
    if ((m = ruta.match(/^\/v1\/events\/([^/]+)$/))) { const o = E.eventos.find((e) => e.id === m[1]); return o ? { estado: 200, cuerpo: publico(o) } : noExiste(m[1]); }
    if (ruta === '/v1/events') {
      const tipos = [].concat(q.types || []);
      const desde = gte(q, 'created');
      const todos = [...E.eventos].reverse().filter((e) => (!tipos.length || tipos.includes(e.type)) && (desde === null || e.created >= desde)
        && (q.delivery_success === undefined || String(e._entregado) === q.delivery_success));
      return listar(todos.map(publico), q, ruta);
    }
    return fallo(404, 'invalid_request_error', `Unrecognized request URL (${metodo}: ${ruta}).`);
  }

  // ---- el control (mueve el mundo) --------------------------------------
  const pagoCon = (pi) => { const o = E.pis.get(pi); if (!o) throw new Error(`no conozco ${pi}`); return o; };
  const sesionDe = (pi) => [...E.sesiones.values()].find((s) => s.payment_intent === pi);
  const crearCargo = (pi, medio, estado) => {
    const ach = medio === 'ach';
    const c = { id: nuevoId(ach ? 'py' : 'ch'), object: 'charge', amount: pi.amount, amount_refunded: 0, refunded: false, currency: 'usd', status: estado,
                paid: estado === 'succeeded', payment_intent: pi.id, metadata: { ...pi.metadata }, created: ahora(), disputed: false,
                balance_transaction: null, failure_balance_transaction: null, failure_code: null, failure_message: null, livemode: false,
                billing_details: { email: 'cliente@ejemplo.com', name: 'Cliente Ejemplo', phone: null, address: null },
                payment_method_details: ach ? { type: 'us_bank_account', us_bank_account: { last4: '6789', routing_number: '110000000', bank_name: 'STRIPE TEST BANK' } }
                                            : { type: 'card', card: { brand: 'visa', last4: '4242' } } };
    const b = bt(ach ? 'payment' : 'charge', pi.amount, ach ? comisionAch(pi.amount) : comisionTarjeta(pi.amount), c.id, 'charge', ach && estado !== 'succeeded' ? 'pending' : 'available');
    c.balance_transaction = b.id;
    E.cargos.set(c.id, c);
    pi.latest_charge = c.id;
    return c;
  };
  const crearPago = (monto, metadata, descripcion) => {
    const pi = { id: nuevoId('pi'), object: 'payment_intent', amount: monto, amount_received: 0, currency: 'usd', status: 'requires_payment_method',
                 livemode: false, created: ahora(), metadata: { ...(metadata || {}) }, description: descripcion || null, latest_charge: null,
                 last_payment_error: null, cancellation_reason: null, next_action: null, payment_method_types: ['us_bank_account', 'card'],
                 receipt_email: 'cliente@ejemplo.com' };
    E.pis.set(pi.id, pi);
    return pi;
  };
  const control = {
    '/__pagar'({ plink, medio = 'tarjeta', verificacion = 'instantanea' }) {
      const link = E.links.get(plink);
      if (!link) throw new Error(`no conozco ${plink}`);
      if (!link.active) throw new Error(`${plink} no está activo`);
      const eventos = [];
      const pi = crearPago(link._monto, link.payment_intent_data.metadata, link.payment_intent_data.description);
      const s = { id: nuevoId('cs_test'), object: 'checkout.session', mode: 'payment', status: 'complete', payment_status: 'unpaid', amount_total: link._monto,
                  currency: 'usd', payment_link: plink, payment_intent: pi.id, metadata: { ...link.metadata }, livemode: false, created: ahora(),
                  customer_details: { email: 'cliente@ejemplo.com', name: 'Cliente Ejemplo', phone: null, address: { country: 'US' } } };
      E.sesiones.set(s.id, s);
      let cargo = null;
      if (medio === 'tarjeta') {
        cargo = crearCargo(pi, 'tarjeta', 'succeeded');
        pi.status = 'succeeded'; pi.amount_received = pi.amount; s.payment_status = 'paid';
        eventos.push(evento('checkout.session.completed', s), evento('payment_intent.succeeded', pi), evento('charge.succeeded', cargo));
      } else if (verificacion === 'microdepositos') {
        pi.status = 'requires_action'; pi.next_action = { type: 'verify_with_microdeposits', verify_with_microdeposits: { hosted_verification_url: `http://127.0.0.1:${puerto}/verificar/${pi.id}` } };
        eventos.push(evento('checkout.session.completed', s), evento('payment_intent.requires_action', pi));
      } else {
        cargo = crearCargo(pi, 'ach', 'pending');
        pi.status = 'processing';
        eventos.push(evento('checkout.session.completed', s), evento('payment_intent.processing', pi), evento('charge.pending', cargo));
      }
      link.restrictions.completed_sessions.count++;
      if (link.restrictions.completed_sessions.count >= link.restrictions.completed_sessions.limit && link.active) {
        link.active = false;
        eventos.push(evento('payment_link.updated', link, { active: true }));
      }
      return { pi: pi.id, sesion: s.id, cargo: cargo?.id ?? null, monto: pi.amount, eventos };
    },
    '/__pago_suelto'({ monto, medio = 'tarjeta' }) {
      const pi = crearPago(Number(monto), {}, 'Pago suelto');
      const cargo = crearCargo(pi, medio, 'succeeded');
      pi.status = 'succeeded'; pi.amount_received = pi.amount;
      return { pi: pi.id, cargo: cargo.id, eventos: [evento('payment_intent.succeeded', pi), evento('charge.succeeded', cargo)] };
    },
    '/__liquidar'({ pi: id }) {
      const pi = pagoCon(id);
      const eventos = [];
      if (pi.status === 'requires_action') {
        pi.next_action = null; pi.status = 'processing';
        crearCargo(pi, 'ach', 'pending');
        eventos.push(evento('payment_intent.processing', pi));
      }
      const c = E.cargos.get(pi.latest_charge);
      c.status = 'succeeded'; c.paid = true;
      E.bts.find((b) => b.id === c.balance_transaction).status = 'available';
      pi.status = 'succeeded'; pi.amount_received = pi.amount;
      eventos.push(evento('payment_intent.succeeded', pi), evento('charge.succeeded', c));
      const s = sesionDe(pi.id);
      if (s) { s.payment_status = 'paid'; eventos.push(evento('checkout.session.async_payment_succeeded', s)); }
      return { pi: pi.id, eventos };
    },
    '/__fallar'({ pi: id, codigo = 'insufficient_funds' }) {
      const pi = pagoCon(id);
      const eventos = [];
      const c = pi.latest_charge ? E.cargos.get(pi.latest_charge) : null;
      if (c) {
        c.status = 'failed'; c.failure_code = codigo; c.failure_message = 'The customer\'s account has insufficient funds to cover this payment.';
        E.bts.find((b) => b.id === c.balance_transaction).status = 'available';
        const r = bt('payment_failure_refund', -c.amount, 0, c.id, 'charge_failure');
        c.failure_balance_transaction = r.id;
        bt('stripe_fee', -400, 0, null, 'fee');
        eventos.push(evento('charge.failed', c));
      }
      pi.status = 'requires_payment_method';
      pi.last_payment_error = { type: 'invalid_request_error', code: codigo, message: 'The customer\'s account has insufficient funds to cover this payment.', payment_method_type: 'us_bank_account' };
      eventos.push(evento('payment_intent.payment_failed', pi));
      const s = sesionDe(pi.id);
      if (s) eventos.push(evento('checkout.session.async_payment_failed', s));
      return { pi: pi.id, eventos };
    },
    '/__reembolsar'({ pi: id, monto }) {
      const pi = pagoCon(id);
      const c = E.cargos.get(pi.latest_charge);
      const cuanto = Number(monto ?? c.amount - c.amount_refunded);
      const r = { id: nuevoId('re'), object: 'refund', amount: cuanto, charge: c.id, payment_intent: pi.id, currency: 'usd', status: 'succeeded',
                  balance_transaction: null, failure_balance_transaction: null, failure_reason: null, created: ahora(), metadata: {} };
      E.reembolsos.set(r.id, r);
      r.balance_transaction = bt(c.payment_method_details.type === 'card' ? 'refund' : 'payment_refund', -cuanto, 0, r.id, 'refund').id;
      const antes = c.amount_refunded;
      c.amount_refunded += cuanto; c.refunded = c.amount_refunded >= c.amount;
      return { re: r.id, eventos: [evento('charge.refunded', c, { amount_refunded: antes }), evento('refund.created', r), evento('refund.updated', r)] };
    },
    '/__reembolso_falla'({ re }) {
      const r = E.reembolsos.get(re);
      if (!r) throw new Error(`no conozco ${re}`);
      r.status = 'failed'; r.failure_reason = 'lost_or_stolen_card';
      r.failure_balance_transaction = bt('refund_failure', r.amount, 0, r.id, 'refund_failure').id;
      const c = E.cargos.get(r.charge);
      c.amount_refunded -= r.amount; c.refunded = false;
      return { re, eventos: [evento('refund.failed', r), evento('refund.updated', r)] };
    },
    '/__disputa'({ pi: id, fase, monto }) {
      const pi = pagoCon(id);
      const c = E.cargos.get(pi.latest_charge);
      let d = [...E.disputas.values()].find((x) => x.payment_intent === pi.id && !['won', 'lost'].includes(x.status));
      const eventos = [];
      if (fase === 'abrir') {
        const cuanto = Number(monto ?? c.amount);
        d = { id: nuevoId('dp'), object: 'dispute', amount: cuanto, charge: c.id, payment_intent: pi.id, currency: 'usd', reason: 'fraudulent',
              status: 'needs_response', is_charge_refundable: false, created: ahora(), evidence_details: { due_by: ahora() + 7 * 86400 },
              balance_transactions: [], livemode: false };
        E.disputas.set(d.id, d);
        d.balance_transactions.push(publico(bt('adjustment', -cuanto, 1500, d.id, 'dispute')));
        c.disputed = true;
        eventos.push(evento('charge.dispute.created', d), evento('charge.dispute.funds_withdrawn', d));
      } else if (fase === 'ganar') {
        d.balance_transactions.push(publico(bt('adjustment', d.amount, 0, d.id, 'dispute_reversal')));
        d.status = 'won';
        eventos.push(evento('charge.dispute.funds_reinstated', d), evento('charge.dispute.closed', d));
      } else {
        d.status = 'lost';
        eventos.push(evento('charge.dispute.closed', d));
      }
      return { dp: d.id, eventos };
    },
    '/__fee'({ monto, descripcion }) { const b = bt('stripe_fee', -Number(monto), 0, null, 'fee'); b.description = descripcion || 'Stripe fee'; return { txn: b.id }; },
    '/__bt'({ tipo, monto, categoria }) { return { txn: bt(tipo, Number(monto), 0, null, categoria || 'other_adjustment').id }; },
    '/__payout'({ conciliacion = 'completed' } = {}) {
      const juntas = E.bts.filter((b) => b._payout === null && b.status === 'available' && b.type !== 'payout');
      const neto = juntas.reduce((s, b) => s + b.net, 0);
      if (neto <= 0) throw new Error(`no hay saldo para un depósito (${neto})`);
      const po = { id: nuevoId('po'), object: 'payout', amount: neto, currency: 'usd', arrival_date: hoyUTC(), automatic: true, status: 'paid', method: 'standard',
                   type: 'bank_account', destination: 'ba_SIM0001', balance_transaction: null, failure_balance_transaction: null, failure_code: null,
                   failure_message: null, reconciliation_status: conciliacion, statement_descriptor: null, trace_id: { status: 'pending', value: null },
                   created: ahora(), livemode: false };
      E.payouts.set(po.id, po);
      for (const b of juntas) b._payout = po.id;
      const propio = bt('payout', -neto, 0, po.id, 'payout');
      propio._payout = po.id;
      po.balance_transaction = propio.id;
      return { po: po.id, monto: neto, llegada: new Date(po.arrival_date * 1000).toISOString().slice(0, 10), lineas: juntas.length + 1,
               eventos: [evento('payout.paid', po)] };
    },
    '/__payout_conciliar'({ po: id }) {
      const po = E.payouts.get(id);
      po.reconciliation_status = 'completed';
      return { po: id, eventos: [evento('payout.reconciliation_completed', po)] };
    },
    '/__payout_fallar'({ po: id, codigo = 'account_closed' }) {
      const po = E.payouts.get(id);
      po.status = 'failed'; po.failure_code = codigo; po.failure_message = 'The bank account has been closed.';
      po.failure_balance_transaction = bt('payout_failure', po.amount, 0, po.id, 'payout_reversal').id;
      return { po: id, eventos: [evento('payout.failed', po)] };
    },
    '/__caer'({ veces = 1 }) { E.caer = Number(veces); return { caer: E.caer }; },
    '/__sin_permiso'({ ruta, metodo, rak, expand, limpiar }) {
      // (expand: solo cuando la petición expande eso, p. ej. data.source = «Balance transaction sources»)
      if (limpiar) E.sinPermiso = []; else E.sinPermiso.push({ ruta, metodo: metodo || null, rak, expand: expand || null });
      return { reglas: E.sinPermiso.length };
    },
    '/__no_entregado'({ evt, evts }) {
      for (const id of [].concat(evts || [], evt ? [evt] : [])) { const e = E.eventos.find((x) => x.id === id); if (e) e._entregado = false; }
      return { ok: true };
    },
    '/__pagina'({ n = 100 }) { E.pagina = Number(n); return { pagina: E.pagina }; },
    '/__estado'() {
      return { llamadas: E.llamadas, links: [...E.links.values()].map(publico), payouts: [...E.payouts.values()].map(publico),
               bts: E.bts.map((b) => ({ ...publico(b), payout: b._payout })), pis: [...E.pis.values()].map(publico) };
    },
    '/__eventos'() { return { eventos: E.eventos.map((e) => ({ ...publico(e), entregado: e._entregado })) }; },
  };

  const servidor = http.createServer(async (req, res) => {
    const enviar = (estado, cuerpo, cab = {}) => { res.writeHead(estado, { 'Content-Type': 'application/json', ...cab }); res.end(JSON.stringify(cuerpo)); };
    let crudo = '';
    for await (const trozo of req) crudo += trozo;
    const url = new URL(req.url, `http://127.0.0.1:${puerto}`);
    try {
      if (url.pathname.startsWith('/__')) {
        const f = control[url.pathname];
        if (!f) return enviar(404, { error: 'control desconocido' });
        return enviar(200, f(crudo ? JSON.parse(crudo) : {}));
      }
      if (!url.pathname.startsWith('/v1/')) return enviar(404, { error: { type: 'invalid_request_error', message: 'Unrecognized request URL.' } });
      const metodo = req.method;
      const auth = req.headers.authorization || '';
      const version = req.headers['stripe-version'] || null;
      const idem = req.headers['idempotency-key'] || null;
      const q = leerFormulario(url.search.slice(1));
      const p = metodo === 'POST' ? leerFormulario(crudo) : {};
      E.llamadas.push({ metodo, ruta: url.pathname, version, idem, bearer: /^Bearer /.test(auth), consulta: q, cuerpo: p });
      if (E.caer > 0) { E.caer--; return enviar(503, { error: { type: 'api_error', message: 'Stripe simulado: caído a propósito.' } }); }
      if (auth !== `Bearer ${llave}`) return enviar(401, { error: { type: 'invalid_request_error', message: `Invalid API Key provided: ${enmascarada}` } });
      if (version !== VERSION) return enviar(400, { error: { type: 'invalid_request_error', message: `Invalid Stripe API version: ${version}` } });
      const regla = E.sinPermiso.find((r) => url.pathname.startsWith(r.ruta) && (!r.metodo || r.metodo === metodo)
        && (!r.expand || expandir(q).includes(r.expand)));
      if (regla) {
        return enviar(403, { error: { type: 'invalid_request_error', message: `The provided key '${enmascarada}' does not have the required permissions for this endpoint on account 'acct_SIM0001'. Having the '${regla.rak}' permission would allow this request to continue.` } });
      }
      if (metodo === 'POST') {
        if (!idem) return enviar(400, { error: { type: 'invalid_request_error', message: 'Este simulado exige Idempotency-Key en todo POST.' } });
        const firma = `${metodo} ${url.pathname} ${JSON.stringify(p)}`;
        const guardada = E.idem.get(idem);
        if (guardada) {
          if (guardada.firma !== firma) return enviar(400, { error: { type: 'idempotency_error', message: 'Keys for idempotent requests can only be used with the same parameters they were first used with. Try using a key other than \'' + idem + '\' if you meant to execute a different request.' } });
          return enviar(guardada.estado, guardada.cuerpo, { 'Idempotent-Replayed': 'true' });
        }
        const r = api(metodo, url.pathname, q, p);
        E.idem.set(idem, { firma, estado: r.estado, cuerpo: r.cuerpo });
        return enviar(r.estado, r.cuerpo);
      }
      const r = api(metodo, url.pathname, q, p);
      return enviar(r.estado, r.cuerpo);
    } catch (e) {
      return enviar(500, { error: { type: 'api_error', message: `simulado: ${e.message}` } });
    }
  });
  return { servidor, estado: E, escuchar: () => new Promise((r) => servidor.listen(puerto, '127.0.0.1', r)) };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const puerto = Number(process.argv[2] || 8892);
  const sim = crearSimulador({ puerto });
  await sim.escuchar();
  console.log(`listo ${puerto}`);
}
