# frozen_string_literal: true

module MCP
  module Tools
    class CreateSocialPost < Base
      description "Write a new social post and save it as a draft. Nothing goes out until send_social_post " \
                  "queues it. The answer gives each part's length and limit on each network, so a long part " \
                  "shows before you send"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
