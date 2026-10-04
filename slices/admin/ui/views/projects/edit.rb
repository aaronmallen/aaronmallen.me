# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Projects
        class Edit < View
          include Components::Projects

          def initialize(records:, **editor)
            super()
            @editor = editor
            @records = records
          end

          def view_template
            content_for(:title, @editor[:project].name)

            Editor(**@editor)
            linked
          end

          private

          def linked
            id = @editor[:project].id

            RecordLinks::Section(
              records: @records, scope: "project-#{id}-record", id:, unlink_route: :admin_unlink_project_record,
              link_path: path(:admin_link_project_record, id:), find_path: path(:admin_edit_project, id:),
            )
          end
        end
      end
    end
  end
end
