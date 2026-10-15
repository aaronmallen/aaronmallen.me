# frozen_string_literal: true

RSpec.describe LinkedIn::Client do
  it "pins a LinkedIn-Version no more than ten months old" do
    pinned = Date.strptime(described_class::VERSION, "%Y%m")
    today = Date.today

    expect((today.year * 12) + today.month - (pinned.year * 12) - pinned.month).to be <= 10
  end
end
