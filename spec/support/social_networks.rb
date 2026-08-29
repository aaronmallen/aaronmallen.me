# frozen_string_literal: true

module SocialNetworks
  BLUESKY_DID = "did:plc:ada"
  BLUESKY_PDS = "https://bsky.social/xrpc"
  BLUESKY_PUBLIC = "https://public.api.bsky.app/xrpc"
  MASTODON_STATUSES = "https://ruby.social/api/v1/statuses"

  def bluesky_uri(rkey) = "at://#{BLUESKY_DID}/app.bsky.feed.post/#{rkey}"

  def bluesky_url(name) = "#{BLUESKY_PDS}/#{name}"

  def bluesky_writes = @bluesky_writes ||= []

  def json_response(status: 200, **body)
    { status:, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end

  def stub_bluesky
    stub_bluesky_session
    stub_bluesky_writes
  end

  def stub_bluesky_engagement(uri, likes: 0, replies: 0, reposts: 0)
    stub_request(:get, "#{BLUESKY_PUBLIC}/app.bsky.feed.getPosts")
      .with(query: { uris: uri })
      .to_return(**json_response(posts: [{ likeCount: likes, replyCount: replies, repostCount: reposts, uri: }]))
  end

  def stub_bluesky_parent(uri, root: nil)
    stub_request(:get, bluesky_url("com.atproto.repo.getRecord"))
      .with(query: hash_including("rkey" => uri.split("/").last))
      .to_return(**json_response(cid: "cid-#{uri.split('/').last}", uri:, value: { reply: root && { root: } }.compact))
  end

  def stub_bluesky_session(**body)
    session = { accessJwt: "jwt", did: BLUESKY_DID, handle: "ada.example", **body }.compact

    stub_request(:post, bluesky_url("com.atproto.server.createSession")).to_return(**json_response(**session))
  end

  def stub_bluesky_writes
    stub_request(:post, bluesky_url("com.atproto.repo.putRecord")).to_return do |request|
      written = JSON.parse(request.body).tap { bluesky_writes << it }

      json_response(cid: "cid", uri: bluesky_uri(written.fetch("rkey")))
    end
  end

  def stub_mastodon(*ids)
    responses = ids.map { json_response(id: it, url: "https://ruby.social/@ada/#{it}") }

    stub_request(:post, MASTODON_STATUSES).to_return(*responses)
  end

  def stub_mastodon_engagement(id, likes: 0, replies: 0, reposts: 0)
    stub_request(:get, "#{MASTODON_STATUSES}/#{id}")
      .to_return(**json_response(id:, favourites_count: likes, replies_count: replies, reblogs_count: reposts))
  end
end

RSpec.configure do |config|
  config.include SocialNetworks
end
