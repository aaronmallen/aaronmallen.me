# frozen_string_literal: true

RSpec.describe "API OpenAPI document", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, body = nil, token: api_token)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    public_send(verb, "/api/v1#{path}", body, headers)
    last_response
  end

  def document = JSON.parse(call_api(:get, "/openapi.json").body)

  def endpoints
    names = Dir[API::Slice.root.join("endpoints", "*.rb")].map { File.basename(it, ".rb") }

    names.select { API::Slice.key?("endpoints.#{it}") }
  end

  def operation_ids = OpenAPI.document.fetch("paths").values.flat_map { it.values.map { it.fetch("operationId") } }

  def operations = OpenAPI.document.fetch("paths").flat_map { |path, verbs| verbs.map { |verb, _| [verb, path] } }

  def try(verb, path)
    call_api(verb.to_sym, path.gsub(/\{\w+\}/, "0"), %w[patch post].include?(verb) ? "{}" : nil)
    OpenAPI.answer_errors(last_request, last_response).map { "#{verb.upcase} #{path}: #{it}" }
  end

  it "serves the document the api slice builds" do
    expect(document).to eq(OpenAPI.document)
  end

  it "answers 200" do
    expect(call_api(:get, "/openapi.json").status).to eq(200)
  end

  it "refuses a request with no token" do
    expect(call_api(:get, "/openapi.json", token: nil).status).to eq(401)
  end

  it "is a valid OpenAPI 3.1 document" do
    errors = JSONSchemer.openapi(document).validate.map { "#{it['data_pointer']}: #{it['error']}" }

    expect(errors).to be_empty
  end

  it "describes every endpoint" do
    missing = endpoints - operation_ids

    expect(missing).to be_empty, "the document leaves out these endpoints:\n#{missing.join("\n")}"
  end

  it "describes the timeline read_task answers, one schema per kind of entry" do
    reply = document.dig("paths", "/tasks/{id}", "get", "responses", "200", "content", "application/json", "schema")

    expect(reply.dig("properties", "timeline", "items", "oneOf").map { it.fetch("$ref").split("/").last })
      .to eq(%w[TaskTimelineComment TaskTimelineSession TaskTimelineMove TaskTimelineTag TaskTimelineStatus])
  end

  it "describes when a journal entry was written and when it last changed" do
    entry = document.dig("components", "schemas", "JournalEntry")
    stamp = { "type" => "string", "format" => "date-time" }

    expect(entry.fetch("properties").slice("created_at", "updated_at"))
      .to eq("created_at" => stamp, "updated_at" => stamp)
  end

  it "lists the serializer schemas in name order, after the refusals" do
    names = document.dig("components", "schemas").keys

    expect(names.drop(2)).to eq(names.drop(2).sort)
  end

  it "gives each operation one ID" do
    expect(operation_ids).to eq(operation_ids.uniq)
  end

  it "answers every operation it describes with a status and body it documents" do
    errors = operations.flat_map { |verb, path| try(verb, path) }

    expect(errors).to be_empty, errors.join("\n")
  end
end
