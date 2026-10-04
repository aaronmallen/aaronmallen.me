# frozen_string_literal: true

RSpec.describe "Admin people", type: :feature do
  let(:repo) { Social::Slice["repos.person_repo"] }

  before { sign_in_to_admin }

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  it "fills the key from the name of a new person" do
    visit "/admin/people/new"
    fill_in("person[name]", with: "Ada Lovelace")

    expect(page).to have_field("person[key]", with: "ada-lovelace")
  end

  it "leaves a stored person's key alone when the name changes" do
    person = create(:person, name: "Ada", key: "ada")
    visit "/admin/people/#{person.id}/edit"
    fill_in("person[name]", with: "Ada Lovelace")

    expect(page).to have_field("person[key]", with: "ada")
  end

  describe "searching for accounts" do
    let(:ada) { { avatar: "https://cdn.bsky.app/ada.jpg", displayName: "Ada Lovelace", handle: "ada.bsky.social" } }
    let(:grace) { { acct: "grace@hachyderm.io", avatar: "https://files.example/g.png", display_name: "Grace Hopper" } }

    def box(network) = find_by_id("person-#{network}-search")

    def find_result(network, query, text)
      search(network, query)
      find("#person-#{network}-results [role='option']", text:)
    end

    def search(network, keys) = box(network).send_keys(keys)

    def searches(network) = request_gate.count("/admin/people/search/#{network}")

    before do
      connect_social_networks
      visit "/admin/people/new"
    end

    it "shows the search boxes once scripts run" do
      expect(page).to have_field("Search Bluesky").and have_field("Search Mastodon")
    end

    it "fills the Bluesky handle, the name and the key from a picked account", :aggregate_failures do
      stub_bluesky_search("ada", ada)
      find_result("bluesky", "ada", "Ada Lovelace").click

      expect(page).to have_field("person[bluesky_handle]", with: "ada.bsky.social")
      expect(page).to have_field("person[name]", with: "Ada Lovelace")
      expect(page).to have_field("person[key]", with: "ada-lovelace")
    end

    it "fills the Mastodon handle as @user@instance" do
      stub_mastodon_search("grace", grace)
      find_result("mastodon", "grace", "Grace Hopper").click

      expect(page).to have_field("person[mastodon_handle]", with: "@grace@hachyderm.io")
    end

    it "keeps a name I typed" do
      stub_bluesky_search("ada", ada)
      fill_in("person[name]", with: "Countess Ada")
      find_result("bluesky", "ada", "Ada Lovelace").click

      expect(page).to have_field("person[name]", with: "Countess Ada")
    end

    it "picks by keyboard", :aggregate_failures do
      stub_bluesky_search("ada", ada, ada.merge(displayName: "Ada Two", handle: "ada2.bsky.social"))
      find_result("bluesky", "ada", "Ada Two")
      search("bluesky", %i[down down enter])

      expect(page).to have_field("person[bluesky_handle]", with: "ada2.bsky.social")
      expect(page).to have_no_css("#person-bluesky-results", visible: :visible)
    end

    it "points the box at the active result", :aggregate_failures do
      stub_bluesky_search("ada", ada)
      find_result("bluesky", "ada", "Ada Lovelace")
      search("bluesky", :down)

      expect(box("bluesky")["aria-activedescendant"]).to eq("person-bluesky-results-0")
      expect(box("bluesky")["aria-expanded"]).to eq("true")
    end

    it "shuts the results on Escape" do
      stub_bluesky_search("ada", ada)
      find_result("bluesky", "ada", "Ada Lovelace")
      search("bluesky", :escape)

      expect(page).to have_no_css("#person-bluesky-results", visible: :visible)
    end

    it "does not save the form on Enter in the search box" do
      search("bluesky", :enter)

      expect(page).to have_current_path("/admin/people/new")
    end

    it "asks the network once for a burst of typing" do
      stub_bluesky_search("ada", ada)
      find_result("bluesky", "ada", "Ada Lovelace")

      expect(searches("bluesky")).to eq(1)
    end

    it "asks nothing for one character" do
      stub_mastodon_search("grace", grace)
      search("bluesky", "a")
      find_result("mastodon", "grace", "Grace Hopper")

      expect(searches("bluesky")).to eq(0)
    end

    it "shows an error row and leaves the field as it was", :aggregate_failures do
      stub_bluesky_search("ada", status: 502)
      fill_in("person[bluesky_handle]", with: "typed.example")
      search("bluesky", "ada")

      expect(page).to have_css("#person-bluesky-results [aria-disabled='true']", text: "Bluesky did not answer")
      expect(page).to have_field("person[bluesky_handle]", with: "typed.example")
    end

    it "says how many accounts it found" do
      stub_bluesky_search("ada", ada)
      search("bluesky", "ada")

      expect(page).to have_css("[data-person-search-status]", text: "1 account found", visible: :all)
    end

    it "searches from the editor too" do
      stub_bluesky_search("lovelace", { displayName: "Ada L", handle: "lovelace.example" })
      visit "/admin/people/#{create(:person, name: 'Ada').id}/edit"
      find_result("bluesky", "lovelace", "Ada L").click

      expect(page).to have_field("person[bluesky_handle]", with: "lovelace.example")
        .and have_field("person[name]", with: "Ada")
    end
  end

  it "shows no search box for a network with no credentials" do
    connect_social_networks(bluesky: {})
    visit "/admin/people/new"

    expect(page).to have_field("Search Mastodon").and have_no_field("Search Bluesky")
  end

  describe "removing a person" do
    let!(:person) { create(:person, name: "Ada Lovelace") }

    before { visit "/admin/people/#{person.id}/edit" }

    it "asks with the confirmation text" do
      message = dismiss_confirm { click_button "Remove" }

      expect(message).to eq(translate("ui.components.people.editor.confirm_delete", name: "Ada Lovelace"))
    end

    it "keeps them when I don't confirm" do
      dismiss_confirm { click_button "Remove" }

      expect(repo.all.map(&:name)).to eq(["Ada Lovelace"])
    end

    it "removes them once I confirm" do
      accept_confirm { click_button "Remove" }

      expect(page).to have_css(".toast", text: "Person removed")
    end
  end
end
