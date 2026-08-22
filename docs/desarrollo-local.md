# Desarrollo local con Supabase

El proyecto corre contra una copia completa de Supabase en tu máquina: la misma
base de datos, autenticación, almacenamiento y panel de administración que la
nube, sin costo ni límites.

---

## Arrancar

Dos comandos, en este orden:

```bash
colima start
```

```bash
supabase start
```

El primero levanta el motor de contenedores; el segundo, Supabase. La primera
vez tarda unos minutos porque descarga las imágenes; después son segundos.

Luego el sitio:

```bash
python3 servidor.py
```

Y listo: `http://localhost:8000`.

## Detener

```bash
supabase stop
```

```bash
colima stop
```

Conviene detenerlos cuando no estés trabajando: consumen unos 4 GB de RAM.
Los datos se conservan entre reinicios.

---

## Direcciones útiles

| Qué | Dónde |
|---|---|
| El sitio | http://localhost:8000 |
| Studio (ver y editar la base) | http://127.0.0.1:54323 |
| API de Supabase | http://127.0.0.1:54321 |
| Base de datos | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| Correos de prueba | http://127.0.0.1:54324 |

**Studio** es el equivalente local del panel de supabase.com: puedes navegar las
tablas, correr consultas y revisar las políticas de seguridad.

**Correos de prueba**: en local no se envía correo de verdad. Todo lo que el
sistema mande (confirmaciones, recuperación de contraseña) aparece ahí.

---

## Reinstalar la base

Cuando cambies algo en `sql/`:

```bash
bash sql/generar-instalador.sh
```

```bash
bash aplicar-esquema.sh
```

El primero regenera `sql/00-instalar.sql` a partir de los scripts sueltos. El
segundo borra la base, la vuelve a construir y actualiza la llave en
`js/config.js`. Puedes correrlo las veces que quieras.

## Verificar que todo está bien

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f sql/99-pruebas.sql
```

Son 26 comprobaciones: folios, reparto 60/40, turnos encimados, y sobre todo
los permisos del sitio público. Todas deben decir `OK`. No deja datos.

---

## Cómo sabe el sitio a qué base conectarse

`js/config.js` distingue el entorno solo:

```javascript
const ES_LOCAL = ['localhost', '127.0.0.1', ''].includes(window.location.hostname);
```

En `localhost` usa la base local; publicado, usa la de producción. **No hay que
editar nada al publicar**, y no existe el riesgo de subir el sitio apuntando a
una base que solo existe en tu máquina.

Las llaves locales que ves en el archivo son claves de desarrollo de Supabase,
públicas y conocidas. No protegen nada y pueden vivir en el repositorio.

---

## Pasar a producción

Cuando contrates el plan Pro y crees el proyecto:

1. **SQL Editor → New query**: pega `sql/00-instalar.sql` completo y ejecuta.
   Es el mismo archivo que usas en local, incluye los tres buckets de Storage.
2. Pega `sql/99-pruebas.sql` y confirma que todo diga `OK`.
3. En `js/config.js`, sustituye los dos valores de la rama de producción:

   ```javascript
   : 'https://xxxxxxxx.supabase.co',   // Project URL
   : 'eyJhbGci...',                     // llave anon public
   ```

4. **Authentication → URL Configuration**: agrega la URL donde publiques el sitio.
5. Si no quieres los 12 perfiles de prueba en producción, ejecuta por separado
   `01`, `02`, `03` y `04`, y omite `05-seed.sql`.

Nada más. Los scripts son idénticos en los dos lados.

---

## Si algo falla

**`Cannot connect to the Docker daemon`** — Colima no está corriendo:
`colima start`.

**`supabase start` se queda colgado** — puertos ocupados por una sesión previa:
`supabase stop --no-backup` y vuelve a arrancar.

**El sitio muestra el aviso de "datos de demostración"** — no está encontrando la
base. Revisa que `supabase status` responda y abre la consola del navegador
(F12) y escribe `diagnostico()`.

**Se acabó el espacio en disco** — las imágenes ocupan unos 3 GB:
`docker system prune -a` libera lo que no se usa.
