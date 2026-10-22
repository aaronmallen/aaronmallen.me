# frozen_string_literal: true

module MCP
  module Tools
    class RunLinkCheck < Base
      description "Queue the whole link check the nightly job runs: every link in every published blog post and " \
                  "every short link's destination, as the admin's banner does when a run stopped early. It runs " \
                  "in the background and takes a while"
      endpoint
    end
  end
end
