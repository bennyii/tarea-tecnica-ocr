module ReceiptsHelper
  # Formatea montos en pesos chilenos ($ 12.345)
  def format_clp(amount)
    return "—" if amount.blank?

    number_to_currency(amount, unit: "$ ", delimiter: ".", separator: ",", precision: 0)
  end

  # Formato de fecha chilena legible (ej: 10 de Septiembre, 2026)
  def format_receipt_date(date)
    return "—" if date.blank?

    l(date, format: :long) rescue date.strftime("%d/%m/%Y")
  end

  # Badge de estado con estilo semántico
  def receipt_status_badge(status)
    status_str = status.to_s
    label, css_class = case status_str
    when "saved"
                         [ "Guardada", "badge-saved" ]
    when "ready_for_review"
                         [ "Por revisar", "badge-ready_for_review" ]
    when "processing"
                         [ "Procesando", "badge-processing" ]
    when "uploaded"
                         [ "Subida", "badge-uploaded" ]
    when "failed"
                         [ "Revisar", "badge-failed" ]
    else
                         [ status_str.humanize, "badge-ready_for_review" ]
    end

    content_tag(:span, label, class: "badge #{css_class}")
  end
end
