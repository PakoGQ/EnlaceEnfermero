#!/bin/bash
# ============================================================================
# Crea usuarios de prueba en el Supabase LOCAL, uno por cada rol.
#
#   bash crear-usuarios-prueba.sh
#
# Usa la API de administracion con la llave de servicio local, que es una clave
# de desarrollo publica y conocida. NUNCA correr esto contra produccion.
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
CLAVE="prueba1234"

if ! curl -s -o /dev/null "$API/auth/v1/health"; then
  echo "Supabase local no responde. Levantalo con: supabase start"
  exit 1
fi

crear() {
  local correo="$1" nombre="$2" apellidos="$3" rol="$4" telefono="$5"

  respuesta=$(curl -s -X POST "$API/auth/v1/admin/users" \
    -H "apikey: $LLAVE" \
    -H "Authorization: Bearer $LLAVE" \
    -H "Content-Type: application/json" \
    -d "{
      \"email\": \"$correo\",
      \"password\": \"$CLAVE\",
      \"email_confirm\": true,
      \"user_metadata\": {
        \"nombre\": \"$nombre\",
        \"apellidos\": \"$apellidos\",
        \"rol\": \"$rol\",
        \"telefono\": \"$telefono\"
      }
    }")

  if echo "$respuesta" | grep -q '"id"'; then
    printf "  %-28s %-12s OK\n" "$correo" "$rol"
  elif echo "$respuesta" | grep -qi "already been registered\|already exists"; then
    printf "  %-28s %-12s ya existia\n" "$correo" "$rol"
  else
    printf "  %-28s %-12s FALLO\n" "$correo" "$rol"
    echo "     $(echo "$respuesta" | head -c 160)"
  fi
}

echo "Creando usuarios de prueba (contrasena: $CLAVE)"
echo
crear "admin@enlace.test"       "Paco"    "Gaitán"    "admin"       "+523311111111"
crear "coordinador@enlace.test" "Lucía"   "Márquez"   "coordinador" "+523312222222"
crear "enfermero@enlace.test"   "María"   "Ruiz"      "enfermero"   "+523313333333"
crear "cliente@enlace.test"     "Norma"   "Bañuelos"  "cliente"     "+523314444444"

echo
echo "Ligando el usuario enfermero con un perfil del catalogo..."
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -q -c "
update public.enfermeros
set usuario_id = (select id from public.usuarios where email = 'enfermero@enlace.test')
where nombre_completo = 'María Fernanda Ruiz Delgado'
  and usuario_id is null;" 2>/dev/null && echo "  OK"

# La ficha de cliente la crea el trigger tg_ficha_cliente al insertarse el
# usuario, pero nace vacia. Se descarta y en su lugar la cuenta se liga al
# hospital que el seed ya dejo con solicitudes, turnos y pagos: sin historia
# el panel del cliente no se puede validar (se ve igual que uno recien creado).
echo "Ligando la cuenta de cliente con el hospital del seed..."
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -q -c "
delete from public.clientes c
where c.usuario_id = (select id from public.usuarios where email = 'cliente@enlace.test')
  and not exists (select 1 from public.solicitudes s where s.cliente_id = c.id);

update public.clientes
set usuario_id      = (select id from public.usuarios where email = 'cliente@enlace.test'),
    nombre_contacto = 'Norma Bañuelos',
    tipo            = 'hospital',
    municipio       = 'guadalajara'
where razon_social = 'Hospital San Rafael'
  and notas = 'SEED';" 2>/dev/null && echo "  OK"

echo
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -X -c "
select u.email, u.rol, u.nombre || ' ' || coalesce(u.apellidos,'') as nombre,
       case when e.id is not null then e.folio
            when c.id is not null then 'cliente'
            else '' end as ficha
from public.usuarios u
left join public.enfermeros e on e.usuario_id = u.id
left join public.clientes  c on c.usuario_id = u.id
order by u.rol;" 2>/dev/null
