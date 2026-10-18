# frozen_string_literal: true

module Activity
  module Operations
    class SwitchCronEntry < Blog::Operation
      include Deps[schedule: "sidekiq.schedule", set_state: "sidekiq.schedule_state"]

      def call(name, enabled:)
        step found(schedule[name])

        step(queued { set_state.call(name, { "enabled" => enabled }) })
      end
    end
  end
end
