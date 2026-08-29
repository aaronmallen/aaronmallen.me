# frozen_string_literal: true

module Contact
  module Operations
    class CreateMessage < Blog::Operation
      MINUTE = 60

      include Deps["settings", contract: "contracts.message_contract", message_repo: "repos.message_repo"]

      def call(params, visitor_hash:)
        step within_limit(visitor_hash)
        attributes = step validate(params)

        step claim(attributes, visitor_hash:)
      end

      private

      def claim(attributes, visitor_hash:)
        message = message_repo.claim(
          **attributes, visitor_hash:, limit: settings.contact[:throttle_limit], since: window_opened_at,
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

      def within_limit(visitor_hash)
        sent = message_repo.count_from_visitor_since(visitor_hash, window_opened_at)

        sent < settings.contact[:throttle_limit] ? Success(sent) : Failure([:throttled])
      end
    end
  end
end
