# frozen_string_literal: true

RSpec.describe "API guarded rows", type: :request do
  def self.guarded = %w[workout message mail_thread note note_folder]

  def answer(rows, scopes)
    endpoint = Class.new(API::Endpoint) do
      const_set(:SCHEMA, { additionalProperties: false })
      define_method(:handle) { Success(rows:) }
    end

    endpoint.new.call(scopes:).value!.fetch(:rows)
  end

  def guarded_rows(value)
    case value
      when Hash then guarded_rows(value.values) + (self.class.guarded.include?(value["kind"]) ? [value] : [])
      when Array then value.flat_map { guarded_rows(it) }
      else []
    end
  end

  def headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{token}" }

  def leaks(verb, path)
    body = %w[patch post].include?(verb) ? "{}" : query
    public_send(verb.to_sym, "/api/v1#{path.gsub(/\{\w+\}/, view.id.to_s)}", body, headers)
    shown?(last_response.body) ? ["#{verb.upcase} #{path}"] : []
  end

  def marker = "zephyr"

  def operations = OpenAPI.document.fetch("paths").flat_map { |path, verbs| verbs.keys.map { [it, path] } }

  def query
    { from: (Date.today - 7).iso8601, to: Date.today.iso8601, query: marker, name: marker }
  end

  def rows = self.class.guarded.map { { kind: it } } + [{ kind: "task" }]

  def shown?(body) = body.include?(marker) || guarded_rows(JSON.parse(body)).any?

  def token = @token ||= API::Slice["operations.mint_token"].call(name: "Reader", scopes: %w[read]).value!.fetch(:value)

  def view = @view ||= create(:saved_view, screen: "activity", filters: query.slice(:from, :to))

  before do
    yesterday = Time.now - 86_400
    create(:workout, started_at: yesterday, device: "#{marker} watch")
    thread = create(:message, subject: "#{marker} letter", received_at: yesterday)
    create(:mail_message, mail_thread_id: thread.id, body: "#{marker} body", received_at: yesterday)
    create(:message, :read, subject: "#{marker} reply", received_at: yesterday)
    create(:note, title: "#{marker} sketches", body: "#{marker} body")
    create(:note_folder, name: "#{marker} folder")
  end

  it "shows no workout, mail or note row from any endpoint to a token with only read" do
    leaked = operations.flat_map { |verb, path| leaks(verb, path) }

    expect(leaked).to be_empty, "these show a workout, mail or note row:\n#{leaked.join("\n")}"
  end

  it "drops workout, mail and note rows from an endpoint that does not drop them itself" do
    expect(answer(rows, %w[read])).to eq([{ kind: "task" }])
  end

  it "keeps workout, mail and note rows for a token with health, mail and notes" do
    expect(answer(rows, %w[read health mail notes])).to eq(rows)
  end
end
