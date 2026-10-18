# frozen_string_literal: true

module Performance
  module Operations
    class RecordTiming
      LOST = "Timing row lost"

      include Deps["logger", mutations: "repos.timing_mutations"]

      def call(kind, **row)
        case kind
          in :job then mutations.record_job(**row)
          in :page then mutations.record_page(**row)
          in :request then mutations.record_request(**row)
        end
      rescue StandardError => e
        logger.error(LOST, error: e.class.name)
      end
    end
  end
end
