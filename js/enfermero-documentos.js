/* ==========================================================================
   Enlace Enfermero — Mis documentos
   Subir, ver y renovar el expediente (CLAUDE.md 8.7).

   Dos reglas que la base impone y aquí sólo se acompañan:
   - El archivo tiene que vivir en Storage bajo `<enfermero_id>/`. La policy
     del bucket lo exige y subir_mi_documento() lo vuelve a comprobar.
   - El enfermero nunca cambia el estatus de un documento. Al renovar, la
     función lo regresa a 'pendiente' para que la agencia lo revise otra vez.
   ========================================================================== */

/* Tamaño máximo por archivo. El plan de Storage da ~10 MB por profesional:
   sin un tope, tres fotos de celular llenan la cuota de una persona. */
const MAX_MB = 5;

let miFicha = null;   // id en `enfermeros`, necesario para armar la ruta

async function iniciarMisDocumentos() {
  const { datos, error } = await consultar(db.rpc('mi_enfermero_id'));
  if (error || !datos) {
    document.getElementById('listaDocumentos').innerHTML =
      `<div class="tarjeta">${estadoVacio({
        icono: 'alerta',
        titulo: 'No encontramos tu expediente',
        texto: 'Tu cuenta no está ligada a un perfil profesional. Escríbenos.'
      })}</div>`;
    return;
  }
  miFicha = datos;
  cargarDocumentos();
}

async function cargarDocumentos() {
  const zona = document.getElementById('listaDocumentos');
  zona.innerHTML = '<div class="spinner"></div>';

  const { datos, error } = await consultar(db.rpc('mis_documentos'));

  if (error) {
    zona.innerHTML = `<div class="tarjeta">${estadoVacio({
      icono: 'alerta', titulo: 'No pudimos cargar tus documentos', texto: error
    })}</div>`;
    return;
  }

  const docs = datos || [];
  pintarAvanceExpediente(docs);

  zona.innerHTML = `<div class="lista-documentos">
    ${docs.map(filaDocumento).join('')}
  </div>`;

  zona.querySelectorAll('[data-subir]').forEach(b =>
    b.addEventListener('click', () => abrirSubida(b.dataset.subir, b.dataset.nombre)));

  zona.querySelectorAll('[data-ver]').forEach(b =>
    b.addEventListener('click', () => abrirArchivo(b.dataset.ver)));
}

/** Barra con lo que lleva del expediente obligatorio. */
function pintarAvanceExpediente(docs) {
  const zona = document.getElementById('avanceExpediente');
  const obligatorios = docs.filter(d => d.obligatorio);
  const aprobados = obligatorios.filter(d => d.estatus === 'verificado');
  const pct = obligatorios.length
    ? Math.round((aprobados.length / obligatorios.length) * 100) : 0;
  const completo = pct >= 100;

  zona.innerHTML = `
    <div class="tarjeta-cabecera">
      <div>
        <h3>Expediente obligatorio</h3>
        <p class="texto-sm txt-secundario">
          ${completo
            ? 'Está completo. Nada te frena para que te propongan turnos.'
            : 'Sin estos documentos aprobados no podemos verificarte.'}
        </p>
      </div>
      <strong class="avance-pct">${pct}%</strong>
    </div>
    <div class="avance-barra" role="progressbar" aria-valuenow="${pct}"
         aria-valuemin="0" aria-valuemax="100" aria-label="Avance del expediente">
      <div class="avance-relleno${completo ? ' completo' : ''}" style="width:${pct}%"></div>
    </div>
    <p class="texto-sm txt-secundario">
      ${aprobados.length} de ${obligatorios.length} obligatorios aprobados
    </p>`;
}

/** Estado de vigencia en palabras y color. */
function vigencia(d) {
  if (d.fecha_vencimiento === null || d.dias_para_vencer === null) return '';
  const dias = Number(d.dias_para_vencer);

  if (dias < 0) {
    return `<span class="vigencia vencida">Venció ${esc(fechaCorta(d.fecha_vencimiento))}</span>`;
  }
  if (dias <= 30) {
    return `<span class="vigencia proxima">Vence en ${dias} ${dias === 1 ? 'día' : 'días'}</span>`;
  }
  return `<span class="vigencia">Vigente hasta ${esc(fechaCorta(d.fecha_vencimiento))}</span>`;
}

function filaDocumento(d) {
  const nombre = etiqueta(TIPOS_DOCUMENTO, d.tipo);
  const entregado = d.id !== null;

  // Un obligatorio sin entregar se lista igual, para que se vea el hueco
  const est = !entregado
    ? { nombre: 'Sin entregar', clase: 'badge-gris' }
    : (ESTATUS_VERIFICACION[d.estatus] || { nombre: d.estatus, clase: 'badge-gris' });

  const vencido = entregado && Number(d.dias_para_vencer) < 0;
  const necesitaAccion = !entregado || d.estatus === 'rechazado' || vencido;

  return `
    <article class="fila-documento${necesitaAccion ? ' doc-pendiente' : ''}">
      <span class="doc-icono">${icono('documento', 18)}</span>

      <div class="doc-datos">
        <strong>${esc(nombre)}${d.obligatorio ? ' <span class="marca-obligatorio" title="Obligatorio">*</span>' : ''}</strong>
        <span class="badge ${est.clase}">${esc(est.nombre)}</span>
        ${vigencia(d)}
        ${d.motivo_rechazo ? `<span class="doc-motivo">${esc(d.motivo_rechazo)}</span>` : ''}
      </div>

      <div class="doc-acciones">
        ${entregado ? `
          <button type="button" class="btn btn-fantasma btn-sm" data-ver="${esc(d.archivo_url)}">
            ${icono('ojo', 16)}<span class="solo-ancho">Ver</span>
          </button>` : ''}
        <button type="button" class="btn ${necesitaAccion ? 'btn-primario' : 'btn-secundario'} btn-sm"
                data-subir="${esc(d.tipo)}" data-nombre="${esc(nombre)}">
          ${entregado ? 'Renovar' : 'Subir'}
        </button>
      </div>
    </article>`;
}

/** Abre el archivo con una URL firmada de corta vida. */
async function abrirArchivo(rutaGuardada) {
  const ruta = String(rutaGuardada || '').replace(/^documentos\//, '');
  const { data, error } = await db.storage.from('documentos').createSignedUrl(ruta, 300);

  if (error || !data?.signedUrl) {
    return toast('No pudimos abrir el archivo. Vuelve a subirlo.', 'error');
  }
  window.open(data.signedUrl, '_blank', 'noopener');
}

/** Modal de carga: archivo, emisión y vencimiento. */
function abrirSubida(tipo, nombre) {
  abrirFormulario({
    titulo: `Subir ${nombre}`,
    textoGuardar: 'Subir documento',
    campos: [
      { nombre: 'archivo', etiqueta: 'Archivo', tipo: 'file', requerido: true,
        nota: `PDF o imagen, máximo ${MAX_MB} MB.` },
      { nombre: 'emision', etiqueta: 'Fecha de emisión', tipo: 'date', ancho: 'medio' },
      { nombre: 'vencimiento', etiqueta: 'Fecha de vencimiento', tipo: 'date', ancho: 'medio',
        nota: 'Déjala vacía si el documento no caduca.' }
    ],
    alGuardar: async (valores) => {
      const input = document.querySelector('#modalFormulario [name="archivo"]');
      const archivo = input?.files?.[0];

      if (!archivo) { toast('Elige un archivo.', 'error'); return false; }

      if (archivo.size > MAX_MB * 1024 * 1024) {
        toast(`El archivo pesa más de ${MAX_MB} MB. Comprímelo e inténtalo de nuevo.`, 'error');
        return false;
      }

      const ext = (archivo.name.split('.').pop() || 'pdf').toLowerCase();
      if (!['pdf', 'jpg', 'jpeg', 'png', 'webp'].includes(ext)) {
        toast('Solo aceptamos PDF o imagen.', 'error');
        return false;
      }

      // La ruta DEBE empezar con el id de la ficha: la policy del bucket
      // compara la primera carpeta contra mi_enfermero_id().
      const ruta = `${miFicha}/${tipo}-${Date.now()}.${ext}`;

      const { error: errSubida } = await db.storage
        .from('documentos').upload(ruta, archivo, { upsert: false });

      if (errSubida) {
        toast(`No se pudo subir: ${errSubida.message}`, 'error');
        return false;
      }

      const { datos, error } = await consultar(db.rpc('subir_mi_documento', {
        p_tipo: tipo,
        p_archivo_url: `documentos/${ruta}`,
        p_emision: valores.emision || null,
        p_vencimiento: valores.vencimiento || null
      }));

      if (error) {
        // El archivo ya subió pero el registro falló: se limpia para no dejar
        // basura ocupando la cuota del profesional.
        await db.storage.from('documentos').remove([ruta]);
        toast(error, 'error');
        return false;
      }

      toast(datos?.mensaje || 'Documento recibido.', 'exito');
      cargarDocumentos();
    }
  });
}
