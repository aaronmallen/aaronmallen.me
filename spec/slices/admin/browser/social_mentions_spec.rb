# frozen_string_literal: true

RSpec.describe "Admin social mentions", type: :feature do
  def body(index = 0) = all("[data-social-body]")[index]

  def choices = all("#social-mentions [role='option']").map { it.text.strip }

  def chosen = find("#social-mentions [aria-selected='true']")

  def counts = all("[data-social-count-text]").map(&:text)

  def dialog = find("dialog#person-dialog[open]")

  def groups = all(".compose-mention-group").map { it.text.downcase }

  def list = find("[data-social-mentions]")

  def names = all("[data-social-mention]").map { it.find(".compose-mention-name").text }

  def preview(network) = "[data-social-preview-line='#{network}'] [data-social-preview-text]"

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

        expect { names }.to eventually(eq(["Ada Lovelace", "Grace Hopper", "Alan Kay"]))
      end

      it "groups people by the networks they are on" do
        type "@"

        expect { groups }.to eventually(eq(["mastodon and bluesky", "mastodon only", "bluesky only"]))
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

      it "ends with Add New" do
        type "@"

        expect(choices.last).to eq("Add New")
      end

      it "keeps only Add New when nobody matches" do
        type "@zzz"

        expect(choices).to eq(["Add New"])
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

        expect(body).to match_selector(:field, with: "hi @{grace-hopper} ")
      end

      it "inserts the token on Tab" do
        type "hi @", :down, :tab

        expect(body).to match_selector(:field, with: "hi @{grace-hopper} ")
      end

      it "keeps the focus in the text box after a choice" do
        type "@", :tab

        expect(evaluate_script("document.activeElement.matches('[data-social-body]')")).to be(true)
      end

      it "shuts on Escape with the text as typed", :aggregate_failures do
        type "hi @gr", :escape

        expect(page).to have_no_css("[data-social-mentions]", visible: :visible)
        expect(body).to match_selector(:field, with: "hi @gr")
      end

      it "leaves Enter alone once the list is shut" do
        type "@gr", :escape, :enter

        expect(body).to match_selector(:field, with: "@gr\n")
      end

      it "replaces only the word at the caret" do
        type "@ad", :enter, "and @kay", :enter

        expect(body).to match_selector(:field, with: "@{ada-lovelace} and @{alan-kay} ")
      end
    end

    describe "the pointer" do
      it "inserts the person clicked" do
        type "@"
        find(".compose-mention", text: "Alan Kay").click

        expect(body).to match_selector(:field, with: "@{alan-kay} ")
      end

      it "inserts the person tapped on a phone", :aggregate_failures do
        page.driver.resize(375, 800)
        type "@"

        expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.documentElement)")).to be(false)
        find(".compose-mention", text: "Grace Hopper").click
        expect(body).to match_selector(:field, with: "@{grace-hopper} ")
      end

      it "fits the list inside a phone's width", :aggregate_failures do
        page.driver.resize(375, 800)
        type "@"
        box = evaluate_script("document.querySelector('[data-social-mentions]').getBoundingClientRect().toJSON()")

        expect(box["left"]).to be >= 0
        expect(box["right"]).to be <= 375
      end
    end

    describe "the counters" do
      it "counts the handle each network gets" do
        type "hi @kay", :enter

        expect(counts).to eq(["Mastodon 12/500", "Bluesky 21/300"])
      end

      it "turns a part pink once its mention runs it over the limit", :aggregate_failures do
        body.set("@{alan-kay} #{'a' * 285}")

        expect(page).to have_css(".compose-count.over", text: "Bluesky")
        expect(find("[data-social-send]")).to be_disabled
      end
    end

    describe "the preview" do
      it "stays hidden until a mention is typed" do
        type "hello"

        expect(page).to have_no_css("[data-social-preview]", visible: :visible)
      end

      it "shows each network's text with its handle in place", :aggregate_failures do
        type "hi @ad", :enter

        expect(page).to have_css(preview("mastodon"), text: /\Ahi @person\d+@ruby\.social\z/)
        expect(page).to have_css(preview("bluesky"), text: /\Ahi @person-\d+\.bsky\.social\z/)
      end

      it "shows a plain name where the person has no handle" do
        type "hi @kay", :enter

        expect(page).to have_css(preview("mastodon"), exact_text: "hi Alan Kay")
      end

      it "drops the line of a network turned off" do
        type "hi @kay", :enter
        find(".compose-accounts summary").click
        find(".compose-account-group.bluesky .compose-account").click

        expect(page).to have_no_css("[data-social-preview-line='bluesky']", visible: :visible)
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

    it "offers Add New" do
      type "@"

      expect(choices).to eq(["Add New"])
    end
  end

  describe "adding someone new" do
    let(:person_queries) { Social::Slice["repos.person_queries"] }

    def add_new(text = "hi @Ada Lovelace") = type(text, :enter)

    before do
      create(:person, name: "Grace Hopper", key: "grace-hopper")
      connect_social_networks
      sign_in_to_admin
      visit "/admin/social"
    end

    it "opens the dialog on Enter and inserts no token", :aggregate_failures do
      type "hi @zed", :enter

      expect(dialog).to have_css("form[data-person-form='new']")
      expect(body).to match_selector(:field, with: "hi @zed")
    end

    it "opens the dialog on Tab" do
      type "hi @zed", :tab

      expect(dialog).to have_field("person[name]")
    end

    it "opens the dialog on a click", :aggregate_failures do
      type "hi @"
      find("[data-social-mention-add]").click

      expect(dialog).to have_field("person[name]")
      expect(body).to match_selector(:field, with: "hi @")
    end

    it "fills the name from what follows the @" do
      type "hi @zed", :enter

      expect(dialog).to have_field("person[name]", with: "zed")
    end

    it "fills the key from the name" do
      type "hi @zed", :enter
      dialog.fill_in("person[name]", with: "Zed Shaw")

      expect(dialog).to have_field("person[key]", with: "zed-shaw")
    end

    it "stops filling the key once I edit it" do
      type "hi @zed", :enter
      dialog.fill_in("person[key]", with: "zed")
      dialog.fill_in("person[name]", with: "Zed Shaw")

      expect(dialog).to have_field("person[key]", with: "zed")
    end

    it "shows a refusal in the dialog and keeps what I entered", :aggregate_failures do
      type "hi @zed", :enter
      dialog.click_button "Add person"

      expect(dialog).to have_css("#person-handles-error")
      expect(dialog).to have_field("person[name]", with: "zed")
      expect(body).to match_selector(:field, with: "hi @zed")
    end

    describe "a good save" do
      before do
        type "hi @zed", :enter
        dialog.fill_in("person[name]", with: "Zed Shaw")
        dialog.fill_in("person[mastodon_handle]", with: "@zed@ruby.social")
        dialog.click_button "Add person"
      end

      it "closes the dialog and stores the person", :aggregate_failures do
        expect(page).to have_no_css("dialog#person-dialog[open]")
        expect(person_queries.all.map(&:key)).to contain_exactly("grace-hopper", "zed-shaw")
      end

      it "puts their token in place of what I typed" do
        expect(body).to match_selector(:field, with: "hi @{zed-shaw} ")
      end

      it "gives the focus back to the text box" do
        expect(page).to have_css("[data-social-body]:focus")
      end

      it "adds them to the list without a reload" do
        type "@"

        expect { names }.to eventually(eq(["Grace Hopper", "Zed Shaw"]))
      end

      it "previews their handle for each network", :aggregate_failures do
        expect(page).to have_css(preview("mastodon"), exact_text: "hi @zed@ruby.social")
        expect(page).to have_css(preview("bluesky"), exact_text: "hi Zed Shaw")
      end
    end

    it "keeps the post text after a cancel", :aggregate_failures do
      type "hi @zed", :enter
      dialog.find("[data-dialog-close]").click

      expect(page).to have_no_css("dialog#person-dialog[open]")
      expect(body).to match_selector(:field, with: "hi @zed")
    end

    it "keeps the post text after Escape", :aggregate_failures do
      type "hi @zed", :enter
      dialog.find_field("person[name]").send_keys(:escape)

      expect(page).to have_no_css("dialog#person-dialog[open]")
      expect(body).to match_selector(:field, with: "hi @zed")
    end
  end
end
