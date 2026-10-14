# frozen_string_literal: true

require "cgi"
require "faraday"

module LinkedIn
  module Analytics
    METRICS = { like_count: "REACTION", reply_count: "COMMENT", repost_count: "RESHARE" }.freeze
    PATH = "/rest/memberCreatorPostAnalytics"
    SCOPE = "r_member_postAnalytics"

    def self.count(body)
      raise Error, "LinkedIn answered #{PATH} with #{body.class} instead of JSON" unless body.is_a?(Hash)

      body["elements"].to_a.sum { it["count"].to_i }
    end
    private_class_method :count

    def self.decode(query) = Faraday::NestedParamsEncoder.decode(query)

    def self.encode(params) = params.map { |key, value| "#{key}=#{value}" }.join("&")

    def self.read(id)
      entity = "(#{id.include?(':ugcPost:') ? 'ugc' : 'share'}:#{CGI.escape(id)})"
      counts = METRICS.transform_values { count(yield(q: "entity", entity:, queryType: it)) }

      Social::Structs::Engagement.new(**counts)
    end
  end
end
