# frozen_string_literal: true

module Spec
  module GoogleAccounts
    DATA_TYPES = "https://health.googleapis.com/v4/users/me/dataTypes"
    HEALTH_SCOPES = %w[sleep activity_and_fitness health_metrics_and_measurements]
                    .map { "https://www.googleapis.com/auth/googlehealth.#{it}.readonly" }.freeze
    LISTS = %w[sleep daily-resting-heart-rate daily-heart-rate-variability exercise].freeze
    ROLLUPS = %w[steps active-zone-minutes].freeze

    def connect_google(account_id: "aaron@example.com", scopes: HEALTH_SCOPES, revoked_at: nil, token: "ya29.token")
      set_up_google_client
      Services::Slice["repos.connection_mutations"].add(
        provider: "google", account_id:, label: account_id, revoked_at:, scopes:,
        credentials: { access_token: token, expires_at: Time.now.to_i + 3600, refresh_token: "1//#{account_id}" },
      )
    end

    def google_civil(date) = { date: { year: date.year, month: date.month, day: date.day } }

    def google_date(date) = { year: date.year, month: date.month, day: date.day }

    def google_health_json(body) = { body: body.to_json, headers: { "Content-Type" => "application/json" } }

    def google_time(time) = time.utc.iso8601

    def set_up_google_client(credentials = { client_id: "google-id", client_secret: "google-secret" })
      allow(Hanami.app.settings).to receive(:google).and_return(credentials)
      ::Google::Slice.start(:google)
      client = ::Google::Providers::ClientProvider.client(
        Hanami.app.settings, ::Google::Slice["services.repos.connection_queries"],
        ::Google::Slice["services.operations.change_connection"],
      )
      %w[google.client google.google.client].each { replace_component(it, client) }
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
  config.include Spec::GoogleAccounts
end
