# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class FolderSettings < Component
          prop :folder, Blog::Types::Instance(Structs::NoteTree)
          prop :tree, Blog::Types::Instance(Structs::NoteTree)

          def view_template
            aside(class: "nt-meta", aria: { label: t(".label") }) do
              Card(title: t(".title"), class: "nt-set") do
                name
                inside
                description
              end
              div { remove }
            end
          end

          private

          def act(route) = path(route, id: @folder.id)

          def description
            setting(:admin_describe_note_folder) do
              Field(label: t(".description"), id: "note-folder-description") do |control|
                placeholder = t(".description_placeholder")
                Textarea(**control, name: "description", value: @folder.description, rows: 3, placeholder:)
              end
            end
          end

          def here = act(:admin_note_folder)

          def inside
            setting(:admin_move_note_folder) do
              Field(label: t(".inside"), id: "note-folder-inside") do |control|
                Input(**control, name: "path", value: parent, list: "note-folder-places", placeholder: t(".top_level"))
              end
              datalist(id: "note-folder-places") { places.each { option(value: it) } }
            end
          end

          def name
            setting(:admin_rename_note_folder) do
              Field(label: t(".name"), id: "note-folder-name") do |control|
                Input(**control, name: "name", value: @folder.name, required: true)
              end
            end
          end

          def parent = @folder.path.rpartition("/").first

          def parent_name = parent.empty? ? t(".the_top_level") : parent

          def places
            @tree.all.map(&:path).reject { it == @folder.path || it.start_with?("#{@folder.path}/") }
          end

          def remove
            confirm = t(".confirm_remove", name: @folder.name, count: @folder.count, place: parent_name)

            ButtonForm(
              action: act(:admin_remove_note_folder), label: t(".remove"), variant: :gh, icon: :trash,
              confirm: (confirm unless @folder.empty?), hidden: { return_to: here },
            )
          end

          def setting(route, &)
            AutoForm(method: "post", action: act(route), data: { morph: true }) do
              HiddenFields(values: { return_to: here })
              yield
            end
          end
        end
      end
    end
  end
end
