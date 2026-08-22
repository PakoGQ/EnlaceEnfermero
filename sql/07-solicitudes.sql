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
