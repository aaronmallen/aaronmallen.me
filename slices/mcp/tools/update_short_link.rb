# frozen_string_literal: true

module MCP
  module Tools
    class UpdateShortLink < Base
      description "Edit one short link by ID, as the admin's Links tab does: point it at a new destination, give " \
                  "it a new code or title. A field you leave out keeps what it has. A new code ends the old link, " \
                  "and an empty title has the site read it again from the page. #{Untrusted::SHORT_LINKS}"
      endpoint
    end
  end
end
