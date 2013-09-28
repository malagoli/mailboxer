# This migration comes from professionisti_engine (originally 20130831104743)
class AddApprovalStatusNoteToMessages < ActiveRecord::Migration
  def change
    add_column :notifications, :approval_status_note, :string
  end
end
