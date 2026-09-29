# frozen_string_literal: true

module Admin
  module Operations
    class BuildSocialPage
      include Dry::Core::Constants

      DEFAULT_VALUES = {
        mode: Blog::Types::SocialMode["now"],
        parts: [EMPTY_STRING].freeze,
        schedule_at: EMPTY_STRING,
      }.freeze
      include Deps[
        count_network_lengths: "operations.count_network_lengths",
        list_networks: "operations.list_networks",
        list_social_accounts: "operations.list_social_accounts",
        open_suggestion_counts: "suggestions.queries.open_counts_for_social_posts",
        review_social_edits: "operations.review_social_edits",
        settings: "settings",
        social_post_counts_by_status: "social.queries.social_post_counts_by_status",
        social_posts_by_filter: "social.queries.social_posts_by_filter",
      ]

      def call(
        filter: Blog::Types::SocialQueue["queued"], page: nil, params: nil, editing: nil,
        errors: EMPTY_HASH, now: Time.now
      )
        items = social_posts_by_filter.call(filter, page || first_page)

        { filter:, items:, now:, **queue(items.rows), **composer(params, editing, errors) }
      end

      private

      def composer(params, editing, errors)
        values = values(params, editing)

        {
          counts: count_network_lengths.call(values[:parts]),
          editing: editing&.id,
          errors:,
          networks: list_networks.call(selected: targets(params, editing)),
          suggestions: review_social_edits.call(editing),
          values:,
        }
      end

      def first_page = Blog::Page.new(number: 1, size: settings.page_size[:admin])

      def open_counts(items)
        unsent = items.reject { it.status == Blog::Types::SocialPostStatus["posted"] }

        open_suggestion_counts.call(unsent.map(&:id))
      end

      def parts(bodies)
        found = Array(bodies).map { Blog::Types::Text[it] }

        found.empty? ? [EMPTY_STRING] : found
      end

      def queue(items)
        {
          accounts: list_social_accounts.call,
          queued: social_post_counts_by_status.call.fetch(Blog::Types::SocialPostStatus["scheduled"], 0),
          suggestion_counts: open_counts(items),
        }
      end

      def record_values(social_post)
        scheduled = social_post.status == Blog::Types::SocialPostStatus["scheduled"]

        {
          mode: scheduled ? Blog::Types::SocialMode["schedule"] : Blog::Types::SocialMode["now"],
          parts: parts(social_post.parts.map(&:body)),
          schedule_at: scheduled ? Blog::TimeZone.input_value(social_post.posted_at) : EMPTY_STRING,
        }
      end

      def targets(params, editing)
        return Array(params[:targets]).map(&:to_s) if params

        editing&.targets&.to_a
      end

      def values(params, editing)
        return record_values(editing) if !params && editing
        return DEFAULT_VALUES unless params

        {
          mode: Blog::Types::SocialModeParam[params[:mode]],
          parts: parts(params[:parts]),
          schedule_at: Blog::Types::Text[params[:schedule_at]],
        }
      end
    end
  end
end
