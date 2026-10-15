# frozen_string_literal: true

module Public
  module UI
    module Views
      module Search
        class Index < View
          EMPTY = Blog::Constants::EMPTY_ARRAY
          NONE = Blog::Constants::EMPTY_HASH
          NOINDEX = "noindex"
          PAGED = Blog::Types::Instance(Blog::Structs::Paged)

          prop :query, Blog::Types::String
          prop :kind, Blog::Types::String.optional
          prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer), default: NONE
          prop :groups, Blog::Types::Hash.map(Blog::Types::String, PAGED), default: NONE
          prop :boards, Blog::Types::Array.of(Blog::Types::Integer), default: EMPTY
          prop :failed, Blog::Types::Bool, default: false
          prop :limited, Blog::Types::Bool, default: false
          prop :tags, Blog::Types::Array.of(Blog::Types::Hash), default: EMPTY
          prop :latest, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)), default: EMPTY

          def view_template
            content_for(:title, blank? ? t(".title") : t(".title_for", query: @query))
            content_for(:description, t(".description"))
            content_for(:robots, NOINDEX)

            h1(class: "sr-only") { t(".heading") }
            search_form
            outcome
            SearchWays(tags: @tags, latest: @latest) if !@failed && !@limited && (blank? || nothing?)
          end

          private

          def act(href, icon, key) = a(href:) { IconLabel(icon: ["fa-solid", icon]) { t(key) } }

          def blank? = @query.empty?

          def failure
            div(class: "sq-n err", role: "status") do
              h2 { IconLabel(icon: "fa-solid fa-triangle-exclamation") { t(".failed.heading") } }
              p { t(".failed.lede") }
              div(class: "acts") do
                act(path(:search, q: @query), "fa-rotate-right", ".failed.retry")
                act(path(:writing), "fa-list", ".failed.writing")
                act(path(:projects), "fa-cube", ".failed.projects")
              end
            end
          end

          def group(kind, found)
            count = @counts.fetch(kind, 0)

            section(class: "sq-g", aria: { labelledby: "g-#{kind}" }) do
              group_head(kind, count)
              ol(class: "entries") { found.rows.each { SearchHit(hit: it, board: @boards.include?(it.source_id)) } }
              more(kind, count, found)
            end
          end

          def group_head(kind, count)
            div(class: "sq-gh") do
              h2(class: "kicker", id: "g-#{kind}") do
                plain t([".groups", kind].join("."))
                span { t(".group_count", count:) }
              end
            end
          end

          def more(kind, count, found)
            return Pager(page: found, route: :search, params: { q: @query, kind: }) if @kind
            return if count <= found.rows.size

            a(class: "sec-l sq-more", href: path(:search, q: @query, kind:)) do
              span { t([".more", kind].join("."), count:, query: @query) }
              Icon("fa-solid fa-arrow-right")
            end
          end

          def nothing
            p(class: "sr-only", role: "status") { t(".none.status", query: @query) }
            div(class: "sq-n") do
              h2 { t(".none.heading", query: @query) }
              p { t(".none.lede") }
            end
          end

          def nothing? = @groups.values.all? { it.rows.empty? }

          def outcome
            return if blank?

            div(id: "results") do
              next failure if @failed
              next SearchLimit() if @limited
              next nothing if nothing?

              SearchBar(query: @query, kind: @kind, counts: @counts)
              @groups.each { |kind, found| group(kind, found) }
            end
          end

          def search_form
            form(class: "sq", role: "search", action: path(:search), method: "get") do
              label(class: "kicker", for: "q") { t(".label") }
              div(class: "sq-f") do
                Icon("fa-solid fa-magnifying-glass")
                input(
                  id: "q", name: "q", type: "search", value: @query, autocomplete: "off",
                  placeholder: t(".placeholder"), aria: { describedby: ("sq-h" if blank?) },
                )
                button(class: "sq-b", type: "submit") { t(".submit") }
              end
              p(class: "sq-h", id: "sq-h") { t(".hint") } if blank?
            end
          end
        end
      end
    end
  end
end
