# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TaskRules
        class FieldError < Blog::UI::FieldError
          SCOPE = "rule"
        end
      end
    end
  end
end
