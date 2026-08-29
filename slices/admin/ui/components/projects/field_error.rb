# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class FieldError < Blog::UI::FieldError
          SCOPE = "project"
          MESSAGES = {
            name: { "blank" => ".name.blank" },
            og_image_url: { "format" => ".og_image_url.format" },
            repo: { "format" => ".repo.format", "taken" => ".repo.taken" },
            started_on: {
              "after_archived" => ".started_on.after_archived",
              "format" => ".started_on.format",
              "future" => ".started_on.future",
            },
            status: { "format" => ".status.format" },
            tags: { "format" => ".tags.format" },
            url: { "format" => ".url.format" },
          }.freeze
        end
      end
    end
  end
end
