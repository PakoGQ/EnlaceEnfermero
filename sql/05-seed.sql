-- ============================================================================
-- Enlace Enfermero — 05. Datos de prueba (Fase 1)
--
-- 12 perfiles ficticios para poblar el catalogo publico mientras se levanta la
-- operacion real. Los nombres, cedulas y datos son inventados.
--
-- NO ejecutar en produccion con clientes reales. Para revertir:
--   delete from public.enfermeros where folio like 'EE-%' and notas_internas = 'SEED';
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ENFERMEROS
-- Sin foto_url: la tarjeta muestra las iniciales sobre el anillo azul.
-- Las tarifas son NETAS al enfermero y nunca se exponen al publico.
-- ----------------------------------------------------------------------------
insert into public.enfermeros (
  nombre_completo, nivel, cedula_profesional, cedula_verificada, institucion_egreso,
  anios_experiencia, especialidades, certificaciones, idiomas, bio, zonas_cobertura,
  disponible_inmediato, acepta_domicilio, acepta_nocturno, acepta_foraneo,
  tarifa_hora, tarifa_turno_8, tarifa_turno_12, tarifa_turno_24,
  estatus_verificacion, publicado, notas_internas
) values

('María Fernanda Ruiz Delgado', 'especialista', '10482375', true, 'Universidad de Guadalajara',
 12, '{uci,urgencias}', '{bls,acls,via_aerea,ventilacion}', '{espanol,ingles}',
 'Especialista en cuidados intensivos con doce años en unidades de tercer nivel. Manejo de ventilación mecánica, monitoreo hemodinámico y atención de paciente crítico. Acostumbrada a trabajar bajo presión y a coordinarme con el equipo médico tratante.',
 '{guadalajara,zapopan,tlaquepaque}', true, true, true, false,
 175, 1400, 1950, 3100, 'verificado', true, 'SEED'),

('Jorge Alberto Medina Vargas', 'licenciado', '11738294', true, 'Universidad Autónoma de Guadalajara',
 9, '{urgencias,cardiologia,medicina_interna}', '{bls,acls,medicamentos_iv}', '{espanol}',
 'Licenciado en enfermería con nueve años en servicio de urgencias. Experiencia en triage, estabilización de paciente cardiológico y manejo de accesos vasculares. Disponible para turnos nocturnos y cobertura de fines de semana.',
 '{guadalajara,tlaquepaque,tonala}', true, true, true, true,
 130, 1050, 1470, 2350, 'verificado', true, 'SEED'),

('Claudia Ivette Sandoval Ríos', 'especialista', '09847162', true, 'Universidad de Guadalajara',
 11, '{neonatologia,pediatria,materno_infantil}', '{bls,pals,nrp}', '{espanol,ingles}',
 'Especialista en neonatología con once años en cuneros y terapia intensiva neonatal. Certificada en reanimación neonatal. Acompaño a las familias en el cuidado del recién nacido con paciencia y comunicación clara.',
 '{zapopan,guadalajara}', false, true, true, false,
 180, 1450, 2030, 3200, 'verificado', true, 'SEED'),

('Ricardo Emmanuel Ponce Aguilar', 'general', '12904583', true, 'Universidad del Valle de México',
 6, '{medicina_interna,heridas,postoperatorio}', '{bls,heridas_avanzadas,cateteres}', '{espanol}',
 'Enfermero general con seis años de experiencia hospitalaria. Especializado en curación de heridas complejas, manejo de estomas y cuidado postoperatorio. Trabajo con protocolo y llevo registro puntual de la evolución del paciente.',
 '{guadalajara,tlaquepaque,el_salto}', true, true, false, false,
 110, 880, 1230, 1980, 'verificado', true, 'SEED'),

('Ana Lucía Gutiérrez Mora', 'licenciado', '10395827', true, 'Universidad de Guadalajara',
 8, '{geriatria,paliativos,rehabilitacion}', '{bls,medicamentos_iv,muestras}', '{espanol}',
 'Licenciada en enfermería enfocada en el adulto mayor. Ocho años acompañando pacientes en casa: control de medicamentos, movilización, prevención de caídas y cuidados paliativos. Creo en el trato digno y en mantener informada a la familia.',
 '{zapopan,guadalajara,tlajomulco}', true, true, false, false,
 125, 1000, 1400, 2250, 'verificado', true, 'SEED'),

('Diana Patricia Ochoa Reynoso', 'especialista', '08726194', true, 'Instituto Politécnico Nacional',
 14, '{quirofano,postoperatorio}', '{bls,acls,via_aerea}', '{espanol,ingles}',
 'Enfermera instrumentista con catorce años en quirófano. Experiencia en cirugía general, traumatología y laparoscopía. Conozco los protocolos de asepsia y el manejo de instrumental especializado.',
 '{guadalajara,zapopan}', false, false, true, true,
 185, 1480, 2070, 3300, 'verificado', true, 'SEED'),

('Luis Ángel Barajas Cortés', 'tecnico', null, false, 'CONALEP Jalisco',
 4, '{general,postoperatorio}', '{bls,muestras}', '{espanol}',
 'Técnico en enfermería con cuatro años de experiencia en hospitalización y recuperación postquirúrgica. Apoyo en signos vitales, higiene, movilización y toma de muestras. Puntual y con buena disposición para aprender.',
 '{tlaquepaque,tonala,guadalajara}', true, true, true, false,
 90, 720, 1010, 1620, 'verificado', true, 'SEED'),

('Verónica Alejandra Núñez Salas', 'licenciado', '11284736', true, 'Universidad de Guadalajara',
 10, '{oncologia,paliativos,medicina_interna}', '{bls,cateteres,medicamentos_iv}', '{espanol}',
 'Licenciada en enfermería con diez años en el área oncológica. Manejo de catéteres centrales, administración de quimioterapia bajo indicación médica y control de efectos adversos. Trato cercano con el paciente y su familia.',
 '{guadalajara,zapopan,tlaquepaque}', false, true, false, false,
 135, 1080, 1510, 2420, 'verificado', true, 'SEED'),

('José Antonio Ramírez Padilla', 'especialista', '09163847', true, 'Universidad de Guadalajara',
 13, '{nefrologia,medicina_interna}', '{bls,acls,cateteres}', '{espanol}',
 'Especialista en nefrología con trece años en unidades de hemodiálisis. Manejo de accesos vasculares, control de balance hídrico y seguimiento del paciente renal crónico. Experiencia en hemodiálisis domiciliaria.',
 '{guadalajara,tonala,el_salto,zapotlanejo}', true, true, true, true,
 170, 1360, 1900, 3050, 'verificado', true, 'SEED'),

('Gabriela Montserrat Estrada Lomelí', 'general', '12573948', true, 'Universidad Autónoma de Guadalajara',
 7, '{materno_infantil,pediatria,general}', '{bls,pals,muestras}', '{espanol}',
 'Enfermera general con siete años en atención materno-infantil. Apoyo en control prenatal, lactancia y cuidado del recién nacido en domicilio. Comunicación clara y paciente con las mamás primerizas.',
 '{zapopan,tlajomulco,guadalajara}', true, true, false, false,
 115, 920, 1290, 2060, 'verificado', true, 'SEED'),

('Fernando Iván Cárdenas Sepúlveda', 'auxiliar', null, false, 'Cruz Roja Mexicana',
 3, '{general,geriatria}', '{bls}', '{espanol}',
 'Auxiliar de enfermería con tres años de experiencia en asilos y cuidado domiciliario. Apoyo en higiene, alimentación asistida, movilización y acompañamiento. Responsable y con muy buena disposición.',
 '{tlaquepaque,tonala,el_salto,juanacatlan}', true, true, true, false,
 75, 600, 840, 1350, 'verificado', true, 'SEED'),

('Rosa Elena Villalobos Chávez', 'cuidador', null, false, 'Instituto de Formación en Cuidados',
 9, '{geriatria,paliativos}', '{bls}', '{espanol}',
 'Cuidadora de adulto mayor con nueve años de experiencia en domicilio. Especializada en pacientes con demencia y movilidad reducida. Manejo rutinas de estimulación, aseo y compañía. Referencias comprobables.',
 '{guadalajara,zapopan,tlajomulco,ixtlahuacan}', true, true, true, false,
 80, 640, 900, 1440, 'verificado', true, 'SEED');

-- ----------------------------------------------------------------------------
-- CLIENTES, SOLICITUD Y ASIGNACIONES
-- Necesarios para que las evaluaciones publicas de la landing tengan respaldo.
-- ----------------------------------------------------------------------------
insert into public.clientes (tipo, razon_social, nombre_contacto, municipio, notas)
values
  ('hospital',   'Hospital San Rafael',        'Lic. Norma Bañuelos',  'Guadalajara', 'SEED'),
  ('asilo',      'Casa de Retiro Los Robles',  'Sr. Enrique Padilla',  'Zapopan',     'SEED'),
  ('particular', null,                          'Familia Zermeño',      'Zapopan',     'SEED');

insert into public.solicitudes (cliente_id, tipo_servicio, nivel_requerido, fecha_inicio,
                                turno, horas_por_turno, municipio, tarifa_ofrecida_cliente,
                                estatus, origen)
select id, 'turno_hospitalario', 'especialista', current_date - 30, 'nocturno', 12,
       municipio, public.cobro_cliente(1950), 'completada', 'seed'
from public.clientes where notas = 'SEED';

-- Un turno completado por enfermero, con tres semanas de separacion para que
-- el validador de traslapes no los rechace.
insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus)
select s.id,
       e.id,
       current_date - (21 + row_number() over (order by e.nombre_completo))::int,
       'guardia_12', '07:00', '19:00',
       -- reparto 60/40: se factura al cliente lo necesario para que al
       -- enfermero le toque su tarifa neta (CLAUDE.md 15.2)
       public.cobro_cliente(e.tarifa_turno_12),
       e.tarifa_turno_12,
       'completada'
from public.enfermeros e
cross join lateral (select id from public.solicitudes where origen = 'seed' limit 1) s
where e.notas_internas = 'SEED';

-- ----------------------------------------------------------------------------
-- EVALUACIONES PUBLICAS — alimentan los testimonios de la landing
-- El trigger actualizar_calificacion_enfermero recalcula el promedio solo.
-- ----------------------------------------------------------------------------
insert into public.evaluaciones (asignacion_id, cliente_id, enfermero_id, puntualidad,
                                 trato, competencia_tecnica, calificacion_general,
                                 comentario, publica)
select a.id,
       (select id from public.clientes where notas = 'SEED' limit 1),
       a.enfermero_id, 5, 5, 5, 5,
       c.comentario, true
from public.asignaciones a
join public.enfermeros e on e.id = a.enfermero_id
join (values
  ('María Fernanda Ruiz Delgado',
   'Llegó puntual las tres noches y manejó al paciente en ventilación sin un solo contratiempo. El médico tratante quedó muy conforme. La volveremos a solicitar.'),
  ('Ana Lucía Gutiérrez Mora',
   'Cuidó a mi mamá durante seis semanas. Además de su trabajo, nos explicaba todo con mucha paciencia. La familia entera quedó agradecida.'),
  ('Diana Patricia Ochoa Reynoso',
   'Instrumentista de primer nivel. Se integró al equipo de quirófano desde el primer día y conocía perfectamente los protocolos.')
) as c(nombre, comentario) on c.nombre = e.nombre_completo;

-- ----------------------------------------------------------------------------
-- ESCAPARATE
-- Se fija el historial acumulado de cada perfil para que el catalogo no se vea
-- vacio. En operacion real estos dos campos los calcula el trigger.
-- ----------------------------------------------------------------------------
update public.enfermeros e
set calificacion_promedio = v.calificacion,
    total_servicios       = v.servicios
from (values
  ('María Fernanda Ruiz Delgado',        4.9, 87),
  ('Jorge Alberto Medina Vargas',        4.8, 64),
  ('Claudia Ivette Sandoval Ríos',       5.0, 71),
  ('Ricardo Emmanuel Ponce Aguilar',     4.7, 42),
  ('Ana Lucía Gutiérrez Mora',           4.9, 58),
  ('Diana Patricia Ochoa Reynoso',       4.8, 93),
  ('Luis Ángel Barajas Cortés',          4.6, 28),
  ('Verónica Alejandra Núñez Salas',     4.9, 66),
  ('José Antonio Ramírez Padilla',       4.7, 79),
  ('Gabriela Montserrat Estrada Lomelí', 4.8, 45),
  ('Fernando Iván Cárdenas Sepúlveda',   4.5, 19),
  ('Rosa Elena Villalobos Chávez',       4.9, 52)
) as v(nombre, calificacion, servicios)
where e.nombre_completo = v.nombre;

-- ----------------------------------------------------------------------------
-- DISPONIBILIDAD de los proximos 14 dias, para el panel lateral del perfil
-- ----------------------------------------------------------------------------
insert into public.disponibilidad (enfermero_id, fecha, turno, disponible)
select e.id, d.fecha, t.turno, true
from public.enfermeros e
cross join generate_series(current_date, current_date + 13, interval '1 day') as d(fecha)
cross join (values ('matutino'::turno_tipo), ('vespertino'), ('nocturno')) as t(turno)
where e.notas_internas = 'SEED'
  -- patron variado por perfil para que el calendario no se vea uniforme
  and (extract(day from d.fecha)::int + length(e.nombre_completo)) % 3 <> 0
  and (t.turno <> 'nocturno' or e.acepta_nocturno)
on conflict (enfermero_id, fecha, turno) do nothing;

-- ============================================================================
-- OPERACION RECIENTE
-- Da contenido al panel de la agencia: solicitudes en varios estatus, turnos
-- de este mes, documentos por vencer y perfiles esperando verificacion.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Dos candidatos esperando verificacion (alimenta la alerta correspondiente)
-- ----------------------------------------------------------------------------
insert into public.enfermeros (nombre_completo, nivel, anios_experiencia, especialidades,
                               zonas_cobertura, estatus_verificacion, publicado, notas_internas)
values
  ('Alejandra Sáenz Mendoza', 'licenciado', 6, '{geriatria,paliativos}',
   '{guadalajara,zapopan}', 'pendiente', false, 'SEED'),
  ('Óscar Iván Trejo Lara', 'tecnico', 3, '{general}',
   '{tlaquepaque,tonala}', 'en_revision', false, 'SEED');

-- ----------------------------------------------------------------------------
-- Solicitudes en distintos puntos del proceso
-- ----------------------------------------------------------------------------
insert into public.solicitudes (
  cliente_id, tipo_servicio, nivel_requerido, entorno, tipo_paciente,
  nivel_atencion, procedimientos, cantidad_enfermeros, fecha_inicio, turno,
  horas_por_turno, municipio, estatus, urgente, origen, contacto_nombre,
  contacto_telefono, created_at
)
select
  (select id from public.clientes where razon_social = 'Hospital San Rafael'),
  v.tipo::tipo_servicio, v.nivel::nivel_enfermeria, v.entorno::entorno_servicio,
  v.paciente, v.atencion::nivel_atencion, v.procs, v.cantidad,
  current_date + v.dias_inicio, v.turno::turno_tipo, v.horas, v.municipio,
  v.estatus::estatus_solicitud, v.urgente, 'seed', v.contacto, '+523310000000',
  now() - (v.horas_atras || ' hours')::interval
from (values
  -- Recien llegadas hoy
  ('turno_hospitalario','especialista','hospital','no_aplica','especializado',
   '{ventilacion,medicamentos_iv}'::text[], 2, 3,'nocturno',12,'guadalajara','nueva',   true,  'Hospital San Rafael',  2),
  ('cuidado_domiciliario','licenciado','domicilio','adulto_mayor','enfermeria',
   '{signos,medicamentos_orales,higiene}'::text[], 1, 5,'guardia_12',12,'zapopan','nueva', false, 'Familia Ledesma',      6),
  -- En busqueda desde hace mas de un dia: dispara la alerta
  ('cuidado_domiciliario','general','domicilio','postoperatorio','enfermeria',
   '{curaciones,movilizacion}'::text[], 1, 2,'matutino',8,'tlaquepaque','en_busqueda', false,'Sr. Alfonso Rivera',  38),
  ('turno_hospitalario','tecnico','clinica','no_aplica','basico',
   '{signos,higiene}'::text[], 3, 1,'vespertino',8,'guadalajara','en_busqueda', true, 'Clínica del Valle',      52),
  -- Ya con propuesta enviada y confirmadas
  ('cuidado_domiciliario','especialista','domicilio','paliativo','especializado',
   '{oxigeno,medicamentos_iv,sondas}'::text[], 1, 4,'guardia_24',24,'zapopan','propuesta_enviada', false,'Familia Zermeño', 26),
  ('turno_hospitalario','licenciado','asilo','adulto_mayor','enfermeria',
   '{signos,glucosa,medicamentos_orales}'::text[], 2, 7,'matutino',8,'tlajomulco','confirmada', false,'Casa de Retiro Los Robles', 72)
) as v(tipo, nivel, entorno, paciente, atencion, procs, cantidad, dias_inicio,
       turno, horas, municipio, estatus, urgente, contacto, horas_atras);

-- Domicilio del servicio en las dos que llegan a tener personal asignado.
-- Sin esto no se puede ver la regla 10.8 en accion: el profesional conoce el
-- domicilio solo despues de aceptar el turno, nunca mientras lo esta pensando.
update public.solicitudes set direccion_servicio = v.direccion
from (values
  ('propuesta_enviada', 'Av. Patria 1890, Col. Jardines Universidad'),
  ('confirmada',        'Camino Real a Colima 340, Col. Santa Fe')
) as v(estatus, direccion)
where public.solicitudes.origen = 'seed'
  and public.solicitudes.estatus::text = v.estatus;

-- ----------------------------------------------------------------------------
-- Turnos de este mes: completados, en curso y propuestos
-- Se reparten en fechas distintas por enfermero para no chocar con el
-- validador de traslapes.
-- ----------------------------------------------------------------------------
insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus)
select
  -- Se reparten entre las solicitudes ya cerradas para que el tablero no
  -- muestre decenas de turnos colgando de una sola solicitud abierta.
  -- El reparto es por semana y no por md5: con md5 el sorteo podia dejar a un
  -- cliente entero sin turnos recientes, y entonces su panel se veia muerto
  -- (gasto del mes en cero, nada por evaluar) aunque el sistema estuviera bien.
  -- La semana 0 le toca a la primera solicitud por folio, que es la del
  -- hospital ligado a la cuenta de prueba: asi siempre hay algo dentro de los
  -- 15 dias en que se puede evaluar.
  (select sc.id from public.solicitudes sc
   where sc.estatus = 'completada'
   order by sc.folio
   offset (v.semana % 3) limit 1),
  e.id,
  -- un turno por semana durante las ultimas tres, escalonado por perfil
  (date_trunc('week', current_date) - (v.semana || ' weeks')::interval)::date
    + ((row_number() over (partition by v.semana order by e.nombre_completo) % 5))::int,
  'guardia_12', '07:00', '19:00',
  public.cobro_cliente(e.tarifa_turno_12), e.tarifa_turno_12,
  'completada'
from public.enfermeros e
cross join (values (0), (1), (2)) as v(semana)
where e.notas_internas = 'SEED'
  and e.publicado = true
  and e.tarifa_turno_12 is not null;

-- Las dos personas que ya aceptaron la solicitud confirmada
insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus)
select
  (select id from public.solicitudes where origen = 'seed' and estatus = 'confirmada' limit 1),
  e.id, current_date + 7, 'matutino', '07:00', '15:00',
  public.cobro_cliente(e.tarifa_turno_8), e.tarifa_turno_8, 'aceptada'
from public.enfermeros e
where e.nombre_completo in ('Ana Lucía Gutiérrez Mora', 'Gabriela Montserrat Estrada Lomelí');

-- Un turno en curso hoy, colgado de una solicitud ya cerrada para no alterar
-- el conteo de cobertura de las que siguen abiertas
insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus, checkin_at)
select
  (select id from public.solicitudes where estatus = 'completada' limit 1),
  e.id, current_date, 'guardia_24', '08:00', '08:00',
  public.cobro_cliente(e.tarifa_turno_24), e.tarifa_turno_24,
  'en_curso', now() - interval '4 hours'
from public.enfermeros e
where e.nombre_completo = 'José Antonio Ramírez Padilla';

-- Propuestas esperando respuesta del enfermero
insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus, created_at)
select
  (select id from public.solicitudes where origen = 'seed' and estatus = 'propuesta_enviada' limit 1),
  e.id, current_date + 4, 'guardia_24', '08:00', '08:00',
  public.cobro_cliente(e.tarifa_turno_24), e.tarifa_turno_24,
  'propuesta', now() - interval '20 hours'
from public.enfermeros e
where e.nombre_completo in ('Claudia Ivette Sandoval Ríos', 'Verónica Alejandra Núñez Salas');

-- El perfil ligado a la cuenta de prueba `enfermero@enlace.test` (EE-00001)
-- necesita trabajo por delante, no solo historial: sin una propuesta que
-- responder y un turno aceptado, el panel del enfermero se ve vacio y no hay
-- forma de validarlo. Las fechas se separan de sus turnos completados para no
-- chocar con validar_traslape().
insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus, created_at)
select
  (select id from public.solicitudes where origen = 'seed' and estatus = 'propuesta_enviada' limit 1),
  e.id, current_date + 3, 'nocturno', '23:00', '07:00',
  public.cobro_cliente(e.tarifa_turno_8), e.tarifa_turno_8,
  'propuesta', now() - interval '6 hours'
from public.enfermeros e
where e.nombre_completo = 'María Fernanda Ruiz Delgado';

insert into public.asignaciones (solicitud_id, enfermero_id, fecha, turno, hora_inicio,
                                 hora_fin, tarifa_cliente, tarifa_enfermero, estatus)
select
  (select id from public.solicitudes where origen = 'seed' and estatus = 'confirmada' limit 1),
  e.id, current_date + 6, 'guardia_12', '07:00', '19:00',
  public.cobro_cliente(e.tarifa_turno_12), e.tarifa_turno_12,
  'aceptada'
from public.enfermeros e
where e.nombre_completo = 'María Fernanda Ruiz Delgado';

-- ----------------------------------------------------------------------------
-- Cotizacion de las solicitudes que ya pasaron de "en busqueda"
--
-- La regla dice que no se puede proponer sin haber cotizado, y proponer_asignacion()
-- la hace cumplir. Pero el seed inserta directo y se la brincaba, asi que dejaba
-- solicitudes en "propuesta enviada" y "confirmada" sin tarifa: un estado que la
-- aplicacion nunca produciria y que hace ver el panel de la agencia como roto.
--
-- La tarifa sale de lo que realmente se facturo en sus turnos, para que el
-- reparto que muestra el panel cuadre con las asignaciones.
-- ----------------------------------------------------------------------------
update public.solicitudes s
set tarifa_ofrecida_cliente = v.tarifa
from (
  select a.solicitud_id, round(avg(a.tarifa_cliente), 2) as tarifa
  from public.asignaciones a
  where a.estatus <> 'rechazada'
  group by a.solicitud_id
) as v
where v.solicitud_id = s.id
  and s.tarifa_ofrecida_cliente is null
  and s.estatus in ('propuesta_enviada', 'confirmada', 'en_curso', 'completada');

-- ----------------------------------------------------------------------------
-- Cobros al cliente
-- Uno pagado, uno pendiente y uno vencido: sin esto la pantalla de facturacion
-- del cliente sale vacia y no hay forma de validarla. El monto sale de los
-- turnos realmente facturados de cada solicitud, no de un numero inventado.
-- ----------------------------------------------------------------------------
-- Un cobro por solicitud y quincena, que es como factura la agencia. Agrupar
-- solo por solicitud daria un cobro de decenas de miles: el seed cuelga muchos
-- turnos de una misma solicitud cerrada.
-- La numeracion va en una CTE aparte porque Postgres no admite funciones de
-- ventana dentro de una condicion de JOIN.
with cortes as (
  select s.id                   as solicitud_id,
         (date_trunc('month', a.fecha)
          + case when extract(day from a.fecha) <= 15
                 then interval '0 day' else interval '15 days' end)::date as desde,
         case when extract(day from a.fecha) <= 15
              then (date_trunc('month', a.fecha) + interval '14 days')::date
              else (date_trunc('month', a.fecha) + interval '1 month'
                    - interval '1 day')::date end                          as hasta,
         sum(a.tarifa_cliente)  as total,
         max(a.fecha)           as ultima
  from public.solicitudes s
  join public.asignaciones a on a.solicitud_id = s.id and a.estatus = 'completada'
  where s.origen = 'seed'
  group by s.id, date_trunc('month', a.fecha), (extract(day from a.fecha) <= 15)
)
insert into public.pagos (tipo, referencia_id, periodo_inicio, periodo_fin,
                          monto, metodo, estatus, fecha_pago, notas)
select 'cobro_cliente', c.solicitud_id, c.desde, c.hasta, c.total,
       -- Lo viejo ya se pago; lo del corte en curso sigue abierto
       case when c.ultima < current_date - 20 then 'transferencia' end,
       case when c.ultima < current_date - 20 then 'pagado'
            when c.ultima < current_date - 10 then 'vencido'
            else 'pendiente' end::estatus_pago,
       case when c.ultima < current_date - 20 then c.ultima + 5 end,
       case when c.ultima < current_date - 20 then 'Factura CFDI enviada al correo registrado.'
            when c.ultima < current_date - 10 then 'Venció el plazo acordado.'
            else 'Factura enviada, en espera de pago.' end
from cortes c;

-- ----------------------------------------------------------------------------
-- Documentos: al corriente, por vencer, vencidos y en espera de revision
-- ----------------------------------------------------------------------------
insert into public.documentos (enfermero_id, tipo, archivo_url, fecha_emision,
                               fecha_vencimiento, estatus)
select e.id, v.tipo::tipo_documento,
       'documentos/' || e.id || '/' || v.tipo || '.pdf',
       current_date - (v.antiguedad || ' days')::interval,
       case when v.vence_en is null then null
            else current_date + (v.vence_en || ' days')::interval end,
       v.estatus::estatus_verif
from public.enfermeros e
join (values
  ('María Fernanda Ruiz Delgado',  'ine',             400, null, 'verificado'),
  ('María Fernanda Ruiz Delgado',  'certificado_bls', 700,   18, 'verificado'),
  ('María Fernanda Ruiz Delgado',  'certificado_acls',730,   -5, 'verificado'),
  ('Jorge Alberto Medina Vargas',  'ine',             300, null, 'verificado'),
  ('Jorge Alberto Medina Vargas',  'certificado_bls', 690,   25, 'verificado'),
  ('Diana Patricia Ochoa Reynoso', 'examen_medico',   340,   12, 'verificado'),
  ('Ana Lucía Gutiérrez Mora',     'vacunacion',      200,  120, 'verificado'),
  -- Expediente completo esperando revision: sirve para probar el flujo entero
  -- hasta publicar el perfil
  ('Alejandra Sáenz Mendoza',      'ine',                  10, null, 'pendiente'),
  ('Alejandra Sáenz Mendoza',      'curp',                 10, null, 'pendiente'),
  ('Alejandra Sáenz Mendoza',      'comprobante_domicilio',10, null, 'pendiente'),
  ('Alejandra Sáenz Mendoza',      'cedula_profesional',   10, null, 'pendiente'),
  ('Alejandra Sáenz Mendoza',      'titulo',               10, null, 'pendiente'),
  -- Expediente a medias: le faltan documentos por entregar
  ('Óscar Iván Trejo Lara',        'ine',                   4, null, 'en_revision'),
  ('Óscar Iván Trejo Lara',        'comprobante_domicilio', 4, null, 'en_revision')
) as v(nombre, tipo, antiguedad, vence_en, estatus) on v.nombre = e.nombre_completo;
