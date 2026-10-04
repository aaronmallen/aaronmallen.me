# frozen_string_literal: true

require "logger"

RSpec.describe Blog::Settings do
  describe "#reader_salt" do
    let(:app) { Hanami.app["settings"] }

    def settings_with(**values)
      described_class.new(Hanami::Settings::CompositeStore.new(values, Hanami.app.config.settings_store))
    end

    it "takes a salt of 64 characters or more that repeats no other secret" do
      expect(settings_with(reader_salt: "r" * 64).reader_salt).to eq("r" * 64)
    end

    it "refuses a salt under 64 characters" do
      expect { settings_with(reader_salt: "r" * 63) }.to raise_error(Hanami::Settings::InvalidSettingsError)
    end

    it "refuses a salt that repeats analytics_salt" do
      expect { settings_with(reader_salt: app.analytics_salt) }
        .to raise_error(Hanami::Settings::InvalidSettingsError, /reader_salt: must not repeat analytics_salt/)
    end

    it "refuses a salt that repeats app_secret" do
      expect { settings_with(reader_salt: app.app_secret) }
        .to raise_error(Hanami::Settings::InvalidSettingsError, /reader_salt: must not repeat app_secret/)
    end

    it "still refuses an analytics_salt that repeats app_secret" do
      expect { settings_with(analytics_salt: app.app_secret) }
        .to raise_error(Hanami::Settings::InvalidSettingsError, /analytics_salt: must not repeat app_secret/)
    end
  end

  describe "#redis" do
    let(:blanks) { [nil, "", " "] }
    let(:names) { %w[REDIS_CONNECT_TIMEOUT REDIS_RECONNECT_ATTEMPTS REDIS_TIMEOUT] }

    def client(redis = {})
      sidekiq = Sidekiq::Config.new
      sidekiq.logger = Logger.new(File::NULL)
      sidekiq.redis = redis
      config = sidekiq.new_redis_pool(1).with(&:config)

      {
        connect_timeout: config.connect_timeout,
        read_timeout: config.read_timeout,
        reconnect_attempts: (0..10).count { config.retriable?(it) },
        write_timeout: config.write_timeout,
      }
    end

    def client_for(environment, **variables)
      stub_const("ENV", ENV.to_h.merge(variables))
      client(redis_settings(redis_file(environment)))
    end

    def redis_file(environment)
      Hanami::Settings::FileStore.new(Hanami.app.root.join("config/settings/#{environment}.yml")).fetch(:redis)
    end

    def redis_settings(redis)
      store = Hanami::Settings::CompositeStore.new({ redis: }, Hanami.app.config.settings_store)

      described_class.new(store).redis.compact
    end

    %w[development production test].each do |environment|
      context "with the #{environment} settings" do
        it "hands the timeouts and reconnect attempts to Sidekiq's Redis client" do
          set = names.zip(%w[2.5 4 10]).to_h

          expect(client_for(environment, **set))
            .to eq(connect_timeout: 2.5, read_timeout: 10.0, reconnect_attempts: 4, write_timeout: 10.0)
        end

        it "keeps Sidekiq's own defaults when nothing is set", :aggregate_failures do
          defaults = client

          blanks.each { |blank| expect(client_for(environment, **names.to_h { [it, blank] })).to eq(defaults) }
        end
      end
    end

    it "takes numbers written straight into a settings file" do
      redis = { "connect_timeout" => 2, "reconnect_attempts" => 3, "timeout" => 7.5 }

      expect(client(redis_settings(redis)))
        .to eq(connect_timeout: 2.0, read_timeout: 7.5, reconnect_attempts: 3, write_timeout: 7.5)
    end

    it "refuses a timeout that is not a positive number" do
      expect { client_for("test", "REDIS_TIMEOUT" => "0") }.to raise_error(Hanami::Settings::InvalidSettingsError)
    end

    it "refuses a negative number of reconnect attempts" do
      expect { client_for("test", "REDIS_RECONNECT_ATTEMPTS" => "-1") }
        .to raise_error(Hanami::Settings::InvalidSettingsError)
    end
  end
end
