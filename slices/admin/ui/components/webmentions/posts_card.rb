# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Webmentions
        class PostsCard < Component
          prop :posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Card(title: t(".title")) do
              @posts.empty? ? Empty { t(".empty") } : @posts.each { |post| row(post) }
            end
          end

          private

          def row(post)
            ListItem(title: post.title, href: path(:admin_edit_post, id: post.id)) do
              post.webmentions_enabled ? Pill(color: :green) { t(".enabled") } : Pill(color: :sand) { t(".disabled") }
            end
          end
        end
      end
    end
  end
end
