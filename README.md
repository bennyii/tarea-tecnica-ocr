# Lector de Boletas Chilenas OCR con IA

Aplicación web desarrollada en **Ruby on Rails 8** que permite subir boletas de compra chilenas (PDF o imágenes), extraer automáticamente la información clave mediante Inteligencia Artificial (**Gemini API**) y estructurar los datos para su revisión y almacenamiento en **PostgreSQL**.

🔗 **Demo en producción:** https://tarea-tecnica-ocr.onrender.com/

---

## Tabla de contenido

- [Flujo de uso](#-flujo-de-uso)
- [Arquitectura y cómo se resolvió el problema](#-arquitectura-y-cómo-se-resolvió-el-problema)
- [Manejo de errores y casos límite](#manejo-de-errores-y-casos-límite)
- [Prompts utilizados con IA](#-prompts-utilizados-con-ia)
- [Requisitos previos](#-requisitos-previos)
- [Variables de entorno](#-variables-de-entorno)
- [Instalación y ejecución local](#-instalación-y-ejecución-local)
- [Despliegue en Render](#-despliegue-en-render-capa-gratuita)
- [Qué mejoraría con más tiempo](#-qué-mejoraría-con-más-tiempo)
- [Stack técnico](#-stack-técnico)
- [Documentación adicional](#documentación-adicional)


---

##  Flujo de uso

1. El usuario entra a la app y sube una boleta (PDF, JPG o PNG).
2. La app la guarda en Cloudflare R2 y encola un job en segundo plano.
3. Gemini procesa la imagen/PDF y extrae los campos clave.
4. El usuario es redirigido automáticamente a un formulario **precargado** con los datos detectados, junto a una vista previa del documento original.
5. El usuario revisa, corrige si hace falta, y guarda.
6. Puede consultar todas las boletas guardadas desde el listado principal (`/receipts`).

---

##  Arquitectura y cómo se resolvió el problema

Se implementó la siguiente arquitectura usando las herramientas nativas de Rails 8 (Solid Stack):

1. **Almacenamiento (Cloudflare R2):** las boletas se gestionan mediante `ActiveStorage` y se guardan en un bucket de Cloudflare R2.
2. **Procesamiento asíncrono (Solid Queue):** para no bloquear la interfaz mientras la IA procesa el documento, la extracción se encola como un job en segundo plano (`ActiveJob` + `Solid Queue`), usando la misma base de datos PostgreSQL.
3. **Extracción multimodal (Gemini API):** en vez de usar un OCR tradicional y luego un LLM por separado, se usa **Gemini 3.5 Flash-Lite** por sus capacidades multimodales: se le envía la imagen/PDF directamente y se le pide que haga el OCR y estructure la salida en JSON en un solo paso.
4. **Flujo de usuario (polling):** el cliente consulta periódicamente el estado del job (`GET /receipts/:id/status`) y, al completarse, redirige al formulario de edición precargado para validación manual antes de guardar en PostgreSQL.

### Manejo de errores y casos límite

- Si Gemini detecta que el archivo **no es una boleta** (foto de una persona, paisaje, etc.), devuelve todos los campos en `null` y el receipt se marca como `failed`, permitiendo reintentar o completar manualmente.
- Si el archivo subido ya existe (mismo checksum), la app redirige al registro existente en vez de duplicarlo.
- Ante errores transitorios de Gemini (HTTP 429/503), el job reintenta automáticamente con backoff exponencial (hasta 5 intentos).
- Si el polling supera los 60 segundos sin respuesta, se ofrece un botón para continuar manualmente sin quedar bloqueado.

---

##  Prompts utilizados con IA

Se usó un enfoque de *zero-shot prompting* solicitando una salida JSON estricta y validable.

**Prompt de sistema (`system_instruction`) enviado a Gemini:**

> "Eres un asistente que extrae datos estructurados de boletas de compra chilenas a partir de una imagen o documento adjunto.
> Devuelve EXCLUSIVAMENTE un objeto JSON válido, sin texto adicional, sin explicaciones, sin markdown ni backticks, con esta estructura exacta:
>
> ```json
> {
>   "merchant_name": string | null,
>   "rut_emisor": string | null,
>   "purchase_date": string | null,
>   "document_number": string | null,
>   "document_type": string | null,
>   "net_amount": number | null,
>   "tax_amount": number | null,
>   "total_amount": number | null
> }
> ```
>
> Reglas:
> - Si un campo no se puede determinar con confianza, usa null (no inventes datos).
> - Los montos deben ser números sin puntos de miles ni símbolo $.
> - El RUT debe incluir el guion y dígito verificador si están presentes.
> - purchase_date siempre en formato ISO YYYY-MM-DD.
> - Si la imagen proporcionada CLARAMENTE NO es una boleta, factura o comprobante de compra, debes devolver absolutamente todos los valores como `null`."

**Mensaje de usuario adjunto:** "Analiza este comprobante y extrae los datos solicitados." + el archivo en `inline_data` (base64).

**Configuración de generación:** `temperature: 0.0` (respuestas determinísticas) y `response_mime_type: "application/json"` para forzar salida JSON válida directamente desde la API.

---

##  Requisitos previos

- Ruby 3.4.x (ver `.ruby-version`)
- PostgreSQL 15+
- Cuenta en [Google AI Studio](https://aistudio.google.com/) para obtener una `GEMINI_API_KEY`
- Cuenta en Cloudflare R2 (o AWS S3) para almacenamiento de archivos

---

##  Variables de entorno

Crea un archivo `.env` en la raíz del proyecto

```dotenv
# IA
GEMINI_API_KEY=tu_api_key_de_gemini
GEMINI_MODEL=gemini-3.5-flash-lite

# Base de datos (local)
DATABASE_URL="postgres://postgres:postgres@localhost:5432/tarea_tecnica_ocr_development"

# Cloudflare R2 (solo necesario si quieres probar almacenamiento en la nube en local;
# en desarrollo por defecto se usa disco local, ver config/storage.yml)
R2_ACCOUNT_ID=tu_account_id
R2_ACCESS_KEY_ID=tu_access_key
R2_SECRET_ACCESS_KEY=tu_secret_key
R2_BUCKET=tu_bucket
```

##   Instalación y ejecución local

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/bennyii/tarea-tecnica-ocr.git
   cd tarea-tecnica-ocr
   ```

2. **Instalar dependencias:**
   ```bash
   bundle install
   ```

3. **Configurar variables de entorno:** copia el bloque de la sección anterior en un archivo `.env` en la raíz (usa `dotenv-rails`, ya incluido en el Gemfile para desarrollo/test).

4. **Crear y preparar las bases de datos** (incluye las tablas de Solid Queue, Solid Cache y Solid Cable):
   ```bash
   bin/rails db:prepare
   ```

5. **Iniciar el servidor y el worker de jobs:**
   ```bash
   bin/dev
   ```
   Esto levanta Puma y, dentro del mismo proceso, el supervisor de Solid Queue (ver `config/puma.rb`, plugin `:solid_queue`). Si prefieres correrlos por separado:
   ```bash
   bin/rails server
   bin/jobs
   ```

6. **Abrir la app:** [http://localhost:3000](http://localhost:3000)



---

##  Despliegue en Render (capa gratuita)

La app está desplegada en Render usando una única base de datos PostgreSQL (plan free) y Cloudflare R2 para el storage. Este proceso implicó resolver tres problemas concretos, documentados.

### 1. Cloudflare R2 rechazaba las subidas

**Problema:** el SDK de AWS (que Rails usa por debajo para `ActiveStorage` con servicios S3-compatible) exige por defecto un cálculo estricto de checksums (CRC32) que R2 no procesa de la misma forma que S3, causando que las subidas fallaran con error.

**Solución:** en `config/storage.yml`, dentro del servicio `cloudflare`, se agregó:
```yaml
request_checksum_calculation: when_required
response_checksum_validation: when_required
```

### 2. Solid Queue no encontraba sus tablas (`solid_queue_jobs`)

**Problema:** Rails 8 con Solid Queue necesita que se ejecute `bin/rails db:prepare` (no solo `db:migrate`) para crear las tablas de las bases de datos lógicas adicionales (`queue`, `cache`, `cable`) definidas en `config/database.yml`. Al desplegar en Render usando el entorno Ruby nativo (sin Dockerfile), ese paso no se ejecutaba automáticamente durante el deploy, así que la tabla `solid_queue_jobs` nunca se creaba y el encolado de jobs fallaba.

**Solución recomendada:** en el dashboard de Render, agregar en **Settings → Pre-Deploy Command** (o al final del Build Command):
```bash
bin/rails db:prepare
```
Esto crea/migra automáticamente las 4 bases lógicas en cada deploy, de forma reproducible y sin intervención manual.

### 3. Out of Memory (OOM) por Puma en modo cluster

**Problema:** el plan free de Render da solo 512 MB de RAM. Puma arrancaba con 2 workers en modo cluster, lo que significaba dos copias completas de Rails y de Solid Queue corriendo al mismo tiempo (>600 MB), provocando reinicios constantes del servicio.

**Solución:** en `config/puma.rb` se fuerza el modo de proceso único:
```ruby
workers 0
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"] || Rails.env.production?
```
Con esto el consumo bajó a ~200 MB y el servicio dejó de caerse.

### Variables de entorno necesarias en Render

| Variable | Descripción |
|---|---|
| `RAILS_MASTER_KEY` | Contenido de `config/master.key` (no versionado) |
| `DATABASE_URL` | Provista automáticamente por Render al conectar la base de datos |
| `GEMINI_API_KEY` | API key de Google AI Studio |
| `GEMINI_MODEL` | `gemini-3.5-flash-lite` |
| `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` | Credenciales del bucket de Cloudflare R2 |
| `SOLID_QUEUE_IN_PUMA` | `true` (corre el worker dentro del mismo proceso de Puma) |

---

##  Qué mejoraría con más tiempo

- **Validación de RUT chileno:** agregar validación del dígito verificador del RUT emisor extraído por la IA, en vez de solo verificar formato.

- **Manejo de PDFs multipágina:** boletas con múltiples páginas (ej. facturas con detalle de ítems) podrían necesitar lógica adicional para indicarle a Gemini en qué página buscar los totales.

- **Agregados con SQL en vez de Ruby:** los totales del listado de boletas guardadas se calculan iterando el array ya cargado; para un volumen mayor convendría usar `sum(:total_amount)` a nivel de base de datos en vez de en memoria.

- **Job de limpieza automática:** purgar boletas abandonadas (subidas pero nunca guardadas ni descartadas) tras un tiempo razonable, para no acumular registros huérfanos indefinidamente — hoy el usuario puede verlas y eliminarlas manualmente desde "Boletas pendientes", pero no hay limpieza automática.

- **Autenticación e identificación de usuarios:** actualmente todas las boletas se guardan en una única tabla `receipts` sin ningún tipo de dueño asociado, por lo que cualquier persona que entre a la app ve y puede editar las boletas de todos los demás. Con más tiempo agregaría autenticación (por ejemplo con `Devise` o `Rails 8 Authentication generator`), una asociación `belongs_to :user` en el modelo `Receipt`, y filtrado en `ReceiptsController` (`index`, `pending`, `show`, `edit`, `update`, `destroy`) para que cada usuario solo vea y gestione sus propias boletas.

##  Stack técnico

- Ruby on Rails 8.1
- PostgreSQL (Solid Queue, Solid Cache, Solid Cable)
- Cloudflare R2 (ActiveStorage, compatible S3)
- Gemini API (`gemini-3.5-flash-lite`, multimodal)
- Faraday (cliente HTTP)
- Turbo + Stimulus + Importmap

---

## Documentación adicional

- [Resumen ejecutivo del proyecto](docs/PROJECT_OVERVIEW.md)
- [Aplicación principal](app/)
- [Configuración del entorno](config/)
- [Modelos y lógica de negocio](app/models/)
- [Jobs y procesamiento asíncrono](app/jobs/)
