# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Artifacts
        class Index < Action
          KIND = Blog::Types::RecordKind["artifact"]
          WEEK = 7 * 86_400

          include Deps[
            artifact_queries: "agents.repos.artifact_queries", project_queries: "projects.repos.project_queries",
            record_link_queries: "links.repos.record_link_queries",
          ]

          def handle(request, response)
            list = listed(request.params)
            artifacts = artifact_queries.latest_listed(requested_page(request, response), **list)
            not_found(response) if artifacts.past_end?

            response.render(view, artifacts:, list:, **totals, **rows(artifacts.rows))
          end

          private

          def listed(params)
            { type: Blog::Types::ArtifactTypeParam[params[:type]], text: Blog::Types::OptionalText[params[:search]] }
          end

          def rows(found)
            ids = found.map(&:id)

            { current: artifact_queries.current_versions(ids), linked: record_link_queries.counts(KIND, ids),
              keys: project_queries.keys(found.flat_map(&:tags).filter_map(&:project_id)) }
          end

          def totals
            { counts: artifact_queries.count_by_type, week: artifact_queries.updated_since(Time.now - WEEK) }
          end
        end
      end
    end
  end
end
