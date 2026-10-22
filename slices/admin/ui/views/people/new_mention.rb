# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class NewMention < View
          include Components::People

          prop :editor, Blog::Types::Hash, :**

          def view_template
            content_for(:live_tables, Blog::Constants::EMPTY_ARRAY)
            PageHead(title: t(".heading"), sub: t(".sub"))
            Card(data: { person_editor: true }) { PersonForm(**@editor) }
          end
        end
      end
    end
  end
end
