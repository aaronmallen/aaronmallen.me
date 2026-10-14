# frozen_string_literal: true

require "faraday"
require "time"

module LinkedIn
  class Client
    Account = Data.define(:author, :expires_at, :reads_analytics, :reads_posts, :token)

    API_URL = "https://api.linkedin.com"
    HASHTAG = /\{hashtag\|\\#\|([^{}]*)\}/
    HEADERS = { "Accept" => "application/json", "X-Restli-Protocol-Version" => "2.0.0" }.freeze
    JOINER = "\n\n"
    LIMIT = 3000
    POST_ID_HEADER = "x-restli-id"
    POST_URL = "https://www.linkedin.com/feed/update/%s/"
    POSTS_PATH = "/rest/posts"
    PROVIDER = Blog::Types::ServiceProvider["linkedin"]
    READ_POSTS = "r_member_social"
    RECENT = 20
    RESERVED = /[\\|{}@\[\]()<>*_~]/
    TOO_MANY_REQUESTS = 429
    UNAUTHORIZED = 401
    VERSION = "202609"

    def initialize(auth:, http:, account: nil, retrying: false)
      @account = account
      @auth = auth
      @http = http
      @retrying = retrying
    end

    def configured? = @auth.configured? && !connections.empty?

    def count(text) = text.to_s.grapheme_clusters.size

    def engagement(id) = account.reads_analytics ? Analytics.read(id) { analytics(it) } : nil

    def find_post(text)
      return nil unless account.reads_posts

      wanted = text.to_s
      found = recent_posts.find { plain(it["commentary"]) == wanted }
      found && remote(found["id"].to_s)
    end

    def for(connection)
      credentials = connection.credentials
      account = Account.new(
        author: "urn:li:person:#{connection.account_id}", expires_at: credentials[:expires_at],
        reads_analytics: connection.scopes.to_a.include?(Analytics::SCOPE),
        reads_posts: connection.scopes.to_a.include?(READ_POSTS), token: credentials.fetch(:access_token),
      )

      self.class.new(account:, auth: @auth, http: @http)
    end

    def inspect = "#<#{self.class.name} configured=#{configured?}>"

    def joiner = JOINER

    def limit = LIMIT

    def max_bytes = nil

    def post(text, photos: [], **)
      found = @retrying && find_post(text)
      return found if found

      content = Images.content(photos, account.author, connection) { |route, run| request(route, timeout: Error, &run) }
      response = request("POST #{POSTS_PATH}") { connection.post(POSTS_PATH, payload(text, content)) }
      id = response.headers[POST_ID_HEADER].to_s
      raise Error, "LinkedIn answered #{POSTS_PATH} without a post ID" if id.empty?

      remote(id)
    end

    def reserved_per_url = nil

    def retrying = self.class.new(account:, auth: @auth, http: @http, retrying: true)

    def within_limit?(text) = count(text) <= LIMIT

    private

    def account = @account || raise(Error, "LinkedIn is not connected")

    def analytics(params)
      request("GET #{Analytics::PATH}") do
        connection.get(Analytics::PATH, params) { it.options.params_encoder = Analytics }
      end.body
    end

    def answered(route, response)
      return response if response.success?
      raise RateLimited, "LinkedIn rate limited #{route}" if response.status == TOO_MANY_REQUESTS
      raise Expired, "LinkedIn refused the access token for #{route}" if response.status == UNAUTHORIZED

      raise Error, "LinkedIn answered #{response.status} for #{route}"
    end

    def check_expiry
      expires_at = account.expires_at
      return unless expires_at && Time.at(expires_at.to_i) <= Time.now

      raise Expired, "LinkedIn connection expired at #{Time.at(expires_at.to_i).utc.iso8601}; connect it again"
    end

    def connection
      check_expiry
      @connection ||= @http.call(url: API_URL, headers: headers) do |faraday|
        faraday.request :json
        faraday.response :json
      end
    end

    def connections = services["repos.connection_queries"].for(PROVIDER)

    def escape(text) = text.to_s.gsub(RESERVED) { "\\#{it}" }

    def headers = HEADERS.merge("Authorization" => "Bearer #{account.token}", "LinkedIn-Version" => VERSION)

    def payload(text, content)
      {
        author: account.author, commentary: escape(text), content:, isReshareDisabledByAuthor: false,
        distribution: { feedDistribution: "MAIN_FEED", targetEntities: [], thirdPartyDistributionChannels: [] },
        lifecycleState: "PUBLISHED", visibility: "PUBLIC",
      }.compact
    end

    def plain(commentary) = commentary.to_s.gsub(HASHTAG, "#\\1").gsub(/\\(.)/m, "\\1")

    def recent_posts
      params = { author: account.author, count: RECENT, q: "author", sortBy: "CREATED" }
      response = request("GET #{POSTS_PATH}") do
        connection.get(POSTS_PATH, params) { it.headers["X-RestLi-Method"] = "FINDER" }
      end
      body = response.body
      raise Error, "LinkedIn answered #{POSTS_PATH} with #{body.class} instead of JSON" unless body.is_a?(Hash)

      body["elements"].to_a
    end

    def remote(id) = Social::Structs::RemotePost.new(id:, url: format(POST_URL, id))

    def request(route, timeout: account.reads_posts ? Error : Unsure)
      answered(route, yield)
    rescue Faraday::TimeoutError => e
      raise timeout, "LinkedIn request #{route} timed out: #{e.message}"
    rescue Faraday::Error, URI::Error => e
      raise Error, "LinkedIn request #{route} failed: #{e.message}"
    end

    def services = Hanami.app.slices[:services]
  end
end
