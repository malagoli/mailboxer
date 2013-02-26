class AddApprovalStatus < ActiveRecord::Migration
  def self.up
    add_column :notifications, :approval_status, :integer
    add_column :notifications, :approval_status_date, :datetime
  end

  def self.down
    remove_column :notifications, :approval_status
    remove_column :notifications, :approval_status_date
  end
end
