/* ==========================================================================
   Enlace Enfermero — Estructura de los paneles
   Barra superior y navegacion lateral, compartidas por las tres areas
   privadas. El menu cambia segun el rol; el acceso lo controla protegerRuta()
   y, en ultima instancia, las politicas de RLS de la base.
   ========================================================================== */

const MENUS = {
  admin: [
    { href: 'index.html',        texto: 'Panel',         icono: 'panel' },
    { href: 'solicitudes.html',  texto: 'Solicitudes',   icono: 'inbox' },
    { href: 'asignaciones.html', texto: 'Asignaciones',  icono: 'check' },
    { href: 'calendario.html',   texto: 'Calendario',    icono: 'calendario' },
    { href: 'enfermeros.html',   texto: 'Enfermeros',    icono: 'usuarios' },
    { href: 'documentos.html',   texto: 'Documentos',    icono: 'documento' },
    { href: 'clientes.html',     texto: 'Clientes',      icono: 'hospital' },
    { href: 'pagos.html',        texto: 'Pagos',         icono: 'dinero' },
    { href: 'reportes.html',     texto: 'Reportes',      icono: 'maletin' },
    { href: 'referidos.html',    texto: 'Referidos',     icono: 'escudo' },
    { href: 'configuracion.html',texto: 'Configuración', icono: 'filtro' }
  ],
  enfermero: [
    { href: 'index.html',          texto: 'Inicio',         icono: 'panel' },
    { href: 'asignaciones.html',   texto: 'Mis turnos',     icono: 'calendario' },
    { href: 'disponibilidad.html', texto: 'Disponibilidad', icono: 'reloj' },
    { href: 'perfil.html',         texto: 'Mi perfil',      icono: 'usuarios' },
    { href: 'documentos.html',     texto: 'Documentos',     icono: 'documento' },
    { href: 'historial.html',      texto: 'Historial',      icono: 'check' },
    { href: 'ganancias.html',      texto: 'Ganancias',      icono: 'dinero' }
  ],
  cliente: [
    { href: 'index.html',        texto: 'Inicio',          icono: 'panel' },
    { href: 'solicitar.html',    texto: 'Nueva solicitud', icono: 'inbox' },
    { href: 'solicitudes.html',  texto: 'Mis solicitudes', icono: 'documento' },
    { href: 'personal.html',     texto: 'Personal',        icono: 'usuarios' },
    { href: 'evaluar.html',      texto: 'Evaluar',         icono: 'estrella' },
    { href: 'facturacion.html',  texto: 'Facturación',     icono: 'dinero' }
  ]
};

/** El coordinador ve lo mismo que el admin salvo lo que toca dinero y ajustes. */
const OCULTO_A_COORDINACION = ['pagos.html', 'configuracion.html', 'reportes.html'];

/**
 * Pinta la estructura del panel.
 * @param {object} perfil el que devuelve protegerRuta()
 * @param {string} activa archivo actual, p.ej. 'solicitudes.html'
 */
function renderPanel(perfil, activa = 'index.html') {
  const r = raiz();
  const area = perfil.rol === 'cliente' ? 'cliente'
             : perfil.rol === 'enfermero' ? 'enfermero'
             : 'admin';

  let menu = MENUS[area];
  if (perfil.rol === 'coordinador') {
    menu = menu.filter(m => !OCULTO_A_COORDINACION.includes(m.href));
  }

  const nombre = `${perfil.nombre} ${perfil.apellidos || ''}`.trim();
  const etiquetaRol = {
    admin: 'Agencia', coordinador: 'Coordinación',
    enfermero: 'Enfermero/a', cliente: 'Cliente'
  }[perfil.rol] || perfil.rol;

  // --- Barra superior ---
  const cabecera = document.getElementById('panelCabecera');
  if (cabecera) {
    cabecera.className = 'panel-cabecera';
    cabecera.innerHTML = `
      <button class="btn-icono panel-menu-boton" id="btnMenuPanel"
              aria-label="Abrir menú" aria-expanded="false">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor"
             stroke-width="2" stroke-linecap="round" aria-hidden="true">
          <line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/>
          <line x1="3" y1="18" x2="21" y2="18"/>
        </svg>
      </button>

      <a href="${r}index.html" class="logo panel-logo">
        <img src="${r}assets/logo.svg" alt="" width="34" height="34">
        <span class="logo-texto">Enlace<span>Enfermero</span></span>
      </a>

      <div class="panel-usuario">
        <div class="panel-usuario-datos">
          <strong>${esc(nombre)}</strong>
          <span>${esc(etiquetaRol)}</span>
        </div>
        <div class="panel-avatar" aria-hidden="true">${esc(iniciales(nombre))}</div>
        <button type="button" class="btn btn-fantasma btn-sm" id="btnSalir">
          ${icono('salir', 18)}<span class="salir-texto">Salir</span>
        </button>
      </div>`;
  }

  // --- Navegacion lateral ---
  const lateral = document.getElementById('panelNav');
  if (lateral) {
    lateral.className = 'panel-nav';
    lateral.innerHTML = `
      <nav aria-label="Secciones">
        ${menu.map(m => `
          <a href="${m.href}" class="panel-nav-link${m.href === activa ? ' activo' : ''}"
             ${m.href === activa ? 'aria-current="page"' : ''}>
            ${icono(m.icono, 19)}<span>${esc(m.texto)}</span>
          </a>`).join('')}
      </nav>
      <a href="${r}index.html" class="panel-nav-link panel-nav-pie">
        ${icono('flechaDer', 19)}<span>Ver el sitio público</span>
      </a>`;
  }

  activarMenuPanel();
  document.getElementById('btnSalir')?.addEventListener('click', cerrarSesion);
}

/** Abre y cierra la navegacion lateral en pantallas chicas. */
function activarMenuPanel() {
  const boton  = document.getElementById('btnMenuPanel');
  const nav    = document.getElementById('panelNav');
  if (!boton || !nav) return;

  let velo = document.getElementById('veloPanel');
  if (!velo) {
    velo = document.createElement('div');
    velo.id = 'veloPanel';
    velo.className = 'velo-panel';
    document.body.appendChild(velo);
  }

  const alternar = (abierto) => {
    nav.classList.toggle('abierto', abierto);
    velo.classList.toggle('abierto', abierto);
    boton.setAttribute('aria-expanded', String(abierto));
    document.body.style.overflow = abierto ? 'hidden' : '';
  };

  boton.addEventListener('click', () => alternar(!nav.classList.contains('abierto')));
  velo.addEventListener('click', () => alternar(false));
  nav.querySelectorAll('a').forEach(a => a.addEventListener('click', () => alternar(false)));
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && nav.classList.contains('abierto')) alternar(false);
  });
}

/**
 * Arranque de cualquier pagina de panel: comprueba la sesion, pinta la
 * estructura y devuelve el perfil. Si no hay acceso, redirige y devuelve null.
 */
async function iniciarPanel(rolesPermitidos, activa = 'index.html') {
  const perfil = await protegerRuta(rolesPermitidos);
  if (!perfil) return null;
  renderPanel(perfil, activa);

  // El vencimiento de un documento ocurre por el paso del tiempo, no por un
  // evento, asi que ningun trigger lo detecta. El catalogo publico no depende
  // de esto (la vista lo evalua al consultar), pero el ESTADO GUARDADO si, y es
  // el que la agencia lee en sus pantallas: sin esta llamada, la bandeja de
  // documentos mostraba "vencidos: 0" con papeles ya caducados enfrente.
  //
  // Va aqui y no en cada pantalla porque si no seria un juego de topos: basta
  // que una lo olvide para que muestre datos rancios. Casi siempre no cambia
  // nada, asi que solo se avisa cuando de verdad despublico a alguien.
  if (['admin', 'coordinador'].includes(perfil.rol)) {
    consultar(db.rpc('marcar_documentos_vencidos')).then(({ datos }) => {
      if (datos?.perfiles_despublicados > 0) {
        const n = datos.perfiles_despublicados;
        toast(`${n} ${n === 1 ? 'perfil salió' : 'perfiles salieron'} del catálogo ` +
              'por documentos vencidos.', 'alerta');
      }
    });
  }

  return perfil;
}
