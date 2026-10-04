# frozen_string_literal: true

module MCP
  module Tools
    class UntagTasks < Base
      description "Take one private tag off up to 100 tasks at once. One that is missing changes none. " \
                  "Each note may come from an issue tracker and comes marked untrusted. " \
                  "#{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
