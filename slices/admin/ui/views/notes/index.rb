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
          prop :folder, Blog::Types::Instance(Structs::NoteTree).optional, default: nil
          prop :filed, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)), default: Blog::Constants::EMPTY_ARRAY
          prop :written, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)
          prop :recent, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)), default: Blog::Constants::EMPTY_ARRAY
          prop :query, Blog::Types::String, default: Blog::Constants::EMPTY_STRING
          prop :tag, Blog::Types::String.optional, default: nil
          prop :hits, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)), default: Blog::Constants::EMPTY_ARRAY
          prop :backlink_counts, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :unwritten, Blog::Types::Array.of(Blog::Types::Hash), default: Blog::Constants::EMPTY_ARRAY
          prop :backlinks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)), default: Blog::Constants::EMPTY_ARRAY
          prop :links_out, Blog::Types::Array.of(Blog::Types::Hash), default: Blog::Constants::EMPTY_ARRAY
          prop :editing, Blog::Types::Bool, default: false
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :values, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            title = @note&.title || @folder&.name
            content_for(:title, title) if title
            PageHead(title: t(".heading"), sub:, sub_icon: "fa-solid fa-lock") { new_note }

            div(class: ["nt", ("open" if title)]) do
              side
              main_pane
            end
          end

          private

          def main_pane
            return page if @note
            return Folder(folder: @folder, tree: @tree, notes: @filed, backlink_counts: @backlink_counts) if @folder

            Home(notes: @recent, tree: @tree, backlink_counts: @backlink_counts, unwritten: @unwritten)
          end

          def new_note
            Form(action: path(:admin_create_note)) do
              HiddenFields(values: { folder_id: @note&.folder_id })
              Button(type: "submit", variant: :pri, icon: :add) { t(".new_note") }
            end
          end

          def page
            Page(
              note: @note, tree: @tree, editing: @editing, errors: @errors, values: @values, written: @written,
              backlinks: @backlinks, links_out: @links_out,
            )
          end

          def side
            Tree(
              tree: @tree, pinned: @pinned, current: @note&.id, folder_id: @note ? @note.folder_id : @folder&.id,
              query: @query, tag: @tag, hits: @hits, open_folder: @folder&.id,
            )
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
