# frozen_string_literal: true

require "blog/extensions/hanami/cli/db/postgres/extension"

RSpec.describe Blog::Extensions::Hanami::CLI::DB::Postgres::Extension do
  let(:settings) { Hanami.app["settings"].database }

  def database(name)
    url = Blog::Providers::DBProvider.database_url(settings.merge(name:))
    Hanami::CLI::Commands::App::DB::Utils::Postgres.new(
      slice: Hanami.app, gateway_name: :default, system_call: Hanami::CLI::SystemCall.new,
    ).tap { allow(it).to receive(:database_url).and_return(url) }
  end

  describe "#exists?" do
    it "finds the database the settings name" do
      expect(database(settings[:name])).to exist
    end

    it "misses a database that is not there, quotes and all" do
      expect(database("#{settings[:name]}_o'missing")).not_to exist
    end
  end
end
