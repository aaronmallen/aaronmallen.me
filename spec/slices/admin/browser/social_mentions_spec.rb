# frozen_string_literal: true

RSpec.describe "Admin social mentions", type: :feature do
  def body(index = 0) = all("[data-social-body]")[index]

  def chosen = find("#social-mentions [aria-selected='true']")

  def groups = all(".compose-mention-group").map { it.text.downcase }

  def list = find("[data-social-mentions]")

  def names = all("[data-social-mention]").map { it.find(".compose-mention-name").text }

  def type(*keys, index: 0) = body(index).send_keys(*keys)

  describe "with people in the directory" do
    before do
      create(:person, :bluesky, name: "Ada Lovelace", key: "ada-lovelace")
      create(:person, name: "Grace Hopper", key: "grace-hopper")
      create(:person, name: "Alan Kay", key: "alan-kay", mastodon_handle: nil, bluesky_handle: "alan.bsky.social",
                      bluesky_did: "did:plc:alan")
      connect_social_networks
      sign_in_to_admin
      visit "/admin/social"
    end

    describe "the list" do
      it "stays shut until an @ is typed" do
        type "hello"

        expect(page).to have_no_css("[data-social-mentions]", visible: :visible)
      end

      it "offers everyone on @" do
        type "@"

        expect(names).to eq(["Ada Lovelace", "Grace Hopper", "Alan Kay"])
      end

      it "groups people by the networks they are on" do
        type "@"

        expect(groups).to eq(["mastodon and bluesky", "mastodon only", "bluesky only"])
      end

      it "shows each person's handles" do
        type "@"

        expect(find(".compose-mention",
                    text: "Alan Kay")).to have_css(".compose-mention-handles", text: "alan.bsky.social")
      end

      it "narrows as you type" do
        type "@ad"

        expect(names).to eq(["Ada Lovelace"])
      end

      it "matches a handle" do
        type "@bsky"

        expect(names).to eq(["Ada Lovelace", "Alan Kay"])
      end

      it "hides a group with nobody left in it" do
        type "@grace"

        expect(groups).to eq(["mastodon only"])
      end

      it "shuts when nobody matches" do
        type "@zzz"

        expect(page).to have_no_css("[data-social-mentions]", visible: :visible)
      end

      it "stays shut for an @ inside a word" do
        type "mail ada@"

        expect(page).to have_no_css("[data-social-mentions]", visible: :visible)
      end

      it "opens in a part added to the thread" do
        click_button "Add to thread"
        type "@gr", index: 1

        expect(names).to eq(["Grace Hopper"])
      end

      it "shuts when the text box loses focus" do
        type "@"
        find("h1").click

        expect(page).to have_no_css("[data-social-mentions]", visible: :visible)
      end
    end

    describe "the keyboard" do
      it "starts on the first person" do
        type "@"

        expect(chosen).to have_text("Ada Lovelace")
      end

      it "moves down with the arrow key" do
        type "@", :down

        expect(chosen).to have_text("Grace Hopper")
      end

      it "moves back up with the arrow key" do
        type "@", :down, :down, :up

        expect(chosen).to have_text("Grace Hopper")
      end

      it "inserts the token on Enter" do
        type "hi @gr", :enter

        expect(body.value).to eq("hi @{grace-hopper} ")
      end

      it "inserts the token on Tab" do
        type "hi @", :down, :tab

        expect(body.value).to eq("hi @{grace-hopper} ")
      end

      it "keeps the focus in the text box after a choice" do
        type "@", :tab

        expect(evaluate_script("document.activeElement.matches('[data-social-body]')")).to be(true)
      end

      it "shuts on Escape with the text as typed", :aggregate_failures do
        type "hi @gr", :escape

        expect(page).to have_no_css("[data-social-mentions]", visible: :visible)
        expect(body.value).to eq("hi @gr")
      end

      it "leaves Enter alone once the list is shut" do
        type "@gr", :escape, :enter

        expect(body.value).to eq("@gr\n")
      end

      it "replaces only the word at the caret" do
        type "@ad", :enter, "and @kay", :enter

        expect(body.value).to eq("@{ada-lovelace} and @{alan-kay} ")
      end
    end

    describe "the pointer" do
      it "inserts the person clicked" do
        type "@"
        find(".compose-mention", text: "Alan Kay").click

        expect(body.value).to eq("@{alan-kay} ")
      end

      it "inserts the person tapped on a phone", :aggregate_failures do
        page.driver.resize(375, 800)
        type "@"

        expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.documentElement)")).to be(false)
        find(".compose-mention", text: "Grace Hopper").click
        expect(body.value).to eq("@{grace-hopper} ")
      end

      it "fits the list inside a phone's width", :aggregate_failures do
        page.driver.resize(375, 800)
        type "@"
        box = evaluate_script("document.querySelector('[data-social-mentions]').getBoundingClientRect().toJSON()")

        expect(box["left"]).to be >= 0
        expect(box["right"]).to be <= 375
      end
    end

    describe "a screen reader" do
      it "hears the person under the arrow key" do
        type "@", :down

        expect(body["aria-activedescendant"]).to eq("social-mentions-grace-hopper")
      end

      it "ties the text box to the list", :aggregate_failures do
        expect(body["aria-controls"]).to eq("social-mentions")
        expect(body["aria-autocomplete"]).to eq("list")
        expect(body["aria-haspopup"]).to eq("listbox")
      end

      it "hears how many people match" do
        type "@bsky"

        expect(page).to have_css("[data-social-mention-status]", text: "2 people", visible: :all)
      end

      it "hears who was chosen" do
        type "@gr", :enter

        expect(page).to have_css("[data-social-mention-status]", text: "Mentioned Grace Hopper", visible: :all)
      end

      it "drops the active person once the list shuts" do
        type "@", :escape

        expect(body["aria-activedescendant"]).to be_nil
      end
    end
  end

  describe "with nobody in the directory" do
    before do
      connect_social_networks
      sign_in_to_admin
      visit "/admin/social"
    end

    it "offers no list" do
      type "@"

      expect(page).to have_no_css("[data-social-mentions]", visible: :all)
    end
  end
end
