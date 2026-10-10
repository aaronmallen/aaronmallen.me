# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tokens
        class FieldError < Blog::UI::FieldError
          SCOPE = "token"
          MESSAGES = {
            expires_on: { "format" => ".expires_on.format", "past" => ".expires_on.past" },
            name: { "blank" => ".name.blank", "control" => ".name.control", "long" => ".name.long" },
            scopes: { "blank" => ".scopes.blank" },
          }.freeze
        end
      end
    end
  end
end
