# frozen_string_literal: true

module Admin
  module UI
    class View < Blog::UI::View
      include Components

      layout Layouts::Application
    end
  end
end
