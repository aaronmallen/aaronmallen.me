# frozen_string_literal: true

require "open3"

module Blog
  module Version
    UNKNOWN = "unknown"

    def self.read(root)
      return UNKNOWN unless File.exist?(File.join(root, ".git"))

      output, status = Open3.capture2("git", "describe", "--tags", chdir: root, err: File::NULL)
      status.success? ? output.strip : UNKNOWN
    rescue SystemCallError
      UNKNOWN
    end

    CURRENT = read(File.expand_path("../..", __dir__))
  end
end
