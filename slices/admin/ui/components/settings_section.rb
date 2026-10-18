# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SettingsSection < Component
        prop :id, Blog::Types::String
        prop :title, Blog::Types::String

        def view_template(&)
          heading = "#{@id}-heading"

          section(id: @id, class: "settings-section", aria: { labelledby: heading }) do
            h2(id: heading, class: "settings-section-heading") { @title }
            yield
          end
        end
      end
    end
  end
end
