# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::Record::Contracts::JournalEditContract, ::Record::Contracts::JournalEntryContract].freeze
          SCOPE = "journal"

          def self.field_slug(field) = super.tr("_", "-")
        end
      end
    end
  end
end
