# frozen_string_literal: true

module Spec
  module GoogleAccounts
    DATA_TYPES = "https://health.googleapis.com/v4/users/me/dataTypes"
    GMAIL = "https://gmail.googleapis.com/gmail/v1/users/me"
    GMAIL_SCOPES = %w[openid https://www.googleapis.com/auth/gmail.modify].freeze
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

    def gmail_message(id, labels: %w[INBOX UNREAD], at: Time.now, parts: nil, **headers)
      headers = { From: "Ada Lovelace <ada@example.com>", Subject: "Engines", **headers }

      {
        id:, labelIds: labels, internalDate: (at.to_r * 1000).to_i.to_s,
        payload: {
          mimeType: "multipart/alternative", headers: headers.map { |name, value| { name:, value: } },
          parts: parts || [gmail_part("text/plain", "Hello there"), gmail_part("text/html", "<p>Hello there</p>")],
        },
      }
    end

    def gmail_part(type, text, charset: "UTF-8", filename: "")
      headers = [{ name: "Content-Type", value: "#{type}; charset=\"#{charset}\"" }]
      data = Base64.urlsafe_encode64(text.dup.force_encoding(Encoding::BINARY), padding: false)

      { mimeType: type, filename:, headers:, body: { data: } }
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

    def stub_gmail(history: [], history_id: "200", labels: [], profile: "100", threads: {})
      stub_request(:get, "#{GMAIL}/profile").to_return(google_health_json({ historyId: profile }))
      stub_request(:get, "#{GMAIL}/labels").to_return(google_health_json({ labels: }))
      pages = { history: [{ messages: history.map { |id| { threadId: id } } }], historyId: history_id }
      stub_request(:get, %r{\A#{GMAIL}/history\?}o).to_return(google_health_json(pages))
      threads.each { |id, messages| stub_gmail_thread(id, messages) }
    end

    def stub_gmail_thread(id, messages)
      stub_request(:get, %r{\A#{GMAIL}/threads/#{id}\?})
        .to_return(google_health_json({ id:, messages: messages.map { it.merge(threadId: id) } }))
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
