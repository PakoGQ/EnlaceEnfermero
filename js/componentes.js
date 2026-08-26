/* ==========================================================================
   Enlace Enfermero — Componentes compartidos
   Header, footer, menu movil, modales y piezas de UI reutilizables.
   Se renderizan por JS para no duplicar el markup en ~30 archivos HTML
   (no hay build step: CLAUDE.md regla 4).
   ========================================================================== */

/* ==========================================================================
   ICONOS — SVG inline, trazo 1.5-2px, sin librerias (CLAUDE.md 3.4)
   ========================================================================== */
const ICONOS = {
  escudo:    '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/>',
  estrella:  '<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>',
  usuarios:  '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  reloj:     '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
  calendario:'<rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>',
  ubicacion: '<path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/>',
  telefono:  '<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.9.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/>',
  correo:    '<rect x="2" y="4" width="20" height="16" rx="2"/><polyline points="22,6 12,13 2,6"/>',
  whatsapp:  '<path d="M20.5 3.5A11.9 11.9 0 0 0 12 0C5.4 0 .1 5.3.1 11.9c0 2.1.5 4.1 1.6 5.9L0 24l6.3-1.7c1.7.9 3.7 1.4 5.7 1.4 6.6 0 11.9-5.3 11.9-11.9 0-3.2-1.2-6.2-3.4-8.3zM12 21.5c-1.8 0-3.5-.5-5-1.4l-.4-.2-3.7 1 1-3.6-.2-.4a9.6 9.6 0 0 1-1.5-5.1c0-5.4 4.4-9.8 9.8-9.8 2.6 0 5.1 1 7 2.9a9.7 9.7 0 0 1 2.9 6.9c0 5.5-4.4 9.9-9.9 9.9z" fill="currentColor" stroke="none"/><path d="M17.4 14.4c-.3-.1-1.7-.9-2-1-.3-.1-.5-.1-.7.1-.2.3-.7 1-.9 1.2-.2.2-.3.2-.6.1-1.8-.9-2.9-1.6-4.1-3.6-.3-.5.3-.5.9-1.6.1-.2 0-.4 0-.5 0-.1-.7-1.6-.9-2.2-.2-.6-.5-.5-.7-.5h-.6c-.2 0-.5.1-.8.4-.3.3-1 1-1 2.5s1.1 2.9 1.2 3.1c.1.2 2.1 3.2 5 4.5 1.9.8 2.6.9 3.5.7.6-.1 1.7-.7 1.9-1.4.2-.7.2-1.2.2-1.4-.1-.1-.3-.2-.6-.3z" fill="currentColor" stroke="none"/>',
  buscar:    '<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>',
  filtro:    '<polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/>',
  flechaDer: '<line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>',
  flechaAbajo:'<polyline points="6 9 12 15 18 9"/>',
  cerrar:    '<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>',
  check:     '<polyline points="20 6 9 17 4 12"/>',
  alerta:    '<path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>',
  documento: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/>',
  hospital:  '<path d="M3 21h18"/><path d="M5 21V7l7-4 7 4v14"/><line x1="12" y1="10" x2="12" y2="16"/><line x1="9" y1="13" x2="15" y2="13"/>',
  casa:      '<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>',
  maletin:   '<rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>',
  dinero:    '<line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>',
  subir:     '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/>',
  salir:     '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>',
  inbox:     '<polyline points="22 12 16 12 14 15 10 15 8 12 2 12"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/>',
  ojo:       '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/>',
  ojoCerrado:'<path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/>',
  candado:   '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
  panel:     '<rect x="3" y="3" width="7" height="9"/><rect x="14" y="3" width="7" height="5"/><rect x="14" y="12" width="7" height="9"/><rect x="3" y="16" width="7" height="5"/>'
};

/**
 * Devuelve un SVG listo para insertar.
 * @param {string} nombre clave de ICONOS
 * @param {number} tam  tamano en px
 */
function icono(nombre, tam = 20, clase = '') {
  const trazo = ICONOS[nombre];
  if (!trazo) return '';
  return `<svg width="${tam}" height="${tam}" viewBox="0 0 24 24" fill="none"
    stroke="currentColor" stroke-width="1.75" stroke-linecap="round"
    stroke-linejoin="round" class="${clase}" aria-hidden="true">${trazo}</svg>`;
}

/* ==========================================================================
   RUTAS
   Las paginas viven en la raiz y en /admin, /panel y /cliente. El header y el
   footer se comparten, asi que los enlaces se calculan segun la profundidad.
   ========================================================================== */
function raiz() {
  const partes = window.location.pathname.split('/').filter(Boolean);
  const enSubcarpeta = ['admin', 'panel', 'cliente'].includes(partes[partes.length - 2]);
  return enSubcarpeta ? '../' : '';
}

/* ==========================================================================
   HEADER
   ========================================================================== */
const NAV_PUBLICO = [
  { href: 'index.html',      texto: 'Inicio' },
  { href: 'servicios.html',  texto: 'Servicios' },
  { href: 'enfermeros.html', texto: 'Enfermeros' },
  { href: 'nosotros.html',   texto: 'Nosotros' },
  { href: 'contacto.html',   texto: 'Contacto' }
];

/**
 * Inserta el header en <header id="header"></header>.
 * @param {string} activa nombre del archivo actual, p.ej. 'servicios.html'
 */
function renderHeader(activa = '') {
  const contenedor = document.getElementById('header');
  if (!contenedor) return;
  const r = raiz();

  const enlaces = NAV_PUBLICO.map(item => `
    <a href="${r}${item.href}" class="nav-link${activa === item.href ? ' activo' : ''}"
       ${activa === item.href ? 'aria-current="page"' : ''}>${item.texto}</a>`).join('');

  contenedor.className = 'header';
  contenedor.innerHTML = `
    <div class="contenedor">
      <a href="${r}index.html" class="logo" aria-label="Enlace Enfermero, ir al inicio">
        <img src="${r}assets/logo.svg" alt="" width="42" height="42">
        <span class="logo-texto">Enlace<span>Enfermero</span></span>
      </a>

      <nav class="nav" id="nav" aria-label="Navegación principal">
        ${enlaces}
        <div class="nav-acciones">
          <a href="${r}unete.html" class="btn btn-secundario btn-sm">Soy enfermero/a</a>
          <a href="${r}solicitar.html" class="btn btn-primario btn-sm">Solicitar personal</a>
        </div>
      </nav>

      <button class="btn-menu" id="btnMenu" aria-label="Abrir menú"
              aria-expanded="false" aria-controls="nav">
        <span></span><span></span><span></span>
      </button>
    </div>`;

  // Velo que oscurece el fondo con el menu abierto
  if (!document.querySelector('.velo-nav')) {
    const velo = document.createElement('div');
    velo.className = 'velo-nav';
    velo.id = 'veloNav';
    document.body.appendChild(velo);
  }

  activarMenu();
  activarSombraHeader();
}

/** Abre y cierra el menu lateral en movil. */
function activarMenu() {
  const btn  = document.getElementById('btnMenu');
  const nav  = document.getElementById('nav');
  const velo = document.getElementById('veloNav');
  if (!btn || !nav) return;

  const alternar = (abrir) => {
    btn.setAttribute('aria-expanded', String(abrir));
    btn.setAttribute('aria-label', abrir ? 'Cerrar menú' : 'Abrir menú');
    nav.classList.toggle('abierto', abrir);
    velo?.classList.toggle('abierto', abrir);
    document.body.style.overflow = abrir ? 'hidden' : '';
  };

  btn.addEventListener('click', () => {
    alternar(btn.getAttribute('aria-expanded') !== 'true');
  });
  velo?.addEventListener('click', () => alternar(false));
  nav.querySelectorAll('a').forEach(a => a.addEventListener('click', () => alternar(false)));
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && btn.getAttribute('aria-expanded') === 'true') {
      alternar(false);
      btn.focus();
    }
  });
  // Al pasar a escritorio el menu deja de ser panel: se restablece el scroll
  window.matchMedia('(min-width: 1024px)').addEventListener('change', e => {
    if (e.matches) alternar(false);
  });
}

/** Agrega sombra al header cuando la pagina se desplaza. */
function activarSombraHeader() {
  const header = document.getElementById('header');
  if (!header) return;
  const alSalir = () => header.classList.toggle('desplazado', window.scrollY > 8);
  alSalir();
  window.addEventListener('scroll', alSalir, { passive: true });
}

/* ==========================================================================
   FOOTER
   ========================================================================== */
function renderFooter() {
  const contenedor = document.getElementById('footer');
  if (!contenedor) return;
  const r = raiz();
  const wa = `https://wa.me/${CONFIG.WHATSAPP_AGENCIA}`;

  // Las redes sociales solo se pintan si estan capturadas en config.js,
  // para no dejar enlaces vacios en produccion.
  const redes = Object.entries(CONFIG.REDES || {}).filter(([, url]) => url);
  const bloqueRedes = redes.length ? `
    <div class="footer-redes">
      ${redes.map(([nombre, url]) => `
        <a href="${esc(url)}" target="_blank" rel="noopener noreferrer"
           aria-label="${esc(nombre)}">${icono('flechaDer', 18)}</a>`).join('')}
    </div>` : '';

  contenedor.className = 'footer';
  contenedor.innerHTML = `
    <div class="contenedor">
      <div class="footer-grid">

        <div class="footer-marca">
          <a href="${r}index.html" class="logo">
            <img src="${r}assets/logo-blanco.svg" alt="" width="42" height="42">
            <span class="logo-texto">Enlace<span>Enfermero</span></span>
          </a>
          <p>Agencia de reclutamiento y colocación de personal de enfermería
             verificado en la Zona Metropolitana de Guadalajara.</p>
          ${bloqueRedes}
        </div>

        <div>
          <h4>Servicios</h4>
          <ul>
            <li><a href="${r}servicios.html#domiciliario">Cuidado domiciliario</a></li>
            <li><a href="${r}servicios.html#hospitalario">Turnos hospitalarios</a></li>
            <li><a href="${r}servicios.html#permanente">Colocación permanente</a></li>
            <li><a href="${r}servicios.html#eventos">Cobertura de eventos</a></li>
          </ul>
        </div>

        <div>
          <h4>Enlace Enfermero</h4>
          <ul>
            <li><a href="${r}nosotros.html">Nosotros</a></li>
            <li><a href="${r}enfermeros.html">Ver personal</a></li>
            <li><a href="${r}unete.html">Trabaja con nosotros</a></li>
            <li><a href="${r}contacto.html">Contacto</a></li>
          </ul>
        </div>

        <div>
          <h4>Contacto</h4>
          <ul class="footer-contacto">
            <li>${icono('ubicacion', 16)}<span>${esc(CONFIG.CIUDAD_BASE)}</span></li>
            <li>${icono('correo', 16)}<a href="mailto:${esc(CONFIG.EMAIL_AGENCIA)}">${esc(CONFIG.EMAIL_AGENCIA)}</a></li>
            <li>${icono('whatsapp', 16)}<a href="${wa}" target="_blank" rel="noopener noreferrer">WhatsApp</a></li>
            <li>${icono('reloj', 16)}<span>Atención 24/7</span></li>
          </ul>
        </div>

      </div>

      <p class="footer-aviso-legal">
        Enlace Enfermero es una agencia de colocación de personal. No presta
        servicios médicos ni emite diagnósticos. El personal colocado actúa bajo
        indicación médica y dentro del alcance de su nivel de práctica profesional.
      </p>

      <div class="footer-legal">
        <span>&copy; ${new Date().getFullYear()} ${esc(CONFIG.NOMBRE_AGENCIA)}. Todos los derechos reservados.</span>
        <nav aria-label="Enlaces legales">
          <a href="${r}aviso-privacidad.html">Aviso de privacidad</a>
          <a href="${r}terminos.html">Términos y condiciones</a>
        </nav>
      </div>
    </div>`;
}

/* --- Boton flotante de WhatsApp --- */
function renderBotonWhatsApp() {
  if (document.querySelector('.btn-whatsapp')) return;
  const a = document.createElement('a');
  a.className = 'btn-whatsapp';
  a.href = enlaceWhatsApp();
  a.target = '_blank';
  a.rel = 'noopener noreferrer';
  a.setAttribute('aria-label', 'Escríbenos por WhatsApp');
  a.innerHTML = icono('whatsapp', 28);
  document.body.appendChild(a);
}

/* ==========================================================================
   PIEZAS REUTILIZABLES
   ========================================================================== */

/** Badge de estatus a partir de un catalogo de config.js. */
function badge(catalogo, valor) {
  const item = catalogo[valor];
  if (!item) return `<span class="badge badge-gris">${esc(valor || '-')}</span>`;
  return `<span class="badge ${item.clase}">${esc(item.nombre)}</span>`;
}

/** Badge de verificacion: el diferenciador del negocio (CLAUDE.md 3.4). */
function badgeVerificado() {
  return `<span class="badge badge-verificado">${icono('escudo', 14)}Verificado</span>`;
}

/** Calificacion con estrella. `total` es el numero de servicios evaluados. */
function estrellas(promedio, total = 0) {
  const valor = Number(promedio) || 0;
  if (!valor) return `<span class="calificacion txt-tenue">Sin evaluaciones</span>`;
  return `<span class="calificacion">
    <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      ${ICONOS.estrella}
    </svg>${valor.toFixed(1)}
    ${total ? `<span class="conteo">(${total})</span>` : ''}
  </span>`;
}

/**
 * Tarjeta de enfermero para el catalogo y la landing (CLAUDE.md 3.4).
 * Recibe una fila de la vista `enfermeros_publico`: nunca datos de contacto.
 */
function tarjetaEnfermero(e, opciones = {}) {
  const r = opciones.raiz ?? raiz();
  const chips = (e.especialidades || []).slice(0, 3)
    .map(id => `<span class="chip">${esc(etiqueta(ESPECIALIDADES, id))}</span>`).join('');
  const restantes = Math.max(0, (e.especialidades || []).length - 3);

  const foto = e.foto_url
    ? `<img src="${esc(e.foto_url)}" alt="Foto de ${esc(e.nombre_completo)}" loading="lazy">`
    : `<div class="inicial" aria-hidden="true">${esc(iniciales(e.nombre_completo))}</div>`;

  return `
    <article class="tarjeta tarjeta-hover tarjeta-enfermero">
      <div class="enfermero-top">
        <div class="enfermero-foto">
          ${foto}
          ${e.disponible_inmediato
            ? '<span class="punto-estatus disponible" title="Disponible de inmediato"></span>'
            : ''}
        </div>
        <div class="enfermero-datos">
          <h3>${esc(e.nombre_completo)}</h3>
          <p class="texto-sm txt-secundario">${esc(etiqueta(NIVELES, e.nivel))}</p>
          <div class="enfermero-meta">
            ${e.cedula_verificada ? badgeVerificado() : ''}
            ${estrellas(e.calificacion_promedio, e.total_servicios)}
          </div>
        </div>
      </div>

      <p class="texto-sm txt-secundario">
        ${esc(e.anios_experiencia)} ${e.anios_experiencia === 1 ? 'año' : 'años'} de experiencia
        ${e.disponible_inmediato ? ' &middot; <span class="txt-exito">Disponible ya</span>' : ''}
      </p>

      <div class="enfermero-chips">
        ${chips}
        ${restantes ? `<span class="chip chip-neutro">+${restantes}</span>` : ''}
      </div>

      ${e.bio ? `<p class="enfermero-bio">${esc(e.bio)}</p>` : ''}

      <div class="enfermero-pie">
        <a href="${r}perfil.html?id=${encodeURIComponent(e.id)}" class="btn btn-secundario btn-sm">Ver perfil</a>
        <button type="button" class="btn btn-primario btn-sm"
                data-seleccionar="${esc(e.id)}"
                data-nombre="${esc(e.nombre_completo)}"
                aria-pressed="false">Agregar</button>
      </div>
    </article>`;
}

/** Bloque de estado vacio con llamado a la accion opcional. */
function estadoVacio({ icono: nombreIcono = 'inbox', titulo, texto, boton }) {
  return `
    <div class="estado-vacio">
      <div class="icono">${icono(nombreIcono, 30)}</div>
      <h3>${esc(titulo)}</h3>
      <p>${esc(texto)}</p>
      ${boton ? `<a href="${esc(boton.href)}" class="btn btn-primario">${esc(boton.texto)}</a>` : ''}
    </div>`;
}

/** Bloque de carga: n esqueletos de tarjeta. */
function esqueletoTarjetas(n = 6) {
  return Array.from({ length: n }, () => `
    <div class="tarjeta">
      <div class="flex gap-4">
        <div class="esqueleto esqueleto-circulo"></div>
        <div style="flex:1">
          <div class="esqueleto esqueleto-linea" style="width:70%"></div>
          <div class="esqueleto esqueleto-linea" style="width:45%"></div>
          <div class="esqueleto esqueleto-linea" style="width:60%"></div>
        </div>
      </div>
    </div>`).join('');
}

/* ==========================================================================
   CONTRASENAS
   ========================================================================== */

/** Conecta los botones que muestran u ocultan una contrasena. */
function activarVerClave() {
  document.querySelectorAll('[data-ver]').forEach(boton => {
    const campo = document.getElementById(boton.dataset.ver);
    if (!campo) return;

    boton.innerHTML = icono('ojo', 20);

    boton.addEventListener('click', () => {
      const visible = campo.type === 'text';
      campo.type = visible ? 'password' : 'text';
      boton.innerHTML = icono(visible ? 'ojo' : 'ojoCerrado', 20);
      boton.setAttribute('aria-label', visible ? 'Mostrar contraseña' : 'Ocultar contraseña');
      campo.focus();
    });
  });
}

/**
 * Evalua que tan solida es una contrasena. Devuelve 0 a 4.
 * No es un medidor criptografico: solo orienta al usuario mientras escribe.
 */
function fuerzaClave(clave) {
  if (!clave) return { nivel: 0, texto: '' };

  let puntos = 0;
  if (clave.length >= 8)  puntos++;
  if (clave.length >= 12) puntos++;
  if (/[a-z]/.test(clave) && /[A-Z]/.test(clave)) puntos++;
  if (/\d/.test(clave)) puntos++;
  if (/[^\w\s]/.test(clave)) puntos++;

  // Las secuencias obvias no cuentan por larga que sea la contrasena
  if (/^(.)\1+$/.test(clave) || /123456|password|qwerty|contrasena/i.test(clave)) {
    puntos = Math.min(puntos, 1);
  }

  const nivel = Math.min(4, Math.max(1, puntos));
  const textos = ['', 'Muy débil', 'Débil', 'Aceptable', 'Sólida'];
  return { nivel, texto: textos[nivel] };
}

/** Pinta el medidor bajo un campo de contrasena. */
function activarMedidorClave(idCampo, idMedidor) {
  const campo = document.getElementById(idCampo);
  const zona  = document.getElementById(idMedidor);
  if (!campo || !zona) return;

  zona.innerHTML = `
    <div class="fuerza-barras"><span></span><span></span><span></span><span></span></div>
    <div class="fuerza-texto"></div>`;

  campo.addEventListener('input', () => {
    const { nivel, texto } = fuerzaClave(campo.value);
    zona.className = 'fuerza-clave' + (nivel ? ' fuerza-' + nivel : '');
    zona.querySelector('.fuerza-texto').textContent = texto;
  });
}

/* ==========================================================================
   ARRANQUE COMUN
   Cada pagina llama a iniciarPagina('archivo.html') al final del body.
   ========================================================================== */
function iniciarPagina(paginaActiva = '') {
  renderHeader(paginaActiva);
  renderFooter();
  renderBotonWhatsApp();
  activarAparicion();
  registrarVisita();
}

/* ==========================================================================
   PESTAÑAS
   Patron de tablist del estandar: una sola pestaña en el orden de tabulacion
   y las flechas mueven entre ellas. Sin eso, quien navega con teclado tiene
   que pasar por todas las pestañas para llegar al contenido.
   ========================================================================== */

/** Activa todos los [role="tablist"] de la pagina. */
function activarPestanas() {
  document.querySelectorAll('[role="tablist"]').forEach(lista => {
    const pestanas = Array.from(lista.querySelectorAll('[role="tab"]'));
    if (pestanas.length < 2) return;

    const mostrar = (indice, mover = true) => {
      pestanas.forEach((pestana, i) => {
        const activa = i === indice;
        pestana.setAttribute('aria-selected', String(activa));
        // Solo la activa queda tabulable: es lo que define el patron
        pestana.tabIndex = activa ? 0 : -1;
        const panel = document.getElementById(pestana.getAttribute('aria-controls'));
        if (panel) panel.classList.toggle('oculto', !activa);
      });
      if (mover) pestanas[indice].focus();
    };

    pestanas.forEach((pestana, i) => {
      pestana.addEventListener('click', () => mostrar(i, false));
    });

    lista.addEventListener('keydown', (evento) => {
      const actual = pestanas.findIndex(p => p.getAttribute('aria-selected') === 'true');
      const salto = { ArrowRight: 1, ArrowLeft: -1 }[evento.key];
      if (salto) {
        evento.preventDefault();
        mostrar((actual + salto + pestanas.length) % pestanas.length);
      } else if (evento.key === 'Home') {
        evento.preventDefault();
        mostrar(0);
      } else if (evento.key === 'End') {
        evento.preventDefault();
        mostrar(pestanas.length - 1);
      }
    });
  });
}
