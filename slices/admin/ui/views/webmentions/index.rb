# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Webmentions
        class Index < View
          include Components::Webmentions

          APPROVED = Blog::Types::WebmentionStatus["approved"]
          PENDING = Blog::Types::WebmentionStatus["pending"]

          EMPTIES = Blog::Types::WebmentionStatus.values.to_h { [it, ".empty.#{it}"] }.freeze
          FILTERS = Blog::Types::WebmentionStatus.values.to_h { [it, "ui.views.webmentions.index.#{it}"] }.freeze

          prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)
          prop :filter, Blog::Types::WebmentionStatus
          prop :inbox, Blog::Types::Hash
          prop :posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :settings, Blog::Types::Instance(ROM::Struct)

          def view_template
            PageHead(title: t(".heading"), sub:) { filter_form }

            inbox
            div(class: "g-main wm-settings") { side_cards }
          end

          private

          def count(status) = @counts.fetch(status, 0)

          def filter_form
            FilterSwitch(
              action: path(:admin_webmentions),
              name: "status",
              options: FILTERS,
              selected: @filter,
              label: t(".filter"),
            )
          end

          def inbox
            rows
            Pager(page: @inbox[:mentions], route: :admin_webmentions, params: { status: @filter })
          end

          def row(mention)
            Row(mention:, slug: @inbox[:slugs].fetch(mention.post_id), filter: @filter, bulk: Bulk::ID)
          end

          def rows
            mentions = @inbox[:mentions]
            return Card { Empty { t(EMPTIES.fetch(@filter)) } } if mentions.rows.empty?

            Bulk(filter: @filter, page: mentions.number)
            div(class: "cols", data: { key_list: true }) { mentions.rows.each { |mention| row(mention) } }
          end

          def side_cards
            SettingsCard(settings: @settings, filter: @filter)
            PostsCard(posts: @posts)
          end

          def sub
            dotted(
              t(".pending_count", count: count(PENDING)),
              t(".shown_count", count: count(APPROVED)),
            )
          end
        end
      end
    end
  end
end
