# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tags
        class Index < View
          include Components::Tags

          LIVE_TABLES = %w[decision_tags journal_entry_tags post_tags project_tags task_rule_tags task_tags].freeze
          PRIVATE = Blog::Types::TagScope["private"]
          PUBLIC = Blog::Types::TagScope["public"]

          COUNTS = { PUBLIC => ".count.public", PRIVATE => ".count.private" }.freeze
          SCOPES = { PUBLIC => ".scopes.public", PRIVATE => ".scopes.private" }.freeze
          TITLES = { PUBLIC => ".title.public", PRIVATE => ".title.private" }.freeze
          SEARCH_ID = "tags-q"

          prop :count, Blog::Types::Integer
          prop :editing, Blog::Types::Hash.optional
          prop :errors, Blog::Types::Hash
          prop :name, Blog::Types::String
          prop :query, Blog::Types::String
          prop :scope, Blog::Types::TagScope
          prop :tags, Blog::Types::Instance(Blog::Structs::Paged)
          prop :usage, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::Hash)

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            SettingsHead(title: t(".heading"))
            div(class: "g-main") do
              div(class: "settings-main") do
                card
                Pager(page: @tags, route: :admin_tags, params: scope_params(@scope))
              end
              side_panel
            end
          end

          private

          def card
            blurb = t(COUNTS.fetch(@scope), count: @count)

            Card(title: t(TITLES.fetch(@scope)), blurb:, data: { key_list: true }) do |card|
              card.side do
                switch
                filter_form
              end
              Capture(name: @name, errors: @errors, tag_scope: @scope)
              rows
            end
          end

          def editor(tag) = Editor(tag:, uses: uses(tag), editing: @editing, page: @tags.number, query: @query)

          def empty = Empty { @query.empty? ? t(".empty") : t(".no_match", query: @query) }

          def filter_form
            AutoForm(action: path(:admin_tags), role: "search") do
              input(type: "hidden", name: "scope", value: @scope)
              SearchField(
                id: SEARCH_ID, label: t(".search"), name: "q", value: @query,
                class: "tags-search", placeholder: t(".search_placeholder"),
              )
            end
          end

          def rows
            return empty if @tags.rows.empty?

            @tags.rows.each { Row(tag: it, uses: uses(it)) }
          end

          def scope_link(scope)
            { href: scope_path(scope), text: t(SCOPES.fetch(scope)), current: scope == @scope }
          end

          def scope_params(scope) = @query.empty? ? { scope: } : { scope:, q: @query }

          def scope_path(scope) = path(:admin_tags, **scope_params(scope))

          def side_panel
            Card(as: :aside, class: "settings-side tag-panel", id: Editor::PANEL_ID) do
              div(class: "tag-panel-intro") do
                p(class: "settings-aside") { t(".aside") }
                Hint { t(".note") }
              end
              @tags.rows.each { editor(it) }
            end
          end

          def switch
            SegmentedLinks(label: t(".scope"), items: SCOPES.keys.map { scope_link(it) })
          end

          def uses(tag) = @usage.fetch(tag.id, Blog::Constants::EMPTY_HASH)
        end
      end
    end
  end
end
