# frozen_string_literal: true

require "digest"
require "sidekiq"

Sidekiq.testing!(:fake)

module Seeds
  HOUR = 60 * 60
  MINUTE = 60

  class IssueClient
    def initialize(issues)
      @issues = issues
    end

    def assigned_issues = @issues

    def configured? = true

    def issues(_urls) = []
  end

  class Network
    def initialize(name)
      @name = name
    end

    def configured? = true

    def post(_text, idempotency_key:, **)
      id = "#{@name}-#{idempotency_key.part.id}"

      Social::RemotePost.new(id:, url: "https://#{@name}.example.com/@ada/#{id}")
    end

    def resolve(handle) = "did:plc:#{Digest::SHA256.hexdigest(handle)[0, 24]}"

    def within_limit?(_text) = true
  end

  class SourcePages
    OK = 200

    def initialize(pages)
      @pages = pages
    end

    def fetch(url)
      Social::Webmentions::Client::Response.new(body: @pages.fetch(url), headers: {}, status: OK, url:)
    end
  end

  module_function

  def ago(days, hour: 10, minute: 0) = Blog::TimeZone.local_time(*date_parts(today - days), hour, minute)

  def date_parts(date) = [date.year, date.month, date.day]

  def networks = Blog::Types::NetworkName.values.to_h { [it, Network.new(it)] }.freeze

  def today = Blog::TimeZone.today

  def unwrap(result) = result.respond_to?(:value!) ? result.value! : result
end
