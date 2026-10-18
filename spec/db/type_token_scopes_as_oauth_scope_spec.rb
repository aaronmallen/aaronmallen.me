# frozen_string_literal: true

RSpec.describe "Typing token scopes as oauth_scope", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:migration) do
    path = Hanami.app.root.join("config/db/migrate/20261018150007_type_token_scopes_as_oauth_scope.rb")
    ROM::SQL.with_gateway(Hanami.app["db.rom"].gateways[:default]) { load path.to_s }
    Sequel::Migration.descendants.last
  end
  let(:scopes) { Blog::Types::OAuthScope.values }
  let(:sets) { [scopes, *scopes.zip] }
  let(:client) { create(:oauth_client).id }

  def held(table) = db[table].order(:id).select_map(:scopes).map(&:to_a)

  def rows(index)
    {
      api_tokens: { name: "Token #{index}", token_digest: Blog::Types::SecretDigest["api-#{index}"] },
      oauth_tokens: {
        oauth_client_id: client, type: "access", expires_at: Time.now + 3600,
        token_digest: Blog::Types::SecretDigest["oauth-#{index}"],
      },
      oauth_codes: {
        oauth_client_id: client, code_digest: Blog::Types::SecretDigest["code-#{index}"], expires_at: Time.now + 60,
        redirect_uri: "https://claude.ai/api/mcp/auth_callback", code_challenge: "challenge",
      },
    }
  end

  before do
    migration.apply(db, :down)
    sets.each_with_index do |set, index|
      rows(index).each { |table, row| db[table].insert(scopes: Sequel.pg_array(set, :text), **row) }
    end
    migration.apply(db, :up)
  end

  it "keeps every scope each token and code held" do
    expect(%i[api_tokens oauth_tokens oauth_codes].map { held(it) }).to all(eq(sets))
  end

  it "lets each API token through with the scopes it held" do
    found = sets.each_index.map do |index|
      API::Slice["repos.api_token_queries"].live_by_token("api-#{index}").scopes.to_a
    end

    expect(found).to eq(sets)
  end

  it "lets each OAuth token through with the scopes it held" do
    found = sets.each_index.map do |index|
      MCP::Slice["repos.oauth_token_queries"].by_token("oauth-#{index}", type: "access").scopes.to_a
    end

    expect(found).to eq(sets)
  end

  it "still refuses an API token with no scopes" do
    expect { db[:api_tokens].insert(name: "Empty", token_digest: "empty", scopes: Sequel.pg_array([], :oauth_scope)) }
      .to raise_error(Sequel::CheckConstraintViolation)
  end
end
