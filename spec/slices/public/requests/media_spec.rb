# frozen_string_literal: true

RSpec.describe "Media", type: :request do
  let(:key) { "#{'a1b2c3d4' * 4}.jpg" }
  let(:path) { "/media/#{key}" }
  let(:photo) { create(:photo, key:) }
  let(:url) { media_store_url(key) }

  def board_task(*traits, **project) = create(:task, project_id: create(:project, *traits, **project).id)

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

    it "lets a browser keep it for a year and Cloudflare for a day" do
      get path

      expect(cache_control).to eq("public, max-age=31536000, s-maxage=86400, immutable")
    end

    it "lets every cache keep it when the operator asks for it" do
      sign_in_to_admin
      get path

      expect(cache_control).to eq("public, max-age=31536000, s-maxage=86400, immutable")
    end

    it "does not key on the cookie" do
      get path

      expect(last_response.headers["Vary"]).to be_nil
    end

    it "answers an image request" do
      get path, {}, "HTTP_ACCEPT" => "image/avif,image/webp"

      expect(last_response).to be_ok
    end

    it "tags it with its key" do
      get path

      expect(last_response.headers["ETag"]).to eq(%("#{key}"))
    end

    it "answers a browser that holds it with an empty 304 and never asks the store", :aggregate_failures do
      get path, {}, "HTTP_IF_NONE_MATCH" => %("#{key}")

      expect(last_response.status).to eq(304)
      expect(last_response.body).to be_empty
      expect(stub_store).not_to have_been_requested
    end

    it "keeps the tag and cache header on a 304", :aggregate_failures do
      get path, {}, "HTTP_IF_NONE_MATCH" => %("#{key}")

      expect(last_response.headers["ETag"]).to eq(%("#{key}"))
      expect(cache_control).to eq("public, max-age=31536000, s-maxage=86400, immutable")
    end

    it "matches a weak tag in a list" do
      get path, {}, "HTTP_IF_NONE_MATCH" => %("other", W/"#{key}")

      expect(last_response.status).to eq(304)
    end

    it "sends the photo when the browser holds another one", :aggregate_failures do
      get path, {}, "HTTP_IF_NONE_MATCH" => %("#{'b' * 32}.jpg")

      expect(last_response).to be_ok
      expect(last_response.body).to eq("photo")
    end

    it "stays public while a draft also shows it" do
      claim_for_post(:draft)
      get path

      expect(cache_control).to eq("public, max-age=31536000, s-maxage=86400, immutable")
    end
  end

  {
    "a task on a published board" => -> { claim("task", board_task(board_published: true).id) },
    "a comment on a task on a published board" => lambda {
      claim("task_comment", create(:task_comment, task_id: board_task(board_published: true).id).id)
    },
  }.each do |owner, setup|
    describe "a photo #{owner} shows" do
      before do
        connect_media_store
        stub_store
        instance_exec(&setup)
      end

      it "comes back to a visitor with the published cache header", :aggregate_failures do
        get path

        expect(last_response).to be_ok
        expect(cache_control).to eq("public, max-age=31536000, s-maxage=86400, immutable")
      end
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
      "a task on an unpublished board claims" => -> { claim("task", board_task.id) },
      "a task on a private project's board claims" => lambda {
        claim("task", board_task(:private, board_published: true).id)
      },
      "a task on no project claims" => -> { claim("task", create(:task).id) },
      "a comment on a task off a published board claims" => lambda {
        claim("task_comment", create(:task_comment, task_id: board_task.id).id)
      },
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

        it "lets only the operator's browser keep the photo for an hour" do
          sign_in_to_admin
          get path

          expect(cache_control).to eq("private, max-age=3600")
        end

        it "answers the operator's browser that holds it with a 304 and never asks the store", :aggregate_failures do
          sign_in_to_admin
          get path, {}, "HTTP_IF_NONE_MATCH" => %("#{key}")

          expect(last_response.status).to eq(304)
          expect(cache_control).to eq("private, max-age=3600")
          expect(store).not_to have_been_requested
        end

        it "answers a visitor who sends the tag with a 404", :aggregate_failures do
          get path, {}, "HTTP_IF_NONE_MATCH" => %("#{key}")

          expect(last_response.status).to eq(404)
          expect(last_response.headers["ETag"]).to be_nil
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

  describe "a smaller width of a photo" do
    let(:photo) { create(:photo, key:, widths: [640, 1280]) }
    let(:store) do
      stub_request(:get, media_store_url("640/#{key}")).to_return(body: "small",
                                                                  headers: { "Content-Type" => "image/jpeg" })
    end

    before do
      connect_media_store
      store
    end

    it "serves a stored width of a published photo like the photo", :aggregate_failures do
      claim_for_post(:published)
      get "/media/640/#{key}"

      expect(last_response.body).to eq("small")
      expect(last_response.content_type).to eq("image/jpeg")
      expect(cache_control).to eq("public, max-age=31536000, s-maxage=86400, immutable")
    end

    it "tags a width with its own key" do
      claim_for_post(:published)
      get "/media/640/#{key}"

      expect(last_response.headers["ETag"]).to eq(%("640/#{key}"))
    end

    it "answers a browser that holds a width with a 304 and never asks the store", :aggregate_failures do
      claim_for_post(:published)
      get "/media/640/#{key}", {}, "HTTP_IF_NONE_MATCH" => %("640/#{key}")

      expect(last_response.status).to eq(304)
      expect(store).not_to have_been_requested
    end

    it "sends a width when the browser holds the full photo" do
      claim_for_post(:published)
      get "/media/640/#{key}", {}, "HTTP_IF_NONE_MATCH" => %("#{key}")

      expect(last_response.body).to eq("small")
    end

    it "answers a width the photo does not store with a 404 and never asks the store", :aggregate_failures do
      claim_for_post(:published)
      stray = stub_request(:any, /store\.example/)
      get "/media/960/#{key}"

      expect(last_response.status).to eq(404)
      expect(stray).not_to have_been_requested
    end

    it "answers a width of a photo no published post shows with a 404, even to the operator", :aggregate_failures do
      claim_for_post(:draft)
      sign_in_to_admin
      get "/media/640/#{key}"

      expect(last_response.status).to eq(404)
      expect(store).not_to have_been_requested
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

    it "sends no tag" do
      expect(last_response.headers["ETag"]).to be_nil
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
      expect(last_response.headers["ETag"]).to be_nil
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
