# frozen_string_literal: true

RSpec.describe "The worker shutting down", type: :app do
  let(:sidekiq) { Sidekiq::Config.new(lifecycle_events: { startup: [], exit: [] }) }

  before do
    allow(Hanami).to receive(:boot)
    allow(Hanami).to receive(:shutdown)
    allow(Sidekiq).to receive(:configure_server).and_yield(sidekiq)
    load Hanami.app.root.join("config/sidekiq.rb").to_s
  end

  it "stops the app's providers" do
    sidekiq[:lifecycle_events][:exit].each(&:call)

    expect(Hanami).to have_received(:shutdown)
  end
end
