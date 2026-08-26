/* ==========================================================================
   Enlace Enfermero — Paginas publicas
   Capa de datos del sitio abierto y logica de la landing.

   Regla de oro: el sitio publico SOLO lee de la vista `enfermeros_publico`.
   Nunca consulta la tabla `enfermeros`, que contiene tarifas netas, cedula
   completa, telefono y notas internas (CLAUDE.md 6).
   ========================================================================== */

/* ==========================================================================
   CAPA DE DATOS
   Si aun no hay credenciales de Supabase, se usa js/datos-demo.js para poder
   revisar el sitio. En cuanto se capturan, todo sale de la base.
   ========================================================================== */

const usandoDemo = () => !supabaseListo() && typeof DATOS_DEMO !== 'undefined';

/**
 * Consulta el catalogo publico.
 * @param {object} filtros nivel, especialidades[], municipio, disponible,
 *                         experienciaMin, calificacionMin, nocturno, domicilio, texto
 * @param {object} opciones orden, limite, desde
 * @returns {Promise<{datos: array, total: number, error: string|null}>}
 */
async function buscarEnfermeros(filtros = {}, opciones = {}) {
  const { orden = 'relevancia', limite = CONFIG.ITEMS_POR_PAGINA, desde = 0 } = opciones;

  if (usandoDemo()) {
    return filtrarEnDemo(filtros, orden, limite, desde);
  }
  if (!supabaseListo()) {
    return { datos: [], total: 0, error: 'Aún no se ha conectado la base de datos.' };
  }

  let consulta = db.from('enfermeros_publico').select('*', { count: 'exact' });

  if (filtros.nivel)      consulta = consulta.eq('nivel', filtros.nivel);
  if (filtros.disponible) consulta = consulta.eq('disponible_inmediato', true);
  if (filtros.nocturno)   consulta = consulta.eq('acepta_nocturno', true);
  if (filtros.domicilio)  consulta = consulta.eq('acepta_domicilio', true);
  if (filtros.experienciaMin)  consulta = consulta.gte('anios_experiencia', filtros.experienciaMin);
  if (filtros.calificacionMin) consulta = consulta.gte('calificacion_promedio', filtros.calificacionMin);
  // `contains` sobre text[]: el perfil debe cubrir TODAS las especialidades pedidas
  if (filtros.especialidades?.length) consulta = consulta.contains('especialidades', filtros.especialidades);
  if (filtros.municipio)  consulta = consulta.contains('zonas_cobertura', [filtros.municipio]);
  if (filtros.texto)      consulta = consulta.ilike('nombre_completo', `%${filtros.texto}%`);

  consulta = aplicarOrden(consulta, orden).range(desde, desde + limite - 1);

  const { data, error, count } = await consulta;
  if (error) return { datos: [], total: 0, error: traducirError(error) };
  return { datos: data || [], total: count ?? 0, error: null };
}

function aplicarOrden(consulta, orden) {
  switch (orden) {
    case 'calificacion': return consulta.order('calificacion_promedio', { ascending: false, nullsFirst: false });
    case 'experiencia':  return consulta.order('anios_experiencia', { ascending: false });
    case 'disponibles':  return consulta.order('disponible_inmediato', { ascending: false })
                                        .order('calificacion_promedio', { ascending: false, nullsFirst: false });
    default:             return consulta.order('disponible_inmediato', { ascending: false })
                                        .order('calificacion_promedio', { ascending: false, nullsFirst: false })
                                        .order('total_servicios', { ascending: false });
  }
}

/** Mismos filtros que arriba, resueltos en memoria sobre los datos de demo. */
function filtrarEnDemo(filtros, orden, limite, desde) {
  let lista = [...DATOS_DEMO.enfermeros];

  if (filtros.nivel)      lista = lista.filter(e => e.nivel === filtros.nivel);
  if (filtros.disponible) lista = lista.filter(e => e.disponible_inmediato);
  if (filtros.nocturno)   lista = lista.filter(e => e.acepta_nocturno);
  if (filtros.domicilio)  lista = lista.filter(e => e.acepta_domicilio);
  if (filtros.experienciaMin)  lista = lista.filter(e => e.anios_experiencia >= filtros.experienciaMin);
  if (filtros.calificacionMin) lista = lista.filter(e => (e.calificacion_promedio || 0) >= filtros.calificacionMin);
  if (filtros.especialidades?.length) {
    lista = lista.filter(e => filtros.especialidades.every(id => (e.especialidades || []).includes(id)));
  }
  if (filtros.municipio) lista = lista.filter(e => (e.zonas_cobertura || []).includes(filtros.municipio));
  if (filtros.texto) {
    const t = filtros.texto.toLowerCase();
    lista = lista.filter(e =>
      e.nombre_completo.toLowerCase().includes(t) ||
      (e.especialidades  || []).some(id => etiqueta(ESPECIALIDADES,  id).toLowerCase().includes(t)) ||
      (e.certificaciones || []).some(id => etiqueta(CERTIFICACIONES, id).toLowerCase().includes(t)));
  }

  const porCalificacion = (a, b) => (b.calificacion_promedio || 0) - (a.calificacion_promedio || 0);
  if (orden === 'calificacion')      lista.sort(porCalificacion);
  else if (orden === 'experiencia')  lista.sort((a, b) => b.anios_experiencia - a.anios_experiencia);
  else lista.sort((a, b) => (b.disponible_inmediato - a.disponible_inmediato)
                            || porCalificacion(a, b)
                            || (b.total_servicios - a.total_servicios));

  return { datos: lista.slice(desde, desde + limite), total: lista.length, error: null };
}

/** Un perfil del catalogo publico por su id. */
async function obtenerEnfermero(id) {
  if (usandoDemo()) {
    const perfil = DATOS_DEMO.enfermeros.find(e => e.id === id);
    return { datos: perfil || null, error: perfil ? null : 'No encontramos a esta persona.' };
  }
  if (!supabaseListo()) return { datos: null, error: 'Aún no se ha conectado la base de datos.' };

  const { data, error } = await db.from('enfermeros_publico').select('*').eq('id', id).maybeSingle();
  if (error)  return { datos: null, error: traducirError(error) };
  if (!data)  return { datos: null, error: 'No encontramos a esta persona.' };
  return { datos: data, error: null };
}

/** Evaluaciones publicas, para los testimonios de la landing y el perfil. */
async function obtenerEvaluaciones(enfermeroId = null, limite = 6) {
  if (usandoDemo()) {
    const lista = enfermeroId
      ? DATOS_DEMO.evaluaciones.filter(e => e.enfermero_id === enfermeroId)
      : DATOS_DEMO.evaluaciones;
    return { datos: lista.slice(0, limite), error: null };
  }
  if (!supabaseListo()) return { datos: [], error: null };

  // Se trae tambien el nombre del profesional para poder firmar el testimonio
  let consulta = db.from('evaluaciones')
    .select('enfermero_id, calificacion_general, comentario, created_at, enfermeros_publico(nombre_completo)')
    .eq('publica', true)
    .not('comentario', 'is', null)
    .order('created_at', { ascending: false })
    .limit(limite);
  if (enfermeroId) consulta = consulta.eq('enfermero_id', enfermeroId);

  const { data, error } = await consulta;
  if (error) return { datos: [], error: traducirError(error) };

  // El join anida el perfil; se aplana para que las evaluaciones tengan la
  // misma forma vengan de la base o del archivo de demostracion.
  const datos = (data || []).map(ev => ({
    ...ev,
    enfermero_nombre: ev.enfermeros_publico?.nombre_completo || null
  }));

  return { datos, error: null };
}

/** Disponibilidad de los proximos dias de un perfil. */
async function obtenerDisponibilidad(enfermeroId, dias = 14) {
  if (usandoDemo()) return { datos: DATOS_DEMO.disponibilidad(enfermeroId, dias), error: null };
  if (!supabaseListo()) return { datos: [], error: null };

  const hasta = new Date();
  hasta.setDate(hasta.getDate() + dias);

  const { data, error } = await db.from('disponibilidad')
    .select('fecha, turno, disponible')
    .eq('enfermero_id', enfermeroId)
    .eq('disponible', true)
    .gte('fecha', hoyISO())
    .lte('fecha', hasta.toISOString().slice(0, 10))
    .order('fecha');

  return { datos: data || [], error: error ? traducirError(error) : null };
}

/** Metricas de la barra de confianza de la landing. */
async function obtenerMetricas() {
  if (usandoDemo()) {
    const lista = DATOS_DEMO.enfermeros;
    const servicios = lista.reduce((suma, e) => suma + (e.total_servicios || 0), 0);
    const promedio = lista.reduce((suma, e) => suma + (e.calificacion_promedio || 0), 0) / lista.length;
    return { verificados: lista.length, servicios, promedio };
  }
  if (!supabaseListo()) return null;

  const { data, error } = await db.from('enfermeros_publico')
    .select('calificacion_promedio, total_servicios');
  if (error || !data?.length) return null;

  return {
    verificados: data.length,
    servicios: data.reduce((suma, e) => suma + (e.total_servicios || 0), 0),
    promedio: data.reduce((suma, e) => suma + (e.calificacion_promedio || 0), 0) / data.length
  };
}

/* ==========================================================================
   LANDING
   ========================================================================== */

/** Contadores animados de la barra de confianza. */
function animarContador(elemento, destino, decimales = 0, sufijo = '') {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    elemento.textContent = destino.toFixed(decimales) + sufijo;
    return;
  }
  const duracion = 1200;
  const inicio = performance.now();
  const final = destino.toFixed(decimales) + sufijo;

  const paso = (ahora) => {
    const avance = Math.min((ahora - inicio) / duracion, 1);
    // easeOutCubic: arranca rapido y frena al final
    const suave = 1 - Math.pow(1 - avance, 3);
    elemento.textContent = (destino * suave).toFixed(decimales) + sufijo;
    if (avance < 1) requestAnimationFrame(paso);
  };
  requestAnimationFrame(paso);

  // Red de seguridad: si el navegador pausa requestAnimationFrame (pestana en
  // segundo plano), el contador se quedaria en un valor intermedio erroneo.
  setTimeout(() => { elemento.textContent = final; }, duracion + 150);
}

async function cargarMetricas() {
  const zona = document.getElementById('metricas');
  if (!zona) return;

  const m = await obtenerMetricas();
  if (!m) return;   // sin datos, se quedan los guiones del HTML

  const valores = {
    verificados: [m.verificados, 0, ''],
    servicios:   [m.servicios, 0, ''],
    promedio:    [m.promedio, 1, ''],
    respuesta:   [24, 0, ' h']
  };

  // Los contadores arrancan cuando la barra entra en pantalla
  const arrancar = () => Object.entries(valores).forEach(([clave, [valor, dec, suf]]) => {
    const el = zona.querySelector(`[data-metrica="${clave}"]`);
    if (el) animarContador(el, valor, dec, suf);
  });

  if (!('IntersectionObserver' in window)) return arrancar();

  let arrancados = false;
  const arrancarUnaVez = () => {
    if (arrancados) return;
    arrancados = true;
    arrancar();
  };

  const observador = new IntersectionObserver((entradas) => {
    if (entradas[0].isIntersecting) { arrancarUnaVez(); observador.disconnect(); }
  }, { threshold: 0.4 });
  observador.observe(zona);

  // Si el observador no responde, los contadores se quedarian en un guion.
  setTimeout(() => {
    const r = zona.getBoundingClientRect();
    if (r.top < window.innerHeight && r.bottom > 0) arrancarUnaVez();
  }, 1500);
}

/** Personal destacado: los 6 mejor calificados. */
async function cargarDestacados() {
  const zona = document.getElementById('destacados');
  if (!zona) return;

  zona.innerHTML = esqueletoTarjetas(3);
  const { datos, error } = await buscarEnfermeros({}, { orden: 'calificacion', limite: 6 });

  if (error || !datos.length) {
    zona.innerHTML = estadoVacio({
      icono: 'usuarios',
      titulo: 'Estamos preparando el catálogo',
      texto: 'En cuanto tengamos personal publicado aparecerá aquí. Mientras tanto, cuéntanos qué necesitas y lo buscamos por ti.',
      boton: { href: 'solicitar.html', texto: 'Solicitar personal' }
    });
    return;
  }
  zona.innerHTML = datos.map(e => tarjetaEnfermero(e)).join('');
  sincronizarBotonesSeleccion();
}

/** Testimonios reales tomados de las evaluaciones publicas. */
async function cargarTestimonios() {
  const zona = document.getElementById('testimonios');
  if (!zona) return;

  const { datos } = await obtenerEvaluaciones(null, 3);
  const conComentario = datos.filter(e => e.comentario);

  if (!conComentario.length) {
    zona.closest('section')?.classList.add('oculto');
    return;
  }

  // Cinco estrellas, rellenas hasta la calificacion recibida
  const estrellasFila = (valor) => {
    const svg = (relleno) => `<svg width="16" height="16" viewBox="0 0 24 24"
      fill="${relleno ? 'currentColor' : 'none'}" stroke="currentColor" stroke-width="1.5"
      aria-hidden="true">${ICONOS.estrella}</svg>`;
    return `<div class="estrellas-fila" role="img" aria-label="${valor} de 5 estrellas">
      ${[1, 2, 3, 4, 5].map(n => svg(n <= valor)).join('')}
    </div>`;
  };

  zona.innerHTML = conComentario.map(ev => `
    <blockquote class="tarjeta testimonio aparece">
      ${estrellasFila(ev.calificacion_general)}
      <p>&ldquo;${esc(ev.comentario)}&rdquo;</p>
      <footer class="texto-sm txt-secundario">
        Sobre <strong>${esc(ev.enfermero_nombre || 'nuestro personal')}</strong>
        ${ev.cliente ? ' &middot; ' + esc(ev.cliente) : ''}
      </footer>
    </blockquote>`).join('');

  activarAparicion();
}

/** Chips de especialidad que llevan al catalogo ya filtrado. */
function pintarEspecialidades() {
  const zona = document.getElementById('chipsEspecialidades');
  if (!zona) return;
  zona.innerHTML = ESPECIALIDADES.map(e =>
    `<a href="enfermeros.html?esp=${e.id}" class="chip chip-boton">${esc(e.nombre)}</a>`).join('');
}

/** Mini-buscador del hero: arma la URL del catalogo con los filtros puestos. */
function activarBuscadorHero() {
  const form = document.getElementById('buscadorHero');
  if (!form) return;

  const selNivel = form.querySelector('[name="nivel"]');
  const selMun   = form.querySelector('[name="municipio"]');
  selNivel.innerHTML = '<option value="">Cualquier nivel</option>' +
    NIVELES.map(n => `<option value="${n.id}">${esc(n.nombre)}</option>`).join('');
  selMun.innerHTML = '<option value="">Todos los municipios</option>' +
    MUNICIPIOS.map(m => `<option value="${m.id}">${esc(m.nombre)}</option>`).join('');

  form.addEventListener('submit', (evento) => {
    evento.preventDefault();
    const params = new URLSearchParams();
    if (selNivel.value) params.set('nivel', selNivel.value);
    if (selMun.value)   params.set('municipio', selMun.value);
    const desde = form.querySelector('[name="fecha"]').value;
    if (desde) params.set('desde', desde);
    window.location.href = 'enfermeros.html' + (params.toString() ? '?' + params : '');
  });
}

/** Acordeon accesible de preguntas frecuentes. */
function activarAcordeones() {
  document.querySelectorAll('.acordeon-boton').forEach(boton => {
    boton.addEventListener('click', () => {
      const abierto = boton.getAttribute('aria-expanded') === 'true';
      boton.setAttribute('aria-expanded', String(!abierto));
      document.getElementById(boton.getAttribute('aria-controls'))
              ?.classList.toggle('abierto', !abierto);
    });
  });
}

/** Alterna los pasos de "Cómo funciona" entre cliente y enfermero. */
function activarPasos() {
  const botones = document.querySelectorAll('[data-pasos]');
  if (!botones.length) return;

  botones.forEach(boton => boton.addEventListener('click', () => {
    const objetivo = boton.dataset.pasos;
    botones.forEach(b => {
      const activo = b === boton;
      b.classList.toggle('activo', activo);
      b.setAttribute('aria-selected', String(activo));
    });
    document.querySelectorAll('[data-panel-pasos]').forEach(panel => {
      panel.classList.toggle('oculto', panel.dataset.panelPasos !== objetivo);
    });
  }));
}

/** Arranque de la landing. */
function iniciarLanding() {
  activarHeroCarrusel();
  activarBuscadorHero();
  activarAsesor();
  pintarEspecialidades();
  activarAcordeones();
  activarPasos();
  activarSeleccion();
  cargarMetricas();
  cargarDestacados();
  cargarTestimonios();

  // Aviso visible mientras el sitio corre con datos de demostracion
  if (usandoDemo()) {
    document.getElementById('avisoDemo')?.classList.remove('oculto');
  }
}

/* ==========================================================================
   ASESOR DE CASO — index.html (CLAUDE.md 8.1)

   El cliente describe su situacion con sus palabras y aqui se traduce a los
   campos con los que ya trabaja el catalogo: nivel, especialidad, entorno y
   turno. Todo ocurre en el navegador: el texto no viaja a ningun lado ni se
   guarda, porque casi siempre trae datos de salud de un tercero (LFPDPPP) y
   en este punto del recorrido todavia no hay consentimiento.

   Esto NO es el agente conversacional de la Fase 4. Ese necesita la Claude
   API detras de un backend, porque la llave no puede vivir en el frontend.
   Esto es coincidencia por palabras; cuando llegue el agente real se
   sustituye analizarCaso() y la interfaz no se toca.
   ========================================================================== */

/** Minusculas y sin acentos, para que "cirugía" y "cirugia" pesen igual. */
function sinAcentos(texto) {
  return (texto || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

/* Señales de urgencia clinica. Si aparece una, el asesor NO recomienda a
   nadie: manda al 911. La agencia coloca personal, no da atencion medica
   (CLAUDE.md 11), y esa linea no se cruza ni para "orientar". */
const ASESOR_URGENCIA = [
  'no respira', 'no puede respirar', 'se esta ahogando', 'dificultad para respirar',
  'convulsion', 'convulsionando', 'ataque epileptico',
  'infarto', 'paro cardiaco', 'dolor en el pecho', 'derrame', 'embolia',
  'sangrado abundante', 'hemorragia', 'sangra mucho',
  'inconsciente', 'no responde', 'se desmayo', 'perdio el conocimiento',
  'intoxicacion', 'envenenamiento', 'sobredosis', 'se quiere matar', 'suicid'
];

/* Especialidades. Se elige la de mayor puntaje: pedir dos a la vez estrecha
   demasiado, porque el catalogo exige que el perfil cubra TODAS las pedidas. */
const ASESOR_ESPECIALIDAD = [
  { id: 'geriatria',       claves: ['adulto mayor', 'anciano', 'anciana', 'abuelit', 'abuelo', 'abuela', 'tercera edad', 'demencia', 'alzheimer', 'asilo', 'casa de retiro', 'postrado', 'edad avanzada', 'de 80', 'de 90'] },
  { id: 'paliativos',      claves: ['paliativ', 'fase terminal', 'enfermo terminal', 'ultimos dias', 'hospicio', 'sin tratamiento curativo'] },
  { id: 'postoperatorio',  claves: ['cirugia', 'operaron', 'operacion', 'postoperatorio', 'post operatorio', 'lo operaron', 'la operaron', 'salio de quirofano', 'reciente operacion'] },
  { id: 'heridas',         claves: ['herida', 'curacion', 'curaciones', 'ulcera', 'escara', 'llaga', 'estoma', 'colostomia', 'pie diabetico'] },
  { id: 'oncologia',       claves: ['cancer', 'quimio', 'oncolog', 'tumor', 'radioterapia', 'leucemia'] },
  { id: 'nefrologia',      claves: ['dialisis', 'hemodialisis', 'riñon', 'rinon', 'insuficiencia renal', 'nefrolog'] },
  { id: 'cardiologia',     claves: ['del corazon', 'cardiac', 'cardiolog', 'marcapasos', 'insuficiencia cardiaca'] },
  { id: 'neonatologia',    claves: ['recien nacido', 'neonat', 'prematuro', 'cunero'] },
  { id: 'pediatria',       claves: ['mi hijo', 'mi hija', 'pediatr', 'el niño', 'la niña', 'el nino', 'la nina', 'menor de edad'] },
  { id: 'materno_infantil',claves: ['embaraz', 'parto', 'puerperio', 'lactancia', 'cesarea', 'recien parida'] },
  { id: 'uci',             claves: ['terapia intensiva', 'cuidados intensivos', 'uci', 'uti', 'ventilador', 'ventilacion mecanica', 'intubad', 'traqueo'] },
  { id: 'urgencias',       claves: ['area de urgencias', 'sala de urgencias', 'triage'] },
  { id: 'quirofano',       claves: ['quirofano', 'instrumentista', 'cirugias programadas'] },
  { id: 'salud_mental',    claves: ['psiquiatr', 'salud mental', 'depresion', 'esquizofren', 'bipolar', 'crisis de ansiedad'] },
  { id: 'rehabilitacion',  claves: ['rehabilitacion', 'fisioterapia', 'terapia fisica', 'fractura', 'protesis', 'volver a caminar'] },
  { id: 'medicina_interna',claves: ['diabet', 'hipertens', 'presion alta', 'epoc', 'enfermedad cronica'] }
];

/* Nivel requerido. Gana el primero de la lista que tenga coincidencia: el
   orden va de mayor a menor exigencia, porque un caso que menciona ventilador
   y tambien "acompañar" necesita al especialista, no al cuidador. */
const ASESOR_NIVEL = [
  { id: 'especialista', claves: ['ventilador', 'ventilacion', 'traqueo', 'intubad', 'dialisis', 'hemodialisis', 'cateter', 'via central', 'quimio', 'terapia intensiva', 'nutricion parenteral', 'bomba de infusion', 'sonda nasogastrica'] },
  { id: 'licenciado',   claves: ['medicament', 'intravenos', 'suero', 'inyec', 'sonda', 'curacion', 'curaciones', 'herida', 'oxigeno', 'nebuliz', 'insulina', 'glucosa', 'signos vitales'] },
  { id: 'general',      claves: ['toma de presion', 'control de medicamentos', 'monitoreo', 'vigilancia medica', 'pastillas'] },
  { id: 'cuidador',     claves: ['acompan', 'compañia', 'compania', 'bañar', 'banar', 'asear', 'aseo', 'alimentar', 'darle de comer', 'pasear', 'vigilar', 'hacerle compañia'] }
];

const ASESOR_ENTORNO = [
  { id: 'domicilio', claves: ['en casa', 'en su casa', 'en mi casa', 'a domicilio', 'domicilio', 'en el hogar', 'departamento', 'salio del hospital', 'lo dieron de alta', 'la dieron de alta', 'dado de alta'] },
  { id: 'hospital',  claves: ['hospital', 'clinica', 'sanatorio', 'hospitalizad', 'internado'] },
  { id: 'asilo',     claves: ['asilo', 'casa de retiro', 'residencia geriatrica'] }
];

const ASESOR_TURNO = [
  { id: 'guardia_24', claves: ['24 horas', 'dia y noche', 'todo el dia', 'tiempo completo', 'de planta'] },
  { id: 'nocturno',   claves: ['de noche', 'por la noche', 'nocturno', 'en la madrugada', 'turno de noche'] },
  { id: 'fin_semana', claves: ['fin de semana', 'sabado', 'domingo'] }
];

const ASESOR_PRISA = ['urgente', 'hoy mismo', 'para hoy', 'para mañana', 'para manana',
                      'lo antes posible', 'de inmediato', 'cuanto antes', 'esta noche', 'ya mismo'];

/** Traduce el caso en texto libre a los campos del catalogo. */
function analizarCaso(texto) {
  const t = sinAcentos(texto);
  const hay = (claves) => claves.some(k => t.includes(sinAcentos(k)));
  const puntaje = (claves) => claves.filter(k => t.includes(sinAcentos(k))).length;

  if (hay(ASESOR_URGENCIA)) return { urgenciaClinica: true };

  // Especialidad: la de mas coincidencias, y solo si hubo alguna
  let especialidad = '';
  let mejor = 0;
  ASESOR_ESPECIALIDAD.forEach(regla => {
    const p = puntaje(regla.claves);
    if (p > mejor) { mejor = p; especialidad = regla.id; }
  });

  const primero = (lista) => (lista.find(r => hay(r.claves)) || {}).id || '';

  return {
    urgenciaClinica: false,
    especialidad,
    nivel:     primero(ASESOR_NIVEL),
    entorno:   primero(ASESOR_ENTORNO),
    turno:     primero(ASESOR_TURNO),
    prisa:     hay(ASESOR_PRISA),
    municipio: (MUNICIPIOS.find(m => t.includes(sinAcentos(m.nombre))) || {}).id || '',
    señales:   [especialidad, primero(ASESOR_NIVEL), primero(ASESOR_ENTORNO)].filter(Boolean).length
  };
}

/** Agrega una burbuja al hilo y deja la vista al final. */
function asesorBurbuja(quien, html) {
  const hilo = document.getElementById('asesorHilo');
  const burbuja = document.createElement('div');
  burbuja.className = `asesor-burbuja asesor-${quien}`;
  burbuja.innerHTML = html;
  hilo.appendChild(burbuja);
  hilo.scrollTop = hilo.scrollHeight;
  return burbuja;
}

/** Ficha compacta: en el ancho del hilo no cabe la tarjeta completa. */
function asesorFicha(e) {
  const foto = e.foto_url
    ? `<img src="${esc(e.foto_url)}" alt="" loading="lazy">`
    : `<span class="inicial" aria-hidden="true">${esc(iniciales(e.nombre_completo))}</span>`;
  return `
    <a class="asesor-ficha" href="perfil.html?id=${encodeURIComponent(e.id)}">
      <span class="asesor-ficha-foto">${foto}</span>
      <span class="asesor-ficha-datos">
        <strong>${esc(e.nombre_completo)}</strong>
        <span class="texto-xs txt-secundario">
          ${esc(etiqueta(NIVELES, e.nivel))} &middot; ${esc(e.anios_experiencia)} años
          ${e.disponible_inmediato ? '&middot; <span class="txt-exito">disponible ya</span>' : ''}
        </span>
      </span>
      <span class="asesor-ficha-cal">★ ${Number(e.calificacion_promedio || 0).toFixed(1)}</span>
    </a>`;
}

/** Redacta la lectura del caso en una frase, solo con lo que si se detecto. */
function asesorLectura(l) {
  // El sujeto va siempre, aunque el caso no haya dicho el nivel: sin el, la
  // frase se queda coja ("necesitas para cobertura de turnos en institucion").
  const partes = [l.nivel
    ? `un perfil de <strong>${esc(etiqueta(NIVELES, l.nivel).toLowerCase())}</strong>`
    : '<strong>personal de enfermería verificado</strong>'];
  if (l.especialidad) partes.push(`con experiencia en <strong>${esc(etiqueta(ESPECIALIDADES, l.especialidad).toLowerCase())}</strong>`);
  if (l.entorno === 'domicilio') partes.push('para atención <strong>en domicilio</strong>');
  if (l.entorno === 'hospital')  partes.push('para <strong>cobertura de turnos en institución</strong>');
  if (l.entorno === 'asilo')     partes.push('para <strong>una casa de retiro o asilo</strong>');
  if (l.turno === 'nocturno')    partes.push('en <strong>turno nocturno</strong>');
  if (l.turno === 'guardia_24')  partes.push('en <strong>guardia de 24 horas</strong>');
  if (l.turno === 'fin_semana')  partes.push('en <strong>fin de semana</strong>');

  return partes.join(', ');
}

/** Busca en el catalogo aflojando filtros hasta encontrar algo que mostrar. */
async function asesorBuscar(l) {
  const intentos = [
    { nivel: l.nivel, especialidades: l.especialidad ? [l.especialidad] : [],
      domicilio: l.entorno === 'domicilio' || undefined,
      nocturno:  l.turno === 'nocturno' || undefined,
      municipio: l.municipio },
    { especialidades: l.especialidad ? [l.especialidad] : [] },
    { nivel: l.nivel },
    {}
  ];

  for (const filtros of intentos) {
    const limpio = Object.fromEntries(
      Object.entries(filtros).filter(([, v]) => v && (!Array.isArray(v) || v.length)));
    if (!Object.keys(limpio).length && filtros !== intentos[intentos.length - 1]) continue;

    const r = await buscarEnfermeros(limpio, { orden: 'calificacion', limite: 3 });
    if (r.error) return r;
    if (r.datos.length) return { ...r, exacto: filtros === intentos[0] };
  }
  return { datos: [], total: 0, error: null, exacto: false };
}

/** Enlace al catalogo con la lectura ya aplicada como filtros. */
function asesorEnlaceCatalogo(l) {
  const p = new URLSearchParams();
  if (l.nivel)        p.set('nivel', l.nivel);
  if (l.especialidad) p.set('esp', l.especialidad);
  if (l.municipio)    p.set('municipio', l.municipio);
  if (l.turno === 'nocturno')    p.set('nocturno', '1');
  if (l.entorno === 'domicilio') p.set('domicilio', '1');
  return 'enfermeros.html' + (p.toString() ? '?' + p : '');
}

/** Responde a un caso: lo lee, busca y propone. */
async function asesorResponder(texto) {
  asesorBurbuja('cliente', esc(texto));
  const lectura = analizarCaso(texto);

  // Primero lo que no se negocia: una urgencia no se atiende con una tarjeta
  if (lectura.urgenciaClinica) {
    asesorBurbuja('agencia alarma', `
      <p><strong>Eso suena a una urgencia médica.</strong></p>
      <p>Enlace Enfermero es una agencia de colocación de personal y no da
         atención médica. Llama al <strong>911</strong> o acude al servicio de
         urgencias más cercano ahora mismo.</p>
      <p>Cuando el paciente esté estable, aquí estamos para el cuidado que siga.</p>`);
    return;
  }

  if (lectura.señales === 0) {
    asesorBurbuja('agencia', `
      <p>Con eso todavía no alcanzo a ubicar el perfil. Ayúdame con tres datos:
         <strong>quién es el paciente</strong>, <strong>qué necesita</strong>
         (curaciones, medicamentos, acompañamiento…) y <strong>dónde</strong>
         sería el servicio.</p>`);
    return;
  }

  const pensando = asesorBurbuja('agencia',
    '<span class="asesor-puntos" aria-label="Buscando"><i></i><i></i><i></i></span>');

  const { datos, total, error, exacto } = await asesorBuscar(lectura);
  pensando.remove();

  if (error) {
    asesorBurbuja('agencia', `<p>${esc(error)} Vuelve a intentarlo en un momento,
      o cuéntanoslo por WhatsApp y lo revisamos contigo.</p>`);
    return;
  }

  const lecturaTexto = asesorLectura(lectura);
  const prisa = lectura.prisa
    ? ' Marcaste que corre prisa, así que lo atendemos con prioridad.'
    : '';

  if (!datos.length) {
    asesorBurbuja('agencia', `
      <p>Por lo que me cuentas necesitas ${lecturaTexto}.</p>
      <p>Ahora mismo no tengo a nadie con ese perfil publicado, pero eso no
         quiere decir que no lo consigamos: déjanos tu solicitud y lo buscamos
         por ti.${prisa}</p>
      <div class="asesor-acciones">
        <a href="solicitar.html" class="btn btn-primario btn-sm">Dejar mi solicitud</a>
      </div>`);
    return;
  }

  // El resultado y el aviso van en la misma frase: decir "encaja" y despues
  // "no es coincidencia exacta" se contradice y le resta credibilidad al resto.
  const veredicto = exacto
    ? `Tengo <strong>${total}</strong> ${total === 1 ? 'perfil que encaja' : 'perfiles que encajan'}.
       ${total === 1 ? 'Este es' : 'Estos son los mejor calificados'}:`
    : `No tengo una coincidencia exacta publicada, pero
       ${datos.length === 1 ? 'este es el perfil más cercano' : 'estos son los más cercanos'}:`;

  asesorBurbuja('agencia', `
    <p>Por lo que me cuentas necesitas ${lecturaTexto}.${prisa}</p>
    <p>${veredicto}</p>
    <div class="asesor-fichas">${datos.map(asesorFicha).join('')}</div>
    <div class="asesor-acciones">
      <a href="${asesorEnlaceCatalogo(lectura)}" class="btn btn-secundario btn-sm">Ver todos</a>
      <a href="solicitar.html" class="btn btn-primario btn-sm">Solicitar personal</a>
    </div>`);
}

/** Carrusel del hero. Lo que rota es la seccion completa —titulo, panel y
    tinte de fondo—, no un panel suelto. Avanza solo, se detiene cuando alguien
    esta mirando o navegando con teclado dentro, y no se mueve si el sistema
    pidio menos movimiento: ahi los puntos siguen sirviendo para cambiar a
    mano (CLAUDE.md 3.4, quinto uso del movimiento). */
function activarHeroCarrusel() {
  const zona = document.getElementById('heroCarrusel');
  if (!zona) return;

  const pista   = zona.querySelector('.hero-pista');
  const laminas = Array.from(pista.children);
  const puntos  = document.getElementById('heroPuntos');
  if (laminas.length < 2) return;

  let actual = 0;
  let reloj  = null;
  const quieto = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  puntos.innerHTML = laminas.map((lamina, i) => `
    <button type="button" class="hero-punto" role="tab"
            aria-selected="${i === 0}" aria-controls="${lamina.id}"
            aria-label="${esc(lamina.getAttribute('aria-label') || `Lámina ${i + 1}`)}"></button>`).join('');
  const botones = Array.from(puntos.children);

  const mostrar = (i) => {
    actual = (i + laminas.length) % laminas.length;
    pista.style.transform = `translateX(-${actual * 100}%)`;
    laminas.forEach((lamina, n) => {
      // La lamina fuera de vista sigue en el DOM: se oculta para que ni el
      // lector de pantalla ni el tabulador entren en algo que no se ve.
      lamina.toggleAttribute('aria-hidden', n !== actual);
      lamina.querySelectorAll('a').forEach(a => { a.tabIndex = n === actual ? 0 : -1; });
    });
    botones.forEach((b, n) => b.setAttribute('aria-selected', String(n === actual)));
  };

  const arrancar = () => {
    if (quieto || reloj) return;
    reloj = setInterval(() => mostrar(actual + 1), 6000);
  };
  const detener = () => { clearInterval(reloj); reloj = null; };

  botones.forEach((boton, i) => boton.addEventListener('click', () => {
    mostrar(i);
    detener();          // si ya eligio a mano, dejar de moverle debajo
  }));

  // Flechas para recorrerlo con teclado, como manda el patron de pestañas
  puntos.addEventListener('keydown', (evento) => {
    const paso = { ArrowRight: 1, ArrowLeft: -1 }[evento.key];
    if (!paso) return;
    evento.preventDefault();
    detener();
    mostrar(actual + paso);
    botones[actual].focus();
  });

  zona.addEventListener('mouseenter', detener);
  zona.addEventListener('mouseleave', arrancar);
  zona.addEventListener('focusin', detener);
  zona.addEventListener('focusout', (evento) => {
    if (!zona.contains(evento.relatedTarget)) arrancar();
  });

  // Fuera de pantalla no tiene sentido gastar cuadros de animacion
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(([entrada]) => entrada.isIntersecting ? arrancar() : detener())
      .observe(zona);
  } else {
    arrancar();
  }

  mostrar(0);
}

/** Arranque del asesor: saludo, ejemplos y envio. */
function activarAsesor() {
  const forma = document.getElementById('asesorForma');
  if (!forma) return;

  const campo = document.getElementById('asesorTexto');

  asesorBurbuja('agencia', `
    <p>Hola. Cuéntame qué necesitas y te digo qué perfil de enfermería te
       conviene, sin llenar formularios.</p>`);

  const EJEMPLOS = [
    'Mi papá de 78 años salió de cirugía y necesita curaciones en casa',
    'Busco quien acompañe a mi abuela de noche, en su casa',
    'Necesito cubrir turnos en mi clínica la próxima semana'
  ];
  const zona = document.getElementById('asesorEjemplos');
  zona.innerHTML = EJEMPLOS
    .map(e => `<button type="button" class="asesor-ejemplo">${esc(e)}</button>`).join('');

  const enviar = (texto) => {
    const limpio = (texto || '').trim();
    // Solo se ignora el vacio. Un "hola" si entra: lo atiende la rama de
    // señales insuficientes, que pide los datos que faltan. Descartarlo en
    // silencio dejaba al usuario picando Enter sin que pasara nada.
    if (!limpio) {
      campo.focus();
      return;
    }
    zona.classList.add('oculto');   // los ejemplos ya cumplieron su trabajo
    campo.value = '';
    asesorResponder(limpio);
  };

  zona.querySelectorAll('.asesor-ejemplo').forEach(boton =>
    boton.addEventListener('click', () => enviar(boton.textContent)));

  forma.addEventListener('submit', (evento) => {
    evento.preventDefault();
    enviar(campo.value);
  });

  // Enter envia, Shift+Enter hace salto de linea: es un chat, no un ensayo
  campo.addEventListener('keydown', (evento) => {
    if (evento.key === 'Enter' && !evento.shiftKey) {
      evento.preventDefault();
      enviar(campo.value);
    }
  });
}

/* ==========================================================================
   CATALOGO — enfermeros.html (CLAUDE.md 8.2)
   Los filtros se reflejan en la URL para que la busqueda sea compartible.
   ========================================================================== */

const catalogo = {
  filtros: {},
  orden: 'relevancia',
  pagina: 0,
  total: 0,
  cargando: false
};

/** Lee el estado inicial de los filtros desde la URL. */
function filtrosDesdeURL() {
  const p = new URLSearchParams(window.location.search);
  const lista = (clave) => (p.get(clave) || '').split(',').filter(Boolean);

  return {
    nivel:           p.get('nivel') || '',
    municipio:       p.get('municipio') || '',
    especialidades:  lista('esp'),
    disponible:      p.get('disponible') === '1',
    nocturno:        p.get('nocturno') === '1',
    domicilio:       p.get('domicilio') === '1',
    experienciaMin:  Number(p.get('exp')) || 0,
    calificacionMin: Number(p.get('cal')) || 0,
    texto:           p.get('q') || ''
  };
}

/** Vuelca los filtros vigentes en la barra de direcciones. */
function urlDesdeFiltros() {
  const f = catalogo.filtros;
  actualizarURL({
    nivel:      f.nivel,
    municipio:  f.municipio,
    esp:        f.especialidades,
    disponible: f.disponible ? '1' : '',
    nocturno:   f.nocturno   ? '1' : '',
    domicilio:  f.domicilio  ? '1' : '',
    exp:        f.experienciaMin  || '',
    cal:        f.calificacionMin || '',
    q:          f.texto,
    orden:      catalogo.orden === 'relevancia' ? '' : catalogo.orden
  });
}

/** Llena los controles del formulario de filtros con los catalogos. */
function pintarControlesFiltro() {
  const f = catalogo.filtros;

  const selNivel = document.getElementById('fNivel');
  selNivel.innerHTML = '<option value="">Cualquier nivel</option>' +
    NIVELES.map(n => `<option value="${n.id}">${esc(n.nombre)}</option>`).join('');
  selNivel.value = f.nivel;

  const selMun = document.getElementById('fMunicipio');
  selMun.innerHTML = '<option value="">Todos los municipios</option>' +
    MUNICIPIOS.map(m => `<option value="${m.id}">${esc(m.nombre)}</option>`).join('');
  selMun.value = f.municipio;

  document.getElementById('fEspecialidades').innerHTML = ESPECIALIDADES.map(e => `
    <label class="check">
      <input type="checkbox" name="esp" value="${e.id}"
             ${f.especialidades.includes(e.id) ? 'checked' : ''}>
      <span>${esc(e.nombre)}</span>
    </label>`).join('');

  document.getElementById('fBuscar').value = f.texto;
  document.getElementById('fDisponible').checked = f.disponible;
  document.getElementById('fNocturno').checked   = f.nocturno;
  document.getElementById('fDomicilio').checked  = f.domicilio;
  // Los deslizadores tienen paso fijo: un valor que venga de la URL puede no
  // ser representable (cal=4.8 con paso 0.5). Se ajusta al paso hacia abajo y
  // el filtro se queda con ese valor, para que control, ficha y resultado
  // digan siempre lo mismo.
  f.experienciaMin  = ajustarAlPaso(document.getElementById('fExperiencia'),  f.experienciaMin);
  f.calificacionMin = ajustarAlPaso(document.getElementById('fCalificacion'), f.calificacionMin);

  document.getElementById('fOrden').value = catalogo.orden;

  actualizarEtiquetasRango();
}

/** Baja el valor al paso del deslizador y lo deja puesto. Devuelve el aplicado. */
function ajustarAlPaso(control, valor) {
  const paso = Number(control.step) || 1;
  const max  = Number(control.max);
  const min  = Number(control.min);

  let ajustado = Math.floor(Number(valor) / paso) * paso;
  ajustado = Math.min(Math.max(ajustado, min), max);
  // El paso decimal arrastra error de punto flotante (4.5000000000000004)
  ajustado = Number(ajustado.toFixed(2));

  control.value = ajustado;
  return ajustado;
}

function actualizarEtiquetasRango() {
  const exp = Number(document.getElementById('fExperiencia').value);
  const cal = Number(document.getElementById('fCalificacion').value);
  document.getElementById('vExperiencia').textContent =
    exp ? `${exp}+ años` : 'Cualquiera';
  document.getElementById('vCalificacion').textContent =
    cal ? `${cal.toFixed(1)}+ estrellas` : 'Cualquiera';
}

/** Recoge lo que el usuario tiene puesto en el formulario. */
function leerControlesFiltro() {
  catalogo.filtros = {
    nivel:      document.getElementById('fNivel').value,
    municipio:  document.getElementById('fMunicipio').value,
    especialidades: [...document.querySelectorAll('input[name="esp"]:checked')].map(i => i.value),
    disponible: document.getElementById('fDisponible').checked,
    nocturno:   document.getElementById('fNocturno').checked,
    domicilio:  document.getElementById('fDomicilio').checked,
    experienciaMin:  Number(document.getElementById('fExperiencia').value) || 0,
    calificacionMin: Number(document.getElementById('fCalificacion').value) || 0,
    texto:      document.getElementById('fBuscar').value.trim()
  };
  catalogo.orden = document.getElementById('fOrden').value;
}

/** Consulta y pinta los resultados. `agregar` = boton "Cargar más". */
async function cargarCatalogo(agregar = false) {
  const zona = document.getElementById('resultados');
  if (!zona || catalogo.cargando) return;

  catalogo.cargando = true;
  if (!agregar) {
    catalogo.pagina = 0;
    zona.innerHTML = esqueletoTarjetas(6);
  }

  const { datos, total, error } = await buscarEnfermeros(catalogo.filtros, {
    orden: catalogo.orden,
    limite: CONFIG.ITEMS_POR_PAGINA,
    desde: catalogo.pagina * CONFIG.ITEMS_POR_PAGINA
  });

  catalogo.cargando = false;
  catalogo.total = total;

  if (error) {
    zona.innerHTML = estadoVacio({
      icono: 'alerta',
      titulo: 'No pudimos cargar el catálogo',
      texto: error,
      boton: { href: 'solicitar.html', texto: 'Déjanos tu solicitud' }
    });
    document.getElementById('conteo').textContent = '';
    document.getElementById('zonaCargarMas').innerHTML = '';
    return;
  }

  if (!agregar) zona.innerHTML = '';

  if (!datos.length && !agregar) {
    zona.innerHTML = estadoVacio({
      icono: 'buscar',
      titulo: 'No encontramos a nadie con esos filtros',
      texto: 'Prueba quitando alguno, o déjanos tu solicitud y lo buscamos por ti sin costo.',
      boton: { href: 'solicitar.html', texto: 'Déjanos tu solicitud y lo buscamos' }
    });
  } else {
    zona.insertAdjacentHTML('beforeend', datos.map(e => tarjetaEnfermero(e)).join(''));
    sincronizarBotonesSeleccion();
  }

  // Conteo y boton de cargar mas
  const mostrados = catalogo.pagina * CONFIG.ITEMS_POR_PAGINA + datos.length;
  document.getElementById('conteo').textContent = total
    ? `${total} ${total === 1 ? 'profesional disponible' : 'profesionales disponibles'}`
    : '';

  document.getElementById('zonaCargarMas').innerHTML = mostrados < total
    ? `<button type="button" class="btn btn-secundario btn-lg" id="btnCargarMas">
         Cargar más (${total - mostrados} restantes)
       </button>`
    : '';

  document.getElementById('btnCargarMas')?.addEventListener('click', () => {
    catalogo.pagina++;
    cargarCatalogo(true);
  });

  pintarFiltrosActivos();
}

/** Fichas de los filtros puestos, cada una con su boton para quitarla. */
function pintarFiltrosActivos() {
  const zona = document.getElementById('filtrosActivos');
  if (!zona) return;

  const f = catalogo.filtros;
  const activos = [];

  if (f.nivel)      activos.push(['nivel', etiqueta(NIVELES, f.nivel)]);
  if (f.municipio)  activos.push(['municipio', etiqueta(MUNICIPIOS, f.municipio)]);
  f.especialidades.forEach(id => activos.push([`esp:${id}`, etiqueta(ESPECIALIDADES, id)]));
  if (f.disponible) activos.push(['disponible', 'Disponible de inmediato']);
  if (f.nocturno)   activos.push(['nocturno', 'Acepta turno nocturno']);
  if (f.domicilio)  activos.push(['domicilio', 'Atiende a domicilio']);
  if (f.experienciaMin)  activos.push(['exp', `${f.experienciaMin}+ años`]);
  if (f.calificacionMin) activos.push(['cal', `${f.calificacionMin}+ estrellas`]);
  if (f.texto)      activos.push(['texto', `"${f.texto}"`]);

  zona.innerHTML = activos.length
    ? activos.map(([clave, texto]) => `
        <button type="button" class="ficha-filtro" data-quitar="${esc(clave)}">
          ${esc(texto)}
          <span aria-hidden="true">&times;</span>
          <span class="solo-lectores">Quitar filtro</span>
        </button>`).join('') +
      `<button type="button" class="btn btn-fantasma btn-sm" id="btnLimpiar">Limpiar todo</button>`
    : '';

  zona.querySelectorAll('[data-quitar]').forEach(boton => {
    boton.addEventListener('click', () => quitarFiltro(boton.dataset.quitar));
  });
  document.getElementById('btnLimpiar')?.addEventListener('click', limpiarFiltros);
}

function quitarFiltro(clave) {
  const f = catalogo.filtros;
  if (clave.startsWith('esp:')) {
    const id = clave.slice(4);
    f.especialidades = f.especialidades.filter(e => e !== id);
  } else if (clave === 'exp')   f.experienciaMin = 0;
  else if (clave === 'cal')     f.calificacionMin = 0;
  else if (clave === 'texto')   f.texto = '';
  else if (clave === 'nivel' || clave === 'municipio') f[clave] = '';
  else f[clave] = false;

  pintarControlesFiltro();
  urlDesdeFiltros();
  cargarCatalogo();
}

function limpiarFiltros() {
  catalogo.filtros = {
    nivel: '', municipio: '', especialidades: [], disponible: false,
    nocturno: false, domicilio: false, experienciaMin: 0, calificacionMin: 0, texto: ''
  };
  catalogo.orden = 'relevancia';
  pintarControlesFiltro();
  urlDesdeFiltros();
  cargarCatalogo();
}

/** Abre y cierra el panel de filtros en movil. */
function activarPanelFiltros() {
  const panel  = document.getElementById('panelFiltros');
  const abrir  = document.getElementById('btnFiltros');
  const cerrar = document.getElementById('btnCerrarFiltros');
  const velo   = document.getElementById('veloFiltros');
  if (!panel) return;

  const alternar = (abierto) => {
    panel.classList.toggle('abierto', abierto);
    velo?.classList.toggle('abierto', abierto);
    abrir.setAttribute('aria-expanded', String(abierto));
    document.body.style.overflow = abierto ? 'hidden' : '';
  };

  abrir?.addEventListener('click', () => alternar(true));
  cerrar?.addEventListener('click', () => alternar(false));
  velo?.addEventListener('click', () => alternar(false));
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && panel.classList.contains('abierto')) alternar(false);
  });
}

/** Arranque del catalogo. */
function iniciarCatalogo() {
  const p = new URLSearchParams(window.location.search);
  catalogo.filtros = filtrosDesdeURL();
  catalogo.orden = p.get('orden') || 'relevancia';

  pintarControlesFiltro();
  activarPanelFiltros();

  const aplicar = () => {
    leerControlesFiltro();
    urlDesdeFiltros();
    cargarCatalogo();
  };

  document.getElementById('formFiltros').addEventListener('change', aplicar);
  document.getElementById('formFiltros').addEventListener('submit', e => {
    e.preventDefault();
    aplicar();
  });
  document.getElementById('fBuscar').addEventListener('input', retardar(aplicar, 400));
  document.getElementById('fOrden').addEventListener('change', aplicar);

  // Las etiquetas de los deslizadores se actualizan mientras se arrastran
  ['fExperiencia', 'fCalificacion'].forEach(id =>
    document.getElementById(id).addEventListener('input', actualizarEtiquetasRango));

  if (usandoDemo()) document.getElementById('avisoDemo')?.classList.remove('oculto');

  activarSeleccion();
  cargarCatalogo();
}

/* ==========================================================================
   PERFIL — perfil.html?id= (CLAUDE.md 8.3)
   Nunca se muestran datos de contacto: la coordinacion pasa por la agencia.
   ========================================================================== */

/** Pestañas del perfil. */
function activarPestanas() {
  const botones = document.querySelectorAll('[role="tab"]');

  botones.forEach(boton => boton.addEventListener('click', () => {
    botones.forEach(b => {
      const activo = b === boton;
      b.setAttribute('aria-selected', String(activo));
      b.classList.toggle('activo', activo);
      document.getElementById(b.getAttribute('aria-controls'))
              ?.classList.toggle('oculto', !activo);
    });
  }));
}

/** Calendario de disponibilidad de los proximos siete dias. */
function pintarDisponibilidad(filas) {
  const zona = document.getElementById('disponibilidad');
  if (!zona) return;

  if (!filas.length) {
    zona.innerHTML = `<p class="texto-sm txt-secundario">
      No hay disponibilidad publicada para los próximos días. Consúltanos y la confirmamos contigo.</p>`;
    return;
  }

  // Se agrupan los turnos por dia
  const porDia = new Map();
  filas.forEach(f => {
    const clave = f.fecha instanceof Date ? hoyISOde(f.fecha) : String(f.fecha);
    if (!porDia.has(clave)) porDia.set(clave, []);
    porDia.get(clave).push(f.turno);
  });

  const dias = [...porDia.entries()].slice(0, 7);
  zona.innerHTML = dias.map(([fecha, turnos]) => {
    const f = aFecha(fecha);
    return `
      <div class="dia-disponible">
        <div class="dia-fecha">
          <span class="dia-semana">${new Intl.DateTimeFormat('es-MX', { weekday: 'short' }).format(f)}</span>
          <span class="dia-numero">${f.getDate()}</span>
        </div>
        <div class="dia-turnos">
          ${turnos.map(t => `<span class="chip chip-neutro">${esc(etiqueta(TURNOS, t).split(' (')[0])}</span>`).join('')}
        </div>
      </div>`;
  }).join('');
}

/** Fecha de un objeto Date en formato YYYY-MM-DD local. */
function hoyISOde(fecha) {
  const mes = String(fecha.getMonth() + 1).padStart(2, '0');
  const dia = String(fecha.getDate()).padStart(2, '0');
  return `${fecha.getFullYear()}-${mes}-${dia}`;
}

/** Lista de evaluaciones publicas del profesional. */
function pintarEvaluaciones(lista) {
  const zona = document.getElementById('listaEvaluaciones');
  if (!zona) return;

  const conComentario = lista.filter(e => e.comentario);
  if (!conComentario.length) {
    zona.innerHTML = estadoVacio({
      icono: 'estrella',
      titulo: 'Todavía no hay evaluaciones publicadas',
      texto: 'Las evaluaciones se publican cuando el cliente califica un servicio completado.'
    });
    return;
  }

  zona.innerHTML = conComentario.map(ev => `
    <article class="tarjeta evaluacion">
      <div class="estrellas-fila" role="img" aria-label="${ev.calificacion_general} de 5 estrellas">
        ${[1,2,3,4,5].map(n => `<svg width="16" height="16" viewBox="0 0 24 24"
            fill="${n <= ev.calificacion_general ? 'currentColor' : 'none'}"
            stroke="currentColor" stroke-width="1.5" aria-hidden="true">${ICONOS.estrella}</svg>`).join('')}
      </div>
      <p>&ldquo;${esc(ev.comentario)}&rdquo;</p>
      ${ev.cliente ? `<footer class="texto-sm txt-secundario">${esc(ev.cliente)}</footer>` : ''}
    </article>`).join('');
}

/** Arranque del perfil. */
async function iniciarPerfil() {
  const id = paramURL('id');
  const zona = document.getElementById('perfil');
  const cargando = document.getElementById('cargandoPerfil');

  if (!id) {
    cargando.innerHTML = estadoVacio({
      icono: 'buscar',
      titulo: 'No indicaste a quién quieres ver',
      texto: 'Vuelve al catálogo y elige un perfil.',
      boton: { href: 'enfermeros.html', texto: 'Ver el catálogo' }
    });
    return;
  }

  const { datos: e, error } = await obtenerEnfermero(id);

  if (error || !e) {
    cargando.innerHTML = estadoVacio({
      icono: 'buscar',
      titulo: 'No encontramos este perfil',
      texto: error || 'Puede que ya no esté publicado. Revisa el catálogo, seguro tenemos a alguien con el mismo perfil.',
      boton: { href: 'enfermeros.html', texto: 'Ver el catálogo' }
    });
    return;
  }

  document.title = `${e.nombre_completo} — Enlace Enfermero`;
  cargando.classList.add('oculto');
  zona.classList.remove('oculto');

  // --- Encabezado ---
  document.getElementById('pFoto').innerHTML = e.foto_url
    ? `<img src="${esc(e.foto_url)}" alt="Foto de ${esc(e.nombre_completo)}">`
    : `<div class="inicial" aria-hidden="true">${esc(iniciales(e.nombre_completo))}</div>`;

  document.getElementById('pNombre').textContent = e.nombre_completo;
  document.getElementById('pNivel').textContent  = etiqueta(NIVELES, e.nivel);
  document.getElementById('pFolio').textContent  = e.folio || '';

  document.getElementById('pInsignias').innerHTML = [
    e.cedula_verificada ? badgeVerificado() : '',
    e.disponible_inmediato ? '<span class="badge badge-exito">Disponible de inmediato</span>' : '',
    estrellas(e.calificacion_promedio, e.total_servicios)
  ].join('');

  document.getElementById('pDatos').innerHTML = `
    <div class="dato">
      <span class="dato-valor">${esc(e.anios_experiencia)}</span>
      <span class="dato-etiqueta">${e.anios_experiencia === 1 ? 'año' : 'años'} de experiencia</span>
    </div>
    <div class="dato">
      <span class="dato-valor">${esc(e.total_servicios || 0)}</span>
      <span class="dato-etiqueta">servicios completados</span>
    </div>
    <div class="dato">
      <span class="dato-valor">${e.calificacion_promedio ? Number(e.calificacion_promedio).toFixed(1) : '—'}</span>
      <span class="dato-etiqueta">calificación</span>
    </div>`;

  // --- Pestaña: perfil ---
  document.getElementById('pBio').textContent = e.bio || 'Este perfil todavía no tiene descripción.';

  document.getElementById('pEspecialidades').innerHTML = (e.especialidades || []).length
    ? e.especialidades.map(id => `<span class="chip">${esc(etiqueta(ESPECIALIDADES, id))}</span>`).join('')
    : '<p class="texto-sm txt-tenue">Sin especialidades declaradas.</p>';

  document.getElementById('pZonas').innerHTML = (e.zonas_cobertura || []).length
    ? e.zonas_cobertura.map(id => `<span class="chip chip-neutro">${esc(etiqueta(MUNICIPIOS, id))}</span>`).join('')
    : '<p class="texto-sm txt-tenue">Sin zonas declaradas.</p>';

  document.getElementById('pModalidad').innerHTML = [
    ['Atiende a domicilio', e.acepta_domicilio],
    ['Acepta turno nocturno', e.acepta_nocturno]
  ].map(([texto, si]) => `
    <li class="${si ? 'si' : 'no'}">
      ${icono(si ? 'check' : 'cerrar', 16)}
      <span>${esc(texto)}</span>
    </li>`).join('');

  // --- Pestaña: experiencia y certificaciones ---
  document.getElementById('pCertificaciones').innerHTML = (e.certificaciones || []).length
    ? e.certificaciones.map(id => `
        <li>${icono('check', 16)}<span>${esc(etiqueta(CERTIFICACIONES, id))}</span></li>`).join('')
    : '<li class="txt-tenue">Sin certificaciones registradas.</li>';

  document.getElementById('pIdiomas').textContent = (e.idiomas || []).length
    ? e.idiomas.join(', ')
    : 'No especificado';

  document.getElementById('pCedula').innerHTML = e.cedula_verificada
    ? `${badgeVerificado()} <span class="texto-sm txt-secundario">Cédula validada ante la SEP</span>`
    : `<span class="badge badge-gris">Sin cédula profesional</span>
       <span class="texto-sm txt-secundario">Nivel que no requiere cédula</span>`;

  // --- Panel lateral y evaluaciones ---
  document.getElementById('btnSolicitar').href = `solicitar.html?enfermero=${encodeURIComponent(e.id)}`;

  const btnAgregar = document.getElementById('btnAgregarSeleccion');
  btnAgregar.dataset.seleccionar = e.id;
  btnAgregar.dataset.nombre = e.nombre_completo;
  activarSeleccion();

  const [disp, evals] = await Promise.all([
    obtenerDisponibilidad(e.id, 14),
    obtenerEvaluaciones(e.id, 10)
  ]);
  pintarDisponibilidad(disp.datos);
  pintarEvaluaciones(evals.datos);

  activarPestanas();
  activarAparicion();
}

/* ==========================================================================
   FORMULARIOS MULTIPASO — solicitar.html y unete.html
   Un solo motor para los dos: navegacion entre pasos, barra de progreso y
   validacion por paso. No deja avanzar con campos invalidos.
   ========================================================================== */

function crearFormularioPasos({ formId, pasos, alEnviar }) {
  const form = document.getElementById(formId);
  if (!form) return null;

  let actual = 0;

  const secciones  = [...form.querySelectorAll('[data-paso]')];
  const barra      = document.getElementById('barraPasos');
  const btnAtras   = document.getElementById('btnAtras');
  const btnSiguiente = document.getElementById('btnSiguiente');
  const btnEnviar  = document.getElementById('btnEnviar');

  function pintarProgreso() {
    barra.innerHTML = pasos.map((texto, i) => `
      <div class="paso ${i === actual ? 'activo' : ''} ${i < actual ? 'completado' : ''}">
        <div class="paso-barra"></div>
        <span class="paso-texto">${esc(texto)}</span>
      </div>`).join('');
  }

  function mostrar(indice) {
    actual = indice;
    secciones.forEach((s, i) => s.classList.toggle('oculto', i !== indice));

    btnAtras.classList.toggle('oculto', indice === 0);
    btnSiguiente.classList.toggle('oculto', indice === secciones.length - 1);
    btnEnviar.classList.toggle('oculto', indice !== secciones.length - 1);

    pintarProgreso();

    // El foco va al encabezado del paso para que un lector de pantalla lo anuncie
    secciones[indice].querySelector('h2')?.focus();
    window.scrollTo({ top: form.offsetTop - 100, behavior: 'smooth' });
  }

  /** Valida solo los campos del paso visible. */
  function pasoValido() {
    const seccion = secciones[actual];
    let valido = true;

    seccion.querySelectorAll('input, select, textarea').forEach(campo => {
      limpiarError(campo);

      const obligatorio = campo.hasAttribute('required');
      const valor = campo.type === 'checkbox' ? campo.checked : campo.value.trim();

      if (obligatorio && !valor) {
        marcarError(campo, campo.type === 'checkbox'
          ? 'Necesitamos tu confirmación para continuar.'
          : 'Este dato es necesario.');
        valido = false;
        return;
      }
      if (!valor) return;

      if (campo.type === 'email' && !validar.email(valor)) {
        marcarError(campo, 'Revisa el correo, parece incompleto.');
        valido = false;
      }
      if (campo.type === 'tel' && !validar.telefono(valor)) {
        marcarError(campo, 'Escribe 10 dígitos, con lada. Ejemplo: 33 1234 5678.');
        valido = false;
      }
      if (campo.dataset.validar === 'curp' && !validar.curp(valor)) {
        marcarError(campo, 'La CURP debe tener 18 caracteres.');
        valido = false;
      }
      if (campo.dataset.validar === 'cedula' && !validar.cedula(valor)) {
        marcarError(campo, 'La cédula profesional tiene 7 u 8 dígitos.');
        valido = false;
      }
      if (campo.dataset.validar === 'nacimiento' && !validar.mayorDeEdad(valor)) {
        marcarError(campo, 'Debes ser mayor de edad para registrarte.');
        valido = false;
      }
    });

    // Grupos de casillas que exigen al menos una marcada
    seccion.querySelectorAll('[data-minimo-uno]').forEach(grupo => {
      if (!grupo.querySelector('input:checked')) {
        const aviso = grupo.parentElement.querySelector('.mensaje-error');
        if (!aviso) {
          const nuevo = document.createElement('span');
          nuevo.className = 'mensaje-error';
          nuevo.setAttribute('role', 'alert');
          nuevo.textContent = grupo.querySelector('input[type="radio"]')
            ? 'Elige una opción para continuar.'
            : 'Elige al menos una opción.';
          grupo.parentElement.appendChild(nuevo);
        }
        valido = false;
      } else {
        grupo.parentElement.querySelector('.mensaje-error')?.remove();
      }
    });

    if (!valido) {
      seccion.querySelector('.campo.error input, .campo.error select, .campo.error textarea')?.focus();
      toast('Revisa los datos marcados en rojo.', 'error');
    }
    return valido;
  }

  btnSiguiente.addEventListener('click', () => {
    if (pasoValido()) mostrar(actual + 1);
  });
  btnAtras.addEventListener('click', () => mostrar(actual - 1));

  // Enter no debe enviar el formulario en un paso intermedio
  form.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && e.target.tagName !== 'TEXTAREA' && actual < secciones.length - 1) {
      e.preventDefault();
      if (pasoValido()) mostrar(actual + 1);
    }
  });

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!pasoValido()) return;

    btnEnviar.classList.add('cargando');
    btnEnviar.disabled = true;
    try {
      await alEnviar(new FormData(form));
    } finally {
      btnEnviar.classList.remove('cargando');
      btnEnviar.disabled = false;
    }
  });

  // Al corregir un campo se quita su marca de error
  form.addEventListener('input', (e) => {
    if (e.target.closest('.campo.error')) limpiarError(e.target);

    // Los grupos con `data-minimo-uno` no llevan la clase .error en el campo:
    // su aviso se agrega aparte, asi que hay que retirarlo a mano en cuanto
    // el usuario marque algo.
    const grupo = e.target.closest('[data-minimo-uno]');
    if (grupo?.querySelector('input:checked')) {
      grupo.parentElement.querySelector('.mensaje-error')?.remove();
    }
  });

  mostrar(0);
  return { mostrar, pasoValido };
}

/** Pantalla de confirmacion con folio, comun a los dos formularios. */
function mostrarConfirmacion({ titulo, texto, folio, acciones = [] }) {
  const zona = document.getElementById('confirmacion');
  const form = document.getElementById('zonaFormulario');
  if (!zona) return;

  form?.classList.add('oculto');
  zona.classList.remove('oculto');
  zona.innerHTML = `
    <div class="tarjeta confirmacion-tarjeta">
      <div class="confirmacion-icono">${icono('check', 34)}</div>
      <h1>${esc(titulo)}</h1>
      <p>${esc(texto)}</p>
      ${folio ? `
        <div class="folio-caja">
          <span class="folio-etiqueta">Tu folio de seguimiento</span>
          <strong class="folio-numero">${esc(folio)}</strong>
        </div>` : ''}
      <div class="confirmacion-acciones">
        ${acciones.map(a => `<a href="${esc(a.href)}" class="btn ${a.clase || 'btn-secundario'}"
            ${a.externo ? 'target="_blank" rel="noopener noreferrer"' : ''}>${esc(a.texto)}</a>`).join('')}
      </div>
    </div>`;
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

/* ==========================================================================
   SOLICITAR PERSONAL — solicitar.html (CLAUDE.md 8.4)
   ========================================================================== */

async function iniciarSolicitud() {
  // Catalogos en los controles
  llenarSelect('sTipoServicio', TIPOS_SERVICIO, 'Selecciona el servicio');
  llenarSelect('sEntorno', ENTORNOS, 'Selecciona el lugar');
  llenarSelect('sTipoPaciente', TIPOS_PACIENTE, 'Selecciona una opción');
  llenarSelect('sNivel', NIVELES, 'Cualquier nivel');
  llenarSelect('sTurno', TURNOS, 'Selecciona el turno');
  llenarSelect('sMunicipio', MUNICIPIOS, 'Selecciona el municipio');
  llenarSelect('sTipoCliente', TIPOS_CLIENTE, 'Selecciona una opción');

  document.getElementById('sEspecialidades').innerHTML = ESPECIALIDADES.map(e => `
    <label class="check">
      <input type="checkbox" name="especialidades" value="${e.id}">
      <span>${esc(e.nombre)}</span>
    </label>`).join('');

  // El nivel de atencion es la variable que mas pesa en la cotizacion, por eso
  // va con su explicacion a la vista y no escondido en un desplegable.
  document.getElementById('sNivelAtencion').innerHTML = NIVELES_ATENCION.map(n => `
    <label class="opcion-radio">
      <input type="radio" name="nivel_atencion" value="${n.id}">
      <span class="opcion-cuerpo">
        <strong>${esc(n.nombre)}</strong>
        <small>${esc(n.ayuda)}</small>
      </span>
    </label>`).join('');

  document.getElementById('sProcedimientos').innerHTML = PROCEDIMIENTOS.map(p => `
    <label class="check">
      <input type="checkbox" name="procedimientos" value="${p.id}">
      <span>${esc(p.nombre)}</span>
    </label>`).join('');

  // "Ninguno en particular" es excluyente respecto a los demas
  document.getElementById('sProcedimientos').addEventListener('change', (evento) => {
    const casillas = [...document.querySelectorAll('input[name="procedimientos"]')];
    const ninguno = casillas.find(c => c.value === 'ninguno');
    if (evento.target === ninguno && ninguno.checked) {
      casillas.forEach(c => { if (c !== ninguno) c.checked = false; });
    } else if (evento.target !== ninguno && evento.target.checked) {
      ninguno.checked = false;
    }
  });

  document.getElementById('sDias').innerHTML = DIAS_SEMANA.map(d => `
    <label class="check-pastilla">
      <input type="checkbox" name="dias" value="${d.id}">
      <span>${esc(d.nombre.slice(0, 3))}</span>
    </label>`).join('');

  // La fecha de inicio no puede ser anterior a hoy
  const hoy = hoyISO();
  document.getElementById('sFechaInicio').min = hoy;
  document.getElementById('sFechaFin').min = hoy;

  // El cliente pudo elegir uno o varios perfiles del catalogo (CLAUDE.md 15.3).
  // Vienen por la URL (?enfermero=id1,id2) o de la seleccion en curso.
  await pintarPreseleccionados();

  crearFormularioPasos({
    formId: 'formSolicitud',
    pasos: ['Servicio', 'Detalles', 'Ubicación', 'Contacto'],
    alEnviar: enviarSolicitud
  });
}

/** Muestra los profesionales que el cliente ya eligio y deja quitarlos. */
async function pintarPreseleccionados() {
  const zona = document.getElementById('preseleccionado');
  if (!zona) return;

  const deURL = (paramURL('enfermero') || '').split(',').filter(Boolean);
  const ids = deURL.length ? deURL : seleccion.lista().map(p => p.id);

  if (!ids.length) {
    zona.classList.add('oculto');
    zona.innerHTML = '';
    return;
  }

  const perfiles = (await Promise.all(ids.map(id => obtenerEnfermero(id))))
    .map(r => r.datos)
    .filter(Boolean);

  if (!perfiles.length) {
    zona.classList.add('oculto');
    return;
  }

  // La seleccion se deja igual a lo que se esta mostrando, para que la barra
  // flotante y el formulario no se contradigan.
  seleccion.guardar(perfiles.map(p => ({ id: p.id, nombre: p.nombre_completo })));

  zona.classList.remove('oculto');
  zona.innerHTML = `
    <div class="preseleccion-caja">
      <p class="preseleccion-titulo">
        ${icono('usuarios', 18)}
        Estás solicitando a ${perfiles.length === 1 ? 'este profesional' : `estos ${perfiles.length} profesionales`}
      </p>
      <div class="preseleccion-lista">
        ${perfiles.map(p => `
          <div class="preseleccion">
            <div class="preseleccion-foto">${p.foto_url
              ? `<img src="${esc(p.foto_url)}" alt="">`
              : `<span>${esc(iniciales(p.nombre_completo))}</span>`}</div>
            <div>
              <strong>${esc(p.nombre_completo)}</strong>
              <span class="texto-sm txt-secundario">${esc(etiqueta(NIVELES, p.nivel))}</span>
            </div>
            <button type="button" class="btn-icono" data-quitar-preseleccion="${esc(p.id)}"
                    aria-label="Quitar a ${esc(p.nombre_completo)}">
              ${icono('cerrar', 18)}
            </button>
          </div>`).join('')}
      </div>
      <p class="texto-sm txt-secundario">
        Confirmamos su disponibilidad para tus fechas. Si alguno no puede,
        te proponemos a alguien con el mismo perfil.
      </p>
    </div>`;

  zona.querySelectorAll('[data-quitar-preseleccion]').forEach(boton =>
    boton.addEventListener('click', async () => {
      seleccion.quitar(boton.dataset.quitarPreseleccion);
      // La URL manda sobre la seleccion: hay que reescribirla al quitar uno
      actualizarURL({ enfermero: seleccion.comoParametro() });
      await pintarPreseleccionados();
    }));

  // Con un solo profesional se precarga su nivel como referencia
  if (perfiles.length === 1) {
    document.getElementById('sNivel').value = perfiles[0].nivel;
  }
}

function llenarSelect(id, catalogo, textoVacio) {
  const sel = document.getElementById(id);
  if (!sel) return;
  sel.innerHTML = `<option value="">${esc(textoVacio)}</option>` +
    catalogo.map(c => `<option value="${c.id}">${esc(c.nombre)}</option>`).join('');
}

async function enviarSolicitud(datos) {
  const solicitud = {
    tipo_servicio:          datos.get('tipo_servicio'),
    nivel_requerido:        datos.get('nivel_requerido') || null,
    especialidad_requerida: datos.getAll('especialidades'),
    descripcion_paciente:   datos.get('descripcion') || null,
    entorno:                datos.get('entorno'),
    tipo_paciente:          datos.get('tipo_paciente') || null,
    nivel_atencion:         datos.get('nivel_atencion') || null,
    procedimientos:         datos.getAll('procedimientos'),
    cantidad_enfermeros:    Number(datos.get('cantidad')) || 1,
    fecha_inicio:           datos.get('fecha_inicio'),
    fecha_fin:              datos.get('fecha_fin') || null,
    turno:                  datos.get('turno') || null,
    horas_por_turno:        Number(datos.get('horas')) || null,
    dias_semana:            datos.getAll('dias'),
    direccion_servicio:     datos.get('direccion') || null,
    municipio:              datos.get('municipio'),
    enfermeros_solicitados: (paramURL('enfermero') || '').split(',').filter(Boolean),
    urgente:                datos.get('urgente') === 'on',
    // El canal por el que llego, para que la agencia sepa de donde viene el
    // negocio. El panel del cliente lo sobreescribe; por defecto es la landing.
    origen:                 window.ORIGEN_SOLICITUD || 'landing',
    codigo_referido:        paramURL('ref'),
    contacto_nombre:        datos.get('nombre'),
    contacto_telefono:      normalizarTelefono(datos.get('telefono')),
    contacto_email:         datos.get('email') || null
  };

  // Sin base de datos conectada no se puede guardar: se dice con claridad y se
  // ofrece WhatsApp para no perder al prospecto.
  if (!supabaseListo()) {
    mostrarConfirmacion({
      titulo: 'Falta conectar la base de datos',
      texto: 'El formulario está completo y validado, pero todavía no hay credenciales de Supabase en js/config.js, así que la solicitud no se guardó. Mientras tanto puedes escribirnos por WhatsApp.',
      acciones: [
        { href: enlaceWhatsApp(`Hola, necesito personal de enfermería. Mi nombre es ${datos.get('nombre')}.`),
          texto: 'Escribir por WhatsApp', clase: 'btn-primario', externo: true },
        { href: 'index.html', texto: 'Volver al inicio' }
      ]
    });
    return;
  }

  // Se manda por funcion y no con insert directo: asi el sitio publico recibe
  // el folio sin necesidad de tener permiso de lectura sobre `solicitudes`.
  const { datos: folio, error } = await consultar(
    db.rpc('crear_solicitud', { p_datos: solicitud })
  );

  if (error) {
    toast(error, 'error');
    return;
  }

  seleccion.limpiar();

  mostrarConfirmacion({
    titulo: 'Recibimos tu solicitud',
    texto: 'Un coordinador la está revisando. Te contactamos hoy mismo con los perfiles que se ajusten a lo que necesitas.',
    folio: folio,
    acciones: [
      { href: enlaceWhatsApp(`Hola, acabo de enviar la solicitud ${folio || ''}.`),
        texto: 'Dar seguimiento por WhatsApp', clase: 'btn-primario', externo: true },
      { href: 'enfermeros.html', texto: 'Ver el catálogo' }
    ]
  });
}

/* ==========================================================================
   REGISTRO DE ENFERMEROS — unete.html (CLAUDE.md 8.5)

   En la Fase 1 el candidato todavia no tiene cuenta: el alta entra en
   `enfermeros` con usuario_id nulo, sin publicar y sin verificar, tal como
   permite la policy `enfermeros_alta_publica`. La cuenta y la carga de
   documentos llegan en la Fase 2, cuando exista autenticacion; por eso el
   ultimo paso explica que documentos se van a pedir en vez de subirlos.
   ========================================================================== */

async function iniciarRegistro() {
  llenarSelect('uNivel', NIVELES, 'Selecciona tu nivel');

  const marcar = (id, catalogo, campo) => {
    document.getElementById(id).innerHTML = catalogo.map(c => `
      <label class="check">
        <input type="checkbox" name="${campo}" value="${c.id}">
        <span>${esc(c.nombre)}</span>
      </label>`).join('');
  };
  marcar('uEspecialidades', ESPECIALIDADES, 'especialidades');
  marcar('uCertificaciones', CERTIFICACIONES, 'certificaciones');
  marcar('uZonas', MUNICIPIOS, 'zonas');

  document.getElementById('uTurnos').innerHTML = TURNOS.map(t => `
    <label class="check-pastilla">
      <input type="checkbox" name="turnos" value="${t.id}">
      <span>${esc(t.nombre.split(' (')[0])}</span>
    </label>`).join('');

  // La lista de documentos cambia segun el nivel: los que requieren cedula
  // deben entregar tambien titulo (CLAUDE.md 10.2)
  document.getElementById('uNivel').addEventListener('change', pintarDocumentosRequeridos);
  pintarDocumentosRequeridos();

  crearFormularioPasos({
    formId: 'formRegistro',
    pasos: ['Datos', 'Formación', 'Experiencia', 'Disponibilidad', 'Documentos'],
    alEnviar: enviarRegistro
  });
}

function pintarDocumentosRequeridos() {
  const nivel = document.getElementById('uNivel').value;
  const conCedula = NIVELES_CON_CEDULA.includes(nivel);

  const requeridos = TIPOS_DOCUMENTO.filter(d => d.obligatorio).map(d => d.nombre);
  requeridos.push(conCedula
    ? 'Cédula profesional y título'
    : 'Constancia de estudios o certificado');

  document.getElementById('uListaDocumentos').innerHTML = requeridos.map(d => `
    <li>${icono('documento', 16)}<span>${esc(d)}</span></li>`).join('');

  // El campo de cédula solo aplica a los niveles que la requieren
  document.getElementById('campoCedula').classList.toggle('oculto', !conCedula);
  document.getElementById('uCedula').required = conCedula;
}

async function enviarRegistro(datos) {
  const perfil = {
    nombre_completo:      `${datos.get('nombre')} ${datos.get('apellidos')}`.trim(),
    fecha_nacimiento:     datos.get('nacimiento') || null,
    genero:               datos.get('genero') || null,
    nivel:                datos.get('nivel'),
    cedula_profesional:   datos.get('cedula') || null,
    institucion_egreso:   datos.get('institucion') || null,
    anios_experiencia:    Number(datos.get('experiencia')) || 0,
    especialidades:       datos.getAll('especialidades'),
    certificaciones:      datos.getAll('certificaciones'),
    idiomas:              datos.get('idiomas')
                            ? datos.get('idiomas').split(',').map(i => i.trim()).filter(Boolean)
                            : ['Español'],
    bio:                  datos.get('bio') || null,
    zonas_cobertura:      datos.getAll('zonas'),
    disponible_inmediato: datos.get('inmediato') === 'on',
    acepta_domicilio:     datos.getAll('turnos').length > 0,
    acepta_nocturno:      datos.getAll('turnos').includes('nocturno'),
    acepta_foraneo:       datos.get('foraneo') === 'on',
    // Campos que la policy exige y que solo el admin puede cambiar despues
    estatus_verificacion: 'pendiente',
    publicado:            false,
    cedula_verificada:    false,
    total_servicios:      0
  };

  // El contacto no vive en `enfermeros` sino en `usuarios`, que aun no existe
  // sin autenticacion: se guarda como lead para que el admin pueda llamar.
  const contacto = {
    nombre:   perfil.nombre_completo,
    telefono: normalizarTelefono(datos.get('telefono')),
    email:    datos.get('email'),
    mensaje:  `Registro de enfermero. Nivel: ${etiqueta(NIVELES, perfil.nivel)}. ` +
              `Experiencia: ${perfil.anios_experiencia} años. ` +
              `Zonas: ${perfil.zonas_cobertura.map(z => etiqueta(MUNICIPIOS, z)).join(', ')}.`,
    tipo:     'busco_empleo',
    origen:   'unete'
  };

  if (!supabaseListo()) {
    mostrarConfirmacion({
      titulo: 'Falta conectar la base de datos',
      texto: 'Tu registro está completo y validado, pero todavía no hay credenciales de Supabase en js/config.js, así que no se guardó. Mientras tanto puedes escribirnos por WhatsApp.',
      acciones: [
        { href: enlaceWhatsApp(`Hola, quiero registrarme como enfermero. Mi nombre es ${perfil.nombre_completo}.`),
          texto: 'Escribir por WhatsApp', clase: 'btn-primario', externo: true },
        { href: 'index.html', texto: 'Volver al inicio' }
      ]
    });
    return;
  }

  const { datos: folio, error } = await consultar(
    db.rpc('registrar_enfermero', { p_datos: perfil })
  );

  if (error) {
    toast(error, 'error');
    return;
  }

  // El lead con los datos de contacto va aparte y no debe tumbar el registro
  await consultar(db.from('leads').insert(contacto));

  mostrarConfirmacion({
    titulo: 'Recibimos tu solicitud',
    texto: 'Nuestro equipo verificará tus documentos en 24 a 48 horas. Te contactamos por WhatsApp para pedirte los archivos y resolver cualquier duda.',
    folio: folio,
    acciones: [
      { href: enlaceWhatsApp(`Hola, me registré como enfermero. Mi folio es ${folio || ''}.`),
        texto: 'Enviar mis documentos por WhatsApp', clase: 'btn-primario', externo: true },
      { href: 'index.html', texto: 'Volver al inicio' }
    ]
  });
}

/* ==========================================================================
   SELECCION DE PROFESIONALES (CLAUDE.md 15.3)
   El cliente puede armar una lista con uno o varios perfiles del catalogo y
   mandarlos juntos en una sola solicitud. La agencia confirma disponibilidad.

   Se guarda en sessionStorage porque son identificadores publicos del catalogo
   —los mismos que ya viajan en la URL— y se pierden al cerrar la pestaña.
   Ningun dato personal pasa por aqui.
   ========================================================================== */

const seleccion = {
  CLAVE: 'ee_seleccion',

  lista() {
    try {
      return JSON.parse(sessionStorage.getItem(this.CLAVE)) || [];
    } catch (e) {
      return [];
    }
  },

  guardar(lista) {
    try {
      sessionStorage.setItem(this.CLAVE, JSON.stringify(lista));
    } catch (e) { /* modo privado del navegador: la seleccion no persiste */ }
    renderBarraSeleccion();
    sincronizarBotonesSeleccion();
  },

  tiene(id) {
    return this.lista().some(p => p.id === id);
  },

  alternar(id, nombre) {
    const lista = this.lista();
    const i = lista.findIndex(p => p.id === id);

    if (i >= 0) {
      lista.splice(i, 1);
      this.guardar(lista);
      return false;
    }
    lista.push({ id, nombre });
    this.guardar(lista);
    return true;
  },

  quitar(id) {
    this.guardar(this.lista().filter(p => p.id !== id));
  },

  limpiar() {
    this.guardar([]);
  },

  /** Los ids en el formato que espera solicitar.html */
  comoParametro() {
    return this.lista().map(p => p.id).join(',');
  }
};

/** Barra fija con la seleccion en curso. Aparece solo si hay algo elegido. */
function renderBarraSeleccion() {
  const lista = seleccion.lista();
  let barra = document.getElementById('barraSeleccion');

  if (!lista.length) {
    barra?.remove();
    document.body.classList.remove('con-barra-seleccion');
    return;
  }

  if (!barra) {
    barra = document.createElement('div');
    barra.id = 'barraSeleccion';
    barra.className = 'barra-seleccion';
    barra.setAttribute('role', 'region');
    barra.setAttribute('aria-label', 'Profesionales seleccionados');
    document.body.appendChild(barra);
  }
  document.body.classList.add('con-barra-seleccion');

  const r = raiz();
  barra.innerHTML = `
    <div class="contenedor barra-seleccion-cuerpo">
      <div class="barra-seleccion-info">
        <strong>${lista.length} ${lista.length === 1 ? 'profesional seleccionado' : 'profesionales seleccionados'}</strong>
        <div class="barra-seleccion-fichas">
          ${lista.map(p => `
            <button type="button" class="ficha-filtro" data-quitar-seleccion="${esc(p.id)}">
              ${esc(p.nombre)}
              <span aria-hidden="true">&times;</span>
              <span class="solo-lectores">Quitar de la selección</span>
            </button>`).join('')}
        </div>
      </div>
      <div class="barra-seleccion-acciones">
        <button type="button" class="btn btn-fantasma btn-sm" id="btnLimpiarSeleccion">Limpiar</button>
        <a href="${r}solicitar.html?enfermero=${encodeURIComponent(seleccion.comoParametro())}"
           class="btn btn-primario">Solicitar a ${lista.length === 1 ? 'este profesional' : 'estos ' + lista.length}</a>
      </div>
    </div>`;

  barra.querySelectorAll('[data-quitar-seleccion]').forEach(boton =>
    boton.addEventListener('click', () => seleccion.quitar(boton.dataset.quitarSeleccion)));
  document.getElementById('btnLimpiarSeleccion')
          ?.addEventListener('click', () => seleccion.limpiar());
}

/** Deja los botones "Agregar" de las tarjetas acordes con la seleccion. */
function sincronizarBotonesSeleccion() {
  document.querySelectorAll('[data-seleccionar]').forEach(boton => {
    const elegido = seleccion.tiene(boton.dataset.seleccionar);
    boton.classList.toggle('btn-primario', !elegido);
    boton.classList.toggle('btn-exito', elegido);
    boton.setAttribute('aria-pressed', String(elegido));
    boton.innerHTML = elegido
      ? `${icono('check', 16)}Agregado`
      : 'Agregar';
  });
}

/** Conecta los botones de seleccion que existan en la pagina. */
function activarSeleccion() {
  document.addEventListener('click', (evento) => {
    const boton = evento.target.closest('[data-seleccionar]');
    if (!boton) return;

    evento.preventDefault();
    const agregado = seleccion.alternar(boton.dataset.seleccionar, boton.dataset.nombre);
    toast(agregado
      ? `${boton.dataset.nombre} se agregó a tu selección.`
      : `${boton.dataset.nombre} se quitó de tu selección.`,
      agregado ? 'exito' : 'info', 2500);
  });

  renderBarraSeleccion();
  sincronizarBotonesSeleccion();
}
