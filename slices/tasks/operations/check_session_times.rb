# frozen_string_literal: true

module Tasks
  module Operations
    class CheckSessionTimes < Blog::Operation
      ORDER = "order"

      def call(started_at, ended_at, now)
        step past(started_at, ended_at, now)
        step ordered(started_at, ended_at)
      end

      private

      def future(time, now) = ([Blog::Contract::FUTURE] if time && time > now)

      def ordered(started_at, ended_at)
        return Failure[:invalid, { ended_at: [ORDER] }] if ended_at && ended_at < started_at

        Success([started_at, ended_at])
      end

      def past(started_at, ended_at, now)
        errors = { started_at: future(started_at, now), ended_at: future(ended_at, now) }.compact

        errors.empty? ? Success() : Failure[:invalid, errors]
      end
    end
  end
end
