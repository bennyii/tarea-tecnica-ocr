require "faraday"
require "json"
require "base64"

class GeminiOcrService
  class TransientError < StandardError; end
  GEMINI_BASE_URL = "https://generativelanguage.googleapis.com".freeze

  SYSTEM_PROMPT = <<~PROMPT.strip
    Eres un asistente que extrae datos estructurados de boletas de compra
    chilenas a partir de una imagen o documento adjunto.

    Devuelve EXCLUSIVAMENTE un objeto JSON válido, sin texto adicional,
    sin explicaciones, sin markdown ni backticks, con esta estructura exacta:

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
  PROMPT

  FIELDS = %i[
    merchant_name
    rut_emisor
    purchase_date
    document_number
    document_type
    net_amount
    tax_amount
    total_amount
  ].freeze

  def self.call(receipt, client: nil)
    new(receipt, client: client).call
  end

  def initialize(receipt, client: nil)
    @receipt = receipt
    @client = client || default_connection
    @api_key = ENV.fetch("GEMINI_API_KEY", nil)
    # Usamos un modelo flash moderno y multimodal compatible con imágenes/PDFs
    @model = ENV.fetch("GEMINI_MODEL", "gemini-2.5-flash")
  end

  def call
    return { error: "No hay archivo adjunto en la boleta" } unless @receipt.file.attached?

    response = execute_request
    return handle_api_error(response) unless response.status == 200

    raw_content = extract_candidate_text(response)
    parse_response(raw_content)
  rescue Faraday::Error => e
    { error: "Error de red conectando con Gemini: #{e.message}", raw_response: nil }
  end

  private

  RETRYABLE_STATUSES = [429, 503].freeze

def execute_request
    file_data = @receipt.file.download
    raw_mime_type = @receipt.file.content_type

    # Normalización de MIME types para asegurar compatibilidad estricta con Gemini
    mime_type = case raw_mime_type
                when "image/jpg" then "image/jpeg"
                when "image/png", "image/jpeg", "application/pdf", "image/webp", "image/heic" then raw_mime_type
                else
                  # Fallback basado en la extensión del archivo original si el content_type es dudoso
                  filename = @receipt.file.filename.to_s.downcase
                  if filename.end_with?(".png")
                    "image/png"
                  elif filename.end_with?(".pdf")
                    "application/pdf"
                  else
                    "image/jpeg" # Por defecto asumimos jpeg para imágenes
                  end
                end

    base64_file = Base64.strict_encode64(file_data)

    @client.post("/v1beta/models/#{@model}:generateContent") do |req|
      req.params["key"] = @api_key
      req.headers["Content-Type"] = "application/json"
      req.body = request_payload(base64_file, mime_type).to_json
    end
  end

  def request_payload(base64_file, mime_type)
    {
      system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
      contents: [
        {
          parts: [
            { text: "Analiza este comprobante y extrae los datos solicitados." },
            {
              inline_data: {
                mime_type: mime_type,
                data: base64_file
              }
            }
          ]
        }
      ],
      generationConfig: {
        response_mime_type: "application/json",
        temperature: 0.0
      }
    }
  end

  def extract_candidate_text(response)
    body = response.body.is_a?(Hash) ? response.body : JSON.parse(response.body.to_s)
    body.dig("candidates", 0, "content", "parts", 0, "text")
  end

  def handle_api_error(response)
    if RETRYABLE_STATUSES.include?(response.status)
      raise TransientError, "Gemini no disponible temporalmente (HTTP #{response.status}): #{response.body}"
    end
    {
      error: "Error devuelto por Gemini (HTTP #{response.status}): #{response.body}",
      raw_response: response.body.to_s
    }
  end

  def parse_response(raw_content)
    parsed = JSON.parse(raw_content.to_s)
    build_success_hash(parsed, raw_content)
  rescue JSON::ParserError, TypeError => e
    {
      error: "JSON mal formado recibido de la IA: #{e.message}",
      raw_response: raw_content
    }
  end

  def build_success_hash(parsed, raw_content)
    result = FIELDS.index_with do |field|
      parsed[field.to_s]
    end
    result[:raw_response] = raw_content
    result
  end

  def default_connection
    Faraday.new(url: GEMINI_BASE_URL) do |f|
      f.options.timeout = 30
      f.options.open_timeout = 10
    end
  end
end