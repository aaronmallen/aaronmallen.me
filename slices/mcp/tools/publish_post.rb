# frozen_string_literal: true

module MCP
  module Tools
    class PublishPost < Base
      description "Publish one blog post as it stands. A draft goes out now, or on its publish time when that is " \
                  "still to come. A scheduled post goes out now, as the admin editor sends one when its publish " \
                  "time is cleared. Its announcement and webmentions go with it when the post has them on. " \
                  "A published post cannot be called back, and one already out is refused. " \
                  "The post takes the same checks the admin editor makes, and a refusal names each field at fault"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
