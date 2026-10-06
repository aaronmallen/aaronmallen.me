# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Posts
        class Edit < View
          include Components::Posts

          prop :records, Blog::Types::Hash
          prop :editor, Blog::Types::Hash, :**

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
