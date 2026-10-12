# frozen_string_literal: true

module Mail
  module Relations
    class MailAttachments < Blog::DB::Relation
      schema :mail_attachments, infer: true do
        associations do
          belongs_to :mail_message
        end
      end

      def in_part_order = order(:part_id)
    end
  end
end
