# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tags
        class Index < View
          include Components::Tags

          SEARCH_ID = "tags-q"

          def initialize(editing:, errors:, name:, query:, tags:, usage:)
            super()
            @editing = editing
            @errors = errors
            @name = name
            @query = query
            @tags = tags
            @usage = usage
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(".count", count: @tags.size)) { filter_form }

            Card(label: t(".label"), title: t(".title")) do |card|
              card.side { Hint(inline: true) { t(".aside") } }
              Capture(name: @name, errors: @errors)
              rows
            end

            Hint { t(".note") }
          end

          private

          def empty = Empty { @query.empty? ? t(".empty") : t(".no_match", query: @query) }

          def filter_form
            form(action: path(:admin_tags), method: "get", role: "search", data: { autosubmit: "" }) do
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
        end
      end
    end
  end
end
