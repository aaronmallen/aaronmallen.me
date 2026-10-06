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
              records: @records, kind: "project", id:, find_path: path(:admin_edit_project, id:),
            )
          end
        end
      end
    end
  end
end
