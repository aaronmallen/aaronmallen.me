# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class FolderBar < Component
          prop :folder, Blog::Types::Instance(Structs::NoteTree)
          prop :tree, Blog::Types::Instance(Structs::NoteTree)

          def view_template
            div(class: "nt-bar") do
              Button(
                href: path(:admin_notes), variant: :gh, small: true, icon: "fa-solid fa-arrow-left", class: "nt-back",
              ) { t(".files") }
              crumbs
              span(class: "nt-sp")
              new_folder
              Form(action: path(:admin_create_note)) do
                HiddenFields(values: { folder_id: @folder.id })
                Button(type: "submit", variant: :pri, small: true, icon: :add) { t(".new_note") }
              end
            end
          end

          private

          def above = @tree.all.select { @folder.path.start_with?("#{it.path}/") }.sort_by { it.path.size }

          def crumbs
            span(class: "nt-crumb") do
              above.each do |folder|
                span do
                  a(class: "nt-cb", href: path(:admin_note_folder, id: folder.id)) { folder.name }
                  plain " /"
                end
              end
              span(class: "nt-cur") { @folder.name }
            end
          end

          def new_folder
            details(class: "nt-nf") do
              Button(summary: true, small: true, icon: "fa-solid fa-folder-plus") { t(".new_folder") }
              Form(action: path(:admin_create_note_folder)) do
                HiddenFields(values: { prefix: "#{@folder.path}/" })
                input(
                  class: "nt-ti", type: "text", name: "path", autocomplete: "off", required: true,
                  aria: { label: t(".folder_name") }, placeholder: t(".folder_placeholder"),
                )
              end
            end
          end
        end
      end
    end
  end
end
