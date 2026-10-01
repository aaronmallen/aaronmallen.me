# frozen_string_literal: true

module Blog
  class Routes < Hanami::Routes
    slice :public, at: "/"
    slice :admin, at: "/admin", as: :admin
    slice :api, at: "/api/v1", as: :api
    slice :mcp, at: "/", as: :mcp
  end
end
