# frozen_string_literal: true

module MCP
  module Tools
    class CancelTask < Base
      description "Cancel one open or started task, stamped with the time now. It closes without counting as work " \
                  "done, so the activity feed leaves it out. " \
                  "The note and each comment's body may come from an issue tracker and come marked " \
                  "untrusted. #{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::WRITE

      class << self
        private

        def answered(task) = Untrusted.task(task)
      end
    end
  end
end
