# frozen_string_literal: true

module MCP
  module Tools
    class RestoreProject < Base
      UNRESTORED = "could not restore the project"

      description "Restore one archived project to /projects as active"
      input_schema(API::Helpers::Schema.by_id)
      scope Blog::Types::OAuthScope["write"]

      class << self
        def call(id:, server_context:)
          case dep(:restore_project, server_context).call(id)
            in Success(project) then answer(id:, status: project.status)
            in Failure(:not_found) then refuse(API::Helpers::Wording.missing("archived project", id))
            else refuse(UNRESTORED)
          end
        end
      end
    end
  end
end
