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


-- ############################################################################
-- ###  01-schema.sql
-- ############################################################################

-- ============================================================================
-- Enlace Enfermero — 01. Esquema
-- Tipos enumerados, tablas e indices. Definido en CLAUDE.md seccion 5.
-- Ejecutar en el SQL Editor de Supabase, en este orden:
--   01-schema.sql -> 02-rls.sql -> 03-funciones.sql -> 04-vistas.sql -> 05-seed.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TIPOS ENUMERADOS
-- ----------------------------------------------------------------------------
create type rol_usuario      as enum ('admin', 'coordinador', 'enfermero', 'cliente');
create type nivel_enfermeria as enum ('auxiliar', 'tecnico', 'general', 'licenciado', 'especialista', 'cuidador');
create type tipo_cliente     as enum ('particular', 'hospital', 'clinica', 'asilo', 'aseguradora', 'empresa');
create type tipo_servicio    as enum ('turno_hospitalario', 'cuidado_domiciliario', 'colocacion_permanente', 'evento', 'traslado');
create type turno_tipo       as enum ('matutino', 'vespertino', 'nocturno', 'guardia_12', 'guardia_24', 'fin_semana');
create type estatus_solicitud  as enum ('nueva', 'en_busqueda', 'propuesta_enviada', 'confirmada', 'en_curso', 'completada', 'cancelada');
create type estatus_asignacion as enum ('propuesta', 'aceptada', 'rechazada', 'en_curso', 'completada', 'no_asistio', 'cancelada');
create type estatus_verif    as enum ('pendiente', 'en_revision', 'verificado', 'rechazado', 'vencido');
create type tipo_documento   as enum ('ine', 'curp', 'cedula_profesional', 'titulo', 'comprobante_domicilio', 'certificado_bls', 'certificado_acls', 'carta_no_antecedentes', 'examen_medico', 'vacunacion', 'cv', 'referencia_laboral');
create type estatus_pago     as enum ('pendiente', 'parcial', 'pagado', 'vencido', 'cancelado');
-- Variables que determinan la cotizacion (CLAUDE.md 15.5)
create type nivel_atencion   as enum ('observacion', 'basico', 'enfermeria', 'especializado');
create type entorno_servicio as enum ('domicilio', 'hospital', 'clinica', 'asilo', 'empresa', 'evento');

-- Tipos auxiliares no listados en el CLAUDE.md pero necesarios para `pagos`
-- y `referidos`. Se documentan aqui para que el modelo quede explicito.
create type tipo_pago        as enum ('cobro_cliente', 'pago_enfermero');
create type estatus_referido as enum ('registrado', 'validado', 'pagado');

-- ----------------------------------------------------------------------------
-- 2. SECUENCIAS PARA FOLIOS
-- ----------------------------------------------------------------------------
create sequence if not exists seq_folio_enfermero start 1;
create sequence if not exists seq_folio_solicitud start 1;

-- ----------------------------------------------------------------------------
-- 3. USUARIOS — espejo de auth.users con el rol
-- ----------------------------------------------------------------------------
create table public.usuarios (
  id             uuid primary key references auth.users(id) on delete cascade,
  rol            rol_usuario not null default 'cliente',
  nombre         text not null,
  apellidos      text,
  email          text unique not null,
  telefono       text,
  whatsapp       text,
  foto_url       text,
  activo         boolean not null default true,
  ultimo_acceso  timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index idx_usuarios_rol   on public.usuarios (rol);
create index idx_usuarios_email on public.usuarios (email);

-- ----------------------------------------------------------------------------
-- 4. ENFERMEROS — el corazon del catalogo
-- ----------------------------------------------------------------------------
create table public.enfermeros (
  id                    uuid primary key default gen_random_uuid(),
  -- nullable: la agencia puede dar de alta a un enfermero sin cuenta propia
  usuario_id            uuid unique references public.usuarios(id) on delete set null,
  folio                 text unique,
  nombre_completo       text not null,
  fecha_nacimiento      date,
  genero                text,
  nivel                 nivel_enfermeria not null,
  cedula_profesional    text,
  cedula_verificada     boolean not null default false,
  institucion_egreso    text,
  anios_experiencia     int not null default 0 check (anios_experiencia >= 0 and anios_experiencia <= 60),
  especialidades        text[] not null default '{}',
  certificaciones       text[] not null default '{}',
  idiomas               text[] not null default '{}',
  bio                   text check (char_length(bio) <= 600),
  foto_url              text,
  zonas_cobertura       text[] not null default '{}',
  disponible_inmediato  boolean not null default false,
  acepta_domicilio      boolean not null default true,
  acepta_nocturno       boolean not null default false,
  acepta_foraneo        boolean not null default false,
  -- Tarifas NETAS al enfermero. Nunca se exponen al publico.
  tarifa_hora           numeric(10,2) check (tarifa_hora     >= 0),
  tarifa_turno_8        numeric(10,2) check (tarifa_turno_8  >= 0),
  tarifa_turno_12       numeric(10,2) check (tarifa_turno_12 >= 0),
  tarifa_turno_24       numeric(10,2) check (tarifa_turno_24 >= 0),
  calificacion_promedio numeric(3,2) check (calificacion_promedio between 0 and 5),
  total_servicios       int not null default 0,
  estatus_verificacion  estatus_verif not null default 'pendiente',
  -- Solo admin. Nunca se expone al publico ni al propio enfermero.
  notas_internas        text,
  publicado             boolean not null default false,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- El catalogo publico filtra siempre por estos dos campos juntos (regla 10.1)
create index idx_enfermeros_publicos on public.enfermeros (publicado, estatus_verificacion);
create index idx_enfermeros_nivel    on public.enfermeros (nivel);
create index idx_enfermeros_usuario  on public.enfermeros (usuario_id);
-- GIN para los filtros por arreglo del catalogo
create index idx_enfermeros_especialidades on public.enfermeros using gin (especialidades);
create index idx_enfermeros_zonas          on public.enfermeros using gin (zonas_cobertura);

-- ----------------------------------------------------------------------------
-- 5. CLIENTES
-- ----------------------------------------------------------------------------
create table public.clientes (
  id                uuid primary key default gen_random_uuid(),
  -- unique: una cuenta no puede tener dos fichas de cliente. Sigue admitiendo
  -- varios nulos, porque la agencia da de alta clientes que no tienen cuenta.
  usuario_id        uuid unique references public.usuarios(id) on delete set null,
  tipo              tipo_cliente not null default 'particular',
  razon_social      text,
  nombre_contacto   text not null,
  telefono          text,
  email             text,
  rfc               text,
  requiere_factura  boolean not null default false,
  direccion         text,
  colonia           text,
  municipio         text,
  cp                text,
  notas             text,
  activo            boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index idx_clientes_usuario on public.clientes (usuario_id);
create index idx_clientes_tipo    on public.clientes (tipo);

-- ----------------------------------------------------------------------------
-- 6. SOLICITUDES
-- ----------------------------------------------------------------------------
create table public.solicitudes (
  id                      uuid primary key default gen_random_uuid(),
  folio                   text unique,
  -- nullable: una solicitud puede entrar como lead sin cuenta
  cliente_id              uuid references public.clientes(id) on delete set null,
  tipo_servicio           tipo_servicio not null,
  nivel_requerido         nivel_enfermeria,
  especialidad_requerida  text[] not null default '{}',
  descripcion_paciente    text,
  -- Entrada de la cotizacion. No hay tabulador fijo: la tarifa se define con
  -- estas variables (CLAUDE.md 15.5), por eso van estructuradas.
  entorno                 entorno_servicio,
  tipo_paciente           text,
  nivel_atencion          nivel_atencion,
  procedimientos          text[] not null default '{}',
  cantidad_enfermeros     int not null default 1 check (cantidad_enfermeros between 1 and 50),
  fecha_inicio            date not null,
  fecha_fin               date,
  turno                   turno_tipo,
  horas_por_turno         int check (horas_por_turno between 1 and 24),
  dias_semana             text[] not null default '{}',
  direccion_servicio      text,
  municipio               text,
  -- Tarifa cotizada por la agencia. La escribe el admin al responder la
  -- solicitud, nunca el cliente al enviarla (CLAUDE.md 15.5 y regla 10.6).
  tarifa_ofrecida_cliente numeric(10,2) check (tarifa_ofrecida_cliente >= 0),
  estatus                 estatus_solicitud not null default 'nueva',
  urgente                 boolean not null default false,
  origen                  text,
  codigo_referido         text,
  -- El cliente puede llegar habiendo elegido ya a uno o varios profesionales
  -- del catalogo (CLAUDE.md 15.3). La agencia confirma su disponibilidad y,
  -- si no pueden, propone equivalentes. Sin llave foranea porque es un arreglo:
  -- la integridad la cuida el frontend y la asignacion final vive en
  -- `asignaciones`, que si tiene la referencia.
  enfermeros_solicitados  uuid[] not null default '{}',
  -- Datos de contacto cuando entra sin cuenta
  contacto_nombre         text,
  contacto_telefono       text,
  contacto_email          text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),

  constraint fechas_coherentes check (fecha_fin is null or fecha_fin >= fecha_inicio)
);

create index idx_solicitudes_cliente on public.solicitudes (cliente_id);
create index idx_solicitudes_estatus on public.solicitudes (estatus, created_at desc);
create index idx_solicitudes_fecha   on public.solicitudes (fecha_inicio);
create index idx_solicitudes_pedidos on public.solicitudes using gin (enfermeros_solicitados);

-- ----------------------------------------------------------------------------
-- 7. ASIGNACIONES — la tabla que genera el dinero
-- ----------------------------------------------------------------------------
create table public.asignaciones (
  id                uuid primary key default gen_random_uuid(),
  solicitud_id      uuid not null references public.solicitudes(id) on delete cascade,
  enfermero_id      uuid not null references public.enfermeros(id) on delete restrict,
  fecha             date not null,
  turno             turno_tipo not null,
  hora_inicio       time not null,
  hora_fin          time not null,
  tarifa_cliente    numeric(10,2) not null check (tarifa_cliente   >= 0),
  tarifa_enfermero  numeric(10,2) not null check (tarifa_enfermero >= 0),
  -- La comision nunca puede ser negativa (regla 10.5)
  comision_agencia  numeric(10,2) generated always as (tarifa_cliente - tarifa_enfermero) stored,
  estatus           estatus_asignacion not null default 'propuesta',
  checkin_at        timestamptz,
  checkout_at       timestamptz,
  motivo_rechazo    text,
  notas             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint comision_no_negativa check (tarifa_cliente >= tarifa_enfermero)
);

create index idx_asignaciones_solicitud on public.asignaciones (solicitud_id);
create index idx_asignaciones_enfermero on public.asignaciones (enfermero_id, fecha);
create index idx_asignaciones_estatus   on public.asignaciones (estatus, fecha);

-- ----------------------------------------------------------------------------
-- 8. DISPONIBILIDAD
-- ----------------------------------------------------------------------------
create table public.disponibilidad (
  id           uuid primary key default gen_random_uuid(),
  enfermero_id uuid not null references public.enfermeros(id) on delete cascade,
  fecha        date not null,
  turno        turno_tipo not null,
  disponible   boolean not null default true,
  nota         text,
  created_at   timestamptz not null default now(),

  constraint disponibilidad_unica unique (enfermero_id, fecha, turno)
);

create index idx_disponibilidad_busqueda on public.disponibilidad (fecha, turno, disponible);

-- ----------------------------------------------------------------------------
-- 9. DOCUMENTOS — bucket privado, acceso solo por URL firmada
-- ----------------------------------------------------------------------------
create table public.documentos (
  id                 uuid primary key default gen_random_uuid(),
  enfermero_id       uuid not null references public.enfermeros(id) on delete cascade,
  tipo               tipo_documento not null,
  archivo_url        text not null,
  fecha_emision      date,
  fecha_vencimiento  date,
  estatus            estatus_verif not null default 'pendiente',
  verificado_por     uuid references public.usuarios(id) on delete set null,
  verificado_at      timestamptz,
  motivo_rechazo     text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index idx_documentos_enfermero on public.documentos (enfermero_id);
create index idx_documentos_estatus   on public.documentos (estatus);
-- Soporta la alerta de documentos por vencer del dashboard admin
create index idx_documentos_vencimiento on public.documentos (fecha_vencimiento)
  where fecha_vencimiento is not null;

-- ----------------------------------------------------------------------------
-- 10. EVALUACIONES
-- ----------------------------------------------------------------------------
create table public.evaluaciones (
  id                   uuid primary key default gen_random_uuid(),
  asignacion_id        uuid not null unique references public.asignaciones(id) on delete cascade,
  cliente_id           uuid references public.clientes(id) on delete set null,
  enfermero_id         uuid not null references public.enfermeros(id) on delete cascade,
  puntualidad          int not null check (puntualidad          between 1 and 5),
  trato                int not null check (trato                between 1 and 5),
  competencia_tecnica  int not null check (competencia_tecnica  between 1 and 5),
  calificacion_general int not null check (calificacion_general between 1 and 5),
  comentario           text,
  publica              boolean not null default true,
  created_at           timestamptz not null default now()
);

create index idx_evaluaciones_enfermero on public.evaluaciones (enfermero_id);
create index idx_evaluaciones_publicas  on public.evaluaciones (publica, created_at desc);

-- ----------------------------------------------------------------------------
-- 11. PAGOS
-- ----------------------------------------------------------------------------
create table public.pagos (
  id               uuid primary key default gen_random_uuid(),
  tipo             tipo_pago not null,
  -- Apunta a `solicitudes.id` cuando es cobro y a `enfermeros.id` cuando es pago.
  -- Sin llave foranea porque el destino depende de `tipo`.
  referencia_id    uuid not null,
  periodo_inicio   date,
  periodo_fin      date,
  monto            numeric(10,2) not null check (monto >= 0),
  metodo           text,
  estatus          estatus_pago not null default 'pendiente',
  comprobante_url  text,
  fecha_pago       date,
  notas            text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index idx_pagos_tipo       on public.pagos (tipo, estatus);
create index idx_pagos_referencia on public.pagos (referencia_id);

-- ----------------------------------------------------------------------------
-- 12. REFERIDOS
-- ----------------------------------------------------------------------------
create table public.codigos_referido (
  id          uuid primary key default gen_random_uuid(),
  usuario_id  uuid not null references public.usuarios(id) on delete cascade,
  codigo      text unique not null,
  tipo        text not null check (tipo in ('enfermero', 'cliente')),
  usos        int not null default 0,
  activo      boolean not null default true,
  created_at  timestamptz not null default now()
);

create index idx_codigos_usuario on public.codigos_referido (usuario_id);

create table public.referidos (
  id                uuid primary key default gen_random_uuid(),
  codigo            text not null,
  referidor_id      uuid references public.usuarios(id) on delete set null,
  referido_id       uuid references public.usuarios(id) on delete set null,
  tipo_referido     text check (tipo_referido in ('enfermero', 'cliente')),
  -- La recompensa se acredita al completar el primer servicio pagado,
  -- nunca al registrarse (CLAUDE.md 5.2, regla de negocio del programa)
  estatus           estatus_referido not null default 'registrado',
  recompensa_monto  numeric(10,2) default 0,
  fecha_validacion  timestamptz,
  created_at        timestamptz not null default now()
);

create index idx_referidos_codigo    on public.referidos (codigo);
create index idx_referidos_referidor on public.referidos (referidor_id);

-- ----------------------------------------------------------------------------
-- 13. BITACORA Y CAPTACION
-- ----------------------------------------------------------------------------
create table public.actividad (
  id              uuid primary key default gen_random_uuid(),
  usuario_id      uuid references public.usuarios(id) on delete set null,
  accion          text not null,
  tabla_afectada  text,
  registro_id     uuid,
  detalle         jsonb,
  ip              text,
  created_at      timestamptz not null default now()
);

create index idx_actividad_fecha   on public.actividad (created_at desc);
create index idx_actividad_usuario on public.actividad (usuario_id);

create table public.leads (
  id            uuid primary key default gen_random_uuid(),
  nombre        text not null,
  telefono      text,
  email         text,
  mensaje       text,
  tipo          text check (tipo in ('busco_personal', 'busco_empleo')),
  origen        text,
  utm_source    text,
  utm_campaign  text,
  atendido      boolean not null default false,
  created_at    timestamptz not null default now()
);

create index idx_leads_atendido on public.leads (atendido, created_at desc);

create table public.visitas (
  id            uuid primary key default gen_random_uuid(),
  pagina        text,
  referrer      text,
  utm_source    text,
  utm_medium    text,
  utm_campaign  text,
  user_agent    text,
  created_at    timestamptz not null default now()
);

create index idx_visitas_fecha on public.visitas (created_at desc);

-- ############################################################################
-- ###  02-rls.sql
-- ############################################################################

-- ============================================================================
-- Enlace Enfermero — 02. Row Level Security
-- RLS activo en todas las tablas sin excepcion (CLAUDE.md seccion 6).
-- Ejecutar despues de 01-schema.sql.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- FUNCION AUXILIAR
-- security definer para poder leer `usuarios` sin caer en recursion de RLS.
-- ----------------------------------------------------------------------------
create or replace function public.mi_rol()
returns rol_usuario
language sql
stable
security definer
set search_path = public
as $$
  select rol from public.usuarios where id = auth.uid();
$$;

-- true para admin y coordinador: ambos operan la agencia.
--
-- NO es security definer a proposito: necesita ver el rol real del llamante.
-- Si fuera definer, `current_user` seria siempre el propietario y la funcion
-- no podria distinguir a un cliente web de una operacion interna.
create or replace function public.es_staff()
returns boolean
language sql
stable
as $$
  select coalesce(public.mi_rol() in ('admin', 'coordinador'), false)
      -- Los unicos roles que llegan desde el navegador son `anon` y
      -- `authenticated`. Cualquier otro (service_role, el propietario de la
      -- base, o el de un trigger security definer) es interno y opera con
      -- plenos permisos. Sin esta linea, el trigger que recalcula la
      -- calificacion queda revertido por el trigger que protege los campos
      -- reservados al admin, y el promedio nunca se actualiza.
      or current_user not in ('anon', 'authenticated');
$$;

-- Version estricta de es_staff(), para usar DENTRO de funciones security definer.
--
-- es_staff() reconoce como internos a los roles que no son `anon` ni
-- `authenticated`, lo cual es correcto en las policies (ahi current_user es el
-- rol real del llamante) pero NO dentro de un security definer: ahi
-- current_user es el propietario de la funcion, asi que cualquier usuario con
-- sesion pasaria el filtro.
--
-- Esta solo mira quien es el usuario segun su token, que es lo unico que no
-- cambia al entrar en un security definer.
create or replace function public.es_staff_estricto()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.usuarios
    where id = auth.uid()
      and rol in ('admin', 'coordinador')
      and activo = true
  );
$$;

-- id del registro en `enfermeros` que pertenece al usuario en sesion
create or replace function public.mi_enfermero_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.enfermeros where usuario_id = auth.uid();
$$;

-- ----------------------------------------------------------------------------
-- Que documentos exige cada nivel (regla 10.2)
-- Todos entregan identidad y domicilio; la diferencia esta en la acreditacion
-- profesional: cedula y titulo para quienes ejercen con cedula, constancia de
-- estudios para el resto.
-- ----------------------------------------------------------------------------
create or replace function public.documentos_obligatorios(p_nivel nivel_enfermeria)
returns tipo_documento[]
language sql
immutable
as $$
  select case
    when p_nivel in ('general', 'licenciado', 'especialista')
      then array['ine', 'curp', 'comprobante_domicilio', 'cedula_profesional', 'titulo']::tipo_documento[]
    else
      array['ine', 'curp', 'comprobante_domicilio', 'titulo']::tipo_documento[]
  end;
$$;

comment on function public.documentos_obligatorios(nivel_enfermeria) is
  'Documentos sin los cuales un perfil no puede verificarse (CLAUDE.md 10.2). Para los niveles sin cedula, `titulo` se acepta como constancia de estudios.';

-- true si el perfil tiene algun documento OBLIGATORIO caducado.
--
-- La regla 10.3 dice que un documento vencido despublica el perfil, pero el
-- vencimiento no es un evento: pasa por el paso del tiempo, y ningun trigger
-- se entera. Si la regla dependiera de que alguien corra un proceso, un perfil
-- con la cedula caducada seguiria en el catalogo hasta que ese proceso corriera.
--
-- Por eso la condicion se evalua al momento de consultar, no se guarda. Solo
-- cuentan los obligatorios: un BLS caducado no despublica a nadie, nada mas le
-- cierra la puerta a los turnos que pidan esa certificacion.
create or replace function public.tiene_obligatorio_vencido(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.documentos d
    join public.enfermeros e on e.id = d.enfermero_id
    where d.enfermero_id = p_id
      and d.tipo = any(public.documentos_obligatorios(e.nivel))
      and d.fecha_vencimiento is not null
      and d.fecha_vencimiento < current_date
      and d.estatus <> 'rechazado'
  );
$$;

comment on function public.tiene_obligatorio_vencido(uuid) is
  'Regla 10.3 evaluada al vuelo: un obligatorio caducado saca el perfil del catalogo sin necesidad de que corra ningun proceso.';

-- true si el perfil aparece en el catalogo publico. Es security definer porque
-- se usa dentro de policies: sin eso, la subconsulta a `enfermeros` quedaria
-- filtrada por el propio RLS y siempre daria falso para un visitante.
create or replace function public.enfermero_es_publico(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.enfermeros
    where id = p_id
      and publicado = true
      and estatus_verificacion = 'verificado'
  )
  and not public.tiene_obligatorio_vencido(p_id);
$$;

-- id del registro en `clientes` que pertenece al usuario en sesion
create or replace function public.mi_cliente_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.clientes where usuario_id = auth.uid() limit 1;
$$;

-- ----------------------------------------------------------------------------
-- CRUCES ENTRE `solicitudes` Y `asignaciones` — POR QUE VAN EN UNA FUNCION
--
-- La policy de solicitudes necesitaba mirar asignaciones, y la de asignaciones
-- necesitaba mirar solicitudes. Cada subconsulta disparaba el RLS de la otra
-- tabla, que disparaba el de la primera: Postgres corta con
-- «infinite recursion detected in policy». El efecto era que NI el enfermero NI
-- el cliente podian leer ninguna de las dos tablas; solo el staff se salvaba
-- porque su policy evalua es_staff() y corta antes.
--
-- La salida es sacar el cruce a una funcion `security definer`: adentro corre
-- como propietario, el RLS de la otra tabla no se evalua, y el ciclo se rompe.
-- Ambas siguen filtrando por auth.uid(), asi que no aflojan nada.
-- ----------------------------------------------------------------------------

-- true si el enfermero en sesion tiene una asignacion YA COMPROMETIDA en esa
-- solicitud. Una propuesta no cuenta a proposito: mientras la esta pensando no
-- tiene por que conocer el domicilio del paciente (regla 10.8). El panel le
-- muestra los datos del turno por sus propias funciones, que devuelven solo
-- las columnas seguras.
create or replace function public.tengo_asignacion_en(p_solicitud uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.asignaciones a
    where a.solicitud_id = p_solicitud
      and a.enfermero_id = public.mi_enfermero_id()
      and a.estatus in ('aceptada', 'en_curso', 'completada')
  );
$$;

-- true si la solicitud pertenece al cliente en sesion
create or replace function public.solicitud_es_de_mi_cliente(p_solicitud uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.solicitudes s
    where s.id = p_solicitud
      and s.cliente_id = public.mi_cliente_id()
  );
$$;


-- ----------------------------------------------------------------------------
-- ACTIVAR RLS EN TODAS LAS TABLAS
-- ----------------------------------------------------------------------------
alter table public.usuarios          enable row level security;
alter table public.enfermeros        enable row level security;
alter table public.clientes          enable row level security;
alter table public.solicitudes       enable row level security;
alter table public.asignaciones      enable row level security;
alter table public.disponibilidad    enable row level security;
alter table public.documentos        enable row level security;
alter table public.evaluaciones      enable row level security;
alter table public.pagos             enable row level security;
alter table public.codigos_referido  enable row level security;
alter table public.referidos         enable row level security;
alter table public.actividad         enable row level security;
alter table public.leads             enable row level security;
alter table public.visitas           enable row level security;

-- ----------------------------------------------------------------------------
-- PERMISOS DE TABLA (GRANT)
--
-- RLS y GRANT son dos capas distintas y hacen falta las dos: el GRANT decide
-- si el rol puede tocar la tabla, y la policy decide que filas ve o escribe.
-- Sin GRANT, PostgREST responde "permission denied" antes de siquiera evaluar
-- las policies.
--
-- Se otorga lo minimo. Nadie borra desde el frontend: no hay DELETE.
-- ----------------------------------------------------------------------------

-- El visitante sin sesion solo necesita leer lo publicable y dejar su rastro.
-- Las altas de solicitud y de enfermero NO se hacen con insert directo sino
-- con las funciones de 03-funciones.sql, que devuelven el folio.
grant select on public.evaluaciones   to anon, authenticated;
grant select on public.disponibilidad to anon, authenticated;
grant insert on public.leads          to anon, authenticated;
grant insert on public.visitas        to anon, authenticated;

-- Con sesion iniciada, cada rol trabaja sobre sus propias filas; el filtro
-- fino lo hacen las policies de abajo.
grant select, insert, update on all tables in schema public to authenticated;
grant usage on all sequences in schema public to authenticated;

-- ----------------------------------------------------------------------------
-- PERMISOS POR COLUMNA — LA TERCERA CAPA
--
-- RLS filtra FILAS y GRANT abre la TABLA, pero varias reglas del negocio son de
-- COLUMNA, y ninguna de las dos capas anteriores puede expresarlas.
--
-- Sin esto, la policy que le deja a un enfermero ver sus asignaciones le dejaba
-- ver TODA la fila, incluida `comision_agencia`: sabia exactamente cuanto se
-- queda la agencia en cada turno. Y al cliente le pasaba lo mismo al reves:
-- veia `tarifa_enfermero` y podia calcular el margen. Los dos son el argumento
-- perfecto para saltarse a la agencia, que es justo lo que el modelo no puede
-- permitir (CLAUDE.md 6 y 15.2).
--
-- OJO CON EL ORDEN: un `revoke select (columna)` NO hace nada si el rol
-- conserva el `select` de la tabla completa; Postgres entiende que el permiso
-- de tabla ya cubre todas las columnas. Hay que quitar primero el de tabla y
-- despues otorgar la lista de columnas permitidas.
--
-- Las pantallas no se ven afectadas: leen por funciones `security definer`,
-- que corren como propietario y no pasan por esta capa. Lo que se cierra es la
-- puerta de atras, la de abrir la consola del navegador y consultar la tabla.
-- ----------------------------------------------------------------------------

-- `asignaciones` y `solicitudes` dejan de ser legibles directamente. Todo lo
-- que los tres paneles necesitan de ellas sale de funciones que devuelven solo
-- columnas seguras (06 a 11). Ningun archivo de js/ las consulta directo.
revoke select on public.asignaciones from authenticated;
revoke select on public.solicitudes  from authenticated;

-- En `enfermeros` y `clientes` si hay lectura directa desde el panel, asi que
-- se otorga columna por columna: todas menos las notas que escribe la agencia.
-- La lista se arma sola para que una columna nueva nazca cerrada en vez de
-- abierta por descuido.
do $$
declare
  cols text;
  v_tabla text;
  v_oculta text;
begin
  foreach v_tabla in array array['enfermeros', 'clientes'] loop
    v_oculta := case v_tabla when 'enfermeros' then 'notas_internas' else 'notas' end;

    execute format('revoke select on public.%I from authenticated', v_tabla);

    select string_agg(quote_ident(column_name), ', ' order by ordinal_position)
      into cols
    from information_schema.columns
    where table_schema = 'public'
      and table_name   = v_tabla
      and column_name <> v_oculta;

    execute format('grant select (%s) on public.%I to authenticated', cols, v_tabla);
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- USUARIOS
-- ----------------------------------------------------------------------------
create policy usuarios_lee_su_fila on public.usuarios
  for select to authenticated using (id = auth.uid());

create policy usuarios_edita_su_fila on public.usuarios
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- El alta la hace el trigger al confirmarse el registro en auth.users,
-- pero se permite tambien el insert propio para el flujo de registro directo.
create policy usuarios_crea_su_fila on public.usuarios
  for insert to authenticated with check (id = auth.uid());

create policy usuarios_staff on public.usuarios
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- ENFERMEROS
-- El publico NO consulta esta tabla: usa la vista `enfermeros_publico`
-- definida en 04-vistas.sql. Por eso aqui no hay ninguna policy para `anon`.
-- Un trigger en 03-funciones.sql impide que el enfermero modifique los campos
-- reservados al admin: estatus_verificacion, publicado, tarifas, notas_internas.
-- ----------------------------------------------------------------------------
-- Alta publica desde unete.html. El candidato aun no tiene cuenta, por eso el
-- esquema deja `usuario_id` nullable. El WITH CHECK obliga a que la fila entre
-- siempre sin verificar, sin publicar, sin tarifas y sin notas internas: lo
-- unico que puede hacer un anonimo es proponerse como candidato.
create policy enfermeros_alta_publica on public.enfermeros
  for insert to anon, authenticated with check (
    usuario_id is null
    and publicado = false
    and estatus_verificacion = 'pendiente'
    and cedula_verificada = false
    and notas_internas is null
    and tarifa_hora is null
    and tarifa_turno_8 is null
    and tarifa_turno_12 is null
    and tarifa_turno_24 is null
    and calificacion_promedio is null
    and total_servicios = 0
  );

create policy enfermeros_lee_su_fila on public.enfermeros
  for select to authenticated using (usuario_id = auth.uid());

create policy enfermeros_edita_su_fila on public.enfermeros
  for update to authenticated
  using (usuario_id = auth.uid()) with check (usuario_id = auth.uid());

create policy enfermeros_staff on public.enfermeros
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- CLIENTES
-- ----------------------------------------------------------------------------
create policy clientes_su_fila on public.clientes
  for select to authenticated using (usuario_id = auth.uid());

create policy clientes_edita_su_fila on public.clientes
  for update to authenticated
  using (usuario_id = auth.uid()) with check (usuario_id = auth.uid());

create policy clientes_crea_su_fila on public.clientes
  for insert to authenticated with check (usuario_id = auth.uid());

create policy clientes_staff on public.clientes
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- SOLICITUDES
-- El formulario publico puede insertar sin sesion (lead), pero jamas leer.
-- ----------------------------------------------------------------------------
-- Alta publica desde solicitar.html. El cliente describe su necesidad; la
-- tarifa la cotiza la agencia despues (CLAUDE.md 15.5), asi que la solicitud
-- debe entrar sin precio y sin estatus adelantado.
create policy solicitudes_alta_publica on public.solicitudes
  for insert to anon, authenticated with check (
    tarifa_ofrecida_cliente is null
    and estatus = 'nueva'
  );

create policy solicitudes_cliente_lee on public.solicitudes
  for select to authenticated using (cliente_id = public.mi_cliente_id());

-- El enfermero solo ve las solicitudes de los turnos que ya acepto.
-- El cruce va por funcion para no recursar contra la policy de asignaciones.
create policy solicitudes_enfermero_lee on public.solicitudes
  for select to authenticated using (public.tengo_asignacion_en(solicitudes.id));

create policy solicitudes_staff on public.solicitudes
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- ASIGNACIONES
-- El enfermero puede cambiar el estatus a aceptada o rechazada; el resto de
-- transiciones y los montos quedan protegidos por trigger (03-funciones.sql).
-- ----------------------------------------------------------------------------
create policy asignaciones_enfermero_lee on public.asignaciones
  for select to authenticated using (enfermero_id = public.mi_enfermero_id());

create policy asignaciones_enfermero_responde on public.asignaciones
  for update to authenticated
  using (enfermero_id = public.mi_enfermero_id())
  with check (enfermero_id = public.mi_enfermero_id());

-- Igual que arriba: el cruce sale a una funcion para romper el ciclo
create policy asignaciones_cliente_lee on public.asignaciones
  for select to authenticated using (
    public.solicitud_es_de_mi_cliente(asignaciones.solicitud_id)
  );

create policy asignaciones_staff on public.asignaciones
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- DISPONIBILIDAD — CRUD propio del enfermero
-- ----------------------------------------------------------------------------
-- El perfil publico muestra "disponibilidad esta semana" (CLAUDE.md 8.3), asi
-- que el visitante necesita leer los turnos libres de quien esta publicado.
-- Solo eso: los turnos ocupados y las notas no se exponen.
create policy disponibilidad_publica on public.disponibilidad
  for select to anon, authenticated using (
    disponible = true
    and public.enfermero_es_publico(enfermero_id)
  );

create policy disponibilidad_propia on public.disponibilidad
  for all to authenticated
  using (enfermero_id = public.mi_enfermero_id())
  with check (enfermero_id = public.mi_enfermero_id());

create policy disponibilidad_staff on public.disponibilidad
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- DOCUMENTOS — el enfermero sube y consulta los suyos, nunca los aprueba
-- ----------------------------------------------------------------------------
create policy documentos_enfermero_lee on public.documentos
  for select to authenticated using (enfermero_id = public.mi_enfermero_id());

create policy documentos_enfermero_sube on public.documentos
  for insert to authenticated with check (enfermero_id = public.mi_enfermero_id());

create policy documentos_enfermero_reemplaza on public.documentos
  for update to authenticated
  using (enfermero_id = public.mi_enfermero_id())
  with check (enfermero_id = public.mi_enfermero_id());

create policy documentos_staff on public.documentos
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- EVALUACIONES
-- ----------------------------------------------------------------------------
create policy evaluaciones_publicas on public.evaluaciones
  for select to anon, authenticated using (publica = true);

create policy evaluaciones_enfermero_lee on public.evaluaciones
  for select to authenticated using (enfermero_id = public.mi_enfermero_id());

-- Solo sobre asignaciones completadas del propio cliente y dentro de 15 dias
create policy evaluaciones_cliente_crea on public.evaluaciones
  for insert to authenticated with check (
    cliente_id = public.mi_cliente_id()
    and exists (
      select 1
      from public.asignaciones a
      join public.solicitudes s on s.id = a.solicitud_id
      where a.id = evaluaciones.asignacion_id
        and a.estatus = 'completada'
        and s.cliente_id = public.mi_cliente_id()
        and a.fecha >= current_date - interval '15 days'
    )
  );

create policy evaluaciones_staff on public.evaluaciones
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- PAGOS — cada parte ve solo lo suyo
-- ----------------------------------------------------------------------------
create policy pagos_enfermero_lee on public.pagos
  for select to authenticated using (
    tipo = 'pago_enfermero' and referencia_id = public.mi_enfermero_id()
  );

create policy pagos_cliente_lee on public.pagos
  for select to authenticated using (
    tipo = 'cobro_cliente' and exists (
      select 1 from public.solicitudes s
      where s.id = pagos.referencia_id
        and s.cliente_id = public.mi_cliente_id()
    )
  );

create policy pagos_staff on public.pagos
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- REFERIDOS
-- ----------------------------------------------------------------------------
create policy codigos_propio on public.codigos_referido
  for select to authenticated using (usuario_id = auth.uid());

create policy codigos_staff on public.codigos_referido
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

create policy referidos_propio on public.referidos
  for select to authenticated using (referidor_id = auth.uid() or referido_id = auth.uid());

create policy referidos_staff on public.referidos
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- BITACORA Y CAPTACION
-- ----------------------------------------------------------------------------
-- La bitacora la escribe el trigger (security definer), nadie la edita a mano
create policy actividad_staff_lee on public.actividad
  for select to authenticated using (public.es_staff());

create policy leads_alta_publica on public.leads
  for insert to anon, authenticated with check (true);

create policy leads_staff on public.leads
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

create policy visitas_alta_publica on public.visitas
  for insert to anon, authenticated with check (true);

create policy visitas_staff_lee on public.visitas
  for select to authenticated using (public.es_staff());

-- ----------------------------------------------------------------------------
-- STORAGE (CLAUDE.md 6, "Storage")
-- Los buckets se crean aqui y no a mano en el panel, para que la instalacion
-- quede completa de una sola pasada y sea igual en local y en produccion.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  -- Fotos de perfil: lectura publica, 5 MB, solo imagenes
  ('fotos', 'fotos', true, 5242880,
   array['image/jpeg', 'image/png', 'image/webp']),

  -- Documentos de identidad y profesionales: PRIVADO, 10 MB
  ('documentos', 'documentos', false, 10485760,
   array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),

  -- Comprobantes de pago: PRIVADO, solo staff
  ('comprobantes', 'comprobantes', false, 10485760,
   array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do nothing;

-- fotos: lectura abierta, escritura solo autenticado
create policy fotos_lectura_publica on storage.objects
  for select to anon, authenticated using (bucket_id = 'fotos');

create policy fotos_escritura on storage.objects
  for insert to authenticated with check (bucket_id = 'fotos');

create policy fotos_actualiza on storage.objects
  for update to authenticated using (bucket_id = 'fotos');

-- documentos: el enfermero solo toca la carpeta con su propio uuid.
-- Convencion de ruta: documentos/<enfermero_id>/<tipo>-<timestamp>.<ext>
create policy documentos_sube_propio on storage.objects
  for insert to authenticated with check (
    bucket_id = 'documentos'
    and (storage.foldername(name))[1] = public.mi_enfermero_id()::text
  );

create policy documentos_lee_propio on storage.objects
  for select to authenticated using (
    bucket_id = 'documentos'
    and (storage.foldername(name))[1] = public.mi_enfermero_id()::text
  );

create policy documentos_staff on storage.objects
  for all to authenticated using (bucket_id = 'documentos' and public.es_staff())
  with check (bucket_id = 'documentos' and public.es_staff());

-- comprobantes: exclusivo del staff
create policy comprobantes_staff on storage.objects
  for all to authenticated using (bucket_id = 'comprobantes' and public.es_staff())
  with check (bucket_id = 'comprobantes' and public.es_staff());

-- ############################################################################
-- ###  03-funciones.sql
-- ############################################################################

-- ============================================================================
-- Enlace Enfermero — 03. Funciones y triggers
-- Definidas en CLAUDE.md seccion 7. Ejecutar despues de 02-rls.sql.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 9. set_updated_at() — trigger universal
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger tg_usuarios_updated     before update on public.usuarios     for each row execute function public.set_updated_at();
create trigger tg_enfermeros_updated   before update on public.enfermeros   for each row execute function public.set_updated_at();
create trigger tg_clientes_updated     before update on public.clientes     for each row execute function public.set_updated_at();
create trigger tg_solicitudes_updated  before update on public.solicitudes  for each row execute function public.set_updated_at();
create trigger tg_asignaciones_updated before update on public.asignaciones for each row execute function public.set_updated_at();
create trigger tg_documentos_updated   before update on public.documentos   for each row execute function public.set_updated_at();
create trigger tg_pagos_updated        before update on public.pagos        for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 1 y 2. Folios secuenciales: EE-00001 y SOL-00001
-- ----------------------------------------------------------------------------
-- security definer: el folio lo asigna el sistema. Sin esto, un alta anonima
-- (formulario publico de solicitud o de registro) falla al no tener permiso
-- sobre la secuencia.
create or replace function public.generar_folio_enfermero()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.folio is null then
    new.folio := 'EE-' || lpad(nextval('seq_folio_enfermero')::text, 5, '0');
  end if;
  return new;
end;
$$;

create trigger tg_folio_enfermero
  before insert on public.enfermeros
  for each row execute function public.generar_folio_enfermero();

-- security definer: el folio lo asigna el sistema. Sin esto, un alta anonima
-- (formulario publico de solicitud o de registro) falla al no tener permiso
-- sobre la secuencia.
create or replace function public.generar_folio_solicitud()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.folio is null then
    new.folio := 'SOL-' || lpad(nextval('seq_folio_solicitud')::text, 5, '0');
  end if;
  return new;
end;
$$;

create trigger tg_folio_solicitud
  before insert on public.solicitudes
  for each row execute function public.generar_folio_solicitud();

-- ----------------------------------------------------------------------------
-- 3. generar_codigo_referido() — REF- + 6 caracteres alfanumericos unicos
-- ----------------------------------------------------------------------------
create or replace function public.generar_codigo_referido()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  nuevo_codigo text;
  intentos int := 0;
begin
  -- Solo enfermeros y clientes participan en el programa de referidos
  if new.rol not in ('enfermero', 'cliente') then
    return new;
  end if;

  loop
    nuevo_codigo := 'REF-' || upper(substr(md5(gen_random_uuid()::text), 1, 6));
    exit when not exists (select 1 from public.codigos_referido where codigo = nuevo_codigo);
    intentos := intentos + 1;
    if intentos > 10 then
      raise exception 'No se pudo generar un codigo de referido unico';
    end if;
  end loop;

  insert into public.codigos_referido (usuario_id, codigo, tipo)
  values (new.id, nuevo_codigo, new.rol::text);

  return new;
end;
$$;

create trigger tg_codigo_referido
  after insert on public.usuarios
  for each row execute function public.generar_codigo_referido();

-- ----------------------------------------------------------------------------
-- 4. actualizar_calificacion_enfermero()
-- Recalcula promedio y total de servicios evaluados.
-- ----------------------------------------------------------------------------
create or replace function public.actualizar_calificacion_enfermero()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  objetivo uuid := coalesce(new.enfermero_id, old.enfermero_id);
begin
  update public.enfermeros e
  set calificacion_promedio = sub.promedio,
      total_servicios       = sub.total
  from (
    select round(avg(calificacion_general)::numeric, 2) as promedio,
           count(*) as total
    from public.evaluaciones
    where enfermero_id = objetivo
  ) sub
  where e.id = objetivo;

  return coalesce(new, old);
end;
$$;

create trigger tg_calificacion_enfermero
  after insert or update or delete on public.evaluaciones
  for each row execute function public.actualizar_calificacion_enfermero();

-- ----------------------------------------------------------------------------
-- 5. Comision de la agencia
-- Se resuelve como columna generada en `asignaciones` (01-schema.sql):
--   comision_agencia = tarifa_cliente - tarifa_enfermero
-- y la restriccion `comision_no_negativa` garantiza la regla 10.5.
--
-- El reparto por defecto es 60% enfermero / 40% agencia (CLAUDE.md 15.2).
-- Estas dos funciones lo calculan para que el panel admin no lo haga a mano;
-- el admin puede capturar otro monto cuando una negociacion lo amerite.
-- ----------------------------------------------------------------------------
create or replace function public.pago_enfermero(p_tarifa_cliente numeric)
returns numeric language sql immutable as $$
  select round(coalesce(p_tarifa_cliente, 0) * 0.60, 2);
$$;

comment on function public.pago_enfermero(numeric) is
  'Parte que le toca al enfermero (60%) de lo que paga el cliente.';

create or replace function public.cobro_cliente(p_pago_enfermero numeric)
returns numeric language sql immutable as $$
  select round(coalesce(p_pago_enfermero, 0) / 0.60, 2);
$$;

comment on function public.cobro_cliente(numeric) is
  'Camino inverso: cuanto facturar al cliente para que al enfermero le toque lo indicado.';

-- Si el admin captura la tarifa del cliente y deja en cero la del enfermero,
-- se aplica el reparto por defecto en vez de guardar un pago de cero.
create or replace function public.aplicar_reparto_default()
returns trigger language plpgsql as $$
begin
  if new.tarifa_enfermero is null or new.tarifa_enfermero = 0 then
    new.tarifa_enfermero := public.pago_enfermero(new.tarifa_cliente);
  end if;
  return new;
end;
$$;

create trigger tg_reparto_default
  before insert on public.asignaciones
  for each row execute function public.aplicar_reparto_default();


-- ----------------------------------------------------------------------------
-- 6. validar_traslape() — CRITICO (regla 10.4)
-- Un enfermero no puede tener dos turnos encimados. Contempla los turnos que
-- cruzan la medianoche (nocturno 23:00-07:00) sumando un dia al cierre.
-- Solo bloquean las asignaciones ya comprometidas; varias `propuesta` sobre el
-- mismo horario son validas porque el enfermero aun no acepta ninguna.
-- ----------------------------------------------------------------------------
create or replace function public.rango_asignacion(p_fecha date, p_inicio time, p_fin time)
returns tsrange language sql immutable as $$
  select tsrange(
    (p_fecha + p_inicio)::timestamp,
    case when p_fin > p_inicio
         then (p_fecha + p_fin)::timestamp
         else (p_fecha + 1 + p_fin)::timestamp   -- el turno cruza la medianoche
    end,
    '[)'
  );
$$;

create or replace function public.validar_traslape()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  encimada record;
begin
  -- Una asignacion rechazada o cancelada libera el horario
  if new.estatus in ('rechazada', 'cancelada', 'no_asistio') then
    return new;
  end if;

  select a.id, a.fecha, a.hora_inicio, a.hora_fin into encimada
  from public.asignaciones a
  where a.enfermero_id = new.enfermero_id
    and a.id is distinct from new.id
    and a.estatus in ('propuesta', 'aceptada', 'en_curso', 'completada')
    -- se compara contra el dia anterior y el siguiente por los turnos nocturnos
    and a.fecha between new.fecha - 1 and new.fecha + 1
    and public.rango_asignacion(a.fecha, a.hora_inicio, a.hora_fin)
        && public.rango_asignacion(new.fecha, new.hora_inicio, new.hora_fin)
    -- una propuesta no bloquea a otra propuesta: bloquea lo ya comprometido
    and (new.estatus <> 'propuesta' or a.estatus <> 'propuesta')
  limit 1;

  if found then
    raise exception 'El enfermero ya tiene un turno asignado que se encima: % de % a %',
      to_char(encimada.fecha, 'DD/MM/YYYY'),
      to_char(encimada.hora_inicio, 'HH24:MI'),
      to_char(encimada.hora_fin, 'HH24:MI')
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

create trigger tg_validar_traslape
  before insert or update of fecha, hora_inicio, hora_fin, estatus, enfermero_id
  on public.asignaciones
  for each row execute function public.validar_traslape();

-- ----------------------------------------------------------------------------
-- 7. registrar_actividad() — bitacora generica
-- ----------------------------------------------------------------------------
create or replace function public.registrar_actividad()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  detalle_json jsonb;
begin
  if TG_OP = 'INSERT' then
    detalle_json := jsonb_build_object('nuevo', to_jsonb(new));
  elsif TG_OP = 'UPDATE' then
    detalle_json := jsonb_build_object('antes', to_jsonb(old), 'despues', to_jsonb(new));
  else
    detalle_json := jsonb_build_object('eliminado', to_jsonb(old));
  end if;

  -- Nunca se guardan las notas internas en la bitacora
  detalle_json := detalle_json #- '{nuevo,notas_internas}'
                               #- '{antes,notas_internas}'
                               #- '{despues,notas_internas}';

  insert into public.actividad (usuario_id, accion, tabla_afectada, registro_id, detalle)
  values (
    auth.uid(),
    lower(TG_OP),
    TG_TABLE_NAME,
    coalesce((to_jsonb(new) ->> 'id')::uuid, (to_jsonb(old) ->> 'id')::uuid),
    detalle_json
  );

  return coalesce(new, old);
end;
$$;

create trigger tg_actividad_enfermeros
  after insert or update or delete on public.enfermeros
  for each row execute function public.registrar_actividad();

create trigger tg_actividad_solicitudes
  after insert or update or delete on public.solicitudes
  for each row execute function public.registrar_actividad();

create trigger tg_actividad_asignaciones
  after insert or update or delete on public.asignaciones
  for each row execute function public.registrar_actividad();

create trigger tg_actividad_documentos
  after insert or update or delete on public.documentos
  for each row execute function public.registrar_actividad();

create trigger tg_actividad_pagos
  after insert or update or delete on public.pagos
  for each row execute function public.registrar_actividad();

-- ----------------------------------------------------------------------------
-- 8. alertar_documentos_por_vencer()
-- Se consume desde el dashboard admin y desde Make.com en la Fase 4.
-- ----------------------------------------------------------------------------
create or replace function public.alertar_documentos_por_vencer(p_dias int default 30)
returns table (
  documento_id      uuid,
  enfermero_id      uuid,
  folio             text,
  nombre_completo   text,
  tipo              tipo_documento,
  fecha_vencimiento date,
  dias_restantes    int
)
language sql
stable
security definer
set search_path = public
as $$
  select d.id, e.id, e.folio, e.nombre_completo, d.tipo, d.fecha_vencimiento,
         (d.fecha_vencimiento - current_date)::int
  from public.documentos d
  join public.enfermeros e on e.id = d.enfermero_id
  where d.fecha_vencimiento is not null
    and d.estatus <> 'rechazado'
    and d.fecha_vencimiento <= current_date + p_dias
  order by d.fecha_vencimiento;
$$;

-- ----------------------------------------------------------------------------
-- Regla 10.3: pone al corriente lo que ya caduco.
--
-- El catalogo publico NO depende de esta funcion: la vista `enfermeros_publico`
-- evalua el vencimiento al momento de consultar (ver tiene_obligatorio_vencido
-- en 02-rls.sql). Si dependiera de un proceso, entre que un documento caduca y
-- que ese proceso corre habria una ventana en la que se sigue ofreciendo como
-- verificado a alguien que ya no lo esta.
--
-- Lo que esta funcion hace es que el ESTADO GUARDADO diga la verdad, que es lo
-- que ve la agencia en su panel: sin ella, el admin leeria "publicado: si"
-- sobre un perfil que el catalogo ya dejo de mostrar.
--
-- Solo los documentos OBLIGATORIOS despublican. La version anterior bajaba el
-- perfil por cualquier documento vencido, asi que un BLS caducado sacaba del
-- catalogo a alguien cuyo expediente obligatorio estaba completo.
--
-- Se invoca desde el dashboard de la agencia al abrirse, y en la Fase 4
-- conviene ademas dispararla a diario desde Make.com.
-- ----------------------------------------------------------------------------
drop function if exists public.marcar_documentos_vencidos();

create or replace function public.marcar_documentos_vencidos()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_docs  int := 0;
  v_bajas int := 0;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede correr esta revisión'
      using errcode = '42501';
  end if;

  -- Un documento caducado deja de contar como vigente. Los rechazados se
  -- quedan como estan: ya tienen un motivo y su propio flujo de correccion.
  with tocados as (
    update public.documentos
    set estatus = 'vencido'
    where fecha_vencimiento is not null
      and fecha_vencimiento < current_date
      and estatus not in ('vencido', 'rechazado')
    returning 1
  )
  select count(*) into v_docs from tocados;

  -- Y si lo caducado era obligatorio, el perfil sale del catalogo
  with bajados as (
    update public.enfermeros e
    set publicado = false
    where e.publicado = true
      and public.tiene_obligatorio_vencido(e.id)
    returning 1
  )
  select count(*) into v_bajas from bajados;

  return jsonb_build_object(
    'documentos_marcados',     v_docs,
    'perfiles_despublicados',  v_bajas
  );
end;
$$;

revoke all    on function public.marcar_documentos_vencidos() from public;
grant execute on function public.marcar_documentos_vencidos() to authenticated;

-- ----------------------------------------------------------------------------
-- PROTECCION DE CAMPOS RESERVADOS AL ADMIN (regla 10.6)
-- RLS controla filas, no columnas. Estos triggers revierten cualquier cambio
-- que el propio enfermero intente sobre campos que no le corresponden.
-- ----------------------------------------------------------------------------
-- Sin security definer: necesita ver el rol real del llamante para que
-- es_staff() reconozca al admin y al service_role.
create or replace function public.proteger_campos_enfermero()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if public.es_staff() then
    return new;
  end if;

  new.estatus_verificacion := old.estatus_verificacion;
  new.publicado            := old.publicado;
  new.cedula_verificada    := old.cedula_verificada;
  new.notas_internas       := old.notas_internas;
  new.folio                := old.folio;
  new.tarifa_hora          := old.tarifa_hora;
  new.tarifa_turno_8       := old.tarifa_turno_8;
  new.tarifa_turno_12      := old.tarifa_turno_12;
  new.tarifa_turno_24      := old.tarifa_turno_24;
  new.calificacion_promedio := old.calificacion_promedio;
  new.total_servicios      := old.total_servicios;
  new.usuario_id           := old.usuario_id;

  return new;
end;
$$;

create trigger tg_proteger_enfermero
  before update on public.enfermeros
  for each row execute function public.proteger_campos_enfermero();

-- El enfermero nunca aprueba sus propios documentos
-- Sin security definer: necesita ver el rol real del llamante para que
-- es_staff() reconozca al admin y al service_role.
create or replace function public.proteger_campos_documento()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if public.es_staff() then
    return new;
  end if;

  new.estatus        := old.estatus;
  new.verificado_por := old.verificado_por;
  new.verificado_at  := old.verificado_at;
  new.motivo_rechazo := old.motivo_rechazo;

  return new;
end;
$$;

create trigger tg_proteger_documento
  before update on public.documentos
  for each row execute function public.proteger_campos_documento();

-- El enfermero solo responde a la propuesta y registra su asistencia;
-- los montos y el resto de transiciones son del admin.
-- Sin security definer: necesita ver el rol real del llamante para que
-- es_staff() reconozca al admin y al service_role.
create or replace function public.proteger_campos_asignacion()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if public.es_staff() then
    return new;
  end if;

  new.tarifa_cliente   := old.tarifa_cliente;
  new.tarifa_enfermero := old.tarifa_enfermero;
  new.solicitud_id     := old.solicitud_id;
  new.enfermero_id     := old.enfermero_id;
  new.fecha            := old.fecha;
  new.hora_inicio      := old.hora_inicio;
  new.hora_fin         := old.hora_fin;

  -- Transiciones permitidas al enfermero
  if new.estatus <> old.estatus then
    if not (
      (old.estatus = 'propuesta' and new.estatus in ('aceptada', 'rechazada')) or
      (old.estatus = 'aceptada'  and new.estatus = 'en_curso') or
      (old.estatus = 'en_curso'  and new.estatus = 'completada')
    ) then
      raise exception 'No tienes permiso para cambiar el estatus de % a %',
        old.estatus, new.estatus using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

create trigger tg_proteger_asignacion
  before update on public.asignaciones
  for each row execute function public.proteger_campos_asignacion();

-- ----------------------------------------------------------------------------
-- ALTA AUTOMATICA EN `usuarios` AL REGISTRARSE EN auth.users
-- El rol viene en los metadatos del registro; por defecto es 'cliente'.
-- ----------------------------------------------------------------------------
create or replace function public.crear_usuario_desde_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.usuarios (id, email, nombre, apellidos, telefono, rol)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'nombre', split_part(new.email, '@', 1)),
    new.raw_user_meta_data ->> 'apellidos',
    new.raw_user_meta_data ->> 'telefono',
    coalesce((new.raw_user_meta_data ->> 'rol')::rol_usuario, 'cliente')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger tg_crear_usuario
  after insert on auth.users
  for each row execute function public.crear_usuario_desde_auth();

-- ----------------------------------------------------------------------------
-- FICHA DE CLIENTE AL REGISTRARSE
-- El trigger anterior crea la fila en `usuarios`; esta crea la ficha en
-- `clientes`, que es la que se liga a las solicitudes. Sin ella, un cliente
-- recien registrado no podria ver sus propios servicios.
-- ----------------------------------------------------------------------------
create or replace function public.crear_ficha_cliente()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.rol <> 'cliente' then
    return new;
  end if;

  insert into public.clientes (usuario_id, tipo, nombre_contacto, email, telefono)
  values (
    new.id,
    'particular',
    trim(new.nombre || ' ' || coalesce(new.apellidos, '')),
    new.email,
    new.telefono
  )
  on conflict do nothing;

  return new;
end;
$$;

create trigger tg_ficha_cliente
  after insert on public.usuarios
  for each row execute function public.crear_ficha_cliente();

-- ----------------------------------------------------------------------------
-- ALTAS PUBLICAS
--
-- El formulario publico necesita recibir de vuelta el folio, pero para eso
-- tendria que poder LEER la tabla donde acaba de escribir, y eso abriria
-- solicitudes y enfermeros a cualquiera. Estas funciones resuelven el problema:
-- corren como propietario, insertan solo los campos permitidos y devuelven
-- unicamente el folio.
--
-- Ademas del RLS, aqui se ignoran a proposito los campos reservados al admin
-- (tarifa, estatus, publicado, verificacion): aunque alguien los mande en el
-- json, no llegan a la tabla.
-- ----------------------------------------------------------------------------
create or replace function public.crear_solicitud(p_datos jsonb)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  nuevo_folio text;
begin
  insert into public.solicitudes (
    cliente_id,
    tipo_servicio, nivel_requerido, especialidad_requerida, descripcion_paciente,
    entorno, tipo_paciente, nivel_atencion, procedimientos, cantidad_enfermeros,
    fecha_inicio, fecha_fin, turno, horas_por_turno, dias_semana,
    direccion_servicio, municipio, urgente, origen, codigo_referido,
    enfermeros_solicitados, contacto_nombre, contacto_telefono, contacto_email
  )
  values (
    -- Si quien envia el formulario trae sesion de cliente, la solicitud se
    -- cuelga de su ficha. Sin esto, una solicitud hecha desde el panel del
    -- cliente nacia huerfana y despues el no podia verla en su seguimiento.
    -- No se toma del JSON a proposito: sale de auth.uid(), asi nadie puede
    -- mandar solicitudes a nombre de otro. Un visitante anonimo sigue dando
    -- null, como hasta ahora.
    public.mi_cliente_id(),
    (p_datos ->> 'tipo_servicio')::tipo_servicio,
    nullif(p_datos ->> 'nivel_requerido', '')::nivel_enfermeria,
    coalesce((select array_agg(value) from jsonb_array_elements_text(p_datos -> 'especialidad_requerida')), '{}'),
    nullif(p_datos ->> 'descripcion_paciente', ''),
    nullif(p_datos ->> 'entorno', '')::entorno_servicio,
    nullif(p_datos ->> 'tipo_paciente', ''),
    nullif(p_datos ->> 'nivel_atencion', '')::nivel_atencion,
    coalesce((select array_agg(value) from jsonb_array_elements_text(p_datos -> 'procedimientos')), '{}'),
    coalesce((p_datos ->> 'cantidad_enfermeros')::int, 1),
    (p_datos ->> 'fecha_inicio')::date,
    nullif(p_datos ->> 'fecha_fin', '')::date,
    nullif(p_datos ->> 'turno', '')::turno_tipo,
    nullif(p_datos ->> 'horas_por_turno', '')::int,
    coalesce((select array_agg(value) from jsonb_array_elements_text(p_datos -> 'dias_semana')), '{}'),
    nullif(p_datos ->> 'direccion_servicio', ''),
    nullif(p_datos ->> 'municipio', ''),
    coalesce((p_datos ->> 'urgente')::boolean, false),
    coalesce(nullif(p_datos ->> 'origen', ''), 'landing'),
    nullif(p_datos ->> 'codigo_referido', ''),
    coalesce((select array_agg(value::uuid) from jsonb_array_elements_text(p_datos -> 'enfermeros_solicitados')), '{}'),
    nullif(p_datos ->> 'contacto_nombre', ''),
    nullif(p_datos ->> 'contacto_telefono', ''),
    nullif(p_datos ->> 'contacto_email', '')
  )
  returning folio into nuevo_folio;

  return nuevo_folio;
end;
$$;

create or replace function public.registrar_enfermero(p_datos jsonb)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  nuevo_folio text;
begin
  insert into public.enfermeros (
    nombre_completo, fecha_nacimiento, genero, nivel, cedula_profesional,
    institucion_egreso, anios_experiencia, especialidades, certificaciones,
    idiomas, bio, zonas_cobertura, disponible_inmediato, acepta_domicilio,
    acepta_nocturno, acepta_foraneo,
    -- Siempre entra sin verificar y sin publicar, pase lo que pase en el json
    estatus_verificacion, publicado, cedula_verificada, usuario_id
  )
  values (
    nullif(p_datos ->> 'nombre_completo', ''),
    nullif(p_datos ->> 'fecha_nacimiento', '')::date,
    nullif(p_datos ->> 'genero', ''),
    (p_datos ->> 'nivel')::nivel_enfermeria,
    nullif(p_datos ->> 'cedula_profesional', ''),
    nullif(p_datos ->> 'institucion_egreso', ''),
    coalesce((p_datos ->> 'anios_experiencia')::int, 0),
    coalesce((select array_agg(value) from jsonb_array_elements_text(p_datos -> 'especialidades')), '{}'),
    coalesce((select array_agg(value) from jsonb_array_elements_text(p_datos -> 'certificaciones')), '{}'),
    coalesce((select array_agg(value) from jsonb_array_elements_text(p_datos -> 'idiomas')), '{Español}'),
    nullif(p_datos ->> 'bio', ''),
    coalesce((select array_agg(value) from jsonb_array_elements_text(p_datos -> 'zonas_cobertura')), '{}'),
    coalesce((p_datos ->> 'disponible_inmediato')::boolean, false),
    coalesce((p_datos ->> 'acepta_domicilio')::boolean, true),
    coalesce((p_datos ->> 'acepta_nocturno')::boolean, false),
    coalesce((p_datos ->> 'acepta_foraneo')::boolean, false),
    'pendiente', false, false, null
  )
  returning folio into nuevo_folio;

  return nuevo_folio;
end;
$$;

-- Solo estas dos funciones son invocables sin sesion
revoke all on function public.crear_solicitud(jsonb)     from public;
revoke all on function public.registrar_enfermero(jsonb) from public;
grant execute on function public.crear_solicitud(jsonb)     to anon, authenticated;
grant execute on function public.registrar_enfermero(jsonb) to anon, authenticated;

-- ############################################################################
-- ###  04-vistas.sql
-- ############################################################################

-- ============================================================================
-- Enlace Enfermero — 04. Vistas
-- Exposicion publica controlada y vistas de reportes (CLAUDE.md 6 y 7).
-- Ejecutar despues de 03-funciones.sql.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CATALOGO PUBLICO
-- El sitio publico NUNCA consulta `enfermeros` directamente. Esta vista es el
-- unico punto de lectura anonima y deja fuera, a proposito:
--   cedula_profesional, telefono, correo, direccion, tarifas y notas_internas.
-- Si el cliente pudiera contactar directo al enfermero, se pierde la comision.
--
-- Se deja en security_invoker = false (comportamiento por omision) para que
-- corra con los permisos del propietario y pueda leerse sin sesion; el filtro
-- de filas y de columnas ya vive dentro de la propia vista.
-- ----------------------------------------------------------------------------
create or replace view public.enfermeros_publico as
select
  id,
  folio,
  nombre_completo,
  nivel,
  anios_experiencia,
  especialidades,
  certificaciones,
  idiomas,
  bio,
  foto_url,
  zonas_cobertura,
  disponible_inmediato,
  acepta_domicilio,
  acepta_nocturno,
  calificacion_promedio,
  total_servicios,
  cedula_verificada
from public.enfermeros e
where publicado = true
  and estatus_verificacion = 'verificado'
  -- Regla 10.3: un documento obligatorio caducado saca el perfil del catalogo.
  -- Va aqui y no en un proceso programado porque el vencimiento ocurre por el
  -- paso del tiempo: si dependiera de un job, entre que caduca y que el job
  -- corre el perfil seguiria ofreciendose como verificado.
  and not public.tiene_obligatorio_vencido(e.id);

grant select on public.enfermeros_publico to anon, authenticated;

-- ----------------------------------------------------------------------------
-- VISTAS DE REPORTES
-- Todas con security_invoker = true: respetan el RLS de las tablas base, de
-- modo que solo el staff ve la informacion completa.
-- ----------------------------------------------------------------------------

-- v_kpis_mes: servicios completados, ingresos, comision y cobertura por mes
create or replace view public.v_kpis_mes
with (security_invoker = true) as
select
  date_trunc('month', a.fecha)::date            as mes,
  count(*) filter (where a.estatus = 'completada')      as turnos_completados,
  count(*) filter (where a.estatus = 'no_asistio')      as turnos_no_asistidos,
  coalesce(sum(a.tarifa_cliente)   filter (where a.estatus = 'completada'), 0) as ingresos,
  coalesce(sum(a.tarifa_enfermero) filter (where a.estatus = 'completada'), 0) as pago_enfermeros,
  coalesce(sum(a.comision_agencia) filter (where a.estatus = 'completada'), 0) as comision,
  count(distinct a.enfermero_id) filter (where a.estatus = 'completada')       as enfermeros_activos
from public.asignaciones a
group by 1
order by 1 desc;

-- v_ranking_enfermeros: por calificacion y turnos completados
create or replace view public.v_ranking_enfermeros
with (security_invoker = true) as
select
  e.id,
  e.folio,
  e.nombre_completo,
  e.nivel,
  e.calificacion_promedio,
  count(a.id) filter (where a.estatus = 'completada') as turnos_completados,
  count(a.id) filter (where a.estatus = 'no_asistio') as inasistencias,
  count(a.id) filter (where a.estatus = 'cancelada')  as cancelaciones,
  coalesce(sum(a.comision_agencia) filter (where a.estatus = 'completada'), 0) as comision_generada
from public.enfermeros e
left join public.asignaciones a on a.enfermero_id = e.id
group by e.id, e.folio, e.nombre_completo, e.nivel, e.calificacion_promedio
order by e.calificacion_promedio desc nulls last, turnos_completados desc;

-- v_solicitudes_sin_cubrir: en busqueda desde hace mas de 24 horas
create or replace view public.v_solicitudes_sin_cubrir
with (security_invoker = true) as
select
  s.id,
  s.folio,
  s.tipo_servicio,
  s.nivel_requerido,
  s.municipio,
  s.fecha_inicio,
  s.urgente,
  s.created_at,
  round(extract(epoch from (now() - s.created_at)) / 3600)::int as horas_transcurridas,
  c.razon_social,
  c.nombre_contacto
from public.solicitudes s
left join public.clientes c on c.id = s.cliente_id
where s.estatus in ('nueva', 'en_busqueda')
  and s.created_at < now() - interval '24 hours'
order by s.urgente desc, s.created_at;

-- v_ganancias_enfermero: agregado por enfermero y quincena
create or replace view public.v_ganancias_enfermero
with (security_invoker = true) as
select
  a.enfermero_id,
  e.folio,
  e.nombre_completo,
  date_trunc('month', a.fecha)::date as mes,
  case when extract(day from a.fecha) <= 15 then 1 else 2 end as quincena,
  count(*)                       as turnos,
  sum(a.tarifa_enfermero)        as total_a_pagar,
  min(a.fecha)                   as primera_fecha,
  max(a.fecha)                   as ultima_fecha
from public.asignaciones a
join public.enfermeros e on e.id = a.enfermero_id
where a.estatus = 'completada'
group by a.enfermero_id, e.folio, e.nombre_completo, 4, 5
order by mes desc, quincena desc, e.nombre_completo;

grant select on public.v_kpis_mes,
                public.v_ranking_enfermeros,
                public.v_solicitudes_sin_cubrir,
                public.v_ganancias_enfermero
  to authenticated;

-- ############################################################################
-- ###  06-dashboard.sql
-- ############################################################################

-- ============================================================================
-- Enlace Enfermero — 06. Funciones del panel de la agencia
-- Indicadores, alertas y series para admin/index.html (CLAUDE.md 8.6).
--
-- Todo se resuelve en la base y no en el navegador: son agregados sobre varias
-- tablas y traerlos crudos al frontend seria lento y expondria datos de mas.
-- Cada funcion corta si quien llama no es staff. Usan es_staff_estricto() y no
-- es_staff(): dentro de un security definer, current_user es el propietario, y
-- es_staff() daria por bueno a cualquier usuario con sesion.
-- ============================================================================

-- Se eliminan antes de recrear: CREATE OR REPLACE no admite cambiar el tipo de
-- retorno de una funcion que devuelve tabla.
drop function if exists public.kpis_dashboard();
drop function if exists public.alertas_dashboard();
drop function if exists public.turnos_por_semana(int);
drop function if exists public.ultimas_solicitudes(int);

-- ----------------------------------------------------------------------------
-- Los seis indicadores del dia
-- ----------------------------------------------------------------------------
create or replace function public.kpis_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  inicio_mes date := date_trunc('month', current_date)::date;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede consultar los indicadores'
      using errcode = '42501';
  end if;

  return jsonb_build_object(

    'solicitudes_nuevas_hoy', (
      select count(*) from public.solicitudes
      where created_at::date = current_date and estatus = 'nueva'
    ),

    -- Lo que urge cubrir: solicitudes abiertas que ya deberian tener personal
    'turnos_por_cubrir', (
      select count(*) from public.solicitudes
      where estatus in ('nueva', 'en_busqueda')
    ),

    'turnos_en_curso', (
      select count(*) from public.asignaciones
      where estatus = 'en_curso'
         or (estatus = 'aceptada' and fecha = current_date)
    ),

    'enfermeros_disponibles_hoy', (
      select count(distinct d.enfermero_id)
      from public.disponibilidad d
      join public.enfermeros e on e.id = d.enfermero_id
      where d.fecha = current_date
        and d.disponible = true
        and e.publicado = true
        and e.estatus_verificacion = 'verificado'
    ),

    'ingresos_mes', (
      select coalesce(sum(tarifa_cliente), 0) from public.asignaciones
      where estatus = 'completada' and fecha >= inicio_mes
    ),

    'comision_mes', (
      select coalesce(sum(comision_agencia), 0) from public.asignaciones
      where estatus = 'completada' and fecha >= inicio_mes
    ),

    -- Comparativo con el mes anterior, para saber si vamos mejor o peor
    'comision_mes_anterior', (
      select coalesce(sum(comision_agencia), 0) from public.asignaciones
      where estatus = 'completada'
        and fecha >= (inicio_mes - interval '1 month')::date
        and fecha <  inicio_mes
    ),

    'turnos_completados_mes', (
      select count(*) from public.asignaciones
      where estatus = 'completada' and fecha >= inicio_mes
    )
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Alertas que exigen accion del coordinador
-- ----------------------------------------------------------------------------
create or replace function public.alertas_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede consultar las alertas'
      using errcode = '42501';
  end if;

  return jsonb_build_object(

    -- Vencidos, separados en dos. Solo los OBLIGATORIOS sacan el perfil del
    -- catalogo (regla 10.3); un BLS caducado no despublica a nadie. Contarlos
    -- juntos hacia que el panel dijera "el perfil se despublica" sobre alguien
    -- que en realidad seguia publicado y con razon.
    'documentos_vencidos', (
      select count(*) from public.documentos
      where fecha_vencimiento is not null
        and fecha_vencimiento < current_date
        and estatus <> 'rechazado'
    ),

    'vencidos_obligatorios', (
      select count(*)
      from public.documentos d
      join public.enfermeros e on e.id = d.enfermero_id
      where d.tipo = any(public.documentos_obligatorios(e.nivel))
        and d.fecha_vencimiento is not null
        and d.fecha_vencimiento < current_date
        and d.estatus <> 'rechazado'
    ),

    'documentos_por_vencer', (
      select count(*) from public.documentos
      where fecha_vencimiento is not null
        and fecha_vencimiento between current_date and current_date + 30
        and estatus <> 'rechazado'
    ),

    -- Regla 10.x: una solicitud sin cubrir a mas de 24 h es una senal de alarma
    'solicitudes_sin_cubrir', (
      select count(*) from public.solicitudes
      where estatus in ('nueva', 'en_busqueda')
        and created_at < now() - interval '24 hours'
    ),

    'verificaciones_pendientes', (
      select count(*) from public.enfermeros
      where estatus_verificacion in ('pendiente', 'en_revision')
    ),

    'documentos_por_revisar', (
      select count(*) from public.documentos
      where estatus in ('pendiente', 'en_revision')
    ),

    'propuestas_sin_respuesta', (
      select count(*) from public.asignaciones
      where estatus = 'propuesta'
        and created_at < now() - interval '12 hours'
    )
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Turnos de las ultimas semanas, para la grafica
-- ----------------------------------------------------------------------------
create or replace function public.turnos_por_semana(p_semanas int default 8)
returns table (
  semana        date,
  completados   bigint,
  cancelados    bigint,
  comision      numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede consultar esta serie'
      using errcode = '42501';
  end if;

  return query
  -- Se generan todas las semanas del rango para que la grafica no tenga huecos
  with semanas as (
    select generate_series(
      date_trunc('week', current_date - (p_semanas - 1) * 7),
      date_trunc('week', current_date),
      interval '1 week'
    )::date as semana
  )
  select s.semana,
         count(a.id) filter (where a.estatus = 'completada'),
         count(a.id) filter (where a.estatus in ('cancelada', 'no_asistio')),
         coalesce(sum(a.comision_agencia) filter (where a.estatus = 'completada'), 0)
  from semanas s
  left join public.asignaciones a
         on date_trunc('week', a.fecha)::date = s.semana
  group by s.semana
  order by s.semana;
end;
$$;

-- ----------------------------------------------------------------------------
-- Ultimas solicitudes con lo necesario para actuar sin abrir cada una
-- ----------------------------------------------------------------------------
create or replace function public.ultimas_solicitudes(p_limite int default 10)
returns table (
  id                uuid,
  folio             text,
  cliente           text,
  tipo_servicio     tipo_servicio,
  nivel_requerido   nivel_enfermeria,
  nivel_atencion    nivel_atencion,
  municipio         text,
  fecha_inicio      date,
  cantidad          int,
  urgente           boolean,
  estatus           estatus_solicitud,
  horas_esperando   int,
  asignados         bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede consultar las solicitudes'
      using errcode = '42501';
  end if;

  return query
  select s.id, s.folio,
         coalesce(c.razon_social, c.nombre_contacto, s.contacto_nombre, 'Sin nombre'),
         s.tipo_servicio, s.nivel_requerido, s.nivel_atencion, s.municipio,
         s.fecha_inicio, s.cantidad_enfermeros, s.urgente, s.estatus,
         (extract(epoch from (now() - s.created_at)) / 3600)::int,
         (select count(*) from public.asignaciones a
          where a.solicitud_id = s.id and a.estatus <> 'rechazada')
  from public.solicitudes s
  left join public.clientes c on c.id = s.cliente_id
  order by s.urgente desc, s.created_at desc
  limit p_limite;
end;
$$;

-- Solo con sesion iniciada; dentro cada funcion comprueba que sea staff
revoke all on function public.kpis_dashboard()          from public;
revoke all on function public.alertas_dashboard()       from public;
revoke all on function public.turnos_por_semana(int)    from public;
revoke all on function public.ultimas_solicitudes(int)  from public;

grant execute on function public.kpis_dashboard()         to authenticated;
grant execute on function public.alertas_dashboard()      to authenticated;
grant execute on function public.turnos_por_semana(int)   to authenticated;
grant execute on function public.ultimas_solicitudes(int) to authenticated;

-- ############################################################################
-- ###  07-solicitudes.sql
-- ############################################################################

-- ============================================================================
-- Enlace Enfermero — 07. Solicitudes y sugerencia de personal
-- Tablero de la agencia y motor de match (CLAUDE.md 8.6).
--
-- Todas las funciones comprueban con es_staff_estricto(): son security definer
-- y dentro de una funcion asi `current_user` es el propietario, no el rol del
-- llamante, asi que es_staff() daria por bueno a cualquier usuario con sesion.
-- ============================================================================

-- Se eliminan antes de recrear: CREATE OR REPLACE no admite cambiar el tipo de
-- retorno, y estas funciones devuelven tablas que van a seguir evolucionando.
drop function if exists public.sugerir_enfermeros(uuid, int);
drop function if exists public.solicitudes_tablero();
drop function if exists public.detalle_solicitud(uuid);
drop function if exists public.cambiar_estatus_solicitud(uuid, estatus_solicitud);
drop function if exists public.cotizar_solicitud(uuid, numeric);
drop function if exists public.proponer_asignacion(uuid, uuid, date, turno_tipo, time, time, numeric, numeric);

-- ----------------------------------------------------------------------------
-- Que certificacion respalda cada procedimiento
-- Se usa para no proponer a alguien sin la acreditacion que el caso exige.
-- Los procedimientos que no aparecen aqui no requieren certificado especifico.
-- ----------------------------------------------------------------------------
create or replace function public.certificacion_requerida(p_procedimiento text)
returns text
language sql
immutable
as $$
  select case p_procedimiento
    when 'medicamentos_iv' then 'medicamentos_iv'
    when 'ventilacion'     then 'ventilacion'
    when 'cateteres'       then 'cateteres'
    when 'sondas'          then 'cateteres'
    when 'curaciones'      then 'heridas_avanzadas'
    when 'oxigeno'         then 'via_aerea'
    when 'glucosa'         then 'muestras'
    else null
  end;
$$;

-- Orden jerarquico de los niveles: un especialista puede cubrir un puesto de
-- auxiliar, pero no al reves.
create or replace function public.rango_nivel(p_nivel nivel_enfermeria)
returns int
language sql
immutable
as $$
  select case p_nivel
    when 'cuidador'     then 1
    when 'auxiliar'     then 2
    when 'tecnico'      then 3
    when 'general'      then 4
    when 'licenciado'   then 5
    when 'especialista' then 6
  end;
$$;

-- ----------------------------------------------------------------------------
-- MOTOR DE SUGERENCIA
--
-- Devuelve los perfiles compatibles con una solicitud, con una puntuacion que
-- explica por que. No decide por el coordinador: ordena y justifica para que
-- el decida rapido.
-- ----------------------------------------------------------------------------
create or replace function public.sugerir_enfermeros(
  p_solicitud_id uuid,
  p_limite int default 12
)
returns table (
  id                    uuid,
  folio                 text,
  nombre_completo       text,
  nivel                 nivel_enfermeria,
  anios_experiencia     int,
  calificacion_promedio numeric,
  total_servicios       int,
  foto_url              text,
  tarifa_turno_12       numeric,
  disponible_inmediato  boolean,
  puntuacion            int,
  cubre_nivel           boolean,
  cubre_zona            boolean,
  disponible_fecha      boolean,
  especialidades_match  text[],
  procedimientos_falta  text[],
  ya_ocupado            boolean,
  motivos               text[],
  puntuacion_maxima     int
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  s public.solicitudes%rowtype;
  v_maximo int;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede consultar sugerencias'
      using errcode = '42501';
  end if;

  select sol.* into s from public.solicitudes sol where sol.id = p_solicitud_id;
  if not found then
    raise exception 'No existe la solicitud %', p_solicitud_id;
  end if;

  -- Techo alcanzable para ESTA solicitud: nivel exacto + zona + disponible +
  -- todas las especialidades + inmediato + calificacion perfecta + 10 anios.
  -- Sirve para que el porcentaje diga "que tanto cumple", no "quien va ganando".
  v_maximo := 30 + 20 + 25
            + coalesce(array_length(s.especialidad_requerida, 1), 0) * 12
            + 6 + 20 + 10;

  return query
  with candidatos as (
    select
      e.*,
      -- Nivel: exacto vale mas que uno superior, porque encima cuesta mas caro
      case
        when s.nivel_requerido is null then true
        when public.rango_nivel(e.nivel) >= public.rango_nivel(s.nivel_requerido) then true
        else false
      end as cumple_nivel,
      (s.nivel_requerido is not null and e.nivel = s.nivel_requerido) as nivel_exacto,

      (s.municipio is null or s.municipio = any(e.zonas_cobertura)) as en_zona,

      -- Especialidades de la solicitud que este perfil si tiene
      coalesce((
        select array_agg(esp) from unnest(s.especialidad_requerida) esp
        where esp = any(e.especialidades)
      ), '{}') as esp_coinciden,

      -- Procedimientos pedidos cuya certificacion le falta
      coalesce((
        select array_agg(proc) from unnest(s.procedimientos) proc
        where public.certificacion_requerida(proc) is not null
          and not (public.certificacion_requerida(proc) = any(e.certificaciones))
      ), '{}') as procs_sin_respaldo,

      -- Marco su disponibilidad en la fecha de inicio
      exists (
        select 1 from public.disponibilidad d
        where d.enfermero_id = e.id
          and d.fecha = s.fecha_inicio
          and d.disponible = true
          and (s.turno is null or d.turno = s.turno)
      ) as libre_ese_dia,

      -- Ya comprometido ese dia: no se puede proponer
      exists (
        select 1 from public.asignaciones a
        where a.enfermero_id = e.id
          and a.fecha = s.fecha_inicio
          and a.estatus in ('aceptada', 'en_curso', 'completada')
      ) as ocupado,

      -- Ya se le propuso esta misma solicitud
      exists (
        select 1 from public.asignaciones a
        where a.enfermero_id = e.id
          and a.solicitud_id = s.id
          and a.estatus <> 'rechazada'
      ) as ya_propuesto

    from public.enfermeros e
    where e.publicado = true
      and e.estatus_verificacion = 'verificado'
  ),
  puntuados as (
    select c.*,
      (
          case when c.nivel_exacto then 30 when c.cumple_nivel then 18 else 0 end
        + case when c.en_zona then 20 else 0 end
        + case when c.libre_ese_dia then 25 else 0 end
        + coalesce(array_length(c.esp_coinciden, 1), 0) * 12
        - coalesce(array_length(c.procs_sin_respaldo, 1), 0) * 10
        + case when c.disponible_inmediato then 6 else 0 end
        + round(coalesce(c.calificacion_promedio, 0) * 4)::int
        + least(c.anios_experiencia, 10)
        - case when c.ocupado then 60 else 0 end
      ) as puntos
    from candidatos c
    where c.cumple_nivel
      and not c.ya_propuesto
  )
  select
    p.id, p.folio, p.nombre_completo, p.nivel, p.anios_experiencia,
    p.calificacion_promedio, p.total_servicios, p.foto_url, p.tarifa_turno_12,
    p.disponible_inmediato,
    greatest(p.puntos, 0)::int,
    p.cumple_nivel, p.en_zona, p.libre_ese_dia,
    p.esp_coinciden, p.procs_sin_respaldo, p.ocupado,
    -- Razones legibles, para que el coordinador no tenga que adivinar
    (
      select array_remove(array[
        case when p.nivel_exacto then 'Nivel exacto'
             when p.cumple_nivel then 'Nivel superior al pedido' end,
        case when p.en_zona then 'Cubre la zona' else 'Fuera de su zona' end,
        case when p.libre_ese_dia then 'Marcó disponible ese día' end,
        case when array_length(p.esp_coinciden, 1) > 0
             then array_length(p.esp_coinciden, 1) || ' especialidad(es) que pediste' end,
        case when array_length(p.procs_sin_respaldo, 1) > 0
             then 'Le falta certificación para ' || array_length(p.procs_sin_respaldo, 1) || ' procedimiento(s)' end,
        case when p.ocupado then 'Ya tiene turno ese día' end,
        case when p.total_servicios > 50 then 'Más de 50 servicios con nosotros' end
      ], null)
    ),
    v_maximo
  from puntuados p
  order by p.puntos desc, p.calificacion_promedio desc nulls last, p.total_servicios desc
  limit p_limite;
end;
$$;

-- ----------------------------------------------------------------------------
-- TABLERO: solicitudes agrupadas por estatus
-- ----------------------------------------------------------------------------
create or replace function public.solicitudes_tablero()
returns table (
  id                uuid,
  folio             text,
  cliente           text,
  tipo_servicio     tipo_servicio,
  nivel_requerido   nivel_enfermeria,
  nivel_atencion    nivel_atencion,
  entorno           entorno_servicio,
  municipio         text,
  fecha_inicio      date,
  turno             turno_tipo,
  cantidad          int,
  urgente           boolean,
  estatus           estatus_solicitud,
  horas_esperando   int,
  asignados         bigint,
  aceptados         bigint,
  tarifa            numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver el tablero'
      using errcode = '42501';
  end if;

  return query
  select s.id, s.folio,
         coalesce(c.razon_social, c.nombre_contacto, s.contacto_nombre, 'Sin nombre'),
         s.tipo_servicio, s.nivel_requerido, s.nivel_atencion, s.entorno,
         s.municipio, s.fecha_inicio, s.turno, s.cantidad_enfermeros,
         s.urgente, s.estatus,
         (extract(epoch from (now() - s.created_at)) / 3600)::int,
         (select count(*) from public.asignaciones a
          where a.solicitud_id = s.id and a.estatus <> 'rechazada'),
         (select count(*) from public.asignaciones a
          where a.solicitud_id = s.id
            and a.estatus in ('aceptada', 'en_curso', 'completada')),
         s.tarifa_ofrecida_cliente
  from public.solicitudes s
  left join public.clientes c on c.id = s.cliente_id
  where s.estatus <> 'cancelada'
     or s.updated_at > now() - interval '7 days'
  order by s.urgente desc, s.fecha_inicio, s.created_at desc;
end;
$$;

-- ----------------------------------------------------------------------------
-- DETALLE de una solicitud, con todo lo necesario para cotizar y asignar
-- ----------------------------------------------------------------------------
create or replace function public.detalle_solicitud(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  resultado jsonb;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver la solicitud'
      using errcode = '42501';
  end if;

  select jsonb_build_object(
    'solicitud', to_jsonb(s) - 'cliente_id',
    'cliente', case when c.id is null then null else jsonb_build_object(
        'id', c.id, 'tipo', c.tipo, 'razon_social', c.razon_social,
        'nombre_contacto', c.nombre_contacto, 'telefono', c.telefono,
        'email', c.email, 'municipio', c.municipio
      ) end,
    'asignaciones', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'estatus', a.estatus, 'fecha', a.fecha, 'turno', a.turno,
        'hora_inicio', a.hora_inicio, 'hora_fin', a.hora_fin,
        'tarifa_cliente', a.tarifa_cliente, 'tarifa_enfermero', a.tarifa_enfermero,
        'comision_agencia', a.comision_agencia, 'motivo_rechazo', a.motivo_rechazo,
        'enfermero', jsonb_build_object(
          'id', e.id, 'folio', e.folio, 'nombre_completo', e.nombre_completo,
          'nivel', e.nivel, 'foto_url', e.foto_url,
          'calificacion_promedio', e.calificacion_promedio
        )
      ) order by a.created_at)
      from public.asignaciones a
      join public.enfermeros e on e.id = a.enfermero_id
      where a.solicitud_id = s.id
    ), '[]'::jsonb)
  ) into resultado
  from public.solicitudes s
  left join public.clientes c on c.id = s.cliente_id
  where s.id = p_id;

  if resultado is null then
    raise exception 'No existe la solicitud %', p_id;
  end if;

  return resultado;
end;
$$;

-- ----------------------------------------------------------------------------
-- ACCIONES DEL COORDINADOR
-- ----------------------------------------------------------------------------

-- Mover una solicitud de columna en el tablero
create or replace function public.cambiar_estatus_solicitud(
  p_id uuid,
  p_estatus estatus_solicitud
)
returns estatus_solicitud
language plpgsql
security definer
set search_path = public
as $$
declare
  actual estatus_solicitud;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede mover solicitudes'
      using errcode = '42501';
  end if;

  select sol.estatus into actual from public.solicitudes sol where sol.id = p_id;
  if not found then
    raise exception 'No existe la solicitud %', p_id;
  end if;

  -- No se puede confirmar algo sin nadie aceptado: el tablero mentiria
  if p_estatus in ('confirmada', 'en_curso') then
    if not exists (
      select 1 from public.asignaciones
      where solicitud_id = p_id and estatus in ('aceptada', 'en_curso', 'completada')
    ) then
      raise exception 'No puedes marcarla como % sin personal que haya aceptado', p_estatus
        using errcode = 'P0001';
    end if;
  end if;

  update public.solicitudes set estatus = p_estatus where id = p_id;
  return p_estatus;
end;
$$;

-- Cotizar: la tarifa la escribe la agencia, nunca el cliente (CLAUDE.md 15.5)
create or replace function public.cotizar_solicitud(p_id uuid, p_tarifa numeric)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede cotizar'
      using errcode = '42501';
  end if;

  if p_tarifa is null or p_tarifa < 0 then
    raise exception 'La tarifa debe ser un monto positivo' using errcode = 'P0001';
  end if;

  update public.solicitudes
  set tarifa_ofrecida_cliente = round(p_tarifa, 2)
  where id = p_id;

  return round(p_tarifa, 2);
end;
$$;

-- Proponer a un profesional. Aplica el reparto 60/40 salvo que se indique otro.
create or replace function public.proponer_asignacion(
  p_solicitud_id  uuid,
  p_enfermero_id  uuid,
  p_fecha         date default null,
  p_turno         turno_tipo default null,
  p_hora_inicio   time default null,
  p_hora_fin      time default null,
  p_tarifa_cliente numeric default null,
  p_tarifa_enfermero numeric default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.solicitudes%rowtype;
  nueva_id uuid;
  v_fecha date;
  v_turno turno_tipo;
  v_inicio time;
  v_fin time;
  v_cliente numeric;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede proponer'
      using errcode = '42501';
  end if;

  select sol.* into s from public.solicitudes sol where sol.id = p_solicitud_id;
  if not found then
    raise exception 'No existe la solicitud %', p_solicitud_id;
  end if;

  v_fecha := coalesce(p_fecha, s.fecha_inicio);
  v_turno := coalesce(p_turno, s.turno, 'matutino');

  -- Horario: el que se indique, o el que corresponde al turno
  if p_hora_inicio is not null and p_hora_fin is not null then
    v_inicio := p_hora_inicio;
    v_fin    := p_hora_fin;
  else
    select h.inicio, h.fin into v_inicio, v_fin
    from (values
      ('matutino'::turno_tipo,   '07:00'::time, '15:00'::time),
      ('vespertino',             '15:00',       '23:00'),
      ('nocturno',               '23:00',       '07:00'),
      ('guardia_12',             '07:00',       '19:00'),
      ('guardia_24',             '08:00',       '08:00'),
      ('fin_semana',             '07:00',       '19:00')
    ) as h(turno, inicio, fin)
    where h.turno = v_turno;
  end if;

  -- La tarifa al cliente sale de la cotizacion si no se pasa otra
  v_cliente := coalesce(p_tarifa_cliente, s.tarifa_ofrecida_cliente);
  if v_cliente is null then
    raise exception 'Cotiza la solicitud antes de proponer personal'
      using errcode = 'P0001';
  end if;

  insert into public.asignaciones (
    solicitud_id, enfermero_id, fecha, turno, hora_inicio, hora_fin,
    tarifa_cliente, tarifa_enfermero, estatus
  )
  values (
    p_solicitud_id, p_enfermero_id, v_fecha, v_turno, v_inicio, v_fin,
    v_cliente,
    -- Si no se indica, el trigger de reparto pone el 60%
    coalesce(p_tarifa_enfermero, 0),
    'propuesta'
  )
  returning id into nueva_id;

  -- La solicitud avanza sola al primer envio de propuesta
  if s.estatus in ('nueva', 'en_busqueda') then
    update public.solicitudes set estatus = 'propuesta_enviada' where id = p_solicitud_id;
  end if;

  return nueva_id;
end;
$$;

revoke all on function public.sugerir_enfermeros(uuid, int)          from public;
revoke all on function public.solicitudes_tablero()                  from public;
revoke all on function public.detalle_solicitud(uuid)                from public;
revoke all on function public.cambiar_estatus_solicitud(uuid, estatus_solicitud) from public;
revoke all on function public.cotizar_solicitud(uuid, numeric)       from public;
revoke all on function public.proponer_asignacion(uuid, uuid, date, turno_tipo, time, time, numeric, numeric) from public;

grant execute on function public.sugerir_enfermeros(uuid, int)          to authenticated;
grant execute on function public.solicitudes_tablero()                  to authenticated;
grant execute on function public.detalle_solicitud(uuid)                to authenticated;
grant execute on function public.cambiar_estatus_solicitud(uuid, estatus_solicitud) to authenticated;
grant execute on function public.cotizar_solicitud(uuid, numeric)       to authenticated;
grant execute on function public.proponer_asignacion(uuid, uuid, date, turno_tipo, time, time, numeric, numeric) to authenticated;

-- ############################################################################
-- ###  08-documentos.sql
-- ############################################################################

-- ============================================================================
-- Enlace Enfermero — 08. Verificacion documental
-- Bandeja de revision y publicacion de perfiles (CLAUDE.md 8.6 y 10.2).
--
-- Aqui vive el diferenciador del negocio: nadie aparece en el catalogo sin
-- haber pasado por esto. Las reglas se aplican en la base, no solo en la
-- pantalla, para que no haya forma de saltarselas.
-- ============================================================================

drop function if exists public.documentos_bandeja(estatus_verif, uuid);
drop function if exists public.expediente_enfermero(uuid);
drop function if exists public.revisar_documento(uuid, boolean, text);
drop function if exists public.verificar_enfermero(uuid, boolean);

-- ----------------------------------------------------------------------------
-- Que documentos exige cada nivel (regla 10.2)
--
-- La definicion se movio a 02-rls.sql porque la necesitan enfermero_es_publico()
-- y la vista del catalogo, que se crean antes que este archivo. Aqui se sigue
-- usando igual; solo cambio de lugar.
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- BANDEJA: documentos esperando revision, con su contexto
-- ----------------------------------------------------------------------------
create or replace function public.documentos_bandeja(
  p_estatus estatus_verif default null,
  p_enfermero_id uuid default null
)
returns table (
  id                uuid,
  enfermero_id      uuid,
  folio             text,
  nombre_completo   text,
  nivel             nivel_enfermeria,
  tipo              tipo_documento,
  archivo_url       text,
  fecha_emision     date,
  fecha_vencimiento date,
  dias_para_vencer  int,
  estatus           estatus_verif,
  motivo_rechazo    text,
  verificado_at     timestamptz,
  revisado_por      text,
  subido_hace       int,
  obligatorio       boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede revisar documentos'
      using errcode = '42501';
  end if;

  return query
  select d.id, e.id, e.folio, e.nombre_completo, e.nivel,
         d.tipo, d.archivo_url, d.fecha_emision, d.fecha_vencimiento,
         case when d.fecha_vencimiento is null then null
              else (d.fecha_vencimiento - current_date)::int end,
         d.estatus, d.motivo_rechazo, d.verificado_at,
         trim(coalesce(u.nombre, '') || ' ' || coalesce(u.apellidos, '')),
         (extract(epoch from (now() - d.created_at)) / 3600)::int,
         d.tipo = any(public.documentos_obligatorios(e.nivel))
  from public.documentos d
  join public.enfermeros e on e.id = d.enfermero_id
  left join public.usuarios u on u.id = d.verificado_por
  where (p_estatus is null or d.estatus = p_estatus)
    and (p_enfermero_id is null or d.enfermero_id = p_enfermero_id)
  -- Lo pendiente primero, y dentro de eso lo que lleva mas tiempo esperando
  order by
    case d.estatus
      when 'pendiente'   then 1
      when 'en_revision' then 2
      when 'vencido'     then 3
      when 'rechazado'   then 4
      else 5
    end,
    d.created_at;
end;
$$;


-- ----------------------------------------------------------------------------
-- EXPEDIENTE: todo lo que hay que saber de un candidato para decidir
-- ----------------------------------------------------------------------------
create or replace function public.expediente_enfermero(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  e public.enfermeros%rowtype;
  obligatorios tipo_documento[];
  resultado jsonb;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver expedientes'
      using errcode = '42501';
  end if;

  select enf.* into e from public.enfermeros enf where enf.id = p_id;
  if not found then
    raise exception 'No existe el perfil %', p_id;
  end if;

  obligatorios := public.documentos_obligatorios(e.nivel);

  select jsonb_build_object(
    'enfermero', to_jsonb(e),

    'documentos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'tipo', d.tipo, 'archivo_url', d.archivo_url,
        'estatus', d.estatus, 'fecha_emision', d.fecha_emision,
        'fecha_vencimiento', d.fecha_vencimiento,
        'motivo_rechazo', d.motivo_rechazo, 'verificado_at', d.verificado_at,
        'obligatorio', d.tipo = any(obligatorios)
      ) order by d.tipo = any(obligatorios) desc, d.tipo)
      from public.documentos d where d.enfermero_id = p_id
    ), '[]'::jsonb),

    'obligatorios', to_jsonb(obligatorios),

    -- Los que exige su nivel y todavia no estan aprobados
    'faltantes', coalesce((
      select jsonb_agg(t)
      from unnest(obligatorios) t
      where not exists (
        select 1 from public.documentos d
        where d.enfermero_id = p_id and d.tipo = t and d.estatus = 'verificado'
      )
    ), '[]'::jsonb),

    'puede_verificarse', not exists (
      select 1 from unnest(obligatorios) t
      where not exists (
        select 1 from public.documentos d
        where d.enfermero_id = p_id and d.tipo = t and d.estatus = 'verificado'
      )
    ),

    'tiene_vencidos', exists (
      select 1 from public.documentos d
      where d.enfermero_id = p_id and d.estatus = 'vencido'
    )
  ) into resultado;

  return resultado;
end;
$$;

-- ----------------------------------------------------------------------------
-- REVISAR un documento: aprobar o rechazar con motivo
-- ----------------------------------------------------------------------------
create or replace function public.revisar_documento(
  p_id       uuid,
  p_aprobado boolean,
  p_motivo   text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  d public.documentos%rowtype;
  enfermero_id_afectado uuid;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede revisar documentos'
      using errcode = '42501';
  end if;

  select doc.* into d from public.documentos doc where doc.id = p_id;
  if not found then
    raise exception 'No existe el documento %', p_id;
  end if;

  if not p_aprobado and coalesce(trim(p_motivo), '') = '' then
    raise exception 'Para rechazar hay que decir por que: el candidato necesita saber que corregir'
      using errcode = 'P0001';
  end if;

  -- Un documento ya vencido no se aprueba: primero hay que renovarlo
  if p_aprobado and d.fecha_vencimiento is not null and d.fecha_vencimiento < current_date then
    raise exception 'Ese documento venció el %. Pide la renovación antes de aprobarlo',
      to_char(d.fecha_vencimiento, 'DD/MM/YYYY') using errcode = 'P0001';
  end if;

  update public.documentos
  set estatus        = (case when p_aprobado then 'verificado' else 'rechazado' end)::estatus_verif,
      motivo_rechazo = case when p_aprobado then null else trim(p_motivo) end,
      verificado_por = auth.uid(),
      verificado_at  = now()
  where id = p_id;

  enfermero_id_afectado := d.enfermero_id;

  -- Si se rechaza algo obligatorio de alguien ya publicado, se despublica:
  -- no puede seguir en el catalogo con el expediente incompleto
  if not p_aprobado then
    update public.enfermeros
    set publicado = false,
        estatus_verificacion = case
          when estatus_verificacion = 'verificado' then 'en_revision'
          else estatus_verificacion end
    where id = enfermero_id_afectado
      and publicado = true
      and d.tipo = any(public.documentos_obligatorios(nivel));
  end if;

  return public.expediente_enfermero(enfermero_id_afectado);
end;
$$;

-- ----------------------------------------------------------------------------
-- VERIFICAR y publicar un perfil
-- Solo si su expediente esta completo: la regla no se puede saltar desde la UI.
-- ----------------------------------------------------------------------------
create or replace function public.verificar_enfermero(
  p_id       uuid,
  p_publicar boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  expediente jsonb;
  e public.enfermeros%rowtype;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede verificar perfiles'
      using errcode = '42501';
  end if;

  select enf.* into e from public.enfermeros enf where enf.id = p_id;
  if not found then
    raise exception 'No existe el perfil %', p_id;
  end if;

  expediente := public.expediente_enfermero(p_id);

  if not (expediente ->> 'puede_verificarse')::boolean then
    raise exception 'Faltan documentos obligatorios por aprobar: %',
      (select string_agg(valor, ', ')
       from jsonb_array_elements_text(expediente -> 'faltantes') valor)
      using errcode = 'P0001';
  end if;

  if (expediente ->> 'tiene_vencidos')::boolean then
    raise exception 'Tiene documentos vencidos. Renuévalos antes de publicar el perfil'
      using errcode = 'P0001';
  end if;

  update public.enfermeros
  set estatus_verificacion = 'verificado',
      publicado            = p_publicar,
      -- La cedula se da por validada cuando su documento quedo aprobado
      cedula_verificada    = exists (
        select 1 from public.documentos d
        where d.enfermero_id = p_id
          and d.tipo = 'cedula_profesional'
          and d.estatus = 'verificado'
      )
  where id = p_id;

  return public.expediente_enfermero(p_id);
end;
$$;

-- Quitar del catalogo sin borrar nada
create or replace function public.despublicar_enfermero(p_id uuid, p_motivo text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede despublicar perfiles'
      using errcode = '42501';
  end if;

  update public.enfermeros
  set publicado = false,
      notas_internas = case
        when coalesce(trim(p_motivo), '') = '' then notas_internas
        else coalesce(notas_internas || E'\n', '') ||
             to_char(now(), 'DD/MM/YYYY') || ' - Despublicado: ' || trim(p_motivo)
      end
  where id = p_id;
end;
$$;

revoke all on function public.documentos_bandeja(estatus_verif, uuid) from public;
revoke all on function public.expediente_enfermero(uuid)              from public;
revoke all on function public.revisar_documento(uuid, boolean, text)  from public;
revoke all on function public.verificar_enfermero(uuid, boolean)      from public;
revoke all on function public.despublicar_enfermero(uuid, text)       from public;

grant execute on function public.documentos_bandeja(estatus_verif, uuid) to authenticated;
grant execute on function public.expediente_enfermero(uuid)              to authenticated;
grant execute on function public.revisar_documento(uuid, boolean, text)  to authenticated;
grant execute on function public.verificar_enfermero(uuid, boolean)      to authenticated;
grant execute on function public.despublicar_enfermero(uuid, text)       to authenticated;

-- ############################################################################
-- ###  09-operacion.sql
-- ############################################################################

-- ============================================================================
-- Enlace Enfermero — 09. Operación diaria
-- Asignaciones, calendario, enfermeros y clientes (CLAUDE.md 8.6).
-- ============================================================================

drop function if exists public.asignaciones_lista(estatus_asignacion, date, date, uuid);
drop function if exists public.responder_asignacion_admin(uuid, estatus_asignacion, text);
drop function if exists public.registrar_asistencia(uuid, text);
drop function if exists public.calendario_mes(int, int);
drop function if exists public.enfermeros_admin(text, estatus_verif, boolean);
drop function if exists public.guardar_enfermero(jsonb);
drop function if exists public.clientes_admin(text);
drop function if exists public.guardar_cliente(jsonb);

-- ----------------------------------------------------------------------------
-- ASIGNACIONES
-- ----------------------------------------------------------------------------
create or replace function public.asignaciones_lista(
  p_estatus  estatus_asignacion default null,
  p_desde    date default null,
  p_hasta    date default null,
  p_enfermero uuid default null
)
returns table (
  id                uuid,
  solicitud_id      uuid,
  folio_solicitud   text,
  cliente           text,
  enfermero_id      uuid,
  enfermero         text,
  folio_enfermero   text,
  nivel             nivel_enfermeria,
  fecha             date,
  turno             turno_tipo,
  hora_inicio       time,
  hora_fin          time,
  tarifa_cliente    numeric,
  tarifa_enfermero  numeric,
  comision_agencia  numeric,
  estatus           estatus_asignacion,
  checkin_at        timestamptz,
  checkout_at       timestamptz,
  motivo_rechazo    text,
  municipio         text
)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver las asignaciones'
      using errcode = '42501';
  end if;

  return query
  select a.id, a.solicitud_id, s.folio,
         coalesce(c.razon_social, c.nombre_contacto, s.contacto_nombre, 'Sin nombre'),
         e.id, e.nombre_completo, e.folio, e.nivel,
         a.fecha, a.turno, a.hora_inicio, a.hora_fin,
         a.tarifa_cliente, a.tarifa_enfermero, a.comision_agencia,
         a.estatus, a.checkin_at, a.checkout_at, a.motivo_rechazo, s.municipio
  from public.asignaciones a
  join public.enfermeros e  on e.id = a.enfermero_id
  join public.solicitudes s on s.id = a.solicitud_id
  left join public.clientes c on c.id = s.cliente_id
  where (p_estatus is null   or a.estatus = p_estatus)
    and (p_desde is null     or a.fecha >= p_desde)
    and (p_hasta is null     or a.fecha <= p_hasta)
    and (p_enfermero is null or a.enfermero_id = p_enfermero)
  order by a.fecha desc, a.hora_inicio;
end;
$$;

-- La agencia puede mover cualquier asignación; el enfermero solo responde a la
-- propuesta desde su panel, con las transiciones que permite su trigger.
create or replace function public.responder_asignacion_admin(
  p_id      uuid,
  p_estatus estatus_asignacion,
  p_motivo  text default null
)
returns estatus_asignacion
language plpgsql security definer set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede cambiar asignaciones'
      using errcode = '42501';
  end if;

  if p_estatus in ('rechazada', 'cancelada', 'no_asistio')
     and coalesce(trim(p_motivo), '') = '' then
    raise exception 'Hace falta el motivo: queda en el historial de confiabilidad'
      using errcode = 'P0001';
  end if;

  update public.asignaciones
  set estatus = p_estatus,
      motivo_rechazo = case when p_estatus in ('rechazada','cancelada','no_asistio')
                            then trim(p_motivo) else motivo_rechazo end
  where id = p_id;

  return p_estatus;
end;
$$;

-- Entrada y salida del turno
create or replace function public.registrar_asistencia(p_id uuid, p_accion text)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  a public.asignaciones%rowtype;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede registrar asistencia'
      using errcode = '42501';
  end if;

  select asg.* into a from public.asignaciones asg where asg.id = p_id;
  if not found then
    raise exception 'No existe la asignación %', p_id;
  end if;

  if p_accion = 'entrada' then
    if a.estatus <> 'aceptada' then
      raise exception 'Solo se registra entrada en un turno aceptado' using errcode = 'P0001';
    end if;
    update public.asignaciones
    set checkin_at = now(), estatus = 'en_curso' where id = p_id;

  elsif p_accion = 'salida' then
    if a.checkin_at is null then
      raise exception 'Primero hay que registrar la entrada' using errcode = 'P0001';
    end if;
    update public.asignaciones
    set checkout_at = now(), estatus = 'completada' where id = p_id;

  else
    raise exception 'Acción no válida: %', p_accion using errcode = 'P0001';
  end if;

  return jsonb_build_object('id', p_id, 'accion', p_accion);
end;
$$;

-- ----------------------------------------------------------------------------
-- CALENDARIO: los turnos de un mes
-- ----------------------------------------------------------------------------
create or replace function public.calendario_mes(p_anio int, p_mes int)
returns table (
  fecha        date,
  total        bigint,
  propuestas   bigint,
  aceptadas    bigint,
  en_curso     bigint,
  completadas  bigint,
  incidencias  bigint,
  detalle      jsonb
)
language plpgsql stable security definer set search_path = public
as $$
declare
  inicio date := make_date(p_anio, p_mes, 1);
  fin    date := (inicio + interval '1 month - 1 day')::date;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver el calendario'
      using errcode = '42501';
  end if;

  return query
  -- generate_series con intervalo devuelve timestamptz: hay que bajarlo a date
  select d.dia::date,
         count(a.id),
         count(a.id) filter (where a.estatus = 'propuesta'),
         count(a.id) filter (where a.estatus = 'aceptada'),
         count(a.id) filter (where a.estatus = 'en_curso'),
         count(a.id) filter (where a.estatus = 'completada'),
         count(a.id) filter (where a.estatus in ('no_asistio','cancelada')),
         coalesce(jsonb_agg(jsonb_build_object(
           'id', a.id, 'enfermero', e.nombre_completo, 'turno', a.turno,
           'estatus', a.estatus, 'cliente', coalesce(c.razon_social, c.nombre_contacto, 'Sin nombre')
         ) order by a.hora_inicio) filter (where a.id is not null), '[]'::jsonb)
  from generate_series(inicio, fin, interval '1 day') as d(dia)
  left join public.asignaciones a on a.fecha = d.dia
  left join public.enfermeros e   on e.id = a.enfermero_id
  left join public.solicitudes s  on s.id = a.solicitud_id
  left join public.clientes c     on c.id = s.cliente_id
  group by d.dia
  order by d.dia;
end;
$$;

-- ----------------------------------------------------------------------------
-- ENFERMEROS: cartera completa, con lo que el publico nunca ve
-- ----------------------------------------------------------------------------
create or replace function public.enfermeros_admin(
  p_texto    text default null,
  p_estatus  estatus_verif default null,
  p_publicado boolean default null
)
returns table (
  id                    uuid,
  folio                 text,
  nombre_completo       text,
  nivel                 nivel_enfermeria,
  telefono              text,
  email                 text,
  anios_experiencia     int,
  especialidades        text[],
  zonas_cobertura       text[],
  calificacion_promedio numeric,
  total_servicios       int,
  estatus_verificacion  estatus_verif,
  publicado             boolean,
  disponible_inmediato  boolean,
  tarifa_turno_12       numeric,
  docs_pendientes       bigint,
  docs_vencidos         bigint,
  turnos_mes            bigint,
  tiene_cuenta          boolean
)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver la cartera'
      using errcode = '42501';
  end if;

  return query
  select e.id, e.folio, e.nombre_completo, e.nivel,
         u.telefono, u.email,
         e.anios_experiencia, e.especialidades, e.zonas_cobertura,
         e.calificacion_promedio, e.total_servicios,
         e.estatus_verificacion, e.publicado, e.disponible_inmediato,
         e.tarifa_turno_12,
         (select count(*) from public.documentos d
          where d.enfermero_id = e.id and d.estatus in ('pendiente','en_revision')),
         (select count(*) from public.documentos d
          where d.enfermero_id = e.id and d.estatus = 'vencido'),
         (select count(*) from public.asignaciones a
          where a.enfermero_id = e.id
            and a.fecha >= date_trunc('month', current_date)
            and a.estatus = 'completada'),
         e.usuario_id is not null
  from public.enfermeros e
  left join public.usuarios u on u.id = e.usuario_id
  where (p_estatus is null   or e.estatus_verificacion = p_estatus)
    and (p_publicado is null or e.publicado = p_publicado)
    and (p_texto is null or p_texto = '' or
         e.nombre_completo ilike '%' || p_texto || '%' or
         e.folio ilike '%' || p_texto || '%')
  order by e.created_at desc;
end;
$$;

-- Alta y edicion desde el panel. Solo la agencia toca los campos reservados.
create or replace function public.guardar_enfermero(p_datos jsonb)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid := nullif(p_datos ->> 'id', '')::uuid;
  arr text[];
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede dar de alta personal'
      using errcode = '42501';
  end if;

  if coalesce(trim(p_datos ->> 'nombre_completo'), '') = '' then
    raise exception 'El nombre es obligatorio' using errcode = 'P0001';
  end if;

  if v_id is null then
    insert into public.enfermeros (
      nombre_completo, nivel, cedula_profesional, institucion_egreso,
      anios_experiencia, especialidades, certificaciones, idiomas, bio,
      zonas_cobertura, disponible_inmediato, acepta_domicilio, acepta_nocturno,
      acepta_foraneo, tarifa_hora, tarifa_turno_8, tarifa_turno_12, tarifa_turno_24,
      notas_internas
    ) values (
      trim(p_datos ->> 'nombre_completo'),
      (p_datos ->> 'nivel')::nivel_enfermeria,
      nullif(p_datos ->> 'cedula_profesional', ''),
      nullif(p_datos ->> 'institucion_egreso', ''),
      coalesce((p_datos ->> 'anios_experiencia')::int, 0),
      coalesce((select array_agg(v) from jsonb_array_elements_text(p_datos -> 'especialidades') v), '{}'),
      coalesce((select array_agg(v) from jsonb_array_elements_text(p_datos -> 'certificaciones') v), '{}'),
      coalesce((select array_agg(v) from jsonb_array_elements_text(p_datos -> 'idiomas') v), '{Español}'),
      nullif(p_datos ->> 'bio', ''),
      coalesce((select array_agg(v) from jsonb_array_elements_text(p_datos -> 'zonas_cobertura') v), '{}'),
      coalesce((p_datos ->> 'disponible_inmediato')::boolean, false),
      coalesce((p_datos ->> 'acepta_domicilio')::boolean, true),
      coalesce((p_datos ->> 'acepta_nocturno')::boolean, false),
      coalesce((p_datos ->> 'acepta_foraneo')::boolean, false),
      nullif(p_datos ->> 'tarifa_hora', '')::numeric,
      nullif(p_datos ->> 'tarifa_turno_8', '')::numeric,
      nullif(p_datos ->> 'tarifa_turno_12', '')::numeric,
      nullif(p_datos ->> 'tarifa_turno_24', '')::numeric,
      nullif(p_datos ->> 'notas_internas', '')
    ) returning id into v_id;
  else
    update public.enfermeros set
      nombre_completo    = trim(p_datos ->> 'nombre_completo'),
      nivel              = (p_datos ->> 'nivel')::nivel_enfermeria,
      cedula_profesional = nullif(p_datos ->> 'cedula_profesional', ''),
      institucion_egreso = nullif(p_datos ->> 'institucion_egreso', ''),
      anios_experiencia  = coalesce((p_datos ->> 'anios_experiencia')::int, 0),
      especialidades     = coalesce((select array_agg(v) from jsonb_array_elements_text(p_datos -> 'especialidades') v), '{}'),
      certificaciones    = coalesce((select array_agg(v) from jsonb_array_elements_text(p_datos -> 'certificaciones') v), '{}'),
      idiomas            = coalesce((select array_agg(v) from jsonb_array_elements_text(p_datos -> 'idiomas') v), '{Español}'),
      bio                = nullif(p_datos ->> 'bio', ''),
      zonas_cobertura    = coalesce((select array_agg(v) from jsonb_array_elements_text(p_datos -> 'zonas_cobertura') v), '{}'),
      disponible_inmediato = coalesce((p_datos ->> 'disponible_inmediato')::boolean, false),
      acepta_domicilio   = coalesce((p_datos ->> 'acepta_domicilio')::boolean, true),
      acepta_nocturno    = coalesce((p_datos ->> 'acepta_nocturno')::boolean, false),
      acepta_foraneo     = coalesce((p_datos ->> 'acepta_foraneo')::boolean, false),
      tarifa_hora        = nullif(p_datos ->> 'tarifa_hora', '')::numeric,
      tarifa_turno_8     = nullif(p_datos ->> 'tarifa_turno_8', '')::numeric,
      tarifa_turno_12    = nullif(p_datos ->> 'tarifa_turno_12', '')::numeric,
      tarifa_turno_24    = nullif(p_datos ->> 'tarifa_turno_24', '')::numeric,
      notas_internas     = nullif(p_datos ->> 'notas_internas', '')
    where id = v_id;
  end if;

  return v_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- CLIENTES
-- ----------------------------------------------------------------------------
create or replace function public.clientes_admin(p_texto text default null)
returns table (
  id                uuid,
  tipo              tipo_cliente,
  razon_social      text,
  nombre_contacto   text,
  telefono          text,
  email             text,
  rfc               text,
  requiere_factura  boolean,
  municipio         text,
  activo            boolean,
  solicitudes       bigint,
  turnos            bigint,
  facturado         numeric,
  ultima_solicitud  timestamptz,
  tiene_cuenta      boolean
)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver la cartera de clientes'
      using errcode = '42501';
  end if;

  return query
  select c.id, c.tipo, c.razon_social, c.nombre_contacto, c.telefono, c.email,
         c.rfc, c.requiere_factura, c.municipio, c.activo,
         (select count(*) from public.solicitudes s where s.cliente_id = c.id),
         (select count(*) from public.asignaciones a
          join public.solicitudes s on s.id = a.solicitud_id
          where s.cliente_id = c.id and a.estatus = 'completada'),
         coalesce((select sum(a.tarifa_cliente) from public.asignaciones a
          join public.solicitudes s on s.id = a.solicitud_id
          where s.cliente_id = c.id and a.estatus = 'completada'), 0),
         (select max(s.created_at) from public.solicitudes s where s.cliente_id = c.id),
         c.usuario_id is not null
  from public.clientes c
  where (p_texto is null or p_texto = '' or
         coalesce(c.razon_social, '') ilike '%' || p_texto || '%' or
         c.nombre_contacto ilike '%' || p_texto || '%')
  order by c.created_at desc;
end;
$$;

create or replace function public.guardar_cliente(p_datos jsonb)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid := nullif(p_datos ->> 'id', '')::uuid;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede dar de alta clientes'
      using errcode = '42501';
  end if;

  if coalesce(trim(p_datos ->> 'nombre_contacto'), '') = '' then
    raise exception 'El nombre de contacto es obligatorio' using errcode = 'P0001';
  end if;

  if v_id is null then
    insert into public.clientes (tipo, razon_social, nombre_contacto, telefono, email,
                                 rfc, requiere_factura, direccion, colonia, municipio, cp, notas)
    values (
      coalesce((p_datos ->> 'tipo')::tipo_cliente, 'particular'),
      nullif(p_datos ->> 'razon_social', ''), trim(p_datos ->> 'nombre_contacto'),
      nullif(p_datos ->> 'telefono', ''), nullif(p_datos ->> 'email', ''),
      nullif(p_datos ->> 'rfc', ''), coalesce((p_datos ->> 'requiere_factura')::boolean, false),
      nullif(p_datos ->> 'direccion', ''), nullif(p_datos ->> 'colonia', ''),
      nullif(p_datos ->> 'municipio', ''), nullif(p_datos ->> 'cp', ''),
      nullif(p_datos ->> 'notas', '')
    ) returning id into v_id;
  else
    update public.clientes set
      tipo = coalesce((p_datos ->> 'tipo')::tipo_cliente, tipo),
      razon_social = nullif(p_datos ->> 'razon_social', ''),
      nombre_contacto = trim(p_datos ->> 'nombre_contacto'),
      telefono = nullif(p_datos ->> 'telefono', ''),
      email = nullif(p_datos ->> 'email', ''),
      rfc = nullif(p_datos ->> 'rfc', ''),
      requiere_factura = coalesce((p_datos ->> 'requiere_factura')::boolean, false),
      direccion = nullif(p_datos ->> 'direccion', ''),
      colonia = nullif(p_datos ->> 'colonia', ''),
      municipio = nullif(p_datos ->> 'municipio', ''),
      cp = nullif(p_datos ->> 'cp', ''),
      notas = nullif(p_datos ->> 'notas', ''),
      activo = coalesce((p_datos ->> 'activo')::boolean, activo)
    where id = v_id;
  end if;

  return v_id;
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'asignaciones_lista(estatus_asignacion, date, date, uuid)',
    'responder_asignacion_admin(uuid, estatus_asignacion, text)',
    'registrar_asistencia(uuid, text)',
    'calendario_mes(int, int)',
    'enfermeros_admin(text, estatus_verif, boolean)',
    'guardar_enfermero(jsonb)',
    'clientes_admin(text)',
    'guardar_cliente(jsonb)'
  ] loop
    execute format('revoke all on function public.%s from public', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ############################################################################
-- ###  10-finanzas.sql
-- ############################################################################

-- ============================================================================
-- Enlace Enfermero — 10. Finanzas y administración
-- Pagos, reportes, referidos y configuración (CLAUDE.md 8.6).
-- ============================================================================

drop function if exists public.corte_enfermeros(date, date);
drop function if exists public.cobros_clientes(date, date);
drop function if exists public.registrar_pago(jsonb);
drop function if exists public.pagos_lista(tipo_pago, estatus_pago);
drop function if exists public.reporte_periodo(date, date);
drop function if exists public.referidos_lista();
drop function if exists public.leer_configuracion();
drop function if exists public.guardar_configuracion(text, jsonb);

-- ----------------------------------------------------------------------------
-- CONFIGURACION: clave-valor, para lo que la agencia ajusta sin tocar codigo
-- ----------------------------------------------------------------------------
create table if not exists public.configuracion (
  clave       text primary key,
  valor       jsonb not null,
  descripcion text,
  updated_at  timestamptz not null default now()
);

alter table public.configuracion enable row level security;

drop policy if exists configuracion_staff on public.configuracion;
create policy configuracion_staff on public.configuracion
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

grant select, insert, update on public.configuracion to authenticated;

insert into public.configuracion (clave, valor, descripcion) values
  ('reparto', '{"enfermero": 0.60, "agencia": 0.40}'::jsonb,
   'Reparto por defecto de cada servicio (CLAUDE.md 15.2)'),
  ('agencia', '{"nombre": "Enlace Enfermero", "whatsapp": "", "email": "", "ciudad": "Guadalajara, Jalisco"}'::jsonb,
   'Datos de contacto que se muestran en el sitio'),
  ('tarifas_referencia', '{}'::jsonb,
   'Punto de partida interno para cotizar, por nivel y turno. No es un tabulador cerrado.'),
  ('recompensas_referido', '{"enfermero": 300, "cliente_descuento": 0.10}'::jsonb,
   'Lo que se acredita cuando un referido completa su primer servicio pagado')
on conflict (clave) do nothing;

create or replace function public.leer_configuracion()
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare resultado jsonb;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede leer la configuración'
      using errcode = '42501';
  end if;

  select jsonb_object_agg(clave, jsonb_build_object('valor', valor, 'descripcion', descripcion))
  into resultado from public.configuracion;

  return coalesce(resultado, '{}'::jsonb);
end;
$$;

create or replace function public.guardar_configuracion(p_clave text, p_valor jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
begin
  -- La configuracion la ajusta el admin, no la coordinacion
  if not exists (select 1 from public.usuarios
                 where id = auth.uid() and rol = 'admin' and activo) then
    raise exception 'Solo el administrador puede cambiar la configuración'
      using errcode = '42501';
  end if;

  -- El reparto tiene que sumar exactamente 1, o el dinero se pierde o se inventa
  if p_clave = 'reparto' then
    if abs(((p_valor ->> 'enfermero')::numeric + (p_valor ->> 'agencia')::numeric) - 1) > 0.0001 then
      raise exception 'Los dos porcentajes deben sumar 100%%' using errcode = 'P0001';
    end if;
  end if;

  insert into public.configuracion (clave, valor, updated_at)
  values (p_clave, p_valor, now())
  on conflict (clave) do update set valor = excluded.valor, updated_at = now();

  return p_valor;
end;
$$;

-- ----------------------------------------------------------------------------
-- CORTE DE PAGOS AL PERSONAL
-- Suma los turnos completados que todavia no se han pagado.
-- ----------------------------------------------------------------------------
create or replace function public.corte_enfermeros(p_desde date, p_hasta date)
returns table (
  enfermero_id  uuid,
  folio         text,
  nombre        text,
  nivel         nivel_enfermeria,
  turnos        bigint,
  total_pagar   numeric,
  comision      numeric,
  facturado     numeric,
  ya_pagado     numeric,
  pendiente     numeric
)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver los cortes'
      using errcode = '42501';
  end if;

  return query
  select e.id, e.folio, e.nombre_completo, e.nivel,
         count(a.id),
         coalesce(sum(a.tarifa_enfermero), 0),
         coalesce(sum(a.comision_agencia), 0),
         coalesce(sum(a.tarifa_cliente), 0),
         coalesce((
           select sum(p.monto) from public.pagos p
           where p.tipo = 'pago_enfermero'
             and p.referencia_id = e.id
             and p.estatus = 'pagado'
             and p.periodo_inicio = p_desde
             and p.periodo_fin = p_hasta
         ), 0),
         coalesce(sum(a.tarifa_enfermero), 0) - coalesce((
           select sum(p.monto) from public.pagos p
           where p.tipo = 'pago_enfermero'
             and p.referencia_id = e.id
             and p.estatus = 'pagado'
             and p.periodo_inicio = p_desde
             and p.periodo_fin = p_hasta
         ), 0)
  from public.enfermeros e
  join public.asignaciones a on a.enfermero_id = e.id
  where a.estatus = 'completada'
    and a.fecha between p_desde and p_hasta
  group by e.id, e.folio, e.nombre_completo, e.nivel
  having count(a.id) > 0
  order by 6 desc;
end;
$$;

-- ----------------------------------------------------------------------------
-- COBROS A CLIENTES
-- ----------------------------------------------------------------------------
create or replace function public.cobros_clientes(p_desde date, p_hasta date)
returns table (
  cliente_id   uuid,
  cliente      text,
  tipo         tipo_cliente,
  requiere_factura boolean,
  turnos       bigint,
  total_cobrar numeric,
  ya_cobrado   numeric,
  pendiente    numeric
)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver los cobros'
      using errcode = '42501';
  end if;

  return query
  select c.id,
         coalesce(c.razon_social, c.nombre_contacto),
         c.tipo, c.requiere_factura,
         count(a.id),
         coalesce(sum(a.tarifa_cliente), 0),
         coalesce((
           select sum(p.monto) from public.pagos p
           join public.solicitudes s2 on s2.id = p.referencia_id
           where p.tipo = 'cobro_cliente' and p.estatus = 'pagado'
             and s2.cliente_id = c.id
             and p.periodo_inicio = p_desde and p.periodo_fin = p_hasta
         ), 0),
         coalesce(sum(a.tarifa_cliente), 0) - coalesce((
           select sum(p.monto) from public.pagos p
           join public.solicitudes s2 on s2.id = p.referencia_id
           where p.tipo = 'cobro_cliente' and p.estatus = 'pagado'
             and s2.cliente_id = c.id
             and p.periodo_inicio = p_desde and p.periodo_fin = p_hasta
         ), 0)
  from public.clientes c
  join public.solicitudes s on s.cliente_id = c.id
  join public.asignaciones a on a.solicitud_id = s.id
  where a.estatus = 'completada'
    and a.fecha between p_desde and p_hasta
  group by c.id, c.razon_social, c.nombre_contacto, c.tipo, c.requiere_factura
  order by 6 desc;
end;
$$;

create or replace function public.registrar_pago(p_datos jsonb)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare v_id uuid;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede registrar pagos'
      using errcode = '42501';
  end if;

  if coalesce((p_datos ->> 'monto')::numeric, 0) <= 0 then
    raise exception 'El monto debe ser mayor a cero' using errcode = 'P0001';
  end if;

  insert into public.pagos (tipo, referencia_id, periodo_inicio, periodo_fin,
                            monto, metodo, estatus, comprobante_url, fecha_pago, notas)
  values (
    (p_datos ->> 'tipo')::tipo_pago,
    (p_datos ->> 'referencia_id')::uuid,
    nullif(p_datos ->> 'periodo_inicio', '')::date,
    nullif(p_datos ->> 'periodo_fin', '')::date,
    (p_datos ->> 'monto')::numeric,
    nullif(p_datos ->> 'metodo', ''),
    coalesce((p_datos ->> 'estatus')::estatus_pago, 'pagado'),
    nullif(p_datos ->> 'comprobante_url', ''),
    coalesce(nullif(p_datos ->> 'fecha_pago', '')::date, current_date),
    nullif(p_datos ->> 'notas', '')
  ) returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.pagos_lista(
  p_tipo tipo_pago default null,
  p_estatus estatus_pago default null
)
returns table (
  id            uuid,
  tipo          tipo_pago,
  referencia_id uuid,
  concepto      text,
  periodo_inicio date,
  periodo_fin   date,
  monto         numeric,
  metodo        text,
  estatus       estatus_pago,
  fecha_pago    date,
  notas         text
)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver los pagos'
      using errcode = '42501';
  end if;

  return query
  select p.id, p.tipo, p.referencia_id,
         case p.tipo
           when 'pago_enfermero' then
             coalesce((select e.nombre_completo from public.enfermeros e where e.id = p.referencia_id), 'Sin referencia')
           else
             coalesce((select coalesce(c.razon_social, c.nombre_contacto)
                       from public.solicitudes s
                       left join public.clientes c on c.id = s.cliente_id
                       where s.id = p.referencia_id), 'Sin referencia')
         end,
         p.periodo_inicio, p.periodo_fin, p.monto, p.metodo, p.estatus,
         p.fecha_pago, p.notas
  from public.pagos p
  where (p_tipo is null or p.tipo = p_tipo)
    and (p_estatus is null or p.estatus = p_estatus)
  order by p.created_at desc;
end;
$$;

-- ----------------------------------------------------------------------------
-- REPORTES
-- ----------------------------------------------------------------------------
create or replace function public.reporte_periodo(p_desde date, p_hasta date)
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare resultado jsonb;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver los reportes'
      using errcode = '42501';
  end if;

  select jsonb_build_object(
    'resumen', (
      select jsonb_build_object(
        'turnos_completados', count(*) filter (where estatus = 'completada'),
        'turnos_cancelados',  count(*) filter (where estatus = 'cancelada'),
        'inasistencias',      count(*) filter (where estatus = 'no_asistio'),
        'ingresos',  coalesce(sum(tarifa_cliente)   filter (where estatus = 'completada'), 0),
        'pagado',    coalesce(sum(tarifa_enfermero) filter (where estatus = 'completada'), 0),
        'comision',  coalesce(sum(comision_agencia) filter (where estatus = 'completada'), 0),
        'enfermeros_activos', count(distinct enfermero_id) filter (where estatus = 'completada')
      )
      from public.asignaciones where fecha between p_desde and p_hasta
    ),

    'solicitudes', (
      select jsonb_build_object(
        'recibidas',  count(*),
        'cubiertas',  count(*) filter (where estatus in ('confirmada','en_curso','completada')),
        'canceladas', count(*) filter (where estatus = 'cancelada'),
        'tasa_cobertura', case when count(*) = 0 then 0 else
          round(count(*) filter (where estatus in ('confirmada','en_curso','completada'))::numeric
                / count(*) * 100, 1) end
      )
      from public.solicitudes where created_at::date between p_desde and p_hasta
    ),

    'ranking', coalesce((
      select jsonb_agg(fila order by fila ->> 'comision' desc)
      from (
        select jsonb_build_object(
          'nombre', e.nombre_completo, 'folio', e.folio, 'nivel', e.nivel,
          'turnos', count(a.id),
          'pagado', sum(a.tarifa_enfermero),
          'comision', sum(a.comision_agencia),
          'calificacion', e.calificacion_promedio
        ) as fila
        from public.asignaciones a
        join public.enfermeros e on e.id = a.enfermero_id
        where a.estatus = 'completada' and a.fecha between p_desde and p_hasta
        group by e.id, e.nombre_completo, e.folio, e.nivel, e.calificacion_promedio
        limit 20
      ) t
    ), '[]'::jsonb),

    'por_municipio', coalesce((
      select jsonb_agg(jsonb_build_object('municipio', municipio, 'turnos', turnos, 'ingresos', ingresos))
      from (
        select coalesce(s.municipio, 'sin especificar') as municipio,
               count(a.id) as turnos, sum(a.tarifa_cliente) as ingresos
        from public.asignaciones a
        join public.solicitudes s on s.id = a.solicitud_id
        where a.estatus = 'completada' and a.fecha between p_desde and p_hasta
        group by 1 order by 2 desc
      ) t
    ), '[]'::jsonb)
  ) into resultado;

  return resultado;
end;
$$;

-- ----------------------------------------------------------------------------
-- REFERIDOS
-- La recompensa se acredita al completarse el primer servicio del referido,
-- nunca al registrarse (CLAUDE.md 5.2).
-- ----------------------------------------------------------------------------
create or replace function public.referidos_lista()
returns table (
  id               uuid,
  codigo           text,
  referidor        text,
  referidor_rol    rol_usuario,
  referido         text,
  tipo_referido    text,
  estatus          estatus_referido,
  recompensa_monto numeric,
  fecha_validacion timestamptz,
  created_at       timestamptz,
  servicios_referido bigint
)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver los referidos'
      using errcode = '42501';
  end if;

  return query
  select r.id, r.codigo,
         trim(coalesce(ur.nombre,'') || ' ' || coalesce(ur.apellidos,'')),
         ur.rol,
         trim(coalesce(ud.nombre,'') || ' ' || coalesce(ud.apellidos,'')),
         r.tipo_referido, r.estatus, r.recompensa_monto, r.fecha_validacion, r.created_at,
         coalesce((
           select count(*) from public.asignaciones a
           join public.enfermeros e on e.id = a.enfermero_id
           where e.usuario_id = r.referido_id and a.estatus = 'completada'
         ), 0)
  from public.referidos r
  left join public.usuarios ur on ur.id = r.referidor_id
  left join public.usuarios ud on ud.id = r.referido_id
  order by r.created_at desc;
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'leer_configuracion()', 'guardar_configuracion(text, jsonb)',
    'corte_enfermeros(date, date)', 'cobros_clientes(date, date)',
    'registrar_pago(jsonb)', 'pagos_lista(tipo_pago, estatus_pago)',
    'reporte_periodo(date, date)', 'referidos_lista()'
  ] loop
    execute format('revoke all on function public.%s from public', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ############################################################################
-- ###  11-paneles.sql
-- ############################################################################

-- ============================================================================
-- Enlace Enfermero — 11. Funciones del panel del enfermero
-- Alimentan panel/index.html (CLAUDE.md 8.7).
--
-- Aqui el filtro va al reves que en 06-10: alla se comprueba que quien llama
-- SEA de la agencia; aqui se comprueba que NO lo sea, o mas exacto, que quien
-- llama tenga una ficha propia en `enfermeros`. Cada quien ve lo suyo y nada
-- mas.
--
-- El unico dato en el que se puede confiar dentro de un security definer es
-- auth.uid(), porque current_user pasa a ser el propietario de la funcion.
-- Por eso todo cuelga de mi_enfermero_id(), que mira auth.uid() y nada mas.
-- Un admin que llame a estas funciones sin tener ficha recibe un error: para
-- ver los datos de un profesional tiene sus propias funciones en 09.
-- ============================================================================

-- CREATE OR REPLACE no admite cambiar el tipo de retorno de una funcion que
-- devuelve tabla: hay que soltarlas antes.
drop function if exists public.panel_enfermero_resumen();
drop function if exists public.panel_enfermero_alertas();
drop function if exists public.panel_enfermero_proximos(int);

-- ----------------------------------------------------------------------------
-- Ficha del enfermero en sesion, o error si quien llama no tiene una.
-- Se repite en las tres funciones, asi que vive aparte.
-- ----------------------------------------------------------------------------
create or replace function public.mi_ficha_enfermero()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid := public.mi_enfermero_id();
begin
  if v_id is null then
    raise exception 'Esta sección es solo para el personal de enfermería registrado'
      using errcode = '42501';
  end if;
  return v_id;
end;
$$;

comment on function public.mi_ficha_enfermero() is
  'id de la ficha en `enfermeros` del usuario en sesion. Falla si no tiene. Base de todas las funciones del panel del enfermero.';

-- ----------------------------------------------------------------------------
-- Que tan completo esta el perfil
-- Solo cuenta campos que el propio enfermero puede editar: verificacion,
-- publicacion y tarifas son del admin (regla 10.6), asi que exigirselas seria
-- pedirle algo que no depende de el.
--
-- Recibe un id y NO es security definer, a proposito: si lo fuera, cualquiera
-- con sesion podria preguntar por el perfil de otro pasandole su uuid. Es un
-- ayudante interno sin permiso de ejecucion; solo lo llaman las funciones de
-- abajo, que ya resolvieron de quien se trata.
-- ----------------------------------------------------------------------------
create or replace function public.perfil_completo_pct(p_enfermero_id uuid)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  e            public.enfermeros%rowtype;
  faltantes    jsonb := '[]'::jsonb;
  total        int   := 9;
  hechos       int   := 0;
begin
  select * into e from public.enfermeros where id = p_enfermero_id;
  if not found then
    return jsonb_build_object('pct', 0, 'faltantes', faltantes);
  end if;

  if e.foto_url is not null and e.foto_url <> '' then hechos := hechos + 1;
  else faltantes := faltantes || jsonb_build_array('Tu fotografía'); end if;

  -- 80 caracteres es lo minimo para que una presentacion diga algo
  if length(coalesce(e.bio, '')) >= 80 then hechos := hechos + 1;
  else faltantes := faltantes || jsonb_build_array('Tu presentación'); end if;

  if coalesce(array_length(e.especialidades, 1), 0) > 0 then hechos := hechos + 1;
  else faltantes := faltantes || jsonb_build_array('Tus especialidades'); end if;

  if coalesce(array_length(e.certificaciones, 1), 0) > 0 then hechos := hechos + 1;
  else faltantes := faltantes || jsonb_build_array('Tus certificaciones'); end if;

  if coalesce(array_length(e.idiomas, 1), 0) > 0 then hechos := hechos + 1;
  else faltantes := faltantes || jsonb_build_array('Los idiomas que hablas'); end if;

  if coalesce(array_length(e.zonas_cobertura, 1), 0) > 0 then hechos := hechos + 1;
  else faltantes := faltantes || jsonb_build_array('Las zonas donde puedes trabajar'); end if;

  if coalesce(e.anios_experiencia, 0) > 0 then hechos := hechos + 1;
  else faltantes := faltantes || jsonb_build_array('Tus años de experiencia'); end if;

  if e.institucion_egreso is not null and e.institucion_egreso <> '' then hechos := hechos + 1;
  else faltantes := faltantes || jsonb_build_array('Tu institución de egreso'); end if;

  if e.fecha_nacimiento is not null then hechos := hechos + 1;
  else faltantes := faltantes || jsonb_build_array('Tu fecha de nacimiento'); end if;

  return jsonb_build_object(
    'pct',       round((hechos::numeric / total) * 100)::int,
    'hechos',    hechos,
    'total',     total,
    'faltantes', faltantes
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Los indicadores de la pantalla de inicio
-- ----------------------------------------------------------------------------
create or replace function public.panel_enfermero_resumen()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id         uuid := public.mi_ficha_enfermero();
  inicio_mes   date := date_trunc('month', current_date)::date;
  e            public.enfermeros%rowtype;
begin
  select * into e from public.enfermeros where id = v_id;

  return jsonb_build_object(

    -- Identidad del profesional, para encabezar la pantalla
    'folio',                 e.folio,
    'nombre',                e.nombre_completo,
    'nivel',                 e.nivel,
    'foto_url',              e.foto_url,
    'estatus_verificacion',  e.estatus_verificacion,
    'publicado',             e.publicado,
    'disponible_inmediato',  e.disponible_inmediato,

    -- Trabajo por delante. `propuesta` es lo que espera su respuesta;
    -- `aceptada` es lo que ya se comprometio a cubrir.
    'propuestas_pendientes', (
      select count(*) from public.asignaciones
      where enfermero_id = v_id
        and estatus = 'propuesta'
        and fecha >= current_date
    ),

    'turnos_proximos', (
      select count(*) from public.asignaciones
      where enfermero_id = v_id
        and estatus in ('aceptada', 'en_curso')
        and fecha >= current_date
    ),

    'turno_en_curso', (
      select count(*) from public.asignaciones
      where enfermero_id = v_id and estatus = 'en_curso'
    ),

    -- Ganancias: lo que ya se gano (turnos completados) contra el mes pasado.
    -- Es tarifa_enfermero, nunca tarifa_cliente: lo que la agencia factura no
    -- es asunto del profesional.
    'ganancias_mes', (
      select coalesce(sum(tarifa_enfermero), 0) from public.asignaciones
      where enfermero_id = v_id and estatus = 'completada' and fecha >= inicio_mes
    ),

    'ganancias_mes_anterior', (
      select coalesce(sum(tarifa_enfermero), 0) from public.asignaciones
      where enfermero_id = v_id and estatus = 'completada'
        and fecha >= (inicio_mes - interval '1 month')::date
        and fecha <  inicio_mes
    ),

    -- Lo comprometido a futuro: aun no es dinero ganado, pero ya esta agendado
    'por_ganar', (
      select coalesce(sum(tarifa_enfermero), 0) from public.asignaciones
      where enfermero_id = v_id
        and estatus in ('aceptada', 'en_curso')
        and fecha >= current_date
    ),

    'turnos_completados_mes', (
      select count(*) from public.asignaciones
      where enfermero_id = v_id and estatus = 'completada' and fecha >= inicio_mes
    ),

    'calificacion',    e.calificacion_promedio,
    'total_servicios', e.total_servicios,

    'perfil', public.perfil_completo_pct(v_id)
  );
end;
$$;

comment on function public.panel_enfermero_resumen() is
  'Indicadores de panel/index.html. Solo del enfermero en sesion: nunca expone tarifa_cliente ni comision.';

-- ----------------------------------------------------------------------------
-- Lo que requiere su atencion
-- Misma logica que las alertas del admin, pero acotadas a su expediente y
-- redactadas para el, no para la agencia.
-- ----------------------------------------------------------------------------
create or replace function public.panel_enfermero_alertas()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id         uuid := public.mi_ficha_enfermero();
  obligatorios tipo_documento[];
  v_nivel      nivel_enfermeria;
begin
  select nivel into v_nivel from public.enfermeros where id = v_id;
  obligatorios := public.documentos_obligatorios(v_nivel);

  return jsonb_build_object(

    -- Vencidos, separados en dos: solo los OBLIGATORIOS sacan el perfil del
    -- catalogo (regla 10.3). Un BLS caducado no despublica a nadie; le cierra
    -- la puerta a los turnos que pidan esa certificacion, que es distinto.
    -- Meterlos en el mismo saco hace que el panel le diga a alguien que esta
    -- fuera del catalogo cuando en realidad sigue publicado.
    'documentos_vencidos', (
      select count(*) from public.documentos
      where enfermero_id = v_id
        and fecha_vencimiento is not null
        and fecha_vencimiento < current_date
        and estatus <> 'rechazado'
    ),

    'vencidos_obligatorios', (
      select count(*) from public.documentos
      where enfermero_id = v_id
        and tipo = any(obligatorios)
        and fecha_vencimiento is not null
        and fecha_vencimiento < current_date
        and estatus <> 'rechazado'
    ),

    'documentos_por_vencer', (
      select count(*) from public.documentos
      where enfermero_id = v_id
        and fecha_vencimiento is not null
        and fecha_vencimiento between current_date and current_date + 30
        and estatus <> 'rechazado'
    ),

    'documentos_rechazados', (
      select count(*) from public.documentos
      where enfermero_id = v_id and estatus = 'rechazado'
    ),

    'documentos_en_revision', (
      select count(*) from public.documentos
      where enfermero_id = v_id and estatus in ('pendiente', 'en_revision')
    ),

    -- Obligatorios que no ha entregado. Sin ellos no hay verificacion, y sin
    -- verificacion no aparece en el catalogo (regla 10.1).
    'obligatorios_faltantes', (
      select count(*) from unnest(obligatorios) t
      where not exists (
        select 1 from public.documentos d
        where d.enfermero_id = v_id and d.tipo = t and d.estatus <> 'rechazado'
      )
    ),

    'propuestas_pendientes', (
      select count(*) from public.asignaciones
      where enfermero_id = v_id and estatus = 'propuesta' and fecha >= current_date
    ),

    -- Una propuesta que ya lleva mas de un dia esperando: el cliente esta
    -- viendo pasar el tiempo y la agencia puede reasignar el turno.
    'propuestas_urgentes', (
      select count(*) from public.asignaciones
      where enfermero_id = v_id
        and estatus = 'propuesta'
        and fecha >= current_date
        and (created_at < now() - interval '24 hours'
             or fecha <= current_date + 2)
    ),

    -- Turnos que ya terminaron y siguen sin cerrar: sin checkout no entran al
    -- corte de pago
    'sin_cerrar', (
      select count(*) from public.asignaciones
      where enfermero_id = v_id
        and estatus = 'en_curso'
        and fecha < current_date
    )
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Sus proximos turnos
--
-- Muestra el municipio siempre, pero la direccion exacta y el nombre del sitio
-- solo cuando ya acepto: mientras es una propuesta, todavia puede rechazarla y
-- no tiene por que quedarse con el domicilio del paciente. El telefono y el
-- correo del cliente no salen nunca (regla 10.8): la coordinacion pasa por la
-- agencia.
-- ----------------------------------------------------------------------------
create or replace function public.panel_enfermero_proximos(p_limite int default 5)
returns table (
  id                uuid,
  folio_solicitud   text,
  fecha             date,
  turno             turno_tipo,
  hora_inicio       time,
  hora_fin          time,
  estatus           estatus_asignacion,
  tarifa_enfermero  numeric,
  tipo_servicio     tipo_servicio,
  entorno           text,
  municipio         text,
  direccion         text,
  nivel_atencion    text,
  procedimientos    text[],
  descripcion       text,
  horas_esperando   int
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid := public.mi_ficha_enfermero();
begin
  return query
  select a.id,
         s.folio,
         a.fecha,
         a.turno,
         a.hora_inicio,
         a.hora_fin,
         a.estatus,
         a.tarifa_enfermero,
         s.tipo_servicio,
         s.entorno::text,
         s.municipio,
         case when a.estatus in ('aceptada', 'en_curso')
              then s.direccion_servicio end,
         s.nivel_atencion::text,
         s.procedimientos,
         s.descripcion_paciente,
         (extract(epoch from (now() - a.created_at)) / 3600)::int
  from public.asignaciones a
  join public.solicitudes s on s.id = a.solicitud_id
  where a.enfermero_id = v_id
    and a.estatus in ('propuesta', 'aceptada', 'en_curso')
    and a.fecha >= current_date - 1        -- un turno de anoche sigue vigente
  -- Primero lo que espera respuesta, luego lo mas cercano en el tiempo
  order by (a.estatus = 'propuesta') desc, a.fecha, a.hora_inicio
  limit greatest(p_limite, 1);
end;
$$;

comment on function public.panel_enfermero_proximos(int) is
  'Turnos propuestos, aceptados o en curso del enfermero en sesion. La direccion solo aparece una vez aceptado el turno.';

-- ----------------------------------------------------------------------------
-- Permisos: solo con sesion iniciada. Dentro, cada funcion exige que quien
-- llama tenga ficha propia.
-- ----------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'mi_ficha_enfermero()',
    'panel_enfermero_resumen()', 'panel_enfermero_alertas()',
    'panel_enfermero_proximos(int)'
  ] loop
    execute format('revoke all on function public.%s from public', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- El ayudante no se expone a nadie: solo lo invocan las funciones de arriba,
-- que corren como propietario y ya comprobaron de quien son los datos.
revoke all on function public.perfil_completo_pct(uuid) from public;

-- ============================================================================
-- MIS TURNOS, HISTORIAL, DOCUMENTOS, DISPONIBILIDAD Y GANANCIAS
--
-- Mismo criterio que arriba: nada recibe un id de enfermero, todo cuelga de
-- mi_ficha_enfermero(). Y todo lo que toca `solicitudes` pasa por aqui, porque
-- la policy de esa tabla solo le abre las solicitudes de turnos YA aceptados:
-- para una propuesta, estas funciones son la unica forma de ver el turno, y
-- devuelven solo columnas seguras.
-- ============================================================================

drop function if exists public.panel_enfermero_turnos(text, int);
drop function if exists public.responder_propuesta(uuid, boolean, text);
drop function if exists public.registrar_mi_asistencia(uuid, text);
drop function if exists public.mis_documentos();
drop function if exists public.subir_mi_documento(tipo_documento, text, date, date);
drop function if exists public.mis_ganancias(date, date);
drop function if exists public.aplicar_plantilla_disponibilidad(date, date, int[], turno_tipo[], boolean);

-- ----------------------------------------------------------------------------
-- Lista de turnos, para "Mis turnos" y para "Historial"
--
-- p_grupo: 'activos'   -> lo que sigue vivo: propuesta, aceptada, en curso
--          'historial' -> lo cerrado: completada, rechazada, no asistio, cancelada
--          'todos'
-- ----------------------------------------------------------------------------
create or replace function public.panel_enfermero_turnos(
  p_grupo  text default 'activos',
  p_limite int  default 100
)
returns table (
  id                uuid,
  folio_solicitud   text,
  fecha             date,
  turno             turno_tipo,
  hora_inicio       time,
  hora_fin          time,
  estatus           estatus_asignacion,
  tarifa_enfermero  numeric,
  tipo_servicio     tipo_servicio,
  entorno           text,
  municipio         text,
  direccion         text,
  nivel_atencion    text,
  procedimientos    text[],
  descripcion       text,
  checkin_at        timestamptz,
  checkout_at       timestamptz,
  motivo_rechazo    text,
  calificacion      int,
  creado_at         timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid := public.mi_ficha_enfermero();
begin
  return query
  select a.id,
         s.folio,
         a.fecha,
         a.turno,
         a.hora_inicio,
         a.hora_fin,
         a.estatus,
         a.tarifa_enfermero,
         s.tipo_servicio,
         s.entorno::text,
         s.municipio,
         -- El domicilio solo despues de aceptar (regla 10.8)
         case when a.estatus in ('aceptada', 'en_curso', 'completada')
              then s.direccion_servicio end,
         s.nivel_atencion::text,
         s.procedimientos,
         s.descripcion_paciente,
         a.checkin_at,
         a.checkout_at,
         a.motivo_rechazo,
         (select e.calificacion_general from public.evaluaciones e
          where e.asignacion_id = a.id limit 1),
         a.created_at
  from public.asignaciones a
  join public.solicitudes s on s.id = a.solicitud_id
  where a.enfermero_id = v_id
    and case p_grupo
          when 'activos'   then a.estatus in ('propuesta', 'aceptada', 'en_curso')
          when 'historial' then a.estatus in ('completada', 'rechazada', 'no_asistio', 'cancelada')
          else true
        end
  -- En lo activo urge primero lo que espera respuesta; en lo cerrado, lo reciente
  order by case when p_grupo = 'historial' then null
                else (a.estatus = 'propuesta') end desc nulls last,
           case when p_grupo = 'historial' then a.fecha end desc,
           case when p_grupo <> 'historial' then a.fecha end asc,
           a.hora_inicio
  limit greatest(p_limite, 1);
end;
$$;

-- ----------------------------------------------------------------------------
-- Aceptar o rechazar una propuesta
--
-- Las transiciones validas ya las impone proteger_campos_asignacion; aqui se
-- comprueba ademas que el turno sea suyo y se exige motivo al rechazar, para
-- que la agencia sepa por que se cayo y pueda reasignar con criterio.
-- ----------------------------------------------------------------------------
create or replace function public.responder_propuesta(
  p_asignacion uuid,
  p_acepta     boolean,
  p_motivo     text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id  uuid := public.mi_ficha_enfermero();
  a     public.asignaciones%rowtype;
begin
  select * into a from public.asignaciones
  where id = p_asignacion and enfermero_id = v_id;

  if not found then
    raise exception 'Ese turno no existe o no es tuyo' using errcode = '42501';
  end if;

  if a.estatus <> 'propuesta' then
    raise exception 'Este turno ya no está esperando respuesta (está %)', a.estatus
      using errcode = 'P0001';
  end if;

  if not p_acepta and coalesce(trim(p_motivo), '') = '' then
    raise exception 'Dinos por qué lo rechazas' using errcode = 'P0001';
  end if;

  -- Aceptar un turno que se encima con otro ya aceptado no lo bloquea el
  -- validador de traslapes, porque este no inserta: valida a mano.
  if p_acepta and exists (
    select 1 from public.asignaciones o
    where o.enfermero_id = v_id
      and o.id <> a.id
      and o.fecha = a.fecha
      and o.estatus in ('aceptada', 'en_curso')
      and (a.hora_inicio, a.hora_fin) overlaps (o.hora_inicio, o.hora_fin)
  ) then
    raise exception 'Ya tienes otro turno aceptado que se encima con este'
      using errcode = 'P0001';
  end if;

  update public.asignaciones
  set estatus        = (case when p_acepta then 'aceptada' else 'rechazada' end)::estatus_asignacion,
      motivo_rechazo = case when p_acepta then null else trim(p_motivo) end
  where id = p_asignacion;

  return jsonb_build_object(
    'ok', true,
    'estatus', case when p_acepta then 'aceptada' else 'rechazada' end,
    'mensaje', case when p_acepta
                    then 'Turno aceptado. Te esperamos.'
                    else 'Turno rechazado. Gracias por avisar a tiempo.' end
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Marcar entrada y salida del turno
-- Sin salida registrada el turno no entra al corte de pago, asi que el mensaje
-- lo dice explicitamente.
--
-- Lleva "mi" en el nombre a proposito: `registrar_asistencia()` ya existe en
-- 09-operacion.sql y es la del admin. Como este archivo corre despues, un
-- nombre igual la habria sobreescrito y roto el registro de asistencia del
-- panel de la agencia.
-- ----------------------------------------------------------------------------
create or replace function public.registrar_mi_asistencia(
  p_asignacion uuid,
  p_tipo       text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := public.mi_ficha_enfermero();
  a    public.asignaciones%rowtype;
begin
  select * into a from public.asignaciones
  where id = p_asignacion and enfermero_id = v_id;

  if not found then
    raise exception 'Ese turno no existe o no es tuyo' using errcode = '42501';
  end if;

  if p_tipo = 'entrada' then
    if a.estatus <> 'aceptada' then
      raise exception 'Solo puedes marcar entrada en un turno aceptado'
        using errcode = 'P0001';
    end if;
    -- Un turno se abre el mismo dia, no con dias de anticipacion
    if a.fecha > current_date then
      raise exception 'Todavía no es el día de este turno' using errcode = 'P0001';
    end if;

    update public.asignaciones
    set estatus = 'en_curso', checkin_at = now()
    where id = p_asignacion;

    return jsonb_build_object('ok', true, 'estatus', 'en_curso',
      'mensaje', 'Entrada registrada. Buen turno.');

  elsif p_tipo = 'salida' then
    if a.estatus <> 'en_curso' then
      raise exception 'Este turno no está en curso' using errcode = 'P0001';
    end if;

    update public.asignaciones
    set estatus = 'completada', checkout_at = now()
    where id = p_asignacion;

    return jsonb_build_object('ok', true, 'estatus', 'completada',
      'mensaje', 'Salida registrada. El turno ya entra a tu próximo corte.');
  end if;

  raise exception 'Movimiento no reconocido' using errcode = 'P0001';
end;
$$;

-- ----------------------------------------------------------------------------
-- Mi expediente documental
-- Devuelve tanto lo entregado como los huecos: un obligatorio que falta se
-- lista igual, con id nulo, para que la pantalla lo pinte como pendiente de
-- subir en vez de simplemente no mencionarlo.
-- ----------------------------------------------------------------------------
create or replace function public.mis_documentos()
returns table (
  id                uuid,
  tipo              tipo_documento,
  archivo_url       text,
  fecha_emision     date,
  fecha_vencimiento date,
  estatus           estatus_verif,
  motivo_rechazo    text,
  obligatorio       boolean,
  dias_para_vencer  int
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id         uuid := public.mi_ficha_enfermero();
  obligatorios tipo_documento[];
  v_nivel      nivel_enfermeria;
begin
  select e.nivel into v_nivel from public.enfermeros e where e.id = v_id;
  obligatorios := public.documentos_obligatorios(v_nivel);

  return query
  select d.id, d.tipo, d.archivo_url, d.fecha_emision, d.fecha_vencimiento,
         d.estatus, d.motivo_rechazo,
         d.tipo = any(obligatorios),
         case when d.fecha_vencimiento is null then null
              else (d.fecha_vencimiento - current_date)::int end
  from public.documentos d
  where d.enfermero_id = v_id

  union all

  -- Los obligatorios que aun no entrega
  select null::uuid, t, null, null, null, null::estatus_verif, null, true, null
  from unnest(obligatorios) t
  where not exists (
    select 1 from public.documentos d2
    where d2.enfermero_id = v_id and d2.tipo = t and d2.estatus <> 'rechazado'
  )

  order by 8 desc, 6 nulls first, 2;
end;
$$;

-- ----------------------------------------------------------------------------
-- Registrar o renovar un documento
--
-- Va por funcion y no por INSERT directo por una razon concreta: al renovar
-- hay que devolver el estatus a 'pendiente' para que la agencia lo revise otra
-- vez, y el trigger proteger_campos_documento le prohibe al enfermero tocar
-- ese campo. Adentro de un security definer el trigger si deja pasar el
-- cambio, porque current_user es el propietario.
--
-- El archivo ya debe estar en Storage bajo `<enfermero_id>/...`; la policy del
-- bucket lo exige y aqui se vuelve a comprobar.
-- ----------------------------------------------------------------------------
create or replace function public.subir_mi_documento(
  p_tipo        tipo_documento,
  p_archivo_url text,
  p_emision     date default null,
  p_vencimiento date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id      uuid := public.mi_ficha_enfermero();
  v_previo  uuid;
  v_renueva boolean;
begin
  if coalesce(trim(p_archivo_url), '') = '' then
    raise exception 'Falta el archivo' using errcode = 'P0001';
  end if;

  -- El archivo tiene que vivir en su propia carpeta: si no, estaria
  -- registrando a su nombre un archivo de alguien mas.
  if split_part(replace(p_archivo_url, 'documentos/', ''), '/', 1) <> v_id::text then
    raise exception 'El archivo no corresponde a tu expediente' using errcode = '42501';
  end if;

  if p_vencimiento is not null and p_vencimiento < current_date then
    raise exception 'Ese documento ya está vencido: sube uno vigente'
      using errcode = 'P0001';
  end if;

  select d.id into v_previo from public.documentos d
  where d.enfermero_id = v_id and d.tipo = p_tipo and d.estatus <> 'rechazado'
  limit 1;

  v_renueva := v_previo is not null;

  if v_renueva then
    update public.documentos
    set archivo_url       = p_archivo_url,
        fecha_emision     = p_emision,
        fecha_vencimiento = p_vencimiento,
        estatus           = 'pendiente',
        verificado_por    = null,
        verificado_at     = null,
        motivo_rechazo    = null
    where id = v_previo;
  else
    insert into public.documentos (enfermero_id, tipo, archivo_url,
                                   fecha_emision, fecha_vencimiento, estatus)
    values (v_id, p_tipo, p_archivo_url, p_emision, p_vencimiento, 'pendiente');
  end if;

  return jsonb_build_object(
    'ok', true,
    'renovado', v_renueva,
    'mensaje', case when v_renueva
                    then 'Documento actualizado. Lo revisamos en 24 a 48 horas.'
                    else 'Documento recibido. Lo revisamos en 24 a 48 horas.' end
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Plantilla semanal de disponibilidad
--
-- Marcar dia por dia en el celular es inviable; casi todo el mundo trabaja con
-- un patron fijo. p_dias usa la convencion de Postgres: 0 domingo, 6 sabado.
-- ----------------------------------------------------------------------------
create or replace function public.aplicar_plantilla_disponibilidad(
  p_desde      date,
  p_hasta      date,
  p_dias       int[],
  p_turnos     turno_tipo[],
  p_disponible boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id    uuid := public.mi_ficha_enfermero();
  v_filas int  := 0;
begin
  if p_hasta < p_desde then
    raise exception 'El rango de fechas está al revés' using errcode = 'P0001';
  end if;
  if p_hasta > current_date + 180 then
    raise exception 'Solo puedes programar hasta 6 meses hacia adelante'
      using errcode = 'P0001';
  end if;
  if coalesce(array_length(p_dias, 1), 0) = 0
     or coalesce(array_length(p_turnos, 1), 0) = 0 then
    raise exception 'Elige al menos un día y un turno' using errcode = 'P0001';
  end if;

  with fechas as (
    select d::date as fecha
    from generate_series(greatest(p_desde, current_date), p_hasta, '1 day') d
    where extract(dow from d)::int = any(p_dias)
  ),
  guardadas as (
    insert into public.disponibilidad (enfermero_id, fecha, turno, disponible)
    select v_id, f.fecha, t, p_disponible
    from fechas f cross join unnest(p_turnos) t
    on conflict (enfermero_id, fecha, turno)
      do update set disponible = excluded.disponible
    returning 1
  )
  select count(*) into v_filas from guardadas;

  return jsonb_build_object('ok', true, 'turnos', v_filas,
    'mensaje', v_filas || ' turnos actualizados.');
end;
$$;

-- ----------------------------------------------------------------------------
-- Ganancias por quincena
--
-- El corte de la agencia es quincenal, asi que el agregado tiene que estar en
-- la misma unidad o el profesional no puede cuadrar lo que recibe. Solo cuenta
-- turnos completados: lo aceptado todavia no se gano.
-- ----------------------------------------------------------------------------
create or replace function public.mis_ganancias(
  p_desde date default null,
  p_hasta date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id    uuid := public.mi_ficha_enfermero();
  v_desde date := coalesce(p_desde, (date_trunc('month', current_date) - interval '5 months')::date);
  v_hasta date := coalesce(p_hasta, current_date);
begin
  return jsonb_build_object(

    'total_periodo', (
      select coalesce(sum(tarifa_enfermero), 0) from public.asignaciones
      where enfermero_id = v_id and estatus = 'completada'
        and fecha between v_desde and v_hasta
    ),

    'turnos_periodo', (
      select count(*) from public.asignaciones
      where enfermero_id = v_id and estatus = 'completada'
        and fecha between v_desde and v_hasta
    ),

    'comprometido', (
      select coalesce(sum(tarifa_enfermero), 0) from public.asignaciones
      where enfermero_id = v_id
        and estatus in ('aceptada', 'en_curso') and fecha >= current_date
    ),

    'promedio_turno', (
      select coalesce(round(avg(tarifa_enfermero), 2), 0) from public.asignaciones
      where enfermero_id = v_id and estatus = 'completada'
        and fecha between v_desde and v_hasta
    ),

    -- Se devuelven los limites reales de la quincena y en que mitad cae, no un
    -- texto ya armado: to_char('TMMonth') depende del lc_time del servidor y
    -- en esta base sale en ingles. La etiqueta la arma el navegador con
    -- Intl y siempre en es-MX.
    'quincenas', coalesce((
      select jsonb_agg(q order by q->>'inicio' desc)
      from (
        select jsonb_build_object(
                 'inicio', (date_trunc('month', a.fecha)
                            + case when extract(day from a.fecha) <= 15
                                   then interval '0 day' else interval '15 days' end)::date,
                 'fin',    case when extract(day from a.fecha) <= 15
                                then (date_trunc('month', a.fecha) + interval '14 days')::date
                                else (date_trunc('month', a.fecha) + interval '1 month'
                                      - interval '1 day')::date end,
                 'mitad',  case when extract(day from a.fecha) <= 15 then 1 else 2 end,
                 'turnos', count(*),
                 'monto',  sum(a.tarifa_enfermero)
               ) as q
        from public.asignaciones a
        where a.enfermero_id = v_id and a.estatus = 'completada'
          and a.fecha between v_desde and v_hasta
        group by date_trunc('month', a.fecha),
                 (extract(day from a.fecha) <= 15)
      ) t
    ), '[]'::jsonb)
  );
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'panel_enfermero_turnos(text, int)',
    'responder_propuesta(uuid, boolean, text)',
    'registrar_mi_asistencia(uuid, text)',
    'mis_documentos()',
    'subir_mi_documento(tipo_documento, text, date, date)',
    'aplicar_plantilla_disponibilidad(date, date, int[], turno_tipo[], boolean)',
    'mis_ganancias(date, date)'
  ] loop
    execute format('revoke all on function public.%s from public', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ============================================================================
-- PANEL DEL CLIENTE (CLAUDE.md 8.8)
--
-- Mismo criterio invertido que arriba, pero contra `clientes`: todo cuelga de
-- mi_ficha_cliente() y ninguna funcion recibe el id de a quien consultar.
--
-- REGLA QUE MANDA EN TODO ESTE BLOQUE (regla 10.8 y CLAUDE.md 6):
-- al cliente se le muestra QUIEN va a cubrir su turno, nunca COMO contactarlo.
-- De `enfermeros` solo salen nombre, folio, nivel, foto, calificacion,
-- experiencia y especialidades. Cedula completa, tarifas y notas internas no
-- se seleccionan aqui ni por descuido, y el telefono ni siquiera vive en esa
-- tabla. Si el cliente puede llamarle directo al profesional, la agencia se
-- queda sin comision y el negocio deja de existir.
-- ============================================================================

drop function if exists public.panel_cliente_resumen();
drop function if exists public.panel_cliente_solicitudes(text, int);
drop function if exists public.panel_cliente_solicitud_detalle(uuid);
drop function if exists public.panel_cliente_personal();
drop function if exists public.panel_cliente_evaluables();
drop function if exists public.guardar_evaluacion(uuid, int, int, int, text, boolean);
drop function if exists public.panel_cliente_facturacion();

-- ----------------------------------------------------------------------------
-- Ficha del cliente en sesion, o error si quien llama no tiene una
-- ----------------------------------------------------------------------------
create or replace function public.mi_ficha_cliente()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid := public.mi_cliente_id();
begin
  if v_id is null then
    raise exception 'Esta sección es solo para clientes registrados'
      using errcode = '42501';
  end if;
  return v_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- Indicadores de la pantalla de inicio
-- ----------------------------------------------------------------------------
create or replace function public.panel_cliente_resumen()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id       uuid := public.mi_ficha_cliente();
  inicio_mes date := date_trunc('month', current_date)::date;
  c          public.clientes%rowtype;
begin
  select * into c from public.clientes where id = v_id;

  return jsonb_build_object(
    'razon_social', coalesce(c.razon_social, c.nombre_contacto),
    'tipo',         c.tipo,

    'solicitudes_activas', (
      select count(*) from public.solicitudes
      where cliente_id = v_id
        and estatus in ('nueva', 'en_busqueda', 'propuesta_enviada', 'confirmada', 'en_curso')
    ),

    'turnos_programados', (
      select count(*) from public.asignaciones a
      join public.solicitudes s on s.id = a.solicitud_id
      where s.cliente_id = v_id
        and a.estatus in ('aceptada', 'en_curso')
        and a.fecha >= current_date
    ),

    'turno_en_curso', (
      select count(*) from public.asignaciones a
      join public.solicitudes s on s.id = a.solicitud_id
      where s.cliente_id = v_id and a.estatus = 'en_curso'
    ),

    -- Cuanta gente distinta ha pasado por sus turnos: mide continuidad, que
    -- para un paciente importa tanto como la cobertura
    'personal_distinto', (
      select count(distinct a.enfermero_id) from public.asignaciones a
      join public.solicitudes s on s.id = a.solicitud_id
      where s.cliente_id = v_id and a.estatus in ('completada', 'en_curso', 'aceptada')
    ),

    -- Es tarifa_cliente: lo que le facturamos. El reparto con el profesional
    -- no es asunto suyo.
    'gasto_mes', (
      select coalesce(sum(a.tarifa_cliente), 0) from public.asignaciones a
      join public.solicitudes s on s.id = a.solicitud_id
      where s.cliente_id = v_id and a.estatus = 'completada' and a.fecha >= inicio_mes
    ),

    'por_pagar', (
      select coalesce(sum(p.monto), 0) from public.pagos p
      join public.solicitudes s on s.id = p.referencia_id
      where s.cliente_id = v_id and p.tipo = 'cobro_cliente'
        and p.estatus in ('pendiente', 'parcial', 'vencido')
    ),

    'pagos_vencidos', (
      select count(*) from public.pagos p
      join public.solicitudes s on s.id = p.referencia_id
      where s.cliente_id = v_id and p.tipo = 'cobro_cliente' and p.estatus = 'vencido'
    ),

    -- La evaluacion expira a los 15 dias (regla 10.7)
    'por_evaluar', (
      select count(*) from public.asignaciones a
      join public.solicitudes s on s.id = a.solicitud_id
      where s.cliente_id = v_id
        and a.estatus = 'completada'
        and a.fecha >= current_date - 15
        and not exists (select 1 from public.evaluaciones e where e.asignacion_id = a.id)
    ),

    'solicitudes_sin_cubrir', (
      select count(*) from public.solicitudes
      where cliente_id = v_id
        and estatus in ('nueva', 'en_busqueda')
        and created_at < now() - interval '24 hours'
    )
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Sus solicitudes, con cuanto se ha cubierto de cada una
-- ----------------------------------------------------------------------------
create or replace function public.panel_cliente_solicitudes(
  p_grupo  text default 'activas',
  p_limite int  default 100
)
returns table (
  id              uuid,
  folio           text,
  tipo_servicio   tipo_servicio,
  nivel_requerido nivel_enfermeria,
  nivel_atencion  text,
  entorno         text,
  municipio       text,
  fecha_inicio    date,
  fecha_fin       date,
  turno           turno_tipo,
  cantidad        int,
  estatus         estatus_solicitud,
  urgente         boolean,
  cotizada        boolean,
  turnos_totales  int,
  turnos_cubiertos int,
  creada_at       timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid := public.mi_ficha_cliente();
begin
  return query
  select s.id, s.folio, s.tipo_servicio, s.nivel_requerido,
         s.nivel_atencion::text, s.entorno::text, s.municipio,
         s.fecha_inicio, s.fecha_fin, s.turno, s.cantidad_enfermeros,
         s.estatus, s.urgente,
         -- Al cliente se le dice SI ya se cotizo, no cuanto: el monto lo ve
         -- en su factura, no en el seguimiento
         s.tarifa_ofrecida_cliente is not null,
         (select count(*)::int from public.asignaciones a
          where a.solicitud_id = s.id and a.estatus <> 'rechazada'),
         (select count(*)::int from public.asignaciones a
          where a.solicitud_id = s.id
            and a.estatus in ('aceptada', 'en_curso', 'completada')),
         s.created_at
  from public.solicitudes s
  where s.cliente_id = v_id
    and case p_grupo
          when 'activas'   then s.estatus in ('nueva','en_busqueda','propuesta_enviada','confirmada','en_curso')
          when 'historial' then s.estatus in ('completada','cancelada')
          else true
        end
  order by s.urgente desc, s.created_at desc
  limit greatest(p_limite, 1);
end;
$$;

-- ----------------------------------------------------------------------------
-- Detalle de una solicitud: linea de tiempo y quien la esta cubriendo
-- ----------------------------------------------------------------------------
create or replace function public.panel_cliente_solicitud_detalle(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id  uuid := public.mi_ficha_cliente();
  s     public.solicitudes%rowtype;
  pasos jsonb;
  orden int;
begin
  select * into s from public.solicitudes where id = p_id and cliente_id = v_id;
  if not found then
    raise exception 'Esa solicitud no existe o no es tuya' using errcode = '42501';
  end if;

  -- Posicion del estatus actual dentro del recorrido normal. Una cancelada
  -- queda en -1 y la interfaz la pinta aparte.
  orden := case s.estatus
             when 'nueva' then 0 when 'en_busqueda' then 1
             when 'propuesta_enviada' then 2 when 'confirmada' then 3
             when 'en_curso' then 4 when 'completada' then 5
             else -1 end;

  pasos := (
    select jsonb_agg(jsonb_build_object(
             'titulo', p.titulo, 'detalle', p.detalle,
             'hecho',  orden >= p.pos, 'actual', orden = p.pos)
           order by p.pos)
    from (values
      (0, 'Recibimos tu solicitud',  'Ya tiene folio y está en nuestra bandeja.'),
      (1, 'Buscando personal',       'Cruzamos tu necesidad con el personal verificado disponible.'),
      (2, 'Te enviamos una propuesta','Revisamos disponibilidad y te compartimos los perfiles.'),
      (3, 'Servicio confirmado',     'El personal aceptó y los turnos quedaron agendados.'),
      (4, 'Servicio en curso',       'El personal está cubriendo los turnos.'),
      (5, 'Servicio completado',     'Terminó el periodo contratado.')
    ) as p(pos, titulo, detalle)
  );

  return jsonb_build_object(
    'id',    s.id,
    'folio', s.folio,
    'estatus', s.estatus,
    'cancelada', s.estatus = 'cancelada',
    'tipo_servicio', s.tipo_servicio,
    'nivel_requerido', s.nivel_requerido,
    'nivel_atencion', s.nivel_atencion,
    'entorno', s.entorno,
    'tipo_paciente', s.tipo_paciente,
    'procedimientos', to_jsonb(coalesce(s.procedimientos, '{}')),
    'descripcion', s.descripcion_paciente,
    'municipio', s.municipio,
    'direccion', s.direccion_servicio,
    'fecha_inicio', s.fecha_inicio,
    'fecha_fin', s.fecha_fin,
    'turno', s.turno,
    'horas_por_turno', s.horas_por_turno,
    'cantidad', s.cantidad_enfermeros,
    'urgente', s.urgente,
    'creada_at', s.created_at,
    'pasos', pasos,

    -- Quien cubre el turno, SIN nada que permita contactarlo por fuera
    'personal', coalesce((
      select jsonb_agg(jsonb_build_object(
               'asignacion_id', a.id,
               'fecha', a.fecha,
               'turno', a.turno,
               'hora_inicio', a.hora_inicio,
               'hora_fin', a.hora_fin,
               'estatus', a.estatus,
               'enfermero_id', e.id,
               'nombre', e.nombre_completo,
               'folio', e.folio,
               'nivel', e.nivel,
               'foto_url', e.foto_url,
               'calificacion', e.calificacion_promedio,
               'anios_experiencia', e.anios_experiencia,
               'especialidades', to_jsonb(coalesce(e.especialidades, '{}')),
               'ya_evaluado', exists (
                 select 1 from public.evaluaciones ev where ev.asignacion_id = a.id)
             ) order by a.fecha)
      from public.asignaciones a
      join public.enfermeros e on e.id = a.enfermero_id
      where a.solicitud_id = s.id
        -- Las propuestas todavia no son de su incumbencia: si el profesional
        -- la rechaza, el cliente nunca deberia haber sabido su nombre
        and a.estatus in ('aceptada', 'en_curso', 'completada', 'no_asistio')
    ), '[]'::jsonb)
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Personal que ha trabajado con este cliente
-- Sirve para "solicitar de nuevo a esta persona" (CLAUDE.md 8.8)
-- ----------------------------------------------------------------------------
create or replace function public.panel_cliente_personal()
returns table (
  enfermero_id      uuid,
  folio             text,
  nombre            text,
  nivel             nivel_enfermeria,
  foto_url          text,
  calificacion      numeric,
  anios_experiencia int,
  especialidades    text[],
  turnos_contigo    int,
  ultimo_turno      date,
  activo_ahora      boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid := public.mi_ficha_cliente();
begin
  return query
  select e.id, e.folio, e.nombre_completo, e.nivel, e.foto_url,
         e.calificacion_promedio, e.anios_experiencia, e.especialidades,
         count(*)::int,
         max(a.fecha),
         bool_or(a.estatus in ('aceptada', 'en_curso') and a.fecha >= current_date)
  from public.asignaciones a
  join public.solicitudes s on s.id = a.solicitud_id
  join public.enfermeros  e on e.id = a.enfermero_id
  where s.cliente_id = v_id
    and a.estatus in ('completada', 'en_curso', 'aceptada')
  group by e.id, e.folio, e.nombre_completo, e.nivel, e.foto_url,
           e.calificacion_promedio, e.anios_experiencia, e.especialidades
  order by bool_or(a.estatus in ('aceptada','en_curso') and a.fecha >= current_date) desc,
           max(a.fecha) desc;
end;
$$;

-- ----------------------------------------------------------------------------
-- Turnos que puede evaluar
-- Solo completados y dentro de 15 dias (regla 10.7). Se devuelven tambien los
-- que ya vencieron, marcados, para que no parezca que se perdieron.
-- ----------------------------------------------------------------------------
create or replace function public.panel_cliente_evaluables()
returns table (
  asignacion_id uuid,
  fecha         date,
  turno         turno_tipo,
  folio         text,
  enfermero_id  uuid,
  nombre        text,
  nivel         nivel_enfermeria,
  foto_url      text,
  dias_restantes int,
  vencida       boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid := public.mi_ficha_cliente();
begin
  return query
  select a.id, a.fecha, a.turno, s.folio,
         e.id, e.nombre_completo, e.nivel, e.foto_url,
         (15 - (current_date - a.fecha))::int,
         (current_date - a.fecha) > 15
  from public.asignaciones a
  join public.solicitudes s on s.id = a.solicitud_id
  join public.enfermeros  e on e.id = a.enfermero_id
  where s.cliente_id = v_id
    and a.estatus = 'completada'
    and a.fecha >= current_date - 30
    and not exists (select 1 from public.evaluaciones ev where ev.asignacion_id = a.id)
  order by a.fecha desc;
end;
$$;

-- ----------------------------------------------------------------------------
-- Guardar una evaluacion
--
-- La policy evaluaciones_cliente_crea ya exige turno completado, suyo y dentro
-- de 15 dias. Aqui se repiten las comprobaciones para poder devolver un mensaje
-- que se entienda, en vez del "permission denied" pelado de PostgREST.
-- ----------------------------------------------------------------------------
create or replace function public.guardar_evaluacion(
  p_asignacion  uuid,
  p_puntualidad int,
  p_trato       int,
  p_competencia int,
  p_comentario  text default null,
  p_publica     boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id   uuid := public.mi_ficha_cliente();
  a      public.asignaciones%rowtype;
  v_gral numeric;
begin
  select a2.* into a
  from public.asignaciones a2
  join public.solicitudes s on s.id = a2.solicitud_id
  where a2.id = p_asignacion and s.cliente_id = v_id;

  if not found then
    raise exception 'Ese turno no existe o no es de un servicio tuyo'
      using errcode = '42501';
  end if;

  if a.estatus <> 'completada' then
    raise exception 'Solo puedes evaluar un turno que ya terminó' using errcode = 'P0001';
  end if;

  if current_date - a.fecha > 15 then
    raise exception 'El plazo para evaluar este turno venció (son 15 días)'
      using errcode = 'P0001';
  end if;

  if exists (select 1 from public.evaluaciones e where e.asignacion_id = p_asignacion) then
    raise exception 'Este turno ya lo evaluaste' using errcode = 'P0001';
  end if;

  if p_puntualidad not between 1 and 5
     or p_trato not between 1 and 5
     or p_competencia not between 1 and 5 then
    raise exception 'Las calificaciones van de 1 a 5' using errcode = 'P0001';
  end if;

  -- La general es el promedio de los tres criterios: pedirla por separado
  -- invita a contradecirse consigo mismo
  v_gral := round((p_puntualidad + p_trato + p_competencia)::numeric / 3);

  insert into public.evaluaciones (asignacion_id, cliente_id, enfermero_id,
                                   puntualidad, trato, competencia_tecnica,
                                   calificacion_general, comentario, publica)
  values (p_asignacion, v_id, a.enfermero_id,
          p_puntualidad, p_trato, p_competencia,
          v_gral::int, nullif(trim(coalesce(p_comentario, '')), ''), p_publica);

  return jsonb_build_object('ok', true, 'calificacion', v_gral,
    'mensaje', 'Gracias. Tu evaluación nos ayuda a mejorar el servicio.');
end;
$$;

-- ----------------------------------------------------------------------------
-- Facturacion: lo cobrado y lo pendiente
-- ----------------------------------------------------------------------------
create or replace function public.panel_cliente_facturacion()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid := public.mi_ficha_cliente();
begin
  return jsonb_build_object(

    'total_pagado', (
      select coalesce(sum(p.monto), 0) from public.pagos p
      join public.solicitudes s on s.id = p.referencia_id
      where s.cliente_id = v_id and p.tipo = 'cobro_cliente' and p.estatus = 'pagado'
    ),

    'total_pendiente', (
      select coalesce(sum(p.monto), 0) from public.pagos p
      join public.solicitudes s on s.id = p.referencia_id
      where s.cliente_id = v_id and p.tipo = 'cobro_cliente'
        and p.estatus in ('pendiente', 'parcial', 'vencido')
    ),

    'cobros', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p.id,
               'folio', s.folio,
               'periodo_inicio', p.periodo_inicio,
               'periodo_fin', p.periodo_fin,
               'monto', p.monto,
               'metodo', p.metodo,
               'estatus', p.estatus,
               'fecha_pago', p.fecha_pago,
               'comprobante_url', p.comprobante_url,
               'notas', p.notas,
               'turnos', (
                 select count(*) from public.asignaciones a
                 where a.solicitud_id = s.id and a.estatus = 'completada'
                   and a.fecha between p.periodo_inicio and p.periodo_fin)
             ) order by p.periodo_inicio desc)
      from public.pagos p
      join public.solicitudes s on s.id = p.referencia_id
      where s.cliente_id = v_id and p.tipo = 'cobro_cliente'
    ), '[]'::jsonb)
  );
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'mi_ficha_cliente()', 'panel_cliente_resumen()',
    'panel_cliente_solicitudes(text, int)',
    'panel_cliente_solicitud_detalle(uuid)',
    'panel_cliente_personal()', 'panel_cliente_evaluables()',
    'guardar_evaluacion(uuid, int, int, int, text, boolean)',
    'panel_cliente_facturacion()'
  ] loop
    execute format('revoke all on function public.%s from public', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ############################################################################
-- ###  05-seed.sql
-- ############################################################################

-- ============================================================================
-- Enlace Enfermero — 05. Datos de prueba (Fase 1)
--
-- 12 perfiles ficticios para poblar el catalogo publico mientras se levanta la
-- operacion real. Los nombres, cedulas y datos son inventados.
--
-- NO ejecutar en produccion con clientes reales. Para revertir:
--   delete from public.enfermeros where folio like 'EE-%' and notas_internas = 'SEED';
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ENFERMEROS
-- Sin foto_url: la tarjeta muestra las iniciales sobre el anillo azul.
-- Las tarifas son NETAS al enfermero y nunca se exponen al publico.
-- ----------------------------------------------------------------------------
insert into public.enfermeros (
  nombre_completo, nivel, cedula_profesional, cedula_verificada, institucion_egreso,
  anios_experiencia, especialidades, certificaciones, idiomas, bio, zonas_cobertura,
  disponible_inmediato, acepta_domicilio, acepta_nocturno, acepta_foraneo,
  tarifa_hora, tarifa_turno_8, tarifa_turno_12, tarifa_turno_24,
  estatus_verificacion, publicado, notas_internas
) values

('María Fernanda Ruiz Delgado', 'especialista', '10482375', true, 'Universidad de Guadalajara',
 12, '{uci,urgencias}', '{bls,acls,via_aerea,ventilacion}', '{espanol,ingles}',
 'Especialista en cuidados intensivos con doce años en unidades de tercer nivel. Manejo de ventilación mecánica, monitoreo hemodinámico y atención de paciente crítico. Acostumbrada a trabajar bajo presión y a coordinarme con el equipo médico tratante.',
 '{guadalajara,zapopan,tlaquepaque}', true, true, true, false,
 175, 1400, 1950, 3100, 'verificado', true, 'SEED'),

('Jorge Alberto Medina Vargas', 'licenciado', '11738294', true, 'Universidad Autónoma de Guadalajara',
 9, '{urgencias,cardiologia,medicina_interna}', '{bls,acls,medicamentos_iv}', '{espanol}',
 'Licenciado en enfermería con nueve años en servicio de urgencias. Experiencia en triage, estabilización de paciente cardiológico y manejo de accesos vasculares. Disponible para turnos nocturnos y cobertura de fines de semana.',
 '{guadalajara,tlaquepaque,tonala}', true, true, true, true,
 130, 1050, 1470, 2350, 'verificado', true, 'SEED'),

('Claudia Ivette Sandoval Ríos', 'especialista', '09847162', true, 'Universidad de Guadalajara',
 11, '{neonatologia,pediatria,materno_infantil}', '{bls,pals,nrp}', '{espanol,ingles}',
 'Especialista en neonatología con once años en cuneros y terapia intensiva neonatal. Certificada en reanimación neonatal. Acompaño a las familias en el cuidado del recién nacido con paciencia y comunicación clara.',
 '{zapopan,guadalajara}', false, true, true, false,
 180, 1450, 2030, 3200, 'verificado', true, 'SEED'),

('Ricardo Emmanuel Ponce Aguilar', 'general', '12904583', true, 'Universidad del Valle de México',
 6, '{medicina_interna,heridas,postoperatorio}', '{bls,heridas_avanzadas,cateteres}', '{espanol}',
 'Enfermero general con seis años de experiencia hospitalaria. Especializado en curación de heridas complejas, manejo de estomas y cuidado postoperatorio. Trabajo con protocolo y llevo registro puntual de la evolución del paciente.',
 '{guadalajara,tlaquepaque,el_salto}', true, true, false, false,
 110, 880, 1230, 1980, 'verificado', true, 'SEED'),

('Ana Lucía Gutiérrez Mora', 'licenciado', '10395827', true, 'Universidad de Guadalajara',
 8, '{geriatria,paliativos,rehabilitacion}', '{bls,medicamentos_iv,muestras}', '{espanol}',
 'Licenciada en enfermería enfocada en el adulto mayor. Ocho años acompañando pacientes en casa: control de medicamentos, movilización, prevención de caídas y cuidados paliativos. Creo en el trato digno y en mantener informada a la familia.',
 '{zapopan,guadalajara,tlajomulco}', true, true, false, false,
 125, 1000, 1400, 2250, 'verificado', true, 'SEED'),

('Diana Patricia Ochoa Reynoso', 'especialista', '08726194', true, 'Instituto Politécnico Nacional',
 14, '{quirofano,postoperatorio}', '{bls,acls,via_aerea}', '{espanol,ingles}',
 'Enfermera instrumentista con catorce años en quirófano. Experiencia en cirugía general, traumatología y laparoscopía. Conozco los protocolos de asepsia y el manejo de instrumental especializado.',
 '{guadalajara,zapopan}', false, false, true, true,
 185, 1480, 2070, 3300, 'verificado', true, 'SEED'),

('Luis Ángel Barajas Cortés', 'tecnico', null, false, 'CONALEP Jalisco',
 4, '{general,postoperatorio}', '{bls,muestras}', '{espanol}',
 'Técnico en enfermería con cuatro años de experiencia en hospitalización y recuperación postquirúrgica. Apoyo en signos vitales, higiene, movilización y toma de muestras. Puntual y con buena disposición para aprender.',
 '{tlaquepaque,tonala,guadalajara}', true, true, true, false,
 90, 720, 1010, 1620, 'verificado', true, 'SEED'),

('Verónica Alejandra Núñez Salas', 'licenciado', '11284736', true, 'Universidad de Guadalajara',
 10, '{oncologia,paliativos,medicina_interna}', '{bls,cateteres,medicamentos_iv}', '{espanol}',
 'Licenciada en enfermería con diez años en el área oncológica. Manejo de catéteres centrales, administración de quimioterapia bajo indicación médica y control de efectos adversos. Trato cercano con el paciente y su familia.',
 '{guadalajara,zapopan,tlaquepaque}', false, true, false, false,
 135, 1080, 1510, 2420, 'verificado', true, 'SEED'),

('José Antonio Ramírez Padilla', 'especialista', '09163847', true, 'Universidad de Guadalajara',
 13, '{nefrologia,medicina_interna}', '{bls,acls,cateteres}', '{espanol}',
 'Especialista en nefrología con trece años en unidades de hemodiálisis. Manejo de accesos vasculares, control de balance hídrico y seguimiento del paciente renal crónico. Experiencia en hemodiálisis domiciliaria.',
 '{guadalajara,tonala,el_salto,zapotlanejo}', true, true, true, true,
 170, 1360, 1900, 3050, 'verificado', true, 'SEED'),

('Gabriela Montserrat Estrada Lomelí', 'general', '12573948', true, 'Universidad Autónoma de Guadalajara',
 7, '{materno_infantil,pediatria,general}', '{bls,pals,muestras}', '{espanol}',
 'Enfermera general con siete años en atención materno-infantil. Apoyo en control prenatal, lactancia y cuidado del recién nacido en domicilio. Comunicación clara y paciente con las mamás primerizas.',
 '{zapopan,tlajomulco,guadalajara}', true, true, false, false,
 115, 920, 1290, 2060, 'verificado', true, 'SEED'),

('Fernando Iván Cárdenas Sepúlveda', 'auxiliar', null, false, 'Cruz Roja Mexicana',
 3, '{general,geriatria}', '{bls}', '{espanol}',
 'Auxiliar de enfermería con tres años de experiencia en asilos y cuidado domiciliario. Apoyo en higiene, alimentación asistida, movilización y acompañamiento. Responsable y con muy buena disposición.',
 '{tlaquepaque,tonala,el_salto,juanacatlan}', true, true, true, false,
 75, 600, 840, 1350, 'verificado', true, 'SEED'),

('Rosa Elena Villalobos Chávez', 'cuidador', null, false, 'Instituto de Formación en Cuidados',
 9, '{geriatria,paliativos}', '{bls}', '{espanol}',
 'Cuidadora de adulto mayor con nueve años de experiencia en domicilio. Especializada en pacientes con demencia y movilidad reducida. Manejo rutinas de estimulación, aseo y compañía. Referencias comprobables.',
 '{guadalajara,zapopan,tlajomulco,ixtlahuacan}', true, true, true, false,
 80, 640, 900, 1440, 'verificado', true, 'SEED');

-- ----------------------------------------------------------------------------
-- CLIENTES, SOLICITUD Y ASIGNACIONES
-- Necesarios para que las evaluaciones publicas de la landing tengan respaldo.
-- ----------------------------------------------------------------------------
insert into public.clientes (tipo, razon_social, nombre_contacto, municipio, notas)
values
  ('hospital',   'Hospital San Rafael',        'Lic. Norma Bañuelos',  'Guadalajara', 'SEED'),
  ('asilo',      'Casa de Retiro Los Robles',  'Sr. Enrique Padilla',  'Zapopan',     'SEED'),
  ('particular', null,                          'Familia Zermeño',      'Zapopan',     'SEED');

insert into public.solicitudes (cliente_id, tipo_servicio, nivel_requerido, fecha_inicio,
                                turno, horas_por_turno, municipio, tarifa_ofrecida_cliente,
                                estatus, origen)
select id, 'turno_hospitalario', 'especialista', current_date - 30, 'nocturno', 12,
       municipio, public.cobro_cliente(1950), 'completada', 'seed'
from public.clientes where notas = 'SEED';

-- Un turno completado por enfermero, con tres semanas de separacion para que
-- el validador de traslapes no los rechace.
insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus)
select s.id,
       e.id,
       current_date - (21 + row_number() over (order by e.nombre_completo))::int,
       'guardia_12', '07:00', '19:00',
       -- reparto 60/40: se factura al cliente lo necesario para que al
       -- enfermero le toque su tarifa neta (CLAUDE.md 15.2)
       public.cobro_cliente(e.tarifa_turno_12),
       e.tarifa_turno_12,
       'completada'
from public.enfermeros e
cross join lateral (select id from public.solicitudes where origen = 'seed' limit 1) s
where e.notas_internas = 'SEED';

-- ----------------------------------------------------------------------------
-- EVALUACIONES PUBLICAS — alimentan los testimonios de la landing
-- El trigger actualizar_calificacion_enfermero recalcula el promedio solo.
-- ----------------------------------------------------------------------------
insert into public.evaluaciones (asignacion_id, cliente_id, enfermero_id, puntualidad,
                                 trato, competencia_tecnica, calificacion_general,
                                 comentario, publica)
select a.id,
       (select id from public.clientes where notas = 'SEED' limit 1),
       a.enfermero_id, 5, 5, 5, 5,
       c.comentario, true
from public.asignaciones a
join public.enfermeros e on e.id = a.enfermero_id
join (values
  ('María Fernanda Ruiz Delgado',
   'Llegó puntual las tres noches y manejó al paciente en ventilación sin un solo contratiempo. El médico tratante quedó muy conforme. La volveremos a solicitar.'),
  ('Ana Lucía Gutiérrez Mora',
   'Cuidó a mi mamá durante seis semanas. Además de su trabajo, nos explicaba todo con mucha paciencia. La familia entera quedó agradecida.'),
  ('Diana Patricia Ochoa Reynoso',
   'Instrumentista de primer nivel. Se integró al equipo de quirófano desde el primer día y conocía perfectamente los protocolos.')
) as c(nombre, comentario) on c.nombre = e.nombre_completo;

-- ----------------------------------------------------------------------------
-- ESCAPARATE
-- Se fija el historial acumulado de cada perfil para que el catalogo no se vea
-- vacio. En operacion real estos dos campos los calcula el trigger.
-- ----------------------------------------------------------------------------
update public.enfermeros e
set calificacion_promedio = v.calificacion,
    total_servicios       = v.servicios
from (values
  ('María Fernanda Ruiz Delgado',        4.9, 87),
  ('Jorge Alberto Medina Vargas',        4.8, 64),
  ('Claudia Ivette Sandoval Ríos',       5.0, 71),
  ('Ricardo Emmanuel Ponce Aguilar',     4.7, 42),
  ('Ana Lucía Gutiérrez Mora',           4.9, 58),
  ('Diana Patricia Ochoa Reynoso',       4.8, 93),
  ('Luis Ángel Barajas Cortés',          4.6, 28),
  ('Verónica Alejandra Núñez Salas',     4.9, 66),
  ('José Antonio Ramírez Padilla',       4.7, 79),
  ('Gabriela Montserrat Estrada Lomelí', 4.8, 45),
  ('Fernando Iván Cárdenas Sepúlveda',   4.5, 19),
  ('Rosa Elena Villalobos Chávez',       4.9, 52)
) as v(nombre, calificacion, servicios)
where e.nombre_completo = v.nombre;

-- ----------------------------------------------------------------------------
-- DISPONIBILIDAD de los proximos 14 dias, para el panel lateral del perfil
-- ----------------------------------------------------------------------------
insert into public.disponibilidad (enfermero_id, fecha, turno, disponible)
select e.id, d.fecha, t.turno, true
from public.enfermeros e
cross join generate_series(current_date, current_date + 13, interval '1 day') as d(fecha)
cross join (values ('matutino'::turno_tipo), ('vespertino'), ('nocturno')) as t(turno)
where e.notas_internas = 'SEED'
  -- patron variado por perfil para que el calendario no se vea uniforme
  and (extract(day from d.fecha)::int + length(e.nombre_completo)) % 3 <> 0
  and (t.turno <> 'nocturno' or e.acepta_nocturno)
on conflict (enfermero_id, fecha, turno) do nothing;

-- ============================================================================
-- OPERACION RECIENTE
-- Da contenido al panel de la agencia: solicitudes en varios estatus, turnos
-- de este mes, documentos por vencer y perfiles esperando verificacion.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Dos candidatos esperando verificacion (alimenta la alerta correspondiente)
-- ----------------------------------------------------------------------------
insert into public.enfermeros (nombre_completo, nivel, anios_experiencia, especialidades,
                               zonas_cobertura, estatus_verificacion, publicado, notas_internas)
values
  ('Alejandra Sáenz Mendoza', 'licenciado', 6, '{geriatria,paliativos}',
   '{guadalajara,zapopan}', 'pendiente', false, 'SEED'),
  ('Óscar Iván Trejo Lara', 'tecnico', 3, '{general}',
   '{tlaquepaque,tonala}', 'en_revision', false, 'SEED');

-- ----------------------------------------------------------------------------
-- Solicitudes en distintos puntos del proceso
-- ----------------------------------------------------------------------------
insert into public.solicitudes (
  cliente_id, tipo_servicio, nivel_requerido, entorno, tipo_paciente,
  nivel_atencion, procedimientos, cantidad_enfermeros, fecha_inicio, turno,
  horas_por_turno, municipio, estatus, urgente, origen, contacto_nombre,
  contacto_telefono, created_at
)
select
  (select id from public.clientes where razon_social = 'Hospital San Rafael'),
  v.tipo::tipo_servicio, v.nivel::nivel_enfermeria, v.entorno::entorno_servicio,
  v.paciente, v.atencion::nivel_atencion, v.procs, v.cantidad,
  current_date + v.dias_inicio, v.turno::turno_tipo, v.horas, v.municipio,
  v.estatus::estatus_solicitud, v.urgente, 'seed', v.contacto, '+523310000000',
  now() - (v.horas_atras || ' hours')::interval
from (values
  -- Recien llegadas hoy
  ('turno_hospitalario','especialista','hospital','no_aplica','especializado',
   '{ventilacion,medicamentos_iv}'::text[], 2, 3,'nocturno',12,'guadalajara','nueva',   true,  'Hospital San Rafael',  2),
  ('cuidado_domiciliario','licenciado','domicilio','adulto_mayor','enfermeria',
   '{signos,medicamentos_orales,higiene}'::text[], 1, 5,'guardia_12',12,'zapopan','nueva', false, 'Familia Ledesma',      6),
  -- En busqueda desde hace mas de un dia: dispara la alerta
  ('cuidado_domiciliario','general','domicilio','postoperatorio','enfermeria',
   '{curaciones,movilizacion}'::text[], 1, 2,'matutino',8,'tlaquepaque','en_busqueda', false,'Sr. Alfonso Rivera',  38),
  ('turno_hospitalario','tecnico','clinica','no_aplica','basico',
   '{signos,higiene}'::text[], 3, 1,'vespertino',8,'guadalajara','en_busqueda', true, 'Clínica del Valle',      52),
  -- Ya con propuesta enviada y confirmadas
  ('cuidado_domiciliario','especialista','domicilio','paliativo','especializado',
   '{oxigeno,medicamentos_iv,sondas}'::text[], 1, 4,'guardia_24',24,'zapopan','propuesta_enviada', false,'Familia Zermeño', 26),
  ('turno_hospitalario','licenciado','asilo','adulto_mayor','enfermeria',
   '{signos,glucosa,medicamentos_orales}'::text[], 2, 7,'matutino',8,'tlajomulco','confirmada', false,'Casa de Retiro Los Robles', 72)
) as v(tipo, nivel, entorno, paciente, atencion, procs, cantidad, dias_inicio,
       turno, horas, municipio, estatus, urgente, contacto, horas_atras);

-- Domicilio del servicio en las dos que llegan a tener personal asignado.
-- Sin esto no se puede ver la regla 10.8 en accion: el profesional conoce el
-- domicilio solo despues de aceptar el turno, nunca mientras lo esta pensando.
update public.solicitudes set direccion_servicio = v.direccion
from (values
  ('propuesta_enviada', 'Av. Patria 1890, Col. Jardines Universidad'),
  ('confirmada',        'Camino Real a Colima 340, Col. Santa Fe')
) as v(estatus, direccion)
where public.solicitudes.origen = 'seed'
  and public.solicitudes.estatus::text = v.estatus;

-- ----------------------------------------------------------------------------
-- Turnos de este mes: completados, en curso y propuestos
-- Se reparten en fechas distintas por enfermero para no chocar con el
-- validador de traslapes.
-- ----------------------------------------------------------------------------
insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus)
select
  -- Se reparten entre las solicitudes ya cerradas para que el tablero no
  -- muestre decenas de turnos colgando de una sola solicitud abierta.
  -- El reparto es por semana y no por md5: con md5 el sorteo podia dejar a un
  -- cliente entero sin turnos recientes, y entonces su panel se veia muerto
  -- (gasto del mes en cero, nada por evaluar) aunque el sistema estuviera bien.
  -- La semana 0 le toca a la primera solicitud por folio, que es la del
  -- hospital ligado a la cuenta de prueba: asi siempre hay algo dentro de los
  -- 15 dias en que se puede evaluar.
  (select sc.id from public.solicitudes sc
   where sc.estatus = 'completada'
   order by sc.folio
   offset (v.semana % 3) limit 1),
  e.id,
  -- Un turno por semana durante las ultimas tres, escalonado por perfil.
  -- Se resta una semana de mas a proposito: `date_trunc('week', current_date)`
  -- es el LUNES de esta semana, asi que sin ese ajuste, aplicado un lunes o un
  -- martes, el seed generaba turnos marcados como "completada" con fecha
  -- futura, y ademas chocaban con el turno en curso de hoy y con las
  -- propuestas. Restando una, las tres semanas siempre quedan en el pasado.
  (date_trunc('week', current_date) - ((v.semana + 1) || ' weeks')::interval)::date
    + ((row_number() over (partition by v.semana order by e.nombre_completo) % 5))::int,
  'guardia_12', '07:00', '19:00',
  public.cobro_cliente(e.tarifa_turno_12), e.tarifa_turno_12,
  'completada'
from public.enfermeros e
cross join (values (0), (1), (2)) as v(semana)
where e.notas_internas = 'SEED'
  and e.publicado = true
  and e.tarifa_turno_12 is not null;

-- Las dos personas que ya aceptaron la solicitud confirmada
insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus)
select
  (select id from public.solicitudes where origen = 'seed' and estatus = 'confirmada' limit 1),
  e.id, current_date + 7, 'matutino', '07:00', '15:00',
  public.cobro_cliente(e.tarifa_turno_8), e.tarifa_turno_8, 'aceptada'
from public.enfermeros e
where e.nombre_completo in ('Ana Lucía Gutiérrez Mora', 'Gabriela Montserrat Estrada Lomelí');

-- Un turno en curso hoy, colgado de una solicitud ya cerrada para no alterar
-- el conteo de cobertura de las que siguen abiertas
insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus, checkin_at)
select
  (select id from public.solicitudes where estatus = 'completada' limit 1),
  e.id, current_date, 'guardia_24', '08:00', '08:00',
  public.cobro_cliente(e.tarifa_turno_24), e.tarifa_turno_24,
  'en_curso', now() - interval '4 hours'
from public.enfermeros e
where e.nombre_completo = 'José Antonio Ramírez Padilla';

-- Propuestas esperando respuesta del enfermero
insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus, created_at)
select
  (select id from public.solicitudes where origen = 'seed' and estatus = 'propuesta_enviada' limit 1),
  e.id, current_date + 4, 'guardia_24', '08:00', '08:00',
  public.cobro_cliente(e.tarifa_turno_24), e.tarifa_turno_24,
  'propuesta', now() - interval '20 hours'
from public.enfermeros e
where e.nombre_completo in ('Claudia Ivette Sandoval Ríos', 'Verónica Alejandra Núñez Salas');

-- El perfil ligado a la cuenta de prueba `enfermero@enlace.test` (EE-00001)
-- necesita trabajo por delante, no solo historial: sin una propuesta que
-- responder y un turno aceptado, el panel del enfermero se ve vacio y no hay
-- forma de validarlo.
--
-- Van cerca en el tiempo para que la demo se lea bien. Pueden hacerlo porque el
-- bloque de turnos semanales de arriba ya solo ocupa semanas pasadas.
insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus, created_at)
select
  (select id from public.solicitudes where origen = 'seed' and estatus = 'propuesta_enviada' limit 1),
  e.id, current_date + 2, 'nocturno', '23:00', '07:00',
  public.cobro_cliente(e.tarifa_turno_8), e.tarifa_turno_8,
  'propuesta', now() - interval '6 hours'
from public.enfermeros e
where e.nombre_completo = 'María Fernanda Ruiz Delgado';

insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus)
select
  (select id from public.solicitudes where origen = 'seed' and estatus = 'confirmada' limit 1),
  e.id, current_date + 5, 'guardia_12', '07:00', '19:00',
  public.cobro_cliente(e.tarifa_turno_12), e.tarifa_turno_12,
  'aceptada'
from public.enfermeros e
where e.nombre_completo = 'María Fernanda Ruiz Delgado';

-- ----------------------------------------------------------------------------
-- Cotizacion de las solicitudes que ya pasaron de "en busqueda"
--
-- La regla dice que no se puede proponer sin haber cotizado, y proponer_asignacion()
-- la hace cumplir. Pero el seed inserta directo y se la brincaba, asi que dejaba
-- solicitudes en "propuesta enviada" y "confirmada" sin tarifa: un estado que la
-- aplicacion nunca produciria y que hace ver el panel de la agencia como roto.
--
-- La tarifa sale de lo que realmente se facturo en sus turnos, para que el
-- reparto que muestra el panel cuadre con las asignaciones.
-- ----------------------------------------------------------------------------
update public.solicitudes s
set tarifa_ofrecida_cliente = v.tarifa
from (
  select a.solicitud_id, round(avg(a.tarifa_cliente), 2) as tarifa
  from public.asignaciones a
  where a.estatus <> 'rechazada'
  group by a.solicitud_id
) as v
where v.solicitud_id = s.id
  and s.tarifa_ofrecida_cliente is null
  and s.estatus in ('propuesta_enviada', 'confirmada', 'en_curso', 'completada');

-- ----------------------------------------------------------------------------
-- Cobros al cliente
-- Uno pagado, uno pendiente y uno vencido: sin esto la pantalla de facturacion
-- del cliente sale vacia y no hay forma de validarla. El monto sale de los
-- turnos realmente facturados de cada solicitud, no de un numero inventado.
-- ----------------------------------------------------------------------------
-- Un cobro por solicitud y quincena, que es como factura la agencia. Agrupar
-- solo por solicitud daria un cobro de decenas de miles: el seed cuelga muchos
-- turnos de una misma solicitud cerrada.
-- La numeracion va en una CTE aparte porque Postgres no admite funciones de
-- ventana dentro de una condicion de JOIN.
with cortes as (
  select s.id                   as solicitud_id,
         (date_trunc('month', a.fecha)
          + case when extract(day from a.fecha) <= 15
                 then interval '0 day' else interval '15 days' end)::date as desde,
         case when extract(day from a.fecha) <= 15
              then (date_trunc('month', a.fecha) + interval '14 days')::date
              else (date_trunc('month', a.fecha) + interval '1 month'
                    - interval '1 day')::date end                          as hasta,
         sum(a.tarifa_cliente)  as total,
         max(a.fecha)           as ultima
  from public.solicitudes s
  join public.asignaciones a on a.solicitud_id = s.id and a.estatus = 'completada'
  where s.origen = 'seed'
  group by s.id, date_trunc('month', a.fecha), (extract(day from a.fecha) <= 15)
)
insert into public.pagos (tipo, referencia_id, periodo_inicio, periodo_fin,
                          monto, metodo, estatus, fecha_pago, notas)
select 'cobro_cliente', c.solicitud_id, c.desde, c.hasta, c.total,
       -- Lo viejo ya se pago; lo del corte en curso sigue abierto
       case when c.ultima < current_date - 20 then 'transferencia' end,
       case when c.ultima < current_date - 20 then 'pagado'
            when c.ultima < current_date - 10 then 'vencido'
            else 'pendiente' end::estatus_pago,
       case when c.ultima < current_date - 20 then c.ultima + 5 end,
       case when c.ultima < current_date - 20 then 'Factura CFDI enviada al correo registrado.'
            when c.ultima < current_date - 10 then 'Venció el plazo acordado.'
            else 'Factura enviada, en espera de pago.' end
from cortes c;

-- ----------------------------------------------------------------------------
-- Documentos: al corriente, por vencer, vencidos y en espera de revision
-- ----------------------------------------------------------------------------
insert into public.documentos (enfermero_id, tipo, archivo_url, fecha_emision,
                               fecha_vencimiento, estatus)
select e.id, v.tipo::tipo_documento,
       'documentos/' || e.id || '/' || v.tipo || '.pdf',
       current_date - (v.antiguedad || ' days')::interval,
       case when v.vence_en is null then null
            else current_date + (v.vence_en || ' days')::interval end,
       v.estatus::estatus_verif
from public.enfermeros e
join (values
  ('María Fernanda Ruiz Delgado',  'ine',             400, null, 'verificado'),
  ('María Fernanda Ruiz Delgado',  'certificado_bls', 700,   18, 'verificado'),
  ('María Fernanda Ruiz Delgado',  'certificado_acls',730,   -5, 'verificado'),
  ('Jorge Alberto Medina Vargas',  'ine',             300, null, 'verificado'),
  ('Jorge Alberto Medina Vargas',  'certificado_bls', 690,   25, 'verificado'),
  ('Diana Patricia Ochoa Reynoso', 'examen_medico',   340,   12, 'verificado'),
  ('Ana Lucía Gutiérrez Mora',     'vacunacion',      200,  120, 'verificado'),
  -- Expediente completo esperando revision: sirve para probar el flujo entero
  -- hasta publicar el perfil
  ('Alejandra Sáenz Mendoza',      'ine',                  10, null, 'pendiente'),
  ('Alejandra Sáenz Mendoza',      'curp',                 10, null, 'pendiente'),
  ('Alejandra Sáenz Mendoza',      'comprobante_domicilio',10, null, 'pendiente'),
  ('Alejandra Sáenz Mendoza',      'cedula_profesional',   10, null, 'pendiente'),
  ('Alejandra Sáenz Mendoza',      'titulo',               10, null, 'pendiente'),
  -- Expediente a medias: le faltan documentos por entregar
  ('Óscar Iván Trejo Lara',        'ine',                   4, null, 'en_revision'),
  ('Óscar Iván Trejo Lara',        'comprobante_domicilio', 4, null, 'en_revision')
) as v(nombre, tipo, antiguedad, vence_en, estatus) on v.nombre = e.nombre_completo;

commit;

-- ============================================================================
-- Listo. Ahora:
--   1. Settings -> API: copia Project URL y la llave `anon public`
--      a js/config.js. La llave `service_role` NUNCA va en el frontend.
--   2. Ejecuta 99-pruebas.sql: todos los renglones deben decir OK.
-- ============================================================================
