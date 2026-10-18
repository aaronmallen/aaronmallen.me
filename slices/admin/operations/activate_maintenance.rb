# frozen_string_literal: true

require "fileutils"

module Admin
  module Operations
    class ActivateMaintenance < Blog::Operation
      include Deps["settings"]

      def call
        flag = settings.maintenance[:flag_path]
        step write(flag)
        Blog::Maintenance.pass(settings.app_secret, File.mtime(flag))
      end

      private

      def write(flag)
        FileUtils.touch(flag)
        Success()
      rescue SystemCallError
        Failure(:unwritable)
      end
    end
  end
end
