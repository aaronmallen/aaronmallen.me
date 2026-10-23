# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Show < Action
        PROJECT = Blog::Types::TagScope["project"]

        include Deps[
          project_queries: "projects.repos.project_queries",
          tag_queries: "tags.repos.tag_queries",
          task_queries: "tasks.repos.task_queries",
        ]

        def handle(request, response)
          project = project_queries.by_id(record_id(request))
          not_found(response) unless project

          board = Blog::BoardSizes.from(request.params, settings.board[:column_size])
          tagging = tagging(request, project.id)
          response.render(view, project:, board:, view: board_view(request), tagging:,
                                **filtered(request, project.id, board))
        end

        private

        def board_view(request) = request.params[:view].then { it if UI::Views::Projects::Show::VIEWS.key?(it) }

        def filtered(request, id, board)
          text = Blog::Types::TrimmedText[request.params[:q].to_s]
          query = ::Tasks::Structs::TaskQuery.parse(text) unless text.empty?
          shown = { counts: task_queries.board_counts(id, query), tasks: task_queries.on_board(id, board.sizes, query) }
          return { filter: { text: }, **shown } unless query

          { filter: { text:, ignored: query.ignored, total: task_queries.board_counts(id).values.sum }, **shown }
        end

        def tagging(request, id)
          {
            tags: tag_queries.all_in(PROJECT, project_id: id),
            usage: tag_queries.usage(scope: PROJECT),
            open: request.params[:tags] == "open",
          }
        end
      end
    end
  end
end
