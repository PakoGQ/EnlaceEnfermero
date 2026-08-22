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
