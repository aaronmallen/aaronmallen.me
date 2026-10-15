# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Projects
        class Edit < View
          include Components::Projects

          LIVE_TABLES = %w[project_tags projects record_links].freeze

          prop :records, Blog::Types::Hash
          prop :editor, Blog::Types::Hash, :**

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            content_for(:title, @editor[:project].name)

            Editor(**@editor) { linked }
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
