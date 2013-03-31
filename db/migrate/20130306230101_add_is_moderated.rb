class AddIsModerated < ActiveRecord::Migration
  def self.up
    add_column :conversations, :is_moderated, :boolean, :default => false
  end

  def self.down
    remove_column :conversations, :is_moderated
  end
end
