# frozen_string_literal: true

RSpec.describe "Admin people", type: :feature do
  let(:person_queries) { Social::Slice["repos.person_queries"] }

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

  describe "finding an account" do
    let(:ada) { { avatar: "https://cdn.bsky.app/ada.jpg", displayName: "Ada Lovelace", handle: "ada.bsky.social" } }
    let(:grace) { { acct: "grace@hachyderm.io", avatar: "https://files.example/g.png", display_name: "Grace Hopper" } }

    def add_from(network, query, name)
      search(network, query)
      within(finder.find(".person-result", text: name)) { click_button "Add" }
    end

    def finder = find_by_id("person-finder")

    def search(network, query, button: true)
      within(finder) do
        find(".seg-option.#{network}").click
        fill_in("person-finder-q", with: query)
        button ? click_button("Search") : find_field("person-finder-q").send_keys(:enter)
      end
    end

    before do
      connect_social_networks
      visit "/admin/people"
    end

    it "shows the panel beside the list once scripts run" do
      expect(finder).to have_field("Search Mastodon")
    end

    it "relabels the box for the network I pick" do
      within(finder) { find(".seg-option.bluesky").click }

      expect(finder).to have_field("Search Bluesky")
    end

    it "says how many accounts it found" do
      stub_bluesky_search("ada", ada)
      search("bluesky", "ada")

      expect(finder).to have_css("[data-person-finder-count]", text: "1 account found")
    end

    it "searches on Enter" do
      stub_mastodon_search("grace", grace)
      search("mastodon", "grace", button: false)

      expect(finder).to have_css(".person-result-handle", text: "@grace@hachyderm.io")
    end

    it "says so when nothing matches" do
      stub_bluesky_search("nobody")
      search("bluesky", "nobody")

      expect(finder).to have_css(".empty", text: "No accounts match")
    end

    it "shows the error when the network fails" do
      stub_bluesky_search("ada", status: 502)
      search("bluesky", "ada")

      expect(finder).to have_css(".hint.bad", text: "Bluesky did not answer")
    end

    it "opens the new person drawer from Add with the name, key and handle", :aggregate_failures do
      stub_bluesky_search("ada", ada)
      add_from("bluesky", "ada", "Ada Lovelace")

      expect(page).to have_field("person-new-name", with: "Ada Lovelace")
      expect(page).to have_field("person-new-key", with: "ada")
      expect(page).to have_field("person-new-bluesky_handle", with: "ada.bsky.social")
    end

    it "adds the person it found" do
      stub_mastodon_search("grace", grace)
      add_from("mastodon", "grace", "Grace Hopper")
      within("#person-new-drawer") { click_button "Add person" }

      expect(page).to have_css(".person-row-name", text: "Grace Hopper")
    end
  end

  it "offers only the networks with credentials" do
    connect_social_networks(bluesky: {})
    visit "/admin/people"

    expect(page).to have_css("#person-finder .seg-option.mastodon")
      .and have_no_css("#person-finder .seg-option.bluesky")
  end

  describe "the drawers" do
    let!(:person) { create(:person, name: "Ada Lovelace", key: "ada") }

    before { visit "/admin/people" }

    it "opens a person's editor from their name" do
      click_link "Ada Lovelace"

      expect(page).to have_field("person-#{person.id}-key", with: "ada")
    end

    it "saves from the drawer" do
      click_link "Ada Lovelace"
      fill_in "person-#{person.id}-name", with: "Countess Ada"
      within("#person-#{person.id}-drawer") { click_button "Save" }

      expect(page).to have_css(".person-row-name", text: "Countess Ada")
    end

    it "fills the key from the name in the new person drawer" do
      click_link "New person"
      fill_in "person-new-name", with: "Grace Hopper"

      expect(page).to have_field("person-new-key", with: "grace-hopper")
    end
  end

  describe "removing a person" do
    let!(:person) { create(:person, name: "Ada Lovelace") }

    before { visit "/admin/people/#{person.id}/edit" }

    it "asks with the confirmation text" do
      message = confirm_no { click_button "Remove" }

      expect(message).to eq(translate("ui.components.people.person_form.confirm_delete", name: "Ada Lovelace"))
    end

    it "keeps them when I don't confirm" do
      confirm_no { click_button "Remove" }

      expect(person_queries.all.map(&:name)).to eq(["Ada Lovelace"])
    end

    it "removes them once I confirm" do
      confirm_yes { click_button "Remove" }

      expect(page).to have_css(".toast", text: "Person removed")
    end
  end
end
