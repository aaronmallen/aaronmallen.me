# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TaskRules
        class FieldError < Blog::UI::FieldError
          SCOPE = "rule"
          MESSAGES = {
            pattern: { "blank" => ".pattern.blank", "format" => ".pattern.format", "taken" => ".pattern.taken" },
            projects: { "format" => ".projects.format", "missing" => ".projects.missing" },
            tags: { "blank" => ".tags.blank", "format" => ".tags.format" },
          }.freeze
        end
      end
    end
  end
end
