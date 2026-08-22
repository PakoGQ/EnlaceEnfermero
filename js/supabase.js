/* ==========================================================================
   Enlace Enfermero — Cliente de Supabase
   Unica dependencia externa del proyecto (CLAUDE.md regla 4).
   Requiere que la pagina cargue antes:
     <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
     <script src="js/config.js"></script>
   ========================================================================== */

/* Mientras no se capturen las credenciales reales, el sitio debe seguir
   navegando sin romperse: las paginas verifican `supabaseListo()` antes de
   consultar y muestran un estado vacio en vez de un error en consola. */
const SUPABASE_CONFIGURADO =
  typeof CONFIG !== 'undefined' &&
  !CONFIG.SUPABASE_URL.includes('TU-PROYECTO') &&
  !['TU_ANON_KEY', 'CLAVE_LOCAL_PENDIENTE'].includes(CONFIG.SUPABASE_ANON_KEY);

let db = null;

if (SUPABASE_CONFIGURADO && typeof window.supabase !== 'undefined') {
  db = window.supabase.createClient(CONFIG.SUPABASE_URL, CONFIG.SUPABASE_ANON_KEY, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  });
}

/** Indica si hay conexion utilizable con la base de datos. */
function supabaseListo() {
  return db !== null;
}

/**
 * Envuelve una consulta a Supabase y normaliza el manejo de error.
 * Devuelve { datos, error } — `error` ya viene con mensaje en espanol.
 */
async function consultar(promesa) {
  if (!supabaseListo()) {
    return { datos: null, error: 'Aún no se ha conectado la base de datos.' };
  }
  try {
    const { data, error } = await promesa;
    if (error) {
      return { datos: null, error: traducirError(error) };
    }
    return { datos: data, error: null };
  } catch (e) {
    return { datos: null, error: 'No pudimos conectar con el servidor. Revisa tu conexión e intenta de nuevo.' };
  }
}

/** Traduce los errores mas comunes de Supabase a espanol claro. */
function traducirError(error) {
  const codigo = error.code || '';
  const mensaje = (error.message || '').toLowerCase();

  if (codigo === '23505' || mensaje.includes('duplicate key')) {
    return 'Ese registro ya existe.';
  }
  if (codigo === '23503') {
    return 'El registro está ligado a otra información y no puede modificarse.';
  }
  if (codigo === '42501' || mensaje.includes('row-level security')) {
    return 'No tienes permiso para realizar esta acción.';
  }
  if (mensaje.includes('invalid login credentials')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (mensaje.includes('email not confirmed')) {
    return 'Debes confirmar tu correo antes de iniciar sesión.';
  }
  if (mensaje.includes('user already registered')) {
    return 'Ya existe una cuenta con ese correo.';
  }
  if (mensaje.includes('failed to fetch') || mensaje.includes('network')) {
    return 'No pudimos conectar con el servidor. Revisa tu conexión.';
  }
  return 'Ocurrió un error. Intenta de nuevo en un momento.';
}

/* ==========================================================================
   DIAGNOSTICO
   Herramienta de instalacion. Abre el sitio, abre la consola del navegador
   (F12) y escribe:  diagnostico()
   Revisa la conexion paso por paso y dice exactamente que falta.
   ========================================================================== */

async function diagnostico() {
  const linea = (estado, texto, detalle = '') =>
    console.log(`%c${estado}%c ${texto}${detalle ? '\n   ' + detalle : ''}`,
      `background:${estado === ' OK ' ? '#12B76A' : estado === ' AVISO ' ? '#F79009' : '#D92D20'};` +
      'color:#fff;border-radius:3px;padding:1px 4px;font-weight:bold',
      'color:inherit');

  console.log('%cDiagnóstico de Enlace Enfermero', 'font-size:15px;font-weight:bold;color:#0D6EFD');

  // 1. Credenciales capturadas
  if (typeof CONFIG === 'undefined') {
    return linea(' FALLA ', 'No se cargó js/config.js.',
      'Revisa que la página incluya <script src="js/config.js"></script>');
  }
  if (!SUPABASE_CONFIGURADO) {
    return linea(' FALLA ', 'Faltan las credenciales en js/config.js.',
      'Sustituye SUPABASE_URL y SUPABASE_ANON_KEY por los valores de tu proyecto.');
  }
  linea(' OK ', 'Credenciales capturadas.', CONFIG.SUPABASE_URL);

  // 2. La llave debe ser la anon, nunca la service_role
  try {
    const cuerpo = JSON.parse(atob(CONFIG.SUPABASE_ANON_KEY.split('.')[1]));
    if (cuerpo.role === 'service_role') {
      return linea(' FALLA ', 'PELIGRO: pegaste la llave service_role.',
        'Esa llave da acceso total y NUNCA debe ir en el frontend. ' +
        'Bórrala de config.js, rótala en Supabase y usa la llave anon public.');
    }
    linea(' OK ', `Tipo de llave correcto: ${cuerpo.role}.`);
  } catch (e) {
    linea(' AVISO ', 'No se pudo leer el tipo de llave.', 'Verifica que copiaste la llave completa.');
  }

  // 3. Conexion y biblioteca
  if (!window.supabase) {
    return linea(' FALLA ', 'No se cargó la biblioteca de Supabase.',
      'Revisa la etiqueta <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2">');
  }
  if (!db) {
    return linea(' FALLA ', 'No se pudo crear el cliente.');
  }
  linea(' OK ', 'Cliente creado.');

  // 4. El catalogo publico
  const { data: catalogo, error: errCatalogo } = await db
    .from('enfermeros_publico').select('id', { count: 'exact', head: false }).limit(1);

  if (errCatalogo) {
    const m = (errCatalogo.message || '').toLowerCase();
    if (m.includes('does not exist') || m.includes('schema cache')) {
      return linea(' FALLA ', 'La vista enfermeros_publico no existe.',
        'Ejecuta los scripts de la carpeta sql/ en el orden 01, 02, 03, 04.');
    }
    return linea(' FALLA ', 'Error al leer el catálogo.', errCatalogo.message);
  }
  linea(' OK ', 'La vista enfermeros_publico responde.',
    catalogo.length ? 'Hay perfiles publicados.' : 'Está vacía: ejecuta sql/05-seed.sql o da de alta personal.');

  // 5. RLS: la tabla enfermeros NO debe ser legible en publico
  const { data: fuga } = await db.from('enfermeros').select('id').limit(1);
  if (fuga && fuga.length) {
    linea(' FALLA ', 'GRAVE: la tabla enfermeros es legible sin sesión.',
      'Expone tarifas y notas internas. Revisa que ejecutaste sql/02-rls.sql completo.');
  } else {
    linea(' OK ', 'RLS activo: la tabla enfermeros no se puede leer en público.');
  }

  // 6. Alta publica de solicitudes
  const { error: errSolicitud } = await db.from('solicitudes').insert({
    tipo_servicio: 'cuidado_domiciliario',
    fecha_inicio: hoyISO(),
    contacto_nombre: 'PRUEBA DE DIAGNOSTICO',
    origen: 'diagnostico'
  });

  if (errSolicitud) {
    linea(' FALLA ', 'El formulario público no puede guardar solicitudes.', errSolicitud.message);
  } else {
    linea(' OK ', 'El formulario público puede guardar solicitudes.',
      'Se creó una con el nombre PRUEBA DE DIAGNOSTICO: bórrala desde Supabase.');
  }

  console.log('%cListo. Si todo dice OK, el sitio ya está conectado.',
    'font-weight:bold;color:#12B76A');
}
