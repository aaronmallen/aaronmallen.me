# frozen_string_literal: true

module Admin
  module Operations
    class BuildSocialPage
      include Blog::Constants

      DEFAULT_VALUES = {
        mode: Blog::Types::SocialMode["now"],
        parts: [EMPTY_STRING].freeze,
        schedule_at: EMPTY_STRING,
      }.freeze
      KIND = Blog::Types::RecordKind["social_post"]

      include Deps[
        count_network_lengths: "operations.count_network_lengths",
        list_networks: "operations.list_networks",
        list_record_links: "operations.list_record_links",
        list_social_accounts: "operations.list_social_accounts",
        person_queries: "social.repos.person_queries",
        resolve_mentions: "social.operations.resolve_mentions",
        review_social_edits: "operations.review_social_edits",
        settings: "settings",
        social_post_queries: "social.repos.social_post_queries",
        suggestion_queries: "suggestions.repos.suggestion_queries",
      ]

      def call(
        filter: Blog::Types::SocialQueue["queued"], page: nil, params: nil, editing: nil,
        errors: EMPTY_HASH, records: EMPTY_HASH, now: Time.now
      )
        items = social_post_queries.by_filter(filter, page || first_page)

        {
          filter:, items:, now:, records: editing && list_record_links.call(KIND, editing.id, **records),
          **queue(items.rows), **composer(params, editing, errors),
        }
      end

      private

      def composer(params, editing, errors)
        values = values(params, editing)
        people = person_queries.all

        {
          counts: count_network_lengths.call(values[:parts]),
          editing: editing&.id,
          errors:,
          handles: resolve_mentions.handles(people),
          networks: list_networks.call(selected: targets(params, editing)),
          people:,
          suggestions: review_social_edits.call(editing),
          values:,
        }
      end

      def first_page = Blog::Structs::Page.new(number: 1, size: settings.page_size[:admin])

      def open_counts(items)
        unsent = items.reject { it.status == Blog::Types::SocialPostStatus["posted"] }

        suggestion_queries.open_counts_for_social_posts(unsent.map(&:id))
      end

      def parts(bodies)
        found = Array(bodies).map { Blog::Types::Text[it] }

        found.empty? ? [EMPTY_STRING] : found
      end

      def queue(items)
        {
          accounts: list_social_accounts.call,
          queued: social_post_queries.count_by_status.fetch(Blog::Types::SocialPostStatus["scheduled"], 0),
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
