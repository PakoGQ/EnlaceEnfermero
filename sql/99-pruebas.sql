-- ============================================================================
-- Enlace Enfermero — 99. Verificacion de la instalacion
--
-- Archivo de apoyo, NO forma parte del esquema. Ejecutalo una sola vez despues
-- de 01 a 04 para comprobar que los triggers y las politicas quedaron bien.
-- Al final borra todo lo que inserto.
--
-- Uso: pegarlo completo en el SQL Editor de Supabase y revisar que cada
-- renglon diga "OK". No ejecutar sobre datos reales.
-- ============================================================================

begin;

-- --- Datos de prueba -------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data)
values ('99999999-9999-9999-9999-999999999999', 'prueba@enlaceenfermero.mx',
        '{"nombre":"Prueba","rol":"enfermero"}'::jsonb);

insert into public.enfermeros (usuario_id, nombre_completo, nivel, anios_experiencia,
                               especialidades, publicado, estatus_verificacion)
values ('99999999-9999-9999-9999-999999999999', 'Enfermero De Prueba', 'especialista', 8,
        '{uci}', true, 'verificado');

insert into public.enfermeros (nombre_completo, nivel, publicado, estatus_verificacion)
values ('Perfil Sin Verificar', 'auxiliar', true, 'pendiente');

insert into public.clientes (nombre_contacto, tipo) values ('Cliente De Prueba', 'hospital');

insert into public.solicitudes (cliente_id, tipo_servicio, fecha_inicio, turno)
select id, 'turno_hospitalario', current_date + 30, 'nocturno'
from public.clientes where nombre_contacto = 'Cliente De Prueba';

insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus)
select s.id, e.id, current_date + 30, 'nocturno', '23:00', '07:00',
       1200, public.pago_enfermero(1200), 'completada'
from public.solicitudes s, public.enfermeros e
where e.nombre_completo = 'Enfermero De Prueba'
  and s.cliente_id = (select id from public.clientes where nombre_contacto = 'Cliente De Prueba');

insert into public.evaluaciones (asignacion_id, cliente_id, enfermero_id, puntualidad,
                                 trato, competencia_tecnica, calificacion_general)
select a.id, c.id, a.enfermero_id, 5, 5, 4, 5
from public.asignaciones a, public.clientes c
where c.nombre_contacto = 'Cliente De Prueba'
  and a.enfermero_id = (select id from public.enfermeros where nombre_completo = 'Enfermero De Prueba');

-- --- Comprobaciones --------------------------------------------------------
select 'Folio de enfermero (EE-#####)' as prueba,
       case when folio ~ '^EE-\d{5}$' then 'OK: ' || folio else 'FALLA: ' || coalesce(folio,'nulo') end as resultado
from public.enfermeros where nombre_completo = 'Enfermero De Prueba'
union all
select 'Folio de solicitud (SOL-#####)',
       case when folio ~ '^SOL-\d{5}$' then 'OK: ' || folio else 'FALLA' end
from (select folio from public.solicitudes order by created_at desc limit 1) ultima;

select 'Codigo de referido (REF-XXXXXX)' as prueba,
       case when codigo ~ '^REF-[0-9A-F]{6}$' then 'OK: ' || codigo else 'FALLA' end as resultado
from public.codigos_referido where usuario_id = '99999999-9999-9999-9999-999999999999';

select 'Comision calculada' as prueba,
       case when comision_agencia = 480 then 'OK: ' || comision_agencia else 'FALLA' end as resultado
from public.asignaciones where tarifa_cliente = 1200;

select 'Calificacion recalculada por trigger' as prueba,
       case when calificacion_promedio = 5.00 and total_servicios = 1
            then 'OK: ' || calificacion_promedio || ' con ' || total_servicios || ' servicio'
            else 'FALLA: ' || coalesce(calificacion_promedio::text,'nulo') end as resultado
from public.enfermeros where nombre_completo = 'Enfermero De Prueba';

select 'Reparto 60/40 del servicio' as prueba,
       case when tarifa_enfermero = 720 and comision_agencia = 480
            then 'OK: cliente 1200 = enfermero 720 + agencia 480'
            else 'FALLA: ' || tarifa_enfermero || ' / ' || comision_agencia end as resultado
from public.asignaciones where tarifa_cliente = 1200;

select 'Reparto automatico al dejar el pago en blanco' as prueba,
       case when public.pago_enfermero(2000) = 1200 and public.cobro_cliente(1200) = 2000
            then 'OK: las dos funciones son inversas'
            else 'FALLA' end as resultado;

select 'Catalogo publico oculta a los no verificados' as prueba,
       case when count(*) = 0 then 'OK' else 'FALLA: se filtro un perfil sin verificar' end as resultado
from public.enfermeros_publico where nombre_completo = 'Perfil Sin Verificar';

select 'Catalogo publico no expone datos sensibles' as prueba,
       case when count(*) = 0 then 'OK'
            else 'FALLA: la vista expone ' || string_agg(column_name, ', ') end as resultado
from information_schema.columns
where table_name = 'enfermeros_publico'
  and column_name in ('cedula_profesional', 'notas_internas', 'tarifa_hora',
                      'tarifa_turno_8', 'tarifa_turno_12', 'tarifa_turno_24');

-- Traslape: el segundo turno se encima con el nocturno del dia anterior
do $$
begin
  insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                   hora_fin, tarifa_cliente, tarifa_enfermero, estatus)
  select s.id, e.id, current_date + 31, 'matutino', '06:00', '14:00', 1000, 700, 'aceptada'
  from public.solicitudes s, public.enfermeros e
  where e.nombre_completo = 'Enfermero De Prueba' limit 1;
  raise warning 'Traslape de turnos: FALLA (se permitio un turno encimado)';
exception when others then
  raise notice 'Traslape de turnos: OK (bloqueado)';
end $$;

-- Comision negativa
do $$
begin
  insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                   hora_fin, tarifa_cliente, tarifa_enfermero)
  select s.id, e.id, current_date + 60, 'matutino', '07:00', '15:00', 500, 900
  from public.solicitudes s, public.enfermeros e
  where e.nombre_completo = 'Enfermero De Prueba' limit 1;
  raise warning 'Comision negativa: FALLA (se permitio)';
exception when others then
  raise notice 'Comision negativa: OK (bloqueada)';
end $$;

-- El enfermero no puede tocar los campos reservados al admin
set local role authenticated;
set local request.jwt.claim.sub = '99999999-9999-9999-9999-999999999999';

update public.enfermeros
set bio               = 'Texto que el enfermero SI puede editar',
    cedula_verificada = true,
    notas_internas    = 'intento de escritura',
    tarifa_turno_12   = 9999
where usuario_id = '99999999-9999-9999-9999-999999999999';

reset role;

select 'El enfermero edita su bio' as prueba,
       case when bio = 'Texto que el enfermero SI puede editar' then 'OK' else 'FALLA' end as resultado
from public.enfermeros where nombre_completo = 'Enfermero De Prueba'
union all
select 'El enfermero NO se autoverifica la cedula',
       case when cedula_verificada = false then 'OK' else 'FALLA: se autoverifico' end
from public.enfermeros where nombre_completo = 'Enfermero De Prueba'
union all
select 'El enfermero NO escribe notas internas',
       case when notas_internas is null then 'OK' else 'FALLA: escribio notas internas' end
from public.enfermeros where nombre_completo = 'Enfermero De Prueba'
union all
select 'El enfermero NO fija su tarifa',
       case when tarifa_turno_12 is null then 'OK' else 'FALLA: fijo su propia tarifa' end
from public.enfermeros where nombre_completo = 'Enfermero De Prueba';

-- ----------------------------------------------------------------------------
-- PERMISOS DEL SITIO PUBLICO
--
-- Estas pruebas son las que faltaban cuando el sitio publico no podia escribir
-- nada: RLS estaba bien pero faltaban los GRANT, y "permission denied" aparece
-- antes de que las policies se evaluen siquiera.
-- ----------------------------------------------------------------------------
set local role anon;

do $$
declare
  folio_prueba text;
begin
  -- Leer el catalogo
  perform 1 from public.enfermeros_publico limit 1;
  raise notice 'anon lee el catalogo publico: OK';

  begin
    perform 1 from public.evaluaciones limit 1;
    raise notice 'anon lee las evaluaciones: OK';
  exception when others then
    raise warning 'anon lee las evaluaciones: FALLA (%)', sqlerrm;
  end;

  begin
    perform 1 from public.disponibilidad limit 1;
    raise notice 'anon lee la disponibilidad: OK';
  exception when others then
    raise warning 'anon lee la disponibilidad: FALLA (%)', sqlerrm;
  end;

  begin
    insert into public.leads (nombre, tipo) values ('Prueba permisos', 'busco_personal');
    raise notice 'anon deja un lead: OK';
  exception when others then
    raise warning 'anon deja un lead: FALLA (%)', sqlerrm;
  end;

  begin
    insert into public.visitas (pagina) values ('/prueba');
    raise notice 'anon registra una visita: OK';
  exception when others then
    raise warning 'anon registra una visita: FALLA (%)', sqlerrm;
  end;

  -- El formulario de solicitud, que es de donde vive el negocio
  begin
    folio_prueba := public.crear_solicitud(jsonb_build_object(
      'tipo_servicio', 'cuidado_domiciliario',
      'fecha_inicio', current_date + 5,
      'entorno', 'domicilio',
      'nivel_atencion', 'basico',
      'contacto_nombre', 'Prueba permisos'
    ));
    raise notice 'anon envia una solicitud y recibe folio %: OK', folio_prueba;
  exception when others then
    raise warning 'anon envia una solicitud: FALLA (%)', sqlerrm;
  end;

  begin
    folio_prueba := public.registrar_enfermero(jsonb_build_object(
      'nombre_completo', 'Prueba permisos',
      'nivel', 'general',
      'publicado', true,
      'estatus_verificacion', 'verificado'
    ));
    raise notice 'anon se registra como enfermero, folio %: OK', folio_prueba;
  exception when others then
    raise warning 'anon se registra como enfermero: FALLA (%)', sqlerrm;
  end;

  -- Y lo que NO debe poder hacer
  begin
    perform 1 from public.enfermeros limit 1;
    if found then
      raise warning 'anon lee la tabla enfermeros: FALLA (expone tarifas y notas)';
    else
      raise notice 'anon NO lee la tabla enfermeros: OK';
    end if;
  exception when others then
    raise notice 'anon NO lee la tabla enfermeros: OK (bloqueado)';
  end;

  begin
    perform 1 from public.pagos limit 1;
    if found then
      raise warning 'anon lee los pagos: FALLA';
    else
      raise notice 'anon NO lee los pagos: OK';
    end if;
  exception when others then
    raise notice 'anon NO lee los pagos: OK (bloqueado)';
  end;
end $$;

reset role;

select 'El registro publico entra sin verificar' as prueba,
       case when publicado = false and estatus_verificacion = 'pendiente'
            then 'OK (ignoro publicado=true y verificado)'
            else 'FALLA: entro publicado o verificado' end as resultado
from public.enfermeros where nombre_completo = 'Prueba permisos';

select 'La solicitud publica entra sin tarifa' as prueba,
       case when tarifa_ofrecida_cliente is null and estatus = 'nueva'
            then 'OK (la cotiza el admin)'
            else 'FALLA' end as resultado
from public.solicitudes where contacto_nombre = 'Prueba permisos';

-- ----------------------------------------------------------------------------
-- ACCESO AL PANEL DE LA AGENCIA
--
-- Las funciones del dashboard son security definer, y dentro de una funcion
-- asi `current_user` es el propietario, no el rol del llamante. Por eso
-- comprueban con es_staff_estricto(), que mira el token y no el rol de
-- Postgres. Sin eso, cualquier usuario con sesion veria los ingresos de la
-- agencia y los datos de todos los clientes.
-- ----------------------------------------------------------------------------
do $$
declare
  id_enfermero uuid;
begin
  select id into id_enfermero from public.usuarios where rol = 'enfermero' limit 1;

  if id_enfermero is null then
    raise notice 'Acceso al panel: sin usuarios para probar (ejecuta crear-usuarios-prueba.sh)';
    return;
  end if;

  -- Se simula la sesion de un enfermero
  perform set_config('request.jwt.claim.sub', id_enfermero::text, true);

  begin
    perform public.kpis_dashboard();
    raise warning 'Un enfermero ve los indicadores de la agencia: FALLA';
  exception when others then
    raise notice 'Un enfermero NO ve los indicadores: OK (bloqueado)';
  end;

  begin
    perform public.ultimas_solicitudes(5);
    raise warning 'Un enfermero ve las solicitudes de todos: FALLA';
  exception when others then
    raise notice 'Un enfermero NO ve las solicitudes de todos: OK (bloqueado)';
  end;

  perform set_config('request.jwt.claim.sub', '', true);
end $$;

-- ----------------------------------------------------------------------------
-- PANEL DEL ENFERMERO
--
-- Aqui el filtro va al reves que en el panel de la agencia: no se comprueba
-- que quien llama SEA staff, sino que tenga ficha propia en `enfermeros`.
-- Todo cuelga de mi_enfermero_id(), que mira auth.uid(): es el unico dato que
-- no cambia al entrar en un security definer.
-- ----------------------------------------------------------------------------
do $$
declare
  id_prueba uuid := '99999999-9999-9999-9999-999999999999';
  id_admin  uuid;
  resumen   jsonb;
  dir_prop  text;
  dir_acep  text;
begin
  perform set_config('request.jwt.claims',
                     json_build_object('sub', id_prueba)::text, true);

  -- Ve lo suyo, y lo suyo es lo que le toca
  resumen := public.panel_enfermero_resumen();
  if resumen->>'folio' = (select folio from public.enfermeros where usuario_id = id_prueba)
  then raise notice 'El enfermero ve su propio resumen: OK';
  else raise warning 'El enfermero no ve su propio resumen: FALLA';
  end if;

  -- El resumen habla de lo que el gana, nunca de lo que la agencia factura
  if not (resumen ? 'tarifa_cliente' or resumen ? 'comision') then
    raise notice 'El resumen no expone el ingreso de la agencia: OK';
  else
    raise warning 'El resumen expone datos de la agencia: FALLA';
  end if;

  -- Quien no tiene ficha no entra, aunque traiga sesion valida
  begin
    perform set_config('request.jwt.claims',
                       json_build_object('sub', gen_random_uuid())::text, true);
    perform public.panel_enfermero_resumen();
    raise warning 'Un usuario sin ficha entra al panel del enfermero: FALLA';
  exception when insufficient_privilege then
    raise notice 'Un usuario sin ficha NO entra: OK (bloqueado)';
  end;

  -- Y el admin tampoco: para ver a un profesional tiene sus propias funciones
  select id into id_admin from public.usuarios where rol = 'admin' limit 1;
  if id_admin is not null then
    begin
      perform set_config('request.jwt.claims',
                         json_build_object('sub', id_admin)::text, true);
      perform public.panel_enfermero_alertas();
      raise warning 'El admin entra al panel del enfermero: FALLA';
    exception when insufficient_privilege then
      raise notice 'El admin NO entra por la puerta del enfermero: OK (bloqueado)';
    end;
  end if;

  -- Regla 10.8: el domicilio se conoce al aceptar, no al recibir la propuesta
  update public.solicitudes set direccion_servicio = 'Calle De Prueba 100'
  where cliente_id = (select id from public.clientes where nombre_contacto = 'Cliente De Prueba');

  insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno,
                                   hora_inicio, hora_fin, tarifa_cliente,
                                   tarifa_enfermero, estatus)
  select s.id, e.id, current_date + 31, 'nocturno', '23:00', '07:00',
         1200, public.pago_enfermero(1200), 'propuesta'
  from public.solicitudes s, public.enfermeros e
  where e.usuario_id = id_prueba
    and s.cliente_id = (select id from public.clientes where nombre_contacto = 'Cliente De Prueba');

  perform set_config('request.jwt.claims',
                     json_build_object('sub', id_prueba)::text, true);

  select p.direccion into dir_prop
  from public.panel_enfermero_proximos(10) p where p.estatus = 'propuesta';

  update public.asignaciones set estatus = 'aceptada'
  where enfermero_id = (select id from public.enfermeros where usuario_id = id_prueba)
    and estatus = 'propuesta';

  select p.direccion into dir_acep
  from public.panel_enfermero_proximos(10) p where p.estatus = 'aceptada';

  if dir_prop is null and dir_acep is not null then
    raise notice 'El domicilio aparece solo al aceptar el turno: OK';
  else
    raise warning 'El domicilio se filtra antes de aceptar: FALLA (propuesta=%, aceptada=%)',
                  coalesce(dir_prop,'nulo'), coalesce(dir_acep,'nulo');
  end if;

  perform set_config('request.jwt.claims', '', true);
end $$;

-- ----------------------------------------------------------------------------
-- RECURSION ENTRE `solicitudes` Y `asignaciones`
--
-- Las dos policies se miraban entre si y Postgres cortaba con «infinite
-- recursion detected in policy»: ni el enfermero ni el cliente podian leer
-- ninguna de las dos tablas, y el staff no lo notaba porque su policy evalua
-- es_staff() y corta antes. Se rompio sacando el cruce a un security definer.
-- ----------------------------------------------------------------------------
do $$
declare
  id_prueba uuid := '99999999-9999-9999-9999-999999999999';
  n int;
begin
  perform set_config('request.jwt.claims',
                     json_build_object('sub', id_prueba)::text, true);
  begin
    select count(*) into n from public.asignaciones;
    raise notice 'Un enfermero puede leer sus asignaciones: OK';
  exception when others then
    raise warning 'Las asignaciones siguen recursando: FALLA -> %', sqlerrm;
  end;

  begin
    select count(*) into n from public.solicitudes;
    raise notice 'Un enfermero puede leer sus solicitudes: OK';
  exception when others then
    raise warning 'Las solicitudes siguen recursando: FALLA -> %', sqlerrm;
  end;

  perform set_config('request.jwt.claims', '', true);
end $$;

-- ----------------------------------------------------------------------------
-- CICLO DE VIDA DE UN TURNO DESDE EL PANEL DEL ENFERMERO
-- ----------------------------------------------------------------------------
do $$
declare
  id_prueba uuid := '99999999-9999-9999-9999-999999999999';
  v_ficha   uuid;
  v_asig    uuid;
  r         jsonb;
begin
  perform set_config('request.jwt.claims',
                     json_build_object('sub', id_prueba)::text, true);

  select id into v_ficha from public.enfermeros where usuario_id = id_prueba;

  insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno,
                                   hora_inicio, hora_fin, tarifa_cliente,
                                   tarifa_enfermero, estatus)
  select s.id, v_ficha, current_date, 'matutino', '07:00', '15:00',
         1000, public.pago_enfermero(1000), 'propuesta'
  from public.solicitudes s
  where s.cliente_id = (select id from public.clientes where nombre_contacto = 'Cliente De Prueba')
  limit 1
  returning id into v_asig;

  -- Rechazar sin decir por que deja a la agencia sin informacion para reasignar
  begin
    perform public.responder_propuesta(v_asig, false, null);
    raise warning 'Se rechazo un turno sin motivo: FALLA';
  exception when others then
    raise notice 'Rechazar sin motivo: OK (bloqueado)';
  end;

  r := public.responder_propuesta(v_asig, true);
  if r->>'estatus' = 'aceptada'
  then raise notice 'Aceptar una propuesta: OK';
  else raise warning 'No se pudo aceptar la propuesta: FALLA'; end if;

  -- Una propuesta ya respondida no se responde otra vez
  begin
    perform public.responder_propuesta(v_asig, true);
    raise warning 'Se respondio dos veces la misma propuesta: FALLA';
  exception when others then
    raise notice 'Responder dos veces: OK (bloqueado)';
  end;

  r := public.registrar_mi_asistencia(v_asig, 'entrada');
  if r->>'estatus' = 'en_curso'
  then raise notice 'Marcar entrada: OK';
  else raise warning 'No se registro la entrada: FALLA'; end if;

  r := public.registrar_mi_asistencia(v_asig, 'salida');
  if r->>'estatus' = 'completada'
  then raise notice 'Marcar salida cierra el turno: OK';
  else raise warning 'No se registro la salida: FALLA'; end if;

  perform set_config('request.jwt.claims', '', true);
end $$;

-- ----------------------------------------------------------------------------
-- EL EXPEDIENTE ES SUYO Y DE NADIE MAS
-- ----------------------------------------------------------------------------
do $$
declare
  id_prueba uuid := '99999999-9999-9999-9999-999999999999';
  ajeno     uuid;
begin
  select id into ajeno from public.enfermeros
  where usuario_id is distinct from id_prueba limit 1;

  perform set_config('request.jwt.claims',
                     json_build_object('sub', id_prueba)::text, true);

  begin
    perform public.subir_mi_documento('ine', 'documentos/' || ajeno || '/ajeno.pdf');
    raise warning 'Registro a su nombre un archivo de otra carpeta: FALLA';
  exception when insufficient_privilege then
    raise notice 'Registrar un archivo de otro: OK (bloqueado)';
  end;

  begin
    perform public.subir_mi_documento(
      'ine', 'documentos/' || public.mi_enfermero_id() || '/viejo.pdf',
      null, current_date - 1);
    raise warning 'Acepto un documento ya vencido: FALLA';
  exception when insufficient_privilege then
    raise warning 'Error equivocado al subir vencido: FALLA';
  when others then
    raise notice 'Subir un documento vencido: OK (bloqueado)';
  end;

  perform set_config('request.jwt.claims', '', true);
end $$;

-- La funcion del admin y la del enfermero son distintas: si compartieran
-- nombre, la de 11-paneles.sql sobreescribiria la de 09-operacion.sql y el
-- panel de la agencia se quedaria sin registro de asistencia.
select 'Asistencia: el admin y el enfermero tienen funciones distintas' as prueba,
       case when (select count(*) from pg_proc where proname = 'registrar_asistencia') = 1
             and (select count(*) from pg_proc where proname = 'registrar_mi_asistencia') = 1
            then 'OK' else 'FALLA' end as resultado;

-- ----------------------------------------------------------------------------
-- PANEL DEL CLIENTE
--
-- Lo que se juega aqui es el modelo de negocio: el cliente tiene que ver QUIEN
-- cubre su turno, pero nunca COMO contactarlo. Si puede llamarle directo al
-- profesional, la agencia se queda sin comision (CLAUDE.md 6 y regla 10.8).
-- ----------------------------------------------------------------------------
do $$
declare
  id_cli   uuid := '88888888-8888-8888-8888-888888888888';
  v_ficha  uuid;
  v_sol    uuid;
  v_asig   uuid;
  d        jsonb;
  r        jsonb;
  n        int;
begin
  -- Un cliente propio para la prueba, con su solicitud y su turno cerrado
  insert into auth.users (id, email, raw_user_meta_data)
  values (id_cli, 'cliente.prueba@enlaceenfermero.mx',
          '{"nombre":"Cliente","rol":"cliente"}'::jsonb);

  -- El trigger tg_ficha_cliente ya le creo una ficha vacia al insertar el
  -- usuario; se descarta para poder ligarlo al cliente que si tiene solicitud
  -- (usuario_id es unico en `clientes`).
  delete from public.clientes where usuario_id = id_cli;

  update public.clientes set usuario_id = id_cli
  where nombre_contacto = 'Cliente De Prueba'
  returning id into v_ficha;

  select s.id into v_sol from public.solicitudes s where s.cliente_id = v_ficha limit 1;

  insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno,
                                   hora_inicio, hora_fin, tarifa_cliente,
                                   tarifa_enfermero, estatus)
  select v_sol, e.id, current_date - 2, 'matutino', '07:00', '15:00',
         1000, public.pago_enfermero(1000), 'completada'
  from public.enfermeros e where e.nombre_completo = 'Enfermero De Prueba'
  returning id into v_asig;

  perform set_config('request.jwt.claims',
                     json_build_object('sub', id_cli)::text, true);

  -- 1. Ve lo suyo
  r := public.panel_cliente_resumen();
  if r ? 'solicitudes_activas'
  then raise notice 'El cliente ve su resumen: OK';
  else raise warning 'El cliente no ve su resumen: FALLA'; end if;

  -- 2. LO CRITICO: el detalle no puede traer como contactar al profesional
  d := public.panel_cliente_solicitud_detalle(v_sol);
  if (d->'personal')::text ~* 'telefono|whatsapp|correo|email|cedula|tarifa|notas_internas'
  then raise warning 'El detalle expone contacto, cedula o tarifas: FALLA';
  else raise notice 'El detalle no expone contacto ni tarifas: OK';
  end if;

  -- 4. Evaluar solo lo completado, una vez, y con calificaciones validas
  r := public.guardar_evaluacion(v_asig, 5, 4, 5, 'Prueba automatica', false);
  if (r->>'calificacion')::int = 5
  then raise notice 'Guardar una evaluacion: OK';
  else raise warning 'La evaluacion no se guardo bien: FALLA'; end if;

  begin
    perform public.guardar_evaluacion(v_asig, 5, 5, 5);
    raise warning 'Se evaluo dos veces el mismo turno: FALLA';
  exception when others then
    raise notice 'Evaluar dos veces: OK (bloqueado)';
  end;

  begin
    perform public.guardar_evaluacion(v_asig, 0, 5, 5);
    raise warning 'Acepto una calificacion fuera de 1 a 5: FALLA';
  exception when others then
    raise notice 'Calificacion fuera de rango: OK (bloqueada)';
  end;

  -- 5. Una solicitud enviada con sesion se cuelga de su ficha sola
  declare f text;
  begin
    f := public.crear_solicitud(jsonb_build_object(
           'tipo_servicio', 'turno_hospitalario',
           'fecha_inicio', (current_date + 3)::text,
           'municipio', 'guadalajara',
           'contacto_nombre', 'Cliente De Prueba'));
    select count(*) into n from public.panel_cliente_solicitudes('todas') where folio = f;
    if n = 1
    then raise notice 'La solicitud del panel queda ligada al cliente: OK';
    else raise warning 'La solicitud nacio huerfana: FALLA'; end if;
  end;

  perform set_config('request.jwt.claims', '', true);
end $$;

-- La tabla `enfermeros` tiene que seguir cerrada para el cliente: sus datos le
-- llegan por las funciones del panel, que filtran columnas. Esta comprobacion
-- va fuera del bloque DO de arriba a proposito: ahi dentro se corre como
-- propietario y el RLS ni siquiera se evalua, asi que siempre pasaria.
do $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', '88888888-8888-8888-8888-888888888888')::text, true);
  execute 'set local role authenticated';

  begin
    perform 1 from public.enfermeros limit 1;
    if found then
      raise warning 'El cliente lee la tabla enfermeros directo: FALLA';
    else
      raise notice 'El cliente NO lee la tabla enfermeros: OK';
    end if;
  exception when others then
    raise notice 'El cliente NO lee la tabla enfermeros: OK (bloqueado)';
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end $$;

-- Un enfermero no entra por la puerta del cliente ni al reves
do $$
declare id_enf uuid := '99999999-9999-9999-9999-999999999999';
begin
  perform set_config('request.jwt.claims',
                     json_build_object('sub', id_enf)::text, true);
  begin
    perform public.panel_cliente_resumen();
    raise warning 'Un enfermero entro al panel del cliente: FALLA';
  exception when insufficient_privilege then
    raise notice 'Un enfermero NO entra al panel del cliente: OK (bloqueado)';
  end;
  perform set_config('request.jwt.claims', '', true);
end $$;

-- El ayudante que calcula el avance del perfil recibe un id cualquiera, asi
-- que no puede quedar al alcance del navegador: seria preguntar por el perfil
-- de otro. Solo lo llaman las funciones del panel, que corren como propietario.
select 'Ayudante de perfil fuera del alcance del navegador' as prueba,
       case when not has_function_privilege('authenticated',
                       'public.perfil_completo_pct(uuid)', 'execute')
            then 'OK' else 'FALLA' end as resultado
union all
select 'Panel del enfermero cerrado a visitantes',
       case when not has_function_privilege('anon',
                       'public.panel_enfermero_resumen()', 'execute')
            then 'OK' else 'FALLA' end;

-- Todo lo insertado se descarta
rollback;
