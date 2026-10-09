# frozen_string_literal: true

RSpec.describe Social::Jobs::DeliverSocialPost do
  subject(:job) { described_class.new }

  let(:social_post_mutations) { Social::Slice["repos.social_post_mutations"] }
  let(:social_post_queries) { Social::Slice["repos.social_post_queries"] }

  before { connect_social_networks }

  def deliver(social_post, network) = job.perform(social_post.id, network)

  def delivery(social_post, network) = reloaded(social_post).deliveries.find { it.network == network }

  def exhaust(social_post, network)
    described_class.sidekiq_retries_exhausted_block.call({ "args" => [social_post.id, network] }, nil)
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

  def key(social_post, network, position) = "social-post-#{social_post.id}-#{network}-#{position}"

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

    Social::Bluesky::Tid.for(part.id, part.created_at)
  end

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

        expect { deliver(social_post, "mastodon") }
          .to raise_error(described_class::NetworkUnavailable, "mastodon refused social post #{social_post.id}")
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

    let(:social_post) { queued(targets: %w[bluesky], parts: ["go 🎉 https://a.example"]) }

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
      other = queued(targets: %w[bluesky], parts: ["go 🎉 https://a.example"])
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
        .to include("$type" => "app.bsky.feed.post", "text" => "go 🎉 https://a.example",
                    "createdAt" => match(/\A\d{4}-\d{2}-\d{2}T/))
    end

    it "marks a link with a facet over its byte range" do
      deliver(social_post, "bluesky")

      expect(bluesky_writes.first.dig("record", "facets")).to eq([facet("https://a.example", 8, 25)])
    end

    {
      "stops a link at the paren the prose opened" =>
        ["see (https://a.example/Foo_(bar)).", "https://a.example/Foo_(bar)", 5, 32],
      "stops a link at the bracket the prose opened" =>
        ["see [https://a.example/post].", "https://a.example/post", 5, 27],
      "leaves trailing punctuation out of a link" => ["read https://a.example/post.", "https://a.example/post", 5, 27],
    }.each do |what, (text, url, start, finish)|
      it what do
        deliver(queued(targets: %w[bluesky], parts: [text]), "bluesky")

        expect(bluesky_writes.first.dig("record", "facets")).to eq([facet(url, start, finish)])
      end
    end

    it "marks every link in order and none in the middle of a word" do
      deliver(queued(targets: %w[bluesky], parts: ["xhttps://no.example https://a.example http://b.example/x"]),
              "bluesky")

      expect(bluesky_writes.first.dig("record", "facets").map { it.dig("features", 0, "uri") })
        .to eq(%w[https://a.example http://b.example/x])
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
      expect(facets_for("#ruby https://a.example #hanami"))
        .to eq([tag_facet("ruby", 0, 5), facet("https://a.example", 6, 23), tag_facet("hanami", 24, 31)])
    end

    it "marks no tag for a hash inside a link" do
      expect(facets_for("see https://example.com/#top")).to eq([facet("https://example.com/#top", 4, 28)])
    end

    it "marks no tag that runs into a link" do
      expect(facets_for("#see/https://a.example")).to eq([facet("https://a.example", 5, 22)])
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

    it "keeps the error when the parent comes back without a CID" do
      stub_request(:get, bluesky_url("com.atproto.repo.getRecord"))
        .with(query: hash_including({})).to_return(**json_response(uri: first))
      refused(social_post, "bluesky")

      expect(delivery(social_post, "bluesky").error).to eq("Bluesky returned no CID for the parent post #{first}")
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

      expect { deliver(social_post, "bluesky") }.to raise_error(described_class::NetworkUnavailable, /bluesky/)
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
      expect(bluesky_record("@{ada} #ruby https://a.example").fetch("facets"))
        .to eq([mention_facet("did:plc:ada-lovelace", 0, 16), tag_facet("ruby", 17, 22),
                facet("https://a.example", 23, 40)])
    end

    it "lets no facet overlap a mention" do
      facets = bluesky_record("https://a.example/@{ada}").fetch("facets")

      expect(facets).to eq([mention_facet("did:plc:ada-lovelace", 18, 34)])
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

    before { stub_bluesky }

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

    it "leaves links to other sites as written" do
      expect(mastodon_text(queued(parts: ["see https://example.com/post and #{post_url}"])))
        .to eq("see https://example.com/post and #{post_url}?ref=mastodon")
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

  describe "a network with no credentials" do
    it "marks the delivery failed for good with no Mastodon connection" do
      connect_social_networks(mastodon: {})
      social_post = queued
      deliver(social_post, "mastodon")

      expect(delivery(social_post, "mastodon")).to have_attributes(failed: true, error: "mastodon has no credentials")
    end

    it "asks nothing of Bluesky" do
      connect_social_networks(bluesky: {})
      deliver(queued(targets: %w[bluesky]), "bluesky")

      expect(a_request(:post, bluesky_url("com.atproto.server.createSession"))).not_to have_been_made
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
      refused(social_post, "mastodon")
      exhaust(social_post, "mastodon")
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
end
