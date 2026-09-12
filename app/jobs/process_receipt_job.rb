class ProcessReceiptJob < ApplicationJob
  # Procesa el pipeline OCR en segundo plano para mantener la experiencia del usuario receptiva.
  queue_as :default

  # Reintenta problemas de red
  retry_on Faraday::TimeoutError, "GeminiOcrService::TransientError",
           wait: :polynomially_longer, attempts: 5

  def perform(receipt_id)
    receipt = Receipt.find_by(id: receipt_id)
    return unless receipt

    receipt.update!(status: "processing")
    execute_pipeline(receipt)
  rescue GeminiOcrService::TransientError
    raise
  rescue StandardError => e
    handle_failure(receipt, e)
  end

  private

  # Ejecuta el flujo multimodal OCR y persiste el resultado en la base de datos.
  def execute_pipeline(receipt)
    ai_result = GeminiOcrService.call(receipt)

    if ai_result[:error].present?
      receipt.update!(
        ai_raw_response: ai_result[:raw_response],
        status: "failed"
      )
    elsif invalid_receipt?(ai_result)
      receipt.update!(
        ai_raw_response: ai_result[:raw_response],
        status: "failed"
      )
    else
      receipt.update!(receipt_attributes_from_ai(ai_result))
    end
  end

  # Marca el documento como inválido cuando la IA no puede identificar con confianza el comercio o el total.
  def invalid_receipt?(ai_result)
    ai_result[:merchant_name].blank? && ai_result[:total_amount].blank?
  end

  # Mapea la respuesta de la IA a atributos válidos de la boleta antes de guardarla.
  def receipt_attributes_from_ai(ai_result)
    attrs = ai_result.slice(:merchant_name, :rut_emisor, :document_number, :document_type,
                            :net_amount, :tax_amount, :total_amount)
    attrs.merge(
      purchase_date: parse_date(ai_result[:purchase_date]),
      ai_raw_response: ai_result[:raw_response],
      status: "ready_for_review"
    )
  end

  # Convierte fechas ISO del LLM a un objeto Date de Rails cuando es posible.
  def parse_date(date_str)
    return nil if date_str.blank?

    Date.iso8601(date_str.to_s)
  rescue ArgumentError
    nil
  end

  # Registra la falla en logs y deja la boleta en estado fallido para intervención del usuario.
  def handle_failure(receipt, error)
    Rails.logger.error("ProcessReceiptJob failed for Receipt ##{receipt&.id}: #{error.message}")
    receipt&.update(status: "failed")
  end
end
