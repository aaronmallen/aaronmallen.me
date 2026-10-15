# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Drawer < Component
          EDIT = "person-edit"
          NEW = "person-new"

          prop :editor, Blog::Types::Hash.optional, default: nil

          def self.id_for(scope) = "#{scope}-drawer"

          def view_template
            Dialog(id: self.class.id_for(scope), title_id: "#{scope}-title", title:, data: { dialog: true }) do
              Hint { t("ui.components.people.editor.sub") }
              @editor ? PersonForm(**@editor, scope:) : div(data: { person_edit_body: true })
            end
          end

          private

          def scope = @editor ? NEW : EDIT

          def title = t(@editor ? ".new" : ".edit")
        end
      end
    end
  end
end
