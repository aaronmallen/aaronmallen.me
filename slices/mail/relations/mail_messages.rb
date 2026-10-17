# frozen_string_literal: true

module Mail
  module Relations
    class MailMessages < Blog::DB::Relation
      SYNCED = %i[subject reply_to from_name body html_body received_at].freeze
      LETTER = Sequel.join(%i[reply_to body from_name].map { Sequel.function(:coalesce, it, "") }, " ")

      schema :mail_messages, infer: true do
        associations do
          belongs_to :mail_thread
          has_many :mail_attachments, view: :in_part_order
        end
      end

      def for_visitor(visitor_hash) = where(visitor_hash:)

      def from_visitors = exclude(visitor_hash: nil)

      def matching(text) = containing(text, LETTER)

      def oldest_first = order(self[:received_at].asc, self[:id].asc)

      def received_since(time) = where { received_at >= time }

      def store(rows)
        dataset.insert_conflict(
          target: %i[mail_thread_id gmail_id], update: excluded([*SYNCED, :updated_at]), update_where: changed(SYNCED),
        ).multi_insert(rows)
      end
    end
  end
end
