# frozen_string_literal: true

module Admin
  module UI
    module Components
      module WorkEntries
        class FieldError < Blog::UI::FieldError
          SCOPE = "work-entry"
          MESSAGES = {
            from_year: { "blank" => ".from_year.blank", "format" => ".from_year.format" },
            org: { "blank" => ".org.blank" },
            role: { "blank" => ".role.blank" },
            to_year: { "before_from" => ".to_year.before_from", "format" => ".to_year.format" },
          }.freeze
        end
      end
    end
  end
end
