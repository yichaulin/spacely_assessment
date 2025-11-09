class CreateProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :properties, id: :uuid do |t|
      t.integer :custom_unique_id, null: false
      t.string :name, null: false
      t.string :address, null: false
      t.string :category, null: false

      t.integer :room_number, null: true
      t.integer :rent_fee, null: true
      t.float :size, null: true

      t.timestamps
    end

    add_index :properties, :custom_unique_id, unique: true
    add_index :properties, :category
  end
end
