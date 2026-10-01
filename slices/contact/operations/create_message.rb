# frozen_string_literal: true

module Contact
  module Operations
    class CreateMessage < Blog::Operation
      MINUTE = 60

      include Deps["settings", contract: "contracts.message_contract", message_repo: "repos.message_repo"]

      def call(params, visitor_hash:)
        step within_limits(visitor_hash)
        attributes = step validate(params)

        step claim(attributes, visitor_hash:)
      end

      private

      def claim(attributes, visitor_hash:)
        limits = settings.contact
        status = message_repo.sender_status(attributes[:reply_to])
        message = message_repo.claim(
          status:, visitor_hash:, since: window_opened_at,
          limit: limits[:throttle_limit], total_limit: limits[:total_throttle_limit], **attributes,
        )

        message ? Success(message) : Failure([:throttled])
      end

      def form(params)
        { body: params[:body], reply_to: params[:reply_to], subject: params[:subject] }
      end

      def validate(params) = validated(contract.call(form(params)))

      def window_opened_at
        Time.now - (settings.contact[:throttle_window_minutes] * MINUTE)
      end

      def within_limits(visitor_hash)
        since = window_opened_at
        limits = settings.contact
        under = message_repo.count_from_visitor_since(visitor_hash, since) < limits[:throttle_limit] &&
                message_repo.count_since(since) < limits[:total_throttle_limit]

        under ? Success(visitor_hash) : Failure([:throttled])
      end
    end
  end
end
