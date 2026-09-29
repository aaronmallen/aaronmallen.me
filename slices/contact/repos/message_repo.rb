# frozen_string_literal: true

module Contact
  module Repos
    class MessageRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def by_id(id) = messages.by_pk(id).one

      def by_status(status) = messages.with_status(status).newest_first.to_a

      def claim(visitor_hash:, limit:, since:, **attrs)
        messages.claim(visitor_hash:, limit:, since:, **attrs)
      end

      def count_from_visitor_since(visitor_hash, time) = messages.for_visitor(visitor_hash).received_since(time).count

      def count_with_status(status) = messages.with_status(status).count

      def page_by_status(status, page) = page.fill(messages.with_status(status).newest_first.paged(page).to_a)

      def received_between(from:, to:, page:, status: nil)
        found = messages.received_since(Blog::TimeZone.day_start(from))
        found = found.received_before(Blog::TimeZone.day_start(to + 1))
        found = found.with_status(status) if status

        page.fill(found.newest_first.paged(page).to_a)
      end
    end
  end
end
