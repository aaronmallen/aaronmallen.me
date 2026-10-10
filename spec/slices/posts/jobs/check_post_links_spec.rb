# frozen_string_literal: true

RSpec.describe Posts::Jobs::CheckPostLinks do
  let(:dead) { "https://bob.example/gone" }
  let(:live) { "https://ada.example/notes/1" }

  def body_linking(*urls) = urls.map { "See [a note](#{it})." }.join("\n\n")

  def check = described_class.new.perform

  def checks = Posts::Slice["relations.post_link_checks"].to_a.to_h { [it[:url], it] }

  def post_with(*urls, status: :published) = create(:post, status, body: body_linking(*urls))

  before do
    resolves_publicly("ada.example", "bob.example")
    stub_request(:get, live).to_return(status: 200, body: "<p>a note</p>")
    stub_request(:get, dead).to_return(status: 404)
  end

  it "never retries, since next week's run checks every link again" do
    expect(described_class.get_sidekiq_options["retry"]).to be(false)
  end

  it "checks each outbound link in a published post" do
    post_with(live, dead)
    check

    expect([a_request(:get, live), a_request(:get, dead)]).to all(have_been_made.once)
  end

  it "counts a 404 as a failure and keeps the reason and when it ran", :aggregate_failures do
    post_with(dead)
    check

    expect(checks[dead]).to include(failures: 1, reason: "HTTP 404")
    expect(checks[dead][:checked_at]).to be_within(5).of(Time.now)
  end

  it "counts a 410 as a failure" do
    stub_request(:get, dead).to_return(status: 410)
    post_with(dead)
    check

    expect(checks[dead]).to include(failures: 1, reason: "HTTP 410")
  end

  it "counts failures in a row" do
    post_with(dead)
    2.times { check }

    expect(checks[dead][:failures]).to eq(2)
  end

  it "counts a link that will not connect as a failure", :aggregate_failures do
    stub_request(:get, dead).to_raise(SocketError.new("getaddrinfo: nodename nor servname provided"))
    post_with(dead)
    check

    expect(checks[dead][:failures]).to eq(1)
    expect(checks[dead][:reason]).to include("getaddrinfo")
  end

  it "counts a host that will not resolve as a failure" do
    unresolvable("gone.example")
    post_with("https://gone.example/page")
    check

    expect(checks["https://gone.example/page"]).to include(failures: 1, reason: a_string_including("resolve"))
  end

  it "never fetches a link to a private address, and counts it as working", :aggregate_failures do
    resolves("intranet.example", "192.168.1.10")
    post_with("https://intranet.example/admin")
    check

    expect(a_request(:get, "https://intranet.example/admin")).not_to have_been_made
    expect(checks["https://intranet.example/admin"]).to include(failures: 0, reason: nil)
  end

  it "names the site and the link check in the user agent" do
    post_with(live)
    check

    agent = "aaronmallen.me link-check (+https://aaronmallen.me)"

    expect(a_request(:get, live).with(headers: { "User-Agent" => agent })).to have_been_made
  end

  it "counts a timeout as a failure" do
    stub_request(:get, dead).to_timeout
    post_with(dead)
    check

    expect(checks[dead][:failures]).to eq(1)
  end

  it "counts a 403 as working, since some sites turn bots away" do
    stub_request(:get, live).to_return(status: 403)
    post_with(live)
    check

    expect(checks[live]).to include(failures: 0, reason: nil)
  end

  it "follows a redirect to the page it lands on" do
    stub_request(:get, dead).to_return(status: 301, headers: { "Location" => live })
    post_with(dead)
    check

    expect(checks[dead][:failures]).to eq(0)
  end

  it "counts endless redirects as working, since only a 404, a 410 or no answer counts as broken" do
    stub_request(:get, dead).to_return(status: 302, headers: { "Location" => dead })
    post_with(dead)
    check

    expect(checks[dead][:failures]).to eq(0)
  end

  it "resets the count when a check passes" do
    post_with(live)
    stub_request(:get, live).to_return(status: 404).times(2).then.to_return(status: 200)
    3.times { check }

    expect(checks[live]).to include(failures: 0, reason: nil)
  end

  it "never checks a link to the site itself" do
    post_with("https://aaronmallen.me/writing/hello", "/about", live)
    check

    expect(checks.keys).to eq([live])
  end

  it "never checks a draft", :aggregate_failures do
    post_with(dead, status: :draft)
    check

    expect(a_request(:get, dead)).not_to have_been_made
    expect(checks).to be_empty
  end

  it "forgets a link removed from the post" do
    post = post_with(live, dead)
    check
    Posts::Slice["repos.post_mutations"].update(post.id, body: body_linking(live))
    check

    expect(checks.keys).to eq([live])
  end

  it "forgets the links of a post taken back to a draft" do
    post = post_with(dead)
    check
    Posts::Slice["repos.post_mutations"].update(post.id, status: "draft")
    check

    expect(checks).to be_empty
  end

  it "checks a link once when a post names it twice" do
    post_with(live, live)
    check

    expect(a_request(:get, live)).to have_been_made.once
  end
end
