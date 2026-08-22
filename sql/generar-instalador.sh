#!/bin/bash
# Genera sql/00-instalar.sql uniendo los scripts del esquema en un solo archivo
# envuelto en una transaccion. Ejecutar despues de modificar cualquier 0X-*.sql.
#
#   bash sql/generar-instalador.sh
set -e
cd "$(dirname "$0")"

SALIDA=00-instalar.sql

cat > "$SALIDA" <<'CABECERA'
-- ============================================================================
-- Enlace Enfermero — INSTALADOR COMPLETO
--
-- ARCHIVO GENERADO. No lo edites: se sobreescribe.
-- Sale de unir 01-schema, 02-rls, 03-funciones, 04-vistas y 05-seed.
-- Para regenerarlo despues de cambiar alguno:  bash sql/generar-instalador.sh
--
-- COMO USARLO
--   1. Crea antes los tres buckets en Storage: fotos (publico),
--      documentos (privado) y comprobantes (privado).
--   2. Copia todo este archivo, pegalo en el SQL Editor de Supabase y Run.
--   3. Debe terminar en "Success". Va dentro de una transaccion: si algo
--      falla, no se aplica nada y puedes corregir y reintentar sin limpiar.
--   4. Despues ejecuta 99-pruebas.sql para verificar.
--
-- Incluye 12 perfiles ficticios de prueba. Para instalar sin ellos, ejecuta
-- por separado 01, 02, 03 y 04, y omite 05-seed.sql.
-- ============================================================================

begin;

CABECERA

for f in 01-schema.sql 02-rls.sql 03-funciones.sql 04-vistas.sql 06-dashboard.sql 07-solicitudes.sql 08-documentos.sql 09-operacion.sql 10-finanzas.sql 05-seed.sql; do
  {
    echo ""
    echo "-- ############################################################################"
    echo "-- ###  $f"
    echo "-- ############################################################################"
    echo ""
    cat "$f"
  } >> "$SALIDA"
done

cat >> "$SALIDA" <<'PIE'

commit;

-- ============================================================================
-- Listo. Ahora:
--   1. Settings -> API: copia Project URL y la llave `anon public`
--      a js/config.js. La llave `service_role` NUNCA va en el frontend.
--   2. Ejecuta 99-pruebas.sql: todos los renglones deben decir OK.
-- ============================================================================
PIE

echo "Generado: sql/$SALIDA ($(wc -l < "$SALIDA" | tr -d ' ') lineas)"
