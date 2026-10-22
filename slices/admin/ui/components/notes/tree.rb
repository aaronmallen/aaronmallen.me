# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Tree < Component
          LEAD = /\A[#>\-*\d.\s]+/
          SNIPPET = 60
          WIKI_LINK = /\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/

          prop :tree, Blog::Types::Instance(Structs::NoteTree)
          prop :pinned, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :current, Blog::Types::Integer.optional
          prop :folder_id, Blog::Types::Integer.optional, default: nil
          prop :open_folder, Blog::Types::Integer.optional, default: nil
          prop :query, Blog::Types::String, default: Blog::Constants::EMPTY_STRING
          prop :tag, Blog::Types::String.optional, default: nil
          prop :hits, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)), default: Blog::Constants::EMPTY_ARRAY

          def view_template
            aside(class: "nt-side", aria: { label: t(".label") },
                  data: { menu: path(:admin_notes_menu), note_tree: "" }) do
              search
              @query.empty? ? browse : found
              button(type: "button", id: "note-fold-all", hidden: true, data: { note_fold: "shut" })
              button(type: "button", id: "note-open-all", hidden: true, data: { note_fold: "open" })
            end
          end

          private

          def browse
            pins
            files
            new_folder
            div(class: "nt-tree") { Branch(folder: @tree, current: @current, open_folder: @open_folder) }
          end

          def create
            Form(action: path(:admin_create_note)) do
              HiddenFields(values: { title: @query, folder_id: @folder_id })
              button(type: "submit", class: "nt-r") do
                Icon("fa-solid fa-plus")
                span(class: "nt-t") { t(".create", title: @query) }
              end
            end
          end

          def files
            div(class: "nt-gh") do
              p(class: "nt-g") { t(".files") }
              span(class: "nt-da on") do
                NewNote(label: t(".new_note"))
                NewFolder(label: t(".new_folder"), id: "note-new-folder")
              end
            end
          end

          def found
            p(class: "nt-g") { @tag ? t(".tagged", count: @hits.size, tag: @tag) : t(".matches", count: @hits.size) }
            @hits.each { hit(it) }
            create if @hits.empty? && !@tag
          end

          def hit(note)
            on = note.id == @current

            a(
              class: ["nt-r", "nt-hit", ("on" if on)], href: path(:admin_note, id: note.id, q: @query),
              aria: { current: ("page" if on) }, data: { menu: path(:admin_note_menu, id: note.id) },
            ) do
              span(class: "nt-t") { note.title }
              span(class: "nt-p") { where(note) }
            end
          end

          def new_folder
            form = { class: "nt-nd", hidden: true, data: { note_folder_form: "" } }

            Form(action: path(:admin_create_note_folder), **form) do
              Icon("fa-solid fa-folder-plus")
              input(
                type: "text", name: "path", autocomplete: "off", aria: { label: t(".folder_path") },
                placeholder: t(".folder_placeholder"),
              )
            end
          end

          def pins
            return if @pinned.empty?

            p(class: "nt-g") { t(".pinned") }
            @pinned.each { Row(note: it, current: @current, icon: "fa-solid fa-thumbtack") }
          end

          def search
            action = @current ? path(:admin_note, id: @current) : path(:admin_notes)

            AutoForm(action:, role: "search", class: "nt-sr") do
              Icon("fa-solid fa-magnifying-glass")
              input(
                type: "search", name: "q", value: @query, autocomplete: "off", aria: { label: t(".search") },
                placeholder: t(".search_placeholder"),
              )
            end
          end

          def snippet(note)
            folded = @query.downcase
            return if @tag || note.title.downcase.include?(folded)

            line = note.body.lines.find { it.downcase.include?(folded) }
            unmarked(line)[0, SNIPPET] if line
          end

          def unmarked(line)
            linked = line.gsub(WIKI_LINK) { (::Regexp.last_match(2) || ::Regexp.last_match(1)).strip }

            linked.sub(LEAD, "").delete("*_`").strip
          end

          def where(note)
            folder = @tree.path_of(note.folder_id)
            folder = "/" if folder.empty?
            [folder, snippet(note)].compact.join(" · ")
          end
        end
      end
    end
  end
end
