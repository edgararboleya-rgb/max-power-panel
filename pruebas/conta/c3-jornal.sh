#!/usr/bin/env bash
# =====================================================================
# c3-jornal.sh — lo que c3-pruebas.sql solo puede fingir: EL DEVENGO
# ESTÁNDAR DE c3 CON ZELLE DE VERDAD (los jornales de c10) dentro, cada uno
# confirmado como lo confirma la app, CON Y SIN NÓMINA (c15) en el mismo
# mes (14-nov-2026, Fase 11c).
#
#   ./c3-jornal.sh [nombre_bd]      (por defecto c3_jornal)
#
# Crea su base con c1 + c2 + c3 + c4 + c6 + c10 + c9, SIN la nómina; a
# mitad pega c15 encima, sin volver a pegar c3 (c3 lee los jornales y la
# nómina al vuelo, lleguen cuando lleguen). Dos obras; un jornalero que
# cobra por Zelle (20 la hora) y tres personas de la nómina de Gusto (25 y
# 30 la hora, y el oficial), con sus horas de diciembre de 2026 y de enero
# de 2027, y los Zelle del jornalero en la Bandeja (los lunes, por la
# semana anterior; el pago no es horas × tarifa):
#     Z1  14-dic  451.00  la semana del 7 al 13-dic   (horas ya aprobadas)
#     Z2  21-dic  330.00  la semana del 14 al 20-dic  (horas SIN aprobar)
#     Z3   4-ene  352.00  el 28 y el 29-dic           (horas SIN aprobar)
#     Z9  30-dic   84.00  el 30-dic   (solo para la escena del mes cerrado)
#     Z5  11-ene  336.00  la semana del 4 al 10-ene
#     Z6  19-ene  294.00  la semana del 11 al 17-ene
#     ZA   8-mar  301.00  la semana del 1 al 7-mar    (la escena de las dos
#     ZB  15-mar  252.00  la semana del 8 al 14-mar    sesiones a la vez)
#     ZC   9-abr  170.00  la semana del 5 al 11-abr   (la escena del devengo
#     ZD  16-abr  126.00  la semana del 12 al 18-abr   que se queda sin horas)
# y la nómina del 22-ene (el journal sintético de
# pruebas/conta/nomina/zz-payroll-journal.csv: período 3 a 16-ene).
# El reloj de la base va por delante (fn_fecha_miami, fingida), para que
# las fechas sean siempre las mismas; al final se deja como estaba.
#
# DICIEMBRE, SIN NÓMINA:
#   1. EL MES DEVENGADO, Y LLEGA UN ZELLE DE ESE MES. Diciembre devengado
#      con todas sus horas aprobadas (840.00). «Así es» en el Z1 (un pago
#      del 14-dic por horas que el devengo ya llevaba): al confirmar, el
#      devengo se pone al día SOLO (queda lo que nadie pagó: 400.00), y lo
#      dice su asiento, con el asiento del jornal. Ni el control «devengo»
#      de c3, ni el cuadre 50 de c10, ni las filas del cierre que los miran
#      (130+ y 170) pasan por rojo. (Antes: el devengo se quedaba en 840.00,
#      el cuadre 50 en rojo y el cierre detenido; la única salida era
#      retirar a mano el devengo del mes.)
#   2. EL «ASÍ ES» QUE APRUEBA Y PAGA DENTRO DEL MES (el Z2): sus horas no
#      estaban aprobadas; las aprueba y las paga el 21-dic: el devengo NO
#      cambia (el mismo asiento). (Antes: el control «devengo» en rojo —«ya
#      no es el de las horas aprobadas de hoy»— y, al devengar otra vez, el
#      cuadre 50 en rojo.)
#   3. EL ZELLE DEL MES SIGUIENTE (el Z3, del 4-ene, por horas del 28 y el
#      29-dic que estaban sin aprobar): trabajadas en diciembre y pagadas
#      después: el devengo de diciembre las lleva (720.00), solo; se deshace
#      el día 1 y el pago real entra en enero: cada hora, una vez.
#   4. LA MISMA RESPUESTA EN TODA SESIÓN: el SQL Editor, el dueño sin el
#      código del teléfono y con él ven el mismo control y el mismo devengo.
#   5. LA VUELTA. «Deshacer» el reparto del Z1: sus horas vuelven al
#      devengo, solo (1160.00). Des-casar el Z2 EN LA BANDEJA (c6 reversa su
#      asiento y no sabe del jornal): sus horas —que el «Así es» dejó
#      aprobadas— entran al devengo, solo (1460.00); el reparto queda suelto
#      (lo dice c10, su cuadre 20) y «Deshacer» lo cierra. Repartido otra
#      vez, salen (1160.00).
#   6. SI EL DEVENGO NO SE PUDO PONER AL DÍA (el trigger apagado un instante:
#      como si el libro lo hubiera rechazado): el Z1 entra igual, y queda
#      dicho donde se mira: el control «devengo» (cuenta 22 h que un jornal
#      ya pagó, con su asiento), el cuadre 50 y el cierre; el mes NO se
#      cierra así (MX008, y dice cómo); fn_horas_devengar lo pone al día
#      (720.00) y todo vuelve a verde.
#   7. UN MES CERRADO NO SE TOCA (dentro de una transacción que se deshace):
#      diciembre, con su devengo al día, SE CIERRA; el Z9 —su movimiento es
#      del 30-dic— entra el primer día del mes abierto, y el devengo de
#      diciembre es el mismo asiento; el control lo deja dicho sin ponerse
#      en rojo (la hora que su «Así es» aprobó, con el mes ya cerrado).
# ENERO, CON LA NÓMINA EN EL MISMO MES (c15, encima, sin tocar c3):
#   8. Enero devengado ANTES de sus pagos (2285.00). El Z5 (11-ene) saca sus
#      horas (1965.00); la nómina del 22-ene, al postear, las suyas (885.00):
#      el asiento del devengo nombra el journal y el asiento del jornal; el
#      Z6 (19-ene), las suyas: queda solo lo que NINGUNO de los dos pagó
#      (605.00), al centavo. Entre diciembre, enero y febrero, el 5000 de
#      las obras es el del journal y el 5200 el de los Zelle: nada dos veces.
#   9. LAS ANULACIONES. Anular la nómina: vuelven sus horas, y las del
#      jornal siguen fuera (1685.00); posteada otra vez, 605.00. «Deshacer»
#      el Z5: vuelven las suyas, y las de la nómina siguen fuera (925.00);
#      repartido otra vez, 605.00. El control, en verde cada vez.
#  10. UN MES GRANDE (dentro de una transacción que se deshace): febrero con
#      3,000 reportes de horas (1,500 devengados y 1,500 de 30 jornaleros,
#      pagados por 300 jornales del mes) y 3,000 repartos en la base (años
#      de Zelle): el control de los puentes contesta al dueño por la API en
#      menos de 1 s y sigue en verde, y repartir un Zelle más (el devengo
#      se pone al día al confirmar, con el mes así) cabe de sobra en el tope
#      de la API.
# MARZO, DOS SESIONES A LA VEZ:
#  11. EL JORNAL A LA VEZ QUE EL DEVENGO, en los dos órdenes (dos sesiones de
#      verdad; cada una confirma). (a) EL JORNAL PRIMERO: «Así es» en el ZA
#      y, antes de que confirme, Edgar devenga marzo en otra sesión: el
#      devengo ESPERA su turno antes de mirar las horas (el candado de la
#      cadena del libro) y entra ya sin las del jornal (440.00, no 720.00);
#      nada pasa por rojo. (Antes de la Fase 11c entraba con lo que había
#      visto antes: las horas del jornal, dos veces en el mes.) (b) EL
#      DEVENGO PRIMERO: con una hora más aprobada a mano (el control lo dice
#      mientras), Edgar devenga otra vez y, antes de que confirme, «Así es»
#      en el ZB en otra sesión: el jornal espera su turno, ve el devengo
#      recién puesto y, al confirmar, lo deja al día solo (400.00). Nadie se
#      queda esperando a nadie (ningún interbloqueo, ningún error).
#  12. LOS REPARTOS, CON OTRA FORMA (la revisión de la Fase 11c: lo que
#      c3-pruebas.sql ya no hace con la tabla de verdad, para no pedirla en
#      exclusiva con la app abierta). A jornal_reparto_horas se le cambia el
#      nombre de una columna (como un c10 que c3 no conoce): c3 no sabe qué
#      horas pagó ya un jornal y NO SUPONE NADA: el plan lo dice
#      (jornales_sin_leer), devengar un mes sin devengo se niega (MX008, y
#      manda a pegar c10 y c3), el devengo que había se queda como estaba
#      (retenido), el control «devengo» lo dice de cada mes abierto con
#      devengo, y un mes así NO se cierra (MX008). Con la columna de vuelta,
#      todo en verde y los mismos asientos.
# ABRIL, EL DEVENGO QUE SE QUEDA SIN HORAS:
#  13. (La revisión de la Fase 11c.) Abril devengado con las horas del
#      jornalero (280.00). El ZC paga las de una semana (queda 120.00) y el
#      ZD las de la otra: ya no queda nada trabajado y sin pagar, y el
#      devengo SE DESHACE (su papel: no_aplica, sin_horas). «Deshacer» el ZD:
#      sus horas vuelven a estar sin pagar y EL DEVENGO VUELVE SOLO (120.00,
#      como sustituto del que se deshizo). (Con el c3 de la primera vuelta
#      el mes se quedaba sin devengo, con horas aprobadas y sin pagar, y
#      nada lo decía.) Des-casado el ZC en la Bandeja, 280.00. Y EL TRIGGER
#      EN «IMMEDIATE» (nadie lo pone así salvo las pruebas): en un «Así es»
#      corre antes de que c10 guarde el reparto y no hace nada —el devengo
#      queda por poner al día, el control lo dice y fn_horas_devengar lo
#      arregla—; en un «Deshacer» pone el devengo al día en ese momento, y
#      la cadena del libro queda en orden.
#  14. VOLVER A PEGAR c3 (dos veces) con todo dentro: los devengos son los
#      mismos asientos; y c3-pruebas.sql corre con los Zelle y la nómina de
#      verdad dentro: ninguna falla, y las del corte de los jornales (de la
#      127 a la 136) corren todas.
# Y comprueba al final: la cadena del libro en verde (los permisos y las
# huellas también, con el reloj de vuelta), los puentes (c3) sin nada nuevo
# en rojo, los cuadres del jornal (c10) y de la nómina (c15) sin rojos.
#
# Cada sesión de «la app» va como por PostgREST: el dueño, con el rol
# authenticated, los ajustes de ese rol y el tope de la API (8 s); con su
# código (aal2) o sin él (aal1). Cada «Así es», cada «Deshacer» y cada
# des-casado va en SU transacción y se confirma: el devengo se pone al día
# en un trigger diferido, al confirmar. Nombres y montos inventados («ZZ…»,
# «ZZ C3 JOR»): nada de producción.
#
# Variables: PGHOST (127.0.0.1) y PGPORT (5432), como correr.sh.
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c3_jornal}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'echo "(La base $BD y $TMP quedan: ./correr.sh --borrar $BD; rm -rf $TMP)"' EXIT
else
  trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=terse -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }
# (pegar un archivo como el SQL Editor: una transacción, para al primer error)
pegar() { PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$1"; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

# La escena, como el SQL Editor: dos obras, cuatro personas (su usuario, su
# perfil de campo; tres con su tarifa), sus horas (aprobadas o no) y los
# Zelle del jornalero, como los trae Plaid, en la Bandeja.
P1='00000000-0000-4000-a000-0000000c3101'   # ZZ Ayudante Uno (nómina, 25 la hora)
P4='00000000-0000-4000-a000-0000000c3104'   # ZZ Jornalero Cuatro (Zelle, 20 la hora)
cat > "$TMP/montar.sql" <<'SQL'
insert into proyectos (id, tipo, nombre, estado) values
  ('c3-jor-a', 'comercial', 'ZZ C3 JOR Obra A', 'ejecucion'),
  ('c3-jor-b', 'servicio',  'ZZ C3 JOR Obra B', 'ejecucion');
do $$
declare
  r record;
  v_d uuid := (select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1);
begin
  for r in select * from (values ('00000000-0000-4000-a000-0000000c3101'::uuid, 'ZZ Ayudante Uno'),
                                 ('00000000-0000-4000-a000-0000000c3102'::uuid, 'ZZ Ayudante Dos'),
                                 ('00000000-0000-4000-a000-0000000c3103'::uuid, 'ZZ Oficial Tres'),
                                 ('00000000-0000-4000-a000-0000000c3104'::uuid, 'ZZ Jornalero Cuatro')) as x(id, nombre) loop
    insert into auth.users (id, email) values (r.id, 'c3-jor-' || right(r.id::text, 2) || '@c3-pruebas.invalid') on conflict (id) do nothing;
    insert into perfiles (id, nombre, rol, activo) values (r.id, r.nombre, 'campo', true)
    on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
  end loop;
  insert into costos_equipo (usuario_id, costo_hora) values
    ('00000000-0000-4000-a000-0000000c3101', 25), ('00000000-0000-4000-a000-0000000c3102', 30),
    ('00000000-0000-4000-a000-0000000c3104', 20)
  on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
  -- APROBADAS
  insert into horas (fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el) values
    -- DICIEMBRE de 2026 · el jornalero, la semana del 7 al 13 (la paga el Z1)
    ('2026-12-07', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2026-12-08', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2026-12-09', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-b', 6,  'CO #1', 'ZZ C3 JOR', v_d, now()),
    -- DICIEMBRE · uno de la nómina (nadie se las paga en diciembre)
    ('2026-12-21', '00000000-0000-4000-a000-0000000c3101', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2026-12-22', '00000000-0000-4000-a000-0000000c3101', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    -- ENERO de 2027 · los de la nómina, dentro del período de la del 22-ene (3 a 16-ene)
    ('2027-01-04', '00000000-0000-4000-a000-0000000c3101', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-01-05', '00000000-0000-4000-a000-0000000c3101', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-01-11', '00000000-0000-4000-a000-0000000c3101', 'c3-jor-b', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-01-06', '00000000-0000-4000-a000-0000000c3102', 'c3-jor-b', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-01-12', '00000000-0000-4000-a000-0000000c3102', 'c3-jor-b', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-01-07', '00000000-0000-4000-a000-0000000c3103', 'c3-jor-a', 10, null,    'ZZ C3 JOR', v_d, now()),
    -- ENERO · los de la nómina, LA COLA (después de ese período: nadie las paga en enero)
    ('2027-01-19', '00000000-0000-4000-a000-0000000c3101', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-01-20', '00000000-0000-4000-a000-0000000c3101', 'c3-jor-b', 5,  'CO #1', 'ZZ C3 JOR', v_d, now()),
    ('2027-01-21', '00000000-0000-4000-a000-0000000c3102', 'c3-jor-a', 4,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-01-21', '00000000-0000-4000-a000-0000000c3103', 'c3-jor-a', 10, null,    'ZZ C3 JOR', v_d, now()),
    -- ENERO · el jornalero: la semana del 4 al 10 (Z5), la del 11 al 17 (Z6) y el 19 (nadie se la paga en enero)
    ('2027-01-05', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-01-06', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-b', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-01-12', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-01-13', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-b', 6,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-01-19', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-b', 8,  null,    'ZZ C3 JOR', v_d, now()),
    -- MARZO de 2027 (las dos sesiones a la vez) · el jornalero: la semana del 1 al 7 (ZA) y la del 8 al 14 (ZB)
    ('2027-03-02', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-03-03', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-b', 6,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-03-09', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-03-10', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-b', 4,  null,    'ZZ C3 JOR', v_d, now()),
    -- MARZO · uno de la nómina (nadie se las paga en marzo)
    ('2027-03-16', '00000000-0000-4000-a000-0000000c3101', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    -- ABRIL de 2027 (el devengo que se queda sin horas) · solo el jornalero: la semana del 5 al 11 (ZC) y la del 12 al 18 (ZD)
    ('2027-04-06', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-a', 8,  null,    'ZZ C3 JOR', v_d, now()),
    ('2027-04-13', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-b', 6,  null,    'ZZ C3 JOR', v_d, now());
  -- SIN APROBAR (las aprueba el «Así es» de su Zelle)
  insert into horas (fecha, usuario_id, proyecto_id, horas, co, notas) values
    ('2026-12-14', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-a', 8, null, 'ZZ C3 JOR'),   -- Z2
    ('2026-12-15', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-b', 7, null, 'ZZ C3 JOR'),   -- Z2
    ('2026-12-28', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-a', 8, null, 'ZZ C3 JOR'),   -- Z3
    ('2026-12-29', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-b', 8, null, 'ZZ C3 JOR'),   -- Z3
    ('2026-12-30', '00000000-0000-4000-a000-0000000c3104', 'c3-jor-b', 4, null, 'ZZ C3 JOR');   -- Z9 (solo en la escena del mes cerrado)
end $$;
select set_config('request.jwt.claims', json_build_object('sub', (select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1), 'role', 'authenticated', 'aal', 'aal2')::text, false);
select fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c3-jornal',
  'filas', (select jsonb_agg(jsonb_build_object('id', 'c3-jor-' || z.k, 'fecha', z.fecha, 'plaid_monto', z.monto,
                                                'descripcion', 'Zelle payment to ZZ JORNALERO CUATRO ' || z.n, 'tipo', 'DEBIT', 'pendiente', false))
              from (values ('z1', '2026-12-14', '451.00', 4001), ('z2', '2026-12-21', '330.00', 4002), ('z3', '2027-01-04', '352.00', 4003),
                           ('z9', '2026-12-30', '84.00', 4009), ('z5', '2027-01-11', '336.00', 4005), ('z6', '2027-01-19', '294.00', 4006),
                           ('za', '2027-03-08', '301.00', 4011), ('zb', '2027-03-15', '252.00', 4012),
                           ('zc', '2027-04-09', '170.00', 4013), ('zd', '2027-04-16', '126.00', 4014)) as z(k, fecha, monto, n))));
select count(fn_banco_casar(m.id)) from movimientos_banco m where m.id_externo like 'c3-jor-%';
select fn_jornal_persona('{"usuario_id": "00000000-0000-4000-a000-0000000c3104", "patron": "\\mZZ JORNALERO CUATRO\\M"}')->>'nota_alta';
select set_config('request.jwt.claims', '', false);
SQL

echo "== Base $BD: c1 + c2 + c3 + c4 + c6 + c10 + c9, SIN la nómina, y lo de este script"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c4-estados.sql" "$DOCS/c6-banco.sql" "$DOCS/c10-costo-obra.sql" "$DOCS/c9-cierre.sql" "$TMP/montar.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
[ -n "$DUENO" ] || { echo "No hay un dueño en la base" >&2; exit 2; }
[ "$(ed -c "select count(*) from periodos where periodo in ('2026-12', '2027-01', '2027-02', '2027-03', '2027-04') and estado = 'abierto'")" = "5" ] \
  || { echo "De diciembre de 2026 a abril de 2027 tienen que estar abiertos en una base nueva" >&2; exit 2; }
[ "$(ed -c "select count(*) from v_jornal_pendientes")" = "10" ] \
  || { echo "Los diez Zelle del jornalero tienen que estar en la Bandeja, reconocidos" >&2; ed -c "select id_externo, estado from movimientos_banco"; exit 2; }
# (lo que la base recién cargada ya trae en rojo en los puentes —los papeles de la semilla sin evaluar—: no es de aquí)
ROJOS_C3="$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_puentes_verificar() where not ok")"

# EL RELOJ DE LA BASE, por delante (como el de c2-pruebas: nunca por detrás
# del de verdad). Al final se deja como estaba.
ed -c "select pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure)" > "$TMP/reloj-de-verdad.sql"
reloj() {
  ed -v ON_ERROR_STOP=1 -c "create or replace function public.fn_fecha_miami(t timestamptz) returns date language sql stable set search_path = public, pg_temp as \$b\$ select greatest((t at time zone 'America/New_York')::date, date '$1') \$b\$" \
    || { echo "No se pudo mover el reloj de la base" >&2; exit 2; }
}
reloj_de_verdad() { ed -v ON_ERROR_STOP=1 -f "$TMP/reloj-de-verdad.sql" || { echo "No se pudo devolver el reloj" >&2; exit 2; }; }

# Como la app por PostgREST: el dueño, con el rol authenticated, los ajustes
# de ese rol y el tope de la API (8 s). app <aal1|aal2>.
app() {
  echo "select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\",\"aal\":\"$1\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"
}
# como <aal1|aal2> <sql que devuelve un texto>: lo que devuelve, o su error (:'arch' = el journal). UNA transacción, confirmada.
como() {
  ed -v ON_ERROR_STOP=1 -v arch="${ARCH:-{\}}" 2>&1 <<SQL | sed -n 's/^RESULTADO //p; s/^.*ERROR: *//p'
begin; $(app "$1")
select 'RESULTADO ' || coalesce(($2)::text, '(nulo)');
commit;
SQL
}
dueno() { como aal2 "$1"; }
# El devengo vivo de un mes: sus líneas de 5000 por obra y CO, y su total.
VIVO="a.origen_tabla = 'horas_devengo' and a.camino not in ('reverso', 'reverso_automatico') and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')"
devengo() {
  ed -c "select coalesce((select string_agg(concat_ws(' ', replace(l.proyecto_id, 'c3-jor-', ''), l.co, l.monto::text), ' · ' order by l.proyecto_id, l.co nulls first) || ' = ' || sum(l.monto)
                            from asientos a join asiento_lineas l on l.asiento_id = a.id and l.cuenta = '5000'
                           where $VIVO and a.origen_id = '$1'), 'sin devengo')"
}
numero() { ed -c "select coalesce((select a.numero from asientos a where $VIVO and a.origen_id = '$1'), '-')"; }
# El control devengo de c3 (t/f y cuántos fallan), como el SQL Editor o, con <aal>, como el dueño por la API.
CTL="(select c.ok::text || '/' || jsonb_array_length(c.detalle->'fallan') from fn_puentes_verificar() c where c.control = 'devengo')"
control() { if [ -n "${1:-}" ]; then como "$1" "$CTL"; else ed -c "select $CTL"; fi; }
# El cuadre 50 de c10 (ninguna hora en el devengo de un mes y en un jornal pagado ese mes) y el 20 (ningún reparto suelto).
c50() { ed -c "select k.ok::text from v_jornal_control k where k.orden = 50"; }
c20() { ed -c "select k.ok::text from v_jornal_control k where k.orden = 20"; }
# Las filas del cierre (c9) que miran esto, de un mes: la del control «devengo» de los puentes (130+) y la del jornal (170).
# «-» = ninguna en rojo.
cierre() { ed -c "select coalesce(string_agg(case when r.orden = 170 then '170' else 'devengo' end, ',' order by r.orden), '-') from fn_cierre_revisar('$1') r where not r.ok and (r.control = 'puentes: devengo' or r.orden = 170)"; }
verde() { echo "$(control)|$(c50)|$(cierre "$1")"; }   # todo en verde: true/0|true|-
# Volver a devengar un mes: qué hace (o su error), como el SQL Editor o, con <aal>, como el dueño por la API.
devengar() {
  if [ -n "${2:-}" ]; then como "$2" "fn_horas_devengar('$1')->>'accion'"
  else ed -c "select fn_horas_devengar('$1')->>'accion'" 2>&1 | sed 's/^.*ERROR: *//'; fi
}
# Una cuenta de las obras de la escena en un mes, por obra y CO.
libro() {  # libro <mes> <cuenta>
  ed -c "select coalesce(string_agg(q.obra || ' ' || q.s, ' · ' order by q.obra), 'nada')
           from (select concat_ws(' ', replace(l.proyecto_id, 'c3-jor-', ''), l.co) as obra, sum(l.monto) as s
                   from asiento_lineas l join asientos a on a.id = l.asiento_id
                  where l.proyecto_id like 'c3-jor-%' and l.cuenta = '$2' and a.periodo = '$1'
                  group by 1 having sum(l.monto) <> 0) q"
}

# LOS ZELLE. mov <z1…>: el movimiento. Cada acción, como el dueño por la API (con su código), en su transacción.
mov() { ed -c "select id from movimientos_banco where id_externo = 'c3-jor-$1'"; }
# asi_es <z> <desde> <hasta>: la propuesta y «Así es» con su huella → «aplicado <fecha del asiento> <avisos>»
asi_es() {
  local M; M="$(mov "$1")"
  dueno "(select (r->>'estado') || ' ' || (r->'asiento'->>'fecha_contable') || ' ' || coalesce((select string_agg(a->>'codigo', ',' order by a->>'codigo') from jsonb_array_elements(r->'avisos') a where a->>'codigo' in ('devengo_estandar', 'mes_cerrado')), '-')
            from fn_jornal_aplicar('$M', '$2', '$3', fn_jornal_propuesta('$M', '$2', '$3')->>'visto') r)"
}
asiento_de() { ed -c "select a.numero from jornal_repartos r join asientos a on a.id = r.asiento_id where r.movimiento_id = '$(mov "$1")' and r.estado = 'aplicado'"; }
deshacer() { dueno "fn_jornal_deshacer((select id from jornal_repartos where movimiento_id = '$(mov "$1")' and estado = 'aplicado'), 'ZZ C3 JOR: se deshace para ver el devengo')->>'estado'"; }
descasar() { dueno "fn_banco_descasar('$(mov "$1")', 'ZZ C3 JOR: des-casado en la Bandeja')->>'deshecho'"; }

# Una nómina de Gusto: el journal sintético del repositorio (período 3 a 16-ene, día de pago 22-ene).
archivo() {
  local csv; csv="$(cat "$DIR/nomina/zz-payroll-journal.csv")"
  ed -v csv="$csv" -v nombre="zz-payroll-journal-01222027.csv" <<'SQL'
select jsonb_build_object('nombre', :'nombre', 'sha256', encode(sha256(convert_to(:'csv', 'UTF8')), 'hex'), 'bytes', octet_length(:'csv'),
                          'filas', (select jsonb_agg(to_jsonb(string_to_array(t.l, ',')) order by t.n)
                                      from unnest(string_to_array(:'csv', E'\n')) with ordinality as t(l, n)))::text;
SQL
}
# la nómina entera, por la puerta del dueño: importar, enlazar a su gente y postear. Deja K (la corrida) y POST (lo que dijo postear).
nomina() {
  ARCH="$(archivo)"
  [ -n "$ARCH" ] || { echo "No se pudo armar el archivo de la nómina" >&2; exit 2; }
  IMP="$(dueno "fn_nomina_importar(:'arch'::jsonb)->'corridas'->0->>'resultado'")"
  K="$(ed -c "select id from nomina_corridas where estado = 'importada' order by importada_el desc limit 1")"
  for p in "ZZ Ayudante Uno|0c3101|campo" "ZZ Ayudante Dos|0c3102|campo" "ZZ Oficial Tres|0c3103|oficial"; do
    IFS='|' read -r nom suf cla <<< "$p"
    dueno "fn_nomina_persona(jsonb_build_object('id', (select id from nomina_personas where clave = fn_nomina_clave('$nom')), 'usuario_id', '00000000-0000-4000-a000-000000$suf', 'clase', '$cla', 'confirmar', true))->>'confirmada'" > /dev/null
  done
  dueno "fn_nomina_config('{\"cuenta_sin_obra\": \"6000\"}')->>'cuenta_sin_obra'" > /dev/null
  POST="$(dueno "(select (r->'asiento'->>'fecha') || ' · ' || (r->>'horas') || ' horas' from fn_nomina_postear('$K', fn_nomina_propuesta('$K')->>'visto') r)")"
}

echo
echo "== 1. Diciembre devengado, y llega un Zelle de ese mes (el Z1, del 14-dic)"
reloj 2026-12-31
# (la marca, «al menos»: una mayor —la 2026111402 de la segunda vuelta del 14-nov— sigue valiendo, como en c3-nomina.sh)
revisa "c3 es el de la Fase 11c o posterior (su marca: 2026111401 o más), lee los jornales, y la nómina no está" "al_dia|ok|no_esta" \
  "$(ed -c "select (select case when substring(p.prosrc from '([0-9]{10})')::bigint >= 2026111401 then 'al_dia' else substring(p.prosrc from '([0-9]{10})') end from pg_proc p where p.oid = 'public.fn_puente_version()'::regprocedure) || '|' || (pl->'corte'->'jornales'->>'lectura') || '|' || (pl->'corte'->>'marca') from (select fn_puente_devengo_plan('2026-12') as pl) x")"
revisa "devengar diciembre (el dueño, sin el código del teléfono): todas sus horas aprobadas con obra y con costo" \
  "posteado|a 720.00 · b CO #1 120.00 = 840.00" "$(devengar 2026-12 aal1)|$(devengo 2026-12)"
D0="$(numero 2026-12)"
revisa "la propuesta del Z1 avisa de que sus 22 h están en el devengo de diciembre" "22" \
  "$(dueno "(select a->>'horas' from jsonb_array_elements(fn_jornal_propuesta('$(mov z1)', '2026-12-07', '2026-12-13')->'avisos') a where a->>'codigo' = 'devengo_estandar')")"
revisa "«Así es» en el Z1: entra el 14-dic, repartido por sus horas" "aplicado 2026-12-14 devengo_estandar" "$(asi_es z1 2026-12-07 2026-12-13)"
J1="$(asiento_de z1)"
revisa "al confirmar, el devengo de diciembre se puso al día SOLO: queda lo que nadie pagó (otro asiento)" "a 400.00 = 400.00|otro" \
  "$(devengo 2026-12)|$([ "$(numero 2026-12)" != "$D0" ] && echo otro || echo "el mismo")"
revisa "y su asiento dice lo que dejó fuera y qué asiento lo pagó" "3 reportes, 22 h, sí" \
  "$(ed -c "select (a.procedencia->'documento'->'pagadas_jornal'->>'reportes') || ' reportes, ' || trim_scale((a.procedencia->'documento'->'pagadas_jornal'->>'horas')::numeric) || ' h, ' || case when a.procedencia->'documento'->'pagadas_jornal'->'asientos' = jsonb_build_array('$J1'::text) and a.procedencia->>'corte_jornal' like '%que un jornal%$J1%' and a.descripcion like '%fuera 22 h que un jornal ya había pagado ($J1)%' then 'sí' else 'no' end from asientos a where a.numero = '$(numero 2026-12)'")"
revisa "ni el control «devengo» de c3, ni el cuadre 50 de c10, ni el cierre (filas 130+ y 170) en rojo" "true/0|true|-" "$(verde 2026-12)"
revisa "en el libro, diciembre: el devengo de lo que nadie pagó (5000) y el pago real del jornal (5200)" \
  "a 400.00|a 328.00 · b CO #1 123.00" "$(libro 2026-12 5000)|$(libro 2026-12 5200)"

echo
echo "== 2. El «Así es» que aprueba y paga dentro del mes (el Z2, del 21-dic)"
D1="$(numero 2026-12)"
revisa "«Así es» en el Z2: aprueba sus dos reportes y entra el 21-dic" "aplicado 2026-12-21 -|2" \
  "$(asi_es z2 2026-12-14 2026-12-20)|$(ed -c "select count(*) from horas where usuario_id = '$P4' and fecha between '2026-12-14' and '2026-12-20' and aprobado_el is not null")"
revisa "el devengo de diciembre NO cambia (el mismo asiento): aprobadas y pagadas dentro del mes" "a 400.00 = 400.00|$D1" "$(devengo 2026-12)|$(numero 2026-12)"
revisa "todo sigue en verde" "true/0|true|-" "$(verde 2026-12)"

echo
echo "== 3. El Zelle del mes siguiente (el Z3, del 4-ene, por horas de diciembre sin aprobar)"
reloj 2027-01-04
revisa "«Así es» en el Z3: aprueba el 28 y el 29-dic, y entra el 4-ene" "aplicado 2027-01-04 -" "$(asi_es z3 2026-12-28 2026-12-29)"
revisa "el devengo de diciembre las lleva, solo: trabajadas en diciembre y pagadas después" "a 560.00 · b 160.00 = 720.00" "$(devengo 2026-12)"
revisa "todo sigue en verde (el jornal de enero no choca con el devengo de diciembre)" "true/0|true|-" "$(verde 2026-12)"
revisa "diciembre: el devengo (5000) y los dos Zelle del mes (5200)" "a 560.00 · b 160.00|a 504.00 · b 154.00 · b CO #1 123.00" \
  "$(libro 2026-12 5000)|$(libro 2026-12 5200)"
revisa "enero: el reverso del día 1 (5000) y el Zelle del 4-ene (5200): cada hora, una vez" "a -560.00 · b -160.00|a 176.00 · b 176.00" \
  "$(libro 2027-01 5000)|$(libro 2027-01 5200)"

echo
echo "== 4. La misma respuesta en toda sesión"
revisa "el control devengo: el SQL Editor, el dueño sin el código y con él" "true/0|true/0|true/0" "$(control)|$(control aal1)|$(control aal2)"
revisa "volver a devengar diciembre no hace nada: el SQL Editor, sin el código y con él" "sin_cambios|sin_cambios|sin_cambios" \
  "$(devengar 2026-12)|$(devengar 2026-12 aal1)|$(devengar 2026-12 aal2)"
revisa "y el plan lee los mismos jornales en las tres (5 reportes, 37 h, pagados dentro de diciembre)" "5/37|5/37|5/37" \
  "$(ed -c "select (pl->'corte'->'jornales'->>'reportes') || '/' || trim_scale((pl->'corte'->'jornales'->>'horas')::numeric) from (select fn_puente_devengo_plan('2026-12') as pl) x")|$(como aal1 "(select (r->'pagadas_jornal'->>'reportes') || '/' || trim_scale((r->'pagadas_jornal'->>'horas')::numeric) from fn_horas_devengar('2026-12') r)")|$(como aal2 "(select (r->'pagadas_jornal'->>'reportes') || '/' || trim_scale((r->'pagadas_jornal'->>'horas')::numeric) from fn_horas_devengar('2026-12') r)")"

echo
echo "== 5. La vuelta: «Deshacer» un reparto, y des-casar un pago en la Bandeja"
revisa "«Deshacer» el reparto del Z1: sus horas vuelven al devengo, solo" "deshecho|a 880.00 · b 160.00 · b CO #1 120.00 = 1160.00|true/0|true|-" \
  "$(deshacer z1)|$(devengo 2026-12)|$(verde 2026-12)"
revisa "des-casar el Z2 en la Bandeja (c6 reversa su asiento): sus horas, ya aprobadas, entran al devengo, solo" \
  "clasificado|a 1040.00 · b 300.00 · b CO #1 120.00 = 1460.00|true/0|true" "$(descasar z2)|$(devengo 2026-12)|$(control)|$(c50)"
revisa "el reparto quedó suelto (lo dice c10, su cuadre 20) y «Deshacer» lo cierra; el devengo no se mueve" "false|deshecho|true|a 1040.00 · b 300.00 · b CO #1 120.00 = 1460.00" \
  "$(c20)|$(deshacer z2)|$(c20)|$(devengo 2026-12)"
revisa "el Z2 repartido otra vez: sus horas salen del devengo, solo" "aplicado 2026-12-21 devengo_estandar|a 880.00 · b 160.00 · b CO #1 120.00 = 1160.00|true/0|true|-" \
  "$(asi_es z2 2026-12-14 2026-12-20)|$(devengo 2026-12)|$(verde 2026-12)"

echo
echo "== 6. Si el devengo no se pudo poner al día (el trigger, apagado un instante)"
M1="$(mov z1)"
ed -v ON_ERROR_STOP=1 > "$TMP/6.out" 2>&1 <<SQL
begin;
alter table public.asientos disable trigger trg_puente_asientos_jornal;
$(app aal2)
select 'RESULTADO ' || (fn_jornal_aplicar('$M1', '2026-12-07', '2026-12-13', fn_jornal_propuesta('$M1', '2026-12-07', '2026-12-13')->>'visto')->>'estado');
reset role;
alter table public.asientos enable trigger trg_puente_asientos_jornal;
commit;
SQL
J1="$(asiento_de z1)"
revisa "el Z1 entra igual, y el devengo se queda como estaba" "aplicado|a 880.00 · b 160.00 · b CO #1 120.00 = 1160.00" \
  "$(sed -n 's/^RESULTADO //p' "$TMP/6.out")|$(devengo 2026-12)"
revisa "el control «devengo» lo dice: cuántas horas, qué asiento las pagó y qué hacer" "f/22 h/su asiento/dice cómo" \
  "$(ed -c "select case when c.ok then 't' else 'f' end || '/' || coalesce(substring(f.v from 'cuenta ([0-9.]+ h) que un jornal ya pagó dentro del mes'), '?') || '/' || case when f.v like '%dentro del mes ($J1)%' then 'su asiento' else 'otro' end || '/' || case when f.v like '%select fn_horas_devengar(''2026-12''); lo pone al día%' then 'dice cómo' else 'no lo dice' end from fn_puentes_verificar() c cross join lateral jsonb_array_elements_text(c.detalle->'fallan') f(v) where c.control = 'devengo'")"
revisa "el cuadre 50 de c10 y el cierre (sus filas del devengo y del jornal), también" "false|devengo,170" "$(c50)|$(cierre 2026-12)"
revisa "diciembre NO se cierra así, y dice cómo (se deshace)" "MX008/dice_como" \
  "$(ed -v ON_ERROR_STOP=1 <<'SQL' 2>&1 | sed -n 's/^.*RESULTADO //p; /ERROR/p'
begin;
do $$
declare
  v_b text; v_q text;
begin
  lock table public.periodos in exclusive mode;
  if not exists (select 1 from asientos a where a.tipo = 'apertura') then
    perform fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', (select to_char(p.desde, 'YYYY-MM-DD') from periodos p where p.tipo = 'apertura' order by p.desde limit 1),
      'descripcion', 'ZZ C3 JOR: apertura de prueba (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1010', 'monto', '1000.00'), jsonb_build_object('cuenta', '3900', 'monto', '-1000.00'))));
  end if;
  begin
    for v_q in select p.periodo from periodos p where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= date '2026-12-01' order by p.desde loop
      perform fn_cerrar_periodo(v_q);
    end loop;
    v_b := 'cerrado';
  exception when others then
    v_b := sqlstate || case when sqlerrm like '%desfasado%' and sqlerrm like '%un jornal%' and sqlerrm like '%fn_horas_devengar(''2026-12'')%' then '/dice_como' else ': ' || sqlerrm end;
  end;
  raise notice 'RESULTADO %', v_b;
end $$;
rollback;
SQL
)"
revisa "fn_horas_devengar lo pone al día (el dueño, sin el código), y todo vuelve a verde" "sustituido|a 560.00 · b 160.00 = 720.00|true/0|true|-" \
  "$(devengar 2026-12 aal1)|$(devengo 2026-12)|$(verde 2026-12)"

echo
echo "== 7. Un mes cerrado no se toca (se deshace)"
D12="$(numero 2026-12)"
M9="$(mov z9)"
revisa "diciembre se cierra con su devengo al día; el Z9 (del 30-dic) entra el 1-ene; el devengo es el mismo y el control lo deja dicho sin rojo" \
  "cerrado|aplicado 2027-01-01 mes_cerrado|$D12|true/0/1" \
  "$(ed -v ON_ERROR_STOP=1 <<SQL 2>&1 | sed -n 's/^.*RESULTADO //p; /ERROR/p' | paste -sd'|' -
begin;
lock table public.periodos in exclusive mode;
do \$\$
declare v_q text;
begin
  if not exists (select 1 from asientos a where a.tipo = 'apertura') then
    perform fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', (select to_char(p.desde, 'YYYY-MM-DD') from periodos p where p.tipo = 'apertura' order by p.desde limit 1),
      'descripcion', 'ZZ C3 JOR: apertura de prueba (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1010', 'monto', '1000.00'), jsonb_build_object('cuenta', '3900', 'monto', '-1000.00'))));
  end if;
  for v_q in select p.periodo from periodos p where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= date '2026-12-01' order by p.desde loop
    perform fn_cerrar_periodo(v_q);
  end loop;
end \$\$;
select 'RESULTADO ' || estado from periodos where periodo = '2026-12';
$(app aal2)
select 'RESULTADO ' || (r->>'estado') || ' ' || (r->'asiento'->>'fecha_contable') || ' ' || coalesce((select string_agg(a->>'codigo', ',') from jsonb_array_elements(r->'avisos') a where a->>'codigo' in ('devengo_estandar', 'mes_cerrado')), '-')
  from fn_jornal_aplicar('$M9', '2026-12-30', '2026-12-30', fn_jornal_propuesta('$M9', '2026-12-30', '2026-12-30')->>'visto') r;
set constraints public.trg_puente_asientos_jornal immediate;
reset role;
select 'RESULTADO ' || coalesce((select a.numero from asientos a where $VIVO and a.origen_id = '2026-12'), '-');
select 'RESULTADO ' || c.ok::text || '/' || jsonb_array_length(c.detalle->'fallan') || '/' || jsonb_array_length(c.detalle->'cerrados_con_horas_cambiadas') from fn_puentes_verificar() c where c.control = 'devengo';
rollback;
SQL
)"
revisa "deshecho eso, diciembre sigue abierto, con su devengo, y el Z9 en la Bandeja" "abierto|$D12|pendiente" \
  "$(ed -c "select estado from periodos where periodo = '2026-12'")|$(numero 2026-12)|$(ed -c "select estado from movimientos_banco where id = '$M9'")"

echo
echo "== 8. Enero, con la nómina en el mismo mes (llega c15, encima, sin volver a pegar c3)"
pegar "$DOCS/c15-nomina.sql" > "$TMP/8c15.out" 2>&1 || { tail -n 20 "$TMP/8c15.out"; echo "FALLÓ pegar c15 encima de c3" >&2; exit 2; }
reloj 2027-01-21
revisa "c3 ya lee los dos cortes (la marca sin dinero de la nómina y los repartos de los jornales), sin que nadie lo toque" "ok|ok" \
  "$(ed -c "select (pl->'corte'->>'marca') || '|' || (pl->'corte'->'jornales'->>'lectura') from (select fn_puente_devengo_plan('2027-01') as pl) x")"
revisa "enero devengado ANTES de sus pagos: todas sus horas aprobadas con obra y con costo" "posteado|a 1040.00 · b 1120.00 · b CO #1 125.00 = 2285.00" \
  "$(devengar 2027-01 aal1)|$(devengo 2027-01)"
revisa "«Así es» en el Z5 (11-ene): sus horas salen del devengo, solo" "aplicado 2027-01-11 devengo_estandar|a 880.00 · b 960.00 · b CO #1 125.00 = 1965.00|true/0|true|-" \
  "$(asi_es z5 2027-01-04 2027-01-10)|$(devengo 2027-01)|$(verde 2027-01)"
J5="$(asiento_de z5)"
reloj 2027-01-22
nomina; K2="$K"
revisa "la nómina del 22-ene, posteada con las horas de su período" "nueva|2027-01-22 · 6 horas" "$IMP|$POST"
revisa "al postearla, el devengo de enero se puso al día solo: fuera lo de la nómina Y lo del jornal" "a 480.00 · b 280.00 · b CO #1 125.00 = 885.00|true/0|true|-" \
  "$(devengo 2027-01)|$(verde 2027-01)"
revisa "y su asiento nombra el journal de la nómina y el asiento del jornal" "nómina 5/40 · jornal 2/16 · sí" \
  "$(ed -c "select 'nómina ' || (d->'pagadas'->>'reportes') || '/' || trim_scale((d->'pagadas'->>'horas')::numeric) || ' · jornal ' || (d->'pagadas_jornal'->>'reportes') || '/' || trim_scale((d->'pagadas_jornal'->>'horas')::numeric) || ' · ' || case when d->'pagadas'->'journals' = jsonb_build_array((select c.asiento_numero from nomina_corridas c where c.id = '$K2')) and d->'pagadas_jornal'->'asientos' = jsonb_build_array('$J5'::text) and a.descripcion like '%fuera 40 h que la nómina ya había pagado (%) y 16 h que un jornal ya había pagado ($J5)%' then 'sí' else 'no' end from asientos a cross join lateral (select a.procedencia->'documento' as d) x where a.numero = '$(numero 2027-01)'")"
revisa "«Así es» en el Z6 (19-ene): queda solo lo que NINGUNO de los dos pagó" "aplicado 2027-01-19 devengo_estandar|a 320.00 · b 160.00 · b CO #1 125.00 = 605.00|true/0|true|-" \
  "$(asi_es z6 2027-01-11 2027-01-17)|$(devengo 2027-01)|$(verde 2027-01)"
D01="$(numero 2027-01)"
revisa "al centavo, lo que dice la cola de la nómina (con el código del teléfono: lo que ni una nómina ni un Zelle habían pagado al terminar enero)" "605.00|605.00" \
  "$(dueno "(select sum(q.estandar) from fn_nomina_cola('2027-01') q where q.proyecto_id like 'c3-jor-%')")|$(ed -c "select sum(l.monto) from asientos a join asiento_lineas l on l.asiento_id = a.id and l.cuenta = '5000' where a.numero = '$D01'")"
revisa "entre diciembre, enero y febrero, el 5000 de las obras es el del journal de la nómina: nada dos veces" "sí" \
  "$(ed -c "select case when l.s = j.s and l.s > 0 then 'sí' else 'no: el libro ' || l.s || ', el journal ' || j.s end
              from (select sum(m.monto) as s from asiento_lineas m join asientos a on a.id = m.asiento_id
                     where m.proyecto_id like 'c3-jor-%' and m.cuenta = '5000' and a.periodo in ('2026-12', '2027-01', '2027-02')) l,
                   (select sum(m.monto) as s from asiento_lineas m join nomina_corridas c on c.asiento_id = m.asiento_id
                     where c.estado = 'posteada' and m.proyecto_id like 'c3-jor-%' and m.cuenta = '5000') j")"
revisa "y el 5200, el de los cinco Zelle repartidos (451 + 330 + 352 + 336 + 294)" "1763.00" \
  "$(ed -c "select sum(m.monto) from asiento_lineas m join asientos a on a.id = m.asiento_id where m.proyecto_id like 'c3-jor-%' and m.cuenta = '5200' and a.periodo in ('2026-12', '2027-01', '2027-02')")"
revisa "el control «mano de obra» sigue en verde con nómina, jornales y devengo en el mismo mes" "true" \
  "$(ed -c "select c.ok::text from fn_puentes_verificar() c where c.control = 'mano_de_obra'")"
revisa "la misma respuesta en toda sesión: el SQL Editor, el dueño sin el código y con él" "true/0|true/0|true/0|sin_cambios|sin_cambios|sin_cambios" \
  "$(control)|$(control aal1)|$(control aal2)|$(devengar 2027-01)|$(devengar 2027-01 aal1)|$(devengar 2027-01 aal2)"
echo "     (enero en el libro · 5000: $(libro 2027-01 5000) · 5200: $(libro 2027-01 5200))"

echo
echo "== 9. Las anulaciones: la nómina, y un Zelle"
revisa "anulada la nómina: vuelven sus horas al devengo; las del jornal siguen fuera" "anulada|a 720.00 · b 840.00 · b CO #1 125.00 = 1685.00|true/0|true|-" \
  "$(dueno "(select 'anulada' from fn_nomina_anular('$K2', 'ZZ C3 JOR: se anula para ver el devengo') r where r->>'reverso' is not null and r->>'devengo' like 'El mes 2027-01 tenía un devengo estándar de horas: se puso al día aquí mismo%')")|$(devengo 2027-01)|$(verde 2027-01)"
nomina; K2="$K"
revisa "subida y posteada otra vez: otra vez solo lo que nadie pagó" "nueva|2027-01-22 · 6 horas|a 320.00 · b 160.00 · b CO #1 125.00 = 605.00|true/0|true|-" \
  "$IMP|$POST|$(devengo 2027-01)|$(verde 2027-01)"
revisa "«Deshacer» el Z5: vuelven sus horas; las de la nómina siguen fuera" "deshecho|a 480.00 · b 320.00 · b CO #1 125.00 = 925.00|true/0|true|-" \
  "$(deshacer z5)|$(devengo 2027-01)|$(verde 2027-01)"
revisa "repartido otra vez: otra vez solo lo que nadie pagó" "aplicado 2027-01-11 devengo_estandar|a 320.00 · b 160.00 · b CO #1 125.00 = 605.00|true/0|true|-" \
  "$(asi_es z5 2027-01-04 2027-01-10)|$(devengo 2027-01)|$(verde 2027-01)"
D01="$(numero 2027-01)"

echo
echo "== 10. Un mes grande: el control contesta en menos de 1 s, y un Zelle más cabe de sobra (se deshace)"
# Febrero de 2027: 1,500 reportes de un cuarto de hora del ayudante (aprobados: se devengan) y otros 1,500 de 30 jornaleros de
# relleno (50 cada uno), pagados por 300 jornales del mes (5 reportes cada uno); y 2,700 jornales más de esos 30 en los meses
# anteriores (5 reportes cada uno): 3,000 repartos y 15,000 reportes repartidos. Los repartos de relleno van directos a las
# tablas de c10 (con su marca), cada uno con su movimiento del banco y su asiento de verdad; el último Zelle del mes, el del
# jornalero de la escena, entra por su puerta, como el dueño.
reloj 2027-02-26
ed -v ON_ERROR_STOP=1 > "$TMP/10.out" 2>&1 <<SQL
begin;
select set_config('request.jwt.claims', '{"sub":"$DUENO","role":"authenticated","aal":"aal2"}', true);
insert into auth.users (id, email)
select ('00000000-0000-4000-a000-0000000c32' || lpad(n::text, 2, '0'))::uuid, 'c3-jor-relleno-' || n || '@c3-pruebas.invalid' from generate_series(1, 30) n;
insert into perfiles (id, nombre, rol, activo)
select ('00000000-0000-4000-a000-0000000c32' || lpad(n::text, 2, '0'))::uuid, 'ZZ Relleno ' || lpad(n::text, 2, '0'), 'campo', true from generate_series(1, 30) n
on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
insert into costos_equipo (usuario_id, costo_hora)
select ('00000000-0000-4000-a000-0000000c32' || lpad(n::text, 2, '0'))::uuid, 20 from generate_series(1, 30) n
on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
insert into horas (fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el)
select date '2027-02-01' + (g % 19), '$P1', 'c3-jor-a', 0.25, null, 'ZZ C3 JOR: mes grande', '$DUENO', now() from generate_series(1, 1500) g;
insert into horas (fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el)
select date '2027-02-01' + (k % 19), ('00000000-0000-4000-a000-0000000c32' || lpad(n::text, 2, '0'))::uuid, 'c3-jor-b', 0.25, null,
       'ZZ C3 JOR: mes grande (relleno)', '$DUENO', now()
  from generate_series(1, 30) n cross join generate_series(1, 50) k;
-- un reporte más del jornalero de la escena, aprobado, el 22-feb: entra al devengo, y lo paga después el último Zelle, por su puerta
insert into horas (fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el)
values ('2027-02-22', '$P4', 'c3-jor-a', 8, null, 'ZZ C3 JOR: mes grande (el último)', '$DUENO', now());
select 'RESULTADO importados ' || (fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c3-jornal · mes grande',
  'filas', (select jsonb_agg(jsonb_build_object('id', 'c3-jor-vol-' || g,
                                                'fecha', (case when g <= 300 then date '2027-02-02' + (g % 18) when g = 3001 then date '2027-02-23'
                                                               else date '2026-10-05' + (g % 110) end)::text,
                                                'plaid_monto', case when g = 3001 then '168.00' else (100 + g % 50)::text || '.00' end,
                                                'descripcion', case when g = 3001 then 'Zelle payment to ZZ JORNALERO CUATRO 4010'
                                                                    else 'Zelle payment to ZZ RELLENO ' || (50000 + g) end,
                                                'tipo', 'DEBIT', 'pendiente', false))
              from generate_series(1, 3001) g)))->>'filas_nuevas');
do \$\$
declare
  r record; v jsonb; v_id uuid; v_p uuid; n int := 0;
begin
  for r in select m.id, m.fecha, -m.monto as monto, substring(m.id_externo from '[0-9]+\$')::int as g
             from movimientos_banco m where m.id_externo like 'c3-jor-vol-%' and m.id_externo <> 'c3-jor-vol-3001' order by 4 loop
    -- (los 300 de febrero: 10 por persona; los de antes: 90 por persona)
    v_p := ('00000000-0000-4000-a000-0000000c32' || lpad((case when r.g <= 300 then (r.g - 1) / 10 + 1 else r.g % 30 + 1 end)::text, 2, '0'))::uuid;
    v := fn_postear_interno(jsonb_build_object(
           'camino', 'puente', 'fecha', r.fecha::text, 'origen_tabla', 'movimientos_banco', 'origen_id', r.id::text,
           'descripcion', 'ZZ C3 JOR: un jornal de relleno (se deshace)',
           'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5200', 'monto', r.monto::text, 'proyecto_id', 'c3-jor-b'),
                                       jsonb_build_object('cuenta', '1010', 'monto', (-r.monto)::text)),
           'procedencia', jsonb_build_object('funcion', 'c3-jornal.sh')));
    v_id := gen_random_uuid();
    perform set_config('mx_jornal.escribe', 'jornal_repartos', true);
    insert into jornal_repartos (id, movimiento_id, usuario_id, desde, hasta, regla_periodo, monto, horas, tarifa_sale, cuenta, asiento_id, huella)
    values (v_id, r.id, v_p, r.fecha - 7, r.fecha - 1, 'a_mano', r.monto, 1.25, round(r.monto / 1.25, 2), '5200', (v->>'id')::uuid, 'c3-jornal.sh');
    perform set_config('mx_jornal.escribe', 'jornal_reparto_lineas', true);
    insert into jornal_reparto_lineas (reparto_id, n, orden, proyecto_id, co, cuenta, horas, monto) values (v_id, 1, 2, 'c3-jor-b', null, '5200', 1.25, r.monto);
    perform set_config('mx_jornal.escribe', 'jornal_reparto_horas', true);
    if r.g <= 300 then
      -- los 300 de febrero: cinco reportes de verdad de esa persona cada uno
      insert into jornal_reparto_horas (reparto_id, horas_id, n, fecha, proyecto_id, co, fase, horas, monto)
      select v_id, h.id, 1, h.fecha, h.proyecto_id, null, null, h.horas, round(r.monto / 5, 2)
        from (select h.*, row_number() over (order by h.id) as k from horas h
               where h.usuario_id = v_p and h.notas = 'ZZ C3 JOR: mes grande (relleno)') h
       where (h.k - 1) / 5 = (r.g - 1) % 10;
    else
      -- los de antes: cinco reportes de relleno cada uno (su número no es de ningún reporte de hoy)
      insert into jornal_reparto_horas (reparto_id, horas_id, n, fecha, proyecto_id, co, fase, horas, monto)
      select v_id, 900000000 + r.g * 10 + k, 1, r.fecha - k, 'c3-jor-b', null, null, 0.25, round(r.monto / 5, 2) from generate_series(1, 5) k;
    end if;
    perform set_config('mx_jornal.escribe', '', true);
    n := n + 1;
  end loop;
  raise notice 'RESULTADO repartos %', n;
end \$\$;
select 'RESULTADO de relleno ' || (select count(*) from jornal_repartos r where r.huella = 'c3-jornal.sh') || ' repartos y '
       || (select count(*) from jornal_reparto_horas rh join jornal_repartos r on r.id = rh.reparto_id where r.huella = 'c3-jornal.sh') || ' reportes repartidos';
-- (como si cada uno de esos 3,000 jornales se hubiera confirmado en su día: el trigger pasa ahora por sus 3,000 asientos, sin
-- ningún devengo en esos meses todavía, y no hace nada; así al final solo queda por confirmar el último Zelle)
\timing on
set constraints public.trg_puente_asientos_jornal immediate;
\timing off
set constraints public.trg_puente_asientos_jornal deferred;
select 'RESULTADO sin devengo ' || (select count(*) from asientos a where $VIVO and a.origen_id in ('2027-02', '2026-10', '2026-11'));
select 'RESULTADO devengar ' || (r->>'accion') || ' ' || (r->>'total') || ' fuera ' || (r->'pagadas_jornal'->>'reportes') || ' reportes de ' || jsonb_array_length(r->'pagadas_jornal'->'asientos') || ' jornales'
  from fn_horas_devengar('2027-02') r;
$(app aal1)
\timing on
select 'RESULTADO control ' || $CTL;
\timing off
reset role;
-- un Zelle más de febrero, por su puerta (el dueño, con su código): al confirmar, el devengo del mes grande se pone al día solo
select count(fn_banco_casar(m.id)) from movimientos_banco m where m.id_externo = 'c3-jor-vol-3001';
$(app aal2)
\timing on
select 'RESULTADO asi_es ' || (r->>'estado') from (select fn_jornal_aplicar(m.id, '2027-02-22', '2027-02-22', fn_jornal_propuesta(m.id, '2027-02-22', '2027-02-22')->>'visto') as r from movimientos_banco m where m.id_externo = 'c3-jor-vol-3001' offset 0) x;
set constraints public.trg_puente_asientos_jornal immediate;
\timing off
set constraints public.trg_puente_asientos_jornal deferred;
select 'RESULTADO control_despues ' || $CTL;
reset role;
select 'RESULTADO devengo_despues ' || coalesce((select sum(l.monto)::text from asientos a join asiento_lineas l on l.asiento_id = a.id and l.cuenta = '5000' where $VIVO and a.origen_id = '2027-02'), '-');
rollback;
SQL
grep -q 'ERROR' "$TMP/10.out" && { grep -m3 'ERROR' "$TMP/10.out" | sed 's/^/     /'; }
T_REL="$(awk '/RESULTADO de relleno/ {f=1; next} f && /^Time:/ {print int($2); exit}' "$TMP/10.out")"
T_CTL="$(awk '/RESULTADO control true/ {f=1; next} f && /^Time:/ {print int($2); exit}' "$TMP/10.out")"
T_ZEL="$(awk '/RESULTADO asi_es/ {f=1} f && /^Time:/ {s += $2; n++} n == 2 {print int(s); exit}' "$TMP/10.out")"
revisa "el mes grande, montado: 3,001 Zelle, 3,000 repartos y 15,000 reportes repartidos" "importados 3001|repartos 3000|de relleno 3000 repartos y 15000 reportes repartidos" \
  "$(sed -n 's/^.*RESULTADO \(importados .*\)$/\1/p; s/^.*RESULTADO \(repartos .*\)$/\1/p; s/^.*RESULTADO \(de relleno .*\)$/\1/p' "$TMP/10.out" | paste -sd'|' -)"
revisa "sin devengo en esos meses, confirmar 3,000 jornales no devenga nada (el trigger pasó por los 3,000 en ${T_REL:-?} ms)" "sin devengo 0" \
  "$(sed -n 's/^RESULTADO \(sin devengo .*\)$/\1/p' "$TMP/10.out")"
revisa "febrero devengado: los 1,500 reportes del ayudante y el último del jornalero (9,535.00); los 1,500 que pagaron los 300 jornales del mes, fuera" \
  "devengar posteado 9535.00 fuera 1500 reportes de 300 jornales" "$(sed -n 's/^RESULTADO \(devengar .*\)$/\1/p' "$TMP/10.out")"
revisa "el control de los puentes, como el dueño por la API, sigue en verde" "control true/0" "$(sed -n 's/^RESULTADO \(control true.*\|control false.*\)$/\1/p' "$TMP/10.out")"
revisa "y contesta en menos de 1 s (tardó ${T_CTL:-?} ms)" "sí" "$([ -n "${T_CTL:-}" ] && [ "$T_CTL" -lt 1000 ] && echo sí || echo "no: ${T_CTL:-sin medir} ms")"
revisa "un Zelle más en ese mes: «Así es» y el devengo al día al confirmar, dentro del tope de la API (tardó ${T_ZEL:-?} ms de 8,000)" "asi_es aplicado|control_despues true/0|devengo_despues 9375.00|sí" \
  "$(sed -n 's/^RESULTADO \(asi_es .*\)$/\1/p; s/^RESULTADO \(control_despues .*\)$/\1/p; s/^RESULTADO \(devengo_despues .*\)$/\1/p' "$TMP/10.out" | paste -sd'|' -)|$([ -n "${T_ZEL:-}" ] && [ "$T_ZEL" -lt 8000 ] && echo sí || echo "no: ${T_ZEL:-sin medir} ms")"
revisa "y deshecho, febrero queda sin devengo, sin esas horas, sin esos repartos y sin esas personas" "-|0|0|0" \
  "$(numero 2027-02)|$(ed -c "select count(*) from horas where notas like 'ZZ C3 JOR: mes grande%'")|$(ed -c "select count(*) from jornal_repartos where huella = 'c3-jornal.sh'")|$(ed -c "select count(*) from perfiles where nombre like 'ZZ Relleno %'")"

echo
echo "== 11. El jornal a la vez que el devengo: dos sesiones de verdad, en los dos órdenes"
reloj 2027-03-31
MA="$(mov za)"; MB="$(mov zb)"
# espera_a <archivo>: hasta que esa sesión dijo su RESULTADO (ya hizo lo suyo y duerme antes de confirmar), o 10 s
espera_a() { local i; for i in $(seq 1 100); do grep -q 'RESULTADO' "$1" 2>/dev/null && return 0; sleep 0.1; done; return 1; }
revisa "marzo, sin devengo; sus horas aprobadas con obra y con costo, a estándar: 720.00 (lo dice el plan)" "-|720.00" \
  "$(numero 2027-03)|$(ed -c "select fn_puente_devengo_plan('2027-03')->>'total'")"
# (a) EL JORNAL PRIMERO: «Así es» en el ZA (el dueño, con su código) y, antes de que confirme, Edgar devenga marzo en otra sesión.
ed -v ON_ERROR_STOP=1 > "$TMP/11a-jornal.out" 2>&1 <<SQL &
begin; $(app aal2)
select 'RESULTADO ' || (fn_jornal_aplicar('$MA', '2027-03-01', '2027-03-07', fn_jornal_propuesta('$MA', '2027-03-01', '2027-03-07')->>'visto')->>'estado');
select pg_sleep(3);
commit;
SQL
espera_a "$TMP/11a-jornal.out"
T0=$(date +%s%N)
ed -v ON_ERROR_STOP=1 > "$TMP/11a-devengo.out" 2>&1 <<SQL
begin; $(app aal1)
select 'RESULTADO ' || (fn_horas_devengar('2027-03')->>'accion');
commit;
SQL
T_A=$(( ($(date +%s%N) - T0) / 1000000 ))
wait
revisa "(a) el jornal primero: las dos sesiones confirmaron sin error, y el devengo esperó su turno (${T_A} ms)" "aplicado|posteado|0|esperó" \
  "$(sed -n 's/^RESULTADO //p' "$TMP/11a-jornal.out")|$(sed -n 's/^RESULTADO //p' "$TMP/11a-devengo.out")|$(cat "$TMP/11a-jornal.out" "$TMP/11a-devengo.out" | grep -ci 'error')|$([ "$T_A" -ge 1000 ] && echo esperó || echo "no esperó")"
revisa "el devengo miró DESPUÉS de esperar: entró ya sin las 14 h que pagó el jornal (440.00, no 720.00), y nada en rojo" \
  "a 360.00 · b 80.00 = 440.00|true/0|true|-" "$(devengo 2027-03)|$(verde 2027-03)"
revisa "y su asiento lo dice: fuera 14 h que un jornal ya había pagado, con su asiento" "sí" \
  "$(ed -c "select case when a.descripcion like '%fuera 14 h que un jornal ya había pagado ($(asiento_de za))%' then 'sí' else 'no: ' || a.descripcion end from asientos a where a.numero = '$(numero 2027-03)'")"
# (b) EL DEVENGO PRIMERO: una hora más aprobada a mano (el devengo queda «de ayer» y el control lo dice); Edgar devenga otra vez
# y, antes de que confirme, «Así es» en el ZB en otra sesión.
ed -v ON_ERROR_STOP=1 -c "insert into horas (fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el) values ('2027-03-17', '$P1', 'c3-jor-a', 8, null, 'ZZ C3 JOR', '$DUENO', now())"
revisa "una hora más aprobada a mano en marzo: su devengo quedó «de ayer», y el control lo dice" "false/1" "$(control)"
ed -v ON_ERROR_STOP=1 > "$TMP/11b-devengo.out" 2>&1 <<SQL &
begin; $(app aal1)
select 'RESULTADO ' || (fn_horas_devengar('2027-03')->>'accion');
select pg_sleep(3);
commit;
SQL
espera_a "$TMP/11b-devengo.out"
T0=$(date +%s%N)
ed -v ON_ERROR_STOP=1 > "$TMP/11b-jornal.out" 2>&1 <<SQL
begin; $(app aal2)
select 'RESULTADO ' || (fn_jornal_aplicar('$MB', '2027-03-08', '2027-03-14', fn_jornal_propuesta('$MB', '2027-03-08', '2027-03-14')->>'visto')->>'estado');
commit;
SQL
T_B=$(( ($(date +%s%N) - T0) / 1000000 ))
wait
revisa "(b) el devengo primero: las dos sesiones confirmaron sin error, y el jornal esperó su turno (${T_B} ms)" "sustituido|aplicado|0|esperó" \
  "$(sed -n 's/^RESULTADO //p' "$TMP/11b-devengo.out")|$(sed -n 's/^RESULTADO //p' "$TMP/11b-jornal.out")|$(cat "$TMP/11b-devengo.out" "$TMP/11b-jornal.out" | grep -ci 'error')|$([ "$T_B" -ge 1000 ] && echo esperó || echo "no esperó")"
revisa "el jornal vio el devengo recién puesto y, al confirmar, lo dejó al día solo: queda lo que nadie pagó (16 h × 25), y nada en rojo" \
  "a 400.00 = 400.00|true/0|true|-" "$(devengo 2027-03)|$(verde 2027-03)"
revisa "en el libro, marzo: el devengo de lo que nadie pagó (5000) y los dos Zelle (5200): cada hora, una vez" "a 400.00|a 340.00 · b 213.00" \
  "$(libro 2027-03 5000)|$(libro 2027-03 5200)"
D03="$(numero 2027-03)"

echo
echo "== 12. Los repartos de los jornales, con otra forma: no se supone nada"
# (como un c10 que c3 no conoce: a su tabla de detalle se le cambia el nombre de una columna; al final de la escena vuelve)
ed -v ON_ERROR_STOP=1 -c "alter table public.jornal_reparto_horas rename column horas_id to horas_id_otra_forma" \
  || { echo "No se pudo cambiar la columna de jornal_reparto_horas" >&2; exit 2; }
revisa "el plan lo dice: no pudo leer qué horas pagaron los jornales, y no da ninguna por pagada" "jornales_sin_leer|error|0" \
  "$(ed -c "select (pl->>'codigo') || '|' || (pl->'corte'->'jornales'->>'lectura') || '|' || coalesce(pl->'corte'->'jornales'->>'reportes', '0') from (select fn_puente_devengo_plan('2027-03') as pl) x")"
revisa "devengar un mes sin devengo (febrero) se NIEGA en vez de devengar a ciegas, y dice qué pegar (el dueño, sin el código)" "1" \
  "$(devengar 2027-02 aal1 | grep -c 'No se pudo leer qué horas de 2027-02 pagaron ya los jornales.*no se devenga.*c10-costo-obra.sql')"
revisa "el devengo que había (marzo) se queda como estaba: ni se rehace ni se deshace (el mismo asiento)" "retenido|$D03" "$(devengar 2027-03 aal1)|$(numero 2027-03)"
revisa "el control «devengo» lo dice de cada mes abierto con devengo (diciembre, enero y marzo): no se puede comprobar" "false/3|3" \
  "$(control)|$(ed -c "select count(*) from fn_puentes_verificar() c cross join lateral jsonb_array_elements_text(c.detalle->'fallan') f(v) where c.control = 'devengo' and f.v like '%no se puede comprobar: no se pudo leer qué horas pagaron ya los jornales%c10-costo-obra.sql%el mes no se cierra así%'")"
revisa "y un mes así NO se cierra, y dice qué hacer (se deshace)" "MX008/dice_como" \
  "$(ed -v ON_ERROR_STOP=1 <<'SQL' 2>&1 | sed -n 's/^.*RESULTADO //p; /ERROR/p'
begin;
do $$
declare
  v_b text; v_q text;
begin
  lock table public.periodos in exclusive mode;
  if not exists (select 1 from asientos a where a.tipo = 'apertura') then
    perform fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', (select to_char(p.desde, 'YYYY-MM-DD') from periodos p where p.tipo = 'apertura' order by p.desde limit 1),
      'descripcion', 'ZZ C3 JOR: apertura de prueba (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1010', 'monto', '1000.00'), jsonb_build_object('cuenta', '3900', 'monto', '-1000.00'))));
  end if;
  begin
    for v_q in select p.periodo from periodos p where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= date '2026-12-01' order by p.desde loop
      perform fn_cerrar_periodo(v_q);
    end loop;
    v_b := 'cerrado';
  exception when others then
    v_b := sqlstate || case when sqlerrm like '%2026-12 no se cierra%sin comprobar%no se pudo leer qué horas pagaron ya los jornales%c10-costo-obra.sql%fn_horas_devengar(''2026-12'')%' then '/dice_como' else ': ' || sqlerrm end;
  end;
  raise notice 'RESULTADO %', v_b;
end $$;
rollback;
SQL
)"
ed -v ON_ERROR_STOP=1 -c "alter table public.jornal_reparto_horas rename column horas_id_otra_forma to horas_id" \
  || { echo "No se pudo devolver la columna de jornal_reparto_horas" >&2; exit 2; }
revisa "con la columna de vuelta: los mismos asientos, todo en verde, y devengar no hace nada" "$D12|$D01|$D03|true/0|true|sin_cambios" \
  "$(numero 2026-12)|$(numero 2027-01)|$(numero 2027-03)|$(control)|$(c50)|$(devengar 2027-03 aal1)"

echo
echo "== 13. El devengo que se queda sin horas, y vuelve; y el trigger en «immediate»"
reloj 2027-04-30
# El papel del devengo de un mes en el puente (su estado y su código), y si su devengo vivo sustituye a uno deshecho.
papel() { ed -c "select coalesce((select d.estado || '/' || coalesce(d.codigo, '-') from puente_documentos d where d.tabla = 'horas_devengo' and d.documento_id = '$1'), 'sin papel')"; }
sustituye() { ed -c "select coalesce((select case when a.sustituye_a is not null then 'sustituye' else 'no sustituye' end from asientos a where $VIVO and a.origen_id = '$1'), '-')"; }
revisa "abril devengado: las horas del jornalero, aprobadas y sin pagar (14 h × 20)" "posteado|a 160.00 · b 120.00 = 280.00" "$(devengar 2027-04 aal1)|$(devengo 2027-04)"
revisa "«Así es» en el ZC (9-abr): las horas de su semana salen del devengo" "aplicado 2027-04-09 devengo_estandar|b 120.00 = 120.00|true/0|true|-" \
  "$(asi_es zc 2027-04-05 2027-04-11)|$(devengo 2027-04)|$(verde 2027-04)"
revisa "«Así es» en el ZD (16-abr): ya no queda nada trabajado y sin pagar: el devengo SE DESHACE, y su papel lo dice" \
  "aplicado 2027-04-16 devengo_estandar|sin devengo|no_aplica/sin_horas|true/0|true|-" \
  "$(asi_es zd 2027-04-12 2027-04-18)|$(devengo 2027-04)|$(papel 2027-04)|$(verde 2027-04)"
revisa "«Deshacer» el ZD: sus horas vuelven a estar sin pagar, y el devengo VUELVE solo, como sustituto del que se deshizo" \
  "deshecho|b 120.00 = 120.00|sustituye|contabilizado/-|true/0|true|-" \
  "$(deshacer zd)|$(devengo 2027-04)|$(sustituye 2027-04)|$(papel 2027-04)|$(verde 2027-04)"
revisa "des-casar el ZC en la Bandeja: las suyas, también; y «Deshacer» cierra su reparto suelto" "clasificado|a 160.00 · b 120.00 = 280.00|deshecho|true/0|true" \
  "$(descasar zc)|$(devengo 2027-04)|$(deshacer zc)|$(control)|$(c50)"
# EL TRIGGER EN «IMMEDIATE» (la app no lo pone así nunca; las pruebas sí): no corre al confirmar, sino al terminar la sentencia
# que insertó el asiento.
MC="$(mov zc)"
ed -v ON_ERROR_STOP=1 > "$TMP/13a.out" 2>&1 <<SQL
begin; $(app aal2)
set constraints public.trg_puente_asientos_jornal immediate;
select 'RESULTADO ' || (fn_jornal_aplicar('$MC', '2027-04-05', '2027-04-11', fn_jornal_propuesta('$MC', '2027-04-05', '2027-04-11')->>'visto')->>'estado');
commit;
SQL
revisa "en «immediate», un «Así es» corre ANTES de que c10 guarde el reparto: el pago entra, y el devengo se queda como estaba" \
  "aplicado|a 160.00 · b 120.00 = 280.00" "$(sed -n 's/^RESULTADO //p' "$TMP/13a.out")|$(devengo 2027-04)"
revisa "no queda callado: el control lo dice (8 h que un jornal ya pagó), y fn_horas_devengar lo pone al día" "false/1|8 h|sustituido|b 120.00 = 120.00|true/0" \
  "$(control)|$(ed -c "select coalesce(substring(f.v from 'cuenta ([0-9.]+ h) que un jornal ya pagó dentro del mes'), '?') from fn_puentes_verificar() c cross join lateral jsonb_array_elements_text(c.detalle->'fallan') f(v) where c.control = 'devengo'")|$(devengar 2027-04 aal1)|$(devengo 2027-04)|$(control)"
ed -v ON_ERROR_STOP=1 > "$TMP/13b.out" 2>&1 <<SQL
begin; $(app aal2)
set constraints public.trg_puente_asientos_jornal immediate;
select 'RESULTADO ' || (fn_jornal_deshacer((select id from jornal_repartos where movimiento_id = '$MC' and estado = 'aplicado'), 'ZZ C3 JOR: se deshace con el trigger en immediate')->>'estado');
commit;
SQL
revisa "en «immediate», un «Deshacer» pone el devengo al día en ese momento; el libro queda en orden (cada asiento, con su número y su sello en la cadena)" \
  "deshecho|a 160.00 · b 120.00 = 280.00|true/0|true|" \
  "$(sed -n 's/^RESULTADO //p' "$TMP/13b.out")|$(devengo 2027-04)|$(control)|$(c50)|$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_verificar_cadena() where not ok and control in ('hash', 'enlace', 'numeracion', 'contadores', 'cuadre', 'reversos')")"
D04="$(numero 2027-04)"

echo
echo "== 14. Volver a pegar c3 (dos veces) con todo dentro, y sus pruebas"
reloj_de_verdad
for i in 1 2; do
  pegar "$DOCS/c3-puentes.sql" > "$TMP/11c3-$i.out" 2>&1 || { tail -n 20 "$TMP/11c3-$i.out"; echo "FALLÓ volver a pegar c3 (vez $i)" >&2; exit 2; }
done
revisa "los devengos son los mismos asientos, y todo sigue en verde" "$D12|$D01|$D03|$D04|true/0|true" "$(numero 2026-12)|$(numero 2027-01)|$(numero 2027-03)|$(numero 2027-04)|$(control)|$(c50)"
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" \
  -c '\o /dev/null' -f "$DOCS/c3-pruebas.sql" -c '\o' \
  -c "select format('PRUEBAS total=%s ok=%s fallan=%s omitidas=%s', count(*), count(*) filter (where ok), count(*) filter (where not ok), count(*) filter (where ok is null)) from _pruebas" \
  -c "select n || ' ' || case when ok is null then 'omitida' else 'FALLA' end || ': ' || left(coalesce(obtenido, ''), 300) from _pruebas where ok is not true order by n" \
  -At > "$TMP/11pruebas.out" 2>&1 || { tail -n 20 "$TMP/11pruebas.out"; echo "FALLÓ c3-pruebas.sql" >&2; exit 2; }
grep -E '^PRUEBAS|^[0-9]+ (FALLA|omitida)' "$TMP/11pruebas.out" | sed 's/^/     /'
revisa "c3-pruebas.sql con los Zelle y la nómina de verdad dentro: ninguna falla" "0" "$(sed -n 's/^PRUEBAS .* fallan=\([0-9]*\) .*/\1/p' "$TMP/11pruebas.out")"
revisa "y las del corte de los jornales (de la 127 a la 136) corrieron: ninguna omitida" "0" \
  "$(grep -cE '^1(2[7-9]|3[0-6]) omitida' "$TMP/11pruebas.out")"

echo
echo "== Al final"
revisa "la cadena del libro, en verde (los permisos y las huellas también, con el reloj de vuelta)" "" \
  "$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_verificar_cadena() where not ok")"
revisa "los puentes (c3), sin nada nuevo en rojo" "$ROJOS_C3" "$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_puentes_verificar() where not ok")"
revisa "los cuadres del jornal (c10), sin rojos" "" \
  "$(ed -c "select coalesce(string_agg(orden::text, ', ' order by orden), '') from v_jornal_control where not ok and nivel = 'cuadre'")"
revisa "los cuadres de la nómina (c15), sin rojos" "" \
  "$(ed -c "select coalesce(string_agg(orden::text, ', ' order by orden), '') from fn_nomina_control() where not ok and nivel = 'cuadre'")"

echo
if [ $malos -eq 0 ]; then echo "c3-jornal: todo en orden"; else echo "c3-jornal: ALGO FALLA (arriba)"; fi
exit $malos
