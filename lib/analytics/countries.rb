# frozen_string_literal: true

require "fileutils"
require "maxmind/db"

module Analytics
  class Countries
    MISSING = :missing
    PENDING = ".pending"
    UNREADABLE = :unreadable

    attr_reader :path

    def initialize(databases:, path:)
      @databases = databases
      @path = Pathname(path)
    end

    def code(address)
      found = reader&.get(address.to_s)&.dig("country", "iso_code").to_s
      found if Blog::Types::CountryCode.valid?(found)
    rescue ArgumentError, MaxMind::DB::InvalidDatabaseError, SystemCallError
      nil
    end

    def failure
      return MISSING unless stamp

      UNREADABLE unless reader
    rescue SystemCallError
      UNREADABLE
    end

    def replace(database)
      pending = path.sub_ext(PENDING)
      FileUtils.mkdir_p(path.dirname)
      pending.binwrite(database.to_s)
      open_database(pending)
      pending.rename(path)
      path
    ensure
      FileUtils.rm_f(pending)
    end

    private

    attr_reader :databases

    def open_database(file)
      MaxMind::DB.new(file.to_s, mode: MaxMind::DB::MODE_MEMORY)
    rescue MaxMind::DB::InvalidDatabaseError, IOError, SystemCallError => e
      raise Error, "#{file} is not a MaxMind database: #{e.message}"
    end

    def reader
      at = stamp
      return nil unless at

      databases.reader(path, at) { open_database(path) }
    rescue Error
      nil
    end

    def stamp
      found = path.stat
      [found.ino, found.mtime, found.size]
    rescue Errno::ENOENT
      nil
    end
  end
end
