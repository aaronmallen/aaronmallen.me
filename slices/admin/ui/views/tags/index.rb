# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tags
        class Index < View
          include Components::Tags

          PRIVATE = Blog::Types::TagScope["private"]
          PUBLIC = Blog::Types::TagScope["public"]

          COUNTS = { PUBLIC => ".count.public", PRIVATE => ".count.private" }.freeze
          LABELS = { PUBLIC => ".label.public", PRIVATE => ".label.private" }.freeze
          SCOPES = { PUBLIC => ".scopes.public", PRIVATE => ".scopes.private" }.freeze
          TITLES = { PUBLIC => ".title.public", PRIVATE => ".title.private" }.freeze
          SEARCH_ID = "tags-q"

          def initialize(count:, editing:, errors:, name:, query:, scope:, tags:, usage:)
            super()
            @count = count
            @editing = editing
            @errors = errors
            @name = name
            @query = query
            @scope = scope
            @tags = tags
            @usage = usage
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(COUNTS.fetch(@scope), count: @count)) do
              switch
              filter_form
            end
            card
            Pager(page: @tags, route: :admin_tags, params: scope_params(@scope))
            Hint { t(".note") }
          end

          private

          def card
            Card(label: t(LABELS.fetch(@scope)), title: t(TITLES.fetch(@scope)), data: { key_list: true }) do |card|
              card.side { Hint(inline: true) { t(".aside") } }
              Capture(name: @name, errors: @errors, tag_scope: @scope)
              rows
            end
          end

          def empty = Empty { @query.empty? ? t(".empty") : t(".no_match", query: @query) }

          def filter_form
            form(action: path(:admin_tags), method: "get", role: "search", data: { autosubmit: "" }) do
              input(type: "hidden", name: "scope", value: @scope)
              label(class: "sr-only", for: SEARCH_ID) { t(".search") }
              Input(
                type: "search", id: SEARCH_ID, name: "q", value: @query,
                class: "tags-search", placeholder: t(".search_placeholder"),
              )
              noscript { Button(type: "submit", small: true) { t(".apply") } }
            end
          end

          def row(tag)
            Row(tag:, uses: @usage.fetch(tag.id, Blog::Constants::EMPTY_HASH), editing: @editing,
                page: @tags.number)
          end

          def rows
            return empty if @tags.rows.empty?

            @tags.rows.each { row(it) }
          end

          def scope_link(scope)
            current = scope == @scope

            a(class: ["seg-option", ("current" if current)], href: scope_path(scope),
              aria: { current: ("page" if current) }) { t(SCOPES.fetch(scope)) }
          end

          def scope_params(scope) = @query.empty? ? { scope: } : { scope:, q: @query }

          def scope_path(scope) = path(:admin_tags, **scope_params(scope))

          def switch
            nav(class: "seg", aria: { label: t(".scope") }) { SCOPES.each_key { scope_link(it) } }
          end
        end
      end
    end
  end
end
