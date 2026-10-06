# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Webmentions
        class Index < View
          include Components::Webmentions

          APPROVED = Blog::Types::WebmentionStatus["approved"]
          IGNORED = Blog::Types::WebmentionStatus["ignored"]
          PENDING = Blog::Types::WebmentionStatus["pending"]
          SPAM = Blog::Types::WebmentionStatus["spam"]

          EMPTIES = {
            PENDING => ".empty.pending",
            APPROVED => ".empty.approved",
            IGNORED => ".empty.ignored",
            SPAM => ".empty.spam",
          }.freeze
          FILTERS = {
            PENDING => "ui.views.webmentions.index.pending",
            APPROVED => "ui.views.webmentions.index.approved",
            IGNORED => "ui.views.webmentions.index.ignored",
            SPAM => "ui.views.webmentions.index.spam",
          }.freeze
          SEPARATOR = " · "

          def initialize(counts:, filter:, inbox:, posts:, settings:)
            super()
            @counts = counts
            @filter = filter
            @inbox = inbox
            @posts = posts
            @settings = settings
          end

          def view_template
            PageHead(title: t(".heading"), sub:) { filter_form }

            Grid(columns: 2) do
              SideStack { inbox }
              SideStack { side_cards }
            end
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
            Card(title: t(".inbox"), data: { key_list: true }) { rows }
            Pager(page: @inbox[:mentions], route: :admin_webmentions, params: { status: @filter })
          end

          def row(mention)
            Row(mention:, slug: @inbox[:slugs].fetch(mention.post_id), filter: @filter, bulk: Bulk::ID)
          end

          def rows
            mentions = @inbox[:mentions]
            return Empty { t(EMPTIES.fetch(@filter)) } if mentions.rows.empty?

            Bulk(filter: @filter, page: mentions.number)
            mentions.rows.each { |mention| row(mention) }
          end

          def side_cards
            SettingsCard(settings: @settings, filter: @filter)
            PostsCard(posts: @posts)
          end

          def sub
            [
              t(".pending_count", count: count(PENDING)),
              t(".shown_count", count: count(APPROVED)),
            ].join(SEPARATOR)
          end
        end
      end
    end
  end
end
