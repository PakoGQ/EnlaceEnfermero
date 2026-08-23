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
