# frozen_string_literal: true

module Admin
  module UI
    module Components
      module RecordLinks
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::Links::Contracts::RecordLinkContract].freeze
          SCOPE = "record"

          def self.field_slug(field) = super.tr("_", "-")
        end
      end
    end
  end
end
