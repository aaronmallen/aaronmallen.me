# frozen_string_literal: true

module Admin
  module UI
    module Components
      class DraftsCard < Component
        prop :posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :counts, Blog::Types::Hash

        def view_template
          Card(title: t(".title"), data: { key_list: true }) do
            @posts.empty? ? Empty { t(".empty") } : @posts.each { |post| row(post) }
          end
        end

        private

        def row(post)
          ListItem(title: post.title, href: path(:admin_edit_post, id: post.id), sub: sub(post))
        end

        def sub(post)
          counts = @counts.fetch(post.id)
          words = t(".words", count: counts[:words])
          read_time = t(".read_time", count: counts[:read_time])
          dotted(words, read_time)
        end
      end
    end
  end
end
