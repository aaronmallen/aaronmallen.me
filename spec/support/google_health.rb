# frozen_string_literal: true

module Spec
  module GoogleHealth
    DATA_TYPES = "https://health.googleapis.com/v4/users/me/dataTypes"
    LISTS = %w[sleep daily-resting-heart-rate daily-heart-rate-variability exercise].freeze
    ROLLUPS = %w[steps active-zone-minutes].freeze

    def connect_google_health(revoked_at: nil)
      set_up_google_health_client
      Services::Slice["repos.connection_mutations"].add(
        provider: "google_health", account_id: "me", label: "Google account", revoked_at:,
        credentials: { access_token: "ya29.token", expires_at: Time.now.to_i + 3600, refresh_token: "1//refresh" },
      )
    end

    def google_civil(date) = { date: { year: date.year, month: date.month, day: date.day } }

    def google_date(date) = { year: date.year, month: date.month, day: date.day }

    def google_health_json(body) = { body: body.to_json, headers: { "Content-Type" => "application/json" } }

    def google_time(time) = time.utc.iso8601

    def set_up_google_health_client
      allow(Hanami.app.settings).to receive(:google_health)
        .and_return({ client_id: "google-id", client_secret: "google-secret" })
      Health::Slice.start(:google)
      client = Health::Providers::GoogleProvider.client(
        Hanami.app.settings, Health::Slice["services.repos.connection_queries"],
        Health::Slice["services.operations.change_connection"],
      )
      %w[google.client health.google.client].each { replace_component(it, client) }
    end

    def stub_google_health(**bodies)
      LISTS.each do |type|
        stub_request(:get, %r{\A#{DATA_TYPES}/#{type}/dataPoints\?})
          .to_return(google_health_json(bodies.fetch(type.tr("-", "_").to_sym, { dataPoints: [] })))
      end
      ROLLUPS.each do |type|
        stub_request(:post, "#{DATA_TYPES}/#{type}/dataPoints:dailyRollUp")
          .to_return(google_health_json(bodies.fetch(type.tr("-", "_").to_sym, { rollupDataPoints: [] })))
      end
    end
  end
end

RSpec.configure do |config|
  config.include Spec::GoogleHealth
end
