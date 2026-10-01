# frozen_string_literal: true

module Contact
  module Relations
    class SpamSenders < Blog::DB::Relation
      schema :spam_senders, infer: true

      def by_reply_to(reply_to) = where(reply_to: Sequel.function(:lower, reply_to))

      def flag(reply_to, at:)
        dataset.insert_conflict.insert(reply_to: Sequel.function(:lower, reply_to), marked_at: at)
      end
    end
  end
end
