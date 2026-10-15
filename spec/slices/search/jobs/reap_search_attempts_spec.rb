# frozen_string_literal: true

RSpec.describe Search::Jobs::ReapSearchAttempts, type: :request do
  subject(:job) { described_class.new }

  def attempts = Search::Slice["relations.search_attempts"].count

  def later(seconds) = allow(Time).to receive(:now).and_return(Time.now + seconds)

  def window = Hanami.app["settings"].search[:throttle_window_minutes] * 60

  it "deletes an attempt older than the window" do
    get "/search", q: "zeppelin"
    later(window + 1)

    expect { job.perform }.to change { attempts }.from(1).to(0)
  end

  it "keeps the attempts inside the window" do
    get "/search", q: "zeppelin"
    later(window - 1)

    expect { job.perform }.not_to(change { attempts })
  end
end
