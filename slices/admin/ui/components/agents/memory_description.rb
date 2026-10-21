# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryDescription < Component
          prop :file, Blog::Types::Instance(ROM::Struct)
          prop :tag, Blog::Types::Symbol.enum(:p, :span), default: :p

          def view_template
            tag(@tag, class: "memory-description") do
              AgentMark(model: @file.description_model) if @file.description_agent
              plain @file.description
            end
          end
        end
      end
    end
  end
end
