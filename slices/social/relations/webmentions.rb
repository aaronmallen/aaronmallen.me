# frozen_string_literal: true

module Social
  module Relations
    class Webmentions < Blog::DB::Relation
      APPROVED = Blog::Types::WebmentionStatus["approved"]
      PENDING = Blog::Types::WebmentionStatus["pending"]
      SPAM = Blog::Types::WebmentionStatus["spam"]

      APPROVED_NOT_SPAM = Sequel.&(
        Sequel.function(:bool_or, Sequel.expr(status: APPROVED)),
        Sequel.~(Sequel.function(:bool_or, Sequel.expr(status: SPAM))),
      )

      schema :webmentions, infer: true

      def approved = with_status(APPROVED)

      def by_author_url(author_url) = where(author_url:)

      def for_post(post_id) = where(post_id:)

      def for_posts(post_ids) = where(post_id: post_ids)

      def from_source(source_url) = where(source_url:)

      def known_author? = unordered.dataset.get(APPROVED_NOT_SPAM) || false

      def newest_first = order(self[:received_at].desc, self[:id].desc)

      def oldest_first = order(self[:received_at].asc, self[:id].asc)

      def received_before(time) = where { received_at < time }

      def received_since(time) = where { received_at >= time }

      def store(resent:, **attrs)
        update_statement = excluded([*resent, :updated_at]).merge(status: rechecked(resent))

        command(:store).with(update_statement:).call(attrs)
      end

      def unseen = where(seen_at: nil)

      def with_status(status) = where(status:)

      def with_types(types) = where(type: types)

      private

      def changed(fields)
        stored = Sequel.function(:row, *fields.map { Sequel[:webmentions][it] })
        sent = Sequel.function(:row, *fields.map { Sequel[:excluded][it] })

        Sequel.lit("? IS DISTINCT FROM ?", stored, sent)
      end

      def rechecked(fields)
        status = Sequel[:webmentions][:status]

        Sequel.case({ Sequel.&({ status => APPROVED }, changed(fields)) => PENDING }, status)
      end
    end
  end
end
