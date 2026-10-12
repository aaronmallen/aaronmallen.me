# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class FieldError < Blog::UI::FieldError
          SCOPE = "mail"
        end
      end
    end
  end
end
