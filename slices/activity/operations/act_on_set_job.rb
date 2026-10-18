# frozen_string_literal: true

module Activity
  module Operations
    class ActOnSetJob < Blog::Operation
      Blog::Extensions.pin(
        self,
        gem: "sidekiq",
        version: "8.1.7",
        reason: "it calls JobSet#remove_job, which SortedEntry keeps private, and repeats the retry_count step of " \
                "SortedEntry#retry",
        upstream: nil,
      )

      SETS = Repos::JobQueries::SETS

      include Deps[**Repos::JobQueries.set_deps]

      def call(set, jid, act)
        step Failure(:unknown_act) unless SETS.dig(set, :acts)&.include?(act)

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

      def lookup(set, jid) = queued { sorted_sets.fetch(set).call.find_job(jid) }

      def retried(item) = item["retry_count"] ? item.merge("retry_count" => item["retry_count"] - 1) : item

      def sorted_sets = SETS.keys.to_h { [it, public_send(:"#{it}_set")] }

      def taken(job)
        message = nil
        job.parent.remove_job(job) { message = it }
        message
      end
    end
  end
end
