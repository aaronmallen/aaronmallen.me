# frozen_string_literal: true

RSpec.describe "API token scopes", type: :request do
  def self.tools
    {
      "create_person" => "save_person", "update_person" => "save_person",
      "create_project" => "save_project", "update_project" => "save_project",
      "create_tag" => "save_tag", "update_tag" => "save_tag",
      "create_task_rule" => "save_task_rule", "update_task_rule" => "save_task_rule",
    }
  end

  def self.unscoped = %w[read_document read_token]

  def all_scopes = Blog::Types::OAuthScope.values

  def document = JSON.parse(last_response.body)

  def needed(id)
    return Blog::Types::OAuthScope["read"] if self.class.unscoped.include?(id)

    MCP::Tools.const_get(Hanami.app["inflector"].camelize(self.class.tools.fetch(id, id)), false).scope_value
  end

  def operations
    OpenAPI.document.fetch("paths").flat_map do |path, verbs|
      verbs.map { |verb, operation| [verb, path, operation.fetch("operationId")] }
    end
  end

  def refused?(verb, path, scope, tokens)
    response_to(verb, path, tokens.fetch(scope)).status == 403 &&
      last_response.headers["WWW-Authenticate"] == %(Bearer error="insufficient_scope", scope="#{scope}")
  end

  def response_to(verb, path, token)
    call_api(verb, path.gsub(/\{\w+\}/, "0"), %w[patch post].include?(verb) ? "{}" : nil, token:).then { last_response }
  end

  def stored = API::Slice["db.rom"].relations[:api_tokens]

  it "asks each operation for the scope its MCP tool asks for" do
    tokens = all_scopes.to_h { [it, api_token(all_scopes - [it])] }
    wrong = operations.reject { |verb, path, id| refused?(verb, path, needed(id), tokens) }

    expect(wrong).to be_empty, wrong.map { |verb, path, id| "#{verb.upcase} #{path} (#{id})" }.join("\n")
  end

  it "says which scope the token lacks" do
    response_to("post", "/tasks", api_token(%w[read]))

    expect(document).to eq(
      "error" => "insufficient_scope", "error_description" => "this endpoint needs a token with the write scope",
    )
  end

  it "lets a token with the scope through" do
    response_to("post", "/tasks", api_token(%w[write]))

    expect(last_response.status).to eq(422)
  end

  it "lets a read token read" do
    response_to("get", "/token", api_token(%w[read]))

    expect(last_response.status).to eq(200)
  end

  it "gives a token minted with no scopes named every scope" do
    token = API::Slice["operations.mint_token"].call(name: "Terminal").value![:token]

    expect(stored.by_pk(token.id).one[:scopes]).to match_array(all_scopes)
  end

  it "gives a token stored before scopes every scope" do
    value = Blog::Types::NewSecret[]
    stored.dataset.insert(name: "Old laptop", token_digest: Blog::Types::SecretDigest[value])
    response_to("post", "/posts/{id}/publish", value)

    expect(last_response.status).to eq(422)
  end

  it "refuses a scope it does not know" do
    result = API::Slice["operations.mint_token"].call(name: "Terminal", scopes: %w[admin])

    expect(result).to be_failure
  end

  it "refuses an empty set of scopes" do
    result = API::Slice["operations.mint_token"].call(name: "Terminal", scopes: [])

    expect(result.failure).to eq([:invalid, { scopes: ["blank"] }])
  end
end
