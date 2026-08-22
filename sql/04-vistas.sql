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
from public.enfermeros
where publicado = true
  and estatus_verificacion = 'verificado';

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
