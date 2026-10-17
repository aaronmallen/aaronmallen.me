# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class FieldError < Blog::UI::FieldError
          CONTRACTS = Blog::Constants::EMPTY_ARRAY
          SCOPE = "connection"
        end
      end
    end
  end
end
