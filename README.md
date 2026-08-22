# Enlace Enfermero

Plataforma web de la agencia de reclutamiento y colocación de personal de
enfermería en la Zona Metropolitana de Guadalajara, Jalisco.

La especificación completa del producto vive en [`CLAUDE.md`](CLAUDE.md).
Ese documento manda sobre cualquier decisión técnica.

## Stack

HTML5 + CSS3 + JavaScript ES6 vanilla. Sin frameworks, sin bundlers, sin npm.
Única dependencia externa: el cliente JS de Supabase por CDN.

| Capa | Tecnología |
|---|---|
| Frontend | HTML, CSS con variables nativas, JS vanilla |
| Backend | Supabase (PostgreSQL + Auth + Storage + RLS) |
| Hosting | GitHub Pages |

## Correr en local

Tres comandos:

```bash
colima start
```

```bash
supabase start
```

```bash
python3 servidor.py
```

Luego abrir `http://localhost:8000`. Los dos primeros levantan una copia
completa de Supabase en tu máquina (base de datos, autenticación y almacenamiento);
el tercero sirve el sitio sin caché para que los cambios en CSS y JS se vean al
recargar.

Para detener: `supabase stop` y `colima stop`.

El paso a paso está en [`docs/desarrollo-local.md`](docs/desarrollo-local.md).

## Estructura

```
├── index.html              Landing pública
├── enfermeros.html         Catálogo con filtros
├── perfil.html             Perfil individual (?id=)
├── solicitar.html          Solicitud de personal (4 pasos)
├── unete.html              Registro de enfermeros (5 pasos)
├── servicios.html          Detalle de los 4 servicios
├── nosotros.html           Quiénes somos
├── contacto.html           Contacto y preguntas frecuentes
├── aviso-privacidad.html   LFPDPPP — pendiente de revisión legal
├── terminos.html           Términos — pendiente de revisión legal
├── 404.html
├── login.html              Acceso unificado
├── registro.html           Alta de clientes
├── recuperar.html          Recuperación de contraseña
├── admin/                  Panel de la agencia (11 pantallas)
├── panel/                  Panel del enfermero          (Fase 3)
├── cliente/                Panel del cliente            (Fase 3)
├── css/
│   ├── variables.css       Tokens de diseño
│   ├── base.css            Reset, tipografía, utilidades
│   ├── componentes.css     Botones, tarjetas, formularios, tablas, modales
│   ├── layout.css          Header, footer, contenedores
│   ├── publico.css         Páginas públicas
│   ├── panel.css           Paneles privados             (Fase 2)
│   └── responsive.css      Media queries centralizadas
├── js/
│   ├── config.js           Credenciales y catálogos de negocio
│   ├── supabase.js         Cliente y manejo de errores
│   ├── utils.js            Formato, validaciones, toasts
│   ├── componentes.js      Header, footer y piezas de UI
│   ├── publico.js          Catálogo, perfil y formularios
│   └── datos-demo.js       Respaldo sin Supabase (borrar en producción)
├── sql/                    Base de datos (00-instalar.sql lo trae todo)
├── assets/                 Logo y favicon
├── servidor.py             Servidor local sin caché (solo desarrollo)
├── aplicar-esquema.sh      Reinstala la base local desde sql/
├── supabase/               Configuración del entorno local
└── docs/                   Despliegue y manuales
```

## Configuración

Antes de conectar la base de datos, capturar en `js/config.js`:

```javascript
SUPABASE_URL: 'https://xxxxxxxx.supabase.co',
SUPABASE_ANON_KEY: 'eyJhbGci...',
```

Solo la llave `anon`. La `service_role` nunca se publica en el frontend.

El paso a paso para conectar la base está en [`docs/conectar-supabase.md`](docs/conectar-supabase.md),
y el despliegue a GitHub Pages en [`docs/despliegue.md`](docs/despliegue.md).

## Entornos

`js/config.js` distingue solo dónde está corriendo:

| Dónde | Base de datos |
|---|---|
| `localhost` | Supabase local (Docker) |
| Publicado | Proyecto de Supabase en la nube |

No hay que editar nada al publicar. Las llaves locales del archivo son claves de
desarrollo públicas de Supabase y no protegen nada.

Si no hay ninguna base disponible, el sitio cae en `js/datos-demo.js` —una copia
exacta de `sql/05-seed.sql`— y muestra un aviso ámbar. **Antes de publicar**,
quita la etiqueta `<script>` de ese archivo de las páginas públicas y bórralo.

## Fases

| Fase | Alcance | Estado |
|---|---|---|
| 0 | Cimientos: estructura, tokens, SQL, header y footer | Completada |
| 1 | Sitio público: catálogo, perfiles, formularios | Completada |
| 2 | Autenticación y panel de la agencia | Completada |
| 3 | Paneles de enfermero y de cliente | Pendiente |
| 4 | Automatización, WhatsApp y agente conversacional | Pendiente |
