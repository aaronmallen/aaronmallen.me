# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class FilterBar < Component
          COLUMNS = Blog::Types::TaskColumn.values
          NAMES = BoardCard::NAMES

          prop :project, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::Hash
          prop :shown, Blog::Types::Integer
          prop :tagging, Blog::Types::Hash

          def view_template
            TaskFilter(
              action: path(:admin_project, id: @project.id), name: @project.name, shown: @shown, tags: @tagging[:tags],
              columns:, form: { data: AutoForm::HOOK }, **@filter,
            ) { TagManager(project: @project, **@tagging) }
          end

          private

          def columns = COLUMNS.to_h { [it, t(NAMES.fetch(it))] }
        end
      end
    end
  end
end
