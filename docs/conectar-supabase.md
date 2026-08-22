# Conectar Supabase — paso a paso

Guía para dejar el sitio funcionando contra una base de datos real.
Todo esto lo haces tú desde el navegador; toma unos 15 minutos.

---

## 1. Crear el proyecto

1. Entra a [supabase.com](https://supabase.com) y crea una cuenta (o inicia sesión).
2. **New project**. Llénalo así:

   | Campo | Valor |
   |---|---|
   | Name | `enlace-enfermero` |
   | Database Password | Genera una segura y **guárdala en tu gestor de contraseñas** |
   | Region | `East US (North Virginia)` o `West US (Oregon)` |
   | Plan | Free |

3. Espera 2 o 3 minutos a que termine de aprovisionarse.

> La contraseña de la base de datos no se usa en el sitio. Guárdala de todos modos:
> es la única forma de conectarte directo a Postgres si algún día la necesitas.

---

## 2. Ejecutar los scripts

Son dos pegados. **SQL Editor → New query**.

### 2.1 Instalar

Abre `sql/00-instalar.sql`, copia **todo** el archivo, pégalo y presiona **Run**.

Trae el esquema completo, las políticas de seguridad, los permisos, las
funciones, las vistas, **los tres buckets de Storage** y los 12 perfiles de
prueba. No hay que crear nada a mano en el panel. Debe terminar en **Success** (tarda unos segundos).

> Todo va dentro de una transacción: si algo falla, **no se aplica nada**. La base
> queda como estaba y puedes corregir y volver a pegarlo sin limpiar a mano.

### 2.2 Verificar

Nueva consulta. Pega `sql/99-pruebas.sql` y **Run**.

Comprueba 26 cosas: los folios, el reparto 60/40, que un turno encimado se
rechace, que el catálogo público no exponga tarifas ni notas internas, que un
enfermero no pueda autoverificarse ni fijarse tarifa, y que el sitio público
tenga permiso de hacer justo lo que necesita y nada más.

**Cada renglón del resultado debe decir `OK`.** El script hace `rollback` al
final: no deja nada.

### Si prefieres instalar sin datos de prueba

Ejecuta por separado `01-schema.sql`, `02-rls.sql`, `03-funciones.sql` y
`04-vistas.sql` en ese orden, y omite `05-seed.sql`.

---

## 3. Copiar las credenciales

**Settings → API**. Necesitas dos valores:

| Dónde dice | Qué copiar |
|---|---|
| **Project URL** | `https://xxxxxxxxxxxx.supabase.co` |
| **Project API keys → `anon` `public`** | Una cadena larga que empieza con `eyJ...` |

Pégalos en `js/config.js`:

```javascript
SUPABASE_URL: 'https://xxxxxxxxxxxx.supabase.co',
SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
```

### La llave `service_role` nunca

En esa misma pantalla verás una llave `service_role`. **Esa no.** Da acceso total
saltándose todas las políticas de seguridad, y el archivo `config.js` se publica
en GitHub Pages: cualquiera podría leerla y borrar tu base completa.

Solo la que dice `anon` `public`. Esa está diseñada para ir en el frontend y es
inofensiva por sí sola: lo que protege los datos son las políticas de RLS que ya
están instaladas.

---

## 4. Autorizar las URLs del sitio

**Authentication → URL Configuration**. Agrega en *Site URL* y en *Redirect URLs*:

- `http://localhost:8000` — para desarrollo
- `https://TU-USUARIO.github.io/enlace-enfermero` — cuando publiques
- `https://enlaceenfermero.mx` — cuando tengas dominio

Sin esto, el inicio de sesión de la Fase 2 no va a funcionar.

---

## 5. Comprobar que quedó bien

1. Levanta el sitio:

   ```bash
   python3 servidor.py
   ```

2. Abre `http://localhost:8000`. El aviso ámbar de "datos de demostración"
   **debe desaparecer**, y el catálogo debe mostrar lo que hay en tu base.

3. Abre la consola del navegador (`F12` → pestaña *Console*), escribe
   `diagnostico()` y presiona Enter.

El diagnóstico revisa seis cosas y te dice cuál falla:

- Que las credenciales estén capturadas
- Que sea la llave `anon` y no la `service_role`
- Que el cliente se cree
- Que la vista `enfermeros_publico` responda
- **Que la tabla `enfermeros` NO sea legible en público** (tarifas y notas internas)
- Que el formulario público pueda guardar solicitudes

Deja una solicitud llamada `PRUEBA DE DIAGNOSTICO` en la base. Bórrala desde
**Table Editor → solicitudes** cuando termines.

---

## 6. Quitar los datos de demostración

Cuando la base tenga información real, quita el respaldo local:

1. Borra la línea `<script src="js/datos-demo.js"></script>` de las páginas
   `index.html`, `enfermeros.html`, `perfil.html`, `solicitar.html`,
   `unete.html` y `contacto.html`.
2. Borra el archivo `js/datos-demo.js`.

Si lo dejas, no rompe nada: en cuanto hay credenciales, el sitio lee de Supabase
e ignora ese archivo. Pero son 15 KB que nadie necesita descargar.

---

## Problemas frecuentes

**"relation does not exist"** — falta ejecutar los scripts, o se ejecutaron fuera
de orden. Vuelve al paso 3.

**El catálogo sale vacío pero el diagnóstico dice OK** — no hay perfiles
publicados. Un enfermero solo aparece si tiene `publicado = true` **y**
`estatus_verificacion = 'verificado'`. Revisa en *Table Editor → enfermeros*.

**"new row violates row-level security policy"** — se está intentando escribir un
campo reservado al administrador. Es el comportamiento correcto: los formularios
públicos no pueden fijar tarifas, publicar perfiles ni verificarlos.

**El diagnóstico avisa que la tabla `enfermeros` es legible** — `02-rls.sql` no se
ejecutó completo. Vuelve a correrlo entero; es la protección del modelo de negocio.

---

¿Prefieres trabajar sin nube mientras construyes? Ver
[desarrollo local](desarrollo-local.md).
