class ReceiptsController < ApplicationController
  # Carga la boleta para las acciones que operan sobre un registro específico.
  before_action :set_receipt, only: %i[processing status edit update show reprocess destroy]

  # Redirige a una ruta amigable cuando la boleta solicitada no existe.
  rescue_from ActiveRecord::RecordNotFound, with: :receipt_not_found

  # Muestra la lista de boletas ya guardadas y validadas por el usuario.
  def index
    @receipts = Receipt.saved.recent
  end

  # Muestra las boletas que aún están pendientes de revisión o procesamiento.
  def pending
    @receipts = Receipt.where.not(status: "saved").recent
  end

  # Renderiza la vista de detalle de una boleta.
  def show; end

  # Crea un nuevo registro antes de cargar el documento.
  def new
    @receipt = Receipt.new
  end

  # Edita una boleta y descarta resultados de OCR claramente inválidos.
  def edit
    # Si tanto el comercio como el total están vacíos, la IA no encontró una boleta válida.
    if @receipt.merchant_name.blank? && @receipt.total_amount.blank?
      @receipt.destroy
      redirect_to new_receipt_path, alert: "El documento subido no parece ser una boleta válida. Por favor, sube una foto clara del comprobante."
    end
  end

  # Sube un archivo y encola el procesamiento OCR en segundo plano.
  def create
    uploaded_file = receipt_create_params[:file]
    existing = find_duplicate_receipt(uploaded_file)

    if existing
      redirect_to_existing(existing) and return
    end

    @receipt = Receipt.new(receipt_create_params)

    if @receipt.save
      ProcessReceiptJob.perform_later(@receipt.id)
      redirect_to processing_receipt_path(@receipt), notice: "Boleta subida exitosamente. Procesando..."
    else
      render :new, status: :unprocessable_content
    end
  end

  # Guarda los datos corregidos una vez que el usuario valida la extracción de la IA.
  def update
    if @receipt.update(receipt_update_params.merge(status: "saved"))
      redirect_to receipt_path(@receipt), notice: "¡Boleta guardada con éxito!"
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Redirige al usuario al formulario de revisión cuando el documento llegó a un estado terminal.
  def processing
    redirect_to edit_receipt_path(@receipt) if terminal_status?
  end

  # Proporciona información del estado para que el frontend pueda saber si el procesamiento terminó.
  def status
    render json: {
      id: @receipt.id,
      status: @receipt.status,
      completed: terminal_status?,
      edit_url: edit_receipt_path(@receipt)
    }
  end

  # Reintenta el procesamiento OCR de una boleta que necesita otro intento.
  def reprocess
    ProcessReceiptJob.perform_later(@receipt.id)
    redirect_to processing_receipt_path(@receipt), notice: "Reintentando procesamiento..."
  end

  # Elimina una boleta del sistema.
  def destroy
    @receipt.destroy
    redirect_to receipts_path, notice: "Boleta eliminada correctamente."
  end

  private

  # Fallback amigable cuando no se puede encontrar la boleta.
  def receipt_not_found
    redirect_to receipts_path, alert: "La boleta que buscas no existe o fue eliminada."
  end

  # Busca una boleta por ID para las acciones de miembro.
  def set_receipt
    @receipt = Receipt.find(params[:id])
  end

  # Devuelve true cuando la boleta ya no se está procesando y puede mostrarse al usuario.
  def terminal_status?
    %w[ready_for_review failed saved].include?(@receipt.status)
  end

  # Detecta archivos duplicados comparando el checksum del documento para evitar envíos repetidos.
  def find_duplicate_receipt(uploaded_file)
    return nil unless uploaded_file.respond_to?(:read)

    checksum = OpenSSL::Digest::MD5.new
    while (chunk = uploaded_file.read(5.megabytes))
      checksum.update(chunk)
    end
    uploaded_file.rewind

    encoded_checksum = checksum.base64digest

    Receipt.joins(file_attachment: :blob)
           .where(active_storage_blobs: { checksum: encoded_checksum })
           .where(status: %w[saved ready_for_review uploaded processing failed])
           .first
  end

  # Redirige al usuario según si el registro duplicado ya está guardado o sigue pendiente.
  def redirect_to_existing(receipt)
    if receipt.saved?
      redirect_to receipt_path(receipt), flash: { warning: "Esta boleta ya fue guardada anteriormente." }
    else
      redirect_to edit_receipt_path(receipt), flash: { warning: "Ya existe un registro pendiente para esta boleta (##{receipt.id})." }
    end
  end


  def receipt_create_params
    params.require(:receipt).permit(:file)
  end


  def receipt_update_params
    params.require(:receipt).permit(
      :merchant_name,
      :rut_emisor,
      :purchase_date,
      :document_number,
      :document_type,
      :net_amount,
      :tax_amount,
      :total_amount
    )
  end
end
