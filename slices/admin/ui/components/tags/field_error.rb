# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tags
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::Tags::Contracts::TagContract].freeze
          SCOPE = "tag"
          OVERRIDES = { name: { "format" => "ui.field_error.tags.format" } }.freeze
        end
      end
    end
  end
end
