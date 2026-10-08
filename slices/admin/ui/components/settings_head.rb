# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SettingsHead < Component
        prop :title, Blog::Types::String

        def view_template(&)
          content_for(:title, @title)
          PageHead(title: t(".heading"), sub: t(".lede"), &)
        end
      end
    end
  end
end
