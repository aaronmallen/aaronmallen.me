# frozen_string_literal: true

RSpec.shared_context "with a frozen clock" do
  let!(:now) { Time.now.floor(6) }

  before { allow(Time).to receive(:now).and_return(now) }
end

RSpec.configure do |config|
  config.include_context "with a frozen clock", :frozen_clock
end
