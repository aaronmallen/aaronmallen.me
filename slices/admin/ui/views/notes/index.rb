# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Notes
        class Index < View
          include Components::Notes

          LIVE_TABLES = %w[note_folders note_tags notes].freeze

          prop :tree, Blog::Types::Instance(Structs::NoteTree)
          prop :pinned, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :note, Blog::Types::Instance(ROM::Struct).optional
          prop :recent, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :editing, Blog::Types::Bool, default: false
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :values, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            content_for(:title, @note.title) if @note
            PageHead(title: t(".heading"), sub:, sub_icon: "fa-solid fa-lock") { new_note }

            div(class: ["nt", ("open" if @note)]) do
              Tree(tree: @tree, pinned: @pinned, current: @note&.id)
              @note ? page : Home(notes: @recent, tree: @tree)
            end
          end

          private

          def new_note
            Form(action: path(:admin_create_note)) do
              HiddenFields(values: { folder_id: @note&.folder_id })
              Button(type: "submit", variant: :pri, icon: :add) { t(".new_note") }
            end
          end

          def page
            Page(note: @note, tree: @tree, editing: @editing, errors: @errors, values: @values)
          end

          def sub
            folders = @tree.all.size

            counts = t(".counts", notes: t(".notes", count: @tree.count), folders: t(".folders", count: folders))

            dotted(t(".private"), t(".never_public"), counts)
          end
        end
      end
    end
  end
end
