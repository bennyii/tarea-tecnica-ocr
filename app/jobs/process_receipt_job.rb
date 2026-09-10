class ProcessReceiptJob < ApplicationJob
  queue_as :default

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

  def execute_pipeline(receipt)
   
    ai_result = GeminiOcrService.call(receipt)

    if ai_result[:error].present?
      receipt.update!(
        ai_raw_response: ai_result[:raw_response],
        status: "failed"
      )
    else
      receipt.update!(receipt_attributes_from_ai(ai_result))
    end
  end

  def receipt_attributes_from_ai(ai_result)
    attrs = ai_result.slice(:merchant_name, :rut_emisor, :document_number, :document_type,
                            :net_amount, :tax_amount, :total_amount)
    attrs.merge(
      purchase_date: parse_date(ai_result[:purchase_date]),
      ai_raw_response: ai_result[:raw_response],
      status: "ready_for_review"
    )
  end

  def parse_date(date_str)
    return nil if date_str.blank?

    Date.iso8601(date_str.to_s)
  rescue ArgumentError
    nil
  end

  def handle_failure(receipt, error)
    Rails.logger.error("ProcessReceiptJob failed for Receipt ##{receipt&.id}: #{error.message}")
    receipt&.update(status: "failed")
  end
end