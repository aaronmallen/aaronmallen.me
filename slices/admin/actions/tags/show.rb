# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Show < Action
        include Deps[summarize_tag: "tags.queries.summary"]

        def handle(request, response)
          summary = summarize_tag.call(path_param(request, :name))
          not_found(response) unless summary

          response.render(view, summary:)
        end
      end
    end
  end
end
