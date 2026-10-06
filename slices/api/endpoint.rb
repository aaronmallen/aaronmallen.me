# auto_register: false
# frozen_string_literal: true

require "dry/monads"
require "json"
require "json_schemer"

module API
  class Endpoint
    FINDS = false
    ROOT = :input
    UNAVAILABLE = false

    include Dry::Monads[:result]

    def self.checker = @checker ||= JSONSchemer.schema(JSON.parse(JSON.generate(self::SCHEMA)))

    def call(input = {})
      fields = input.transform_keys(&:to_s)
      errors = self.class.checker.validate(fields).flat_map { complaints(it) }
      return invalid(errors.group_by(&:first).transform_values { it.map(&:last) }) if errors.any?

      handle(**fields.transform_keys(&:to_sym))
    end

    private

    def complaints(error)
      missing = error.dig("details", "missing_keys")
      return missing.map { [it.to_sym, "#{it} is missing"] } if missing

      [[error["data_pointer"].split("/")[1]&.to_sym || ROOT, error["error"]]]
    end

    def failed(message) = Failure(Refusal.failed(message))

    def flat(errors) = errors.transform_values { it.is_a?(Hash) ? it.values.flatten.uniq : it }

    def invalid(errors) = Failure(Refusal.invalid(errors))

    def linked(kind, id) = record_links.call(kind, id).transform_values { serialized(Serializers::Link, it) }

    def not_found(message) = Failure(Refusal.not_found(message))

    def page_of(number) = Blog::Page.new(number:, size: settings.page_size[:mcp])

    def rejected(errors, table)
      complaints = Wording.complaints(errors, table)

      Failure(Refusal.invalid(complaints, message: Wording.summary(complaints)))
    end

    def serialized(serializer, object, **params) = serializer.new(object, params:).serializable_hash

    def suggested(suggestion)
      edits = suggestion&.open_edits || Blog::Constants::EMPTY_ARRAY

      { suggestion_id: (suggestion.id if edits.any?), suggestion_edits: serialized(Serializers::SuggestionEdit, edits) }
    end
  end
end
