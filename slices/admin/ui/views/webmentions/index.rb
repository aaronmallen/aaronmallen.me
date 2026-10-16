# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Webmentions
        class Index < View
          include Components::Webmentions

          APPROVED = Blog::Types::WebmentionStatus["approved"]
          LIVE_TABLES = %w[posts].freeze
          PENDING = Blog::Types::WebmentionStatus["pending"]

          EMPTIES = Blog::Types::WebmentionStatus.values.to_h { [it, ".empty.#{it}"] }.freeze
          FILTERS = Blog::Types::WebmentionStatus.values.to_h { [it, "ui.views.webmentions.index.#{it}"] }.freeze

          prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)
          prop :filter, Blog::Types::WebmentionStatus
          prop :inbox, Blog::Types::Hash

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            PageHead(title: t(".heading"), sub:) do
              filter_form
              Button(href: path(:admin_webmention_settings), variant: :gh, icon: "fa-solid fa-gear") { t(".settings") }
            end

            inbox
          end

          private

          def count(status) = @counts.fetch(status, 0)

          def filter_form
            FilterSwitch(
              action: path(:admin_webmentions),
              name: "status",
              options: FILTERS.transform_values { t(it) },
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
            return Card(empty: t(EMPTIES.fetch(@filter))) if mentions.rows.empty?

            Bulk(filter: @filter, page: mentions.number)
            div(class: "cols", data: { key_list: true }) { mentions.rows.each { |mention| row(mention) } }
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
