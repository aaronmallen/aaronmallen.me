# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class New < View
          include Components::People

          prop :editor, Blog::Types::Hash, :**

          def view_template = Editor(**@editor)
        end
      end
    end
  end
end
