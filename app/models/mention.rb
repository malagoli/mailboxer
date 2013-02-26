class Mention < ActiveRecord::Base
  belongs_to :mentionable, :polymorphic =>  true
  belongs_to :conversation
end