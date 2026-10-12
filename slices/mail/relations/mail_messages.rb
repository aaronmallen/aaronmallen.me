# frozen_string_literal: true

module Mail
  module Relations
    class MailMessages < Blog::DB::Relation
      schema :mail_messages, infer: true do
        associations do
          belongs_to :mail_thread
          has_many :mail_attachments, view: :in_part_order
        end
      end

      def for_visitor(visitor_hash) = where(visitor_hash:)

      def from_visitors = exclude(visitor_hash: nil)

      def oldest_first = order(self[:received_at].asc, self[:id].asc)

      def received_since(time) = where { received_at >= time }
    end
  end
end
