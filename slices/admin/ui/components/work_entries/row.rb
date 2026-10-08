# frozen_string_literal: true

module Admin
  module UI
    module Components
      module WorkEntries
        class Row < Component
          WORK = Blog::Types::ProjectFilter["work"]

          prop :entry, Blog::Types::Instance(ROM::Struct)
          prop :linking, Blog::Types::Bool, default: false

          def view_template
            div(class: "work-row", data: { key_row: true }) do
              div(class: "work-row-body") { body }
              div(class: "work-row-acts hov") do
                links
                remove
              end
            end
          end

          private

          def body
            p(class: "work-row-title") { @entry.role }
            p(class: "work-row-meta") { sub }
            p(class: "work-row-blurb") { @entry.blurb } if written?(@entry.blurb)
          end

          def confirm = t(".confirm_remove", org: @entry.org, role: @entry.role)

          def links
            Button(
              href: path(:admin_projects, filter: WORK, edit: @entry.id), small: true, icon: "fa-solid fa-link",
              title: t(".links"), aria: { current: @linking && "true" },
            ) { span(class: "sr-only") { t(".links") } }
          end

          def remove
            Form(action: remove_path, data: { confirm: }) do
              Button(type: "submit", variant: :warn, small: true, title: t(".remove"), icon: "fa-solid fa-trash-can") do
                span(class: "sr-only") { t(".remove") }
              end
            end
          end

          def remove_path = path(:admin_delete_work_entry, id: @entry.id)

          def sub = t(".sub", from: @entry.from_year, org: @entry.org, to:)

          def to = @entry.current? ? t(".current") : @entry.to_year
        end
      end
    end
  end
end
