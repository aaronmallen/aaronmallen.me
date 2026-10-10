# frozen_string_literal: true

require "tmpdir"

module Backups
  module Operations
    class BackUpDatabase < Blog::Operation
      KEEP = 7
      KEY_FORMAT = "database-%Y%m%dT%H%M%SZ.dump"
      PREFIX = "database-"

      include Deps["dumper", client: "backup_store.client"]

      def call(at: Time.now)
        step configured
        key = step back_up(at.utc.strftime(KEY_FORMAT))
        step prune
        key
      end

      private

      def back_up(key)
        Dir.mktmpdir do |dir|
          path = File.join(dir, key)
          dump(path).bind { upload(key, path) }
        end
      end

      def configured = client.configured? ? Success(nil) : Failure(:not_configured)

      def dump(path)
        Success(dumper.call(path))
      rescue Backups::Error => e
        Failure([:dump_failed, e.message])
      end

      def prune
        client.keys(prefix: PREFIX).sort.reverse.drop(KEEP).each { client.delete(it) }
        Success(nil)
      rescue Backups::Error => e
        Failure([:prune_backups_failed, e.message])
      end

      def upload(key, path)
        Success(client.upload(key, path))
      rescue Backups::Error => e
        Failure([:upload_failed, e.message])
      end
    end
  end
end
