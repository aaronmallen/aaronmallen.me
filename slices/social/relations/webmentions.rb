# frozen_string_literal: true

module Social
  module Relations
    class Webmentions < Blog::DB::Relation
      APPROVED = Blog::Types::WebmentionStatus["approved"]
      PENDING = Blog::Types::WebmentionStatus["pending"]

      schema :webmentions, infer: true

      def approved = with_status(APPROVED)

      def by_author_url(author_url) = where(author_url:)

      def for_post(post_id) = where(post_id:)

      def for_posts(post_ids) = where(post_id: post_ids)

      def from_source(source_url) = where(source_url:)

      def newest_first = order(self[:received_at].desc, self[:id].desc)

      def oldest_first = order(self[:received_at].asc, self[:id].asc)

      def received_before(time) = where { received_at < time }

      def received_since(time) = where { received_at >= time }

      def store(resent:, keep_approved: false, **attrs)
        update_statement = excluded([*resent, :updated_at])
        update_statement = update_statement.merge(status: rechecked(resent)) unless keep_approved

        command(:store).with(update_statement:).call(attrs)
      end

      def unseen = where(seen_at: nil)

      def with_status(status) = where(status:)

      def with_types(types) = where(type: types)

      def without_status(status) = exclude(status:)

      private

      def changed(fields)
        Sequel.is_distinct_from(*%i[webmentions excluded].map { |table| fields.map { Sequel[table][it] } })
      end

      def rechecked(fields)
        status = Sequel[:webmentions][:status]

        Sequel.case({ Sequel.&({ status => APPROVED }, changed(fields)) => PENDING }, status)
      end
    end
  end
end
