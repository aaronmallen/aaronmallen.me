# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tokens
        class FieldError < Blog::UI::FieldError
          SCOPE = "token"
          MESSAGES = {
            name: { "blank" => ".name.blank", "control" => ".name.control", "long" => ".name.long" },
          }.freeze
        end
      end
    end
  end
end
