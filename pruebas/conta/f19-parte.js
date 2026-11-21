/* f19-parte.js — LO QUE fn_bandeja_leer CONTESTA CUANDO SE LE PIDEN UNAS
   TARJETAS ({ids}: la lectura «por partes» de la tercera vuelta), sacado de
   su lectura ENTERA de ese mismo momento.

   La pantalla ya no lee la Bandeja nueva entera después de cada respuesta:
   pide las tarjetas de los hermanos de lo contestado (los demás pendientes
   de la misma contraparte) y funde lo que llega con lo que tenía. En
   pantalla.js la base simulada es la del banco (pantalla-f19.json), y de
   cada paso tiene su lectura entera de después; lo que contestaría a {ids}
   en ese momento es esto: las tarjetas pedidas, los grupos de cargos y los
   lotes que forman ESAS tarjetas (dos o más; los depósitos de un mismo
   pagador solo van en la lectura entera), las listas de la franja enteras,
   y sin lo fijo (las categorías, las cuentas propias, los préstamos, la
   cuadrilla y los proveedores, que la pantalla conserva).

   No es una mentira escrita a mano: f19-capturar.js le pide a la base, en
   cada acción suelta que captura, esa misma lectura por partes, y COMPRUEBA
   que es igual a esta proyección (si un día dejan de coincidir, la captura
   falla y lo dice). */
'use strict';
const FIJO = ['categorias', 'cuentas_propias', 'prestamos', 'cuadrilla', 'proveedores'];
// lo que se compara de un grupo (cuántos y cuánto suman lo cuenta la pantalla con sus filas)
const grupoClave = g => ({ clave: g.clave, clase: g.clase || null, movimientos: g.movimientos, rec: g.rec || null, mixto: g.mixto || null, pendiente: g.pendiente || null, memoria: g.memoria || null, solo_ok: g.solo_ok || null });
function parteDe(entera, ids) {
  const quiero = new Set(ids || []), tarjetas = {};
  for (const id of Object.keys(entera.tarjetas || {})) if (quiero.has(id)) tarjetas[id] = entera.tarjetas[id];
  const grupos = [];
  for (const g of entera.grupos || []) {
    if (g.uno_a_uno) continue;
    const movs = (g.movimientos || []).filter(id => quiero.has(id));
    if (movs.length < 2) continue;
    grupos.push(movs.length === g.movimientos.length ? g : { ...g, movimientos: movs, n: movs.length });
  }
  const r = { ...entera, tarjetas, grupos, parte: true, faltan: [], parcial: false };
  for (const k of FIJO) delete r[k];
  return r;
}
// lo comparable de una lectura por partes (para comprobar la proyección contra lo que contestó la base)
function comparable(r) {
  const { grupos, version, ...x } = r;
  for (const k of FIJO) delete x[k];
  return { ...x, grupos: (grupos || []).map(grupoClave).sort((a, b) => String(a.clave).localeCompare(String(b.clave))) };
}
module.exports = { parteDe, comparable };
