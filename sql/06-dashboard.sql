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

    'documentos_vencidos', (
      select count(*) from public.documentos
      where fecha_vencimiento is not null
        and fecha_vencimiento < current_date
        and estatus <> 'rechazado'
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
