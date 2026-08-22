/* ==========================================================================
   Enlace Enfermero — Configuracion global
   Constantes de la aplicacion y catalogos de negocio (CLAUDE.md 5.3 y 12).

   ATENCION: aqui SOLO va la anon key de Supabase. La service_role key
   nunca debe aparecer en el frontend (CLAUDE.md regla 9).
   ========================================================================== */

/* Detecta si el sitio corre en la maquina de desarrollo. Asi se puede trabajar
   contra el Supabase local sin tener que editar este archivo antes de publicar,
   y sin riesgo de subir a produccion apuntando a una base que solo existe aqui. */
const ES_LOCAL = ['localhost', '127.0.0.1', ''].includes(window.location.hostname);

const CONFIG = {
  /* --- Supabase ---
     PRODUCCION: sustituir los dos valores de abajo por los del proyecto real
     (Settings -> API). Solo la llave `anon public`, nunca la `service_role`.
     LOCAL: los valores los pone `supabase start`; son claves de desarrollo
     conocidas y no protegen nada, por eso pueden vivir en el repositorio. */
  SUPABASE_URL: ES_LOCAL
    ? 'http://127.0.0.1:54321'
    : 'https://TU-PROYECTO.supabase.co',

  SUPABASE_ANON_KEY: ES_LOCAL
    ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
    : 'TU_ANON_KEY',

  /* --- Datos de la agencia: pendientes de confirmar con el cliente --- */
  NOMBRE_AGENCIA: 'Enlace Enfermero',
  WHATSAPP_AGENCIA: '523310000000',            // pendiente: numero real
  EMAIL_AGENCIA: 'contacto@enlaceenfermero.mx', // pendiente: correo real
  CIUDAD_BASE: 'Guadalajara, Jalisco',

  /* Redes sociales: se pintan en el footer solo las que tengan URL.
     Se dejan vacias a proposito para no publicar enlaces rotos. */
  REDES: {
    Facebook:  '',
    Instagram: '',
    LinkedIn:  ''
  },

  /* --- Reglas de negocio --- */
  /* Reparto de cada servicio: el cliente paga a la agencia y la agencia paga
     al enfermero. Los dos porcentajes deben sumar 1 (CLAUDE.md 15.2). */
  COMISION_AGENCIA: 0.40,
  PORCENTAJE_ENFERMERO: 0.60,
  ITEMS_POR_PAGINA: 12,
  DIAS_ALERTA_VENCIMIENTO: 30,   // documentos por vencer (CLAUDE.md 7.8)
  DIAS_PARA_EVALUAR: 15,         // la evaluacion expira a los 15 dias (10.7)
  HORAS_CANCELACION: 12,         // cancelacion tardia (10.9)

  /* --- Rutas por rol tras iniciar sesion (CLAUDE.md 6) ---
     Relativas a proposito: en GitHub Pages el sitio puede vivir en un
     subdirectorio, y una ruta absoluta apuntaria fuera del proyecto. */
  RUTAS_ROL: {
    admin:       'admin/index.html',
    coordinador: 'admin/index.html',
    enfermero:   'panel/index.html',
    cliente:     'cliente/index.html'
  }
};

/* ==========================================================================
   CATALOGOS (CLAUDE.md 5.3)
   El `id` se usa en la base de datos y en la URL. El `nombre` es lo que ve
   el usuario. Nunca cambiar un `id` ya usado en produccion.
   ========================================================================== */

const ESPECIALIDADES = [
  { id: 'uci',              nombre: 'Cuidados intensivos (UCI/UTI)' },
  { id: 'urgencias',        nombre: 'Urgencias' },
  { id: 'quirofano',        nombre: 'Quirófano / Instrumentista' },
  { id: 'pediatria',        nombre: 'Pediatría' },
  { id: 'neonatologia',     nombre: 'Neonatología' },
  { id: 'geriatria',        nombre: 'Geriatría' },
  { id: 'oncologia',        nombre: 'Oncología' },
  { id: 'nefrologia',       nombre: 'Nefrología / Hemodiálisis' },
  { id: 'cardiologia',      nombre: 'Cardiología' },
  { id: 'salud_mental',     nombre: 'Salud mental' },
  { id: 'heridas',          nombre: 'Heridas y estomas' },
  { id: 'paliativos',       nombre: 'Cuidados paliativos' },
  { id: 'materno_infantil', nombre: 'Materno-infantil' },
  { id: 'medicina_interna', nombre: 'Medicina interna' },
  { id: 'postoperatorio',   nombre: 'Cuidado postoperatorio' },
  { id: 'rehabilitacion',   nombre: 'Rehabilitación' },
  { id: 'general',          nombre: 'Enfermería general' }
];

const CERTIFICACIONES = [
  { id: 'bls',              nombre: 'BLS (Soporte vital básico)' },
  { id: 'acls',             nombre: 'ACLS (Soporte vital cardiovascular avanzado)' },
  { id: 'pals',             nombre: 'PALS (Soporte vital pediátrico avanzado)' },
  { id: 'nrp',              nombre: 'NRP (Reanimación neonatal)' },
  { id: 'via_aerea',        nombre: 'Manejo de vía aérea' },
  { id: 'heridas_avanzadas',nombre: 'Curación de heridas avanzadas' },
  { id: 'cateteres',        nombre: 'Manejo de catéteres' },
  { id: 'ventilacion',      nombre: 'Ventilación mecánica' },
  { id: 'muestras',         nombre: 'Toma de muestras' },
  { id: 'medicamentos_iv',  nombre: 'Aplicación de medicamentos IV' }
];

/* Los idiomas se guardan por id, igual que especialidades y certificaciones.
   Sin este catalogo el panel no sabia traducirlos y al guardar el perfil los
   borraba, porque ninguna casilla coincidia con lo almacenado. */
const IDIOMAS = [
  { id: 'espanol', nombre: 'Español' },
  { id: 'ingles',  nombre: 'Inglés' },
  { id: 'frances', nombre: 'Francés' },
  { id: 'aleman',  nombre: 'Alemán' },
  { id: 'lsm',     nombre: 'Lengua de Señas Mexicana' }
];

const MUNICIPIOS = [
  { id: 'guadalajara',   nombre: 'Guadalajara' },
  { id: 'zapopan',       nombre: 'Zapopan' },
  { id: 'tlaquepaque',   nombre: 'Tlaquepaque' },
  { id: 'tonala',        nombre: 'Tonalá' },
  { id: 'tlajomulco',    nombre: 'Tlajomulco' },
  { id: 'el_salto',      nombre: 'El Salto' },
  { id: 'zapotlanejo',   nombre: 'Zapotlanejo' },
  { id: 'juanacatlan',   nombre: 'Juanacatlán' },
  { id: 'ixtlahuacan',   nombre: 'Ixtlahuacán de los Membrillos' }
];

/* --- Enumerados de la base de datos con su etiqueta visible --- */

const NIVELES = [
  { id: 'auxiliar',     nombre: 'Auxiliar de enfermería' },
  { id: 'tecnico',      nombre: 'Técnico en enfermería' },
  { id: 'general',      nombre: 'Enfermero/a general' },
  { id: 'licenciado',   nombre: 'Licenciado/a en enfermería' },
  { id: 'especialista', nombre: 'Enfermero/a especialista' },
  { id: 'cuidador',     nombre: 'Cuidador/a de adulto mayor' }
];

const TIPOS_CLIENTE = [
  { id: 'particular',  nombre: 'Particular / Familia' },
  { id: 'hospital',    nombre: 'Hospital' },
  { id: 'clinica',     nombre: 'Clínica' },
  { id: 'asilo',       nombre: 'Asilo o casa de retiro' },
  { id: 'aseguradora', nombre: 'Aseguradora' },
  { id: 'empresa',     nombre: 'Empresa' }
];

const TIPOS_SERVICIO = [
  { id: 'turno_hospitalario',    nombre: 'Turno hospitalario' },
  { id: 'cuidado_domiciliario',  nombre: 'Cuidado domiciliario' },
  { id: 'colocacion_permanente', nombre: 'Colocación permanente' },
  { id: 'evento',                nombre: 'Cobertura de evento' },
  { id: 'traslado',              nombre: 'Traslado de paciente' }
];

const TURNOS = [
  { id: 'matutino',    nombre: 'Matutino (07:00 - 15:00)',  horas: 8 },
  { id: 'vespertino',  nombre: 'Vespertino (15:00 - 23:00)', horas: 8 },
  { id: 'nocturno',    nombre: 'Nocturno (23:00 - 07:00)',   horas: 8 },
  { id: 'guardia_12',  nombre: 'Guardia de 12 horas',        horas: 12 },
  { id: 'guardia_24',  nombre: 'Guardia de 24 horas',        horas: 24 },
  { id: 'fin_semana',  nombre: 'Fin de semana',              horas: 12 }
];

/* --- Variables de cotizacion (CLAUDE.md 15.5) ---
   No hay tabulador fijo: la agencia cotiza cada servicio con estos datos.
   Por eso se capturan estructurados y no como texto libre. */

const NIVELES_ATENCION = [
  { id: 'observacion',   nombre: 'Solo observación y acompañamiento',
    ayuda: 'El paciente es autosuficiente; se requiere presencia y vigilancia.' },
  { id: 'basico',        nombre: 'Apoyo en actividades básicas',
    ayuda: 'Higiene, alimentación, movilización y acompañamiento.' },
  { id: 'enfermeria',    nombre: 'Cuidados de enfermería',
    ayuda: 'Medicamentos, signos vitales, curaciones y seguimiento.' },
  { id: 'especializado', nombre: 'Cuidados especializados',
    ayuda: 'Paciente crítico, ventilación, diálisis o procedimientos avanzados.' }
];

const TIPOS_PACIENTE = [
  { id: 'adulto_mayor',   nombre: 'Adulto mayor' },
  { id: 'postoperatorio', nombre: 'Postoperatorio' },
  { id: 'cronico',        nombre: 'Enfermedad crónica' },
  { id: 'paliativo',      nombre: 'Cuidados paliativos' },
  { id: 'pediatrico',     nombre: 'Paciente pediátrico' },
  { id: 'maternidad',     nombre: 'Maternidad o recién nacido' },
  { id: 'discapacidad',   nombre: 'Movilidad reducida o discapacidad' },
  { id: 'rehabilitacion', nombre: 'En rehabilitación' },
  { id: 'no_aplica',      nombre: 'No aplica (cobertura de plantilla)' }
];

const ENTORNOS = [
  { id: 'domicilio', nombre: 'Domicilio particular' },
  { id: 'hospital',  nombre: 'Hospital' },
  { id: 'clinica',   nombre: 'Clínica o consultorio' },
  { id: 'asilo',     nombre: 'Asilo o casa de retiro' },
  { id: 'empresa',   nombre: 'Empresa u oficina' },
  { id: 'evento',    nombre: 'Evento o espacio público' }
];

const PROCEDIMIENTOS = [
  { id: 'signos',              nombre: 'Toma de signos vitales' },
  { id: 'medicamentos_orales', nombre: 'Administración de medicamentos orales' },
  { id: 'medicamentos_iv',     nombre: 'Medicamentos intravenosos' },
  { id: 'curaciones',          nombre: 'Curación de heridas' },
  { id: 'sondas',              nombre: 'Manejo de sondas' },
  { id: 'cateteres',           nombre: 'Manejo de catéteres' },
  { id: 'oxigeno',             nombre: 'Oxigenoterapia' },
  { id: 'ventilacion',         nombre: 'Ventilación mecánica' },
  { id: 'alimentacion_sonda',  nombre: 'Alimentación por sonda' },
  { id: 'glucosa',             nombre: 'Control de glucosa' },
  { id: 'movilizacion',        nombre: 'Movilización y cambios de posición' },
  { id: 'higiene',             nombre: 'Aseo y cuidado personal' },
  { id: 'traslado',            nombre: 'Acompañamiento en traslados' },
  { id: 'ninguno',             nombre: 'Ninguno en particular' }
];

const DIAS_SEMANA = [
  { id: 'lun', nombre: 'Lunes' },     { id: 'mar', nombre: 'Martes' },
  { id: 'mie', nombre: 'Miércoles' }, { id: 'jue', nombre: 'Jueves' },
  { id: 'vie', nombre: 'Viernes' },   { id: 'sab', nombre: 'Sábado' },
  { id: 'dom', nombre: 'Domingo' }
];

const TIPOS_DOCUMENTO = [
  { id: 'ine',                    nombre: 'INE / Identificación oficial', obligatorio: true },
  { id: 'curp',                   nombre: 'CURP',                          obligatorio: true },
  { id: 'comprobante_domicilio',  nombre: 'Comprobante de domicilio',      obligatorio: true },
  { id: 'cedula_profesional',     nombre: 'Cédula profesional',            obligatorio: false },
  { id: 'titulo',                 nombre: 'Título o constancia de estudios', obligatorio: false },
  { id: 'certificado_bls',        nombre: 'Certificado BLS',               obligatorio: false },
  { id: 'certificado_acls',       nombre: 'Certificado ACLS',              obligatorio: false },
  { id: 'carta_no_antecedentes',  nombre: 'Carta de no antecedentes penales', obligatorio: false },
  { id: 'examen_medico',          nombre: 'Examen médico',                 obligatorio: false },
  { id: 'vacunacion',             nombre: 'Cartilla de vacunación',        obligatorio: false },
  { id: 'cv',                     nombre: 'Currículum vítae',              obligatorio: false },
  { id: 'referencia_laboral',     nombre: 'Referencia laboral',            obligatorio: false }
];

/* Niveles que requieren cedula profesional + titulo (CLAUDE.md 10.2) */
const NIVELES_CON_CEDULA = ['general', 'licenciado', 'especialista'];

/* --- Etiquetas y color de cada estatus, para badges en la UI --- */

const ESTATUS_SOLICITUD = {
  nueva:             { nombre: 'Nueva',             clase: 'badge-azul' },
  en_busqueda:       { nombre: 'En búsqueda',       clase: 'badge-alerta' },
  propuesta_enviada: { nombre: 'Propuesta enviada', clase: 'badge-cyan' },
  confirmada:        { nombre: 'Confirmada',        clase: 'badge-exito' },
  en_curso:          { nombre: 'En curso',          clase: 'badge-cyan' },
  completada:        { nombre: 'Completada',        clase: 'badge-exito' },
  cancelada:         { nombre: 'Cancelada',         clase: 'badge-error' }
};

const ESTATUS_ASIGNACION = {
  propuesta:  { nombre: 'Propuesta',   clase: 'badge-azul' },
  aceptada:   { nombre: 'Aceptada',    clase: 'badge-exito' },
  rechazada:  { nombre: 'Rechazada',   clase: 'badge-error' },
  en_curso:   { nombre: 'En curso',    clase: 'badge-cyan' },
  completada: { nombre: 'Completada',  clase: 'badge-exito' },
  no_asistio: { nombre: 'No asistió',  clase: 'badge-error' },
  cancelada:  { nombre: 'Cancelada',   clase: 'badge-gris' }
};

const ESTATUS_VERIFICACION = {
  pendiente:   { nombre: 'Pendiente',    clase: 'badge-gris' },
  en_revision: { nombre: 'En revisión',  clase: 'badge-alerta' },
  verificado:  { nombre: 'Verificado',   clase: 'badge-exito' },
  rechazado:   { nombre: 'Rechazado',    clase: 'badge-error' },
  vencido:     { nombre: 'Vencido',      clase: 'badge-error' }
};

const ESTATUS_PAGO = {
  pendiente: { nombre: 'Pendiente', clase: 'badge-alerta' },
  parcial:   { nombre: 'Parcial',   clase: 'badge-cyan' },
  pagado:    { nombre: 'Pagado',    clase: 'badge-exito' },
  vencido:   { nombre: 'Vencido',   clase: 'badge-error' },
  cancelado: { nombre: 'Cancelado', clase: 'badge-gris' }
};
