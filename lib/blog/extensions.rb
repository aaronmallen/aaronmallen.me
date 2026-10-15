# frozen_string_literal: true

module Blog
  module Extensions
    class VersionMismatch < StandardError
    end

    def self.apply(target, extension, gem:, version:, reason:, upstream:)
      actual = Gem.loaded_specs.fetch(gem).version.to_s
      return target.prepend(extension) if actual == version

      raise VersionMismatch, <<~MESSAGE.tr("\n", " ").strip
        #{gem} is #{actual}, but #{caller_locations(1, 1).first.path} patches #{target} for #{version}.
        It works around: #{reason} (#{upstream || 'no upstream report'}).
        Check the patch still holds against #{actual}, then set its version to #{actual}.
      MESSAGE
    end
  end
end
