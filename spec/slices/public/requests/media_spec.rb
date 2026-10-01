# frozen_string_literal: true

RSpec.describe "Media", type: :request do
  let(:key) { "a1b2c3.jpg" }
  let(:missing) { "<Error><Code>NoSuchKey</Code><Message>The specified key does not exist.</Message></Error>" }
  let(:page) { Capybara.string(last_response.body) }
  let(:path) { "/media/#{key}" }
  let(:url) { media_store_url(key) }

  def cache_control = last_response.headers["Cache-Control"]

  describe "a stored photo" do
    before do
      connect_media_store
      stub_request(:get, url).to_return(body: "photo", headers: { "Content-Type" => "image/jpeg" })
    end

    it "comes back with its bytes and content type", :aggregate_failures do
      get path

      expect(last_response).to be_ok
      expect(last_response.body).to eq("photo")
      expect(last_response.content_type).to eq("image/jpeg")
    end

    it "lets every cache keep it for a year" do
      get path

      expect(cache_control).to eq("public, max-age=31536000, immutable")
    end

    it "lets every cache keep it when the operator asks for it" do
      sign_in_to_admin
      get path

      expect(cache_control).to eq("public, max-age=31536000, immutable")
    end

    it "does not key on the cookie" do
      get path

      expect(last_response.headers["Vary"]).to be_nil
    end

    it "answers an image request" do
      get path, {}, "HTTP_ACCEPT" => "image/avif,image/webp"

      expect(last_response).to be_ok
    end
  end

  describe "an unknown key" do
    before do
      connect_media_store
      stub_request(:get, url).to_return(status: 404, body: missing)
      get path
    end

    it "answers with an empty 404", :aggregate_failures do
      expect(last_response.status).to eq(404)
      expect(last_response.body).to be_empty
    end

    it "lets no cache keep it" do
      expect(cache_control).to be_nil
    end
  end

  describe "a store that cannot be reached" do
    before do
      connect_media_store
      stub_request(:get, url).to_timeout
    end

    it "answers the photo with an empty 404", :aggregate_failures do
      get path

      expect(last_response.status).to eq(404)
      expect(last_response.body).to be_empty
    end

    it "still loads a post that uses the photo", :aggregate_failures do
      create(:post, :published, slug: "hello", body: "![A photo](#{path})")
      get "/writing/hello"

      expect(last_response).to be_ok
      expect(page).to have_css("img[src='#{path}']")
    end
  end

  describe "a store with no settings" do
    it "answers with an empty 404", :aggregate_failures do
      get path

      expect(last_response.status).to eq(404)
      expect(last_response.body).to be_empty
    end
  end
end
