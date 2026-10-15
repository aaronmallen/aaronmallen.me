# frozen_string_literal: true

require "digest"

module Blog
  module ThemeScript
    COOKIE = "site_theme"
    ROOT = "document.documentElement.dataset"
    PATTERN = "/(?:^|; )#{COOKIE}=(light|dark)(?:;|$)/".freeze
    SOURCE = "{ const saved = document.cookie.match(#{PATTERN}); if (saved) #{ROOT}.siteTheme = saved[1]; }".freeze
    SOURCE_HASH = "'sha256-#{Digest::SHA256.base64digest(SOURCE)}'".freeze
  end
end
