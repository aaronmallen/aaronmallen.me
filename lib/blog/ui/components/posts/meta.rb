# frozen_string_literal: true

module Blog
  module UI
    module Components
      module Posts
        class Meta < Component
          prop :time, Blog::Types::Time
          prop :tags, Blog::Types::Array.of(Blog::Types::String | Blog::Types::Instance(ROM::Struct))
          prop :read_time, Blog::Types::Integer

          def view_template
            div(class: "post-meta") do
              Date(time: @time)
              Tags(tags: @tags)
              span { t(".read_time", count: @read_time) }
              author
            end
          end

          private

          def author
            a(class: "post-author p-author h-card", href: path(:root)) do
              span(class: "p-name") { Hanami.app.settings.owner_name }
            end
          end
        end
      end
    end
  end
end
