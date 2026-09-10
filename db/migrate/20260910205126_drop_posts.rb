class DropPosts < ActiveRecord::Migration[8.1]
  def change
    drop_table :posts
  end
end
