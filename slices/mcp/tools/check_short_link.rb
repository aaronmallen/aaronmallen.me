# frozen_string_literal: true

module MCP
  module Tools
    class CheckShortLink < Base
      description "Queue a fresh check of one short link's destination by ID, as the check button on the admin's " \
                  "Links tab does. It runs in the background, and the result shows on that tab"
      endpoint
    end
  end
end
