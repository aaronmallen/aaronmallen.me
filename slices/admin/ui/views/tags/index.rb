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

          def initialize(editing:, errors:, name:, query:, scope:, tags:, usage:)
            super()
            @editing = editing
            @errors = errors
            @name = name
            @query = query
            @scope = scope
            @tags = tags
            @usage = usage
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(COUNTS.fetch(@scope), count: @tags.size)) do
              switch
              filter_form
            end
            card
            Hint { t(".note") }
          end

          private

          def card
            Card(label: t(LABELS.fetch(@scope)), title: t(TITLES.fetch(@scope))) do |card|
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

          def rows
            return empty if @tags.empty?

            @tags.each { Row(tag: it, uses: @usage.fetch(it.id, Dry::Core::Constants::EMPTY_HASH), editing: @editing) }
          end

          def scope_link(scope)
            current = scope == @scope

            a(class: ["seg-option", ("current" if current)], href: scope_path(scope),
              aria: { current: ("page" if current) }) { t(SCOPES.fetch(scope)) }
          end

          def scope_path(scope) = @query.empty? ? path(:admin_tags, scope:) : path(:admin_tags, scope:, q: @query)

          def switch
            nav(class: "seg", aria: { label: t(".scope") }) { SCOPES.each_key { scope_link(it) } }
          end
        end
      end
    end
  end
end
