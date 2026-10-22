# frozen_string_literal: true

module API
  module Structs
    Refusal = Data.define(:error, :message, :errors) do
      def self.conflict(message) = new(error: :conflict, message:, errors: {})

      def self.failed(message) = new(error: :failed, message:, errors: {})

      def self.invalid(errors, message: errors.values.flatten.uniq.join("; ")) = new(error: :invalid, message:, errors:)

      def self.not_found(message) = new(error: :not_found, message:, errors: {})

      def self.queue_unavailable = unavailable("the job queue is down, so nothing was queued; try again soon")

      def self.unavailable(message) = new(error: :unavailable, message:, errors: {})

      def self.undeleted(noun) = new(error: :undeleted, message: format(Endpoint::UNDELETED, noun), errors: {})

      def self.unpublished(message) = new(error: :unpublished, message:, errors: {})

      def self.unscoped(scope)
        new(error: :unscoped, message: format(Action::MISSING_SCOPE, scope), errors: { scope: })
      end

      def to_h = { error: error.to_s, message:, errors: }.reject { |_, value| value == {} }
    end
  end
end
