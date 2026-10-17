# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::Projects::Contracts::ProjectContract].freeze
          SCOPE = "project"
          OVERRIDES = { og_image_url: URL }.freeze
        end
      end
    end
  end
end
