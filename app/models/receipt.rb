class Receipt < ApplicationRecord
  STATUSES = %w[uploaded processing ready_for_review saved failed].freeze
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png application/pdf].freeze

  has_one_attached :file

  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :file_presence
  validate :file_content_type

  scope :saved, -> { where(status: "saved") }
  scope :recent, -> { order(created_at: :desc) }

  def uploaded?; status == "uploaded"; end
  def processing?; status == "processing"; end
  def ready_for_review?; status == "ready_for_review"; end
  def saved?; status == "saved"; end
  def failed?; status == "failed"; end

  private

  def file_presence
    errors.add(:file, "debe ser adjuntado") unless file.attached?
  end

  def file_content_type
    return unless file.attached?
    return if ALLOWED_CONTENT_TYPES.include?(file.content_type)

    errors.add(:file, "debe ser un archivo JPG, PNG o PDF")
  end
end