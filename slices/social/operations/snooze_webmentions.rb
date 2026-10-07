# frozen_string_literal: true

module Social
  module Operations
    class SnoozeWebmentions < Operation
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(ids, ends_at)
        each_record(ids) { found(webmention_repo.snooze(it, ends_at)) }
      end
    end
  end
end
