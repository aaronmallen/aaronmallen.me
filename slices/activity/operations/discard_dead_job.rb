# frozen_string_literal: true

module Activity
  module Operations
    class DiscardDeadJob < Operation
      include Deps[dead_set: "sidekiq.dead_set"]

      def call(jid) = step(found(dead_set.call.find_job(jid))).delete
    end
  end
end
