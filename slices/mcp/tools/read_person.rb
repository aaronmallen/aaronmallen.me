# frozen_string_literal: true

module MCP
  module Tools
    class ReadPerson < Base
      description "Read one contact by ID, such as a person hit from search: its key, name and Mastodon and " \
                  "Bluesky handles, and with the contacts permission every private field as well"
      endpoint
    end
  end
end
