# auto_register: false
# frozen_string_literal: true

require "dry/monads"
require "json"
require "json_schemer"

module API
  class Endpoint
    FINDS = false
    MAIL_ROW = "message"
    MAIL_ROWS = "message rows need the mail scope"
    PUBLIC_TASK = "a task on a published board"
    ROOT = :input
    SCOPED = false
    SHOWS_TASKS = false
    UNAVAILABLE = false
    UNDELETED = "this change removes %s for good, so it needs the delete scope"
    UNPUBLISHED = "%s shows in public, so this change needs the publish scope"
    WORKOUT = Blog::Types::ActivityKind["workout"]
    GUARDED = {
      OperationTable::AGENTS => Serializers::Link::AGENT_KINDS,
      OperationTable::HEALTH => [WORKOUT],
      OperationTable::MAIL => [MAIL_ROW, Serializers::Link::MAIL_THREAD],
      "notes" => Serializers::Link::NOTE_KINDS,
    }.freeze

    include Dry::Monads[:result]
    include Deps["settings", honeybadger: "honeybadger.agent", task_queries: "tasks.repos.task_queries"]

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
      scopes.include?(OperationTable::HEALTH) ? kinds : kinds - [WORKOUT]
    end

    def bad_window(message) = invalid(from: [message], to: [message])

    def complaints(error)
      missing = error.dig("details", "missing_keys")
      return missing.map { [it.to_sym, "#{it} is missing"] } if missing

      [[error["data_pointer"].split("/")[1]&.to_sym || ROOT, error["error"]]]
    end

    def failed(message) = Failure(Structs::Refusal.failed(message))

    def going_public(fields)
      return unless self.class::SHOWS_TASKS

      ids = self.class.task_fields.flat_map { Array(fields[it]) }
      PUBLIC_TASK if task_queries.public_board_slugs(ids).any?
    end

    def handled(fields, scopes)
      refusal = publish_refusal(fields, scopes)
      return refusal if refusal

      (self.class::SCOPED ? handle(**fields, scopes:) : handle(**fields)).fmap { hidden(it, scopes) }
    end

    def hidden(payload, scopes)
      kinds = GUARDED.except(*scopes).values.flatten
      kinds.empty? ? payload : Helpers::Guarded.without(payload, kinds)
    end

    def invalid(errors) = Failure(Structs::Refusal.invalid(errors))

    def linked(groups, kinds = Serializers::Link::UNMAILED)
      groups.slice(*kinds).transform_values { serialized(Serializers::Link, it) }
    end

    def links_for(id) = linked(record_link_queries.for_record(self.class::KIND, id))

    def lost_task(name, label)
      message = Helpers::Wording.missing("task", label, by: "label")
      name == :id ? not_found(message) : invalid(name => [message])
    end

    def mail?(scopes) = scopes.include?(OperationTable::MAIL)

    def missing(noun, id, by: "ID") = not_found(Helpers::Wording.missing(noun, id, by:))

    def not_found(message) = Failure(Structs::Refusal.not_found(message))

    def page_of(number) = Helpers::Page.of(number, settings)

    def publish_refusal(fields, scopes)
      shown = going_public(fields) unless scopes.include?(OperationTable::PUBLISH)
      Failure(Structs::Refusal.unpublished(format(UNPUBLISHED, shown))) if shown
    end

    def refuse_mail(field, wanted, scopes) = (invalid(field => [MAIL_ROWS]) if wanted && !mail?(scopes))

    def rejected(errors, table)
      complaints = Helpers::Wording.complaints(errors, table)

      Failure(Structs::Refusal.invalid(complaints, message: Helpers::Wording.summary(complaints)))
    end

    def serialized(serializer, object, **params) = serializer.new(object, params:).serializable_hash

    def suggested(suggestion)
      edits = suggestion&.open_edits || Blog::Constants::EMPTY_ARRAY

      { suggestion_id: (suggestion.id if edits.any?), suggestion_edits: serialized(Serializers::SuggestionEdit, edits) }
    end

    def task_id(reference) = reference.is_a?(Integer) ? reference : task_queries.id_by_label(reference)

    def task_ids(given) = Array(given).map { task_id(it) }

    def unhandled(value, text) = failed(text).tap { honeybadger.notify(NoMatchingPatternError.new(value.inspect)) }

    def with_tasks(fields)
      self.class.task_fields.select { fields.key?(it) }.each do |name|
        given = fields.fetch(name)
        ids = task_ids(given)
        lost = ids.index(nil)
        return lost_task(name, Array(given)[lost]) if lost

        fields[name] = given.is_a?(Array) ? ids : ids.first
      end

      Success(fields)
    end
  end
end
