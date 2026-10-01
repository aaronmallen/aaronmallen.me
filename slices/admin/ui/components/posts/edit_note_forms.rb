# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class EditNoteForms < Component
          prop :post_id, Blog::Types::Integer
          prop :edits, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            @edits.each { Form(id: EditNotes.form_id(it.id), action: form_action(it)) }
          end

          private

          def form_action(edit) = path(:admin_update_post_edit, id: @post_id, edit_id: edit.id)
        end
      end
    end
  end
end
