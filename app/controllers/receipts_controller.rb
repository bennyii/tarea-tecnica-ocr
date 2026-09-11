class ReceiptsController < ApplicationController
  before_action :set_receipt, only: %i[processing status edit update show reprocess destroy]
  rescue_from ActiveRecord::RecordNotFound, with: :receipt_not_found
  def index
    @receipts = Receipt.saved.recent
  end

  # METODO PARA MOSTRAR BOLETAS PENDIENTES
  def pending
  @receipts = Receipt.where.not(status: "saved").recent
  end

  # METODO PARA MOSTRAR BOLETAS
  def show; end

  # METODO PARA CREAR NUEVAS BOLETAS
  def new
    @receipt = Receipt.new
  end

  # METODO PARA EDITAR BOLETAS
  def edit; end

  # METODO PARA CREAR BOLETAS
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

  # METODO PARA ACTUALIZAR LA BOLETA
  def update
    if @receipt.update(receipt_update_params.merge(status: "saved"))
      redirect_to receipt_path(@receipt), notice: "¡Boleta guardada con éxito!"
    else
      render :edit, status: :unprocessable_content
    end
  end

  # METODO PARA DETECTAR SI LA BOLETA ESTA EN UN ESTADO TERMINAL
  def processing
    redirect_to edit_receipt_path(@receipt) if terminal_status?
  end

  # METODO PARA DETECTAR SI LA BOLETA ESTA EN UN ESTADO TERMINAL
  def status
    render json: {
      id: @receipt.id,
      status: @receipt.status,
      completed: terminal_status?,
      edit_url: edit_receipt_path(@receipt)
    }
  end

  # METODO PARA REINTENTAR EL PROCESAMIENTO DE LA BOLETA
  def reprocess
    ProcessReceiptJob.perform_later(@receipt.id)
    redirect_to processing_receipt_path(@receipt), notice: "Reintentando procesamiento..."
  end

  # METODO PARA ELIMINAR BOLETAS
  def destroy
    @receipt.destroy
    redirect_to receipts_path, notice: "Boleta eliminada correctamente."
  end

  private

  def receipt_not_found
    redirect_to receipts_path, alert: "La boleta que buscas no existe o fue eliminada."
  end

  # METODO PARA BUSCAR LA BOLETA POR ID
  def set_receipt
    @receipt = Receipt.find(params[:id])
  end

  # METODO PARA DETECTAR SI LA BOLETA ESTA EN UN ESTADO TERMINAL
  def terminal_status?
    %w[ready_for_review failed saved].include?(@receipt.status)
  end

# METODO PARA DETECTAR ARCHIVOS DUPLICADOS
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
  # METODO PARA REDIRECCIONAR AL USUARIO DEPENDIENDO EL ESTADO DEL ARCHIVO
  def redirect_to_existing(receipt)
    if receipt.saved?
      redirect_to receipt_path(receipt), flash: { warning: "Esta boleta ya fue guardada anteriormente." }
    else
      redirect_to edit_receipt_path(receipt), flash: { warning: "Ya existe un registro pendiente para esta boleta (##{receipt.id})." }
    end
  end

  # METODO PARA PERMITIR LA CREACION DE BOLETAS
  def receipt_create_params
    params.require(:receipt).permit(:file)
  end

  # METODO PARA PERMITIR LA ACTUALIZACION DE BOLETAS
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
