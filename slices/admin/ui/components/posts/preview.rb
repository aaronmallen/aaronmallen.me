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
            h2(class: "preview-title") { @title } unless @title.empty?
            Meta(time: @time, tags: @tags, read_time: @read_time)
            div(class: "post-body") { raw(safe(@body_html)) }
          end
        end
      end
    end
  end
end
