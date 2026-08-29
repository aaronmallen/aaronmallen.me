# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class StatusForm < Component
          ID = "project-status-change"

          prop :project, Blog::Types::Instance(ROM::Struct)

          def view_template
            Form(id: ID, action: path(route, id: @project.id)) do
              input(type: "hidden", name: "filter", value: filter)
            end
          end

          private

          def archived? = @project.archived?

          def filter = archived? ? Blog::Types::ProjectFilter["live"] : Blog::Types::ProjectFilter["archived"]

          def route = archived? ? :admin_restore_project : :admin_archive_project
        end
      end
    end
  end
end
