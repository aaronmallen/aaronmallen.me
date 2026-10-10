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

  def operation_ids = document.fetch("paths").values.flat_map { it.values.map { it.fetch("operationId") } }

  def operations = OpenAPI.document.fetch("paths").flat_map { |path, verbs| verbs.map { |verb, _| [verb, path] } }

  def routes
    API::Slice.routes
    API::Routes.definitions.map { |verb, (path)| [verb.to_s, path.gsub(/:(\w+)/, '{\1}')] }
  end

  def try(verb, path)
    call_api(verb.to_sym, path.gsub(/\{\w+\}/, "0"), %w[patch post].include?(verb) ? "{}" : nil)
    OpenAPI.answer_errors(last_request, last_response).map { "#{verb.upcase} #{path}: #{it}" }
  end

  it "serves the document the api slice builds" do
    expect(document).to eq(OpenAPI.document)
  end

  it "refuses every operation it describes when the request has no token" do
    unguarded = operations.reject do |verb, path|
      call_api(verb.to_sym, path.gsub(/\{\w+\}/, "0"), nil, token: nil)
      last_response.status == 401 && last_response.headers["WWW-Authenticate"] == "Bearer"
    end

    expect(unguarded).to be_empty, unguarded.map { |verb, path| "#{verb.upcase} #{path}" }.join("\n")
  end

  it "is a valid OpenAPI 3.1 document" do
    errors = JSONSchemer.openapi(document).validate.map { "#{it['data_pointer']}: #{it['error']}" }

    expect(errors).to be_empty
  end

  it "describes every endpoint" do
    missing = endpoints - operation_ids

    expect(missing).to be_empty, "the document leaves out these endpoints:\n#{missing.join("\n")}"
  end

  it "describes every route" do
    missing = routes - operations

    expect(missing).to be_empty, "the document leaves out these routes:\n#{missing.map { it.join(' ') }.join("\n")}"
  end

  it "describes no operation without a route" do
    extra = operations - routes

    expect(extra).to be_empty, "no route serves these operations:\n#{extra.map { it.join(' ') }.join("\n")}"
  end

  it "gives each operation one ID" do
    expect(operation_ids).to eq(operation_ids.uniq)
  end

  it "answers every operation it describes with a status and body it documents" do
    errors = operations.flat_map { |verb, path| try(verb, path) }

    expect(errors).to be_empty, errors.join("\n")
  end
end
