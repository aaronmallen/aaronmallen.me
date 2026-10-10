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

  describe "#data_key" do
    let(:app) { Hanami.app["settings"] }

    def settings_with(**values)
      described_class.new(Hanami::Settings::CompositeStore.new(values, Hanami.app.config.settings_store))
    end

    it "takes a key of 64 characters or more that repeats no other secret" do
      expect(settings_with(data_key: "d" * 64).data_key).to eq("d" * 64)
    end

    it "refuses to load when DATA_KEY is unset" do
      stub_const("ENV", ENV.to_h.except("DATA_KEY"))
      file = Hanami::Settings::FileStore.new(Hanami.app.root.join("config/settings/default.yml")).fetch(:data_key)

      expect { settings_with(data_key: file) }.to raise_error(Hanami::Settings::InvalidSettingsError, /data_key/)
    end

    it "refuses a key under 64 characters" do
      expect { settings_with(data_key: "d" * 63) }.to raise_error(Hanami::Settings::InvalidSettingsError, /data_key/)
    end

    it "refuses a key that repeats app_secret" do
      expect { settings_with(data_key: app.app_secret) }
        .to raise_error(Hanami::Settings::InvalidSettingsError, /must not repeat data_key/)
    end
  end

  describe "the committed secrets" do
    let(:committed) do
      %w[development test].to_h do |environment|
        store = Hanami::Settings::FileStore.new(Hanami.app.root.join("config/settings/#{environment}.yml"))
        [environment, described_class::SECRETS.to_h { [it, store.fetch(it)] }]
      end
    end

    let(:fresh) { { analytics_salt: "a" * 64, app_secret: "s" * 64, data_key: "d" * 64, reader_salt: "r" * 64 } }

    def settings_in(environment, **values)
      stub_const("ENV", ENV.to_h.merge("HANAMI_ENV" => environment))
      described_class.new(Hanami::Settings::CompositeStore.new(values, Hanami.app.config.settings_store))
    end

    it "takes secrets of its own in production" do
      expect(settings_in("production", **fresh).app_secret).to eq("s" * 64)
    end

    %w[development test].each do |source|
      described_class::SECRETS.each do |secret|
        it "refuses the #{secret} committed for #{source} in production" do
          expect { settings_in("production", **fresh, secret => committed[source][secret]) }
            .to raise_error(
              Hanami::Settings::InvalidSettingsError,
              /#{secret}: must not use a value committed for development or test/,
            )
        end
      end
    end

    it "refuses them in any environment but development and test" do
      expect { settings_in("staging", **fresh, app_secret: committed["development"][:app_secret]) }
        .to raise_error(Hanami::Settings::InvalidSettingsError, /app_secret: must not use a value committed/)
    end

    %w[development test].each do |environment|
      it "takes the secrets committed for development in #{environment}" do
        expect(settings_in(environment, **committed["development"]).app_secret)
          .to eq(committed["development"][:app_secret])
      end
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
        reconnect_waits: (0..10).filter_map { config.retriable?(it) },
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

    it "hands the timeouts and reconnect attempts to Sidekiq's Redis client" do
      set = names.zip(%w[2.5 4 10]).to_h

      expect(client_for("test", **set))
        .to eq(connect_timeout: 2.5, read_timeout: 10.0, reconnect_waits: [0, 0, 0, 0], write_timeout: 10.0)
    end

    it "hands a list of reconnect waits to Sidekiq's Redis client" do
      client = client_for("test", "REDIS_RECONNECT_ATTEMPTS" => "0.5, 1,2")

      expect(client[:reconnect_waits]).to eq([0.5, 1.0, 2.0])
    end

    it "keeps Sidekiq's own defaults when nothing is set", :aggregate_failures do
      defaults = client

      blanks.each { |blank| expect(client_for("test", **names.to_h { [it, blank] })).to eq(defaults) }
    end

    it "takes numbers written straight into a settings file" do
      redis = { "connect_timeout" => 2, "reconnect_attempts" => 3, "timeout" => 7.5 }

      expect(client(redis_settings(redis)))
        .to eq(connect_timeout: 2.0, read_timeout: 7.5, reconnect_waits: [0, 0, 0], write_timeout: 7.5)
    end

    it "takes a list of waits written straight into a settings file" do
      expect(client(redis_settings("reconnect_attempts" => [0.25, 1]))[:reconnect_waits]).to eq([0.25, 1.0])
    end

    it "reads a single number with a fraction as one wait" do
      expect(client_for("test", "REDIS_RECONNECT_ATTEMPTS" => "1.5")[:reconnect_waits]).to eq([1.5])
    end

    it "takes zero reconnect attempts" do
      expect(client_for("test", "REDIS_RECONNECT_ATTEMPTS" => "0")[:reconnect_waits]).to eq([])
    end

    it "refuses a timeout that is not a positive number" do
      expect { client_for("test", "REDIS_TIMEOUT" => "0") }.to raise_error(Hanami::Settings::InvalidSettingsError)
    end

    it "refuses a negative number of reconnect attempts" do
      expect { client_for("test", "REDIS_RECONNECT_ATTEMPTS" => "-1") }
        .to raise_error(Hanami::Settings::InvalidSettingsError)
    end

    it "refuses a list of reconnect waits that is not all numbers of zero or more", :aggregate_failures do
      ["0.5,-1", "1,,2", "1,2,", "1,soon", ","].each do |value|
        expect { client_for("test", "REDIS_RECONNECT_ATTEMPTS" => value) }
          .to raise_error(Hanami::Settings::InvalidSettingsError)
      end
    end
  end

  describe "#contact" do
    def contact_with(**variables)
      stub_const("ENV", ENV.to_h.merge(variables))
      file = Hanami::Settings::FileStore.new(Hanami.app.root.join("config/settings/default.yml")).fetch(:contact)
      store = Hanami::Settings::CompositeStore.new({ contact: file }, Hanami.app.config.settings_store)
      described_class.new(store).contact
    end

    it "takes a wait of nothing, which turns the wait off" do
      expect(contact_with("CONTACT_MINIMUM_SUBMIT_SECONDS" => "0")[:minimum_submit_seconds]).to eq(0)
    end

    it "refuses a negative wait" do
      expect { contact_with("CONTACT_MINIMUM_SUBMIT_SECONDS" => "-1") }
        .to raise_error(Hanami::Settings::InvalidSettingsError)
    end

    it "refuses an expiry under an hour" do
      expect { contact_with("CONTACT_STAMP_EXPIRY_HOURS" => "0") }.to raise_error(Hanami::Settings::InvalidSettingsError)
    end
  end

  describe "#web_threads" do
    def web_threads(threads)
      stub_const("ENV", ENV.to_h.merge("HANAMI_MAX_THREADS" => threads))
      file = Hanami::Settings::FileStore.new(Hanami.app.root.join("config/settings/default.yml")).fetch(:web_threads)
      store = Hanami::Settings::CompositeStore.new({ web_threads: file }, Hanami.app.config.settings_store)
      described_class.new(store).web_threads
    end

    it "refuses a count under one" do
      expect { web_threads("0") }.to raise_error(Hanami::Settings::InvalidSettingsError)
    end
  end
end
