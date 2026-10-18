# frozen_string_literal: true

module MCP
  module Tools
    class ListArtifacts < Base
      description "List artifacts, last changed first, without their bodies. Narrow them by type, by words in the " \
                  "title, latest body or tags, or both. read_artifact gives the body. " \
                  "#{API::Helpers::Paging::USAGE}. #{Untrusted::ARTIFACT}"
      endpoint
    end
  end
end
