# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Search
        class Index < View
          KINDS_KEYS = Blog::Types::SearchKind.values.to_h { [it, ".kinds.#{it}"] }.freeze
          QUERY_ID = "search-q"

          prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)
          prop :kind, Blog::Types::SearchKind.optional
          prop :query, Blog::Types::String
          prop :results, Blog::Types::Instance(Blog::Structs::Paged)

          def view_template
            PageHead(title: t(".heading"), sub:)

            search_form
            kinds unless @query.empty?
            groups
            Pager(page: @results, route: :admin_search, params: { q: @query, kind: @kind }.compact)
          end

          private

          def empty = Empty { @query.empty? ? t(".empty") : t(".no_match", query: @query) }

          def group(kind, results)
            Card(title: t(KINDS_KEYS.fetch(kind))) do |card|
              card.side { span(class: "meta") { results.size.to_s } }
              results.each { row(it) }
            end
          end

          def groups
            return empty if @results.rows.empty?

            div(class: "cols", data: { key_list: true }) do
              @results.rows.group_by { it.hit.kind }.each { |kind, results| group(kind, results) }
            end
          end

          def kind_link(kind, text, count)
            a(
              class: "search-kind", href: path(:admin_search, **{ q: @query, kind: }.compact),
              aria: { current: ("page" if kind == @kind) },
            ) do
              plain text
              whitespace
              span { count.to_s }
            end
          end

          def kinds
            nav(class: "search-kinds", aria: { label: t(".filter") }) do
              kind_link(nil, t(".all"), total)
              KINDS_KEYS.each { |kind, key| kind_link(kind, t(key), @counts[kind]) if @counts[kind] }
            end
          end

          def row(result)
            hit = result.hit

            ListItem(title: hit.title, href: result.href, sub: hit.match) do
              span { l(hit.day, format: :medium) }
            end
          end

          def search_form
            AutoForm(action: path(:admin_search), role: "search", class: "search-box") do
              SearchField(id: QUERY_ID, label: t(".query"), name: "q", value: @query, placeholder: t(".placeholder"))
              input(type: "hidden", name: "kind", value: @kind) if @kind
            end
          end

          def sub
            return if @query.empty?

            t(".sub", count: total, formatted: Blog::Helpers::Figures.count(total), query: @query)
          end

          def total = @counts.values.sum
        end
      end
    end
  end
end
