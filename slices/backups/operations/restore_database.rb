# frozen_string_literal: true

require "tmpdir"

module Backups
  module Operations
    class RestoreDatabase < Blog::Operation
      include Deps["restorer", client: "backup_store.client"]

      def call(dump)
        step restore_from(dump)
      end

      private

      def download(key, path)
        return Failure([:not_found, key]) unless client.exists?(key)

        File.open(path, "wb") { |file| client.stream(key) { file.write(it) } }
        Success(path)
      rescue ObjectStore::Client::Error => e
        Failure([:download_failed, e.message])
      end

      def locate(dump, dir)
        return Success(dump) if File.file?(dump)
        return Failure([:not_found, dump]) unless client.configured?

        download(dump, File.join(dir, File.basename(dump)))
      end

      def restore(path)
        Success(restorer.call(path))
      rescue Backups::Error => e
        Failure([:restore_failed, e.message])
      end

      def restore_from(dump)
        Dir.mktmpdir { |dir| locate(dump, dir).bind { restore(it) } }
      end
    end
  end
end
