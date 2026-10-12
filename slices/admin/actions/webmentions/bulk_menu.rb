# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class BulkMenu < Action
        FIELDS = %i[status page].freeze

        def handle(request, response)
          ids = picked_ids(request)
          halt 404 if ids.empty?

          filter = Blog::Types::WebmentionStatusParam[request.params[:status]]
          response.render(view, ids:, filter:, fields: request.params.to_h.slice(*FIELDS))
        end
      end
    end
  end
end
