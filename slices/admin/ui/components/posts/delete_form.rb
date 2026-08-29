# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class DeleteForm < Component
          ID = "post-delete"

          prop :post, Blog::Types::Instance(ROM::Struct)
          prop :received, Blog::Types::Integer

          def view_template
            Form(id: ID, action: path(:admin_delete_post, id: @post.id), data: { confirm: })
          end

          private

          def confirm
            return t(".confirm") if @received.zero?

            t(".confirm_webmentions", count: @received)
          end
        end
      end
    end
  end
end
