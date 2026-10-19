# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryFieldError < Blog::UI::FieldError
          CONTRACTS = [
            ::Agents::Contracts::MemoryFactContract, ::Agents::Contracts::MemoryFileContract,
            ::Agents::Contracts::MemoryScopeContract,
          ].freeze
          SCOPE = "memory"
          UNSHOWN = %i[agent model session_id repo project_id task_id].freeze
        end
      end
    end
  end
end
