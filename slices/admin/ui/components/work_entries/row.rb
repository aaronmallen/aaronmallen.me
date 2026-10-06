# frozen_string_literal: true

module Admin
  module UI
    module Components
      module WorkEntries
        class Row < Component
          WRITING = /\S/

          WORK = Blog::Types::ProjectFilter["work"]

          prop :entry, Blog::Types::Instance(ROM::Struct)
          prop :linking, Blog::Types::Bool, default: false

          def view_template
            ListItem(title: @entry.role, sub:) do |item|
              item.body { p(class: "proj-tagline") { @entry.blurb } } if written?(@entry.blurb)
              links
              remove
            end
          end

          private

          def confirm = t(".confirm_remove", org: @entry.org, role: @entry.role)

          def links
            Button(
              href: path(:admin_projects, filter: WORK, edit: @entry.id), small: true, icon: "fa-solid fa-link",
              aria: { current: @linking && "true" },
            ) { t(".links") }
          end

          def remove
            Form(action: remove_path, data: { confirm: }) do
              Button(type: "submit", variant: :warn, small: true, icon: "fa-solid fa-trash-can") { t(".remove") }
            end
          end

          def remove_path = path(:admin_delete_work_entry, id: @entry.id)

          def sub = t(".sub", from: @entry.from_year, org: @entry.org, to:)

          def to = @entry.current? ? t(".current") : @entry.to_year

          def written?(value) = value.to_s.match?(WRITING)
        end
      end
    end
  end
end
