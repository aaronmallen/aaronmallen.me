# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Queue < Component
          DRAFTS = Blog::Types::SocialQueue["drafts"]
          POSTED = Blog::Types::SocialQueue["posted"]
          QUEUED = Blog::Types::SocialQueue["queued"]

          EMPTIES = { QUEUED => ".empty.queued", POSTED => ".empty.posted", DRAFTS => ".empty.drafts" }.freeze
          FILTERS = { QUEUED => ".queued", POSTED => ".posted", DRAFTS => ".drafts" }.freeze

          prop :filter, Blog::Types::String
          prop :items, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :now, Blog::Types::Time
          prop :suggestion_counts, Blog::Types::Hash

          def view_template
            Card(label: t(".label"), title: t(".title")) do |card|
              card.side { filter_form }
              next Empty { t(EMPTIES.fetch(@filter)) } if @items.empty?

              @items.each { QueueItem(social_post: it, filter: @filter, now: @now, suggestions: count(it)) }
            end
          end

          private

          def count(social_post) = @suggestion_counts.fetch(social_post.id, 0)

          def filter_form
            form(action: path(:admin_social), method: "get", data: { autosubmit: "" }) do
              SegmentedControl(label: t(".filter"), name: "filter", options: filter_options, selected: @filter)
              noscript { Button(type: "submit", small: true) { t(".apply") } }
            end
          end

          def filter_options = FILTERS.transform_values { t(it) }
        end
      end
    end
  end
end
