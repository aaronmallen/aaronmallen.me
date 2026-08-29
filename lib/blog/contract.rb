# frozen_string_literal: true

require "dry/validation"

Dry::Validation.load_extensions(:monads)

module Blog
  class Contract < Dry::Validation::Contract
    CONTROL = "control"
    FORMAT = "format"
    SKIPPED = "skipped"

    CONTROLS = /[[:cntrl:]&&[^\t\n\r]]/

    config.messages.load_paths << Hanami.app.root.join("config", "errors.yml")

    register_macro(:without_controls) do
      key.failure(CONTROL) if Array(value).any? { it.to_s.match?(CONTROLS) }
    end

    register_macro(:tag_slugs) do
      key.failure(FORMAT) unless value.all? { Types::Tag.valid?(it) }
    end
  end
end
