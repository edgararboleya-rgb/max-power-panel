/* plaid-simulado.mjs — un Plaid de mentira para probar la función de borde
   `plaid` sin salir a internet. Habla como la API de Plaid (2020-09-14) en lo
   que la función usa: /link/token/create, /item/public_token/exchange,
   /accounts/get, /institutions/get_by_id, /transactions/sync, /item/remove.
   Los datos son inventados, con la forma del Sandbox: un banco («Platypus
   Bank») con una cuenta corriente (····4392) y una tarjeta de crédito
   (····1007). El /transactions/sync tiene dos páginas al primer cursor y una
   «ronda 2» (POST /__ronda2) con una quitada (la pendiente que se posteó),
   una modificada y dos nuevas.
   Uso: node pruebas/conta/plaid-simulado.mjs [puerto=8890]
   Llaves: PLAID_CLIENT_ID / PLAID_SECRET del entorno (o prueba-client / prueba-secret). */
import http from 'node:http';
const PUERTO = Number(process.argv[2] || 8890);
const CLIENT_ID = process.env.PLAID_CLIENT_ID || 'prueba-client';
const SECRET = process.env.PLAID_SECRET || 'prueba-secret';
const estado = { linkTokens: new Map(), items: new Map(), llamadas: [], ronda: 1, fallarSync: false };
const ACCTS = [
  { account_id: 'acc-corriente-1', mask: '4392', name: 'Business Complete Checking', official_name: 'Chase Business Complete Checking', type: 'depository', subtype: 'checking',
    balances: { available: 15400.12, current: 15979.78, iso_currency_code: 'USD' } },
  { account_id: 'acc-tarjeta-1', mask: '1007', name: 'Business Gold Card', official_name: 'American Express Business Gold', type: 'credit', subtype: 'credit card',
    balances: { available: 4000, current: 15420.33, iso_currency_code: 'USD', limit: 20000 } },
];
// Plaid: amount POSITIVO = sale dinero. En la tarjeta, un cargo es positivo y un pago negativo.
const RONDA1 = {
  added: [
    { transaction_id: 'tx-c-001', account_id: 'acc-corriente-1', amount: 1000.00, date: '2026-10-02', authorized_date: '2026-10-02', name: 'AMEX EPAYMENT ACH PMT', merchant_name: 'American Express', pending: false, payment_channel: 'other', transaction_code: null },
    { transaction_id: 'tx-c-002', account_id: 'acc-corriente-1', amount: -2500.00, date: '2026-10-06', authorized_date: null, name: 'Zelle payment from CASA PEREZ', merchant_name: null, pending: false, payment_channel: 'other', transaction_code: null },
    { transaction_id: 'tx-c-003p', account_id: 'acc-corriente-1', amount: 450.00, date: '2026-10-10', authorized_date: '2026-10-10', name: 'CHECK 1043', merchant_name: null, pending: true, payment_channel: 'other', transaction_code: 'cheque', check_number: '1043' },
    { transaction_id: 'tx-c-004', account_id: 'acc-corriente-1', amount: 12.00, date: '2026-10-11', authorized_date: null, name: 'MONTHLY SERVICE FEE', merchant_name: null, pending: false, payment_channel: 'other', transaction_code: 'bank charge' },
    { transaction_id: 'tx-t-001', account_id: 'acc-tarjeta-1', amount: 171.98, date: '2026-10-02', authorized_date: '2026-10-01', name: 'CES 1040 TAMPA FL', merchant_name: 'City Electric Supply', pending: false, payment_channel: 'in store', transaction_code: null },
    { transaction_id: 'tx-t-002', account_id: 'acc-tarjeta-1', amount: 13.99, date: '2026-10-08', authorized_date: '2026-10-08', name: 'NFPA NATL FIRE PROTE800-344-3555 MA', merchant_name: 'NFPA', pending: false, payment_channel: 'online', transaction_code: null },
    { transaction_id: 'tx-t-003', account_id: 'acc-tarjeta-1', amount: 45.10, date: '2026-10-15', authorized_date: '2026-10-15', name: "AplPay LOWE'S OF CENTAMPA FL", merchant_name: "Lowe's", pending: false, payment_channel: 'in store', transaction_code: null },
    { transaction_id: 'tx-t-004', account_id: 'acc-tarjeta-1', amount: -1000.00, date: '2026-10-02', authorized_date: null, name: 'MOBILE PAYMENT - THANK YOU', merchant_name: null, pending: false, payment_channel: 'other', transaction_code: 'payment' },
  ],
};
const RONDA2 = {
  added: [
    { transaction_id: 'tx-c-003', account_id: 'acc-corriente-1', amount: 450.00, date: '2026-10-12', authorized_date: '2026-10-10', name: 'CHECK 1043', merchant_name: null, pending: false, pending_transaction_id: 'tx-c-003p', payment_channel: 'other', transaction_code: 'cheque', check_number: '1043' },
    { transaction_id: 'tx-t-005', account_id: 'acc-tarjeta-1', amount: 61.21, date: '2026-10-16', authorized_date: '2026-10-16', name: 'SUNPASS*ACC21813524 888-865-5352 FL', merchant_name: 'SunPass', pending: false, payment_channel: 'online', transaction_code: null },
  ],
  modified: [
    { transaction_id: 'tx-t-003', account_id: 'acc-tarjeta-1', amount: 45.12, date: '2026-10-15', authorized_date: '2026-10-15', name: "AplPay LOWE'S OF CENTAMPA FL", merchant_name: "Lowe's", pending: false, payment_channel: 'in store', transaction_code: null },
  ],
  removed: [{ transaction_id: 'tx-c-003p', account_id: 'acc-corriente-1' }],
};
const json = (res, code, body) => { res.writeHead(code, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(body)); };
const error = (res, code, error_code, msg, error_type = 'INVALID_REQUEST') =>
  json(res, code, { error_type, error_code, error_message: msg, display_message: null, request_id: 'req-' + Date.now() });
const pagina = (extra, cursor, has_more, req_id) => ({ added: [], modified: [], removed: [], ...extra, next_cursor: cursor, has_more, accounts: ACCTS,
  transactions_update_status: 'HISTORICAL_UPDATE_COMPLETE', request_id: req_id });
const srv = http.createServer((req, res) => {
  let cuerpo = '';
  req.on('data', d => { cuerpo += d; });
  req.on('end', () => {
    let b = {}; try { b = JSON.parse(cuerpo || '{}'); } catch { return error(res, 400, 'INVALID_BODY', 'json'); }
    // mandos de la prueba (no son de Plaid)
    if (req.url === '/__estado') return json(res, 200, { llamadas: estado.llamadas, ronda: estado.ronda, items: [...estado.items.values()].map(i => i.item_id) });
    if (req.url === '/__ronda2') { estado.ronda = 2; return json(res, 200, { ronda: 2 }); }
    if (req.url === '/__fallar_sync') { estado.fallarSync = !!b.si; return json(res, 200, { fallarSync: estado.fallarSync }); }
    const cid = req.headers['plaid-client-id'] || b.client_id, sec = req.headers['plaid-secret'] || b.secret;
    estado.llamadas.push({ ruta: req.url, cuerpo: { ...b, secret: sec ? '***' : undefined, access_token: b.access_token ? '***' : undefined } });
    if (cid !== CLIENT_ID || sec !== SECRET) return error(res, 400, 'INVALID_API_KEYS', 'invalid client_id or secret provided', 'INVALID_INPUT');
    if (req.url === '/link/token/create') {
      if (!b.user?.client_user_id || !b.client_name) return error(res, 400, 'INVALID_FIELD', 'user.client_user_id and client_name are required');
      if (!b.access_token && (!Array.isArray(b.products) || !b.products.includes('transactions'))) return error(res, 400, 'INVALID_PRODUCT', 'products must include transactions');
      const t = 'link-sandbox-' + Math.random().toString(36).slice(2, 10);
      estado.linkTokens.set(t, b);
      return json(res, 200, { link_token: t, expiration: new Date(Date.now() + 4 * 3600e3).toISOString(), request_id: 'req-link' });
    }
    if (req.url === '/item/public_token/exchange') {
      if (!/^public-sandbox-/.test(b.public_token || '')) return error(res, 400, 'INVALID_PUBLIC_TOKEN', 'bad public token');
      const n = estado.items.size + 1, access = `access-sandbox-${n}-${Math.random().toString(36).slice(2, 8)}`, item = `item-sim-${n}`;
      estado.items.set(access, { item_id: item });
      return json(res, 200, { access_token: access, item_id: item, request_id: 'req-ex' });
    }
    const it = estado.items.get(b.access_token);
    if (['/accounts/get', '/transactions/sync', '/item/remove', '/accounts/balance/get'].includes(req.url) && !it)
      return error(res, 400, 'INVALID_ACCESS_TOKEN', 'could not find matching access token', 'INVALID_INPUT');
    if (req.url === '/accounts/get' || req.url === '/accounts/balance/get')
      return json(res, 200, { accounts: ACCTS, item: { item_id: it.item_id, institution_id: 'ins_109508' }, request_id: 'req-acc' });
    if (req.url === '/institutions/get_by_id')
      return json(res, 200, { institution: { institution_id: b.institution_id, name: 'Platypus Bank', country_codes: ['US'] }, request_id: 'req-ins' });
    if (req.url === '/transactions/sync') {
      if (estado.fallarSync) return error(res, 400, 'ITEM_LOGIN_REQUIRED', 'the login details of this item have changed', 'ITEM_ERROR');
      const cur = b.cursor || '';
      if (cur === '') return json(res, 200, pagina({ added: RONDA1.added.slice(0, 5) }, 'cursor-r1-p2', true, 'req-s1'));
      if (cur === 'cursor-r1-p2') return json(res, 200, pagina({ added: RONDA1.added.slice(5) }, 'cursor-r1-fin', false, 'req-s2'));
      if (cur === 'cursor-r1-fin') {
        if (estado.ronda < 2) return json(res, 200, pagina({}, 'cursor-r1-fin', false, 'req-s3'));
        return json(res, 200, pagina(RONDA2, 'cursor-r2-fin', false, 'req-s4'));
      }
      if (cur === 'cursor-r2-fin') return json(res, 200, pagina({}, 'cursor-r2-fin', false, 'req-s5'));
      return error(res, 400, 'INVALID_FIELD', 'cursor not valid');
    }
    if (req.url === '/item/remove') { estado.items.delete(b.access_token); return json(res, 200, { removed: true, request_id: 'req-rm' }); }
    return error(res, 404, 'NOT_FOUND', 'ruta desconocida ' + req.url);
  });
});
srv.listen(PUERTO, '127.0.0.1', () => console.log(`plaid simulado en http://127.0.0.1:${PUERTO}`));
