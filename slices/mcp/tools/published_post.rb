# frozen_string_literal: true

module MCP
  module Tools
    module PublishedPost
      DESCRIPTION = "For a published post's path, since_publish numbers each day of the range from the Chicago day " \
                    "the post went out, which is day 1. The post also gets first_days and unique_readers, " \
                    "whatever the range. first_days gives its visitors on each of its first " \
                    "#{Analytics::Repos::AnalyticsPageQueries::FIRST_DAYS} days, day 1 first, up to today, and " \
                    "median, the middle " \
                    "visitors on each of those days across the posts the site counted from their first day, for " \
                    "comparison. unique_readers gives readers, the people who viewed the post in the 12 months " \
                    "after it went out, each counted once by a hash kept for those months, and final, true once " \
                    "the count can no longer change. readers is null for a post that went out too long before the " \
                    "site began counting. ".freeze
      QUERIES = %i[analytics_page_queries post_reader_queries].freeze

      module_function

      def call(post, path, days, analytics_page_queries:, post_reader_queries:)
        {
          since_publish: since_publish(days, Blog::TimeZone.today(post.published_at)),
          first_days: analytics_page_queries.first_days(path),
          unique_readers: post_reader_queries.unique_readers([post]).fetch(post.id),
        }
      end

      def since_publish(days, first)
        days.select { it.fetch(:day) >= first }.map do |found|
          date = found.fetch(:day)
          { day: (date - first).to_i + 1, date: date.iso8601, **found.except(:day) }
        end
      end
    end
  end
end
