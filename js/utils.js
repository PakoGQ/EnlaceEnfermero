/* ==========================================================================
   Enlace Enfermero — Utilidades
   Formato de fecha y moneda, validaciones, toasts, URL y registro de visitas.
   ========================================================================== */

/* ==========================================================================
   FORMATO
   ========================================================================== */

/** 1234.5 -> "$1,234.50" */
function moneda(valor) {
  const n = Number(valor);
  if (!isFinite(n)) return '$0.00';
  return new Intl.NumberFormat('es-MX', {
    style: 'currency', currency: 'MXN', minimumFractionDigits: 2
  }).format(n);
}

/** 1234.5 -> "$1,235" (sin centavos, para KPIs) */
function monedaCorta(valor) {
  const n = Number(valor);
  if (!isFinite(n)) return '$0';
  return new Intl.NumberFormat('es-MX', {
    style: 'currency', currency: 'MXN', maximumFractionDigits: 0
  }).format(n);
}

/** "2026-08-18" -> "18 de agosto de 2026" */
function fechaLarga(valor) {
  const f = aFecha(valor);
  if (!f) return '';
  return new Intl.DateTimeFormat('es-MX', {
    day: 'numeric', month: 'long', year: 'numeric'
  }).format(f);
}

/** "2026-08-18" -> "18 ago 2026" */
function fechaCorta(valor) {
  const f = aFecha(valor);
  if (!f) return '';
  return new Intl.DateTimeFormat('es-MX', {
    day: '2-digit', month: 'short', year: 'numeric'
  }).format(f);
}

/** "2026-08-18T14:30:00Z" -> "18 ago 2026, 08:30 a. m." */
function fechaHora(valor) {
  const f = aFecha(valor);
  if (!f) return '';
  return new Intl.DateTimeFormat('es-MX', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit'
  }).format(f);
}

/** "14:30:00" -> "02:30 p. m." */
function hora(valor) {
  if (!valor) return '';
  const [h, m] = String(valor).split(':');
  const f = new Date();
  f.setHours(Number(h), Number(m), 0, 0);
  return new Intl.DateTimeFormat('es-MX', { hour: '2-digit', minute: '2-digit' }).format(f);
}

/** Diferencia legible: "hace 3 dias", "en 2 semanas" */
function tiempoRelativo(valor) {
  const f = aFecha(valor);
  if (!f) return '';
  const segundos = Math.round((f - new Date()) / 1000);
  const rangos = [
    ['year',   31536000], ['month',  2592000], ['week',   604800],
    ['day',    86400],    ['hour',   3600],    ['minute', 60]
  ];
  const rtf = new Intl.RelativeTimeFormat('es-MX', { numeric: 'auto' });
  for (const [unidad, seg] of rangos) {
    if (Math.abs(segundos) >= seg) return rtf.format(Math.round(segundos / seg), unidad);
  }
  return rtf.format(segundos, 'second');
}

/** Convierte un valor a Date de forma segura. Las fechas puras (YYYY-MM-DD)
    se construyen en horario local para evitar el corrimiento de un dia. */
function aFecha(valor) {
  if (!valor) return null;
  if (valor instanceof Date) return isNaN(valor) ? null : valor;
  const texto = String(valor);
  if (/^\d{4}-\d{2}-\d{2}$/.test(texto)) {
    const [a, m, d] = texto.split('-').map(Number);
    return new Date(a, m - 1, d);
  }
  const f = new Date(texto);
  return isNaN(f) ? null : f;
}

/** Fecha de hoy en formato YYYY-MM-DD (horario local, no UTC). */
function hoyISO() {
  const f = new Date();
  const mes = String(f.getMonth() + 1).padStart(2, '0');
  const dia = String(f.getDate()).padStart(2, '0');
  return `${f.getFullYear()}-${mes}-${dia}`;
}

/** "5215512345678" -> "+52 55 1234 5678" */
function telefonoLegible(valor) {
  const d = soloDigitos(valor).replace(/^52/, '');
  if (d.length !== 10) return valor || '';
  return `+52 ${d.slice(0, 2)} ${d.slice(2, 6)} ${d.slice(6)}`;
}

function soloDigitos(valor) {
  return String(valor || '').replace(/\D/g, '');
}

/** Normaliza a +52XXXXXXXXXX como exige el modelo de datos (CLAUDE.md 5.2). */
function normalizarTelefono(valor) {
  let d = soloDigitos(valor);
  if (d.length === 10) d = '52' + d;
  if (d.startsWith('521') && d.length === 13) d = '52' + d.slice(3); // quita el 1 de celular
  return '+' + d;
}

/** Iniciales para el avatar cuando no hay foto. */
function iniciales(nombre) {
  return String(nombre || '?')
    .trim().split(/\s+/).slice(0, 2)
    .map(p => p.charAt(0).toUpperCase()).join('');
}

/* ==========================================================================
   REPARTO DEL SERVICIO (CLAUDE.md 15.2)
   El cliente paga a la agencia; la agencia paga al enfermero.
   ========================================================================== */

/**
 * Descompone lo que paga el cliente en las dos partes del reparto.
 * @param {number} tarifaCliente total facturado al cliente
 * @returns {{cliente:number, enfermero:number, agencia:number}} montos en pesos
 */
function repartir(tarifaCliente) {
  const total = Number(tarifaCliente) || 0;
  // Se redondea a centavos el pago al enfermero y la agencia se queda con el
  // resto, para que las dos partes sumen siempre exactamente el total.
  const enfermero = Math.round(total * CONFIG.PORCENTAJE_ENFERMERO * 100) / 100;
  return {
    cliente: total,
    enfermero,
    agencia: Math.round((total - enfermero) * 100) / 100
  };
}

/**
 * Camino inverso: a partir de lo que debe cobrar el enfermero, cuanto se le
 * factura al cliente. Sirve para cotizar desde la tarifa neta del profesional.
 */
function tarifaClienteDesdeEnfermero(tarifaEnfermero) {
  const neto = Number(tarifaEnfermero) || 0;
  return Math.round((neto / CONFIG.PORCENTAJE_ENFERMERO) * 100) / 100;
}

/** Busca el `nombre` de un id dentro de un catalogo de config.js. */
function etiqueta(catalogo, id) {
  if (!Array.isArray(catalogo)) return catalogo?.[id]?.nombre || id || '';
  const item = catalogo.find(x => x.id === id);
  return item ? item.nombre : (id || '');
}

/* ==========================================================================
   SEGURIDAD DE RENDER
   ========================================================================== */

/** Escapa texto antes de insertarlo con innerHTML. Usar SIEMPRE con datos
    provenientes de la base de datos o de la URL. */
function esc(texto) {
  if (texto === null || texto === undefined) return '';
  return String(texto)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

/* ==========================================================================
   VALIDACIONES
   ========================================================================== */

const validar = {
  email: v => /^[^\s@]+@[^\s@]+\.[a-z]{2,}$/i.test(String(v || '').trim()),

  /** Celular mexicano: 10 digitos, con o sin lada +52. */
  telefono: v => {
    const d = soloDigitos(v).replace(/^52/, '');
    return d.length === 10;
  },

  curp: v => /^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$/i.test(String(v || '').trim()),

  /** RFC de persona fisica (13) o moral (12). */
  rfc: v => /^([A-ZÑ&]{3,4})\d{6}([A-Z0-9]{3})$/i.test(String(v || '').trim()),

  /** Cedula profesional: 7 u 8 digitos. Se valida contra la SEP manualmente. */
  cedula: v => /^\d{7,8}$/.test(soloDigitos(v)),

  requerido: v => String(v ?? '').trim().length > 0,

  minimo: (v, n) => String(v ?? '').trim().length >= n,

  /** Fecha no anterior a hoy. */
  fechaFutura: v => {
    const f = aFecha(v);
    if (!f) return false;
    const hoy = new Date(); hoy.setHours(0, 0, 0, 0);
    return f >= hoy;
  },

  /** Mayor de edad. */
  mayorDeEdad: v => {
    const f = aFecha(v);
    if (!f) return false;
    const limite = new Date();
    limite.setFullYear(limite.getFullYear() - 18);
    return f <= limite;
  }
};

/** Marca un campo con error y muestra el mensaje bajo el control. */
function marcarError(input, mensaje) {
  const campo = input.closest('.campo');
  if (!campo) return;
  campo.classList.add('error');
  input.setAttribute('aria-invalid', 'true');
  let aviso = campo.querySelector('.mensaje-error');
  if (!aviso) {
    aviso = document.createElement('span');
    aviso.className = 'mensaje-error';
    aviso.setAttribute('role', 'alert');
    campo.appendChild(aviso);
  }
  aviso.textContent = mensaje;
}

/** Limpia el estado de error de un campo. */
function limpiarError(input) {
  const campo = input.closest('.campo');
  if (!campo) return;
  campo.classList.remove('error');
  input.removeAttribute('aria-invalid');
  campo.querySelector('.mensaje-error')?.remove();
}

/** Limpia todos los errores de un formulario. */
function limpiarErrores(form) {
  form.querySelectorAll('.campo.error').forEach(c => {
    c.classList.remove('error');
    c.querySelector('.mensaje-error')?.remove();
  });
  form.querySelectorAll('[aria-invalid]').forEach(i => i.removeAttribute('aria-invalid'));
}

/* ==========================================================================
   TOASTS
   ========================================================================== */

const ICONOS_TOAST = {
  exito:  '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>',
  error:  '<circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>',
  alerta: '<path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>',
  info:   '<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>'
};

/**
 * Muestra un aviso flotante.
 * @param {string} mensaje texto en espanol para el usuario
 * @param {'exito'|'error'|'alerta'|'info'} tipo
 */
function toast(mensaje, tipo = 'info', duracion = 4500) {
  let zona = document.querySelector('.toasts');
  if (!zona) {
    zona = document.createElement('div');
    zona.className = 'toasts';
    zona.setAttribute('aria-live', 'polite');
    zona.setAttribute('aria-atomic', 'false');
    document.body.appendChild(zona);
  }

  const el = document.createElement('div');
  el.className = `toast toast-${tipo}`;
  el.setAttribute('role', tipo === 'error' ? 'alert' : 'status');
  el.innerHTML = `
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor"
         stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      ${ICONOS_TOAST[tipo] || ICONOS_TOAST.info}
    </svg>
    <span>${esc(mensaje)}</span>`;
  zona.appendChild(el);

  setTimeout(() => {
    el.classList.add('saliendo');
    el.addEventListener('animationend', () => el.remove(), { once: true });
  }, duracion);
}

/* ==========================================================================
   URL Y NAVEGACION
   ========================================================================== */

/** Lee un parametro de la URL. */
function paramURL(nombre) {
  return new URLSearchParams(window.location.search).get(nombre);
}

/** Escribe parametros en la URL sin recargar (para filtros compartibles). */
function actualizarURL(params) {
  const url = new URL(window.location);
  Object.entries(params).forEach(([clave, valor]) => {
    if (valor === null || valor === undefined || valor === '' ||
        (Array.isArray(valor) && valor.length === 0)) {
      url.searchParams.delete(clave);
    } else {
      url.searchParams.set(clave, Array.isArray(valor) ? valor.join(',') : valor);
    }
  });
  window.history.replaceState({}, '', url);
}

/** Enlace de WhatsApp a la agencia con mensaje predefinido. */
function enlaceWhatsApp(mensaje = '') {
  const texto = encodeURIComponent(mensaje || 'Hola, me interesa el servicio de Enlace Enfermero.');
  return `https://wa.me/${CONFIG.WHATSAPP_AGENCIA}?text=${texto}`;
}

/* ==========================================================================
   ANIMACION DE ENTRADA
   ========================================================================== */

/* Los elementos .aparece arrancan en opacity 0 y solo se muestran cuando el
   IntersectionObserver avisa que entraron en pantalla. Si el navegador no
   entrega esas notificaciones, la pagina se queda en blanco: por eso se
   diagnostica una vez y el resultado se recuerda para las llamadas siguientes,
   que pueden traer contenido cargado despues (destacados, testimonios, FAQ). */
let observadorConfiable = null;   // null = sin diagnosticar, false = no responde

/** Muestra los elementos sin animacion. */
function mostrarTodo(elementos) {
  elementos.forEach(el => el.classList.add('visible'));
}

/** Aplica fade-in a todos los elementos con clase .aparece (CLAUDE.md 3.4). */
function activarAparicion() {
  const elementos = document.querySelectorAll('.aparece:not(.visible)');
  if (!elementos.length) return;

  if (observadorConfiable === false ||
      !('IntersectionObserver' in window) ||
      window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    mostrarTodo(elementos);
    return;
  }

  const observador = new IntersectionObserver((entradas) => {
    entradas.forEach(entrada => {
      if (entrada.isIntersecting) {
        observadorConfiable = true;
        entrada.target.classList.add('visible');
        observador.unobserve(entrada.target);
      }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

  elementos.forEach(el => observador.observe(el));

  // Diagnostico: si nada de lo que ya estaba en pantalla se marco como
  // visible, el observador no esta respondiendo y se descarta el efecto.
  setTimeout(() => {
    if (observadorConfiable !== null) return;

    const enPantalla = [...elementos].filter(el => {
      const r = el.getBoundingClientRect();
      return r.top < window.innerHeight && r.bottom > 0;
    });
    if (!enPantalla.length) return;   // nada que diagnosticar todavia

    if (enPantalla.every(el => !el.classList.contains('visible'))) {
      observadorConfiable = false;
      observador.disconnect();
      mostrarTodo(document.querySelectorAll('.aparece:not(.visible)'));
    }
  }, 1500);
}

/* ==========================================================================
   VARIOS
   ========================================================================== */

/** Retrasa la ejecucion hasta que dejen de llegar llamadas (buscadores). */
function retardar(fn, ms = 350) {
  let temporizador;
  return (...args) => {
    clearTimeout(temporizador);
    temporizador = setTimeout(() => fn(...args), ms);
  };
}

/** Registra la visita a la pagina en la tabla `visitas` (CLAUDE.md 5.2).
    Falla en silencio: la analitica nunca debe romper la navegacion. */
async function registrarVisita() {
  if (!supabaseListo()) return;
  const p = new URLSearchParams(window.location.search);
  try {
    await db.from('visitas').insert({
      pagina: window.location.pathname,
      referrer: document.referrer || null,
      utm_source: p.get('utm_source'),
      utm_medium: p.get('utm_medium'),
      utm_campaign: p.get('utm_campaign'),
      user_agent: navigator.userAgent
    });
  } catch (e) { /* sin efecto para el usuario */ }
}
