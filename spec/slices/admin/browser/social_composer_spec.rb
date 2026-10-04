# frozen_string_literal: true

RSpec.describe "Admin social composer", type: :feature do
  let(:bluesky) { Social::Slice["networks.all"].fetch("bluesky") }
  let(:families) { "👨‍👩‍👧‍👦" * 121 }
  let(:link) { "Read https://aaronmallen.me/writing/hello and tell me" }
  let(:mastodon) { Social::Slice["networks.all"].fetch("mastodon") }

  def add_part = click_button("Add to thread")

  def bodies = all("[data-social-body]")

  def counts = all("[data-social-count-text]").map(&:text)

  def draft_button = find("[data-social-draft]")

  def meter(network) = find(".compose-count", text: network)

  def send_button = find("[data-social-send]")

  def toggle(network) = find(".compose-target", text: network).click

  def write(text, index: 0) = bodies[index].set(text)

  before do
    connect_social_networks
    sign_in_to_admin
    visit "/admin/social"
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
