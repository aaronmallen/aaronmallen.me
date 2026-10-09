# frozen_string_literal: true

module Public
  module UI
    class View < Blog::UI::View
      include Components

      layout Layouts::Application

      private

      def head_wording(**values)
        content_for(:title, t(".title", **values))
        content_for(:description, t(".description", **values))
      end
    end
  end
end
