# frozen_string_literal: true

require "blog/secret_check"
require "ipaddr"
require "uri"

module Blog
  class Settings < Hanami::Settings
    DEFAULT_ANALYTICS_THROTTLE_LIMIT = 120
    DEFAULT_CLIENT_REGISTRATION_THROTTLE_LIMIT = 10
    DEFAULT_CLIENT_REGISTRATION_TOTAL_THROTTLE_LIMIT = 30
    DEFAULT_CONTACT_MINIMUM_SUBMIT_SECONDS = 3
    DEFAULT_CONTACT_STAMP_EXPIRY_HOURS = 24
    DEFAULT_CONTACT_THROTTLE_LIMIT = 3
    DEFAULT_CONTACT_TOTAL_THROTTLE_LIMIT = 20
    DEFAULT_STORE_REGION = "us-east-1"
    DEFAULT_THROTTLE_WINDOW_MINUTES = 60
    DEFAULT_WEBMENTION_THROTTLE_LIMIT = 30
    DEFAULT_WEBMENTION_TOTAL_THROTTLE_LIMIT = 100
    DEFAULT_WEB_THREADS = 5
    DEFAULT_WRITING_PATH = "/writing"
    MINUTES_BEFORE_THE_VISITOR_HASH_ROTATES = 1_440
    SECRETS = %i[reader_salt analytics_salt app_secret].freeze

    ApiKeys = Types::Array.constructor do |value|
      (value.is_a?(::Array) ? value : value.to_s.split(",")).map { it.to_s.strip }.reject(&:empty?)
    end

    AttentionLimit = Types::Coercible::Integer.constrained(gt: 0)
    MinimumSubmitSeconds = Types::Coercible::Integer.constrained(gteq: 0)
    OwnerName = Types::String.constrained(format: /\S/)
    PageSize = Types::Coercible::Integer.constrained(gt: 0)
    RedisCount = Types::Coercible::Integer.constrained(gteq: 0)
    RedisWaits = Types::Array.of(Types::Coercible::Float.constrained(gteq: 0)).constrained(min_size: 1)

    RedisAttempts = (RedisCount | RedisWaits).constructor do |value|
      case value
        when ::Array, ::Integer, /\A\s*\d+\s*\z/ then value
        else value.to_s.split(",", -1)
      end
    end

    RedisTimeout = Types::Coercible::Float.constrained(gt: 0)
    Schema = Types::Hash.schema({}).with_key_transform(&:to_sym)
    SiteUrl = Types::String.constrained(format: %r{\Ahttps?://[^\s/?#@]+/?\z})
    StampExpiryHours = Types::Coercible::Integer.constrained(gteq: 1)
    Threads = Types::Coercible::Integer.constrained(gt: 0)
    ThrottleLimit = Types::Coercible::Integer.constrained(gteq: 1)
    ThrottleWindow = Types::Coercible::Integer.constrained(gteq: 1, lt: MINUTES_BEFORE_THE_VISITOR_HASH_ROTATES)

    TrustedProxies = Types::Array.constructor do |value|
      (value.is_a?(::Array) ? value : value.to_s.split(",")).map { IPAddr.new(it.to_s.strip) }
    end

    Value = Types::String.optional.constructor do |value|
      next value unless value.is_a?(::String)

      trimmed = value.strip
      trimmed unless trimmed.empty?
    end

    def self.object_store
      Schema.schema(
        access_key?: Value,
        bucket?: Value,
        endpoint?: Value,
        path_style?: unless_set(Types::Params::Bool, false),
        region?: unless_set(Types::String, DEFAULT_STORE_REGION),
        secret_key?: Value,
      )
    end
    private_class_method :object_store

    def self.throttle(limit, **keys)
      Schema.schema(
        throttle_limit?: unless_set(ThrottleLimit, limit),
        throttle_window_minutes?: unless_set(ThrottleWindow, DEFAULT_THROTTLE_WINDOW_MINUTES),
        **keys,
      )
    end
    private_class_method :throttle

    def self.unless_blank(type)
      type.optional.constructor { |value| value.to_s.strip.empty? ? nil : value }
    end
    private_class_method :unless_blank

    def self.unless_set(type, default)
      type.default(default).constructor { it.nil? ? Dry::Types::Undefined : it }
    end
    private_class_method :unless_set

    setting :analytics, default: {}, constructor: throttle(DEFAULT_ANALYTICS_THROTTLE_LIMIT)

    setting :analytics_salt, constructor: Types::String.constrained(min_size: 64)

    setting :app_secret, constructor: Types::String.constrained(min_size: 64)

    setting :attention, constructor: Schema.schema(
      carried_count: AttentionLimit,
      draft_days: AttentionLimit,
      journal_days: AttentionLimit,
      new_device_days: AttentionLimit,
      someday_days: AttentionLimit,
    )

    setting :backup_store, default: {}, constructor: object_store

    setting :bluesky, default: {}, constructor: Schema.schema(app_password?: Value, handle?: Value, profile_url?: Value)

    setting :client_registration, default: {}, constructor: throttle(
      DEFAULT_CLIENT_REGISTRATION_THROTTLE_LIMIT,
      total_throttle_limit?: unless_set(ThrottleLimit, DEFAULT_CLIENT_REGISTRATION_TOTAL_THROTTLE_LIMIT),
    )

    setting :contact, default: {}, constructor: throttle(
      DEFAULT_CONTACT_THROTTLE_LIMIT,
      minimum_submit_seconds?: unless_set(MinimumSubmitSeconds, DEFAULT_CONTACT_MINIMUM_SUBMIT_SECONDS),
      stamp_expiry_hours?: unless_set(StampExpiryHours, DEFAULT_CONTACT_STAMP_EXPIRY_HOURS),
      total_throttle_limit?: unless_set(ThrottleLimit, DEFAULT_CONTACT_TOTAL_THROTTLE_LIMIT),
    )

    setting :database, default: {}, constructor: Schema.schema(
      name?: Types::String,
      host?: Types::String.default("localhost"),
      max_connections?: Types::Coercible::Integer.default(12),
      password?: Types::String.optional,
      port?: Types::Coercible::Integer.default(5432),
      user?: Types::String.optional,
    )

    setting :github, default: {}, constructor: Schema.schema(
      api_token?: Value,
      client_id?: Value,
      client_secret?: Value,
      profile_url?: Value,
    )

    setting :honeybadger, default: {}, constructor: Schema.schema(
      api_key?: Value,
      project_url?: Value,
      report_data?: Types::Params::Bool.optional,
    )

    setting :linear, default: {}, constructor: Schema.schema(api_keys?: ApiKeys.default([].freeze))

    setting :mastodon, default: {}, constructor: Schema.schema(access_token?: Value, profile_url?: Value, url?: Value)

    setting :maxmind, default: {}, constructor: Schema.schema(account_id?: Value, license_key?: Value)

    setting :media_store, default: {}, constructor: object_store

    setting :owner, default: {}, constructor: Schema.schema(
      github_id: Types::Coercible::Integer.constrained(gt: 0),
      name: OwnerName,
    )

    setting :page_size, constructor: Schema.schema(admin: PageSize, mcp: PageSize, public: PageSize)

    setting :proxy, default: {}, constructor: Schema.schema(
      address_header?: Value,
      trusted_proxies?: TrustedProxies.default([].freeze),
    )

    setting :reader_salt, constructor: Types::String.constrained(min_size: 64)

    setting :redis, default: {}, constructor: Schema.schema(
      connect_timeout?: unless_blank(RedisTimeout),
      db?: Types::Coercible::Integer.default(0),
      host?: Types::String.default("localhost"),
      password?: Value,
      port?: Types::Coercible::Integer.default(6379),
      reconnect_attempts?: unless_blank(RedisAttempts),
      timeout?: unless_blank(RedisTimeout),
      username?: Value,
    )

    setting :site, default: {}, constructor: Schema.schema(
      url: SiteUrl,
      writing_path?: unless_set(Types::String, DEFAULT_WRITING_PATH),
    )

    setting :web_threads, default: DEFAULT_WEB_THREADS, constructor: unless_set(Threads, DEFAULT_WEB_THREADS)

    setting :webmentions, default: {}, constructor: throttle(
      DEFAULT_WEBMENTION_THROTTLE_LIMIT,
      total_throttle_limit?: unless_set(ThrottleLimit, DEFAULT_WEBMENTION_TOTAL_THROTTLE_LIMIT),
    )

    def initialize(...)
      super
      errors = SecretCheck.call(SECRETS.to_h { [it, public_send(it)] })
      return if errors.empty?

      raise Hanami::Settings::InvalidSettingsError, errors
    end

    def inspect_values = inspect

    def operator?(github_id) = Types::Coercible::Integer.call(github_id) { nil } == owner[:github_id]

    def owner_name = owner[:name]

    def owns?(url)
      host = Blog::Types::Normalized::Host
      host.call(url) { return false } == host.call(site[:url]) { nil }
    end

    def site_origin = URI(site[:url]).origin

    def site_url(path = "/") = URI.join(site[:url], path).to_s

    def writing_path = site[:writing_path]
  end
end
