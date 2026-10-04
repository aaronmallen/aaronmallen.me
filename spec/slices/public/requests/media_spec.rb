# frozen_string_literal: true

RSpec.describe "Media", type: :request do
  let(:key) { "#{'a1b2c3d4' * 4}.jpg" }
  let(:path) { "/media/#{key}" }
  let(:photo) { create(:photo, key:) }
  let(:url) { media_store_url(key) }

  def cache_control = last_response.headers["Cache-Control"]

  def claim(owner, owner_id)
    Media::Slice["relations.photo_claims"].command(:create).call(owner:, owner_id:, photo_id: photo.id)
  end

  def claim_for_post(*traits) = claim("post", create(:post, *traits).id)

  def stub_store = stub_request(:get, url).to_return(body: "photo", headers: { "Content-Type" => "image/jpeg" })

  describe "a photo a published post shows" do
    before do
      connect_media_store
      stub_store
      claim_for_post(:published)
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

    it "stays public while a draft also shows it" do
      claim_for_post(:draft)
      get path

      expect(cache_control).to eq("public, max-age=31536000, immutable")
    end
  end

  describe "a photo no published post shows" do
    let(:store) { stub_store }

    before do
      connect_media_store
      store
    end

    {
      "no record claims" => -> {},
      "a draft post claims" => -> { claim_for_post(:draft) },
      "a scheduled post claims" => -> { claim_for_post(:scheduled) },
      "a journal entry claims" => -> { claim("journal_entry", create(:journal_entry).id) },
      "a task claims" => -> { claim("task", 1) },
    }.each do |owner, setup|
      describe "when #{owner}" do
        before do
          photo
          instance_exec(&setup)
        end

        it "answers a visitor with an empty 404 and never asks the store", :aggregate_failures do
          get path

          expect(last_response.status).to eq(404)
          expect(last_response.body).to be_empty
          expect(store).not_to have_been_requested
        end

        it "answers a visitor the way it answers a missing key", :aggregate_failures do
          get path

          expect(cache_control).to eq("public, max-age=60")
          expect(last_response.headers["Vary"]).to be_nil
        end

        it "shows the operator the photo", :aggregate_failures do
          sign_in_to_admin
          get path

          expect(last_response).to be_ok
          expect(last_response.body).to eq("photo")
          expect(last_response.content_type).to eq("image/jpeg")
        end

        it "keeps the operator's copy out of every cache" do
          sign_in_to_admin
          get path

          expect(cache_control).to eq("private, no-store")
        end
      end
    end

    it "turns private again once its post is unpublished" do
      article = create(:post, :published)
      claim("post", article.id)
      Posts::Slice["relations.posts"].by_pk(article.id).command(:update).call(status: "draft")
      get path

      expect(last_response.status).to eq(404)
    end
  end

  describe "an unknown key" do
    before do
      connect_media_store
      missing = "<Error><Code>NoSuchKey</Code><Message>The specified key does not exist.</Message></Error>"
      stub_request(:get, url).to_return(status: 404, body: missing)
      get path
    end

    it "answers with an empty 404", :aggregate_failures do
      expect(last_response.status).to eq(404)
      expect(last_response.body).to be_empty
    end

    it "lets every cache keep it for a minute" do
      expect(cache_control).to eq("public, max-age=60")
    end

    it "does not key on the cookie" do
      expect(last_response.headers["Vary"]).to be_nil
    end
  end

  describe "a key that is not a photo key" do
    before { connect_media_store }

    %W[a1b2c3.jpg #{'A1B2C3D4' * 4}.jpg #{'a1b2c3d4' * 4}.svg #{'a1b2c3d4' * 4}.jpg.png ..%2Fsecret.jpg].each do |bad|
      it "answers #{bad} with an empty 404 and never asks the store", :aggregate_failures do
        store = stub_request(:any, /store\.example/)
        get "/media/#{bad}"

        expect(last_response.status).to eq(404)
        expect(last_response.body).to be_empty
        expect(store).not_to have_been_requested
      end
    end

    it "lets every cache keep the 404 for a minute" do
      get "/media/a1b2c3.jpg"

      expect(cache_control).to eq("public, max-age=60")
    end

    it "lets every cache keep the 404 when the operator asks for it" do
      sign_in_to_admin
      get "/media/a1b2c3.jpg"

      expect(cache_control).to eq("public, max-age=60")
    end
  end

  describe "a store that cannot be reached" do
    before do
      connect_media_store
      stub_request(:get, url).to_timeout
      claim_for_post(:published)
    end

    it "answers the photo with an empty 404", :aggregate_failures do
      get path

      expect(last_response.status).to eq(404)
      expect(last_response.body).to be_empty
      expect(cache_control).to eq("public, max-age=60")
    end

    it "still loads a post that uses the photo", :aggregate_failures do
      create(:post, :published, slug: "hello", body: "![A photo](#{path})")
      get "/writing/hello"

      expect(last_response).to be_ok
      expect(Capybara.string(last_response.body)).to have_css("img[src='#{path}']")
    end
  end

  describe "a store with no settings" do
    it "answers with an empty 404", :aggregate_failures do
      claim_for_post(:published)
      get path

      expect(last_response.status).to eq(404)
      expect(last_response.body).to be_empty
    end
  end
end
