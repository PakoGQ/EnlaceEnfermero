-- ============================================================================
-- Enlace Enfermero — 98. Cuentas de prueba en un proyecto HOSPEDADO
--
-- Archivo de apoyo, NO forma parte del esquema. Sirve para dejar listo un
-- entorno de pruebas en la nube, donde `crear-usuarios-prueba.sh` no sirve
-- porque ese script solo habla con el Supabase local.
--
-- ANTES de ejecutarlo, crea las cuatro cuentas a mano en el panel de Supabase:
--
--   Authentication -> Users -> Add user -> Create new user
--
--   Correo                      Contrasena     Auto Confirm User
--   admin@enlace.test           prueba1234     SI
--   coordinador@enlace.test     prueba1234     SI
--   enfermero@enlace.test       prueba1234     SI
--   cliente@enlace.test         prueba1234     SI
--
-- Marca "Auto Confirm User" en las cuatro: sin eso Supabase manda un correo de
-- confirmacion a un dominio que no existe y la cuenta nunca se activa.
--
-- Las cuatro nacen con rol `cliente`, porque el rol viaja en los metadatos del
-- registro y el panel de Supabase no los pide. Este script corrige los roles y
-- liga las fichas. Ejecutalo COMPLETO en el SQL Editor, despues de 00-instalar.
--
-- NUNCA lo corras sobre datos reales: las contrasenas son publicas.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. Rol y nombre de cada cuenta
-- ----------------------------------------------------------------------------
update public.usuarios u
set rol       = v.rol::rol_usuario,
    nombre    = v.nombre,
    apellidos = v.apellidos,
    telefono  = v.telefono
from (values
  ('admin@enlace.test',       'admin',       'Paco',  'Gaitán',   '+523311111111'),
  ('coordinador@enlace.test', 'coordinador', 'Lucía', 'Márquez',  '+523312222222'),
  ('enfermero@enlace.test',   'enfermero',   'María', 'Ruiz',     '+523313333333'),
  ('cliente@enlace.test',     'cliente',     'Norma', 'Bañuelos', '+523314444444')
) as v(email, rol, nombre, apellidos, telefono)
where u.email = v.email;

-- ----------------------------------------------------------------------------
-- 2. Fichas de cliente que sobran
--
-- El trigger tg_ficha_cliente le crea ficha a todo usuario que nace con rol
-- `cliente`, y las cuatro nacen asi. Al corregir el rol arriba, admin,
-- coordinacion y enfermeria se quedan con una ficha de cliente que no les toca.
-- ----------------------------------------------------------------------------
delete from public.clientes c
where c.usuario_id in (
  select id from public.usuarios
  where email in ('admin@enlace.test', 'coordinador@enlace.test', 'enfermero@enlace.test')
);

-- ----------------------------------------------------------------------------
-- 3. La cuenta de enfermeria se liga a un perfil del catalogo
-- Sin esto el panel del profesional no tiene de donde leer: todas sus
-- funciones cuelgan de mi_enfermero_id().
-- ----------------------------------------------------------------------------
update public.enfermeros
set usuario_id = (select id from public.usuarios where email = 'enfermero@enlace.test')
where nombre_completo = 'María Fernanda Ruiz Delgado'
  and usuario_id is null;

-- ----------------------------------------------------------------------------
-- 4. La cuenta de cliente se liga al hospital del seed
--
-- Su ficha automatica nace vacia, y un panel sin solicitudes ni turnos se ve
-- igual que uno recien creado: no hay nada que probar. Se descarta y en su
-- lugar se toma el hospital que el seed ya dejo con historia.
-- ----------------------------------------------------------------------------
delete from public.clientes c
where c.usuario_id = (select id from public.usuarios where email = 'cliente@enlace.test')
  and not exists (select 1 from public.solicitudes s where s.cliente_id = c.id);

update public.clientes
set usuario_id      = (select id from public.usuarios where email = 'cliente@enlace.test'),
    nombre_contacto = 'Norma Bañuelos',
    tipo            = 'hospital',
    municipio       = 'guadalajara'
where razon_social = 'Hospital San Rafael'
  and notas = 'SEED';

commit;

-- ----------------------------------------------------------------------------
-- Verificacion: las cuatro cuentas con su rol y su ficha
-- ----------------------------------------------------------------------------
select u.email,
       u.rol,
       u.nombre || ' ' || coalesce(u.apellidos, '') as nombre,
       case when e.id is not null then e.folio
            when c.id is not null then coalesce(c.razon_social, 'cliente')
            else '—' end as ficha,
       case when a.confirmed_at is null then 'SIN CONFIRMAR' else 'lista' end as estado
from public.usuarios u
left join auth.users        a on a.id = u.id
left join public.enfermeros e on e.usuario_id = u.id
left join public.clientes   c on c.usuario_id = u.id
where u.email like '%@enlace.test'
order by u.rol;

-- Debe devolver cuatro renglones:
--   admin        Paco Gaitán      —                     lista
--   cliente      Norma Bañuelos   Hospital San Rafael   lista
--   coordinador  Lucía Márquez    —                     lista
--   enfermero    María Ruiz       EE-00001              lista
--
-- Si alguno dice SIN CONFIRMAR, vuelve a Authentication -> Users y confirmalo
-- a mano; si no, no va a poder iniciar sesion.
