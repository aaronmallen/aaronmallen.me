# frozen_string_literal: true

RSpec.describe "A request body", type: :request do
  let(:agent) { Hanami.app["honeybadger.agent"] }
  let(:form) { { "CONTENT_TYPE" => "application/x-www-form-urlencoded" } }
  let(:json) { { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer nope" } }
  let(:megabyte) { 1024 * 1024 }
  let(:page) { Capybara.string(last_response.body) }

  before do
    allow(agent).to receive(:notify).and_call_original
    allow(Rack::Multipart).to receive(:parse_multipart).and_call_original
  end

  def file(bytes = "photo")
    Rack::Test::UploadedFile.new(StringIO.new(bytes), "image/jpeg", original_filename: "a.jpg")
  end

  def messages = Contact::Slice["repos.message_repo"].by_status(Blog::Types::MessageStatus["unread"])

  def rpc(size) = JSON.generate({ jsonrpc: "2.0", id: 1, method: "tools/list", params: { note: "a" * size } })

  shared_examples "a refusal" do |status|
    it "answers #{status}" do
      expect(last_response.status).to eq(status)
    end

    it "answers the site's #{status} page" do
      expect(page).to have_css("main .status", exact_text: status.to_s)
    end

    it "sends no notice" do
      expect(agent).not_to have_received(:notify)
    end
  end

  describe "a form over 1 MB" do
    before { post "/contact", "message[body]=#{'a' * megabyte}", form }

    it_behaves_like "a refusal", 413

    it "stores no message" do
      expect(messages).to be_empty
    end
  end

  describe "a JSON body over 1 MB" do
    before { post "/mcp", rpc(megabyte), json.merge("HTTP_ACCEPT" => "application/json") }

    it "answers 413 in JSON" do
      expect(JSON.parse(last_response.body)).to include("status" => 413)
    end
  end

  describe "a JSON body under 1 MB" do
    before { post "/mcp", rpc(megabyte - 1024), json }

    it "reaches the action" do
      expect(last_response.status).to eq(401)
    end
  end

  describe "a JSON body to the API" do
    before { post "/api/v1/token", JSON.generate({ note: "a" * 1024 }), json }

    it "reaches the router" do
      expect(last_response.status).to eq(405)
    end
  end

  describe "a multipart form" do
    before { post "/contact", "message" => { "body" => "hi" }, "photo" => file }

    it_behaves_like "a refusal", 415

    it "parses none of it" do
      expect(Rack::Multipart).not_to have_received(:parse_multipart)
    end

    it "stores no message" do
      expect(messages).to be_empty
    end
  end

  describe "a multipart POST to the API" do
    before { post "/api/v1/token", "photo" => file }

    it "answers 415" do
      expect(last_response.status).to eq(415)
    end
  end

  describe "a photo upload over 1 MB" do
    before { post "/admin/photos", photo: file("a" * 2 * megabyte) }

    it "reaches the action", :aggregate_failures do
      expect(Rack::Multipart).to have_received(:parse_multipart).at_least(:once)
      expect(last_response.status).to eq(403)
    end
  end

  describe "a photo upload over 25 MB" do
    before { post "/admin/photos", { photo: file }, "CONTENT_LENGTH" => ((25 * megabyte) + 1).to_s }

    it_behaves_like "a refusal", 413

    it "parses none of it" do
      expect(Rack::Multipart).not_to have_received(:parse_multipart)
    end
  end
end
