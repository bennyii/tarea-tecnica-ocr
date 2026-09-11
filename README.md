#  Lector de Boletas Chilenas OCR con IA

Aplicación web desarrollada en Ruby on Rails 8 que permite subir boletas de compra chilenas (PDF o imágenes), extraer automáticamente la información clave mediante Inteligencia Artificial (Gemini API) y estructurar los datos para su revisión y almacenamiento en PostgreSQL.

##  Arquitectura y Cómo se resolvió el problema

Para resolver el desafío de forma eficiente, escalable y moderna, se implementó la siguiente arquitectura utilizando las herramientas nativas de Rails 8 (Solid Stack):

1. **Almacenamiento (Cloudflare R2):** Las boletas subidas por el usuario se gestionan mediante `ActiveStorage` y se almacenan directamente en un bucket de Cloudflare R2 (compatible con S3).
2. **Procesamiento Asíncrono (Solid Queue):** Para evitar bloqueos en la interfaz de usuario mientras la IA procesa el documento, la extracción se encola como un trabajo en segundo plano (`ActiveJob` + `Solid Queue`) utilizando la misma base de datos PostgreSQL.
3. **Extracción Multimodal (Gemini API):** En lugar de usar una herramienta de OCR tradicional y luego un LLM por separado, se utilizó el modelo **Gemini 3.5 Flash-Lite** por sus capacidades multimodales. Se le envía directamente la imagen/PDF y se le pide que realice el OCR y estructure la salida en formato JSON en un solo paso.
4. **Flujo de Usuario (Polling):** El cliente consulta periódicamente el estado del trabajo y, una vez completado, redirige al usuario a un formulario de edición precargado para su validación manual antes de guardarlo en PostgreSQL.

##  Prompts utilizados con IA

Para lograr una extracción precisa y estructurada, se utilizó un enfoque de *Zero-shot prompting* solicitando una salida JSON estricta.

**Ejemplo del prompt principal:**
>"Eres un asistente que extrae datos estructurados de boletas de compra chilenas a partir de una imagen o documento adjunto.

>Devuelve EXCLUSIVAMENTE un objeto JSON válido, sin texto adicional, sin explicaciones, sin markdown ni backticks, con esta estructura exacta:

    {
      "merchant_name": string | null,
      "rut_emisor": string | null,
      "purchase_date": string | null,
      "document_number": string | null,
      "document_type": string | null,
      "net_amount": number | null,
      "tax_amount": number | null,
      "total_amount": number | null
    }

    Reglas:
    - Si un campo no se puede determinar con confianza, usa null (no inventes datos).
    - Los montos deben ser números sin puntos de miles ni símbolo $.
    - El RUT debe incluir el guion y dígito verificador si están presentes.
    - purchase_date siempre en formato ISO YYYY-MM-DD.

##  Requisitos Previos

- Ruby 3.x
- PostgreSQL
- Cuenta en Google AI Studio (Gemini API Key)
- (Opcional para local) Cuenta en Cloudflare R2 o AWS S3 para almacenamiento en la nube.

##  Instalación y Ejecución Local

1. **Clonar el repositorio:**
   git clone [https://github.com/tu-usuario/tu-repo.git](https://github.com/tu-usuario/tu-repo.git)
   cd tu-repo