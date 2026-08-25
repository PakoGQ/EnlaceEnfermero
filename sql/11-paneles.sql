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

    -- Serie de los ultimos 6 meses para dibujar la tendencia en el panel.
    -- Un numero solo dice cuanto; la linea dice si va subiendo, que es la
    -- pregunta que de verdad se hace quien vive de turnos.
    'serie_ganancias', coalesce((
      select jsonb_agg(m.monto order by m.mes)
      from (
        select date_trunc('month', d)::date as mes,
               coalesce((
                 select sum(a.tarifa_enfermero)
                 from public.asignaciones a
                 where a.enfermero_id = v_id
                   and a.estatus = 'completada'
                   and date_trunc('month', a.fecha) = date_trunc('month', d)
               ), 0) as monto
        from generate_series(
               (inicio_mes - interval '5 months'), inicio_mes, interval '1 month'
             ) d
      ) m
    ), '[]'::jsonb),

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
