# frozen_string_literal: true

require "faraday"
require "time"

module Social
  module Bluesky
    class Client
      class Error < Social::Error; end
      class RateLimited < Error; end
      class Refused < Error; end

      Session = Data.define(:did, :handle, :token)

      APP_URL = "https://bsky.app"
      AT_URI = %r{\Aat://([^/]+)/([^/]+)/([^/]+)\z}
      COLLECTION = "app.bsky.feed.post"
      LIMIT = 300
      MAX_BYTES = 3000
      PUT_RECORD = "com.atproto.repo.putRecord"
      REFUSED = 400
      RESOLVE_HANDLE = "com.atproto.identity.resolveHandle"
      SEARCH_ACTORS = "app.bsky.actor.searchActorsTypeahead"
      TOO_MANY_REQUESTS = 429
      XRPC_PATH = "/xrpc"

      def initialize(handle:, password:, pds:, public_api:)
        @handle = handle
        @password = password
        @pds = pds
        @public_api = public_api
      end

      def configured? = !handle.nil? && !password.nil?

      def count(text) = text.to_s.grapheme_clusters.size

      def engagement(uri)
        return nil unless configured?

        body = query(public_api, "app.bsky.feed.getPosts", uris: [uri])
        found = body["posts"].to_a.first
        raise Error, "Bluesky returned no post for #{uri}" unless found

        Engagement.new(
          like_count: found["likeCount"].to_i,
          reply_count: found["replyCount"].to_i,
          repost_count: found["repostCount"].to_i,
        )
      end

      def inspect = "#<#{self.class.name} configured=#{configured?}>"

      def limit = LIMIT

      def max_bytes = MAX_BYTES

      def post(text, idempotency_key:, mentions: [], reply_to: nil)
        session = sign_in
        uri = write(record(text, mentions, reply_to, session), session, rkey(idempotency_key))

        RemotePost.new(id: uri, url: web_url(session.handle, uri))
      end

      def resolve(handle)
        query(public_api, RESOLVE_HANDLE, handle:)["did"] or raise Error, "Bluesky resolved #{handle} without a DID"
      rescue Refused
        nil
      end

      def search(text, limit:) = Actors.accounts(query(public_api, SEARCH_ACTORS, q: text, limit:))

      def within_limit?(text) = count(text) <= LIMIT && text.to_s.bytesize <= MAX_BYTES

      private

      attr_reader :handle, :password, :pds, :public_api

      def address(uri)
        match = AT_URI.match(uri.to_s) or raise Error, "#{uri} is not an at:// URI"

        { collection: match[2], repo: match[1], rkey: match[3] }
      end

      def error_message(nsid, response)
        return "Bluesky answered #{nsid} with #{response.body.class} instead of JSON" if response.success?

        ["Bluesky answered #{response.status} for #{nsid}", *reason(response.body)].join(": ")
      end

      def failure(nsid, response)
        return RateLimited.new("Bluesky rate limited #{nsid}") if response.status == TOO_MANY_REQUESTS

        (response.status == REFUSED ? Refused : Error).new(error_message(nsid, response))
      end

      def procedure(connection, nsid, token: nil, **payload)
        request(connection, :post, nsid, payload, token)
      end

      def query(connection, nsid, token: nil, **params)
        request(connection, :get, nsid, params, token)
      end

      def reason(body)
        return [] unless body.is_a?(Hash)

        body.values_at("error", "message").map { it.to_s.strip }.reject(&:empty?)
      end

      def record(text, mentions, reply_to, session)
        facets = Facets.for(text, mentions:)

        {
          "$type" => COLLECTION,
          createdAt: Time.now.utc.iso8601,
          facets: facets.empty? ? nil : facets,
          reply: reply_to && reply_ref(reply_to, session),
          text:,
        }.compact
      end

      def reply_ref(uri, session)
        parent = query(pds, "com.atproto.repo.getRecord", token: session.token, **address(uri))
        cid, at = parent.values_at("cid", "uri")
        raise Error, "Bluesky returned no CID for the parent post #{uri}" unless cid && at

        strong = { cid:, uri: at }
        { parent: strong, root: parent.dig("value", "reply", "root") || strong }
      end

      def request(connection, verb, nsid, body, token)
        response = connection.public_send(verb, "#{XRPC_PATH}/#{nsid}", body) do |http|
          http.headers["Authorization"] = "Bearer #{token}" if token
        end

        return response.body if response.success? && response.body.is_a?(Hash)

        raise failure(nsid, response)
      rescue Faraday::Error => e
        raise Error, "Bluesky request #{nsid} failed: #{e.message}"
      end

      def rkey(key) = Tid.for(key.part.id, key.part.created_at)

      def sign_in
        body = procedure(pds, "com.atproto.server.createSession", identifier: handle, password:)
        did, author, token = body.values_at("did", "handle", "accessJwt")
        raise Error, "Bluesky returned an incomplete session for #{handle}" unless did && author && token

        Session.new(did:, handle: author, token:)
      end

      def web_url(author, uri) = "#{APP_URL}/profile/#{author}/post/#{uri.split('/').last}"

      def write(record, session, rkey)
        payload = { collection: COLLECTION, record:, repo: session.did, rkey: }
        body = procedure(pds, PUT_RECORD, token: session.token, **payload)

        body["uri"] or raise Error, "Bluesky wrote a record for #{session.did} without a URI"
      end
    end
  end
end
