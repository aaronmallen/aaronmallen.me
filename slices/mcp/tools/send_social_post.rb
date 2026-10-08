# frozen_string_literal: true

module MCP
  module Tools
    class SendSocialPost < Base
      description "Queue one social post that has not gone out, to send now or at a set time, the way the admin " \
                  "does. It goes out to every network it targets, and a sent post cannot be called back. " \
                  "The post is refused if a part runs over a network's limit, naming each such part and network, " \
                  "or if a network has no credentials"
      endpoint scope: OAuth::Scope::PUBLISH
    end
  end
end
