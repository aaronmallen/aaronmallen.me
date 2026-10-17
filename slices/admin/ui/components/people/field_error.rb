# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::Social::Contracts::PersonContract].freeze
          SCOPE = "person"
        end
      end
    end
  end
end
