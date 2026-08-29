# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class FieldError < Blog::UI::FieldError
          SCOPE = "journal"
          MESSAGES = {
            body: { "blank" => ".body.blank" },
            entry_date: { "format" => ".entry_date.format", "future" => ".entry_date.future" },
            tags: { "format" => ".tags.format" },
          }.freeze

          def self.field_slug(field) = super.tr("_", "-")
        end
      end
    end
  end
end
