# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Markdown
        class Preview < View
          layout nil

          prop :source, Blog::Types::String
          prop :renderer, Blog::Types::MarkdownRenderer

          def view_template
            MarkdownBody(source: @source, renderer: @renderer)
          end
        end
      end
    end
  end
end
