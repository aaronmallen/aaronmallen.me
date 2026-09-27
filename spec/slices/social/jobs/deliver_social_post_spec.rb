# frozen_string_literal: true

RSpec.describe Social::Jobs::DeliverSocialPost do
  subject(:job) { described_class.new }

  let(:social_post_repo) { Social::Slice["repos.social_post_repo"] }

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

  def key(social_post, network, position) = "social-post-#{social_post.id}-#{network}-#{position}"

  def queued(targets: %w[mastodon], parts: %w[one])
    social_post_repo.create_with_parts(targets:, parts:, status: "scheduled", posted_at: Time.now - 60)
  end

  def refused(social_post, network)
    deliver(social_post, network)
  rescue described_class::NetworkUnavailable
    nil
  end

  def reloaded(social_post) = social_post_repo.by_id(social_post.id)

  def rkey(social_post, position)
    part = social_post.parts.find { it.position == position }

    Social::Bluesky::Tid.for(part.id, part.created_at)
  end

  def statuses = SocialNetworks::MASTODON_STATUSES

  describe "a post to Mastodon" do
    before { stub_mastodon("110") }

    let(:social_post) { queued(parts: %w[hello]) }

    it "posts the part publicly" do
      deliver(social_post, "mastodon")

      expect(a_request(:post, statuses).with(body: { status: "hello", visibility: "public" })).to have_been_made
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

    it "writes the record to the author's repo under the TID for the part" do
      deliver(social_post, "bluesky")

      expect(bluesky_writes.first).to include("collection" => "app.bsky.feed.post",
                                              "repo" => SocialNetworks::BLUESKY_DID,
                                              "rkey" => rkey(social_post, 1))
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

    it "sends no facets for text without links" do
      deliver(queued(targets: %w[bluesky], parts: %w[hello]), "bluesky")

      expect(bluesky_writes.first.fetch("record")).not_to have_key("facets")
    end

    it "sends no reply for the first part" do
      deliver(social_post, "bluesky")

      expect(bluesky_writes.first.fetch("record")).not_to have_key("reply")
    end

    it "records the AT URI and the bsky.app URL" do
      deliver(social_post, "bluesky")
      tid = rkey(social_post, 1)

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

      query = { collection: "app.bsky.feed.post", repo: SocialNetworks::BLUESKY_DID, rkey: rkey(social_post, 1) }

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
    let(:social_post) { queued(targets: %w[bluesky], parts: %w[one two]) }

    before do
      stub_bluesky_session
      stub_bluesky_parent(bluesky_uri(rkey(social_post, 1)))
      stub_request(:post, bluesky_url("com.atproto.repo.putRecord")).to_return(status: 500)
    end

    it "writes the part again under the key the failed try sent" do
      refused(social_post, "bluesky")
      stub_bluesky_writes
      deliver(social_post, "bluesky")

      expect(a_request(:post, bluesky_url("com.atproto.repo.putRecord"))
        .with(body: hash_including("rkey" => rkey(social_post, 1)))).to have_been_made.twice
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

  describe "a network with no credentials" do
    {
      "nothing set" => {},
      "an instance URL that won't parse" => { access_token: "token", url: "https://ruby social" },
    }.each do |what, mastodon|
      it "marks the delivery failed for good with #{what}" do
        connect_social_networks(mastodon:)
        social_post = queued
        deliver(social_post, "mastodon")

        expect(delivery(social_post, "mastodon")).to have_attributes(failed: true, error: "mastodon has no credentials")
      end
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
    let(:social_post) { queued(targets: %w[bluesky mastodon], parts: %w[one two three]) }

    before do
      stub_bluesky
      stub_bluesky_parent(bluesky_uri(rkey(social_post, 1)))
      stub_bluesky_parent(bluesky_uri(rkey(social_post, 2)))
      stub_mastodon("1", "2", "3")
    end

    it "posts three parts to two networks in twenty one statements" do
      sending = -> { %w[bluesky mastodon].each { deliver(social_post, it) } }

      expect(counting(&sending)).to have(21).items
    end
  end
end
