/* ==========================================================================
   Enlace Enfermero — Mi perfil profesional
   Edita lo que aparece en el catálogo público.

   Sólo se muestran los campos que el profesional REALMENTE puede cambiar.
   El trigger proteger_campos_enfermero le revierte en silencio verificación,
   publicación, tarifas, calificación y notas internas (regla 10.6); pintar
   esos campos en el formulario sería ofrecerle algo que la base va a deshacer.
   ========================================================================== */

/* Los campos editables, en el orden en que conviene llenarlos. */
const CAMPOS_PERFIL = [
  { nombre: 'bio', etiqueta: 'Tu presentación', tipo: 'textarea',
    ayuda: 'Cuéntale al cliente quién eres y qué sabes hacer. Mínimo 80 caracteres.',
    max: 600 },
  { nombre: 'anios_experiencia', etiqueta: 'Años de experiencia', tipo: 'number',
    min: 0, ancho: 'medio' },
  { nombre: 'fecha_nacimiento', etiqueta: 'Fecha de nacimiento', tipo: 'date',
    ancho: 'medio' },
  { nombre: 'institucion_egreso', etiqueta: 'Institución donde estudiaste', tipo: 'text' },
  { nombre: 'especialidades', etiqueta: 'Tus especialidades', tipo: 'checks',
    opciones: ESPECIALIDADES },
  { nombre: 'certificaciones', etiqueta: 'Tus certificaciones', tipo: 'checks',
    opciones: CERTIFICACIONES,
    nota: 'Sólo marca las que puedas respaldar con documento: la agencia las verifica.' },
  { nombre: 'idiomas', etiqueta: 'Idiomas que hablas', tipo: 'checks',
    opciones: IDIOMAS },
  { nombre: 'zonas_cobertura', etiqueta: 'Zonas donde puedes trabajar', tipo: 'checks',
    opciones: MUNICIPIOS },
  { nombre: 'acepta_domicilio', etiqueta: 'Acepto cuidado en domicilio particular', tipo: 'checkbox' },
  { nombre: 'acepta_nocturno',  etiqueta: 'Acepto turnos nocturnos', tipo: 'checkbox' },
  { nombre: 'acepta_foraneo',   etiqueta: 'Acepto salir de la zona metropolitana', tipo: 'checkbox' },
  { nombre: 'disponible_inmediato', etiqueta: 'Estoy disponible de inmediato', tipo: 'checkbox',
    nota: 'Te pone al frente de la lista cuando hay una urgencia.' }
];

let perfilActual = null;

async function iniciarMiPerfil() {
  const { datos, error } = await consultar(
    db.from('enfermeros')
      .select('id, folio, nombre_completo, nivel, cedula_profesional, bio, ' +
              'anios_experiencia, fecha_nacimiento, institucion_egreso, ' +
              'especialidades, certificaciones, idiomas, zonas_cobertura, ' +
              'acepta_domicilio, acepta_nocturno, acepta_foraneo, ' +
              'disponible_inmediato, estatus_verificacion, publicado')
      .limit(1)
      .maybeSingle()
  );

  if (error || !datos) {
    document.getElementById('camposPerfil').innerHTML = estadoVacio({
      icono: 'alerta',
      titulo: 'No pudimos cargar tu perfil',
      texto: error || 'Tu cuenta no está ligada a un perfil profesional.'
    });
    return;
  }

  perfilActual = datos;
  pintarAvance();
  pintarFormulario();
}

/** Reusa el mismo cálculo de avance que la pantalla de inicio. */
async function pintarAvance() {
  const zona = document.getElementById('avancePerfil');
  const { datos } = await consultar(db.rpc('panel_enfermero_resumen'));
  const p = datos?.perfil;
  if (!p) { zona.remove(); return; }

  const completo = p.pct >= 100;
  zona.innerHTML = `
    <div class="tarjeta-cabecera">
      <div>
        <h3>${esc(perfilActual.nombre_completo)}</h3>
        <p class="texto-sm txt-secundario">
          ${esc(perfilActual.folio)} · ${esc(etiqueta(NIVELES, perfilActual.nivel))}
        </p>
      </div>
      <strong class="avance-pct">${p.pct}%</strong>
    </div>
    <div class="avance-barra" role="progressbar" aria-valuenow="${p.pct}"
         aria-valuemin="0" aria-valuemax="100" aria-label="Avance de tu perfil">
      <div class="avance-relleno${completo ? ' completo' : ''}" style="width:${p.pct}%"></div>
    </div>
    ${p.faltantes?.length ? `
      <div class="faltantes">
        ${icono('alerta', 16)}
        <span>Te falta: ${p.faltantes.map(f => esc(f)).join(', ')}.</span>
      </div>` : ''}

    <p class="nota-bloqueada">
      ${icono('candado', 15)}
      Tu nivel, tu cédula, tus tarifas y tu verificación los administra la
      agencia. Si algo de eso cambió, escríbenos.
    </p>`;
}

function control(c, v) {
  switch (c.tipo) {
    case 'textarea':
      return `<textarea id="p_${c.nombre}" name="${c.nombre}"
        maxlength="${c.max || 600}" rows="5"
        placeholder="${esc(c.ayuda || '')}">${esc(v || '')}</textarea>`;

    case 'checkbox':
      return `<label class="check">
        <input type="checkbox" name="${c.nombre}" ${v ? 'checked' : ''}>
        <span>${esc(c.etiqueta)}</span></label>`;

    case 'checks': {
      const marcados = Array.isArray(v) ? v : [];

      // Si la base guarda un valor que no está en el catálogo, se pinta igual
      // como casilla marcada. Sin esto, guardar el formulario lo borraría en
      // silencio: la casilla nunca se marcó, así que al recolectar no aparece.
      // Ya pasó con los idiomas, que se guardaban como 'Español' y no como
      // 'espanol'. Mostrarlo también deja ver la inconsistencia en vez de
      // taparla.
      const desconocidos = marcados
        .filter(x => !c.opciones.some(o => o.id === x))
        .map(x => ({ id: x, nombre: x, fuera: true }));

      return `<div class="lista-checks lista-checks-corta">
        ${[...c.opciones, ...desconocidos].map(o => `<label class="check${o.fuera ? ' check-fuera' : ''}">
          <input type="checkbox" name="${c.nombre}" value="${esc(o.id)}"
            ${marcados.includes(o.id) ? 'checked' : ''}>
          <span>${esc(o.nombre)}${o.fuera ? ' (fuera de catálogo)' : ''}</span></label>`).join('')}
      </div>`;
    }

    default:
      return `<input type="${c.tipo}" id="p_${c.nombre}" name="${c.nombre}"
        value="${esc(v ?? '')}" ${c.min !== undefined ? `min="${c.min}"` : ''}
        placeholder="${esc(c.ayuda || '')}">`;
  }
}

function pintarFormulario() {
  document.getElementById('camposPerfil').innerHTML = `
    ${CAMPOS_PERFIL.map(c => `
      <div class="campo ${c.ancho === 'medio' ? 'campo-medio' : ''}">
        ${c.tipo === 'checkbox' ? '' :
          `<label for="p_${c.nombre}">${esc(c.etiqueta)}</label>`}
        ${control(c, perfilActual[c.nombre])}
        ${c.nota ? `<span class="ayuda">${esc(c.nota)}</span>` : ''}
      </div>`).join('')}

    <div class="form-acciones">
      <button type="submit" class="btn btn-primario" id="btnGuardarPerfil">
        Guardar cambios
      </button>
    </div>`;

  document.getElementById('formPerfil')
    .addEventListener('submit', guardarPerfil);
}

async function guardarPerfil(e) {
  e.preventDefault();
  const form  = e.target;
  const boton = document.getElementById('btnGuardarPerfil');
  const datos = {};

  CAMPOS_PERFIL.forEach(c => {
    if (c.tipo === 'checks') {
      datos[c.nombre] = [...form.querySelectorAll(`[name="${c.nombre}"]:checked`)]
        .map(i => i.value);
    } else if (c.tipo === 'checkbox') {
      datos[c.nombre] = form.querySelector(`[name="${c.nombre}"]`).checked;
    } else {
      const valor = form.querySelector(`[name="${c.nombre}"]`).value.trim();
      // Un campo vacío se guarda como nulo, no como cadena vacía: si no, un
      // "" cuenta como capturado y el avance del perfil mentiría.
      datos[c.nombre] = valor === '' ? null
        : (c.tipo === 'number' ? Number(valor) : valor);
    }
  });

  if (datos.bio && datos.bio.length < 80) {
    toast('Tu presentación necesita al menos 80 caracteres para decir algo.', 'error');
    return;
  }

  boton.classList.add('cargando');
  boton.disabled = true;

  const { error } = await consultar(
    db.from('enfermeros').update(datos).eq('id', perfilActual.id)
  );

  boton.classList.remove('cargando');
  boton.disabled = false;

  if (error) return toast(error, 'error');

  toast('Perfil actualizado.', 'exito');
  Object.assign(perfilActual, datos);
  pintarAvance();
}
