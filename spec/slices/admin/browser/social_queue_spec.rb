# frozen_string_literal: true

RSpec.describe "Admin social queue", type: :feature do
  let(:repo) { Social::Slice["repos.social_post_repo"] }

  def counts = all("[data-social-count-text]").map(&:text)

  def draft = repo.create_with_parts(parts: %w[a-draft], targets: %w[mastodon], status: "draft")

  def queued
    attributes = { parts: %w[waiting], targets: %w[mastodon], status: "scheduled", posted_at: Time.now + (90 * 60) }
    repo.create_with_parts(**attributes)
  end

  before do
    connect_social_networks
    queued
    draft
    sign_in_to_admin
    visit "/admin/social"
  end

  it "shows the queued items before a choice" do
    expect(page).to have_css(".sq-part", text: "waiting")
  end

  describe "choosing drafts" do
    before { find(".seg-option", text: "drafts").click }

    it "submits the filter" do
      expect(page).to have_current_path("/admin/social?filter=drafts")
    end

    it "lists only drafts", :aggregate_failures do
      expect(page).to have_css(".sq-part", text: "a-draft")
      expect(page).to have_no_css(".sq-part", text: "waiting")
    end

    it "keeps drafts chosen" do
      expect(page).to have_checked_field("filter", with: "drafts", visible: :all)
    end
  end

  describe "editing a draft" do
    before do
      find(".seg-option", text: "drafts").click
      click_link "Edit"
    end

    it "fills the composer" do
      expect(find("[data-social-body]").value).to eq("a-draft")
    end

    it "counts the text it opened with" do
      expect(counts).to eq(["Mastodon 7/500", "Bluesky 7/300"])
    end

    it "saves back to the same item", :aggregate_failures do
      find("[data-social-body]").set("rewritten")
      click_button "Post now"

      expect(page).to have_css("[data-toast]", text: "Queued for Mastodon")
      expect(repo.queued.map { it.parts.map(&:body) }).to eq([%w[rewritten], %w[waiting]])
    end
  end

  describe "removing a queued item" do
    before { click_button "Remove" }

    it "says the item was removed" do
      expect(page).to have_css("[data-toast]", text: "Removed from queue")
    end

    it "drops the item from the queue" do
      expect(page).to have_no_css(".sq-part", text: "waiting")
    end
  end
end
