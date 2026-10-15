# auto_register: false
# frozen_string_literal: true

require "dry/monads"
require "json"
require "json_schemer"

module API
  class Endpoint
    FINDS = false
    HEALTH = Blog::Types::OAuthScope["health"]
    MAIL = Blog::Types::OAuthScope["mail"]
    MAIL_ROW = "message"
    MAIL_ROWS = "message rows need the mail scope"
    ROOT = :input
    SCOPED = false
    UNAVAILABLE = false
    WORKOUT = Blog::Types::ActivityKind["workout"]

    include Dry::Monads[:result]
    include Deps["settings", task_queries: "tasks.repos.task_queries"]

    def self.checker = @checker ||= JSONSchemer.schema(JSON.parse(JSON.generate(self::SCHEMA)))

    def self.task_fields
      @task_fields ||= self::SCHEMA.fetch(:properties, {}).filter_map do |name, schema|
        name if Helpers::Schema.task?(schema)
      end
    end

    def call(input = {}, scopes: Blog::Constants::EMPTY_ARRAY)
      fields = input.transform_keys(&:to_s)
      errors = self.class.checker.validate(fields).flat_map { complaints(it) }
      return invalid(errors.group_by(&:first).transform_values { it.map(&:last) }) if errors.any?

      with_tasks(fields.transform_keys(&:to_sym)).bind { handled(it, scopes) }
    end

    private

    def activity_kinds(scopes)
      kinds = Blog::Types::ActivityKind.values
      scopes.include?(HEALTH) ? kinds : kinds - [WORKOUT]
    end

    def bad_window(message) = invalid(from: [message], to: [message])

    def complaints(error)
      missing = error.dig("details", "missing_keys")
      return missing.map { [it.to_sym, "#{it} is missing"] } if missing

      [[error["data_pointer"].split("/")[1]&.to_sym || ROOT, error["error"]]]
    end

    def failed(message) = Failure(Structs::Refusal.failed(message))

    def flat(errors) = errors.transform_values { it.is_a?(Hash) ? it.values.flatten.uniq : it }

    def handled(fields, scopes) = self.class::SCOPED ? handle(**fields, scopes:) : handle(**fields)

    def invalid(errors) = Failure(Structs::Refusal.invalid(errors))

    def linked(groups) = groups.slice(*Serializers::Link::KINDS).transform_values { serialized(Serializers::Link, it) }

    def links_for(id) = linked(record_link_queries.for_record(self.class::KIND, id))

    def lost_task(name, label)
      message = Helpers::Wording.missing("task", label, by: "label")
      name == :id ? not_found(message) : invalid(name => [message])
    end

    def mail?(scopes) = scopes.include?(MAIL)

    def missing(noun, id, by: "ID") = not_found(Helpers::Wording.missing(noun, id, by:))

    def not_found(message) = Failure(Structs::Refusal.not_found(message))

    def page_of(number) = Helpers::Page.of(number, settings)

    def refuse_mail(field, wanted, scopes) = (invalid(field => [MAIL_ROWS]) if wanted && !mail?(scopes))

    def rejected(errors, table)
      complaints = Helpers::Wording.complaints(errors, table)

      Failure(Structs::Refusal.invalid(complaints, message: Helpers::Wording.summary(complaints)))
    end

    def serialized(serializer, object, **params) = serializer.new(object, params:).serializable_hash

    def share_origin = settings.share_site[:url].chomp("/")

    def suggested(suggestion)
      edits = suggestion&.open_edits || Blog::Constants::EMPTY_ARRAY

      { suggestion_id: (suggestion.id if edits.any?), suggestion_edits: serialized(Serializers::SuggestionEdit, edits) }
    end

    def task_id(reference) = reference.is_a?(Integer) ? reference : task_queries.id_by_label(reference)

    def with_tasks(fields)
      self.class.task_fields.select { fields.key?(it) }.each do |name|
        given = fields.fetch(name)
        ids = Array(given).map { task_id(it) || (return lost_task(name, it)) }
        fields[name] = given.is_a?(Array) ? ids : ids.first
      end

      Success(fields)
    end
  end
end
