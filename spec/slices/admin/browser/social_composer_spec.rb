# frozen_string_literal: true

RSpec.describe "Admin social composer", type: :feature do
  let(:bluesky) { Social::Slice["networks.all"].fetch("bluesky") }
  let(:families) { "👨‍👩‍👧‍👦" * 121 }
  let(:link) { "Read https://aaronmallen.me/writing/hello and tell me" }
  let(:mastodon) { Social::Slice["networks.all"].fetch("mastodon") }

  def add_part = click_button("Add to thread")

  def bodies = all("[data-social-body]")

  def chips = all(".compose-chip").map { it.text.strip }

  def counts = all("[data-social-count-text]").map(&:text)

  def draft_button = find("[data-social-draft]")

  def height(selector) = evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().height")

  def meter(network) = find(".compose-count", text: network)

  def open_accounts = find(".compose-accounts summary").click

  def picked = all("[data-social-target]:checked", visible: :all).map(&:value)

  def remember(*accounts)
    execute_script("localStorage.setItem('social:accounts', arguments[0])", JSON.generate(accounts.map(&:to_s)))
    visit "/admin/social"
  end

  def remove_chip(account) = find("button[aria-label='Remove #{account}']").click

  def send_button = find("[data-social-send]")

  def toggle(network)
    open_accounts if has_no_css?(".compose-accounts[open]", wait: false)
    find(".compose-account-group.#{network.downcase} .compose-account").click
  end

  def write(text, index: 0) = bodies[index].set(text)

  before do
    connect_social_networks
    sign_in_to_admin
    visit "/admin/social"
    remember(social_account("mastodon").id, social_account("bluesky").id)
  end

  describe "the account picker" do
    it "counts the accounts left ticked" do
      toggle "Bluesky"

      expect(page).to have_css(".compose-accounts summary", text: "1 of 2")
    end

    it "grows the rows to touch size on a narrow screen" do
      page.driver.resize(375, 800)
      open_accounts

      expect(height(".compose-account")).to be >= 44
    end

    it "shows a chip for each picked account" do
      expect(chips).to eq(["@aaronmallen", "@ada.example"])
    end

    it "unticks an account from its chip" do
      remove_chip "@ada.example"

      expect(chips).to eq(["@aaronmallen"])
    end

    it "tints a chip by its network" do
      expect(page).to have_css(".compose-chip.bluesky", text: "@ada.example")
    end

    it "asks for an account when none is picked" do
      write "hello"
      remove_chip "@aaronmallen@ruby.social"
      remove_chip "@ada.example"

      expect(page).to have_css(".compose-to", text: "Pick at least one account")
    end

    it "shows the hosts of two picked accounts with the same handle" do
      connect_another_mastodon(host: "hachyderm.io")
      connect_another_mastodon(host: "mastodon.social")
      remember_social_accounts

      expect(all(".compose-chip-host").map(&:text)).to eq(%w[hachyderm.io mastodon.social])
    end

    context "with four accounts" do
      before do
        connect_another_bluesky
        connect_another_mastodon
        remember_social_accounts
      end

      it "folds the chips past three into a button" do
        expect(chips).to eq(["@aaronmallen", "@ada", "@ada.example"])
      end

      it "opens the menu from the button" do
        click_button "+1 more"

        expect(page).to have_css(".compose-accounts[open]")
      end

      it "ticks every account in a group" do
        open_accounts
        within(".compose-account-group.bluesky") { click_button "none" }
        within(".compose-account-group.bluesky") { click_button "all 2" }

        expect(page).to have_css(".compose-accounts summary", text: "4 of 4")
      end
    end

    it "leaves the group link off a group of one" do
      open_accounts

      expect(page).to have_no_css(".compose-account-group.bluesky [data-social-group]", visible: :visible)
    end

    it "picks every account then clears them" do
      toggle "Bluesky"
      click_button "Everywhere"
      click_button "Clear"

      expect(page).to have_css(".compose-to", text: "Pick at least one account")
    end

    it "closes the menu on Esc" do
      open_accounts
      find(".compose-accounts summary").send_keys(:escape)

      expect(page).to have_no_css(".compose-accounts[open]")
    end

    it "closes the menu on a click outside it" do
      open_accounts
      find("main").click(x: 5, y: 5)

      expect(page).to have_no_css(".compose-accounts[open]")
    end

    it "leaves the search off with five accounts or fewer" do
      open_accounts

      expect(page).to have_no_field("Find an account")
    end

    it "grows the chip buttons to touch size on a narrow screen" do
      page.driver.resize(375, 800)

      expect(height(".compose-chip-remove")).to be >= 44
    end

    context "with more than five accounts" do
      before do
        %w[a.example b.example c.example].each { connect_another_mastodon(host: it) }
        connect_another_bluesky
        remember_social_accounts
        open_accounts
      end

      it "filters the rows by handle, ignoring case and a leading @" do
        fill_in "Find an account", with: "@GRACE"

        expect(page).to have_css(".compose-account", count: 1, text: "@grace.example")
      end

      it "says when no account matches" do
        fill_in "Find an account", with: "zed"

        expect(page).to have_css(".compose-accounts-menu", text: /No account matches .zed./)
      end

      it "acts on the rows left with the group link" do
        fill_in "Find an account", with: "ada"
        within(".compose-account-group.mastodon") { click_button "none" }

        expect(page).to have_css(".compose-accounts summary", text: "3 of 6")
      end
    end
  end

  describe "the remembered accounts" do
    def bluesky_id = social_account("bluesky").id.to_s

    def mastodon_id = social_account("mastodon").id.to_s

    def pick_bluesky_and_write
      toggle "Mastodon"
      write "hello"
    end

    def reopen
      find("[data-toast]")
      visit "/admin/social"
    end

    def schedule_for(time)
      find(".seg-option", text: "schedule").click
      fill_in "Send time (Chicago)", with: time
      send_button.click
    end

    it "starts a new post with the accounts last sent to" do
      remember(bluesky_id)

      expect(picked).to eq([bluesky_id])
    end

    it "remembers the accounts a sent post went to" do
      pick_bluesky_and_write
      send_button.click
      reopen

      expect(picked).to eq([bluesky_id])
    end

    it "remembers the accounts of a scheduled post" do
      pick_bluesky_and_write
      schedule_for "2099-03-01T09:30"
      reopen

      expect(picked).to eq([bluesky_id])
    end

    it "remembers nothing when a draft is saved" do
      pick_bluesky_and_write
      draft_button.click
      reopen

      expect(picked).to eq([mastodon_id, bluesky_id])
    end

    it "ticks the first account when none it remembers is still connected" do
      remember(0)

      expect(picked).to eq([mastodon_id])
    end

    it "ticks the first account with nothing remembered" do
      execute_script("localStorage.clear()")
      visit "/admin/social"

      expect(picked).to eq([mastodon_id])
    end

    it "keeps a draft's own accounts when it opens" do
      draft = Social::Slice["repos.social_post_mutations"].create_with_parts(
        parts: %w[hi], targets: %w[bluesky], connection_ids: [bluesky_id.to_i], status: "draft",
      )
      visit "/admin/social?edit=#{draft.id}"

      expect(picked).to eq([bluesky_id])
    end
  end

  describe "the thread" do
    it "adds a part" do
      add_part

      expect(page).to have_css("[data-social-part]", count: 2)
    end

    it "counts each part on its own" do
      add_part
      write "hello"

      expect(counts).to eq(["Mastodon 5/500", "Bluesky 5/300", "Mastodon 0/500", "Bluesky 0/300"])
    end

    it "removes a part" do
      add_part
      all("[data-social-remove]").last.click

      expect(page).to have_css("[data-social-part]", count: 1)
    end

    it "keeps the text of the parts it keeps" do
      add_part
      write "first"
      write "second", index: 1
      all("[data-social-remove]").last.click

      expect(bodies.map(&:value)).to eq(%w[first])
    end

    it "hides the remove button while there is one part" do
      expect(page).to have_no_css("[data-social-remove]", visible: :visible)
    end

    it "shows the remove button once there is a thread" do
      add_part

      expect(page).to have_css("[data-social-remove]", count: 2, visible: :visible)
    end
  end

  describe "the counters" do
    it "counts as you type" do
      write "hello"

      expect(counts.first).to eq("Mastodon 5/500")
    end

    it "counts a link the way Mastodon does" do
      write link

      expect(counts.first).to eq("Mastodon #{mastodon.count(link)}/500")
    end

    %w[(https://example.com/a(b)) (https://x.y/z)) [https://x.y/z] https://x.y/a[b]].each do |bracketed|
      it "trims the brackets of #{bracketed} the way Mastodon does" do
        write "see #{bracketed}"

        expect(counts.first).to eq("Mastodon #{mastodon.count("see #{bracketed}")}/500")
      end
    end

    it "turns a part over the Mastodon limit pink once its link trims" do
      tail = " (https://example.com/a(b))"
      write ("a" * (501 - mastodon.count(tail))) + tail

      expect(page).to have_css(".compose-count.over", text: "Mastodon")
    end

    it "counts a link to the site with the tag Bluesky sends" do
      write link

      expect(counts.last).to eq("Bluesky #{bluesky.count(link.sub('/hello', '/hello?ref=bluesky'))}/300")
    end

    {
      "https://example.com/hello" => "https://example.com/hello",
      "https://aaronmallen.me" => "https://aaronmallen.me/?ref=bluesky",
      "https://aaronmallen.me/a?b=c#d" => "https://aaronmallen.me/a?b=c&ref=bluesky#d",
      "https://aaronmallen.me/a?ref=x" => "https://aaronmallen.me/a?ref=x",
      "(https://aaronmallen.me/a)" => "(https://aaronmallen.me/a?ref=bluesky)",
    }.each do |typed, sent|
      it "counts #{typed} as Bluesky gets it" do
        write "see #{typed}"

        expect(counts.last).to eq("Bluesky #{bluesky.count("see #{sent}")}/300")
      end
    end

    it "turns a part over the Bluesky limit pink once its link to the site is tagged" do
      write "#{'a' * 262} https://aaronmallen.me/writing/hello"

      expect(page).to have_css(".compose-count.over", text: "Bluesky")
    end

    it "counts emoji the way Bluesky does" do
      write "👍🏽 👨‍👩‍👧 done"

      expect(counts.last).to eq("Bluesky #{bluesky.count('👍🏽 👨‍👩‍👧 done')}/300")
    end

    it "mutes a network that is off" do
      toggle "Bluesky"

      expect(page).to have_css(".compose-count.off", text: "Bluesky")
    end

    it "turns a part over the limit pink" do
      write "a" * 301

      expect(page).to have_css(".compose-count.over", text: "Bluesky")
    end

    it "turns a part under the grapheme limit and over the byte limit pink" do
      write families

      expect(page).to have_css(".compose-count.over", text: "Bluesky")
    end

    it "fills the meter of a part over the byte limit" do
      write families

      expect(meter("Bluesky")).to have_css("[data-social-meter][style*='width: 100%']")
    end

    it "fills the meter to the count while both limits hold" do
      write "a" * 150

      expect(meter("Bluesky")).to have_css("[data-social-meter][style*='width: 50%']")
    end

    it "leaves a network under its limit green" do
      write "a" * 301

      expect(page).to have_no_css(".compose-count.over", text: "Mastodon")
    end
  end

  describe "the buttons" do
    it "disables posting with nothing written" do
      expect(send_button).to be_disabled
    end

    it "enables posting once something is written" do
      write "hello"

      expect(send_button).not_to be_disabled
    end

    it "disables posting with no network on" do
      write "hello"
      toggle "Mastodon"
      toggle "Bluesky"

      expect(send_button).to be_disabled
    end

    it "disables posting with a part over a selected limit" do
      write "a" * 301

      expect(send_button).to be_disabled
    end

    it "disables posting with a part over the byte limit" do
      write families

      expect(send_button).to be_disabled
    end

    it "enables posting once the network over its limit is off" do
      write "a" * 301
      toggle "Bluesky"

      expect(send_button).not_to be_disabled
    end

    it "disables posting when any part of a thread is over a limit" do
      write "hello"
      add_part
      write "a" * 301, index: 1

      expect(send_button).to be_disabled
    end

    it "enables the draft button over a limit" do
      write "a" * 301

      expect(draft_button).not_to be_disabled
    end

    it "disables the draft button with no network on" do
      write "hello"
      toggle "Mastodon"
      toggle "Bluesky"

      expect(draft_button).to be_disabled
    end
  end

  describe "the send time" do
    it "hides the schedule field while posting now" do
      expect(page).to have_no_field("Send time (Chicago)")
    end

    it "reveals the schedule field" do
      find(".seg-option", text: "schedule").click

      expect(page).to have_field("Send time (Chicago)")
    end

    it "renames the button for a scheduled post" do
      find(".seg-option", text: "schedule").click

      expect(send_button).to have_text("Schedule")
    end

    it "hides the schedule field again" do
      find(".seg-option", text: "schedule").click
      find(".seg-option", text: "post now").click

      expect(page).to have_no_field("Send time (Chicago)")
    end
  end

  it "queues what was written" do
    write "hello"
    send_button.click

    expect(page).to have_css("[data-toast]", text: "Queued for Mastodon + Bluesky")
  end
end
