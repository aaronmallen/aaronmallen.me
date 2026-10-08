# frozen_string_literal: true

RSpec.describe "MCP screens", type: :feature do
  include Spec::DB::FactoryHelper.new(:mcp)

  let(:client) { create(:oauth_client, client_name: "Claude", redirect_uris: [redirect_uri]) }
  let(:redirect_uri) { "http://localhost:#{page.server.port}/callback" }

  def authorize_path(**overrides)
    params = {
      client_id: client.client_id,
      code_challenge: MCP::Slice["operations.derive_code_challenge"].call(Blog::Types::NewSecret[]),
      code_challenge_method: "S256",
      redirect_uri:,
      resource: "https://aaronmallen.me/mcp",
      response_type: "code",
      scope: "read write",
      state: "state-from-claude",
    }

    "/oauth/authorize?#{Rack::Utils.build_query(params.merge(overrides))}"
  end

  def screens
    {
      "consent" => authorize_path,
      "form expired" => lambda do
        visit authorize_path
        forge_form "/oauth/authorize"
      end,
      "refused" => authorize_path(response_type: "token"),
    }
  end

  before { sign_in_to_admin }

  it_behaves_like "accessible screens"
  it_behaves_like "readable screens", tap: true
end
