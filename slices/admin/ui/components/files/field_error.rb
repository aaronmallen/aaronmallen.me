# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::Shares::Contracts::ShareContract].freeze
          SCOPE = "share"
        end
      end
    end
  end
end
