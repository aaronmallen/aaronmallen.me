# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class TaskDialog < Component
          LISTS = Tasks::TaskForm::LISTS.to_h { [it, Helpers::TaskLists.name(it)] }.freeze
          REPLY = /\A(?:(?:re|fwd?):\s*)+/i

          prop :thread, Blog::Types::Instance(ROM::Struct)
          prop :list, Blog::Types::Hash
          prop :trigger, Blog::Types::Bool, default: true

          def view_template
            Button(small: true, icon: "fa-solid fa-square-check", data: { dialog_open: id }) { t(".open") } if @trigger
            Dialog(
              id:, title_id: "#{id}-heading", title: t(".title"), class: "modal", data: { dialog: true },
            ) do |dialog|
              dialog.foot { foot }
              Form(id: form_id, action: path(:admin_make_mail_task, id: @thread.id), class: "form-stack") do
                HiddenFields(values: @list)
                fields
              end
            end
          end

          private

          def fields
            Field(label: t(".task_title"), id: "#{id}-title") do |control|
              Input(**control, name: "task[title]", value: title, required: true, autocomplete: "off")
            end
            Field(label: t(".list")) do
              SegmentedControl(label: t(".list"), name: "task[list]", options: lists, selected: nil)
            end
            Hint { t(".linked") }
            Checkbox(label: t(".archive"), name: "task[archive]", checked: true)
          end

          def foot
            Button(variant: :gh, small: true, data: { dialog_close: true }) { t(".cancel") }
            Button(type: "submit", form: form_id, variant: :pri, small: true) { t(".save") }
          end

          def form_id = "#{id}-form"

          def id = "mail-task-#{@thread.id}"

          def lists = LISTS.transform_values { t(it) }

          def title = @thread.subject.sub(REPLY, "")
        end
      end
    end
  end
end
