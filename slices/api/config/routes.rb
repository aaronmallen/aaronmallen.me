# frozen_string_literal: true

module API
  class Routes < Hanami::Routes
    get "/token", to: "tokens.show"
  end
end
