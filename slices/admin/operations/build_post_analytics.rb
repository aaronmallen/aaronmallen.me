# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostAnalytics
      TOP_ROWS = 10

      include Deps["routes", summarize_page: "api.operations.summarize_page"]

      def call(post:, range:)
        to = Blog::TimeZone.today
        path = routes.path(:post, slug: post.slug)
        found = summarize_page.call(path:, from: to - (range - 1), to:, top: TOP_ROWS, post:)
        totals = found.fetch(:totals)

        {
          post:,
          range:,
          **totals.slice(:views, :visitors, :bounces, :read_throughs),
          readers: totals.fetch(:reach),
          **found.slice(:clicks, :countries, :devices, :referrers, :scroll, :sources, :first_days, :unique_readers),
        }
      end
    end
  end
end
