# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class MoveTo < Component
          prop :menu, Blog::Types::Instance(ContextMenu)
          prop :tree, Blog::Types::Instance(Structs::NoteTree)
          prop :current, Blog::Types::String
          prop :action, Blog::Types::String
          prop :skip, Blog::Types::String.optional, default: nil

          def view_template
            @menu.sub(t(".move"), icon: "fa-solid fa-folder-tree") do
              place(t(".top_level"), Blog::Constants::EMPTY_STRING)
              paths.each { place(it, it) }
              @menu.separator
              @menu.field(t(".new_folder"), action: @action, name: "path", pattern: ".*\\S.*", invalid: t(".blank"),
                                            suggest: [])
            end
          end

          private

          def paths
            all = @tree.all.map(&:path)
            @skip ? all.reject { it == @skip || it.start_with?("#{@skip}/") } : all
          end

          def place(label, path) = @menu.check(label, on: path == @current, action: @action, fields: { path: })
        end
      end
    end
  end
end
