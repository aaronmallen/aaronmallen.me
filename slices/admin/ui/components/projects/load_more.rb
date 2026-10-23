# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class LoadMore < Component
          prop :project_id, Blog::Types::Integer
          prop :board, Blog::Types::Instance(Blog::BoardSizes)
          prop :column, Blog::Types::TaskColumn
          prop :count, Blog::Types::Integer
          prop :shown, Blog::Types::Integer
          prop :query, Blog::Types::Hash

          def view_template
            left = @board.left(@count, @shown)
            return unless left.positive?

            AutoForm(action: path(:admin_project, id: @project_id)) do
              HiddenFields(values: { **@board.more(@column), **@query })
              Button(type: "submit", variant: :gh, small: true) { t("ui.board.load_more", count: left) }
            end
          end
        end
      end
    end
  end
end
