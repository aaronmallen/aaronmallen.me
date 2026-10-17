# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tokens
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::API::Contracts::TokenContract].freeze
          LIMITS = { name: { max: ::API::Contracts::TokenContract::MAX_NAME } }.freeze
          SCOPE = "token"
        end
      end
    end
  end
end
