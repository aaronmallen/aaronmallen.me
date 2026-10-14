# frozen_string_literal: true

module Performance
  module Operations
    class RecordTiming
      LOST = "Timing row lost"

      include Deps["logger", mutations: "repos.timing_mutations"]

      def call(kind, **row)
        mutations.public_send(:"record_#{kind}", **row)
      rescue StandardError => e
        logger.error(LOST, error: e.class.name)
      end
    end
  end
end
