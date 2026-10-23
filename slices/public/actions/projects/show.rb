# frozen_string_literal: true

module Public
  module Actions
    module Projects
      class Show < Action
        PROJECT = Blog::Types::TagScope["project"]

        include Deps[
          project_queries: "projects.repos.project_queries",
          tag_queries: "tags.repos.tag_queries",
          task_queries: "tasks.repos.task_queries",
        ]

        share_with_caches

        def handle(request, response)
          project = project_queries.public_board(path_param(request, :slug))
          response.status = :not_found unless project

          response[:project] = project
          response[:board] = Blog::BoardSizes.from(request.params, settings.board[:column_size])
          response[:counts] = {}
          expose_board(request, response, project.id) if project
        end

        private

        def expose_board(request, response, id)
          text = Blog::Types::TrimmedText[request.params[:q].to_s]
          query = ::Tasks::Structs::TaskQuery.parse(text) unless text.empty?

          response[:tags] = tag_queries.all_in(PROJECT, project_id: id)
          response[:filter] = filter(id, text, query)
          expose_tasks(response, id, query)
        end

        def expose_tasks(response, id, query)
          response[:counts] = task_queries.board_counts(id, query)
          response[:tasks] = task_queries.on_public_board(id, response[:board].sizes, query)
        end

        def filter(id, text, query)
          return { text: } unless query

          { text:, ignored: query.ignored, total: task_queries.board_counts(id).values.sum }
        end
      end
    end
  end
end
