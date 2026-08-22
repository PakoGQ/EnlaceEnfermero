-- ============================================================================
-- Enlace Enfermero — 02. Row Level Security
-- RLS activo en todas las tablas sin excepcion (CLAUDE.md seccion 6).
-- Ejecutar despues de 01-schema.sql.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- FUNCION AUXILIAR
-- security definer para poder leer `usuarios` sin caer en recursion de RLS.
-- ----------------------------------------------------------------------------
create or replace function public.mi_rol()
returns rol_usuario
language sql
stable
security definer
set search_path = public
as $$
  select rol from public.usuarios where id = auth.uid();
$$;

-- true para admin y coordinador: ambos operan la agencia.
--
-- NO es security definer a proposito: necesita ver el rol real del llamante.
-- Si fuera definer, `current_user` seria siempre el propietario y la funcion
-- no podria distinguir a un cliente web de una operacion interna.
create or replace function public.es_staff()
returns boolean
language sql
stable
as $$
  select coalesce(public.mi_rol() in ('admin', 'coordinador'), false)
      -- Los unicos roles que llegan desde el navegador son `anon` y
      -- `authenticated`. Cualquier otro (service_role, el propietario de la
      -- base, o el de un trigger security definer) es interno y opera con
      -- plenos permisos. Sin esta linea, el trigger que recalcula la
      -- calificacion queda revertido por el trigger que protege los campos
      -- reservados al admin, y el promedio nunca se actualiza.
      or current_user not in ('anon', 'authenticated');
$$;

-- Version estricta de es_staff(), para usar DENTRO de funciones security definer.
--
-- es_staff() reconoce como internos a los roles que no son `anon` ni
-- `authenticated`, lo cual es correcto en las policies (ahi current_user es el
-- rol real del llamante) pero NO dentro de un security definer: ahi
-- current_user es el propietario de la funcion, asi que cualquier usuario con
-- sesion pasaria el filtro.
--
-- Esta solo mira quien es el usuario segun su token, que es lo unico que no
-- cambia al entrar en un security definer.
create or replace function public.es_staff_estricto()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.usuarios
    where id = auth.uid()
      and rol in ('admin', 'coordinador')
      and activo = true
  );
$$;

-- id del registro en `enfermeros` que pertenece al usuario en sesion
create or replace function public.mi_enfermero_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.enfermeros where usuario_id = auth.uid();
$$;

-- true si el perfil aparece en el catalogo publico. Es security definer porque
-- se usa dentro de policies: sin eso, la subconsulta a `enfermeros` quedaria
-- filtrada por el propio RLS y siempre daria falso para un visitante.
create or replace function public.enfermero_es_publico(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.enfermeros
    where id = p_id
      and publicado = true
      and estatus_verificacion = 'verificado'
  );
$$;

-- id del registro en `clientes` que pertenece al usuario en sesion
create or replace function public.mi_cliente_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.clientes where usuario_id = auth.uid() limit 1;
$$;

-- ----------------------------------------------------------------------------
-- ACTIVAR RLS EN TODAS LAS TABLAS
-- ----------------------------------------------------------------------------
alter table public.usuarios          enable row level security;
alter table public.enfermeros        enable row level security;
alter table public.clientes          enable row level security;
alter table public.solicitudes       enable row level security;
alter table public.asignaciones      enable row level security;
alter table public.disponibilidad    enable row level security;
alter table public.documentos        enable row level security;
alter table public.evaluaciones      enable row level security;
alter table public.pagos             enable row level security;
alter table public.codigos_referido  enable row level security;
alter table public.referidos         enable row level security;
alter table public.actividad         enable row level security;
alter table public.leads             enable row level security;
alter table public.visitas           enable row level security;

-- ----------------------------------------------------------------------------
-- PERMISOS DE TABLA (GRANT)
--
-- RLS y GRANT son dos capas distintas y hacen falta las dos: el GRANT decide
-- si el rol puede tocar la tabla, y la policy decide que filas ve o escribe.
-- Sin GRANT, PostgREST responde "permission denied" antes de siquiera evaluar
-- las policies.
--
-- Se otorga lo minimo. Nadie borra desde el frontend: no hay DELETE.
-- ----------------------------------------------------------------------------

-- El visitante sin sesion solo necesita leer lo publicable y dejar su rastro.
-- Las altas de solicitud y de enfermero NO se hacen con insert directo sino
-- con las funciones de 03-funciones.sql, que devuelven el folio.
grant select on public.evaluaciones   to anon, authenticated;
grant select on public.disponibilidad to anon, authenticated;
grant insert on public.leads          to anon, authenticated;
grant insert on public.visitas        to anon, authenticated;

-- Con sesion iniciada, cada rol trabaja sobre sus propias filas; el filtro
-- fino lo hacen las policies de abajo.
grant select, insert, update on all tables in schema public to authenticated;
grant usage on all sequences in schema public to authenticated;

-- ----------------------------------------------------------------------------
-- USUARIOS
-- ----------------------------------------------------------------------------
create policy usuarios_lee_su_fila on public.usuarios
  for select to authenticated using (id = auth.uid());

create policy usuarios_edita_su_fila on public.usuarios
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- El alta la hace el trigger al confirmarse el registro en auth.users,
-- pero se permite tambien el insert propio para el flujo de registro directo.
create policy usuarios_crea_su_fila on public.usuarios
  for insert to authenticated with check (id = auth.uid());

create policy usuarios_staff on public.usuarios
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- ENFERMEROS
-- El publico NO consulta esta tabla: usa la vista `enfermeros_publico`
-- definida en 04-vistas.sql. Por eso aqui no hay ninguna policy para `anon`.
-- Un trigger en 03-funciones.sql impide que el enfermero modifique los campos
-- reservados al admin: estatus_verificacion, publicado, tarifas, notas_internas.
-- ----------------------------------------------------------------------------
-- Alta publica desde unete.html. El candidato aun no tiene cuenta, por eso el
-- esquema deja `usuario_id` nullable. El WITH CHECK obliga a que la fila entre
-- siempre sin verificar, sin publicar, sin tarifas y sin notas internas: lo
-- unico que puede hacer un anonimo es proponerse como candidato.
create policy enfermeros_alta_publica on public.enfermeros
  for insert to anon, authenticated with check (
    usuario_id is null
    and publicado = false
    and estatus_verificacion = 'pendiente'
    and cedula_verificada = false
    and notas_internas is null
    and tarifa_hora is null
    and tarifa_turno_8 is null
    and tarifa_turno_12 is null
    and tarifa_turno_24 is null
    and calificacion_promedio is null
    and total_servicios = 0
  );

create policy enfermeros_lee_su_fila on public.enfermeros
  for select to authenticated using (usuario_id = auth.uid());

create policy enfermeros_edita_su_fila on public.enfermeros
  for update to authenticated
  using (usuario_id = auth.uid()) with check (usuario_id = auth.uid());

create policy enfermeros_staff on public.enfermeros
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- CLIENTES
-- ----------------------------------------------------------------------------
create policy clientes_su_fila on public.clientes
  for select to authenticated using (usuario_id = auth.uid());

create policy clientes_edita_su_fila on public.clientes
  for update to authenticated
  using (usuario_id = auth.uid()) with check (usuario_id = auth.uid());

create policy clientes_crea_su_fila on public.clientes
  for insert to authenticated with check (usuario_id = auth.uid());

create policy clientes_staff on public.clientes
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- SOLICITUDES
-- El formulario publico puede insertar sin sesion (lead), pero jamas leer.
-- ----------------------------------------------------------------------------
-- Alta publica desde solicitar.html. El cliente describe su necesidad; la
-- tarifa la cotiza la agencia despues (CLAUDE.md 15.5), asi que la solicitud
-- debe entrar sin precio y sin estatus adelantado.
create policy solicitudes_alta_publica on public.solicitudes
  for insert to anon, authenticated with check (
    tarifa_ofrecida_cliente is null
    and estatus = 'nueva'
  );

create policy solicitudes_cliente_lee on public.solicitudes
  for select to authenticated using (cliente_id = public.mi_cliente_id());

-- El enfermero solo ve las solicitudes en las que tiene una asignacion
create policy solicitudes_enfermero_lee on public.solicitudes
  for select to authenticated using (
    exists (
      select 1 from public.asignaciones a
      where a.solicitud_id = solicitudes.id
        and a.enfermero_id = public.mi_enfermero_id()
    )
  );

create policy solicitudes_staff on public.solicitudes
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- ASIGNACIONES
-- El enfermero puede cambiar el estatus a aceptada o rechazada; el resto de
-- transiciones y los montos quedan protegidos por trigger (03-funciones.sql).
-- ----------------------------------------------------------------------------
create policy asignaciones_enfermero_lee on public.asignaciones
  for select to authenticated using (enfermero_id = public.mi_enfermero_id());

create policy asignaciones_enfermero_responde on public.asignaciones
  for update to authenticated
  using (enfermero_id = public.mi_enfermero_id())
  with check (enfermero_id = public.mi_enfermero_id());

create policy asignaciones_cliente_lee on public.asignaciones
  for select to authenticated using (
    exists (
      select 1 from public.solicitudes s
      where s.id = asignaciones.solicitud_id
        and s.cliente_id = public.mi_cliente_id()
    )
  );

create policy asignaciones_staff on public.asignaciones
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- DISPONIBILIDAD — CRUD propio del enfermero
-- ----------------------------------------------------------------------------
-- El perfil publico muestra "disponibilidad esta semana" (CLAUDE.md 8.3), asi
-- que el visitante necesita leer los turnos libres de quien esta publicado.
-- Solo eso: los turnos ocupados y las notas no se exponen.
create policy disponibilidad_publica on public.disponibilidad
  for select to anon, authenticated using (
    disponible = true
    and public.enfermero_es_publico(enfermero_id)
  );

create policy disponibilidad_propia on public.disponibilidad
  for all to authenticated
  using (enfermero_id = public.mi_enfermero_id())
  with check (enfermero_id = public.mi_enfermero_id());

create policy disponibilidad_staff on public.disponibilidad
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- DOCUMENTOS — el enfermero sube y consulta los suyos, nunca los aprueba
-- ----------------------------------------------------------------------------
create policy documentos_enfermero_lee on public.documentos
  for select to authenticated using (enfermero_id = public.mi_enfermero_id());

create policy documentos_enfermero_sube on public.documentos
  for insert to authenticated with check (enfermero_id = public.mi_enfermero_id());

create policy documentos_enfermero_reemplaza on public.documentos
  for update to authenticated
  using (enfermero_id = public.mi_enfermero_id())
  with check (enfermero_id = public.mi_enfermero_id());

create policy documentos_staff on public.documentos
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- EVALUACIONES
-- ----------------------------------------------------------------------------
create policy evaluaciones_publicas on public.evaluaciones
  for select to anon, authenticated using (publica = true);

create policy evaluaciones_enfermero_lee on public.evaluaciones
  for select to authenticated using (enfermero_id = public.mi_enfermero_id());

-- Solo sobre asignaciones completadas del propio cliente y dentro de 15 dias
create policy evaluaciones_cliente_crea on public.evaluaciones
  for insert to authenticated with check (
    cliente_id = public.mi_cliente_id()
    and exists (
      select 1
      from public.asignaciones a
      join public.solicitudes s on s.id = a.solicitud_id
      where a.id = evaluaciones.asignacion_id
        and a.estatus = 'completada'
        and s.cliente_id = public.mi_cliente_id()
        and a.fecha >= current_date - interval '15 days'
    )
  );

create policy evaluaciones_staff on public.evaluaciones
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- PAGOS — cada parte ve solo lo suyo
-- ----------------------------------------------------------------------------
create policy pagos_enfermero_lee on public.pagos
  for select to authenticated using (
    tipo = 'pago_enfermero' and referencia_id = public.mi_enfermero_id()
  );

create policy pagos_cliente_lee on public.pagos
  for select to authenticated using (
    tipo = 'cobro_cliente' and exists (
      select 1 from public.solicitudes s
      where s.id = pagos.referencia_id
        and s.cliente_id = public.mi_cliente_id()
    )
  );

create policy pagos_staff on public.pagos
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- REFERIDOS
-- ----------------------------------------------------------------------------
create policy codigos_propio on public.codigos_referido
  for select to authenticated using (usuario_id = auth.uid());

create policy codigos_staff on public.codigos_referido
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

create policy referidos_propio on public.referidos
  for select to authenticated using (referidor_id = auth.uid() or referido_id = auth.uid());

create policy referidos_staff on public.referidos
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

-- ----------------------------------------------------------------------------
-- BITACORA Y CAPTACION
-- ----------------------------------------------------------------------------
-- La bitacora la escribe el trigger (security definer), nadie la edita a mano
create policy actividad_staff_lee on public.actividad
  for select to authenticated using (public.es_staff());

create policy leads_alta_publica on public.leads
  for insert to anon, authenticated with check (true);

create policy leads_staff on public.leads
  for all to authenticated using (public.es_staff()) with check (public.es_staff());

create policy visitas_alta_publica on public.visitas
  for insert to anon, authenticated with check (true);

create policy visitas_staff_lee on public.visitas
  for select to authenticated using (public.es_staff());

-- ----------------------------------------------------------------------------
-- STORAGE (CLAUDE.md 6, "Storage")
-- Los buckets se crean aqui y no a mano en el panel, para que la instalacion
-- quede completa de una sola pasada y sea igual en local y en produccion.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  -- Fotos de perfil: lectura publica, 5 MB, solo imagenes
  ('fotos', 'fotos', true, 5242880,
   array['image/jpeg', 'image/png', 'image/webp']),

  -- Documentos de identidad y profesionales: PRIVADO, 10 MB
  ('documentos', 'documentos', false, 10485760,
   array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),

  -- Comprobantes de pago: PRIVADO, solo staff
  ('comprobantes', 'comprobantes', false, 10485760,
   array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do nothing;

-- fotos: lectura abierta, escritura solo autenticado
create policy fotos_lectura_publica on storage.objects
  for select to anon, authenticated using (bucket_id = 'fotos');

create policy fotos_escritura on storage.objects
  for insert to authenticated with check (bucket_id = 'fotos');

create policy fotos_actualiza on storage.objects
  for update to authenticated using (bucket_id = 'fotos');

-- documentos: el enfermero solo toca la carpeta con su propio uuid.
-- Convencion de ruta: documentos/<enfermero_id>/<tipo>-<timestamp>.<ext>
create policy documentos_sube_propio on storage.objects
  for insert to authenticated with check (
    bucket_id = 'documentos'
    and (storage.foldername(name))[1] = public.mi_enfermero_id()::text
  );

create policy documentos_lee_propio on storage.objects
  for select to authenticated using (
    bucket_id = 'documentos'
    and (storage.foldername(name))[1] = public.mi_enfermero_id()::text
  );

create policy documentos_staff on storage.objects
  for all to authenticated using (bucket_id = 'documentos' and public.es_staff())
  with check (bucket_id = 'documentos' and public.es_staff());

-- comprobantes: exclusivo del staff
create policy comprobantes_staff on storage.objects
  for all to authenticated using (bucket_id = 'comprobantes' and public.es_staff())
  with check (bucket_id = 'comprobantes' and public.es_staff());
