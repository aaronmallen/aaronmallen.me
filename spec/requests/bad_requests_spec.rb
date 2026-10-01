# frozen_string_literal: true

RSpec.describe "A request the site cannot read", type: :request do
  let(:agent) { Hanami.app["honeybadger.agent"] }
  let(:form) { { "CONTENT_TYPE" => "application/x-www-form-urlencoded" } }
  let(:page) { Capybara.string(last_response.body) }

  before { allow(agent).to receive(:notify).and_call_original }

  shared_examples "a bad request" do
    it "answers 400" do
      expect(last_response.status).to eq(400)
    end

    it "answers the site's 400 page" do
      expect(page).to have_css("main .status", exact_text: "400")
    end

    it "sends no notice" do
      expect(agent).not_to have_received(:notify)
    end
  end

  describe "a tag that is not UTF-8" do
    before { get "/writing/tags/%FF" }

    it_behaves_like "a bad request"
  end

  describe "a tag feed that is not UTF-8" do
    before { get "/writing/tags/%FF.atom" }

    it_behaves_like "a bad request"
  end

  describe "a query value that is not UTF-8" do
    before { get "/writing", {}, "QUERY_STRING" => "page=%FF" }

    it_behaves_like "a bad request"
  end

  describe "a query key that is not UTF-8" do
    before { get "/writing", {}, "QUERY_STRING" => "%FF=1" }

    it_behaves_like "a bad request"
  end

  describe "a contact field that is not UTF-8" do
    before { post "/contact", "message[subject]=hi&message[body]=%FF", form }

    it_behaves_like "a bad request"

    it "stores no message" do
      expect(Contact::Slice["repos.message_repo"].by_status(Blog::Types::MessageStatus["unread"])).to be_empty
    end
  end

  describe "a query Rack cannot unescape" do
    before { get "/", {}, "QUERY_STRING" => "a=%" }

    it_behaves_like "a bad request"
  end

  describe "a contact field sent as both a value and a hash" do
    before { post "/contact", "message[body]=a&message[body][x]=b", form }

    it_behaves_like "a bad request"
  end

  describe "a form body over Rack's limit" do
    before { post "/contact", "message[body]=#{'a' * Rack::Utils.default_query_parser.bytesize_limit}", form }

    it_behaves_like "a bad request"
  end

  describe "a client that asks for JSON" do
    before { get "/", {}, "QUERY_STRING" => "a=%", "HTTP_ACCEPT" => "application/json" }

    it "answers 400" do
      expect(last_response.status).to eq(400)
    end

    it "names the status in JSON" do
      expect(JSON.parse(last_response.body)).to include("status" => 400)
    end
  end

  describe "a JSON body that holds a percent sign" do
    before do
      body = JSON.generate({ jsonrpc: "2.0", id: 1, method: "tools/list", params: { note: "100%" } })
      post "/mcp", body, "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer nope"
    end

    it "reaches the action" do
      expect(last_response.status).to eq(401)
    end
  end

  describe "a file upload whose bytes are not UTF-8" do
    before do
      file = Rack::Test::UploadedFile.new(StringIO.new("\xFF\xD8\xFF\xFE".b), "image/jpeg", original_filename: "a.jpg")
      post "/admin/photos", photo: file
    end

    it "passes the guard" do
      expect(last_response.status).not_to eq(400)
    end
  end

  describe "a request the site can read" do
    before { get "/writing/tags/nothing-here", {}, "QUERY_STRING" => "a=caf%C3%A9" }

    it "reaches the action" do
      expect(last_response.status).to eq(404)
    end

    it "answers the action's page, not the 400 page" do
      expect(page).to have_css("main .status", exact_text: "404")
    end
  end
end
