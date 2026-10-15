# frozen_string_literal: true

Analytics::Slice.configure_provider :db do
  Blog::Providers::DBProvider.configure(config, target.app["settings"])

  before(:start) do
    ROM.plugins do
      adapter(:sql) { register :daily_rollup, Analytics::DB::Plugins::DailyRollup, type: :relation }
    end
  end
end
