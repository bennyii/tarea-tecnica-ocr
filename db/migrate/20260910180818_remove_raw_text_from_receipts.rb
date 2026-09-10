class RemoveRawTextFromReceipts < ActiveRecord::Migration[8.1]
  def change
    remove_column :receipts, :raw_text, :string
  end
end
