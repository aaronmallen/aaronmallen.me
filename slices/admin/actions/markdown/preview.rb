# frozen_string_literal: true

module Admin
  module Actions
    module Markdown
      class Preview < Action
        RENDERERS = { "posts" => ::Posts::Markdown, "tasks" => ::Tasks::Markdown }.freeze

        def handle(request, response)
          renderer = RENDERERS.fetch(request.params[:renderer]) { halt 404 }

          response.render(view, html: renderer.to_html(Blog::Types::Text[request.params[:markdown]]).strip)
        end
      end
    end
  end
end
