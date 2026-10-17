# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class EditForm < Component
          HEIGHT = "200px"
          TEMPLATE = "journal-edit-template"

          prop :place, Blog::Types::Hash
          prop :action, Blog::Types::String, default: Blog::Constants::EMPTY_STRING
          prop :body, Blog::Types::String, default: Blog::Constants::EMPTY_STRING
          prop :tags, Blog::Types::String, default: Blog::Constants::EMPTY_STRING
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :scope, Blog::Types::String, default: TEMPLATE
          prop :source, Blog::Types::String, default: Blog::Constants::EMPTY_STRING

          def view_template
            Form(action: @action, class: "journal-edit", data: { journal_edit_form: "", journal_source: @source }) do
              HiddenFields(values: @place)
              EntryFields(body: @body, tags: @tags, errors: @errors, scope: @scope, height: HEIGHT, label: t(".body"))
              div(class: "journal-edit-foot") do
                Button(small: true, data: { journal_cancel: "" }) { t(".cancel") }
                SaveButton(body: @body) { t(".save") }
              end
            end
          end
        end
      end
    end
  end
end
