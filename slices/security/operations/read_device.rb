# frozen_string_literal: true

module Security
  module Operations
    class ReadDevice
      BROWSERS = {
        "Edge" => %r{\bEdg(?:e|A|iOS)?/},
        "Opera" => %r{\b(?:OPR|OPiOS)/},
        "Firefox" => %r{\b(?:Firefox|FxiOS)/},
        "Chrome" => %r{\b(?:Chrome|CriOS)/},
        "Safari" => %r{\bVersion/.*\bSafari/},
      }.freeze
      SYSTEMS = {
        "iOS" => /\b(?:iPhone|iPad|iPod)\b/,
        "Android" => /\bAndroid\b/,
        "ChromeOS" => /\bCrOS\b/,
        "Windows" => /\bWindows\b/,
        "macOS" => /\bMac OS X\b|\bMacintosh\b/,
        "Linux" => /\bLinux\b/,
      }.freeze

      def call(user_agent) = { browser: match(BROWSERS, user_agent), os: match(SYSTEMS, user_agent) }

      private

      def match(names, user_agent) = names.find { |_, pattern| pattern.match?(user_agent.to_s) }&.first
    end
  end
end
