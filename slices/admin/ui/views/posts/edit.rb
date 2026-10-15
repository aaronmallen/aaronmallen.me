# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Posts
        class Edit < View
          include Components::Posts

          LIVE_TABLES = %w[
            post_link_checks post_tags posts record_links service_connections suggestions webmention_settings
          ].freeze

          prop :records, Blog::Types::Hash
          prop :editor, Blog::Types::Hash, :**

          def view_template
            content_for(:live_tables, LIVE_TABLES)
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
