# frozen_string_literal: true

module Admin
  module Actions
    module Markdown
      class Preview < Action
        def handle(request, response)
          renderer = request.params[:renderer]
          halt :not_found unless Blog::Types::MarkdownRenderer.valid?(renderer)

          response.render(view, source: Blog::Types::Text[request.params[:markdown]], renderer:)
        end
      end
    end
  end
end
