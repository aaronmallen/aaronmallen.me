# frozen_string_literal: true

module Admin
  module UI
    module Components
      module WorkEntries
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::Projects::Contracts::WorkEntryContract].freeze
          SCOPE = "work-entry"
        end
      end
    end
  end
end
