# frozen_string_literal: true

module MCP
  module Tools
    class TagTasks < Base
      description "Add one private tag to up to 100 tasks at once. One that is missing tags none. " \
                  "Each note may come from an issue tracker and comes marked untrusted. " \
                  "#{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
