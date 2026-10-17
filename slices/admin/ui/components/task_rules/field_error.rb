# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TaskRules
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::Tasks::Contracts::TaskRuleContract].freeze
          SCOPE = "rule"
        end
      end
    end
  end
end
