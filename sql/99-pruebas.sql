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

-- Todo lo insertado se descarta
rollback;
