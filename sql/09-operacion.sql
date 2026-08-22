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
