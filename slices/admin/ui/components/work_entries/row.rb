# frozen_string_literal: true

module Admin
  module UI
    module Components
      module WorkEntries
        class Row < Component
          WRITING = /\S/

          prop :entry, Blog::Types::Instance(ROM::Struct)

          def view_template
            div(class: "li", data: { key_row: true }) do
              div(class: "li-main") do
                span(class: "li-title") { @entry.role }
                p(class: "li-sub") { sub }
                p(class: "proj-tagline") { @entry.blurb } if written?(@entry.blurb)
              end
              div(class: "li-side") { remove }
            end
          end

          private

          def confirm = t(".confirm_remove", org: @entry.org, role: @entry.role)

          def remove
            render Blog::UI::Components::Form.new(action: remove_path, data: { confirm: }) do
              Button(type: "submit", variant: :warn, small: true) do
                i(class: "fa-solid fa-trash-can", aria: { hidden: "true" })
                span { t(".remove") }
              end
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
