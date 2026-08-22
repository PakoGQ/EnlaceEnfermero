#!/bin/bash
# ============================================================================
# Aplica el esquema de Enlace Enfermero a la base de Supabase local
# y deja js/config.js con la llave anon de este entorno.
#
#   bash aplicar-esquema.sh
#
# Se puede correr las veces que haga falta: reinicia la base desde cero.
# Solo toca el entorno LOCAL. La configuracion de produccion no se modifica.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

BD="postgresql://postgres:postgres@127.0.0.1:54322/postgres"

echo "============================================================"
echo "  Instalando el esquema en Supabase local"
echo "============================================================"
echo

if ! supabase status >/dev/null 2>&1; then
  echo "Supabase local no esta corriendo. Levantalo con:"
  echo "  supabase start"
  exit 1
fi

echo "[1/3] Limpiando la base..."
supabase db reset --no-seed >/dev/null 2>&1 || {
  echo "      No se pudo reiniciar. Continuando sobre la base actual."
}

echo "[2/3] Aplicando sql/00-instalar.sql..."
if psql "$BD" -v ON_ERROR_STOP=1 -q -f sql/00-instalar.sql 2>/tmp/ee-instalar.log; then
  echo "      OK"
else
  echo "      FALLO:"
  grep -v '^NOTICE' /tmp/ee-instalar.log | head -15
  exit 1
fi

echo "[3/3] Capturando la llave anon en js/config.js..."
LLAVE=$(supabase status -o json 2>/dev/null | python3 -c "
import json,sys
try: print(json.load(sys.stdin).get('ANON_KEY',''))
except Exception: print('')
")

if [ -z "$LLAVE" ]; then
  LLAVE=$(supabase status 2>/dev/null | grep -i 'anon key' | awk '{print $NF}')
fi

if [ -z "$LLAVE" ]; then
  echo "      No se pudo leer la llave. Corre 'supabase status' y pegala a mano."
else
  python3 - "$LLAVE" <<'PY'
import re, sys
llave = sys.argv[1]
p = 'js/config.js'
s = open(p, encoding='utf-8').read()
s = re.sub(r"(\? ')[^']*('\s*\n\s*: 'TU_ANON_KEY')", r"\1" + llave + r"\2", s, count=1)
open(p, 'w', encoding='utf-8').write(s)
print('      OK')
PY
fi

echo
echo "============================================================"
psql "$BD" -X -c "
select (select count(*) from public.enfermeros_publico) as catalogo,
       (select count(*) from public.solicitudes)        as solicitudes,
       (select count(*) from pg_policies
        where schemaname in ('public','storage'))       as politicas;"
echo "Studio: http://127.0.0.1:54323"
echo "Sitio:  http://localhost:8000   (python3 servidor.py)"
echo "============================================================"
