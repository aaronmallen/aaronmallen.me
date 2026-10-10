# frozen_string_literal: true

module Social
  module Operations
    class ActOnWebmentions < Blog::Operation
      FIELDS = %i[act ids].freeze

      include Deps[contract: "contracts.bulk_contract", moderate_webmention: "operations.moderate_webmention"]

      def call(params)
        fields = step validate(params)
        verdict = fields[:act]

        each_record(fields[:ids]) { moderate_webmention.call(it, verdict) }
      end

      private

      def form(params) = FIELDS.to_h { [it, params[it]] }

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
