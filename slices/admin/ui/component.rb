# frozen_string_literal: true

module Admin
  module UI
    class Component < Blog::UI::Component
      include Components

      private

      def count(number) = Blog::Helpers::Figures.count(number)
    end
  end
end
