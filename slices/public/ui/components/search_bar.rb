# frozen_string_literal: true

module Public
  module UI
    module Components
      class SearchBar < Component
        KINDS = Blog::Types::PublicSearchKind.values

        prop :query, Blog::Types::String
        prop :kind, Blog::Types::String.optional
        prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)

        def view_template
          div(class: "sq-bar") do
            status
            nav(class: "sq-k", aria: { label: t(".label") }) do
              kind_link(nil, total)
              KINDS.each { kind_link(it, @counts.fetch(it, 0)) }
            end
          end
        end

        private

        def kind_link(kind, count)
          href = path(:search, q: @query, **{ kind: }.compact)

          a(href:, aria: { current: ("page" if kind == @kind) }) do
            plain t([".kinds", kind || "all"].join("."))
            whitespace
            span { count.to_s }
          end
        end

        def status
          p(class: "sq-c", role: "status") do
            b { t(".results", count: total) }
            plain t(".for", query: @query)
            span(class: "sr-only") { t(".summary", kinds: KINDS.map { summary(it) }.join(", ")) }
          end
        end

        def summary(kind) = t([".summaries", kind].join("."), count: @counts.fetch(kind, 0))

        def total = @counts.values.sum
      end
    end
  end
end
