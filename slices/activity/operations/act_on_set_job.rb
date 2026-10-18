# frozen_string_literal: true

module Activity
  module Operations
    class ActOnSetJob < Blog::Operation
      ACTS = { "retries" => %w[retry kill delete], "dead" => %w[retry discard], "scheduled" => %w[run delete] }.freeze

      include Deps[dead_set: "sidekiq.dead_set", retry_set: "sidekiq.retry_set", scheduled_set: "sidekiq.scheduled_set"]

      def call(set, jid, act)
        step Failure(:unknown_act) unless ACTS.fetch(set, []).include?(act)

        job = step found(step(lookup(set, jid)))
        message = step found(step(queued { taken(job) }))

        step(queued { follow(act, message) })
        job
      end

      private

      def follow(act, message)
        case act
          when "retry" then Sidekiq::Client.push(retried(Sidekiq.load_json(message)))
          when "run" then Sidekiq::Client.push(Sidekiq.load_json(message))
          when "kill" then dead_set.call.kill(message)
        end
      end

      def lookup(set, jid) = queued { sets.fetch(set).call.find_job(jid) }

      def retried(item) = item["retry_count"] ? item.merge("retry_count" => item["retry_count"] - 1) : item

      def sets = { "retries" => retry_set, "dead" => dead_set, "scheduled" => scheduled_set }

      def taken(job)
        message = nil
        job.parent.remove_job(job) { message = it }
        message
      end
    end
  end
end
