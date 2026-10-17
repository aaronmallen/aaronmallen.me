# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class FieldError < Blog::UI::FieldError
          LIMITS = { subject: { max: Blog::Constants::MAIL_SUBJECT_MAX } }.freeze
          SCOPE = "mail"
        end
      end
    end
  end
end
