# frozen_string_literal: true

module Analytics
  module Operations
    class CheckVisit < Blog::Operation
      include Deps[contract: "contracts.visit_contract"]

      def call(payload)
        result = contract.call(payload)
        step(result.success? ? Success(result.to_h) : Failure(:malformed))
      end
    end
  end
end
