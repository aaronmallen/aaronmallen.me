# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class SessionSearch < Component
          FILTERS = {
            repo: "fa-brands fa-github", project_id: "fa-solid fa-cube", task_id: "fa-solid fa-list-check",
            scope: "fa-solid fa-layer-group",
          }.freeze
          LABELS = FILTERS.to_h { |key, _| [key, ".filters.#{key}"] }.freeze

          prop :search, Blog::Types::Instance(ROM::Struct)

          def view_template
            hits = @search.agent_session_search_hits

            div(class: "agent-search") do
              head(hits.size)
              next Hint { t(".none") } if hits.empty?

              ul(class: "record-link-list") { hits.each { |found| li(class: "record-link-row") { hit(found) } } }
            end
          end

          private

          def filters
            set = FILTERS.select { |key, _| @search[key] }
            return span { t(".no_filters") } if set.empty?

            set.each { |key, icon| Pill(icon:) { t(LABELS.fetch(key), value: @search[key]) } }
          end

          def head(count)
            div(class: "agent-search-head") do
              span { l(Blog::TimeZone.local(@search.searched_at), format: :clock) }
              span(class: "agent-search-query") { t(".query", query: @search.query) }
              filters
              span(class: "agent-search-count") { t(".facts", count:) }
            end
          end

          def hit(found)
            id = found.memory_file_id

            tag(id ? :a : :span, class: "agent-change", href: (path(:admin_memory_file, id:) if id)) do
              span(class: "agent-change-text") do
                AgentMark(model: found.model) if found.agent
                plain found.text
              end
              span(class: "meta") { dotted(id ? found.path : t(".deleted"), (t(".removed") if found.removed_at)) }
            end
          end
        end
      end
    end
  end
end
