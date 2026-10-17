# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class FieldError < Blog::UI::FieldError
          ADDRESSES = { "format" => ".to.format" }.freeze
          CONTRACTS = [::Mail::Contracts::SendContract].freeze
          LIMITS = { subject: { max: Blog::Constants::MAIL_SUBJECT_MAX } }.freeze
          OVERRIDES = { bcc: ADDRESSES, cc: ADDRESSES }.freeze
          SCOPE = "mail"
          UNSHOWN = %i[thread].freeze
        end
      end
    end
  end
end
