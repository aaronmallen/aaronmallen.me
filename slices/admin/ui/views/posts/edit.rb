# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Posts
        class Edit < View
          include Components::Posts

          def initialize(records:, **editor)
            super()
            @editor = editor
            @records = records
          end

          def view_template
            content_for(:title, @editor[:post].title)

            Editor(**@editor)
            linked
          end

          private

          def linked
            id = @editor[:post].id

            RecordLinks::Section(
              records: @records, kind: "post", id:, find_path: path(:admin_edit_post, id:),
            )
          end
        end
      end
    end
  end
end
