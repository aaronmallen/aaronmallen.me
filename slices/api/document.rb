# frozen_string_literal: true

module API
  class Document
    BODIES = %w[patch post].freeze
    CREATED = Action::CREATED.to_s
    FIELD = /\{(\w+)\}/
    JSON_TYPE = "application/json"
    OK = Action::OK.to_s
    OPENAPI = "3.1.0"
    RESPONSES = "#/components/responses/"
    SCHEMAS = "#/components/schemas/"
    SERVER = "/api/v1"
    SUCCESS = "the request worked"
    TITLE = "aaronmallen.me API"
    VERSION = "1"

    OPERATIONS = [
      ["list_journal_entries", "get", "/journal_entries", OK],
      ["create_journal_entry", "post", "/journal_entries", CREATED],
      ["read_journal_entry", "get", "/journal_entries/{id}", OK],
      ["update_journal_entry", "patch", "/journal_entries/{id}", OK],
      ["delete_journal_entry", "delete", "/journal_entries/{id}", OK],
      ["list_tasks", "get", "/tasks", OK],
      ["capture_task", "post", "/tasks", CREATED],
      ["cancel_tasks", "post", "/tasks/bulk/cancel", OK],
      ["complete_tasks", "post", "/tasks/bulk/complete", OK],
      ["delete_tasks", "post", "/tasks/bulk/delete", OK],
      ["move_tasks", "post", "/tasks/bulk/move", OK],
      ["tag_tasks", "post", "/tasks/bulk/tag", OK],
      ["untag_tasks", "post", "/tasks/bulk/untag", OK],
      ["read_task", "get", "/tasks/{id}", OK],
      ["save_task", "patch", "/tasks/{id}", OK],
      ["delete_task", "delete", "/tasks/{id}", OK],
      ["cancel_task", "post", "/tasks/{id}/cancel", OK],
      ["complete_task", "post", "/tasks/{id}/complete", OK],
      ["move_task", "post", "/tasks/{id}/move", OK],
      ["reopen_task", "post", "/tasks/{id}/reopen", OK],
      ["mark_task_seen", "post", "/tasks/{id}/seen", OK],
      ["reorder_task", "post", "/tasks/{id}/reorder", OK],
      ["schedule_task", "post", "/tasks/{id}/schedule", OK],
      ["pause_task", "post", "/tasks/{id}/pause", OK],
      ["start_task", "post", "/tasks/{id}/start", OK],
      ["set_task_total", "post", "/tasks/{id}/total", OK],
      ["update_work_session", "patch", "/tasks/{id}/sessions/{session_id}", OK],
      ["delete_work_session", "delete", "/tasks/{id}/sessions/{session_id}", OK],
      ["add_task_comment", "post", "/tasks/{id}/comments", CREATED],
      ["edit_task_comment", "patch", "/tasks/{id}/comments/{comment_id}", OK],
      ["delete_task_comment", "delete", "/tasks/{id}/comments/{comment_id}", OK],
      ["link_tasks", "post", "/tasks/{id}/links", CREATED],
      ["unlink_task", "delete", "/tasks/{id}/links/{other_id}", OK],
      ["read_commit", "get", "/commits/{id}", OK],
      ["list_decisions", "get", "/decisions", OK],
      ["open_decision", "post", "/decisions", CREATED],
      ["read_decision", "get", "/decisions/{id}", OK],
      ["edit_decision", "patch", "/decisions/{id}", OK],
      ["drop_decision", "post", "/decisions/{id}/drop", OK],
      ["reopen_decision", "post", "/decisions/{id}/reopen", OK],
      ["resolve_decision", "post", "/decisions/{id}/resolve", OK],
      ["add_decision_option", "post", "/decisions/{id}/options", CREATED],
      ["edit_decision_option", "patch", "/decisions/{id}/options/{option_id}", OK],
      ["delete_decision_option", "delete", "/decisions/{id}/options/{option_id}", OK],
      ["add_decision_comment", "post", "/decisions/{id}/comments", CREATED],
      ["edit_decision_comment", "patch", "/decisions/{id}/comments/{comment_id}", OK],
      ["delete_decision_comment", "delete", "/decisions/{id}/comments/{comment_id}", OK],
      ["tag_decision", "post", "/decisions/{id}/tags", CREATED],
      ["untag_decision", "delete", "/decisions/{id}/tags/{tag}", OK],
      ["delete_messages", "post", "/messages/bulk/delete", OK],
      ["mark_messages_read", "post", "/messages/bulk/read", OK],
      ["mark_messages_unread", "post", "/messages/bulk/unread", OK],
      ["delete_posts", "post", "/posts/bulk/delete", OK],
      ["tag_posts", "post", "/posts/bulk/tag", OK],
      ["read_post", "get", "/posts/{id}", OK],
      ["publish_post", "post", "/posts/{id}/publish", OK],
      ["update_post_edit_note", "patch", "/posts/{id}/edits/{edit_id}", OK],
      ["list_attention", "get", "/attention", OK],
      ["list_inbox", "get", "/inbox", OK],
      ["snooze_attention", "post", "/attention/snooze", OK],
      ["list_calendar", "get", "/calendar", OK],
      ["list_links", "get", "/links/{kind}/{id}", OK],
      ["link_records", "post", "/links/{kind}/{id}", CREATED],
      ["unlink_records", "delete", "/links/{kind}/{id}/{other_kind}/{other_id}", OK],
      ["list_people", "get", "/people", OK],
      ["create_person", "post", "/people", CREATED],
      ["search_accounts", "get", "/people/search/{network}", OK],
      ["read_person", "get", "/people/{id}", OK],
      ["update_person", "patch", "/people/{id}", OK],
      ["delete_person", "delete", "/people/{id}", OK],
      ["read_project", "get", "/projects/{id}", OK],
      ["read_review", "get", "/review", OK],
      ["search", "get", "/search", OK],
      ["read_social_post", "get", "/social_posts/{id}", OK],
      ["list_sprints", "get", "/sprints", OK],
      ["plan_sprint", "post", "/sprints", CREATED],
      ["read_current_sprint", "get", "/sprints/current", OK],
      ["drop_sprint", "delete", "/sprints/{id}", OK],
      ["list_saved_views", "get", "/saved_views", OK],
      ["create_saved_view", "post", "/saved_views", CREATED],
      ["update_saved_view", "patch", "/saved_views/{id}", OK],
      ["delete_saved_view", "delete", "/saved_views/{id}", OK],
      ["list_task_tag_rules", "get", "/task_tag_rules", OK],
      ["create_task_tag_rule", "post", "/task_tag_rules", CREATED],
      ["update_task_tag_rule", "patch", "/task_tag_rules/{id}", OK],
      ["delete_task_tag_rule", "delete", "/task_tag_rules/{id}", OK],
      ["read_saved_view", "get", "/saved_views/{id}/records", OK],
      ["read_time_report", "get", "/time_report", OK],
      ["list_webmentions", "get", "/webmentions", OK],
      ["approve_webmentions", "post", "/webmentions/bulk/approve", OK],
      ["ignore_webmentions", "post", "/webmentions/bulk/ignore", OK],
      ["mark_webmentions_spam", "post", "/webmentions/bulk/spam", OK],
      ["read_webmention", "get", "/webmentions/{id}", OK],
      ["read_work_entry", "get", "/work_entries/{id}", OK],
      ["read_token", "get", "/token", OK],
      ["read_document", "get", "/openapi.json", OK],
    ].freeze

    SOURCES = { "read_document" => Actions::Documents::Show, "read_token" => Actions::Tokens::Show }.freeze

    REFUSAL = Schema.object(
      {
        error: { type: "string", enum: [*Action::STATUSES.keys.map(&:to_s), Action::NOT_AN_OBJECT.fetch(:error)] },
        message: Schema::STRING,
      },
      optional: { errors: { type: "object", additionalProperties: Schema.list(Schema::STRING) } },
    ).freeze

    UNAUTHORIZED = Schema.object(
      { error_description: Schema::STRING },
      optional: { error: { type: "string", enum: [Operations::Authenticate::INVALID_TOKEN] } },
    ).freeze

    REFUSALS = {
      "400" => ["BadBody", "the body is not a JSON object", "Refusal"],
      "401" => ["Unauthorized", "no token, or one that is unknown or revoked", "Unauthorized"],
      "404" => ["NotFound", "no record has that ID", "Refusal"],
      "422" => ["Invalid", "the input fails a check", "Refusal"],
      "500" => ["Failed", "the site could not finish the work", "Refusal"],
    }.freeze

    include Deps["inflector"]

    def call
      {
        openapi: OPENAPI,
        info: { title: TITLE, version: VERSION },
        servers: [{ url: SERVER }],
        security: [{ token: [] }],
        paths:,
        components:,
      }
    end

    private

    def body(fields, required)
      return {} if fields.empty?

      schema = { type: "object", additionalProperties: false, properties: fields, required: }.reject do |_, value|
        value == []
      end
      { requestBody: { required: required.any?, content: json(schema) } }
    end

    def components
      {
        schemas: { Refusal: REFUSAL, Unauthorized: UNAUTHORIZED, **serializers },
        responses: REFUSALS.values.to_h { |name, description, schema| [name, refusal(description, schema)] },
        securitySchemes: { token: { type: "http", scheme: "bearer" } },
      }
    end

    def json(schema) = { JSON_TYPE => { schema: } }

    def operation(id, verb, path, status)
      source = SOURCES.fetch(id) { Endpoints.const_get(inflector.camelize(id)) }
      fields = path.scan(FIELD).flatten
      rest, required = remaining(source::SCHEMA, fields)
      taken = BODIES.include?(verb) ? body(rest, required) : {}

      {
        operationId: id,
        summary: inflector.humanize(id),
        parameters: parameters(fields, verb == "get" ? rest : {}, source::SCHEMA, required),
        **taken,
        responses: responses(source, status, fields:, body: taken.any?),
      }
    end

    def parameter(name, place, schema, required:)
      exploded = schema[:type] == "array" ? { style: "form", explode: false } : {}

      { name:, in: place, required:, schema:, **exploded }
    end

    def parameters(fields, query, input, required)
      properties = input.fetch(:properties, {})

      [
        *fields.map { parameter(it, "path", properties.fetch(it.to_sym), required: true) },
        *query.map { |name, schema| parameter(name.to_s, "query", schema, required: required.include?(name.to_s)) },
      ]
    end

    def paths
      OPERATIONS.each_with_object({}) do |(id, verb, path, status), found|
        found[path] = found.fetch(path, {}).merge(verb => operation(id, verb, path, status))
      end
    end

    def refusal(description, schema) = { description:, content: json({ "$ref": "#{SCHEMAS}#{schema}" }) }

    def remaining(input, fields)
      [input.fetch(:properties, {}).except(*fields.map(&:to_sym)), input.fetch(:required, []) - fields]
    end

    def responses(source, status, fields:, body:)
      codes = ["401"]
      codes << "400" if body
      codes << "404" if fields.any? || (source < Endpoint && source::FINDS)
      codes << "422" if source::SCHEMA.fetch(:properties, {}).any?
      codes << "500" if source < Endpoint

      {
        status => { description: SUCCESS, content: json(source::REPLY) },
        **codes.sort.to_h { [it, { "$ref": "#{RESPONSES}#{REFUSALS.fetch(it).first}" }] },
      }
    end

    def serializers
      Serializers.constants.map { Serializers.const_get(it) }.to_h { [it.component, it::SCHEMA] }
    end
  end
end
