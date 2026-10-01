# frozen_string_literal: true

RSpec.describe "Admin people", type: :feature do
  let(:repo) { Social::Slice["repos.person_repo"] }

  def add(name:, key:, bluesky_handle:)
    visit "/admin/people/new"
    fill_in("person[name]", with: name)
    fill_in("person[key]", with: key)
    fill_in("person[bluesky_handle]", with: bluesky_handle)
    click_on "Add person"
  end

  before { sign_in_to_admin }

  def resolves(handle, did)
    stub_request(:get, "#{SocialNetworks::BLUESKY_PUBLIC}/com.atproto.identity.resolveHandle")
      .with(query: { handle: })
      .to_return(**json_response(did:))
  end

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  it "adds a person whose Bluesky handle resolves", :aggregate_failures do
    resolves("ada.bsky.social", "did:plc:ada")
    add(name: "Ada Lovelace", key: "ada", bluesky_handle: "ada.bsky.social")

    expect(page).to have_css(".toast", text: "Person added")
    expect(repo.all.map(&:bluesky_did)).to eq(%w[did:plc:ada])
  end

  it "edits a person" do
    person = create(:person, name: "Ada")
    visit "/admin/people/#{person.id}/edit"
    fill_in "person[name]", with: "Ada Lovelace"
    click_on "Save"

    expect(page).to have_css(".li-title", text: "Ada Lovelace")
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
