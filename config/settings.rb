# frozen_string_literal: true

require "ipaddr"

module Blog
  class Settings < Hanami::Settings
    DEFAULT_ANALYTICS_THROTTLE_LIMIT = 120
    DEFAULT_CLIENT_REGISTRATION_THROTTLE_LIMIT = 10
    DEFAULT_CONTACT_THROTTLE_LIMIT = 3
    DEFAULT_THROTTLE_WINDOW_MINUTES = 60
    DEFAULT_WEBMENTION_THROTTLE_LIMIT = 30
    DEFAULT_WEBMENTION_TOTAL_THROTTLE_LIMIT = 100
    MINUTES_BEFORE_THE_VISITOR_HASH_ROTATES = 1_440

    OwnerName = Types::String.constrained(format: /\S/)
    Schema = Types::Hash.schema({}).with_key_transform(&:to_sym)
    SiteUrl = Types::String.constrained(format: %r{\Ahttps?://[^\s/?#@]+/?\z})
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

    def self.throttle(limit, **keys)
      Schema.schema(
        throttle_limit?: unless_set(ThrottleLimit, limit),
        throttle_window_minutes?: unless_set(ThrottleWindow, DEFAULT_THROTTLE_WINDOW_MINUTES),
        **keys,
      )
    end
    private_class_method :throttle

    def self.unless_set(type, default)
      type.default(default).constructor { it.nil? ? Dry::Types::Undefined : it }
    end
    private_class_method :unless_set

    setting :analytics, default: {}, constructor: throttle(DEFAULT_ANALYTICS_THROTTLE_LIMIT)

    setting :analytics_salt, constructor: Types::String.constrained(min_size: 64)

    setting :app_secret, constructor: Types::String.constrained(min_size: 64)

    setting :bluesky, default: {}, constructor: Schema.schema(app_password?: Value, handle?: Value, profile_url?: Value)

    setting :client_registration, default: {}, constructor: throttle(DEFAULT_CLIENT_REGISTRATION_THROTTLE_LIMIT)

    setting :contact, default: {}, constructor: throttle(DEFAULT_CONTACT_THROTTLE_LIMIT)

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
      report_data?: Types::Params::Bool.optional,
    )

    setting :mastodon, default: {}, constructor: Schema.schema(access_token?: Value, profile_url?: Value, url?: Value)

    setting :maxmind, default: {}, constructor: Schema.schema(account_id?: Value, license_key?: Value)

    setting :owner, default: {}, constructor: Schema.schema(
      github_id: Types::Coercible::Integer.constrained(gt: 0),
      name: OwnerName,
    )

    setting :proxy, default: {}, constructor: Schema.schema(
      address_header?: Value,
      trusted_proxies?: TrustedProxies.default([].freeze),
    )

    setting :redis, default: {}, constructor: Schema.schema(
      db?: Types::Coercible::Integer.default(0),
      host?: Types::String.default("localhost"),
      password?: Value,
      port?: Types::Coercible::Integer.default(6379),
      username?: Value,
    )

    setting :site, default: {}, constructor: Schema.schema(url: SiteUrl)

    setting :webmentions, default: {}, constructor: throttle(
      DEFAULT_WEBMENTION_THROTTLE_LIMIT,
      total_throttle_limit?: unless_set(ThrottleLimit, DEFAULT_WEBMENTION_TOTAL_THROTTLE_LIMIT),
    )

    def initialize(...)
      super
      return unless analytics_salt == app_secret

      raise Hanami::Settings::InvalidSettingsError, { analytics_salt: "must not repeat app_secret" }
    end

    def inspect_values = inspect

    def operator?(github_id) = Types::Coercible::Integer.call(github_id) { nil } == owner[:github_id]

    def owns?(url)
      host = Blog::Types::Normalized::Host
      host.call(url) { return false } == host.call(site[:url]) { nil }
    end
  end
end
