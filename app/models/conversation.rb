class Conversation < ActiveRecord::Base
  attr_accessible :subject

	has_many :messages, :dependent => :destroy
	has_many :receipts, :through => :messages

  has_many :mentions

	validates_presence_of :subject

  before_validation :clean

  scope :participant, lambda {|participant|
    select('DISTINCT conversations.*').
    where('notifications.type'=> Message.name).
    order("conversations.updated_at DESC").
    joins(:receipts).merge(Receipt.recipient(participant))
  }
  scope :inbox, lambda {|participant|
    participant(participant).merge(Receipt.inbox.not_trash)
  }
  scope :sentbox, lambda {|participant|
    participant(participant).merge(Receipt.sentbox.not_trash)
  }
  scope :trash, lambda {|participant|
    participant(participant).merge(Receipt.trash)
  }
  scope :unread,  lambda {|participant|
    participant(participant).merge(Receipt.is_unread)
  }
  scope :not_trash,  lambda {|participant|
    participant(participant).merge(Receipt.not_trash)
  }

  #scope :for_mentionable_with_approved_messages, lambda {|mentionable|
  #  joins(:messages).joins(:mentions).where(:mentions => {:mentionable_id => mentionable.id, :mentionable_type => mentionable.class.name}).where(:notifications => {:approval_status=>3})

  scope :for_mentionable, lambda {|mentionable|
    joins(:mentions).where(:mentions => {:mentionable_id =>mentionable.id, :mentionable_type => mentionable.class.name})
  }

  scope :approved, where(["notifications.approval_status in (?)",  [Message::APPROVAL_STATUS['approved']  ]])



  #Mark the conversation as read for one of the participants
	def mark_as_read(participant)
		return if participant.nil?
		return self.receipts_for(participant).mark_as_read
	end

  #Mark the conversation as unread for one of the participants
	def mark_as_unread(participant)
		return if participant.nil?
		return self.receipts_for(participant).mark_as_unread
	end

  #Move the conversation to the trash for one of the participants
	def move_to_trash(participant)
		return if participant.nil?
		return self.receipts_for(participant).move_to_trash
	end

  #Takes the conversation out of the trash for one of the participants
	def untrash(participant)
		return if participant.nil?
		return self.receipts_for(participant).untrash
	end

  #Mark the conversation as deleted for one of the participants
  def mark_as_deleted(participant)
    return if participant.nil?
    deleted_receipts = self.receipts_for(participant).mark_as_deleted
    if is_orphaned?
      self.destroy
    else
      deleted_receipts
    end
  end

  #Returns an array of participants
	def recipients
		if self.last_message
			recps = self.last_message.recipients
			recps = recps.is_a?(Array) ? recps : [recps]
		return recps
		end
		return []
	end

  #Returns an array of participants
	def participants
	  return recipients
	end

	#Originator of the conversation.
	def originator
		@orignator = self.original_message.sender if @originator.nil?
		return @orignator
	end

	#First message of the conversation.
	def original_message
		@original_message = self.messages.find(:first, :order => 'created_at') if @original_message.nil?
		return @original_message
	end

	#Sender of the last message.
	def last_sender
		@last_sender = self.last_message.sender if @last_sender.nil?
		return @last_sender
	end

  #Sender of the last approved message.
  def last_approved_sender
    @last_approved_sender = self.last_approved_message.sender if @last_approved_sender.nil?
    return @last_approved_sender
  end


  #Last approved message in the conversation.
	def last_approved_message
		@last_approved_message = self.messages.all_approved.find(:first, :order => 'created_at DESC') if @last_approved_message.nil?
		return @last_approved_message
	end

  #Returns the receipts of the conversation for one participants
	def receipts_for(participant)
	  return Receipt.conversation(self).recipient(participant)
	end

  #Returns the number of messages of the conversation
	def count_messages
		return Message.conversation(self).count
	end

  #Returns true if the messageable is a participant of the conversation
	def is_participant?(participant)
		return false if participant.nil?
		return self.receipts_for(participant).count != 0
	end

  #Returns true if the participant has at least one trashed message of the conversation
	def is_trashed?(participant)
		return false if participant.nil?
		return self.receipts_for(participant).trash.count!=0
	end

  #Returns true if the participant has deleted the conversation
  def is_deleted?(participant)
    return false if participant.nil?
    return self.receipts_for(participant).deleted.count == self.receipts_for(participant).count
  end

  #Returns true if both participants have deleted the conversation
  def is_orphaned?
    participants.reduce(true) do |is_orphaned, participant|
      is_orphaned && is_deleted?(participant)
    end
  end

  #Returns true if the participant has trashed all the messages of the conversation
	def is_completely_trashed?(participant)
		return false if participant.nil?
		return self.receipts_for(participant).trash.count == self.receipts_for(participant).count
	end

	def is_read?(participant)
		!self.is_unread?(participant)
	end

  #Returns true if the participant has at least one unread message of the conversation
	def is_unread?(participant)
		return false if participant.nil?
		return self.receipts_for(participant).not_trash.is_unread.count!=0
	end

	protected

	include ActionView::Helpers::SanitizeHelper

  #Use the default sanitize to clean the conversation subject
	def clean
		self.subject = sanitize self.subject
	end

end
