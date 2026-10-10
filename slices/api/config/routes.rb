# frozen_string_literal: true

module API
  class Routes < Hanami::Routes
    ACTIONS = { "read_document" => "documents.show", "read_token" => "tokens.show" }.freeze

    Operations::BuildDocument::OPERATIONS.each do |id, verb, path|
      route = path.gsub(Operations::BuildDocument::FIELD, ':\1')
      public_send(verb, route, to: ACTIONS.fetch(id) { Actions::Forward.route(id) })
    end
  end
end
