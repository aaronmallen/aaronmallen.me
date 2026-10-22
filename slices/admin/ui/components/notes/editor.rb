# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Editor < Component
          prop :note, Blog::Types::Instance(ROM::Struct)
          prop :errors, Blog::Types::Hash
          prop :values, Blog::Types::Hash

          def view_template
            Form(action: path(:admin_update_note, id: @note.id), class: "nt-edit", data:) do
              held
              title
              Tags(note: @note, editing: true)
              refusals
              body
              foot
            end
          end

          private

          def body
            textarea(
              class: "nt-ta", name: "note[body]", aria: { label: t(".body") }, placeholder: t(".placeholder"),
              autofocus: !fresh?,
            ) { value(:body) }
          end

          def data
            { note_editor: "", live_keep: "", taken: t(".taken", title: "{title}"), changed: t(".changed"),
              failed: t(".failed"), saved: t(".saved", time: "{time}") }
          end

          def foot
            p(class: "nt-tip") { t(".tip") }
            div(class: "nt-save", data: { note_save: "" }) do
              Button(type: "submit", variant: :pri, small: true) do
                t(".save")
              end
            end
          end

          def fresh? = @note.title.start_with?(::Notes::Operations::CreateNote::UNTITLED) && @note.body.empty?

          def held
            input(type: "hidden", name: "note[version]", value: @note.version, data: { note_version: "" })
            input(type: "hidden", name: "note[tags]", value: tags, data: { note_tag_list: "" })
          end

          def refusals
            p(class: "nt-bad", hidden: !@errors.key?(:title), data: { note_title_error: "" }) do
              t(".taken", title: value(:title)) if @errors.key?(:title)
            end
            p(class: "nt-bad", hidden: !@errors.key?(:version), data: { note_refused: "" }) do
              t(".changed") if @errors.key?(:version)
            end
          end

          def tags = @note.tags.map(&:name).join(", ")

          def title
            input(
              class: "nt-ttl", type: "text", name: "note[title]", value: value(:title), aria: { label: t(".title") },
              autocomplete: "off", autofocus: fresh?, data: { note_title: @note.title },
            )
          end

          def value(field) = @values.fetch(field) { @note.public_send(field) }.to_s
        end
      end
    end
  end
end
