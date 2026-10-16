#!/usr/bin/env python3
"""qfx2sql.py <archivo.qfx|.ofx> <salida.sql> [--cuenta 2013] [--nombre "Amex Gold 2026-10-08"]
Envuelve un archivo OFX/QFX entero en el SQL que Edgar pega en el SQL Editor:
fn_banco_importar_ofx (c6) + fn_banco_casar_todo + el resumen de la cuenta."""
import sys, pathlib, re, argparse
ap = argparse.ArgumentParser()
ap.add_argument('qfx'); ap.add_argument('salida'); ap.add_argument('--cuenta', default=None); ap.add_argument('--nombre', default=None)
a = ap.parse_args()
raw = pathlib.Path(a.qfx).read_bytes()
try: texto = raw.decode('utf-8')
except UnicodeDecodeError: texto = raw.decode('latin-1')
texto = texto.replace('\r\n', '\n').replace('\r', '\n')
tag = 'qfx'
while f'${tag}$' in texto: tag += 'x'
nombre = a.nombre or pathlib.Path(a.qfx).name
lit = lambda s: "'" + s.replace("'", "''") + "'"
cuenta = lit(a.cuenta) if a.cuenta else 'null'
acct = re.search(r'<ACCTID>([^<\n]+)', texto); bal = re.search(r'<LEDGERBAL>.*?<BALAMT>([^<\n]+).*?<DTASOF>([^<\n]+)', texto, re.S)
n = len(re.findall(r'<STMTTRN>', texto))
sql = f"""-- EL BANCO · importar {nombre} (c6): el archivo entero del banco, tal cual. Pegar entero.
-- Mismo archivo otra vez: no entra nada (su sha256). Movimientos: {n}; cuenta del archivo: ····{(acct.group(1).strip()[-4:] if acct else '?')};
-- saldo que trae: {(bal.group(1).strip() + ' al ' + bal.group(2).strip()[:8]) if bal else 'ninguno'}.
select fn_banco_importar_ofx(${tag}${texto}${tag}$, {cuenta}, {lit(nombre)});
select fn_banco_casar_todo({cuenta if a.cuenta else 'null'});
select cuenta, tipo, saldo_libros, saldo_banco, saldo_banco_al, pendientes, pendientes_monto, ultima_conciliacion, alarma from v_banco_saldos order by cuenta;
"""
pathlib.Path(a.salida).write_text(sql, encoding='utf-8')
print(f'ok: {a.salida} ({len(sql)} bytes, {n} movimientos, cuenta ····{acct.group(1).strip()[-4:] if acct else "?"})')
