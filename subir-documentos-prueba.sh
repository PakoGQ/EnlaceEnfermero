#!/bin/bash
# ============================================================================
# Sube al Storage LOCAL los PDF de prueba que corresponden a los documentos
# registrados en la base, para que el visor de la bandeja funcione de verdad.
#
#   bash subir-documentos-prueba.sh
#
# Usa la llave de servicio local, que es una clave de desarrollo publica.
# NUNCA correr esto contra produccion.
# ============================================================================
set -uo pipefail

API="http://127.0.0.1:54321"

# La llave se lee del entorno local en vez de estar escrita aqui: asi este
# archivo no lleva ningun token y es imposible que apunte a otro proyecto.
LLAVE=$(supabase status -o json 2>/dev/null | python3 -c "
import json,sys
try: print(json.load(sys.stdin).get('SERVICE_ROLE_KEY',''))
except Exception: print('')
")

if [ -z "$LLAVE" ]; then
  echo "No pude leer la llave local. Levanta el entorno con: supabase start"
  exit 1
fi
ORIGEN="/tmp/docs-prueba"
BD="postgresql://postgres:postgres@127.0.0.1:54322/postgres"

if [ ! -d "$ORIGEN" ]; then
  echo "No hay PDF de prueba en $ORIGEN."
  exit 1
fi

echo "Subiendo documentos de prueba al bucket privado..."
subidos=0; fallidos=0

while IFS='|' read -r ruta tipo; do
  [ -z "$ruta" ] && continue
  archivo="$ORIGEN/$tipo.pdf"
  [ -f "$archivo" ] || archivo="$ORIGEN/ine.pdf"   # respaldo genérico

  # La ruta guardada incluye el bucket: se quita para el destino
  destino="${ruta#documentos/}"

  codigo=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    "$API/storage/v1/object/documentos/$destino" \
    -H "Authorization: Bearer $LLAVE" \
    -H "Content-Type: application/pdf" \
    -H "x-upsert: true" \
    --data-binary "@$archivo")

  if [ "$codigo" = "200" ]; then
    subidos=$((subidos+1))
  else
    fallidos=$((fallidos+1))
    [ "$fallidos" -le 3 ] && echo "  fallo ($codigo): $destino"
  fi
done < <(psql "$BD" -tAc "select archivo_url || '|' || tipo from public.documentos;")

echo "  subidos: $subidos   fallidos: $fallidos"
echo
psql "$BD" -tAc "select count(*) from storage.objects where bucket_id='documentos';" \
  | xargs echo "  archivos en el bucket:"
