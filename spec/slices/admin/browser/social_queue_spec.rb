# frozen_string_literal: true

RSpec.describe "Admin social queue", type: :feature do
  let(:repo) { Social::Slice["repos.social_post_repo"] }

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

  it "submits the filter once drafts is chosen" do
    find(".seg-option", text: "drafts").click

    expect(page).to have_current_path("/admin/social?filter=drafts")
  end

  describe "editing a draft" do
    before do
      find(".seg-option", text: "drafts").click
      click_link "Edit"
    end

    it "fills the composer" do
      expect(find("[data-social-body]").value).to eq("a-draft")
    end

    it "saves back to the same item", :aggregate_failures do
      find("[data-social-body]").set("rewritten")
      click_button "Post now"

      expect(page).to have_css("[data-toast]", text: "Queued for Mastodon")
      expect(repo.queued.map { it.parts.map(&:body) }).to eq([%w[rewritten], %w[waiting]])
    end
  end
end
