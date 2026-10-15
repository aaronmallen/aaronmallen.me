# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Edit < View
          include Components::People

          prop :editor, Blog::Types::Hash, :**

          def view_template
            content_for(:live_tables, Blog::Constants::EMPTY_ARRAY)
            Editor(**@editor)
          end
        end
      end
    end
  end
end
