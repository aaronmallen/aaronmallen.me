# frozen_string_literal: true

module Admin
  module UI
    module Components
      class AttentionLines < Component
        BROKEN = Blog::Types::PostFilter["broken"]
        DEAD = Blog::Types::JobSetName["dead"]
        PENDING = Blog::Types::WebmentionStatus["pending"]
        POSTED = Blog::Types::SocialQueue["posted"]
        QUEUED = Blog::Types::SocialQueue["queued"]
        SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]

        prop :broken_links, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::Integer)
        prop :failed_social_posts, Blog::Types::Array.of(Blog::Types::SocialPostStatus)
        prop :inbox, Blog::Types::Integer
        prop :more_dead_jobs, Blog::Types::Integer
        prop :webmentions, Blog::Types::Integer

        def view_template
          line(".inbox", path(:admin_inbox), ".waiting", @inbox)
          line(".cross_posts", path(:admin_social, filter: failed_queue), ".failed", @failed_social_posts.size)
          line(".webmentions", path(:admin_webmentions, status: PENDING), ".waiting", @webmentions)
          line(".dead_jobs", dead_set, ".more", @more_dead_jobs)
          broken_links
        end

        private

        def broken_count(posts, short)
          return t(".failing", count: posts + short) unless posts.positive? && short.positive?

          t(".broken_split", posts:, short:)
        end

        def broken_links
          posts, short = @broken_links.values_at(:posts, :short)
          return if (posts + short).zero?

          TodayLine(label: t(".broken_links"), href: path(:admin_posts, status: BROKEN), warn: true) do
            broken_count(posts, short)
          end
        end

        def dead_set = "#{path(:admin_settings_jobs, set: DEAD)}##{Jobs::Set.id(DEAD)}"

        def failed_queue = @failed_social_posts.include?(SCHEDULED) ? QUEUED : POSTED

        def line(label, href, value, count)
          return unless count.positive?

          TodayLine(label: t(label), href:, warn: true) { t(value, count:) }
        end
      end
    end
  end
end
