# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tokens
        class FieldError < Blog::UI::FieldError
          SCOPE = "token"
        end
      end
    end
  end
end
