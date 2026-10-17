# frozen_string_literal: true

RSpec.describe Posts::Jobs::CheckPostLinksAgain do
  let(:dead) { "https://bob.example/gone" }
  let(:live) { "https://ada.example/notes/1" }

  def body_linking(*urls) = urls.map { "See [a note](#{it})." }.join("\n\n")

  def checks = Posts::Slice["relations.post_link_checks"].to_a.to_h { [it[:url], it] }

  def post_with(*urls, status: :published) = create(:post, status, body: body_linking(*urls))

  def queue_and_run(*)
    described_class.perform_async(*)
    described_class.drain
  end

  before do
    resolves_publicly("ada.example", "bob.example")
    stub_request(:get, live).to_return(status: 200)
    stub_request(:get, dead).to_return(status: 404)
  end

  it "checks every link in one post", :aggregate_failures do
    post = post_with(live, dead)
    post_with("https://ada.example/other")
    queue_and_run(post.id)

    expect(checks.keys).to contain_exactly(live, dead)
    expect(checks[dead]).to include(failures: 1, reason: "404 Not Found")
  end

  it "checks one link in a post", :aggregate_failures do
    post = post_with(live, dead)
    queue_and_run(post.id, dead)

    expect(checks.keys).to eq([dead])
    expect(a_request(:get, live)).not_to have_been_made
  end

  it "counts on from the nightly run" do
    post = post_with(dead)
    Posts::Jobs::CheckPostLinks.new.perform
    queue_and_run(post.id, dead)

    expect(checks[dead][:failures]).to eq(2)
  end

  it "checks nothing for a link the post no longer names" do
    post = post_with(live)
    queue_and_run(post.id, dead)

    expect(a_request(:get, dead)).not_to have_been_made
  end

  it "checks nothing in a draft" do
    post = post_with(dead, status: :draft)
    queue_and_run(post.id)

    expect(checks).to be_empty
  end
end
