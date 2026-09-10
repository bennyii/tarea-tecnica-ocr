class CreateReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :receipts do |t|
      t.string :merchant_name
      t.string :rut_emisor
      t.date :purchase_date
      t.string :document_number
      t.string :document_type
      t.decimal :net_amount, precision: 12, scale: 2
      t.decimal :tax_amount, precision: 12, scale: 2
      t.decimal :total_amount, precision: 12, scale: 2
      t.text :raw_text
      t.text :ai_raw_response
      t.string :status, default: "uploaded"

      t.timestamps
    end

    add_index :receipts, :status
  end
end
