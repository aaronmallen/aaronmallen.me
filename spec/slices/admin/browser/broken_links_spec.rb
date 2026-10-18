# frozen_string_literal: true

RSpec.describe "Admin broken links", type: :feature do
  let(:dead) { "https://bob.example/gone" }
  let(:post) { create(:post, :published, title: "Linked", body: "intro\n\n[the note](#{dead})") }
  let(:link) { Shares::Slice["operations.create_short_link"].call(destination: dead).value! }

  def checks = Posts::Slice["relations.post_link_checks"]

  def short_checks = Shares::Slice["relations.short_link_checks"]

  before do
    checks.record(post_id: post.id, url: dead, reason: "404 Not Found", at: Time.now)
    short_checks.record(short_link_id: link.id, url: dead, reason: "404 Not Found", at: Time.now)
    sign_in_to_admin
    visit "/admin/posts?status=broken"
    wait_for_stream
  end

  it "queues a post link check and stays on the list", :aggregate_failures do
    page.execute_script("window.stayed = true")
    find(".post-broken-links button[value='#{dead}']").click

    expect(page).to have_css(".toast", text: "Checking that link")
    expect(Posts::Jobs::CheckPostLinksAgain.jobs.map { it["args"] }).to eq([[post.id, dead]])
    expect(page.evaluate_script("window.stayed")).to be(true)
  end

  it "queues a short link check", :aggregate_failures do
    find(".post-broken-short button[formaction='/admin/links/#{link.id}/check']").click

    expect(page).to have_css(".toast", text: "Checking that link")
    expect(Shares::Jobs::CheckShortLinkAgain.jobs.map { it["args"] }).to eq([[link.id]])
  end

  it "updates the post row when a check lands", :aggregate_failures do
    checks.record(post_id: post.id, url: dead, reason: nil, at: Time.now)

    expect(page).to have_no_css(".post-broken-links")
    expect(page).to have_css(".page-head-sub", text: "1 broken link: 0 in 0 posts and 1 short link.")
  end

  it "updates the short links card when a check lands" do
    short_checks.record(short_link_id: link.id, url: dead, reason: nil, at: Time.now)

    expect(page).to have_no_css(".post-broken-short")
  end
end
