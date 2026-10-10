# frozen_string_literal: true

module Contact
  module Operations
    class CreateMessage < Operation
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
        limits = settings.contact
        status = message_queries.sender_status(attributes[:reply_to])
        message = message_mutations.claim(
          status:, visitor_hashes:, since: window_opened_at,
          limit: limits[:throttle_limit], total_limit: limits[:total_throttle_limit], **attributes,
        )

        message ? Success(message) : Failure([:throttled])
      end

      def form(params)
        { body: params[:body], reply_to: params[:reply_to], subject: params[:subject] }
      end

      def validate(params) = validated(contract.call(form(params)))

      def window_opened_at
        Time.now - (settings.contact[:throttle_window_minutes] * Blog::Helpers::Figures::MINUTE)
      end

      def within_limits(visitor_hashes)
        since = window_opened_at
        limits = settings.contact
        under = message_queries.count_from_visitor_since(visitor_hashes, since) < limits[:throttle_limit] &&
                message_queries.count_since(since) < limits[:total_throttle_limit]

        under ? Success(visitor_hashes) : Failure([:throttled])
      end
    end
  end
end
