# frozen_string_literal: true

module Public
  module UI
    module Components
      class BoardFilter < Component
        prop :project, Blog::Types::Instance(ROM::Struct)
        prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :filter, Blog::Types::Hash
        prop :shown, Blog::Types::Integer

        def view_template
          TaskFilter(
            action: path(:project, slug: @project.slug), name: @project.name, shown: @shown, tags: @tags, columns:,
            **@filter,
          )
        end

        private

        def columns = Blog::Types::TaskColumn.values.to_h { [it, t(["ui.views.projects.show.columns", it].join("."))] }
      end
    end
  end
end
