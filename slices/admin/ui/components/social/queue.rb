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
          prop :now, Blog::Types::Time
          prop :page, Blog::Types::Instance(Blog::Paged)
          prop :suggestion_counts, Blog::Types::Hash

          def view_template
            Card(label: t(".label"), title: t(".title"), data: { key_list: true }) do |card|
              card.side { filter_form }
              next Empty { t(EMPTIES.fetch(@filter)) } if @page.rows.empty?

              @page.rows.each { QueueItem(social_post: it, filter: @filter, now: @now, suggestions: count(it)) }
              Pager(page: @page, route: :admin_social, params: { filter: @filter })
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
