# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class FieldError < Blog::UI::FieldError
          SCOPE = "connection"
          MESSAGES = {
            access_token: { "blank" => ".token_blank" },
            api_key: { "blank" => ".blank" },
            app_password: { "blank" => ".app_password_blank" },
            handle: { "blank" => ".handle_blank" },
          }.freeze
        end
      end
    end
  end
end
