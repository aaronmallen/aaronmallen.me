# frozen_string_literal: true

module Public
  module Actions
    module Tasks
      class Show < Action
        include Deps[
          comment_queries: "tasks.repos.task_comment_queries",
          project_queries: "projects.repos.project_queries",
          task_queries: "tasks.repos.task_queries",
        ]

        share_with_caches

        def handle(request, response)
          project = project_queries.public_board(path_param(request, :slug)) || not_found(response)
          task = find_task(request, response, project)

          response[:project] = project
          response[:task] = task
          response[:comments] = comment_queries.for_task(task.id)
          response[:related] = related(task, project)
        end

        private

        def find_task(request, response, project)
          number = Blog::Types::Id.call(path_param(request, :number)) { not_found(response) }
          task_queries.on_public_board_by_number(project.id, number) || not_found(response)
        end

        def related(task, project)
          slugs = task_queries.public_board_slugs(task.links.map { it.task.id })

          task.links.filter_map do |link|
            found = slugs[link.task.id]
            [link, found.include?(project.slug) ? project.slug : found.first] if found
          end
        end
      end
    end
  end
end
