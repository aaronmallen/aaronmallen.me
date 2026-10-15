# frozen_string_literal: true

module Social
  module Operations
    class ActOnWebmentions < Blog::Operation
      include Deps[
        contract: "contracts.bulk_contract", # rubocop:disable Hanami/UnusedDeps
        moderate_webmention: "operations.moderate_webmention",
      ]

      def call(params)
        fields = step validate(params)
        verdict = fields[:act]

        each_record(fields[:ids]) { moderate_webmention.call(it, verdict) }
      end
    end
  end
end
