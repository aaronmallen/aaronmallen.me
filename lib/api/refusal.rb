# frozen_string_literal: true

module API
  Refusal = Data.define(:error, :message, :errors) do
    def self.failed(message) = new(error: :failed, message:, errors: {})

    def self.invalid(errors, message: errors.values.flatten.uniq.join("; ")) = new(error: :invalid, message:, errors:)

    def self.not_found(message) = new(error: :not_found, message:, errors: {})

    def self.unavailable(message) = new(error: :unavailable, message:, errors: {})

    def to_h = { error: error.to_s, message:, errors: }.reject { |_, value| value == {} }
  end
end
