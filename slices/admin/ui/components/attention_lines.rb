# frozen_string_literal: true

module Admin
  module UI
    module Components
      class AttentionLines < Component
        PENDING = Blog::Types::WebmentionStatus["pending"]
        POSTED = Blog::Types::SocialQueue["posted"]
        QUEUED = Blog::Types::SocialQueue["queued"]
        SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]

        prop :failed_social_posts, Blog::Types::Array.of(Blog::Types::SocialPostStatus)
        prop :inbox, Blog::Types::Integer
        prop :webmentions, Blog::Types::Integer

        def view_template
          line(".inbox", path(:admin_inbox), ".waiting", @inbox)
          line(".cross_posts", path(:admin_social, filter: failed_queue), ".failed", @failed_social_posts.size)
          line(".webmentions", path(:admin_webmentions, status: PENDING), ".waiting", @webmentions)
        end

        private

        def failed_queue = @failed_social_posts.include?(SCHEDULED) ? QUEUED : POSTED

        def line(label, href, value, count)
          return unless count.positive?

          TodayLine(label: t(label), href:, warn: true) { t(value, count:) }
        end
      end
    end
  end
end
