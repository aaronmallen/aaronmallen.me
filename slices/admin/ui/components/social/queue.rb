# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Queue < Component
          EMPTIES = Blog::Types::SocialQueue.values.to_h { [it, ".empty.#{it}"] }.freeze
          FILTERS = Blog::Types::SocialQueue.values.to_h { [it, "ui.components.social.queue.#{it}"] }.freeze

          prop :accounts, Blog::Types::Hash
          prop :filter, Blog::Types::String
          prop :now, Blog::Types::Time
          prop :page, Blog::Types::Instance(Blog::Structs::Paged)
          prop :suggestion_counts, Blog::Types::Hash

          def view_template
            Card(title: t(".title"), data: { key_list: true }) do |card|
              card.side { filter_form }
              next Empty { t(EMPTIES.fetch(@filter)) } if @page.rows.empty?

              @page.rows.each { item(it) }
              Pager(page: @page, route: :admin_social, params: { filter: @filter })
            end
          end

          private

          def count(social_post) = @suggestion_counts.fetch(social_post.id, 0)

          def filter_form
            FilterSwitch(
              action: path(:admin_social),
              name: "filter",
              options: FILTERS,
              selected: @filter,
              label: t(".filter"),
            )
          end

          def item(social_post)
            QueueItem(social_post:, accounts: @accounts, filter: @filter, now: @now, suggestions: count(social_post))
          end
        end
      end
    end
  end
end
