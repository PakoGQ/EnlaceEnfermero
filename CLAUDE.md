# CLAUDE.md — Enlace Enfermero

> Documento maestro de especificación del proyecto. Claude Code debe leer este archivo
> completo antes de escribir una sola línea de código y consultarlo en cada iteración.

---

## 0. Reglas de trabajo para Claude Code

**Estas reglas son obligatorias y tienen prioridad sobre cualquier otra consideración técnica.**

1. **Un cambio a la vez.** Nunca implementes múltiples features en una sola tanda. Termina, muestra, valida, avanza.
2. **Prueba visual obligatoria.** Después de cada cambio en UI, indica exactamente qué archivo abrir en el navegador y qué debe verse. No avances hasta confirmación.
3. **No inventes datos ni endpoints.** Si falta una decisión de negocio, pregunta antes de asumir.
4. **Vanilla estricto.** Nada de React, Vue, Next, Tailwind por CDN, ni build steps. HTML + CSS + JavaScript puro. Única dependencia externa permitida: el cliente JS de Supabase vía CDN.
5. **Mobile-first siempre.** El 80% del tráfico será celular. Diseña primero a 375px, luego escala.
6. **Español mexicano** en toda la interfaz, comentarios y mensajes de error visibles al usuario. Nombres de variables, tablas y columnas en español sin acentos (`enfermeros`, `fecha_inicio`, `estatus`).
7. **No borres código existente sin avisar.** Si algo estorba, coméntalo y explica por qué.
8. **Cada archivo nuevo se anuncia** con su ruta completa antes de crearlo.
9. **Nunca publiques la `service_role key`** de Supabase en el frontend. Solo `anon key`.
10. **Fase por fase.** No adelantes trabajo de la Fase 3 si estamos en la Fase 1.

---

## 1. Resumen ejecutivo

**Enlace Enfermero** es una plataforma web para una agencia de reclutamiento y colocación de personal de enfermería en México (inicio: Zona Metropolitana de Guadalajara, Jalisco).

Conecta tres actores:

| Actor | Quién es | Qué obtiene |
|---|---|---|
| **Enfermero/a** | Auxiliar, técnico, general, licenciado o especialista con cédula. **Trabaja como prestador de servicios independiente (freelance)**, no como empleado de la agencia | Perfil profesional verificado, oferta constante de turnos y colocaciones, pagos ordenados |
| **Cliente** | Hospitales, clínicas, asilos, casas de retiro, aseguradoras y particulares | Personal verificado, disponible y con respaldo de agencia |
| **Agencia (Admin)** | Enlace Enfermero | Comisión por colocación temporal + cuota por colocación permanente |

### Modelos de ingreso

1. **Colocación temporal / staffing por turno** — la agencia cobra al cliente una tarifa por turno y reparte el ingreso: **60% para el enfermero, 40% para la agencia**. El cliente contrata siempre con la agencia y le paga a la agencia; la agencia paga al enfermero.
2. **Colocación permanente (headhunting)** — cuota única al cliente por contratación definitiva (referencia: 1 a 1.5 meses del sueldo del puesto).
3. **Cuidado domiciliario** — turnos de 8/12/24 hrs en domicilio del paciente, facturados por la agencia.
4. **Membresía institucional (Fase 4, opcional)** — cuota mensual para clientes con volumen que garantiza tiempos de respuesta y tarifas preferentes.

### Estado del proyecto
Proyecto nuevo, desde cero. Replica la arquitectura ya validada del proyecto Doncellas
(vanilla + Supabase + GitHub Pages + panel admin + panel de proveedor + agente conversacional en Fase 2).

---

## 2. Stack técnico

**Idéntico al de Doncellas. No sustituir ninguna pieza sin autorización explícita.**

| Capa | Tecnología |
|---|---|
| Frontend | HTML5, CSS3 (variables nativas), JavaScript ES6+ vanilla |
| Backend / BD | Supabase (PostgreSQL + Auth + Storage + Row Level Security) |
| Hosting | GitHub Pages (rama `main`, carpeta raíz) |
| Automatización (Fase 2) | Make.com |
| Mensajería (Fase 2) | WhatsApp Business API |
| IA conversacional (Fase 2) | Claude API (`claude-sonnet-4-6`) |
| Notificaciones | WhatsApp + correo transaccional (Resend o SMTP vía Make) |
| Analítica | Registro propio en tabla `visitas` + Google Analytics 4 (opcional) |

### Restricciones técnicas
- Sin frameworks, sin bundlers, sin npm en el frontend.
- Sin `localStorage` para datos sensibles; solo la sesión que maneja Supabase.
- Imágenes en Supabase Storage, nunca en el repositorio.
- Todo el CSS en archivos separados. Nada de estilos en línea salvo valores calculados por JS.

---

## 3. Identidad visual

### 3.1 Concepto
Limpio, clínico pero cálido. Debe transmitir **confianza médica + humanidad**.
Referencias de tono: dashboards de salud digital modernos (Doctoralia, Nurse.com, Mediktor),
no hospital burocrático. Mucho espacio en blanco, tarjetas con sombras suaves, esquinas redondeadas,
iconografía de línea. Nada de imágenes genéricas de stock con jeringas.

### 3.2 Paleta de colores

```css
:root {
  /* Azules — identidad principal */
  --azul-900: #04263F;   /* texto sobre claro, footer */
  --azul-800: #073B63;   /* headers oscuros */
  --azul-700: #0B5394;   /* hover de botones */
  --azul-600: #0D6EFD;   /* AZUL PRIMARIO — botones, links, acentos */
  --azul-500: #3B8DF5;   /* estados activos */
  --azul-400: #6BABF8;   /* bordes activos */
  --azul-200: #BFDBFE;   /* fondos de badge */
  --azul-100: #E3F0FF;   /* fondos de sección */
  --azul-050: #F4F9FF;   /* fondo alterno de página */

  /* Cyan / turquesa — acento secundario "salud" */
  --cyan-600: #0891B2;
  --cyan-400: #22D3EE;
  --cyan-100: #CFFAFE;

  /* Neutros */
  --blanco:   #FFFFFF;
  --gris-050: #F8FAFC;
  --gris-100: #F1F5F9;
  --gris-200: #E2E8F0;   /* bordes */
  --gris-400: #94A3B8;   /* texto deshabilitado */
  --gris-600: #475569;   /* texto secundario */
  --gris-900: #0F172A;   /* texto principal */

  /* Semánticos */
  --exito:    #12B76A;   /* verificado, disponible, completado */
  --exito-bg: #E7F8F0;
  --alerta:   #F79009;   /* pendiente, por vencer */
  --alerta-bg:#FEF3E2;
  --error:    #D92D20;   /* rechazado, cancelado, documento vencido */
  --error-bg: #FEE4E2;
  --info:     var(--azul-600);

  /* Sombras */
  --sombra-sm: 0 1px 2px rgba(4, 38, 63, .06);
  --sombra-md: 0 4px 16px rgba(4, 38, 63, .08);
  --sombra-lg: 0 12px 32px rgba(4, 38, 63, .12);

  /* Radios */
  --radio-sm: 8px;
  --radio-md: 14px;
  --radio-lg: 22px;
  --radio-full: 999px;

  /* Espaciado (escala de 4) */
  --e1: 4px;  --e2: 8px;  --e3: 12px; --e4: 16px;
  --e5: 24px; --e6: 32px; --e7: 48px; --e8: 64px; --e9: 96px;

  /* Tipografía */
  --fuente-titulo: 'Plus Jakarta Sans', 'Segoe UI', system-ui, sans-serif;
  --fuente-texto:  'Inter', system-ui, -apple-system, sans-serif;

  /* Transiciones */
  --trans: 200ms cubic-bezier(.4, 0, .2, 1);
}
```

**Regla de uso de color:** fondo blanco dominante (mínimo 70% de la pantalla).
El azul se usa en botones, encabezados, iconos y acentos. El cyan solo para gráficas,
badges de especialidad y detalles decorativos. Nunca fondos azules a pantalla completa
salvo el hero de la landing y el footer.

### 3.3 Tipografía
- Títulos: **Plus Jakarta Sans** 600/700/800 — Google Fonts.
- Cuerpo: **Inter** 400/500/600 — Google Fonts.
- Escala: `h1 clamp(2rem, 5vw, 3.5rem)` / `h2 clamp(1.5rem, 3.5vw, 2.25rem)` / `h3 1.35rem` / `body 1rem` / `small .875rem`.
- Interlineado: 1.6 en párrafos, 1.2 en títulos.

### 3.4 Componentes visuales clave
- **Tarjeta de enfermero:** foto circular con anillo azul, nombre, badge de nivel, badge verde "Verificado" con ícono de escudo, especialidades como chips cyan, años de experiencia, estrellas de calificación, botón "Ver perfil" y "Solicitar".
- **Badge de verificación:** obligatorio y muy visible. Es el diferenciador del negocio.
- **Botón primario:** fondo `--azul-600`, texto blanco, radio `--radio-full`, sombra media, hover que sube 2px.
- **Hero de landing:** degradado `linear-gradient(135deg, var(--azul-800), var(--azul-600) 60%, var(--cyan-600))`, texto blanco, con formas orgánicas SVG en el fondo (ondas suaves, nunca cruces rojas ni simbología clínica agresiva).
- **Iconografía:** SVG inline de trazo 1.5–2px, sin librerías externas.
- **Animaciones:** solo `opacity` y `transform`. Fade-in al hacer scroll vía `IntersectionObserver`. Duración máx 400ms.
- **Accesibilidad:** contraste mínimo AA, `:focus-visible` con outline azul de 3px, todo interactivo alcanzable con teclado, `alt` en todas las imágenes.

---

## 4. Estructura de archivos

```
enlace-enfermero/
├── index.html                    # Landing pública
├── enfermeros.html               # Catálogo público de personal (con filtros)
├── perfil.html                   # Perfil individual (?id=uuid)
├── servicios.html                # Detalle de los servicios de la agencia
├── solicitar.html                # Formulario público de solicitud de personal
├── unete.html                    # Registro de enfermeros (alta de candidato)
├── nosotros.html                 # Quiénes somos / confianza
├── contacto.html                 # Contacto + FAQ
├── login.html                    # Acceso unificado (redirige por rol)
├── registro.html                 # Registro de cliente
├── recuperar.html                # Recuperación de contraseña
├── aviso-privacidad.html         # LFPDPPP — obligatorio
├── terminos.html                 # Términos y condiciones
├── 404.html
│
├── admin/                        # PANEL AGENCIA (rol: admin)
│   ├── index.html                # Dashboard con KPIs
│   ├── enfermeros.html           # Alta, edición, verificación
│   ├── documentos.html           # Bandeja de verificación documental
│   ├── clientes.html             # Cartera de clientes
│   ├── solicitudes.html          # Solicitudes entrantes
│   ├── asignaciones.html         # Match enfermero ↔ solicitud
│   ├── calendario.html           # Vista mensual de turnos cubiertos
│   ├── pagos.html                # Cobros a clientes y pagos a enfermeros
│   ├── reportes.html             # Métricas y exportación CSV
│   ├── referidos.html            # Programa de referidos
│   └── configuracion.html        # Tarifas, comisiones, catálogos
│
├── panel/                        # PANEL ENFERMERO (rol: enfermero)
│   ├── index.html                # Resumen: próximos turnos, ganancias, alertas
│   ├── perfil.html               # Editar perfil profesional
│   ├── documentos.html           # Subir/renovar documentos
│   ├── disponibilidad.html       # Calendario de disponibilidad
│   ├── asignaciones.html         # Ofertas recibidas / aceptar / rechazar
│   ├── historial.html            # Turnos completados
│   └── ganancias.html            # Ingresos por periodo
│
├── cliente/                      # PANEL CLIENTE (rol: cliente)
│   ├── index.html                # Resumen de servicios activos
│   ├── solicitar.html            # Nueva solicitud
│   ├── solicitudes.html          # Estatus de solicitudes
│   ├── personal.html             # Personal asignado actual e histórico
│   ├── evaluar.html              # Calificar un servicio
│   └── facturacion.html          # Historial de pagos y facturas
│
├── css/
│   ├── variables.css             # Tokens de la sección 3.2
│   ├── base.css                  # Reset, tipografía, utilidades
│   ├── componentes.css           # Botones, tarjetas, badges, modales, tablas, forms
│   ├── layout.css                # Header, footer, grids, contenedores
│   ├── publico.css               # Estilos exclusivos de páginas públicas
│   ├── panel.css                 # Estilos compartidos de los 3 paneles
│   └── responsive.css            # Media queries centralizadas
│
├── js/
│   ├── config.js                 # URL y anon key de Supabase + constantes
│   ├── supabase.js               # Inicialización del cliente
│   ├── auth.js                   # login, registro, logout, guardia de rutas por rol
│   ├── utils.js                  # formato de fechas, moneda MXN, toasts, validaciones
│   ├── componentes.js            # render de tarjetas, modales, paginación, tablas
│   ├── publico.js                # catálogo, filtros, perfil, formularios públicos
│   ├── panel-admin.js
│   ├── panel-enfermero.js
│   ├── panel-cliente.js
│   └── referidos.js
│
├── assets/
│   ├── logo.svg
│   ├── logo-blanco.svg
│   ├── favicon.svg
│   ├── icons/                    # SVG sueltos si se reutilizan
│   └── img/                      # solo imágenes estáticas del sitio
│
├── sql/
│   ├── 01-schema.sql             # Tablas, tipos, índices
│   ├── 02-rls.sql                # Políticas de seguridad
│   ├── 03-funciones.sql          # Triggers y funciones
│   ├── 04-vistas.sql             # Vistas para reportes
│   └── 05-seed.sql               # Datos de prueba
│
├── docs/
│   ├── despliegue.md
│   ├── make-escenarios.md        # Fase 2
│   └── manual-admin.md
│
├── CLAUDE.md                     # Este archivo
└── README.md
```

---

## 5. Modelo de datos (Supabase / PostgreSQL)

### 5.1 Tipos enumerados

```sql
create type rol_usuario      as enum ('admin', 'coordinador', 'enfermero', 'cliente');
create type nivel_enfermeria as enum ('auxiliar', 'tecnico', 'general', 'licenciado', 'especialista', 'cuidador');
create type tipo_cliente     as enum ('particular', 'hospital', 'clinica', 'asilo', 'aseguradora', 'empresa');
create type tipo_servicio    as enum ('turno_hospitalario', 'cuidado_domiciliario', 'colocacion_permanente', 'evento', 'traslado');
create type turno_tipo       as enum ('matutino', 'vespertino', 'nocturno', 'guardia_12', 'guardia_24', 'fin_semana');
create type estatus_solicitud   as enum ('nueva', 'en_busqueda', 'propuesta_enviada', 'confirmada', 'en_curso', 'completada', 'cancelada');
create type estatus_asignacion  as enum ('propuesta', 'aceptada', 'rechazada', 'en_curso', 'completada', 'no_asistio', 'cancelada');
create type estatus_verif    as enum ('pendiente', 'en_revision', 'verificado', 'rechazado', 'vencido');
create type tipo_documento   as enum ('ine', 'curp', 'cedula_profesional', 'titulo', 'comprobante_domicilio', 'certificado_bls', 'certificado_acls', 'carta_no_antecedentes', 'examen_medico', 'vacunacion', 'cv', 'referencia_laboral');
create type estatus_pago     as enum ('pendiente', 'parcial', 'pagado', 'vencido', 'cancelado');
```

### 5.2 Tablas

#### `usuarios`
Espejo de `auth.users` con el rol y datos base.

| Columna | Tipo | Notas |
|---|---|---|
| id | uuid PK | = `auth.users.id` |
| rol | rol_usuario | default `'cliente'` |
| nombre | text | requerido |
| apellidos | text | |
| email | text unique | |
| telefono | text | formato +52XXXXXXXXXX |
| whatsapp | text | |
| foto_url | text | |
| activo | boolean | default true |
| ultimo_acceso | timestamptz | |
| created_at | timestamptz | default now() |

#### `enfermeros`
Perfil profesional. Es el corazón del catálogo.

| Columna | Tipo | Notas |
|---|---|---|
| id | uuid PK | default gen_random_uuid() |
| usuario_id | uuid FK → usuarios | unique, nullable (la agencia puede dar de alta sin cuenta) |
| folio | text unique | generado: `EE-00001` |
| nombre_completo | text | |
| fecha_nacimiento | date | |
| genero | text | |
| nivel | nivel_enfermeria | |
| cedula_profesional | text | validable contra RNP/SEP |
| cedula_verificada | boolean | default false |
| institucion_egreso | text | |
| anios_experiencia | int | |
| especialidades | text[] | ver catálogo 5.3 |
| certificaciones | text[] | BLS, ACLS, PALS, heridas, etc. |
| idiomas | text[] | |
| bio | text | máx 600 caracteres |
| foto_url | text | Storage bucket `fotos` |
| zonas_cobertura | text[] | municipios/colonias |
| disponible_inmediato | boolean | default false |
| acepta_domicilio | boolean | |
| acepta_nocturno | boolean | |
| acepta_foraneo | boolean | |
| tarifa_hora | numeric(10,2) | tarifa de REFERENCIA del enfermero, base para cotizar (no es precio fijo) |
| tarifa_turno_8 | numeric(10,2) | |
| tarifa_turno_12 | numeric(10,2) | |
| tarifa_turno_24 | numeric(10,2) | |
| calificacion_promedio | numeric(3,2) | calculado por trigger |
| total_servicios | int | default 0 |
| estatus_verificacion | estatus_verif | default `'pendiente'` |
| notas_internas | text | **solo admin, nunca se expone al público** |
| publicado | boolean | default false — solo `true` aparece en el catálogo |
| created_at / updated_at | timestamptz | |

#### `clientes`

| Columna | Tipo |
|---|---|
| id | uuid PK |
| usuario_id | uuid FK → usuarios, nullable |
| tipo | tipo_cliente |
| razon_social | text |
| nombre_contacto | text |
| telefono / email | text |
| rfc | text |
| requiere_factura | boolean |
| direccion, colonia, municipio, cp | text |
| notas | text |
| activo | boolean |
| created_at | timestamptz |

#### `solicitudes`

| Columna | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| folio | text unique | `SOL-00001` |
| cliente_id | uuid FK | nullable si es lead sin cuenta |
| tipo_servicio | tipo_servicio | |
| nivel_requerido | nivel_enfermeria | |
| especialidad_requerida | text[] | |
| descripcion_paciente | text | edad, condición, cuidados necesarios |
| fecha_inicio | date | |
| fecha_fin | date | nullable si es indefinido |
| turno | turno_tipo | |
| horas_por_turno | int | |
| dias_semana | text[] | |
| direccion_servicio | text | |
| municipio | text | |
| tarifa_ofrecida_cliente | numeric(10,2) | lo que paga el cliente |
| estatus | estatus_solicitud | default `'nueva'` |
| urgente | boolean | |
| origen | text | landing, whatsapp, referido, telefono |
| codigo_referido | text | |
| created_at | timestamptz | |

#### `asignaciones`
La tabla que genera el dinero. Una solicitud puede tener varias asignaciones (varios turnos / varios enfermeros).

| Columna | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| solicitud_id | uuid FK | |
| enfermero_id | uuid FK | |
| fecha | date | |
| turno | turno_tipo | |
| hora_inicio / hora_fin | time | |
| tarifa_cliente | numeric(10,2) | lo facturado |
| tarifa_enfermero | numeric(10,2) | lo pagado |
| comision_agencia | numeric(10,2) | **generada**: `tarifa_cliente - tarifa_enfermero` |
| estatus | estatus_asignacion | default `'propuesta'` |
| checkin_at / checkout_at | timestamptz | confirmación de asistencia |
| notas | text | |
| created_at | timestamptz | |

#### `disponibilidad`
| id | enfermero_id | fecha | turno | disponible (bool) | nota |

Índice único en `(enfermero_id, fecha, turno)`.

#### `documentos`
| Columna | Tipo |
|---|---|
| id | uuid PK |
| enfermero_id | uuid FK |
| tipo | tipo_documento |
| archivo_url | text (Storage bucket privado `documentos`) |
| fecha_emision | date |
| fecha_vencimiento | date |
| estatus | estatus_verif |
| verificado_por | uuid FK → usuarios |
| verificado_at | timestamptz |
| motivo_rechazo | text |

#### `evaluaciones`
| id | asignacion_id | cliente_id | enfermero_id | puntualidad (1-5) | trato (1-5) | competencia_tecnica (1-5) | calificacion_general (1-5) | comentario | publica (bool) | created_at |

#### `pagos`
| id | tipo ('cobro_cliente' \| 'pago_enfermero') | referencia_id (solicitud o enfermero) | periodo_inicio | periodo_fin | monto | metodo | estatus estatus_pago | comprobante_url | fecha_pago | notas |

#### `codigos_referido` y `referidos`
Réplica exacta del mecanismo de Doncellas.

- `codigos_referido`: `id, usuario_id, codigo text unique (REF-XXXXXX), tipo ('enfermero'|'cliente'), usos int, activo, created_at`
- `referidos`: `id, codigo, referidor_id, referido_id, tipo_referido, estatus ('registrado'|'validado'|'pagado'), recompensa_monto, fecha_validacion`

**Regla de negocio:** la recompensa se acredita **solo cuando el referido completa su primer servicio pagado**, nunca al registrarse.
- Enfermero refiere enfermero: $300 MXN al completar el primer turno del referido.
- Cliente refiere cliente: 10% de descuento en el siguiente servicio.

#### `actividad`
Bitácora: `id, usuario_id, accion, tabla_afectada, registro_id, detalle jsonb, ip, created_at`.
Se escribe en toda alta, cambio de estatus y verificación.

#### `leads`
Captura de la landing antes de que exista cuenta: `id, nombre, telefono, email, mensaje, tipo ('busco_personal'|'busco_empleo'), origen, utm_source, utm_campaign, atendido bool, created_at`.

#### `visitas`
`id, pagina, referrer, utm_source, utm_medium, utm_campaign, user_agent, created_at` — registro propio de tráfico, igual que en Doncellas.

### 5.3 Catálogos (constantes en `js/config.js`)

**Especialidades:** Cuidados intensivos (UCI/UTI), Urgencias, Quirófano/Instrumentista, Pediatría, Neonatología, Geriatría, Oncología, Nefrología/Hemodiálisis, Cardiología, Salud mental, Heridas y estomas, Cuidados paliativos, Materno-infantil, Medicina interna, Cuidado postoperatorio, Rehabilitación, Enfermería general.

**Certificaciones:** BLS, ACLS, PALS, NRP, manejo de vía aérea, curación de heridas avanzadas, manejo de catéteres, ventilación mecánica, toma de muestras, aplicación de medicamentos IV.

**Municipios base (ZMG):** Guadalajara, Zapopan, Tlaquepaque, Tonalá, Tlajomulco, El Salto, Zapotlanejo, Juanacatlán, Ixtlahuacán de los Membrillos.

---

## 6. Seguridad y RLS

**Mismo patrón que Doncellas.** RLS activo en todas las tablas sin excepción.

### Función auxiliar
```sql
create or replace function public.mi_rol()
returns rol_usuario language sql stable security definer as $$
  select rol from public.usuarios where id = auth.uid();
$$;
```

### Políticas por tabla (resumen)

| Tabla | Público (anon) | Enfermero | Cliente | Admin |
|---|---|---|---|---|
| `usuarios` | — | lee/edita su fila | lee/edita su fila | todo |
| `enfermeros` | SELECT solo `publicado = true AND estatus_verificacion='verificado'`, con **columnas restringidas** (ver abajo) | lee/edita su fila | lee catálogo público | todo |
| `clientes` | — | — | su fila | todo |
| `solicitudes` | INSERT (lead público permitido) | lee solo las de sus asignaciones | sus solicitudes | todo |
| `asignaciones` | — | sus asignaciones; puede cambiar estatus a aceptada/rechazada | las de sus solicitudes | todo |
| `disponibilidad` | — | CRUD propio | — | todo |
| `documentos` | — | INSERT/SELECT propios, sin poder cambiar `estatus` | — | todo |
| `evaluaciones` | SELECT `publica = true` | SELECT propias | INSERT sobre asignaciones completadas suyas | todo |
| `pagos` | — | SELECT propios | SELECT propios | todo |
| `leads`, `visitas` | INSERT | — | — | SELECT/todo |
| `actividad` | — | — | — | SELECT |

### Exposición pública controlada
El catálogo público **no debe consultar la tabla `enfermeros` directamente**. Se crea una vista:

```sql
create view public.enfermeros_publico as
select id, folio, nombre_completo, nivel, anios_experiencia, especialidades,
       certificaciones, idiomas, bio, foto_url, zonas_cobertura,
       disponible_inmediato, calificacion_promedio, total_servicios,
       cedula_verificada
from public.enfermeros
where publicado = true and estatus_verificacion = 'verificado';
```

**Nunca se exponen públicamente:** cédula profesional completa, teléfono, correo, dirección, tarifas netas, notas internas, documentos. El contacto siempre pasa por la agencia. Este es el modelo de negocio: si el cliente puede contactar directo al enfermero, se pierde la comisión.

### Storage
- Bucket `fotos` — público de lectura, escritura solo autenticado.
- Bucket `documentos` — **privado**. Acceso solo vía URL firmada generada para admin y para el propio enfermero.
- Bucket `comprobantes` — privado, solo admin.

---

## 7. Funciones y triggers

1. **`generar_folio_enfermero()`** — trigger BEFORE INSERT en `enfermeros`, asigna `EE-00001` secuencial.
2. **`generar_folio_solicitud()`** — igual para `SOL-00001`.
3. **`generar_codigo_referido()`** — AFTER INSERT en `usuarios`: crea `REF-` + 6 caracteres alfanuméricos aleatorios únicos.
4. **`actualizar_calificacion_enfermero()`** — AFTER INSERT/UPDATE en `evaluaciones`: recalcula `calificacion_promedio` y `total_servicios`.
5. **`calcular_comision()`** — columna generada o trigger BEFORE en `asignaciones`.
6. **`validar_traslape()`** — BEFORE INSERT en `asignaciones`: impide asignar al mismo enfermero dos turnos que se traslapen en fecha y horario. **Crítico.**
7. **`registrar_actividad()`** — trigger genérico sobre las tablas clave.
8. **`alertar_documentos_por_vencer()`** — función invocable que devuelve documentos con `fecha_vencimiento` dentro de 30 días. Se consume desde el dashboard admin y desde Make.com en Fase 2.
9. **`set_updated_at()`** — trigger universal.

### Vistas para reportes
- `v_kpis_mes` — servicios completados, ingresos, comisión, enfermeros activos, tasa de cobertura.
- `v_ranking_enfermeros` — por calificación y turnos completados.
- `v_solicitudes_sin_cubrir` — solicitudes con estatus `en_busqueda` a más de 24 h.
- `v_ganancias_enfermero` — agregado por enfermero y periodo.

---

## 8. Especificación página por página

### 8.1 `index.html` — Landing

**Objetivo:** que un hospital solicite personal y que un enfermero se registre. Dos llamados a la acción claros, sin ambigüedad.

Secciones en orden:
1. **Header fijo** — logo, nav (Servicios, Enfermeros, Nosotros, Contacto), botón secundario "Soy enfermero/a", botón primario "Solicitar personal". Menú hamburguesa en móvil.
2. **Hero** — degradado azul, título `Personal de enfermería verificado, cuando lo necesitas`, subtítulo con la promesa (cobertura en menos de 24 h en la ZMG), dos botones, y una tarjeta flotante a la derecha con un mini-buscador (nivel + municipio + fecha) que lleva a `enfermeros.html` con filtros aplicados.
3. **Barra de confianza** — 4 métricas en línea: enfermeros verificados, turnos cubiertos, calificación promedio, tiempo promedio de respuesta. Contadores animados.
4. **Cómo funciona** — 3 pasos con icono para cliente y toggle para ver los 3 pasos del enfermero.
5. **Servicios** — 4 tarjetas: cuidado domiciliario, turnos hospitalarios, colocación permanente, cobertura de eventos.
6. **Personal destacado** — carrusel con 6 tarjetas de `enfermeros_publico` ordenadas por calificación.
7. **Verificación** — sección que explica el proceso de validación de documentos y cédula. Es el argumento de venta más fuerte; dedicarle diseño.
8. **Especialidades** — grid de chips clicables que filtran el catálogo.
9. **Testimonios** — 3 tarjetas con evaluaciones públicas reales de la BD.
10. **CTA doble** — bloque dividido: izquierda azul "¿Necesitas personal?", derecha blanca "¿Eres enfermero/a?".
11. **FAQ** — acordeón con 8 preguntas.
12. **Footer** — logo, contacto, WhatsApp, redes, aviso de privacidad, términos, aviso legal de la agencia.

Todas las secciones aparecen con fade-in al hacer scroll. La página registra la visita en `visitas` con sus UTM.

### 8.2 `enfermeros.html` — Catálogo

- Barra de filtros lateral (colapsable en móvil como bottom-sheet): nivel, especialidades (multi), municipio, disponibilidad inmediata, años de experiencia (rango), calificación mínima, acepta nocturno/domicilio.
- Buscador por texto (nombre, especialidad, certificación).
- Orden: relevancia, mejor calificados, más experiencia, disponibles primero.
- Grid responsivo: 1 columna (móvil) / 2 (tablet) / 3-4 (desktop).
- Paginación de 12 en 12 con "Cargar más".
- Los filtros se reflejan en la URL (`?nivel=especialista&esp=uci`) para que sean compartibles.
- Estado vacío diseñado con CTA "Déjanos tu solicitud y lo buscamos por ti".

### 8.3 `perfil.html?id=` — Perfil público

- Encabezado con foto grande, nombre, badge de verificación, nivel, calificación, años de experiencia.
- Pestañas: Perfil / Experiencia y certificaciones / Evaluaciones.
- Panel lateral fijo (sticky en desktop) con "Disponibilidad esta semana" (lectura de `disponibilidad`) y botón grande **"Solicitar a este profesional"** que abre `solicitar.html` con el enfermero preseleccionado.
- **Nunca** se muestran datos de contacto directo.

### 8.4 `solicitar.html` — Formulario de solicitud

Formulario multipaso (4 pasos, barra de progreso):
1. Tipo de servicio y nivel requerido.
2. Detalles del paciente/puesto: tipo de paciente, nivel de atención requerido, procedimientos necesarios, especialidades, fechas, turnos y días. **Estas variables son la entrada de la cotización (ver 15.5), así que van en campos estructurados, no solo en texto libre.**
3. Ubicación (municipio, colonia, dirección).
4. Datos de contacto + aceptación de aviso de privacidad.

Al enviar: inserta en `solicitudes` (o en `leads` si no hay sesión), muestra pantalla de confirmación con folio, y dispara notificación al admin. Si trae `?ref=REF-XXXXXX` en la URL, guarda el código.

### 8.5 `unete.html` — Alta de enfermero

Formulario multipaso (5 pasos):
1. Datos personales y contacto.
2. Formación: nivel, institución, cédula, año de egreso.
3. Experiencia: años, especialidades, certificaciones, idiomas.
4. Disponibilidad: zonas, turnos aceptados, disponibilidad inmediata.
5. Documentos: carga de INE, cédula, título, comprobante de domicilio (los demás se piden después).

Al enviar: crea `usuarios` (rol enfermero) + `enfermeros` con `estatus_verificacion = 'pendiente'` y `publicado = false`. Pantalla final: "Recibimos tu solicitud. Nuestro equipo verificará tus documentos en 24-48 h."

### 8.6 Panel Admin (`/admin`)

**Dashboard (`index.html`)**
- 6 tarjetas KPI: solicitudes nuevas hoy, turnos por cubrir, turnos en curso, enfermeros disponibles hoy, ingresos del mes, comisión del mes.
- Alertas en rojo/ámbar: documentos vencidos o por vencer, solicitudes sin cubrir >24 h, enfermeros con verificación pendiente.
- Gráfica de barras (Canvas nativo, sin librerías) de turnos por semana.
- Tabla de últimas 10 solicitudes con acción rápida.

**Enfermeros** — tabla con búsqueda, filtros, estatus de verificación, toggle de `publicado`, acciones: ver, editar, verificar, suspender. Modal de edición completo. Vista de detalle con pestañas: perfil, documentos, asignaciones, evaluaciones, pagos, notas internas.

**Documentos** — bandeja de verificación: lista de documentos pendientes, visor del archivo (URL firmada), botones Aprobar / Rechazar con motivo. Al aprobar todos los obligatorios, sugiere marcar el perfil como verificado.

**Solicitudes** — tablero tipo kanban por estatus, arrastrable. Al abrir una solicitud, el sistema sugiere enfermeros compatibles (match por nivel + especialidad + zona + disponibilidad en la fecha), ordenados por calificación. Botón "Proponer" crea la asignación en estatus `propuesta`.

**Asignaciones** — tabla filtrable por fecha y estatus, con cambio rápido de estatus, registro de check-in/check-out y captura de incidencias.

**Calendario** — vista mensual con todos los turnos; color por estatus. Clic en día muestra el detalle.

**Pagos** — dos pestañas: cobros a clientes (por solicitud/periodo) y pagos a enfermeros (corte quincenal, con total calculado desde `asignaciones` completadas). Exportación CSV.

**Reportes** — selector de periodo, KPIs, tabla de ingresos/comisiones, ranking de enfermeros, tasa de cobertura, exportación CSV.

**Configuración** — tarifas de referencia por nivel y tipo de turno (base de cotización, no tabulador cerrado), porcentaje de reparto por defecto (60/40), catálogos de especialidades, municipios, niveles de atención y procedimientos, datos de la agencia, plantillas de mensajes.

### 8.7 Panel Enfermero (`/panel`)

- **Inicio:** próximos turnos, ganancias del mes, calificación, alertas de documentos por vencer, porcentaje de perfil completo.
- **Perfil:** edición de todo salvo verificación y publicación.
- **Documentos:** subir, ver estatus con color, renovar los vencidos.
- **Disponibilidad:** calendario mensual, clic para marcar/desmarcar turnos disponibles, plantilla semanal repetible.
- **Asignaciones:** ofertas pendientes con botones Aceptar / Rechazar (con motivo), turnos aceptados, botón de check-in/check-out.
- **Historial y Ganancias:** listado y agregado por quincena, con estatus de pago.

### 8.8 Panel Cliente (`/cliente`)

- **Inicio:** servicios activos, próximo turno, personal asignado.
- **Nueva solicitud:** el mismo formulario, precargado con sus datos.
- **Solicitudes:** seguimiento con línea de tiempo del estatus.
- **Personal:** quién está o estuvo asignado, con opción de "solicitar de nuevo a esta persona".
- **Evaluar:** formulario de 4 criterios + comentario, disponible solo sobre asignaciones completadas.
- **Facturación:** historial de pagos y descarga de comprobantes.

---

## 9. Fases de desarrollo

> **No avanzar de fase sin validación explícita del usuario.**

### Fase 0 — Cimientos (día 1-2)
- Repositorio, estructura de carpetas, `config.js`, `variables.css`, `base.css`, `componentes.css`.
- Proyecto en Supabase creado; ejecutar `01-schema.sql`, `02-rls.sql`, `03-funciones.sql`.
- Header y footer compartidos funcionando.
- **Entregable validable:** una página en blanco con header, footer y la paleta aplicada.

### Fase 1 — Público (día 3-7)
- `index.html` completa, `enfermeros.html` con filtros reales contra la vista, `perfil.html`, `servicios.html`, `nosotros.html`, `contacto.html`, `aviso-privacidad.html`, `terminos.html`.
- `solicitar.html` y `unete.html` escribiendo en la BD.
- Seed con 12 enfermeros ficticios para poblar el catálogo.
- **Entregable:** sitio público navegable y capturando solicitudes.

### Fase 2 — Autenticación y Panel Admin (día 8-14)
- `login.html`, `registro.html`, `recuperar.html`, guardia de rutas por rol.
- Todo `/admin` funcional, incluida la bandeja de documentos y el motor de sugerencia de match.
- **Entregable:** la agencia puede operar 100% desde el panel.

### Fase 3 — Paneles de enfermero y cliente (día 15-21)
- `/panel` y `/cliente` completos, incluyendo disponibilidad, aceptación de asignaciones y evaluaciones.
- **Entregable:** ciclo completo solicitud → propuesta → aceptación → servicio → evaluación → pago.

### Fase 4 — Automatización e IA
**No iniciar hasta que las fases 1-3 estén validadas en producción con clientes reales.**
- Escenarios de Make.com: aviso por WhatsApp al enfermero cuando recibe una propuesta; recordatorio 12 h y 1 h antes del turno a ambas partes; aviso al admin de solicitud nueva; alerta semanal de documentos por vencer; solicitud de evaluación al cliente al día siguiente de completado el servicio.
- Programa de referidos operativo con deep links de WhatsApp.
- **Agente conversacional (Claude API):** atiende WhatsApp, califica al prospecto (¿busca personal o empleo?), captura los datos de la solicitud en lenguaje natural, consulta disponibilidad y escala a humano cuando detecta urgencia clínica o negociación de precio. Tono: profesional, cálido, claro. **Nunca da consejo médico ni clínico bajo ninguna circunstancia** — ante cualquier pregunta de salud, responde que la agencia coloca personal y sugiere contactar a un médico o al 911 si es urgencia.

---

## 10. Reglas de negocio

1. Un enfermero solo aparece en el catálogo público si `estatus_verificacion = 'verificado'` **y** `publicado = true`.
2. Documentos obligatorios para verificar: INE, CURP, comprobante de domicilio, y según el nivel: cédula profesional + título (general, licenciado, especialista) o constancia de estudios (auxiliar, técnico, cuidador).
3. Un documento vencido cambia automáticamente el estatus a `vencido` y despublica el perfil hasta su renovación.
4. Un enfermero no puede tener dos asignaciones traslapadas; el sistema lo impide a nivel de base de datos.
5. La comisión de la agencia nunca puede ser negativa: `tarifa_cliente >= tarifa_enfermero`. Validar en formulario y en trigger.
5b. El reparto por defecto de cada asignación es **60% enfermero / 40% agencia**. El admin puede ajustarlo caso por caso, pero el sistema lo propone así.
6. Solo el admin cambia `estatus_verificacion`, `publicado`, `tarifa_cliente` y `comision_agencia`.
7. La evaluación solo se habilita sobre asignaciones en estatus `completada` y expira a los 15 días.
8. Los datos de contacto del enfermero jamás se muestran al cliente, ni siquiera al confirmar el servicio; la coordinación pasa por la agencia (o por un canal controlado en Fase 4).
9. Las cancelaciones con menos de 12 h de anticipación se registran con motivo y afectan un indicador interno de confiabilidad.
10. Toda solicitud recibe un folio visible desde el primer contacto.

---

## 11. Cumplimiento legal (México)

- **Aviso de privacidad** conforme a la LFPDPPP, publicado y aceptado explícitamente en cada formulario (checkbox no premarcado). Debe cubrir datos personales sensibles (salud del paciente, documentos de identidad).
- **Cédula profesional:** verificar contra el Registro Nacional de Profesionistas (SEP). En Fase 1 se captura y se valida manualmente por el admin; en Fase 4 puede automatizarse la consulta.
- La plataforma **no presta servicios médicos**. Es una agencia de colocación de personal. Los textos del sitio deben ser explícitos en esto y evitar cualquier promesa de resultado clínico.
- Incluir aviso de que el personal actúa bajo indicación médica y dentro del alcance de su nivel de práctica.
- Definir con el usuario si la relación con el enfermero es de prestación de servicios profesionales o laboral — impacta contratos, IMSS y facturación. **Pendiente de decisión, no asumir.**
- Facturación CFDI 4.0 si el cliente lo requiere.
- Retención de documentos: acceso restringido, bucket privado, bitácora de accesos en `actividad`.

---

## 12. Variables de entorno / configuración

`js/config.js`:
```javascript
const CONFIG = {
  SUPABASE_URL: 'https://TU-PROYECTO.supabase.co',
  SUPABASE_ANON_KEY: 'TU_ANON_KEY',       // NUNCA la service_role
  WHATSAPP_AGENCIA: '52331XXXXXXX',
  EMAIL_AGENCIA: 'contacto@enlaceenfermero.mx',
  NOMBRE_AGENCIA: 'Enlace Enfermero',
  CIUDAD_BASE: 'Guadalajara, Jalisco',
  COMISION_AGENCIA: 0.40,      // 40% agencia / 60% enfermero
  ITEMS_POR_PAGINA: 12,
  ESPECIALIDADES: [ /* ver 5.3 */ ],
  MUNICIPIOS: [ /* ver 5.3 */ ],
  CERTIFICACIONES: [ /* ver 5.3 */ ]
};
```

---

## 13. Despliegue

1. Repositorio `enlace-enfermero` en GitHub.
2. Settings → Pages → Source: `main` / raíz.
3. Dominio: `enlaceenfermero.mx` (verificar disponibilidad) → registro CNAME + archivo `CNAME` en la raíz.
4. En Supabase → Authentication → URL Configuration: agregar el dominio de Pages y el dominio propio a *Site URL* y *Redirect URLs*.
5. Como GitHub Pages no soporta reescrituras, cada ruta es un archivo `.html` real. `404.html` personalizada.

---

## 14. Checklist de calidad por entrega

Antes de dar por terminada cualquier tarea, verificar:

- [ ] Se ve correcto a 375px, 768px y 1440px.
- [ ] Sin errores en la consola.
- [ ] Estados de carga (skeleton o spinner) y estados vacíos diseñados.
- [ ] Errores de red manejados con `try/catch` y toast visible al usuario.
- [ ] Formularios con validación en cliente y mensajes claros en español.
- [ ] Contraste AA y navegación por teclado.
- [ ] Ningún dato sensible expuesto en la respuesta de Supabase (revisar la consulta, no solo la UI).
- [ ] RLS probado con un usuario de cada rol.
- [ ] Sin `console.log` de depuración en el código final.

---

## 15. Decisiones de negocio

### Resueltas

**1. Relación con el enfermero: freelance.**
El enfermero es **prestador de servicios profesionales independiente**, no empleado
de la agencia. No hay relación laboral, no se genera IMSS ni prestaciones por parte
de la agencia. Cada colocación es una prestación de servicios independiente.

**2. Modelo de cobro y reparto: 60/40.**
El cliente contrata con la agencia y le paga **a la agencia**. La agencia paga al
enfermero. El ingreso de cada servicio se reparte:

| Parte | Porcentaje |
|---|---|
| Enfermero | **60%** |
| Agencia | **40%** |

En la base de datos: `tarifa_cliente` es el total facturado, `tarifa_enfermero` es
el 60% y `comision_agencia` (columna generada) queda en el 40% restante.

**3. Origen de la solicitud: los dos caminos son válidos.**
El cliente puede llegar de dos formas, y el sistema debe soportar ambas:

- **Elige perfiles.** Ya vio el catálogo y quiere a **uno o varios** profesionales
  en específico. La agencia confirma disponibilidad y arma la propuesta.
- **Describe lo que necesita.** Da las características del servicio y la agencia le
  envía los perfiles que se ajustan a lo pedido.

En ambos casos **el contrato es con la agencia**, nunca directo con el enfermero.

**4. Cuota de inscripción al enfermero: no se cobra.**
El registro y la verificación son gratuitos. El ingreso viene del cliente.

**5. Tarifas: cotización caso por caso, sin tabulador fijo.**
No existe una lista de precios publicada ni un tabulador cerrado por nivel. La
agencia cotiza cada servicio cuando el cliente expone su necesidad, considerando:

- Tipo de paciente y su condición
- Entorno del servicio: clínica, hospital, asilo o domicilio particular
- Nivel de atención requerido: desde sola observación hasta cuidados especializados
- Procedimientos concretos que deberá realizar el profesional
- Turnos, duración, zona y urgencia
- El o los profesionales que el cliente requiera

**Consecuencia de diseño:** la solicitud debe capturar estas variables de forma
estructurada, no solo en un texto libre, porque son la entrada del proceso de
cotización. `tarifa_ofrecida_cliente` la escribe el admin al cotizar, nunca el
cliente al solicitar.

Las columnas `tarifa_*` de la tabla `enfermeros` son **tarifas de referencia**
del profesional, punto de partida interno para cotizar. No son un precio fijo ni
se exponen al público.

### Pendientes

1. **¿Cuándo cobra la agencia al cliente?** ¿Anticipo, contra entrega o corte quincenal?
   Necesario para el módulo de pagos del panel admin (Fase 2).
2. **Comprobación fiscal del pago al enfermero.** Al ser freelance, cada pago requiere
   respaldo: factura del enfermero, o retención de la agencia bajo el régimen que
   corresponda. Impacta el módulo de pagos y debe definirse con un contador.
3. **¿Dominio definitivo y correo corporativo?**
4. **Datos legales de la agencia** (razón social, domicilio fiscal, RFC) para el aviso
   de privacidad y los términos y condiciones.
