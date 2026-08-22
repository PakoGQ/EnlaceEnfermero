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
