# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryRow < Component
          HITS = 3

          prop :file, Blog::Types::Instance(ROM::Struct)
          prop :query, Blog::Types::String.optional

          def view_template
            ListItem(title: @file.path, href: path(:admin_agent_memory_file, id: @file.id), sub:) do |item|
              item.meta { hits.each { |fact| p(class: "memory-hit") { fact.text } } }
            end
          end

          private

          def hits
            return Blog::Constants::EMPTY_ARRAY unless @query

            @file.facts.select { it.text.downcase.include?(@query.downcase) }.first(HITS)
          end

          def sub
            updated = l(Blog::TimeZone.local(@file.updated_at), format: :medium)

            dotted(t(".facts", count: @file.facts.size), t(".updated", at: updated))
          end
        end
      end
    end
  end
end
