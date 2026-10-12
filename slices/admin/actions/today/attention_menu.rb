# frozen_string_literal: true

module Admin
  module Actions
    module Today
      class AttentionMenu < Action
        include Deps[attention_queries: "activity.repos.attention_queries"]

        def handle(request, response)
          kind = request.params[:kind]
          record_id = Blog::Types::IdParam[request.params[:record_id]]
          row = attention_queries.stalled.find { it.kind == kind && it.record_id == record_id } || halt(404)

          response.render(view, row:)
        end
      end
    end
  end
end
