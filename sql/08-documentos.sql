-- ============================================================================
-- Enlace Enfermero — 08. Verificacion documental
-- Bandeja de revision y publicacion de perfiles (CLAUDE.md 8.6 y 10.2).
--
-- Aqui vive el diferenciador del negocio: nadie aparece en el catalogo sin
-- haber pasado por esto. Las reglas se aplican en la base, no solo en la
-- pantalla, para que no haya forma de saltarselas.
-- ============================================================================

drop function if exists public.documentos_bandeja(estatus_verif, uuid);
drop function if exists public.expediente_enfermero(uuid);
drop function if exists public.revisar_documento(uuid, boolean, text);
drop function if exists public.verificar_enfermero(uuid, boolean);

-- ----------------------------------------------------------------------------
-- Que documentos exige cada nivel (regla 10.2)
--
-- La definicion se movio a 02-rls.sql porque la necesitan enfermero_es_publico()
-- y la vista del catalogo, que se crean antes que este archivo. Aqui se sigue
-- usando igual; solo cambio de lugar.
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- BANDEJA: documentos esperando revision, con su contexto
-- ----------------------------------------------------------------------------
create or replace function public.documentos_bandeja(
  p_estatus estatus_verif default null,
  p_enfermero_id uuid default null
)
returns table (
  id                uuid,
  enfermero_id      uuid,
  folio             text,
  nombre_completo   text,
  nivel             nivel_enfermeria,
  tipo              tipo_documento,
  archivo_url       text,
  fecha_emision     date,
  fecha_vencimiento date,
  dias_para_vencer  int,
  estatus           estatus_verif,
  motivo_rechazo    text,
  verificado_at     timestamptz,
  revisado_por      text,
  subido_hace       int,
  obligatorio       boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede revisar documentos'
      using errcode = '42501';
  end if;

  return query
  select d.id, e.id, e.folio, e.nombre_completo, e.nivel,
         d.tipo, d.archivo_url, d.fecha_emision, d.fecha_vencimiento,
         case when d.fecha_vencimiento is null then null
              else (d.fecha_vencimiento - current_date)::int end,
         d.estatus, d.motivo_rechazo, d.verificado_at,
         trim(coalesce(u.nombre, '') || ' ' || coalesce(u.apellidos, '')),
         (extract(epoch from (now() - d.created_at)) / 3600)::int,
         d.tipo = any(public.documentos_obligatorios(e.nivel))
  from public.documentos d
  join public.enfermeros e on e.id = d.enfermero_id
  left join public.usuarios u on u.id = d.verificado_por
  where (p_estatus is null or d.estatus = p_estatus)
    and (p_enfermero_id is null or d.enfermero_id = p_enfermero_id)
  -- Lo pendiente primero, y dentro de eso lo que lleva mas tiempo esperando
  order by
    case d.estatus
      when 'pendiente'   then 1
      when 'en_revision' then 2
      when 'vencido'     then 3
      when 'rechazado'   then 4
      else 5
    end,
    d.created_at;
end;
$$;


-- ----------------------------------------------------------------------------
-- EXPEDIENTE: todo lo que hay que saber de un candidato para decidir
-- ----------------------------------------------------------------------------
create or replace function public.expediente_enfermero(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  e public.enfermeros%rowtype;
  obligatorios tipo_documento[];
  resultado jsonb;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede ver expedientes'
      using errcode = '42501';
  end if;

  select enf.* into e from public.enfermeros enf where enf.id = p_id;
  if not found then
    raise exception 'No existe el perfil %', p_id;
  end if;

  obligatorios := public.documentos_obligatorios(e.nivel);

  select jsonb_build_object(
    'enfermero', to_jsonb(e),

    'documentos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'tipo', d.tipo, 'archivo_url', d.archivo_url,
        'estatus', d.estatus, 'fecha_emision', d.fecha_emision,
        'fecha_vencimiento', d.fecha_vencimiento,
        'motivo_rechazo', d.motivo_rechazo, 'verificado_at', d.verificado_at,
        'obligatorio', d.tipo = any(obligatorios)
      ) order by d.tipo = any(obligatorios) desc, d.tipo)
      from public.documentos d where d.enfermero_id = p_id
    ), '[]'::jsonb),

    'obligatorios', to_jsonb(obligatorios),

    -- Los que exige su nivel y todavia no estan aprobados
    'faltantes', coalesce((
      select jsonb_agg(t)
      from unnest(obligatorios) t
      where not exists (
        select 1 from public.documentos d
        where d.enfermero_id = p_id and d.tipo = t and d.estatus = 'verificado'
      )
    ), '[]'::jsonb),

    'puede_verificarse', not exists (
      select 1 from unnest(obligatorios) t
      where not exists (
        select 1 from public.documentos d
        where d.enfermero_id = p_id and d.tipo = t and d.estatus = 'verificado'
      )
    ),

    'tiene_vencidos', exists (
      select 1 from public.documentos d
      where d.enfermero_id = p_id and d.estatus = 'vencido'
    )
  ) into resultado;

  return resultado;
end;
$$;

-- ----------------------------------------------------------------------------
-- REVISAR un documento: aprobar o rechazar con motivo
-- ----------------------------------------------------------------------------
create or replace function public.revisar_documento(
  p_id       uuid,
  p_aprobado boolean,
  p_motivo   text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  d public.documentos%rowtype;
  enfermero_id_afectado uuid;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede revisar documentos'
      using errcode = '42501';
  end if;

  select doc.* into d from public.documentos doc where doc.id = p_id;
  if not found then
    raise exception 'No existe el documento %', p_id;
  end if;

  if not p_aprobado and coalesce(trim(p_motivo), '') = '' then
    raise exception 'Para rechazar hay que decir por que: el candidato necesita saber que corregir'
      using errcode = 'P0001';
  end if;

  -- Un documento ya vencido no se aprueba: primero hay que renovarlo
  if p_aprobado and d.fecha_vencimiento is not null and d.fecha_vencimiento < current_date then
    raise exception 'Ese documento venció el %. Pide la renovación antes de aprobarlo',
      to_char(d.fecha_vencimiento, 'DD/MM/YYYY') using errcode = 'P0001';
  end if;

  update public.documentos
  set estatus        = (case when p_aprobado then 'verificado' else 'rechazado' end)::estatus_verif,
      motivo_rechazo = case when p_aprobado then null else trim(p_motivo) end,
      verificado_por = auth.uid(),
      verificado_at  = now()
  where id = p_id;

  enfermero_id_afectado := d.enfermero_id;

  -- Si se rechaza algo obligatorio de alguien ya publicado, se despublica:
  -- no puede seguir en el catalogo con el expediente incompleto
  if not p_aprobado then
    update public.enfermeros
    set publicado = false,
        estatus_verificacion = case
          when estatus_verificacion = 'verificado' then 'en_revision'
          else estatus_verificacion end
    where id = enfermero_id_afectado
      and publicado = true
      and d.tipo = any(public.documentos_obligatorios(nivel));
  end if;

  return public.expediente_enfermero(enfermero_id_afectado);
end;
$$;

-- ----------------------------------------------------------------------------
-- VERIFICAR y publicar un perfil
-- Solo si su expediente esta completo: la regla no se puede saltar desde la UI.
-- ----------------------------------------------------------------------------
create or replace function public.verificar_enfermero(
  p_id       uuid,
  p_publicar boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  expediente jsonb;
  e public.enfermeros%rowtype;
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede verificar perfiles'
      using errcode = '42501';
  end if;

  select enf.* into e from public.enfermeros enf where enf.id = p_id;
  if not found then
    raise exception 'No existe el perfil %', p_id;
  end if;

  expediente := public.expediente_enfermero(p_id);

  if not (expediente ->> 'puede_verificarse')::boolean then
    raise exception 'Faltan documentos obligatorios por aprobar: %',
      (select string_agg(valor, ', ')
       from jsonb_array_elements_text(expediente -> 'faltantes') valor)
      using errcode = 'P0001';
  end if;

  if (expediente ->> 'tiene_vencidos')::boolean then
    raise exception 'Tiene documentos vencidos. Renuévalos antes de publicar el perfil'
      using errcode = 'P0001';
  end if;

  update public.enfermeros
  set estatus_verificacion = 'verificado',
      publicado            = p_publicar,
      -- La cedula se da por validada cuando su documento quedo aprobado
      cedula_verificada    = exists (
        select 1 from public.documentos d
        where d.enfermero_id = p_id
          and d.tipo = 'cedula_profesional'
          and d.estatus = 'verificado'
      )
  where id = p_id;

  return public.expediente_enfermero(p_id);
end;
$$;

-- Quitar del catalogo sin borrar nada
create or replace function public.despublicar_enfermero(p_id uuid, p_motivo text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.es_staff_estricto() then
    raise exception 'Solo el personal de la agencia puede despublicar perfiles'
      using errcode = '42501';
  end if;

  update public.enfermeros
  set publicado = false,
      notas_internas = case
        when coalesce(trim(p_motivo), '') = '' then notas_internas
        else coalesce(notas_internas || E'\n', '') ||
             to_char(now(), 'DD/MM/YYYY') || ' - Despublicado: ' || trim(p_motivo)
      end
  where id = p_id;
end;
$$;

revoke all on function public.documentos_bandeja(estatus_verif, uuid) from public;
revoke all on function public.expediente_enfermero(uuid)              from public;
revoke all on function public.revisar_documento(uuid, boolean, text)  from public;
revoke all on function public.verificar_enfermero(uuid, boolean)      from public;
revoke all on function public.despublicar_enfermero(uuid, text)       from public;

grant execute on function public.documentos_bandeja(estatus_verif, uuid) to authenticated;
grant execute on function public.expediente_enfermero(uuid)              to authenticated;
grant execute on function public.revisar_documento(uuid, boolean, text)  to authenticated;
grant execute on function public.verificar_enfermero(uuid, boolean)      to authenticated;
grant execute on function public.despublicar_enfermero(uuid, text)       to authenticated;
