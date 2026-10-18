# frozen_string_literal: true

module MCP
  module Tools
    class ReadShareGroup < Base
      description "Read one share group by ID: its code, name, link, page views, zip downloads and files, every file " \
                  "with its own link, name, media type, size, alt text and downloads"
      endpoint
    end
  end
end
