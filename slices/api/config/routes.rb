# frozen_string_literal: true

module API
  class Routes < Hanami::Routes
    OperationTable::OPERATIONS.each do |id, verb, path|
      route = path.gsub(Operations::BuildDocument::FIELD, ':\1')
      public_send(verb, route, to: OperationTable::ACTIONS.fetch(id) { Actions::Forward.route(id) })
    end
  end
end
