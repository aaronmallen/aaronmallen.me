# frozen_string_literal: true

require "blog/extensions"
require "dry/validation"

Dry::Validation.load_extensions(:monads)

module Blog
  class Contract < Dry::Validation::Contract
    Extensions.pin(
      self,
      gem: "dry-validation",
      version: "1.11.1",
      reason: "the :moment macro calls the contract's own predicates through the private _contract",
      upstream: nil,
    )

    BLANK = "blank"
    CLOSED = "closed"
    CONTROL = "control"
    FORMAT = "format"
    FUTURE = "future"
    MAX_IDS = 100
    MISSING = "missing"
    SKIPPED = "skipped"
    TOO_LONG = "too_long"
    UNKNOWN_MENTION = "unknown_mention"

    CONTROLS = /[[:cntrl:]&&[^\t\n\r]]/
    PATH_NAME = %r{/|\A\.\.?\z}
    VISIBLE = /[^[:space:]]/

    config.messages.load_paths << Hanami.app.root.join("config", "errors.yml")

    register_macro(:without_controls) do
      key.failure(CONTROL) if Array(value).any? { it.to_s.match?(CONTROLS) }
    end

    register_macro(:bare_filename) do
      key.failure(FORMAT) if key? && value.to_s.match?(PATH_NAME)
    end

    register_macro(:visible) do
      key.failure(BLANK) if Array(value).any? { it.is_a?(::String) && !it.empty? && !it.match?(VISIBLE) }
    end

    register_macro(:known_mentions) do
      key.failure(UNKNOWN_MENTION) if resolve_mentions.unknown(value).any?
    end

    register_macro(:moment) do |context:, macro:|
      next if value.nil? || value.is_a?(Time) || !macro.args.all? { _contract.__send__(it, values, context) }

      key.failure(value == Blog::Constants::GAP ? SKIPPED : FORMAT)
    end

    register_macro(:not_future) do |context:|
      key.failure(FUTURE) if value && value > context.fetch(:today)
    end

    register_macro(:tag_slugs) do
      key.failure(FORMAT) unless Array(value).all? { Types::Tag.valid?(it) }
    end
  end
end
