# frozen_string_literal: true

module MCP
  module Tools
    class UpdateSocialPost < Base
      description "Change the parts or the networks of one social post that has not gone out. A field you " \
                  "leave out keeps what it has. The edit leaves the post a draft, the way saving a draft in " \
                  "the admin does, so a queued post waits until send_social_post queues it again. The answer " \
                  "gives each part's length and limit on each network"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
