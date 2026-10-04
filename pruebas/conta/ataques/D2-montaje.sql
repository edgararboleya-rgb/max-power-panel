-- [Pestaña 1] apertura mínima
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (ataque D2)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
