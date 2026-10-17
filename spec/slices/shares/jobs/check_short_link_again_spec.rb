# frozen_string_literal: true

RSpec.describe Shares::Jobs::CheckShortLinkAgain do
  let(:dead) { "https://bob.example/gone" }
  let(:live) { "https://ada.example/notes/1" }

  def checks = Shares::Slice["relations.short_link_checks"].to_a.to_h { [it[:url], it] }

  def nightly = Posts::Jobs::CheckPostLinks.new.perform

  def queue_and_run(id, *)
    described_class.perform_async(id)
    described_class.drain
  end

  def short_link(destination) = Shares::Slice["operations.create_short_link"].call(destination:).value!

  before do
    resolves_publicly("ada.example", "bob.example")
    stub_request(:get, live).to_return(status: 200)
    stub_request(:get, dead).to_return(status: 404)
  end

  it "checks every short link's destination each night", :aggregate_failures do
    [live, dead].each { short_link(it) }
    nightly

    expect(checks[live]).to include(failures: 0, reason: nil, first_failed_at: nil)
    expect(checks[dead]).to include(failures: 1, reason: "404 Not Found")
    expect(checks[dead].values_at(:checked_at, :first_failed_at)).to all(be_within(5).of(Time.now))
  end

  it "counts the nights a destination keeps failing and keeps when it first failed", :aggregate_failures do
    short_link(dead)
    Shares::Slice["operations.check_short_links"].call(at: Time.now - 86_400)
    nightly

    expect(checks[dead][:failures]).to eq(2)
    expect(checks[dead][:first_failed_at]).to be_within(5).of(Time.now - 86_400)
  end

  describe "the failure rule" do
    def reasons = checks.to_h { |url, check| [url.delete_prefix("#{live}/"), check[:reason]] }

    before do
      [500, 403, 429].each { stub_request(:get, "#{live}/#{it}").to_return(status: it) }
      stub_request(:get, "#{live}/slow").to_timeout
      %w[500 403 429 slow].each { short_link("#{live}/#{it}") }
    end

    it "counts a 5xx and a timeout as failing, and a 403 or 429 as fine" do
      nightly

      expect(reasons).to eq(
        "500" => "500 Internal Server Error", "slow" => "Timed out after 10 seconds", "403" => nil, "429" => nil,
      )
    end
  end

  it "starts counting again once a link points somewhere new" do
    link = short_link(dead)
    nightly
    Shares::Slice["operations.retarget_short_link"].call(link.id, destination: live)
    nightly

    expect(checks.transform_values { it[:failures] }).to eq(live => 0)
  end

  it "checks one short link on demand", :aggregate_failures do
    queue_and_run(short_link(dead).id, short_link(live))

    expect(checks.keys).to eq([dead])
    expect(a_request(:get, live)).not_to have_been_made
  end

  it "counts on from the nightly run" do
    link = short_link(dead)
    nightly
    queue_and_run(link.id)

    expect(checks[dead][:failures]).to eq(2)
  end

  it "checks nothing for a short link that is gone" do
    queue_and_run(0)

    expect(checks).to be_empty
  end
end
