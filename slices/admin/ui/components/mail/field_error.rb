# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::Mail::Contracts::SendContract].freeze
          LIMITS = { subject: { max: Blog::Constants::MAIL_SUBJECT_MAX } }.freeze
          SCOPE = "mail"
          UNSHOWN = %i[thread].freeze
        end
      end
    end
  end
end
