/* ==========================================================================
   Enlace Enfermero — Autenticacion y guardia de rutas
   Inicio de sesion, registro, recuperacion y control de acceso por rol.

   La sesion la maneja Supabase (CLAUDE.md 2): aqui no se guarda nada en
   localStorage ni se confia en el rol que venga del navegador. El rol se lee
   siempre de la tabla `usuarios`, y quien manda de verdad son las politicas
   de RLS: aunque alguien burlara esta guardia, la base no le devolveria nada
   que no le corresponda.
   ========================================================================== */

/* Se guarda en memoria durante la carga de la pagina para no repetir la
   consulta en cada llamada. Se pierde al recargar, que es lo que se quiere. */
let _sesion = null;

/**
 * Devuelve el usuario en sesion con su rol, o null.
 * @returns {Promise<{id, email, rol, nombre, apellidos, foto_url}|null>}
 */
async function sesionActual(forzar = false) {
  if (_sesion && !forzar) return _sesion;
  if (!supabaseListo()) return null;

  const { data: { session } } = await db.auth.getSession();
  if (!session) { _sesion = null; return null; }

  const { data: perfil, error } = await db
    .from('usuarios')
    .select('id, rol, nombre, apellidos, email, telefono, foto_url, activo')
    .eq('id', session.user.id)
    .maybeSingle();

  if (error || !perfil) {
    // La cuenta existe en Auth pero no tiene fila en `usuarios`. Pasa si el
    // trigger no corrio; sin rol no se puede decidir nada, asi que se corta.
    _sesion = null;
    return null;
  }

  if (!perfil.activo) {
    await db.auth.signOut();
    _sesion = null;
    return null;
  }

  _sesion = perfil;
  return _sesion;
}

/** A donde va cada rol despues de entrar. */
function rutaSegunRol(rol) {
  return CONFIG.RUTAS_ROL[rol] || 'index.html';
}

/* ==========================================================================
   INICIO Y CIERRE DE SESION
   ========================================================================== */

/**
 * @returns {Promise<{ok: boolean, destino?: string, error?: string}>}
 */
async function iniciarSesion(email, contrasena) {
  if (!supabaseListo()) {
    return { ok: false, error: 'Aún no se ha conectado la base de datos.' };
  }

  const { data, error } = await db.auth.signInWithPassword({
    email: email.trim().toLowerCase(),
    password: contrasena
  });

  if (error) return { ok: false, error: traducirError(error) };

  const perfil = await sesionActual(true);
  if (!perfil) {
    await db.auth.signOut();
    return { ok: false, error: 'Tu cuenta no tiene un perfil activo. Contacta a la agencia.' };
  }

  // Sin await: la bitacora no debe retrasar la entrada
  db.from('usuarios').update({ ultimo_acceso: new Date().toISOString() })
    .eq('id', perfil.id).then(() => {}, () => {});

  return { ok: true, destino: rutaSegunRol(perfil.rol), perfil };
}

async function cerrarSesion() {
  _sesion = null;
  if (supabaseListo()) await db.auth.signOut();
  window.location.href = raiz() + 'index.html';
}

/* ==========================================================================
   REGISTRO DE CLIENTES
   El registro de enfermeros NO pasa por aqui: entra como candidato desde
   unete.html y la agencia le crea la cuenta al verificarlo (CLAUDE.md 8.5).
   ========================================================================== */

async function registrarCliente({ nombre, apellidos, email, telefono, contrasena }) {
  if (!supabaseListo()) {
    return { ok: false, error: 'Aún no se ha conectado la base de datos.' };
  }

  const { data, error } = await db.auth.signUp({
    email: email.trim().toLowerCase(),
    password: contrasena,
    options: {
      // El rol viaja en los metadatos y lo consume el trigger crear_usuario_desde_auth
      data: { nombre, apellidos, telefono: normalizarTelefono(telefono), rol: 'cliente' },
      emailRedirectTo: window.location.origin + window.location.pathname.replace(/[^/]*$/, 'login.html')
    }
  });

  if (error) return { ok: false, error: traducirError(error) };

  // Con confirmacion de correo activada la sesion todavia no existe
  const requiereConfirmacion = !data.session;
  return { ok: true, requiereConfirmacion };
}

/* ==========================================================================
   RECUPERACION DE CONTRASENA
   ========================================================================== */

async function enviarRecuperacion(email) {
  if (!supabaseListo()) {
    return { ok: false, error: 'Aún no se ha conectado la base de datos.' };
  }

  const destino = window.location.origin +
    window.location.pathname.replace(/[^/]*$/, 'recuperar.html');

  const { error } = await db.auth.resetPasswordForEmail(
    email.trim().toLowerCase(), { redirectTo: destino }
  );

  // No se distingue si el correo existe o no: eso permitiria averiguar
  // quien tiene cuenta en la plataforma.
  if (error && !/user not found/i.test(error.message || '')) {
    return { ok: false, error: traducirError(error) };
  }
  return { ok: true };
}

async function actualizarContrasena(nueva) {
  if (!supabaseListo()) {
    return { ok: false, error: 'Aún no se ha conectado la base de datos.' };
  }
  const { error } = await db.auth.updateUser({ password: nueva });
  if (error) return { ok: false, error: traducirError(error) };
  return { ok: true };
}

/* ==========================================================================
   GUARDIA DE RUTAS
   ========================================================================== */

/**
 * Corta el acceso a una pagina segun el rol. Se llama al principio del <head>
 * de cada pagina privada, antes de pintar nada.
 *
 * @param {string[]} rolesPermitidos p.ej. ['admin', 'coordinador']
 * @returns {Promise<object|null>} el perfil si pasa; si no, redirige
 */
async function protegerRuta(rolesPermitidos) {
  document.documentElement.classList.add('verificando-sesion');

  const perfil = await sesionActual();
  const r = raiz();

  if (!perfil) {
    // Se recuerda a donde queria entrar para volver ahi despues de entrar
    const destino = encodeURIComponent(
      window.location.pathname.split('/').slice(-2).join('/') + window.location.search
    );
    window.location.replace(`${r}login.html?volver=${destino}`);
    return null;
  }

  if (!rolesPermitidos.includes(perfil.rol)) {
    // Tiene sesion pero no le toca esta seccion: se le manda a la suya
    window.location.replace(r + rutaSegunRol(perfil.rol));
    return null;
  }

  document.documentElement.classList.remove('verificando-sesion');
  return perfil;
}

/** Para las paginas publicas: si ya hay sesion, ofrece ir a su panel. */
async function sesionEnPaginaPublica() {
  const perfil = await sesionActual();
  if (!perfil) return null;
  return { perfil, destino: raiz() + rutaSegunRol(perfil.rol) };
}
