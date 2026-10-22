# frozen_string_literal: true

RSpec.describe "Admin people", type: :feature do
  let(:person_queries) { Contacts::Slice["repos.person_queries"] }

  before { sign_in_to_admin }

  it "fills the key from the name in the composer's short form" do
    visit "/admin/contacts/new?reply=mention"
    fill_in("person[name]", with: "Ada Lovelace")

    expect(page).to have_field("person[key]", with: "ada-lovelace")
  end

  describe "finding an account" do
    let(:ada) { { avatar: "https://cdn.bsky.app/ada.jpg", displayName: "Ada Lovelace", handle: "ada.bsky.social" } }
    let(:grace) { { acct: "grace@hachyderm.io", avatar: "https://files.example/g.png", display_name: "Grace Hopper" } }

    def add_from(network, query, name)
      search(network, query)
      within(finder.find(".person-result", text: name)) { click_link "Add" }
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
      visit "/admin/contacts"
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

    it "keeps the results when a change redraws the page" do
      stub_bluesky_search("nobody")
      search("bluesky", "nobody")
      finder.find(".empty")
      create(:person, name: "Grace Hopper", key: "grace")

      expect(page).to have_css(".contact-row-name", text: "Grace").and have_css("#person-finder .empty")
    end

    it "shows the error when the network fails" do
      stub_bluesky_search("ada", status: 502)
      search("bluesky", "ada")

      expect(finder).to have_css(".hint.bad", text: "Bluesky did not answer")
    end

    it "opens a new contact from Add with the name, key and handle", :aggregate_failures do
      stub_bluesky_search("ada", ada)
      add_from("bluesky", "ada", "Ada Lovelace")

      expect(%w[given_name family_name key bluesky_handle].map { find_field("person[#{it}]").value })
        .to eq(%w[Ada Lovelace ada ada.bsky.social])
    end

    it "adds the contact it found" do
      stub_mastodon_search("grace", grace)
      add_from("mastodon", "grace", "Grace Hopper")
      click_button "Add contact"

      expect(page).to have_css("h1.contact-head-title", text: "Grace Hopper")
    end
  end

  it "offers only the networks with credentials" do
    connect_social_networks(bluesky: {})
    visit "/admin/contacts"

    expect(page).to have_css("#person-finder .seg-option.mastodon")
      .and have_no_css("#person-finder .seg-option.bluesky")
  end

  describe "the list" do
    before do
      create(:person, name: "Ada Lovelace", key: "ada", labels: %w[family])
      create(:person, name: "Grace Hopper", key: "grace")
      visit "/admin/contacts"
    end

    it "opens a contact's page from their name" do
      click_link "Ada Lovelace"

      expect(page).to have_css("h1.contact-head-title", text: "Ada Lovelace")
    end

    it "searches as I type" do
      fill_in "contacts-search", with: "grace"

      expect(page).to have_no_css(".contact-row-name", text: "Ada").and have_css(".contact-row-name", text: "Grace")
    end

    it "filters by a label" do
      within(".contacts-labels") { click_link "#family" }

      expect(page).to have_no_css(".contact-row-name", text: "Grace").and have_css(".contact-row-name", text: "Ada")
    end
  end

  describe "the editor" do
    let!(:person) { create(:person, name: "Ada Lovelace", key: "ada", emails: [{ value: "ada@example.com" }]) }

    before { visit "/admin/contacts/#{person.id}/edit" }

    it "adds a row" do
      click_button "+ add phone"
      find("input[name='person[phones][][value]']").fill_in(with: "+1 555 0100")
      click_button "Save"

      expect(page).to have_link("+1 555 0100", href: "tel:+15550100")
    end

    it "removes a row" do
      find("button[aria-label='Remove email']").click
      click_button "Save"

      expect(page).to have_no_link("ada@example.com")
    end

    it "shows the extra name fields on request" do
      click_button "Prefix, middle, suffix, phonetic, file as"
      fill_in "person[name_prefix]", with: "Countess"
      click_button "Save"

      expect(page).to have_css("h1.contact-head-title", text: "Countess Ada Lovelace")
    end

    it "adds a new label as a picked chip" do
      fill_in "person[new_label]", with: "Ruby Friends"
      click_button "Add"
      click_button "Save"

      expect(page).to have_css(".contact-head-labels .tag", text: "#ruby-friends")
    end

    it "asks before deleting here and in Google" do
      message = confirm_no { click_button "Delete" }

      expect(message).to eq(admin_t("ui.components.people.contact_editor.confirm_delete", name: "Ada Lovelace"))
    end

    it "deletes once I confirm" do
      confirm_yes { click_button "Delete" }

      expect(page).to have_css(".toast", text: "Contact deleted")
    end
  end
end
