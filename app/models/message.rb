class Message < Notification


  APPROVAL_STATUS = {"waiting_approval" => 2, "approved" => 3,
                     "not_approved" => 4, "suspended" => 5,  "abuse" => 7}

  attr_accessible :attachment, :approval_status_date, :approval_status, :approval_status_note


  belongs_to :conversation, :validate => true, :autosave => true
  validates_presence_of :sender

  class_attribute :on_deliver_callback
  protected :on_deliver_callback
  scope :conversation, lambda { |conversation|
    where(:conversation_id => conversation.id)
  }

  mount_uploader :attachment, AttachmentUploader

  include Concerns::ConfigurableMailer

  default_value_for :approval_status do
    'waiting_approval'
  end

  default_value_for :approval_status_date do
    Time.current
  end

  default_value_for :approval_status_note do
    nil
  end


  def set_as_approved
    update_attributes!(:approval_status_date => Time.current,
                       :approval_status => 'approved')
    self.deliver_after_save
  end

  def set_as_not_approved
    update_attributes!(:approval_status_date => Time.current,
                       :approval_status => 'not_approved')
  end

  def set_as_not_approved_with_note (note)
    update_attributes!(:approval_status_date => Time.current,
                       :approval_status => 'not_approved',
                       :approval_status_note => note)
  end

if Message.table_exists?
  APPROVAL_STATUS.keys.each do |status_key|

    scope "all_#{status_key}", where("#{:approval_status}" => APPROVAL_STATUS[status_key])
    scope "not_all_#{status_key}", where(["#{:approval_status} <> ?", APPROVAL_STATUS[status_key]]);

    define_method "#{status_key}?" do
      (read_attribute :approval_status) == APPROVAL_STATUS["#{status_key}"]
    end

  end

  define_method "#{:approval_status}" do
    APPROVAL_STATUS.invert[read_attribute :approval_status]
  end

  define_method("#{:approval_status}=") do |val|
    write_attribute("#{:approval_status}",APPROVAL_STATUS[val])
  end
end

  class << self
    #Sets the on deliver callback method.
    def on_deliver(callback_method)
      self.on_deliver_callback = callback_method
    end
  end

  #Delivers a Message. USE NOT RECOMENDED.
  #Use Mailboxer::Models::Message.send_message instead.
  def deliver(reply = false, should_clean = true)
    self.clean if should_clean
    temp_receipts = Array.new
    #Receiver receipts
    self.recipients.each do |r|
      msg_receipt = Receipt.new
      msg_receipt.notification = self
      msg_receipt.is_read = false
      msg_receipt.receiver = r
      msg_receipt.mailbox_type = "inbox"
      temp_receipts << msg_receipt
    end
    #Sender receipt
    sender_receipt = Receipt.new
    sender_receipt.notification = self
    sender_receipt.is_read = true
    sender_receipt.receiver = self.sender
    sender_receipt.mailbox_type = "sentbox"
    temp_receipts << sender_receipt

    temp_receipts.each(&:valid?)
    if temp_receipts.all? { |t| t.errors.empty? }
      temp_receipts.each(&:save!) 	#Save receipts
      self.recipients.each do |r|
      #Should send an email?
        if Mailboxer.uses_emails
          email_to = r.send(Mailboxer.email_method,self)
          unless email_to.blank?
            get_mailer.send_email(self,r).deliver
          end
        end
      end
      if reply
        self.conversation.touch
      end
      self.recipients=nil
    self.on_deliver_callback.call(self) unless self.on_deliver_callback.nil?
    end
    return sender_receipt
  end

  def deliver_after_save
    self.receipts.waiting_approval.each do |r|
      r.mailbox_type="inbox"
      r.save!
        #Should send an email?
        if Mailboxer.uses_emails
          email_to = r.receiver.send(Mailboxer.email_method,self)
          unless email_to.blank?
            get_mailer.send_email(self,r.receiver).deliver
          end
        end
    end
      self.recipients=nil
      self.on_deliver_callback.call(self) unless self.on_deliver_callback.nil?
  end

  def save_not_deliver(reply = false, should_clean = true)
    self.clean if should_clean
    temp_receipts = Array.new

    self.recipients.each do |r|
      msg_receipt = Receipt.new
      msg_receipt.notification = self
      msg_receipt.is_read = false
      msg_receipt.receiver = r
      msg_receipt.mailbox_type = "waiting_approval"
      temp_receipts << msg_receipt
    end

    #Sender receipt
    sender_receipt = Receipt.new
    sender_receipt.notification = self
    sender_receipt.is_read = true
    sender_receipt.receiver = self.sender
    sender_receipt.mailbox_type = "sentbox"
    temp_receipts << sender_receipt

    temp_receipts.each(&:valid?)
    if temp_receipts.all? { |t| t.errors.empty? }
      temp_receipts.each(&:save!) 	#Save receipts

      if reply
        self.conversation.touch
      end
      self.recipients=nil
    end
    sender_receipt
  end

  private
  def build_receipt(receiver, mailbox_type, is_read = false)
    Receipt.new.tap do |receipt|
      receipt.notification = self
      receipt.is_read = is_read
      receipt.receiver = receiver
      receipt.mailbox_type = mailbox_type
    end
  end
end
