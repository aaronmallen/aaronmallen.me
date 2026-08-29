# frozen_string_literal: true

RSpec.describe "CORS preflight", type: :request do
  def preflight(path)
    options path, {}, {
      "HTTP_ORIGIN" => "https://client.example",
      "HTTP_ACCESS_CONTROL_REQUEST_METHOD" => "POST",
      "HTTP_ACCESS_CONTROL_REQUEST_HEADERS" => "authorization, content-type, mcp-protocol-version",
    }
  end

  %w[/mcp /oauth/register /oauth/token].each do |path|
    describe "OPTIONS #{path}" do
      before { preflight(path) }

      it "answers with no content" do
        expect(last_response.status).to eq(204)
      end

      it "carries no body" do
        expect(last_response.body).to be_empty
      end

      it "allows any origin" do
        expect(last_response.headers["Access-Control-Allow-Origin"]).to eq("*")
      end

      it "allows the POST" do
        expect(last_response.headers["Access-Control-Allow-Methods"]).to eq("POST")
      end

      it "allows the headers an MCP client sends" do
        expect(last_response.headers["Access-Control-Allow-Headers"])
          .to eq("Authorization, Content-Type, MCP-Protocol-Version")
      end

      it "asks for no token" do
        expect(last_response.headers).not_to include("WWW-Authenticate")
      end
    end
  end
end
