# frozen_string_literal: true

module Social
  module Operations
    class WakeWebmention < Operation
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(id, now: Time.now)
        webmention = step found(webmention_repo.by_id(id))
        step snoozed(webmention, now)

        webmention_repo.snooze(id, now)
      end
    end
  end
end
