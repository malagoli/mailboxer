class CreateMentions < ActiveRecord::Migration
  def change
    create_table :mentions do |t|
      t.integer :mentionable_id
      t.string  :mentionable_type
      t.column :conversation_id, :integer
      t.timestamps
    end
  end
end

