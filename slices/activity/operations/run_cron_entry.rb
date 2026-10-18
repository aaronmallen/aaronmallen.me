# frozen_string_literal: true

module Activity
  module Operations
    class RunCronEntry < Blog::Operation
      include Deps[schedule: "sidekiq.schedule"]

      def call(name)
        entry = step found(schedule[name])

        step(queued { Object.const_get(entry.fetch("class")).perform_async(*entry["args"]) })
      end
    end
  end
end
