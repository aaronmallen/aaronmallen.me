# frozen_string_literal: true

module Contact
  module Relations
    class Messages < Blog::DB::Relation
      schema :messages, infer: true do
        associations do
          has_many :message_tags
          has_many :tags, through: :message_tags, view: :in_name_order
        end
      end

      def claim(visitor_hash:, limit:, total_limit:, since:, **attrs)
        capped_claim(received_since(since), visitor_hash:, limit:, total_limit:) do
          stamped(:create, :received_at).call(**attrs, visitor_hash:)
        end
      end

      def counts_by(column) = unordered.select(column) { integer.count(id).as(:count) }.group(column)

      def for_visitor(visitor_hash) = where(visitor_hash:)

      def marked_spam_before(time) = where { marked_spam_at < time }

      def newest_first = order(self[:received_at].desc, self[:id].desc)

      def received_before(time) = where { received_at < time }

      def received_since(time) = where { received_at >= time }

      def with_status(status) = where(status:)
    end
  end
end
