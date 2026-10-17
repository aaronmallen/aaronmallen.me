# frozen_string_literal: true

module Blog
  module Extensions
    class VersionMismatch < StandardError
    end

    def self.apply(target, extension, gem:, version:, reason:, upstream:)
      pin(target, gem:, version:, reason:, upstream:, path: caller_locations(1, 1).first.path)
      target.prepend(extension)
    end

    def self.pin(target, gem:, version:, reason:, upstream:, path: caller_locations(1, 1).first.path)
      actual = Gem.loaded_specs.fetch(gem).version.to_s
      return if actual == version

      raise VersionMismatch, <<~MESSAGE.tr("\n", " ").strip
        #{gem} is #{actual}, but #{path} patches #{target} for #{version}.
        It works around: #{reason} (#{upstream || 'no upstream report'}).
        Check the patch still holds against #{actual}, then set its version to #{actual}.
      MESSAGE
    end
  end
end
