# frozen_string_literal: true

require "erb"
require "json"
require "json_schemer"

module OpenAPI
  PREFIX = %r{\A/api/v1(?=/)}
  SLICE_SPECS = %r{spec/slices/api/}

  module_function

  def answer_errors(request, response)
    path = request.path.sub(PREFIX, "")
    named = "#{request.request_method} #{path}"
    found = operation(path, request.request_method.downcase)
    return ["no operation documents #{named}"] unless found

    tokens = response_tokens(*found, response.status.to_s)
    tokens ? body_errors(tokens, response.body) : ["#{named} does not document a #{response.status}"]
  end

  def body_errors(tokens, body)
    schema = schemer.ref(pointer(*tokens, "content", "application/json", "schema"))

    schema.validate(JSON.parse(body)).map { "#{it['data_pointer']}: #{it['error']}" }
  rescue JSON::ParserError
    ["the body is not JSON: #{body[0, 80]}"]
  end

  def document = @document ||= JSON.parse(JSON.generate(API::Slice["operations.build_document"].call))

  def operation(path, verb)
    template = templates.find { path.match?(it.last) }&.first

    [template, verb] if document.dig("paths", template, verb)
  end

  def pointer(*tokens) = "#/#{tokens.map { ERB::Util.url_encode(it.gsub('~', '~0').gsub('/', '~1')) }.join('/')}"

  def response_tokens(template, verb, status)
    found = document.dig("paths", template, verb, "responses", status)
    return unless found
    return ["paths", template, verb, "responses", status] unless found.key?("$ref")

    found.fetch("$ref").delete_prefix("#/").split("/")
  end

  def schemer = @schemer ||= JSONSchemer.openapi(document)

  def templates
    @templates ||= document.fetch("paths").keys.sort_by { it.count("{") }.map do |template|
      [template, /\A#{template.gsub(/\{\w+\}/, '[^/]+')}\z/]
    end
  end
end

RSpec.configure do |config|
  config.after(type: :request, file_path: OpenAPI::SLICE_SPECS) do
    request = last_request
    next unless request.path.match?(OpenAPI::PREFIX)

    errors = OpenAPI.answer_errors(request, last_response)
    expect(errors).to be_empty, "the answer breaks /api/v1/openapi.json:\n#{errors.join("\n")}"
  rescue Rack::Test::Error
    nil
  end
end
