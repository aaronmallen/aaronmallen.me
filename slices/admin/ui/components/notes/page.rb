# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Page < Component
          prop :note, Blog::Types::Instance(ROM::Struct)
          prop :tree, Blog::Types::Instance(Structs::NoteTree)
          prop :editing, Blog::Types::Bool
          prop :errors, Blog::Types::Hash
          prop :values, Blog::Types::Hash
          prop :written, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)
          prop :backlinks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :links_out, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            div(class: "nt-doc") do
              section(class: "nt-page") do
                bar
                @editing ? Editor(note: @note, errors: @errors, values: @values) : read
              end
              aside(class: "nt-meta") { meta }
            end
          end

          private

          def bar
            div(class: "nt-bar") do
              Button(
                href: path(:admin_notes), variant: :gh, small: true, icon: "fa-solid fa-arrow-left", class: "nt-back",
              ) { t(".files") }
              crumbs
              span(class: "nt-sp")
              span(class: "nt-st", data: { note_status: "" }) { status }
              pin
              toggle
            end
          end

          def blank
            p(class: "nt-blank") do
              plain t(".empty")
              whitespace
              a(href: path(:admin_note, id: @note.id, edit: 1)) { t(".start") }
            end
          end

          def body
            div(class: "nt-prose") { @note.body.strip.empty? ? blank : Prose(source: @note.body, written: @written) }
          end

          def crumbs
            parts = folder_path.split("/")

            span(class: "nt-crumb") do
              if parts.empty?
                span { "/" }
              else
                parts.each { |part| span { "#{part} /" } }
              end
              span(class: "nt-cur") { @note.title }
            end
          end

          def delete
            ButtonForm(
              action: path(:admin_delete_note, id: @note.id), label: t(".delete"), variant: :gh, icon: :trash,
              confirm: t(".confirm_delete", title: @note.title, count: @backlinks.size),
            )
          end

          def folder_field
            AutoForm(method: "post", action: path(:admin_move_note, id: @note.id), data: { morph: true }) do
              Field(label: t(".folder"), id: "note-folder") do |control|
                Input(**control, name: "path", value: folder_path, list: "note-folders", placeholder: t(".top_level"))
              end
              datalist(id: "note-folders") { @tree.all.each { option(value: it.path) } }
            end
          end

          def folder_path = @tree.path_of(@note.folder_id)

          def meta
            div(class: "nt-facts") do
              folder_field
              p(class: "nt-mt") do
                span { t(".created", date: l(Blog::TimeZone.local(@note.created_at).to_date, format: :short)) }
                span { t(".words", count: Blog::Helpers::Figures.words(@note.body)) }
                span { IconLabel(icon: "fa-solid fa-lock") { t(".private") } }
              end
            end
            Links(note: @note, backlinks: @backlinks, links_out: @links_out)
            div { delete }
          end

          def pin
            label = @note.pinned ? t(".unpin") : t(".pin")

            Form(action: path(:admin_pin_note, id: @note.id), data: { morph: true }) do
              HiddenFields(values: { pinned: (Blog::Constants::CHECKED unless @note.pinned) })
              Button(
                type: "submit", small: true, icon: "fa-solid fa-thumbtack", label:, class: ("on" if @note.pinned),
                aria: { pressed: @note.pinned.to_s },
              )
            end
          end

          def read
            h1(class: "nt-h") { @note.title }
            Tags(note: @note)
            body
          end

          def status
            return plain(t(".autosaves")) if @editing

            plain t(".edited")
            whitespace
            Edited(at: @note.updated_at)
          end

          def toggle
            if @editing
              Button(href: path(:admin_note, id: @note.id), variant: :pri, small: true, icon: "fa-solid fa-check") do
                t(".done")
              end
            else
              Button(href: path(:admin_note, id: @note.id, edit: 1), small: true, icon: :edit) { t(".edit") }
            end
          end
        end
      end
    end
  end
end
