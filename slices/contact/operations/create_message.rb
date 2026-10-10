# frozen_string_literal: true

module Contact
  module Operations
    class CreateMessage < Blog::Operation
      include Deps[
        "settings",
        contract: "contracts.message_contract",
        message_mutations: "repos.message_mutations",
        message_queries: "repos.message_queries",
      ]

      def call(params, visitor_hashes:)
        step within_limits(visitor_hashes)
        attributes = step validate(params)

        step claim(attributes, visitor_hashes:)
      end

      private

      def claim(attributes, visitor_hashes:)
        status = message_queries.sender_status(attributes[:reply_to])
        message = message_mutations.claim(
          status:, visitor_hashes:, since: throttle.since,
          limit: throttle.limit, total_limit: throttle.total_limit, **attributes,
        )

        message ? Success(message) : Failure(Blog::Throttle::THROTTLED)
      end

      def form(params)
        { body: params[:body], reply_to: params[:reply_to], subject: params[:subject] }
      end

      def throttle = Blog::Throttle.new(settings.contact)

      def validate(params) = validated(contract.call(form(params)))

      def within_limits(visitor_hashes)
        since = throttle.since
        under = throttle.under?(
          message_queries.count_from_visitor_since(visitor_hashes, since), message_queries.count_since(since),
        )

        under ? Success(visitor_hashes) : Failure(Blog::Throttle::THROTTLED)
      end
    end
  end
end
