# frozen_string_literal: true

RSpec.describe Social::Jobs::ReapWebmentionReceipts, type: :request do
  subject(:job) { described_class.new }

  before { create(:post, :published, slug: "hello") }

  def later(seconds) = allow(Time).to receive(:now).and_return(Time.now + seconds)

  def notify(number) = post("/webmention", source: "https://ada.example/notes/#{number}", target:)

  def received = Social::Slice["relations.webmention_receipts"].to_a.map { it[:source_url] }

  def target = "https://aaronmallen.me/writing/hello"

  def window = Hanami.app["settings"].webmentions[:throttle_window_minutes] * 60

  it "deletes a receipt older than the window" do
    notify(1)
    later(window + 60)
    job.perform

    expect(received).to be_empty
  end

  it "keeps a receipt the window is about to let go of" do
    notify(1)
    later(window - 60)
    job.perform

    expect(received).to eq(["https://ada.example/notes/1"])
  end

  it "deletes only the receipts older than the window" do
    notify(1)
    later(window - 60)
    notify(2)
    later(120)

    expect { job.perform }.to change { received }.to(["https://ada.example/notes/2"])
  end

  it "still throttles a sender for the receipts inside the window" do
    lower_throttle_limit(:webmentions, to: 1)
    notify(1)
    job.perform
    notify(2)

    expect(last_response.status).to eq(429)
  end
end
