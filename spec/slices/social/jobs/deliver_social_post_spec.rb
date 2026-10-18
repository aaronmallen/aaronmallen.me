# frozen_string_literal: true

require "vips"

RSpec.describe Social::Jobs::DeliverSocialPost do
  subject(:job) { described_class.new }

  let(:social_post_mutations) { Social::Slice["repos.social_post_mutations"] }
  let(:social_post_queries) { Social::Slice["repos.social_post_queries"] }

  before { connect_social_networks }

  def deliver(social_post, network) = job.perform(social_post.id, social_account(network).id)

  def delivery(social_post, network) = reloaded(social_post).deliveries.find { it.network == network }

  def exhaust(social_post, network, exception = nil)
    job = { "args" => [social_post.id, social_account(network).id] }

    described_class.sidekiq_retries_exhausted_block.call(job, exception)
  end

  def facet(url, start, finish)
    {
      "features" => [{ "$type" => "app.bsky.richtext.facet#link", "uri" => url }],
      "index" => { "byteEnd" => finish, "byteStart" => start },
    }
  end

  def facets_for(text)
    deliver(queued(targets: %w[bluesky], parts: [text]), "bluesky")

    bluesky_writes.first.dig("record", "facets")
  end

  def failing(social_post, network)
    deliver(social_post, network)
  rescue StandardError => e
    e
  end

  def key(social_post, network, position) = "social-post-#{social_post.id}-#{social_account(network).id}-#{position}"

  def queued(targets: %w[mastodon], parts: %w[one])
    social_post_mutations.create_with_parts(targets:, parts:, status: "scheduled", posted_at: Time.now - 60)
  end

  def refused(social_post, network)
    deliver(social_post, network)
  rescue described_class::NetworkUnavailable
    nil
  end

  def reloaded(social_post) = social_post_queries.by_id(social_post.id)

  def rkey(social_post, position)
    part = social_post.parts.find { it.position == position }

    Bluesky::Tid.for(part.id, part.created_at)
  end

  def short_code(url) = Shares::Slice["repos.short_link_queries"].by_destination(url).code

  def statuses = SocialNetworks::MASTODON_STATUSES

  def tag_facet(tag, start, finish)
    {
      "features" => [{ "$type" => "app.bsky.richtext.facet#tag", "tag" => tag }],
      "index" => { "byteEnd" => finish, "byteStart" => start },
    }
  end

  describe "a post to Mastodon" do
    before { stub_mastodon("110") }

    let(:social_post) { queued(parts: %w[hello]) }

    it "posts the part publicly" do
      deliver(social_post, "mastodon")

      expect(a_request(:post, statuses).with(body: { status: "hello", visibility: "public" })).to have_been_made
    end

    it "posts hashtags as they are written" do
      deliver(queued(parts: ["read #ruby."]), "mastodon")

      expect(a_request(:post, statuses).with(body: { status: "read #ruby.", visibility: "public" }))
        .to have_been_made
    end

    it "sends the token as a bearer token" do
      deliver(social_post, "mastodon")

      expect(a_request(:post, statuses).with(headers: { "Authorization" => "Bearer token" })).to have_been_made
    end

    it "sends a key Mastodon can use to refuse a repeat" do
      deliver(social_post, "mastodon")

      expect(a_request(:post, statuses).with(headers: { "Idempotency-Key" => key(social_post, "mastodon", 1) }))
        .to have_been_made
    end

    it "records the remote id and the web url" do
      deliver(social_post, "mastodon")

      expect(delivery(social_post, "mastodon"))
        .to have_attributes(remote_ids: %w[110], remote_url: "https://ruby.social/@ada/110", error: nil)
    end

    it "counts the social post posted once its only network has sent it" do
      deliver(social_post, "mastodon")

      expect(reloaded(social_post)).to have_attributes(status: "posted", posted_at: be_within(5).of(Time.now))
    end

    it "records no web url when Mastodon gives none" do
      stub_request(:post, statuses).to_return(**json_response(id: "110", url: " "))
      deliver(social_post, "mastodon")

      expect(delivery(social_post, "mastodon")).to have_attributes(remote_ids: %w[110], remote_url: nil)
    end
  end

  describe "a thread to Mastodon" do
    before { stub_mastodon("1", "2", "3") }

    let(:social_post) { queued(parts: %w[one two three]) }

    it "replies each part to the one before" do
      deliver(social_post, "mastodon")

      expect(a_request(:post, statuses).with(body: hash_including("status" => "three", "in_reply_to_id" => "2")))
        .to have_been_made
    end

    it "starts the thread with a post that replies to nothing" do
      deliver(social_post, "mastodon")

      expect(a_request(:post, statuses).with(body: { status: "one", visibility: "public" })).to have_been_made
    end

    it "records the remote ids in order and keeps the web url of the first part" do
      deliver(social_post, "mastodon")

      expect(delivery(social_post, "mastodon"))
        .to have_attributes(remote_ids: %w[1 2 3], remote_url: "https://ruby.social/@ada/1")
    end
  end

  describe "photos to Mastodon" do
    let(:photos) { [create(:photo), create(:photo)] }
    let(:uploads) { [] }

    before do
      connect_media_store
      stub_mastodon("1", "2")
      stub_size_limit(16_777_216)
      stub_request(:post, SocialNetworks::MASTODON_MEDIA).to_return do |request|
        uploads << request.body.b
        json_response(id: "m#{uploads.size}")
      end
      photos.each { stub_stored(it, "jpeg #{it.key}") }
    end

    def large_png
      create(:photo, key: format("%032x.png", 999))
        .tap { stub_stored(it, File.binread("spec/fixtures/photos/large.png"), type: "image/png") }
    end

    def stub_size_limit(bytes)
      stub_request(:get, SocialNetworks::MASTODON_INSTANCE)
        .to_return(**json_response(configuration: { media_attachments: { image_size_limit: bytes } }))
    end

    def stub_stored(photo, body, type: "image/jpeg")
      stub_request(:get, media_store_url(photo.key)).to_return(body:, headers: { "Content-Type" => type })
    end

    def uploaded_file(upload) = upload[%r{Content-Type: image/\w+\r\n\r\n(.*)\r\n--}m, 1]

    def with_photos(*held, parts: %w[one two])
      social_post_mutations.create_with_parts(
        targets: %w[mastodon], parts:, photos: held, status: "scheduled", posted_at: Time.now - 60,
      )
    end

    it "attaches the photos to the status in order", :aggregate_failures do
      deliver(with_photos({ part: 1, key: photos[0].key }, { part: 1, key: photos[1].key }), "mastodon")

      expect(uploads.map { uploaded_file(it) }).to eq(["jpeg #{photos[0].key}", "jpeg #{photos[1].key}"])
      expect(a_request(:post, statuses).with(body: hash_including("status" => "one", "media_ids" => %w[m1 m2])))
        .to have_been_made
    end

    it "sends each photo's alt text as its description", :aggregate_failures do
      deliver(with_photos({ part: 1, key: photos[0].key, alt: "A cat on a mat" }), "mastodon")

      expect(uploads.first).to include(%(name="description"\r\n\r\nA cat on a mat\r\n))
      expect(uploads.first).to include(%(filename="file.jpeg"))
    end

    it "leaves the description out for a photo with no alt text" do
      deliver(with_photos({ part: 1, key: photos[0].key }), "mastodon")

      expect(uploads.first).not_to include("description")
    end

    it "shrinks a photo over the server's limit until it fits" do
      stub_size_limit(300)
      deliver(with_photos({ part: 1, key: large_png.key }), "mastodon")
      sent = uploaded_file(uploads.first)

      expect([sent.bytesize, Vips::Image.new_from_buffer(sent, "").width]).to match([be <= 300, be < 3000])
    end

    it "posts a part with no photos as before", :aggregate_failures do
      deliver(with_photos({ part: 1, key: photos[0].key }), "mastodon")

      expect(a_request(:post, statuses).with(body: { status: "two", in_reply_to_id: "1", visibility: "public" }))
        .to have_been_made
      expect(uploads.size).to eq(1)
    end

    it "asks the server for its limit only when a part holds photos" do
      deliver(with_photos(parts: %w[one]), "mastodon")

      expect(a_request(:get, SocialNetworks::MASTODON_INSTANCE)).not_to have_been_made
    end

    it "keeps the error when a photo can't be read" do
      stub_request(:get, media_store_url(photos[0].key)).to_return(status: 404)
      social_post = with_photos({ part: 1, key: photos[0].key })
      refused(social_post, "mastodon")

      expect(delivery(social_post, "mastodon").error).to eq("Photo #{photos[0].key} is unavailable")
    end

    it "keeps the error when Mastodon refuses a photo" do
      stub_request(:post, SocialNetworks::MASTODON_MEDIA).to_return(status: 422)
      social_post = with_photos({ part: 1, key: photos[0].key })
      refused(social_post, "mastodon")

      expect(delivery(social_post, "mastodon").error).to eq("Mastodon answered 422 for POST /api/v2/media")
    end

    describe "a GIF Mastodon processes after the upload" do
      let(:gif) do
        create(:photo, key: format("%032x.gif", 998))
          .tap { stub_stored(it, File.binread("spec/fixtures/photos/animated.gif"), type: "image/gif") }
      end

      before do
        stub_const("Mastodon::Media::SECONDS", 0)
        stub_request(:post, SocialNetworks::MASTODON_MEDIA).to_return(**json_response(status: 202, id: "m9", url: nil))
      end

      def media_status = "https://ruby.social/api/v1/media/m9"

      context "when it finishes" do
        before do
          stub_request(:get, media_status).to_return(
            json_response(status: 206, id: "m9", url: nil), json_response(id: "m9", url: "https://files/m9.mp4"),
          )
          deliver(with_photos({ part: 1, key: gif.key }, parts: %w[one]), "mastodon")
        end

        it "uploads the GIF as a GIF" do
          expect(a_request(:post, SocialNetworks::MASTODON_MEDIA).with { it.body.b.include?("image/gif") })
            .to have_been_made
        end

        it "asks after the GIF until Mastodon has processed it" do
          expect(a_request(:get, media_status)).to have_been_made.twice
        end

        it "attaches the GIF to the status" do
          expect(a_request(:post, statuses).with(body: hash_including("media_ids" => %w[m9]))).to have_been_made
        end
      end

      it "keeps the error and sends no status when the GIF never finishes", :aggregate_failures do
        stub_request(:get, media_status).to_return(**json_response(status: 206, id: "m9", url: nil))
        social_post = with_photos({ part: 1, key: gif.key }, parts: %w[one])
        refused(social_post, "mastodon")

        expect(delivery(social_post, "mastodon").error).to eq("Mastodon did not finish processing media m9")
        expect(a_request(:post, statuses)).not_to have_been_made
      end
    end
  end

  describe "Mastodon refusing the send" do
    let(:social_post) { queued }

    {
      "throttles the post" => [{ status: 429 }, "Mastodon rate limited POST /api/v1/statuses"],
      "rejects the token" => [{ status: 401 }, "Mastodon answered 401 for POST /api/v1/statuses"],
      "answers with something that isn't JSON" => [
        { body: "<html></html>", headers: { "Content-Type" => "text/html" } },
        "Mastodon answered POST /api/v1/statuses with String instead of JSON",
      ],
      "answers without a status ID" => [
        { body: { url: "https://ruby.social/@ada/1" }.to_json, headers: { "Content-Type" => "application/json" } },
        "Mastodon answered /api/v1/statuses without a status ID",
      ],
    }.each do |what, (response, error)|
      it "raises so Sidekiq tries again when Mastodon #{what}" do
        stub_request(:post, statuses).to_return(**response)

        message = "account #{social_account('mastodon').id} refused social post #{social_post.id}"

        expect { deliver(social_post, "mastodon") }.to raise_error(described_class::NetworkUnavailable, message)
      end

      it "keeps what went wrong when Mastodon #{what}" do
        stub_request(:post, statuses).to_return(**response)
        refused(social_post, "mastodon")

        expect(delivery(social_post, "mastodon")).to have_attributes(error:, failed: false)
      end
    end

    it "keeps the error when Mastodon can't be reached" do
      stub_request(:post, statuses).to_timeout
      refused(social_post, "mastodon")

      expect(delivery(social_post, "mastodon").error).to start_with("Mastodon request POST /api/v1/statuses failed")
    end

    it "keeps the token out of the error" do
      stub_request(:post, statuses).to_return(status: 401)
      refused(social_post, "mastodon")

      expect(delivery(social_post, "mastodon").error).not_to include("token")
    end

    it "leaves the social post scheduled for the retry" do
      stub_request(:post, statuses).to_return(status: 500)
      refused(social_post, "mastodon")

      expect(reloaded(social_post).status).to eq("scheduled")
    end

    it "keeps the parts that went out before the failure" do
      stub_request(:post, statuses).to_return(json_response(id: "1", url: "https://ruby.social/@ada/1"),
                                              { status: 500 })
      social_post = queued(parts: %w[one two])
      refused(social_post, "mastodon")

      expect(delivery(social_post, "mastodon")).to have_attributes(remote_ids: %w[1], remote_url: /1\z/)
    end
  end

  describe "a retry" do
    let(:social_post) { queued(parts: %w[one two three]) }

    before do
      stub_request(:post, statuses).to_return(json_response(id: "1", url: "https://ruby.social/@ada/1"),
                                              { status: 500 })
      refused(social_post, "mastodon")
      stub_mastodon("2", "3")
    end

    it "starts again at the part that failed, still in reply to the one that went out" do
      deliver(social_post, "mastodon")

      expect(a_request(:post, statuses).with(body: hash_including("status" => "two", "in_reply_to_id" => "1")))
        .to have_been_made.twice
    end

    it "never posts a part that already went out" do
      deliver(social_post, "mastodon")

      expect(a_request(:post, statuses).with(body: hash_including("status" => "one"))).to have_been_made.once
    end

    it "adds the rest to the ids it had and clears the error" do
      deliver(social_post, "mastodon")

      expect(delivery(social_post, "mastodon")).to have_attributes(remote_ids: %w[1 2 3], error: nil)
    end
  end

  describe "a post to Bluesky" do
    before { stub_bluesky }

    let(:social_post) { queued(targets: %w[bluesky], parts: ["go 🎉 http://shares.localhost"]) }

    it "signs in with the handle and the app password" do
      deliver(social_post, "bluesky")

      expect(a_request(:post, bluesky_url("com.atproto.server.createSession"))
        .with(body: { identifier: "ada.example", password: "secret" })).to have_been_made
    end

    it "signs in as an account connected since the last post with no restart" do
      deliver(social_post, "bluesky")
      connect_bluesky({ app_password: "pw-two", handle: "two.example" })
      deliver(queued(targets: %w[bluesky], parts: ["again"]), "bluesky")

      expect(a_request(:post, bluesky_url("com.atproto.server.createSession"))
        .with(body: { identifier: "two.example", password: "pw-two" })).to have_been_made
    end

    it "writes the record to the author's feed" do
      deliver(social_post, "bluesky")

      expect(bluesky_writes.first).to include("collection" => "app.bsky.feed.post",
                                              "repo" => SocialNetworks::BLUESKY_DID)
    end

    it "writes the record under a key Bluesky takes as a TID" do
      deliver(social_post, "bluesky")

      expect(bluesky_writes.first.fetch("rkey")).to match(/\A[2-7a-j][2-7a-z]{12}\z/)
    end

    it "writes each post under a key of its own" do
      other = queued(targets: %w[bluesky], parts: ["go 🎉 http://shares.localhost"])
      [social_post, other].each { deliver(it, "bluesky") }

      expect(bluesky_writes.map { it.fetch("rkey") }.uniq.size).to eq(2)
    end

    it "writes the record with the session token" do
      deliver(social_post, "bluesky")

      expect(a_request(:post, bluesky_url("com.atproto.repo.putRecord"))
        .with(headers: { "Authorization" => "Bearer jwt" })).to have_been_made
    end

    it "sends the text under the post type, stamped with the time it was written" do
      deliver(social_post, "bluesky")

      expect(bluesky_writes.first.fetch("record"))
        .to include("$type" => "app.bsky.feed.post", "text" => "go 🎉 http://shares.localhost",
                    "createdAt" => match(/\A\d{4}-\d{2}-\d{2}T/))
    end

    it "marks a link with a facet over its byte range" do
      deliver(social_post, "bluesky")

      expect(bluesky_writes.first.dig("record", "facets")).to eq([facet("http://shares.localhost", 8, 31)])
    end

    {
      "stops a link at the paren the prose opened" =>
        ["see (http://shares.localhost/Foo_(bar)).", "http://shares.localhost/Foo_(bar)", 5, 38],
      "stops a link at the bracket the prose opened" =>
        ["see [http://shares.localhost/post].", "http://shares.localhost/post", 5, 33],
      "leaves trailing punctuation out of a link" => ["read http://shares.localhost/post.",
                                                      "http://shares.localhost/post", 5, 33],
    }.each do |what, (text, url, start, finish)|
      it what do
        deliver(queued(targets: %w[bluesky], parts: [text]), "bluesky")

        expect(bluesky_writes.first.dig("record", "facets")).to eq([facet(url, start, finish)])
      end
    end

    it "marks every link in order and none in the middle of a word" do
      deliver(queued(targets: %w[bluesky], parts: ["xhttps://no.example http://shares.localhost/a http://shares.localhost/x"]),
              "bluesky")

      expect(bluesky_writes.first.dig("record", "facets").map { it.dig("features", 0, "uri") })
        .to eq(%w[http://shares.localhost/a http://shares.localhost/x])
    end

    it "sends no facets for text without links or tags" do
      deliver(queued(targets: %w[bluesky], parts: ["hello # world"]), "bluesky")

      expect(bluesky_writes.first.fetch("record")).not_to have_key("facets")
    end

    it "marks each hashtag with a tag facet over the hash and the tag" do
      expect(facets_for("#hanami and #ruby")).to eq([tag_facet("hanami", 0, 7), tag_facet("ruby", 12, 17)])
    end

    it "counts bytes, not characters, before a tag" do
      expect(facets_for("go 🎉 café #ruby")).to eq([tag_facet("ruby", 14, 19)])
    end

    it "starts and ends a tag at any kind of space" do
      expect(facets_for("go\u{A0}#ruby\u{3000}now")).to eq([tag_facet("ruby", 4, 9)])
    end

    it "orders tag and link facets by where they start" do
      expect(facets_for("#ruby http://shares.localhost #hanami"))
        .to eq([tag_facet("ruby", 0, 5), facet("http://shares.localhost", 6, 29), tag_facet("hanami", 30, 37)])
    end

    it "marks no tag for a hash inside a link" do
      expect(facets_for("see http://shares.localhost/#top")).to eq([facet("http://shares.localhost/#top", 4, 32)])
    end

    it "marks no tag that runs into a link" do
      expect(facets_for("#see/http://shares.localhost")).to eq([facet("http://shares.localhost", 5, 28)])
    end

    it "leaves trailing punctuation out of a tag" do
      expect(facets_for("read #ruby.")).to eq([tag_facet("ruby", 5, 10)])
    end

    it "marks a tag of 64 characters" do
      expect(facets_for("##{'a' * 64}")).to eq([tag_facet("a" * 64, 0, 65)])
    end

    {
      "a tag of only digits" => "issue #123",
      "a tag over 64 characters" => "##{'a' * 65}",
      "a hash in the middle of a word" => "C#sharp",
    }.each do |what, text|
      it "marks no tag for #{what}" do
        deliver(queued(targets: %w[bluesky], parts: [text]), "bluesky")

        expect(bluesky_writes.first.fetch("record")).not_to have_key("facets")
      end
    end

    it "sends no reply for the first part" do
      deliver(social_post, "bluesky")

      expect(bluesky_writes.first.fetch("record")).not_to have_key("reply")
    end

    it "records the AT URI and the bsky.app URL" do
      deliver(social_post, "bluesky")
      tid = bluesky_writes.first.fetch("rkey")

      expect(delivery(social_post, "bluesky")).to have_attributes(
        remote_ids: [bluesky_uri(tid)], remote_url: "https://bsky.app/profile/ada.example/post/#{tid}",
      )
    end
  end

  describe "a thread to Bluesky" do
    let(:social_post) { queued(targets: %w[bluesky], parts: %w[one two three]) }
    let(:first) { bluesky_uri(rkey(social_post, 1)) }
    let(:second) { bluesky_uri(rkey(social_post, 2)) }

    before do
      stub_bluesky
      stub_bluesky_parent(first)
      stub_bluesky_parent(second, root: { cid: "cid-root", uri: first })
    end

    it "looks the parent up by its URI" do
      deliver(social_post, "bluesky")

      rkey = bluesky_writes.first.fetch("rkey")
      query = { collection: "app.bsky.feed.post", repo: SocialNetworks::BLUESKY_DID, rkey: }

      expect(a_request(:get, bluesky_url("com.atproto.repo.getRecord")).with(query:)).to have_been_made
    end

    it "roots the second part at the first" do
      deliver(social_post, "bluesky")
      parent = { "cid" => "cid-#{first.split('/').last}", "uri" => first }

      expect(bluesky_writes[1].dig("record", "reply")).to eq("parent" => parent, "root" => parent)
    end

    it "keeps the thread root when the parent is itself a reply" do
      deliver(social_post, "bluesky")

      expect(bluesky_writes[2].dig("record", "reply", "root")).to eq("cid" => "cid-root", "uri" => first)
    end

    it "writes each part under a key of its own" do
      deliver(social_post, "bluesky")

      expect(bluesky_writes.map { it.fetch("rkey") }.uniq.size).to eq(3)
    end

    it "records every part" do
      deliver(social_post, "bluesky")

      expect(delivery(social_post, "bluesky").remote_ids.size).to eq(3)
    end

    it "signs in once for the whole thread" do
      deliver(social_post, "bluesky")

      expect(a_request(:post, bluesky_url("com.atproto.server.createSession"))).to have_been_made.once
    end

    describe "a retry after the account reconnects" do
      before do
        stub_request(:post, bluesky_url("com.atproto.repo.putRecord"))
          .to_return(json_response(cid: "cid", uri: first), { status: 500 })
        refused(social_post, "bluesky")
        reconnect_bluesky
        stub_bluesky_writes
      end

      def reconnect_bluesky
        Services::Slice["repos.connection_mutations"]
          .change(social_account("bluesky").id, credentials: { app_password: "pw-two", handle: "ada.example" })
        stub_request(:post, bluesky_url("com.atproto.server.createSession"))
          .with(body: hash_including("password" => "pw-two"))
          .to_return(**json_response(accessJwt: "new", did: SocialNetworks::BLUESKY_DID, handle: "ada.example"))
      end

      def written_with(token)
        a_request(:post, bluesky_url("com.atproto.repo.putRecord"))
          .with(headers: { "Authorization" => "Bearer #{token}" })
      end

      it "replies with the credentials the account reconnected with" do
        deliver(social_post, "bluesky")

        expect(written_with("new")).to have_been_made.twice
      end

      it "signs in once more for the rest of the thread" do
        deliver(social_post, "bluesky")

        expect(a_request(:post, bluesky_url("com.atproto.server.createSession"))).to have_been_made.twice
      end
    end

    it "keeps the error when the parent comes back without a CID" do
      stub_request(:get, bluesky_url("com.atproto.repo.getRecord"))
        .with(query: hash_including({})).to_return(**json_response(uri: first))
      refused(social_post, "bluesky")

      expect(delivery(social_post, "bluesky").error).to eq("Bluesky returned no CID for the parent post #{first}")
    end
  end

  describe "photos to Bluesky" do
    let(:photos) { Array.new(2) { create(:photo, width: 640, height: 480) } }
    let(:uploads) { [] }

    def blob(index) = { "$type" => "blob", "ref" => { "$link" => "cid-#{index}" }, "mimeType" => "image/jpeg" }

    def held(*alts, part: 1) = alts.each_with_index.map { |alt, index| { part:, key: photos[index].key, alt: } }

    def image(index, alt)
      { "alt" => alt, "aspectRatio" => { "height" => 480, "width" => 640 }, "image" => blob(index) }
    end

    def images = bluesky_writes.first.dig("record", "embed", "images")

    def noise = Vips::Image.gaussnoise(1200, 1200).bandjoin([Vips::Image.gaussnoise(1200, 1200)] * 2).cast(:uchar)

    def store(photo, body = "photo-#{photo.key}", type: "image/jpeg")
      stub_request(:get, media_store_url(photo.key)).to_return(body:, headers: { "Content-Type" => type })
    end

    def with_photos(photos, parts: %w[one])
      social_post_mutations.create_with_parts(targets: %w[bluesky], parts:, photos:, status: "scheduled",
                                              posted_at: Time.now - 60)
    end

    before do
      connect_media_store
      stub_bluesky
      photos.each { store(it) }
      stub_request(:post, bluesky_url("com.atproto.repo.uploadBlob")).to_return do |request|
        uploads << request
        json_response(blob: blob(uploads.size))
      end
    end

    it "uploads each photo and embeds them in order, each with its alt text" do
      deliver(with_photos(held("A cat", "A dog")), "bluesky")

      expect(bluesky_writes.first.dig("record", "embed"))
        .to eq("$type" => "app.bsky.embed.images", "images" => [image(1, "A cat"), image(2, "A dog")])
    end

    it "uploads the bytes from the store under their type, with the session token" do
      deliver(with_photos(held(nil)), "bluesky")

      headers = { "Authorization" => "Bearer jwt", "Content-Type" => "image/jpeg" }

      expect(uploads.first).to have_attributes(body: "photo-#{photos[0].key}", headers: include(headers))
    end

    it "sends empty alt text for a photo with none" do
      deliver(with_photos(held(nil)), "bluesky")

      expect(images.first["alt"]).to eq("")
    end

    it "embeds each part's photos on that part alone" do
      social_post = with_photos(held(nil, part: 2), parts: %w[one two])
      stub_bluesky_parent(bluesky_uri(rkey(social_post, 1)))
      deliver(social_post, "bluesky")

      expect(bluesky_writes.map { it.dig("record", "embed", "images")&.size }).to eq([nil, 1])
    end

    it "shrinks a photo over Bluesky's cap to a JPEG under it" do
      big = noise.write_to_buffer(".png")
      store(photos[0], big, type: "image/png")
      deliver(with_photos(held(nil)), "bluesky")

      expect([big.bytesize, uploads.first.body.bytesize, uploads.first.headers["Content-Type"]])
        .to match([be > 1_000_000, be <= 1_000_000, "image/jpeg"])
    end

    it "keeps the error and posts nothing when the store has lost the photo" do
      stub_request(:get, media_store_url(photos[0].key)).to_return(status: 404)
      social_post = with_photos(held(nil))
      refused(social_post, "bluesky")

      expect([delivery(social_post, "bluesky").error, bluesky_writes])
        .to eq(["Photo #{photos[0].key} is unavailable", []])
    end

    it "keeps the error and posts nothing when an upload comes back without a blob" do
      stub_request(:post, bluesky_url("com.atproto.repo.uploadBlob")).to_return(**json_response(size: 1))
      social_post = with_photos(held(nil))
      refused(social_post, "bluesky")

      expect([delivery(social_post, "bluesky").error, bluesky_writes])
        .to eq(["Bluesky returned no blob for an uploaded image", []])
    end

    it "fails with the error once the retries run out on a photo it can't read", :aggregate_failures do
      store(photos[0], "x" * 1_000_001, type: "image/png")
      social_post = with_photos(held(nil))
      error = failing(social_post, "bluesky").tap { exhaust(social_post, "bluesky", it) }

      expect(error).to be_a(Vips::Error)
      expect(delivery(social_post, "bluesky")).to have_attributes(failed: true, error: error.message)
    end
  end

  describe "a link card on Bluesky" do
    let(:page) { "https://aaronmallen.me/notes/1" }
    let(:picture) { "https://aaronmallen.me/card.png" }
    let(:uploads) { [] }

    def card = bluesky_writes.first.dig("record", "embed")

    def html(head)
      { body: "<html><head>#{head}</head><body>hi</body></html>", headers: { "Content-Type" => "text/html" } }
    end

    def link_post(text = "read #{page}", photos: [])
      social_post_mutations.create_with_parts(targets: %w[bluesky], parts: [text], photos:, status: "scheduled",
                                              posted_at: Time.now - 60)
    end

    def noise = Vips::Image.gaussnoise(1200, 1200).bandjoin([Vips::Image.gaussnoise(1200, 1200)] * 2).cast(:uchar)

    def offer_picture(body)
      serve(html(%(<meta property="og:image" content="#{picture}">)))
      serve_picture(body)
    end

    def serve(response) = stub_request(:get, "#{page}?ref=bluesky").to_return(response)

    def serve_picture(body, type: "image/png")
      stub_request(:get, picture).to_return(body:, headers: { "Content-Type" => type })
    end

    def stored_photo
      connect_media_store
      jpeg = { body: "photo", headers: { "Content-Type" => "image/jpeg" } }
      create(:photo, width: 640, height: 480).tap { stub_request(:get, media_store_url(it.key)).to_return(jpeg) }
    end

    def thumb = { "$type" => "blob", "ref" => { "$link" => "thumb" }, "mimeType" => "image/png" }

    before do
      stub_bluesky
      resolves_publicly("aaronmallen.me")
      stub_request(:post, bluesky_url("com.atproto.repo.uploadBlob")).to_return do |request|
        uploads << request
        json_response(blob: thumb)
      end
    end

    it "embeds the first link with the page's title and description" do
      head = %(<title>Plain</title><meta property="og:title" content="Notes">)
      serve(html(%(#{head}<meta name="description" content=" A  note ">)))
      deliver(link_post("read #{page} and https://aaronmallen.me/other"), "bluesky")

      external = { "description" => "A note", "title" => "Notes", "uri" => "#{page}?ref=bluesky" }

      expect(card).to eq("$type" => "app.bsky.embed.external", "external" => external)
    end

    it "takes the og:description and falls back to the title" do
      serve(html(%(<title>Plain</title><meta property="og:description" content="Open">)))
      deliver(link_post, "bluesky")

      expect(card["external"]).to include("description" => "Open", "title" => "Plain")
    end

    it "uploads the og:image as the card's thumbnail", :aggregate_failures do
      serve(html(%(<meta property="og:image" content="/card.png">)))
      serve_picture("png-bytes")
      deliver(link_post, "bluesky")

      expect(uploads.first).to have_attributes(body: "png-bytes", headers: include("Content-Type" => "image/png"))
      expect(card.dig("external", "thumb")).to eq(thumb)
    end

    it "shrinks a thumbnail over Bluesky's cap to a JPEG under it" do
      big = noise.write_to_buffer(".png")
      offer_picture(big)
      deliver(link_post, "bluesky")

      expect([big.bytesize, uploads.first.body.bytesize, uploads.first.headers["Content-Type"]])
        .to match([be > Bluesky::Images::MAX_BYTES, be <= Bluesky::Images::MAX_BYTES, "image/jpeg"])
    end

    it "sends the card without a thumbnail when a big og:image will not decode", :aggregate_failures do
      offer_picture("x" * (Bluesky::Images::MAX_BYTES + 1))
      deliver(link_post, "bluesky")

      expect(uploads).to be_empty
      expect(card["external"]).not_to have_key("thumb")
    end

    {
      "fails to load" => { status: 404, body: "", headers: { "Content-Type" => "text/plain" } },
      "is not an image" => { body: "<svg/>", headers: { "Content-Type" => "image/svg+xml" } },
    }.each do |what, response|
      it "sends the card without a thumbnail when the og:image #{what}", :aggregate_failures do
        serve(html(%(<title>Notes</title><meta property="og:image" content="#{picture}">)))
        stub_request(:get, picture).to_return(response)
        deliver(link_post, "bluesky")

        expect(card.dig("external", "title")).to eq("Notes")
        expect(card["external"]).not_to have_key("thumb")
      end
    end

    {
      "fails to load" => { status: 500, body: "<title>Oops</title>", headers: { "Content-Type" => "text/html" } },
      "is not HTML" => { body: "{}", headers: { "Content-Type" => "application/json" } },
    }.each do |what, response|
      it "sends the post without a card when the page #{what}", :aggregate_failures do
        serve(response)
        deliver(link_post, "bluesky")

        expect(bluesky_writes.first.fetch("record")).to include("text" => "read #{page}?ref=bluesky")
        expect(bluesky_writes.first.fetch("record")).not_to have_key("embed")
      end
    end

    it "sends the post without a card when the page times out" do
      stub_request(:get, "#{page}?ref=bluesky").to_timeout
      deliver(link_post, "bluesky")

      expect(bluesky_writes.first.fetch("record")).not_to have_key("embed")
    end

    it "sends the photos and no card for a post with photos", :aggregate_failures do
      deliver(link_post(photos: [{ part: 1, key: stored_photo.key, alt: nil }]), "bluesky")

      expect(card["$type"]).to eq("app.bsky.embed.images")
      expect(a_request(:get, "#{page}?ref=bluesky")).not_to have_been_made
    end

    it "fetches the page as a bot, so a short link counts no click" do
      serve(html("<title>Notes</title>"))
      deliver(link_post, "bluesky")

      fetched = a_request(:get, "#{page}?ref=bluesky").with { Blog::Helpers::Bot.match?(it.headers["User-Agent"]) }
      expect(fetched).to have_been_made
    end
  end

  describe "Bluesky refusing the send" do
    let(:social_post) { queued(targets: %w[bluesky]) }

    def session_url = bluesky_url("com.atproto.server.createSession")

    def write_url = bluesky_url("com.atproto.repo.putRecord")

    it "keeps the error when the app password is rejected, without the password" do
      stub_request(:post, session_url).to_return(**json_response(status: 401, error: "AuthenticationRequired"))
      refused(social_post, "bluesky")

      expect(delivery(social_post, "bluesky").error)
        .to eq("Bluesky answered 401 for com.atproto.server.createSession: AuthenticationRequired")
    end

    it "keeps the error and the message Bluesky gives for a refused write" do
      stub_bluesky_session
      stub_request(:post, write_url).to_return(**json_response(status: 400, error: "Invalid", message: "Bad key"))
      refused(social_post, "bluesky")

      expect(delivery(social_post, "bluesky").error)
        .to eq("Bluesky answered 400 for com.atproto.repo.putRecord: Invalid: Bad key")
    end

    it "keeps only the status when Bluesky gives no reason" do
      stub_bluesky_session
      stub_request(:post, write_url).to_return(status: 502)
      refused(social_post, "bluesky")

      expect(delivery(social_post, "bluesky").error).to eq("Bluesky answered 502 for com.atproto.repo.putRecord")
    end

    it "keeps the error when the session comes back without a token" do
      stub_bluesky_session(accessJwt: nil)
      refused(social_post, "bluesky")

      expect(delivery(social_post, "bluesky").error).to eq("Bluesky returned an incomplete session for ada.example")
    end

    it "keeps the error when Bluesky throttles the post" do
      stub_bluesky_session
      stub_request(:post, write_url).to_return(**json_response(status: 429, error: "RateLimitExceeded"))
      refused(social_post, "bluesky")

      expect(delivery(social_post, "bluesky").error).to eq("Bluesky rate limited com.atproto.repo.putRecord")
    end

    it "keeps the error when Bluesky answers with something that isn't JSON" do
      stub_bluesky_session
      stub_request(:post, write_url).to_return(body: "<html></html>", headers: { "Content-Type" => "text/html" })
      refused(social_post, "bluesky")

      expect(delivery(social_post, "bluesky").error).to end_with("with String instead of JSON")
    end

    it "keeps the error when the written record comes back without a URI" do
      stub_bluesky_session
      stub_request(:post, write_url).to_return(**json_response(cid: "cid"))
      refused(social_post, "bluesky")

      expect(delivery(social_post, "bluesky").error).to eq("Bluesky wrote a record for did:plc:ada without a URI")
    end

    it "keeps the error when Bluesky can't be reached" do
      stub_bluesky_session
      stub_request(:post, write_url).to_timeout
      refused(social_post, "bluesky")

      expect(delivery(social_post, "bluesky").error).to start_with("Bluesky request com.atproto.repo.putRecord failed")
    end

    it "raises so Sidekiq tries again" do
      stub_request(:post, session_url).to_return(status: 500)

      expect do
        deliver(social_post,
                "bluesky")
      end.to raise_error(described_class::NetworkUnavailable, /account #{social_account('bluesky').id}/)
    end
  end

  describe "a retry to Bluesky" do
    let(:failed) { [] }
    let(:social_post) { queued(targets: %w[bluesky], parts: %w[one two]) }

    before do
      stub_bluesky_session
      stub_bluesky_parent(bluesky_uri(rkey(social_post, 1)))
      stub_request(:post, bluesky_url("com.atproto.repo.putRecord")).to_return do |request|
        failed << JSON.parse(request.body).fetch("rkey")
        { status: 500 }
      end
    end

    it "writes the part again under the key the failed try sent" do
      refused(social_post, "bluesky")
      stub_bluesky_writes
      deliver(social_post, "bluesky")

      expect(bluesky_writes.first.fetch("rkey")).to eq(failed.first)
    end

    it "keeps the session from the failed try" do
      refused(social_post, "bluesky")
      stub_bluesky_writes
      deliver(social_post, "bluesky")

      expect(a_request(:post, bluesky_url("com.atproto.server.createSession"))).to have_been_made.once
    end
  end

  describe "an expired Bluesky session" do
    let(:social_post) { queued(targets: %w[bluesky], parts: %w[one two]) }
    let(:expired) { json_response(status: 400, error: "ExpiredToken", message: "Token has expired") }

    def expire_after(writes)
      sent = Array.new(writes) { json_response(cid: "cid", uri: bluesky_uri(rkey(social_post, it + 1))) }
      stub_bluesky_writes
      stub_request(:post, write_url).with(headers: { "Authorization" => "Bearer old" }).to_return(*sent, expired)
    end

    def session_url = bluesky_url("com.atproto.server.createSession")

    before do
      stub_request(:post, session_url)
        .to_return(json_response(accessJwt: "old", did: SocialNetworks::BLUESKY_DID, handle: "ada.example"))
        .then.to_return(json_response(accessJwt: "new", did: SocialNetworks::BLUESKY_DID, handle: "ada.example"))
      stub_bluesky_parent(bluesky_uri(rkey(social_post, 1)))
    end

    def write_url = bluesky_url("com.atproto.repo.putRecord")

    it "signs in again and sends the part" do
      expire_after(0)
      deliver(social_post, "bluesky")

      expect(a_request(:post, write_url).with(headers: { "Authorization" => "Bearer new" })).to have_been_made.twice
    end

    it "records every part once the new session sends them" do
      expire_after(1)
      deliver(social_post, "bluesky")

      expect(delivery(social_post, "bluesky")).to have_attributes(remote_ids: have_attributes(size: 2), error: nil)
    end

    it "signs in once more, not once per part" do
      expire_after(1)
      deliver(social_post, "bluesky")

      expect(a_request(:post, session_url)).to have_been_made.twice
    end

    it "keeps the error when the new session is refused too" do
      stub_request(:post, write_url).to_return(expired)
      refused(social_post, "bluesky")

      expect(delivery(social_post, "bluesky").error).to eq("Bluesky session expired for com.atproto.repo.putRecord")
    end
  end

  describe "one network of two failing" do
    let(:social_post) { queued(targets: %w[mastodon bluesky], parts: %w[one two]) }

    before do
      stub_bluesky
      stub_bluesky_parent(bluesky_uri(rkey(social_post, 1)))
      stub_request(:post, statuses).to_return(status: 503)
    end

    def deliver_both
      refused(social_post, "mastodon")
      deliver(social_post, "bluesky")
    end

    it "sends every part to the network that works" do
      deliver_both

      expect(delivery(social_post, "bluesky")).to have_attributes(remote_ids: have_attributes(size: 2), error: nil)
    end

    it "keeps the failing network's error on its own delivery" do
      deliver_both

      expect(delivery(social_post, "mastodon")).to have_attributes(remote_ids: [], error: /503/, failed: false)
    end

    it "sends the working network its parts whichever job runs first" do
      deliver(social_post, "bluesky")
      refused(social_post, "mastodon")

      expect(delivery(social_post, "bluesky").remote_ids.size).to eq(2)
    end

    it "posts nothing to the other network from the failing network's job" do
      refused(social_post, "mastodon")

      expect(a_request(:post, bluesky_url("com.atproto.repo.putRecord"))).not_to have_been_made
    end

    it "never posts again to the network that already sent" do
      deliver_both
      deliver(social_post, "bluesky")

      expect(a_request(:post, bluesky_url("com.atproto.repo.putRecord"))).to have_been_made.twice
    end

    it "keeps the social post scheduled while the failing network retries" do
      deliver_both

      expect(reloaded(social_post).status).to eq("scheduled")
    end

    it "counts the social post posted once the failing network gives up" do
      deliver_both
      exhaust(social_post, "mastodon")

      expect(reloaded(social_post)).to have_attributes(status: "posted", posted_at: be_within(5).of(Time.now))
    end
  end

  describe "a part over the network's limit" do
    let(:social_post) { queued(parts: ["one", "a" * 501]) }

    it "posts nothing at all, not even the parts that fit" do
      deliver(social_post, "mastodon")

      expect(a_request(:post, statuses)).not_to have_been_made
    end

    it "marks the delivery failed for good and names the part" do
      deliver(social_post, "mastodon")

      expect(delivery(social_post, "mastodon"))
        .to have_attributes(failed: true, error: "Part 2 is over the mastodon limit")
    end

    it "counts the social post posted, since nothing is left to try" do
      deliver(social_post, "mastodon")

      expect(reloaded(social_post).status).to eq("posted")
    end

    it "takes a long link on Mastodon as 23 characters" do
      stub_mastodon("1")
      deliver(queued(parts: ["#{'a' * 470} https://example.com/#{'b' * 100}"]), "mastodon")

      expect(a_request(:post, statuses)).to have_been_made
    end

    it "refuses Bluesky text within the grapheme limit but past the byte limit" do
      social_post = queued(targets: %w[bluesky], parts: ["👩‍👩‍👧‍👦" * 300])
      deliver(social_post, "bluesky")

      expect(delivery(social_post, "bluesky")).to have_attributes(failed: true, error: /over the bluesky limit/)
    end
  end

  describe "a post that mentions people" do
    let(:person_mutations) { Social::Slice["repos.person_mutations"] }

    let!(:ada) do
      create(:person, key: "ada", name: "Ada Lovelace", mastodon_handle: "@ada@ruby.social",
                      bluesky_handle: "ada.bsky.social", bluesky_did: "did:plc:ada-lovelace")
    end

    def bluesky_record(text)
      stub_bluesky
      deliver(queued(targets: %w[bluesky], parts: [text]), "bluesky")

      bluesky_writes.first.fetch("record")
    end

    def mastodon_status(text) = sent_status(queued(parts: [text]))

    def mention_facet(did, start, finish)
      {
        "features" => [{ "$type" => "app.bsky.richtext.facet#mention", "did" => did }],
        "index" => { "byteEnd" => finish, "byteStart" => start },
      }
    end

    def sent_status(social_post)
      sent = []
      stub_request(:post, statuses).to_return do |request|
        sent << JSON.parse(request.body).fetch("status")
        json_response(id: "1", url: "https://ruby.social/@ada/1")
      end
      deliver(social_post, "mastodon")

      sent.first
    end

    it "sends Mastodon the person's Mastodon handle" do
      expect(mastodon_status("hi @{ada}!")).to eq("hi @ada@ruby.social!")
    end

    it "sends Bluesky the person's Bluesky handle" do
      expect(bluesky_record("hi @{ada}!").fetch("text")).to eq("hi @ada.bsky.social!")
    end

    it "marks the Bluesky handle with a mention facet naming the stored DID" do
      expect(bluesky_record("🎉 @{ada}").fetch("facets")).to eq([mention_facet("did:plc:ada-lovelace", 5, 21)])
    end

    it "keeps mention, link and tag facets apart and in order" do
      expect(bluesky_record("@{ada} #ruby http://shares.localhost").fetch("facets"))
        .to eq([mention_facet("did:plc:ada-lovelace", 0, 16), tag_facet("ruby", 17, 22),
                facet("http://shares.localhost", 23, 46)])
    end

    it "lets no facet overlap a mention" do
      facets = bluesky_record("http://shares.localhost/@{ada}").fetch("facets")

      expect(facets).to eq([mention_facet("did:plc:ada-lovelace", 24, 40)])
    end

    it "names someone with no Bluesky handle and still sends", :aggregate_failures do
      create(:person, key: "grace", name: "Grace Hopper")
      record = bluesky_record("thanks @{grace}")

      expect(record.fetch("text")).to eq("thanks Grace Hopper")
      expect(record).not_to have_key("facets")
    end

    it "names someone with no Mastodon handle and still sends" do
      create(:person, :bluesky, key: "grace", name: "Grace Hopper", mastodon_handle: nil)

      expect(mastodon_status("thanks @{grace}")).to eq("thanks Grace Hopper")
    end

    it "sends a handle changed after the post was queued in its new form" do
      social_post = queued(parts: ["hi @{ada}"])
      person_mutations.update(ada.id, mastodon_handle: "@ada@hachyderm.io")

      expect(sent_status(social_post)).to eq("hi @ada@hachyderm.io")
    end

    it "sends the key in place of someone taken out of the directory" do
      person_mutations.delete(ada.id)

      expect(mastodon_status("hi @{ada}")).to eq("hi ada")
    end

    it "sends empty braces as they are written" do
      expect(mastodon_status("hi @{}")).to eq("hi @{}")
    end

    it "measures the limit on the text each network gets" do
      social_post = queued(targets: %w[bluesky], parts: ["#{'a' * 290} @{ada}"])
      deliver(social_post, "bluesky")

      expect(delivery(social_post, "bluesky")).to have_attributes(failed: true, error: /over the bluesky limit/)
    end
  end

  describe "a post that links to the site" do
    let(:post_url) { "https://aaronmallen.me/writing/hello" }

    before do
      stub_bluesky
      resolves_publicly("aaronmallen.me")
      stub_request(:get, %r{\Ahttps://aaronmallen\.me/}).to_return(status: 404)
    end

    def bluesky_text(social_post)
      deliver(social_post, "bluesky")

      bluesky_writes.first.dig("record", "text")
    end

    def mastodon_text(social_post)
      sent = []
      stub_request(:post, statuses).to_return do |request|
        sent << JSON.parse(request.body).fetch("status")
        json_response(id: "1", url: "https://ruby.social/@ada/1")
      end
      deliver(social_post, "mastodon")

      sent.first
    end

    it "tags the link for each network", :aggregate_failures do
      social_post = queued(targets: %w[mastodon bluesky], parts: ["read #{post_url}."])

      expect(mastodon_text(social_post)).to eq("read #{post_url}?ref=mastodon.")
      expect(bluesky_text(social_post)).to eq("read #{post_url}?ref=bluesky.")
    end

    it "marks the tagged link with a Bluesky facet" do
      expect(facets_for("see #{post_url}")).to eq([facet("#{post_url}?ref=bluesky", 4, 52)])
    end

    it "keeps the stored text untagged" do
      social_post = queued(targets: %w[mastodon bluesky], parts: ["read #{post_url}"])
      mastodon_text(social_post)
      bluesky_text(social_post)

      expect(reloaded(social_post).parts.map(&:body)).to eq(["read #{post_url}"])
    end

    it "swaps a link to another site for its aa.cool link and keeps the site's long", :aggregate_failures do
      text = mastodon_text(queued(parts: ["see https://github.com/ada and #{post_url}"]))
      code = short_code("https://github.com/ada")

      expect(code).to match(/\A[a-z2-9]{3}\z/)
      expect(text).to eq("see http://shares.localhost/#{code} and #{post_url}?ref=mastodon")
    end

    it "leaves the new link's title to a job, so the page cannot hold up delivery", :aggregate_failures, :commits do
      mastodon_text(queued(parts: ["see https://github.com/ada"]))

      expect(a_request(:get, "https://github.com/ada")).not_to have_been_made
      expect(Shares::Jobs::FetchShortLinkTitle.jobs.size).to eq(1)
    end

    it "sends a link already on aa.cool as typed" do
      expect(mastodon_text(queued(parts: ["see http://shares.localhost/talk"]))).to eq("see http://shares.localhost/talk")
    end

    it "reuses the code of a link I shortened before", :aggregate_failures do
      Shares::Slice["operations.create_short_link"].call(destination: "https://github.com/ada", code: "gh")

      expect(mastodon_text(queued(parts: ["see https://github.com/ada"]))).to eq("see http://shares.localhost/gh")
      expect(Shares::Slice["relations.short_links"].count).to eq(1)
    end

    it "gives each network the same new code", :aggregate_failures do
      social_post = queued(targets: %w[mastodon bluesky], parts: ["see https://github.com/ada"])
      sent = [mastodon_text(social_post), bluesky_text(social_post)]

      expect(sent.uniq.size).to eq(1)
      expect(Shares::Slice["relations.short_links"].count).to eq(1)
    end

    it "keeps the long link in the stored parts" do
      social_post = queued(targets: %w[mastodon bluesky], parts: ["see https://github.com/ada"])
      mastodon_text(social_post)
      bluesky_text(social_post)

      expect(reloaded(social_post).parts.map(&:body)).to eq(["see https://github.com/ada"])
    end

    it "marks the aa.cool link with a Bluesky facet" do
      facets = facets_for("see https://github.com/ada")
      code = short_code("https://github.com/ada")

      expect(facets).to eq([facet("http://shares.localhost/#{code}", 4, 31)])
    end

    {
      "no path" => ["https://aaronmallen.me", "https://aaronmallen.me/?ref=mastodon"],
      "a query" => ["https://aaronmallen.me/writing?page=2", "https://aaronmallen.me/writing?page=2&ref=mastodon"],
      "a fragment" => ["https://aaronmallen.me/writing/hello#end", "https://aaronmallen.me/writing/hello?ref=mastodon#end"],
      "a ref of its own" => ["https://aaronmallen.me/writing/hello?ref=talk", "https://aaronmallen.me/writing/hello?ref=talk"],
    }.each do |what, (written, sent)|
      it "tags a link with #{what} as #{sent}" do
        expect(mastodon_text(queued(parts: ["see #{written}"]))).to eq("see #{sent}")
      end
    end

    it "keeps a mention after a tagged link marked over the right bytes" do
      create(:person, key: "ada", bluesky_handle: "ada.bsky.social", bluesky_did: "did:plc:ada-lovelace")

      expect(facets_for("#{post_url} @{ada}").last).to include("index" => { "byteEnd" => 65, "byteStart" => 49 })
    end

    it "refuses a part the tag pushes over the limit" do
      social_post = queued(targets: %w[bluesky], parts: ["#{'a' * (299 - post_url.size)} #{post_url}"])
      deliver(social_post, "bluesky")

      expect(delivery(social_post,
                      "bluesky")).to have_attributes(failed: true, error: "Part 1 is over the bluesky limit")
    end

    it "sends a part the tag brings right up to the limit" do
      expect(bluesky_text(queued(targets: %w[bluesky], parts: ["#{'a' * (287 - post_url.size)} #{post_url}"])))
        .to end_with("?ref=bluesky")
    end
  end

  describe "two accounts on one network" do
    let(:other) { connect_another_mastodon }
    let(:other_statuses) { "https://hachyderm.io/api/v1/statuses" }
    let(:social_post) { queued }

    before do
      other
      stub_mastodon("110")
      stub_request(:post, other_statuses).to_return(**json_response(id: "220", url: "https://hachyderm.io/@ada/220"))
    end

    def deliver_other = job.perform(social_post.id, other.id)

    it "posts as the account its job names", :aggregate_failures do
      deliver_other

      expect(a_request(:post, other_statuses).with(headers: { "Authorization" => "Bearer other" })).to have_been_made
      expect(a_request(:post, statuses)).not_to have_been_made
    end

    it "keeps a delivery for each account" do
      deliver(social_post, "mastodon")
      deliver_other

      expect(reloaded(social_post).deliveries.to_h { [it.connection_id, it.remote_ids] })
        .to eq(social_account("mastodon").id => %w[110], other.id => %w[220])
    end

    it "sends each account a key of its own" do
      deliver_other

      key = "social-post-#{social_post.id}-#{other.id}-1"

      expect(a_request(:post, other_statuses).with(headers: { "Idempotency-Key" => key })).to have_been_made
    end

    it "keeps the social post scheduled until every account has sent it" do
      deliver(social_post, "mastodon")

      expect(reloaded(social_post).status).to eq("scheduled")
    end

    it "counts the social post posted once every account has sent it" do
      deliver(social_post, "mastodon")
      deliver_other

      expect(reloaded(social_post).status).to eq("posted")
    end

    it "counts the social post posted once the one account it picked has sent it" do
      social_post_mutations.update(social_post.id, connection_ids: [other.id])
      deliver_other

      expect(reloaded(social_post).status).to eq("posted")
    end

    it "sends nothing to an account the social post did not pick", :aggregate_failures do
      social_post_mutations.update(social_post.id, connection_ids: [other.id])
      deliver(social_post, "mastodon")

      expect(a_request(:post, statuses)).not_to have_been_made
      expect(reloaded(social_post).deliveries).to be_empty
    end
  end

  describe "two Bluesky accounts" do
    let(:other) { connect_another_bluesky }
    let(:social_post) { queued(targets: %w[bluesky]) }

    before do
      other
      stub_bluesky
    end

    it "signs in as the account its job names" do
      job.perform(social_post.id, other.id)

      expect(a_request(:post, bluesky_url("com.atproto.server.createSession"))
        .with(body: { identifier: "grace.example", password: "other" })).to have_been_made
    end
  end

  describe "an account disconnected before its job runs" do
    let(:social_post) { queued }
    let!(:gone) { social_account("mastodon") }

    before { Services::Slice["repos.connection_mutations"].delete(gone.id) }

    it "sends nothing and opens no delivery", :aggregate_failures do
      job.perform(social_post.id, gone.id)

      expect(a_request(:any, /ruby\.social/)).not_to have_been_made
      expect(reloaded(social_post).deliveries).to be_empty
    end

    it "gives up quietly" do
      expect { described_class.sidekiq_retries_exhausted_block.call({ "args" => [social_post.id, gone.id] }, nil) }
        .not_to raise_error
    end
  end

  describe "a picked account disconnected before send time" do
    let(:social_post) { queued(targets: %w[mastodon bluesky]) }

    before do
      stub_bluesky
      social_post_mutations.update(social_post.id, connection_ids: %w[mastodon bluesky].map { social_account(it).id })
      Services::Slice["repos.connection_mutations"].delete(social_account("mastodon").id)
    end

    def unconnected = reloaded(social_post).deliveries.reject(&:connection_id)

    it "fails the gone account's network once the rest have sent", :aggregate_failures do
      deliver(social_post, "bluesky")

      expect(reloaded(social_post).status).to eq("posted")
      expect(unconnected.map { [it.network, it.failed, it.error] })
        .to eq([["mastodon", true, "No mastodon account is connected"]])
    end

    it "fails the gone account's network only once, however often the post settles" do
      deliver(social_post, "bluesky")
      deliver(social_post, "bluesky")
      exhaust(social_post, "bluesky")

      expect(unconnected.size).to eq(1)
    end

    it "fails nothing while the rest are still sending" do
      stub_request(:post, bluesky_url("com.atproto.repo.putRecord")).to_return(status: 502)
      refused(social_post, "bluesky")

      expect(unconnected).to be_empty
    end
  end

  describe "a network the social post does not target" do
    it "sends nothing and opens no delivery", :aggregate_failures do
      social_post = queued(targets: %w[mastodon])
      deliver(social_post, "bluesky")

      expect(delivery(social_post, "bluesky")).to be_nil
      expect(a_request(:any, /bsky/)).not_to have_been_made
    end
  end

  describe "a social post that is not due" do
    before { stub_mastodon("110") }

    {
      "a draft" => { status: "draft" },
      "scheduled for later" => { posted_at: Time.now + 3600 },
    }.each do |what, attrs|
      it "sends nothing and opens no delivery for #{what}", :aggregate_failures do
        social_post = queued
        social_post_mutations.update(social_post.id, **attrs)
        deliver(social_post, "mastodon")

        expect(delivery(social_post, "mastodon")).to be_nil
        expect(a_request(:post, statuses)).not_to have_been_made
      end
    end

    it "sends nothing for a social post already posted" do
      social_post = create(:social_post, :posted, targets: %w[mastodon])
      deliver(social_post, "mastodon")

      expect(a_request(:post, statuses)).not_to have_been_made
    end
  end

  describe "a social post that is gone" do
    it "finishes quietly" do
      expect { job.perform(0, "mastodon") }.not_to raise_error
    end

    it "gives up quietly" do
      expect { described_class.sidekiq_retries_exhausted_block.call({ "args" => [0, "mastodon"] }, nil) }
        .not_to raise_error
    end
  end

  describe "the last retry" do
    let(:social_post) { queued }

    before do
      stub_request(:post, statuses).to_return(status: 429)
      exhaust(social_post, "mastodon", failing(social_post, "mastodon"))
    end

    it "marks the delivery failed and keeps the error Mastodon gave" do
      expect(delivery(social_post, "mastodon"))
        .to have_attributes(failed: true, error: "Mastodon rate limited POST /api/v1/statuses")
    end

    it "counts the social post posted once the last network gives up" do
      expect(reloaded(social_post).status).to eq("posted")
    end
  end

  describe "the statements it issues" do
    let(:runs) { (1..3).map { statements(it) } }

    before { stub_bluesky }

    def statements(parts)
      social_post = queued(targets: %w[bluesky mastodon], parts: Array.new(parts) { "part #{it + 1}" })
      (1...parts).each { stub_bluesky_parent(bluesky_uri(rkey(social_post, it))) }
      stub_mastodon(*(1..parts).map(&:to_s))

      counting { %w[bluesky mastodon].each { deliver(social_post, it) } }
    end

    it "adds the same number of statements for each extra part" do
      one, two, three = runs.map(&:size)

      expect(three - two).to eq(two - one)
    end

    it "reads no more for three parts than for one" do
      expect(runs.map { it.grep(/\ASELECT/).size }.uniq).to have(1).item
    end
  end

  describe "a post to LinkedIn" do
    before do
      connect_linkedin
      stub_linkedin("urn:li:share:7")
    end

    let(:social_post) { queued(targets: %w[linkedin], parts: %w[hello]) }

    def commentary(social_post)
      sent = []
      stub_request(:post, linkedin_posts).to_return do |request|
        sent << JSON.parse(request.body).fetch("commentary")
        { status: 201, headers: { "x-restli-id" => "urn:li:share:7" } }
      end
      deliver(social_post, "linkedin")

      sent.first
    end

    it "posts the text publicly as the member" do
      deliver(social_post, "linkedin")

      expect(a_request(:post, linkedin_posts).with(body: hash_including(
        "author" => "urn:li:person:member-ada", "commentary" => "hello", "visibility" => "PUBLIC",
        "lifecycleState" => "PUBLISHED",
      ))).to have_been_made
    end

    it "sends the token and the version headers LinkedIn asks for" do
      deliver(social_post, "linkedin")

      headers = { "Authorization" => "Bearer li-token", "LinkedIn-Version" => LinkedIn::Client::VERSION,
                  "X-Restli-Protocol-Version" => "2.0.0" }

      expect(a_request(:post, linkedin_posts).with(headers:)).to have_been_made
    end

    it "records the post's id and links to it" do
      deliver(social_post, "linkedin")

      expect(delivery(social_post, "linkedin")).to have_attributes(
        remote_ids: %w[urn:li:share:7], remote_url: "https://www.linkedin.com/feed/update/urn:li:share:7/", error: nil,
      )
    end

    it "escapes the characters LinkedIn reserves and leaves hashtags alone" do
      expect(commentary(queued(targets: %w[linkedin], parts: ["a (b) [c] *d* #ruby"])))
        .to eq("a \\(b\\) \\[c\\] \\*d\\* #ruby")
    end

    it "prints a mentioned person's name" do
      create(:person, key: "ada", name: "Ada Lovelace", mastodon_handle: "@ada@ruby.social")

      expect(commentary(queued(targets: %w[linkedin], parts: ["hi @{ada}"]))).to eq("hi Ada Lovelace")
    end
  end

  describe "a thread to LinkedIn" do
    let(:social_post) { queued(targets: %w[linkedin], parts: %w[one two three]) }

    before do
      connect_linkedin
      stub_linkedin("urn:li:share:7")
    end

    it "sends one post with the parts split by a blank line", :aggregate_failures do
      deliver(social_post, "linkedin")

      expect(a_request(:post, linkedin_posts)).to have_been_made.once
      expect(a_request(:post, linkedin_posts).with(body: hash_including("commentary" => "one\n\ntwo\n\nthree")))
        .to have_been_made
    end

    it "counts the social post posted once its one post is out" do
      deliver(social_post, "linkedin")

      expect(reloaded(social_post).status).to eq("posted")
    end

    it "refuses a thread whose parts fit but whose joined text does not", :aggregate_failures do
      social_post = queued(targets: %w[linkedin], parts: ["a" * 1600, "b" * 1600])
      deliver(social_post, "linkedin")

      expect(a_request(:post, linkedin_posts)).not_to have_been_made
      expect(delivery(social_post, "linkedin")).to have_attributes(failed: true, error: /over the linkedin limit/)
    end
  end

  describe "photos to LinkedIn" do
    let(:photos) { Array.new(5) { create(:photo) } }
    let(:posts) { [] }

    def content = posts.first["content"]

    def held(*alts, part: 1, from: 0)
      alts.each_with_index.map { |alt, index| { part:, key: photos[from + index].key, alt: } }
    end

    def image(index, alt = nil) = { "altText" => alt, "id" => "urn:li:image:#{index}" }.compact

    def scopes = Spec::LinkedInAccounts::SCOPES

    def store(photo, body = "photo-#{photo.key}", type: "image/jpeg")
      stub_request(:get, media_store_url(photo.key)).to_return(body:, headers: { "Content-Type" => type })
    end

    def with_photos(photos, parts: %w[one])
      social_post_mutations.create_with_parts(targets: %w[linkedin], parts:, photos:, status: "scheduled",
                                              posted_at: Time.now - 60)
    end

    before do
      connect_media_store
      connect_linkedin(scopes:)
      stub_linkedin_images
      photos.each { store(it) }
      stub_request(:post, linkedin_posts).to_return do |request|
        posts << JSON.parse(request.body)
        { status: 201, headers: { "x-restli-id" => "urn:li:share:7" } }
      end
    end

    it "shows one photo as the post's image, with its alt text" do
      deliver(with_photos(held("A cat")), "linkedin")

      expect(content).to eq("media" => image(1, "A cat"))
    end

    it "shows several photos in order, each with its alt text" do
      deliver(with_photos(held("A cat", "A dog")), "linkedin")

      expect(content).to eq("multiImage" => { "images" => [image(1, "A cat"), image(2, "A dog")] })
    end

    it "leaves the alt text out for a photo with none" do
      deliver(with_photos(held(nil)), "linkedin")

      expect(content).to eq("media" => image(1))
    end

    it "starts each upload for the member" do
      deliver(with_photos(held(nil)), "linkedin")

      body = { initializeUploadRequest: { owner: "urn:li:person:member-ada" } }

      expect(a_request(:post, linkedin_images).with(body:, headers: { "Authorization" => "Bearer li-token" }))
        .to have_been_made
    end

    it "puts the stored bytes to the upload URL under their type" do
      deliver(with_photos(held(nil)), "linkedin")

      headers = { "Authorization" => "Bearer li-token", "Content-Type" => "image/jpeg" }

      expect(a_request(:put, linkedin_upload_url(1)).with(body: "photo-#{photos[0].key}", headers:))
        .to have_been_made
    end

    it "sends a thread's photos on its one post, up to four" do
      deliver(with_photos(held(nil, nil, nil) + held(nil, nil, part: 2, from: 3), parts: %w[one two]), "linkedin")

      expect(content.dig("multiImage", "images").map { it["id"] }).to eq((1..4).map { "urn:li:image:#{it}" })
    end

    it "turns a WebP photo into a JPEG, since LinkedIn takes none" do
      store(photos[0], Vips::Image.black(8, 8).write_to_buffer(".webp"), type: "image/webp")
      deliver(with_photos(held(nil)), "linkedin")

      expect(a_request(:put, linkedin_upload_url(1)).with(headers: { "Content-Type" => "image/jpeg" }))
        .to have_been_made
    end

    it "sends no content and uploads nothing for a post without photos", :aggregate_failures do
      deliver(with_photos([]), "linkedin")

      expect(posts.first).not_to have_key("content")
      expect(a_request(:post, linkedin_images)).not_to have_been_made
    end

    it "keeps the error and posts nothing when LinkedIn starts no upload", :aggregate_failures do
      stub_request(:post, linkedin_images).to_return(**json_response(value: {}))
      social_post = with_photos(held(nil))
      refused(social_post, "linkedin")

      expect(delivery(social_post, "linkedin").error).to include("without an image and an upload URL")
      expect(posts).to be_empty
    end

    it "retries when an upload times out, since nothing is posted yet" do
      stub_request(:put, linkedin_upload_url(1)).to_raise(Net::ReadTimeout)

      expect { deliver(with_photos(held(nil)), "linkedin") }.to raise_error(described_class::NetworkUnavailable)
    end

    context "with leave to read the member's posts" do
      def scopes = %w[openid profile w_member_social r_member_social]
      let(:social_post) { with_photos(held(nil)) }

      before do
        stub_request(:post, linkedin_posts).to_raise(Net::ReadTimeout)
        refused(social_post, "linkedin")
        stub_linkedin_recent("one")
      end

      it "uploads nothing again on a retry that finds the post already out" do
        deliver(social_post, "linkedin")

        expect(a_request(:post, linkedin_images)).to have_been_made.once
      end
    end
  end

  describe "one post to Mastodon, Bluesky and LinkedIn" do
    let(:social_post) { queued(targets: %w[mastodon bluesky linkedin], parts: %w[hello]) }
    let(:urls) do
      [
        "https://ruby.social/@ada/110", %r{\Ahttps://bsky.app/profile/ada.example/post/},
        "https://www.linkedin.com/feed/update/urn:li:share:7/",
      ]
    end

    before do
      connect_linkedin
      stub_mastodon("110")
      stub_bluesky
      stub_linkedin("urn:li:share:7")
    end

    it "sends to all three and links each delivery to its post", :aggregate_failures do
      %w[mastodon bluesky linkedin].each { deliver(social_post, it) }

      expect(reloaded(social_post).status).to eq("posted")
      expect(%w[mastodon bluesky linkedin].map { delivery(social_post, it).remote_url }).to match(urls)
    end
  end

  describe "a LinkedIn timeout" do
    let(:social_post) { queued(targets: %w[linkedin], parts: %w[one two]) }

    before { stub_request(:post, linkedin_posts).to_raise(Net::ReadTimeout) }

    context "without leave to read the member's posts" do
      before { connect_linkedin }

      it "fails for good in place of retrying", :aggregate_failures do
        expect { deliver(social_post, "linkedin") }.not_to raise_error
        expect(delivery(social_post, "linkedin")).to have_attributes(failed: true, error: /timed out/)
      end

      it "retries when the request never reached LinkedIn" do
        stub_request(:post, linkedin_posts).to_timeout

        expect { deliver(social_post, "linkedin") }.to raise_error(described_class::NetworkUnavailable)
      end
    end

    context "with leave to read the member's posts" do
      before do
        connect_linkedin(scopes: %w[openid profile w_member_social r_member_social])
        refused(social_post, "linkedin")
      end

      it "retries" do
        expect(delivery(social_post, "linkedin")).to have_attributes(failed: false, error: /timed out/)
      end

      it "records the post it finds on the retry and posts nothing more", :aggregate_failures do
        stub_linkedin_recent("other", "one\n\ntwo")
        deliver(social_post, "linkedin")

        expect(a_request(:post, linkedin_posts)).to have_been_made.once
        expect(delivery(social_post, "linkedin")).to have_attributes(remote_ids: %w[urn:li:share:1], error: nil)
      end

      it "matches a post LinkedIn hands back escaped and with hashtag templates" do
        social_post = queued(targets: %w[linkedin], parts: ["(a) #ruby"])
        refused(social_post, "linkedin")
        stub_linkedin_recent("\\(a\\) {hashtag|\\#|ruby}")
        deliver(social_post, "linkedin")

        expect(delivery(social_post, "linkedin").remote_ids).to eq(%w[urn:li:share:0])
      end

      it "posts on the retry when no recent post holds the text" do
        stub_linkedin_recent("other")
        stub_linkedin("urn:li:share:9")
        deliver(social_post, "linkedin")

        expect(delivery(social_post, "linkedin").remote_ids).to eq(%w[urn:li:share:9])
      end
    end
  end

  describe "a claimed LinkedIn delivery" do
    let(:social_post) { queued(targets: %w[linkedin], parts: %w[hello]) }

    before do
      connect_linkedin(scopes: %w[openid profile w_member_social r_member_social])
      now = Time.now
      social_post_mutations.claim_delivery(social_post.id, social_account("linkedin"), due_by: now, stale_before: now)
      stub_linkedin_recent("hello")
      stub_linkedin("urn:li:share:9")
    end

    it "posts on the first send even when a recent post has the same text", :aggregate_failures do
      deliver(social_post, "linkedin")

      expect(a_request(:get, linkedin_posts).with(query: hash_including("q" => "author"))).not_to have_been_made
      expect(delivery(social_post, "linkedin").remote_ids).to eq(%w[urn:li:share:9])
    end

    it "checks recent posts first on a send after a failed attempt", :aggregate_failures do
      stub_request(:post, linkedin_posts).to_return(status: 500)
      refused(social_post, "linkedin")
      deliver(social_post, "linkedin")

      expect(a_request(:post, linkedin_posts)).to have_been_made.once
      expect(delivery(social_post, "linkedin").remote_ids).to eq(%w[urn:li:share:0])
    end
  end

  describe "a lapsed LinkedIn connection" do
    let(:social_post) { queued(targets: %w[linkedin], parts: %w[hello]) }

    let(:expired) { "LinkedIn connection expired at 2026-09-01T12:00:00Z; connect it again" }

    it "fails for good with an error that names the expiry", :aggregate_failures do
      connect_linkedin(expires_at: Time.utc(2026, 9, 1, 12).to_i)
      deliver(social_post, "linkedin")

      expect(a_request(:post, linkedin_posts)).not_to have_been_made
      expect(delivery(social_post, "linkedin")).to have_attributes(failed: true, error: expired)
    end

    it "fails for good when LinkedIn refuses the token" do
      connect_linkedin
      stub_request(:post, linkedin_posts).to_return(status: 401)
      deliver(social_post, "linkedin")

      expect(delivery(social_post, "linkedin")).to have_attributes(failed: true, error: /refused the access token/)
    end

    it "retries any other refusal" do
      connect_linkedin
      stub_request(:post, linkedin_posts).to_return(status: 500)

      expect { deliver(social_post, "linkedin") }.to raise_error(described_class::NetworkUnavailable)
    end
  end
end
