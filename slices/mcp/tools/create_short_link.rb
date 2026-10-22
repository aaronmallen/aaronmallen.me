# frozen_string_literal: true

module MCP
  module Tools
    class CreateShortLink < Base
      description "Make a short link on the share host that sends a reader to the destination, and get its ID, " \
                  "code and link. A destination that already has a short link gets that link back, not a second " \
                  "one. The site reads the title from the destination's page. #{Untrusted::SHORT_LINKS}"
      endpoint
    end
  end
end
