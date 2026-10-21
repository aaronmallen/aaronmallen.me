# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryRow < Component
          HITS = 3
          LINK = { class: "memory-path" }.freeze

          prop :file, Blog::Types::Instance(ROM::Struct)
          prop :event, Blog::Types::Instance(ROM::Struct).optional
          prop :query, Blog::Types::String.optional

          def view_template
            ListItem(title: @file.path, href: path(:admin_memory_file, id: @file.id), link: LINK) do |item|
              item.meta do
                MemoryDescription(file: @file)
                p(class: "li-sub") { sub }
                hits.each { |fact| p(class: "memory-hit") { fact.text } }
              end
            end
          end

          private

          def hits
            return Blog::Constants::EMPTY_ARRAY unless @query

            @file.facts.select { it.text.downcase.include?(@query.downcase) }.first(HITS)
          end

          def sub
            at = l(Blog::TimeZone.local(@event&.created_at || @file.updated_at), format: :medium)
            who = (Helpers::AgentBrand.author(@event) if @event) || t(".you")

            dotted(t(".facts", count: @file.facts.size), t(".updated", at:, who:))
          end
        end
      end
    end
  end
end
