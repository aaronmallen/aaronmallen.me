# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Search
        class Index < View
          ALL = ""
          KIND_ID = "search-kind"
          KIND_KEYS = Blog::Types::SearchKind.values.to_h { [it, ".kind.#{it}"] }.freeze
          KINDS_KEYS = Blog::Types::SearchKind.values.to_h { [it, ".kinds.#{it}"] }.freeze
          QUERY_ID = "search-q"

          def initialize(kind:, query:, results:)
            super()
            @kind = kind
            @query = query
            @results = results
          end

          def view_template
            PageHead(title: t(".heading"), sub: (t(".sub", query: @query) unless @query.empty?)) { filter_form }

            Card(title: t(".results"), data: { key_list: true }) { rows }
            Pager(page: @results, route: :admin_search, params: { q: @query, kind: @kind }.compact)
          end

          private

          def empty = Empty { @query.empty? ? t(".empty") : t(".no_match", query: @query) }

          def filter_form
            AutoForm(action: path(:admin_search), role: "search", class: "search-filters") do
              label(class: "sr-only", for: QUERY_ID) { t(".query") }
              Input(type: "search", id: QUERY_ID, name: "q", value: @query, placeholder: t(".placeholder"))
              label(class: "sr-only", for: KIND_ID) { t(".filter") }
              Select(id: KIND_ID, name: "kind", options: kind_options, selected: @kind || ALL)
            end
          end

          def kind_options = { ALL => t(".all"), **KINDS_KEYS.transform_values { t(it) } }

          def row(result)
            hit = result.hit

            ListItem(title: hit.title, href: result.href, sub: hit.match) do
              span { t(KIND_KEYS.fetch(hit.kind)) }
              span { l(hit.day, format: :medium) }
            end
          end

          def rows
            return empty if @results.rows.empty?

            @results.rows.each { row(it) }
          end
        end
      end
    end
  end
end
