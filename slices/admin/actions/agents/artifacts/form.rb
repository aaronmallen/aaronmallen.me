# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Artifacts
        module Form
          FIELDS = %i[title type tags body note].freeze

          private

          def artifact_params(request) = Blog::Types::Fields[request.params[:artifact]].slice(*FIELDS)

          def artifact_path(request) = routes.path(:admin_artifact, id: record_id(request))
        end
      end
    end
  end
end
