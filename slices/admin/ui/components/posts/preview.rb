# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Preview < Component
          prop :body_html, Blog::Types::String
          prop :read_time, Blog::Types::Integer
          prop :tags, Blog::Types::Array.of(Blog::Types::String)
          prop :time, Blog::Types::Time
          prop :title, Blog::Types::String

          def view_template
            header(class: "post-h") do
              h2(class: "post-title") { @title } unless @title.empty?
              Meta(time: @time, tags: @tags, read_time: @read_time)
            end
            div(class: "prose lead") { raw(safe(@body_html)) }
          end
        end
      end
    end
  end
end
