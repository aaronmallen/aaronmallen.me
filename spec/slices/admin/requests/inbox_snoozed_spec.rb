# frozen_string_literal: true

RSpec.describe "Admin inbox snoozed section", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def act(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def inbox = page.all("[data-key-list] .li .li-title").map(&:text)

  def show
    get "/admin/inbox"
    page
  end

  def sleeper(kind)
    {
      message: -> { create(:message, subject: "Woken", received_at: Time.now - 600) },
      webmention: -> { create(:webmention, author_name: "Woken", received_at: Time.now - 600) },
      task: -> { synced("Woken") },
    }.fetch(kind).call
  end

  def snooze(kind, record, ends_at)
    slice = { message: Contact::Slice, webmention: Social::Slice, task: Tasks::Slice }.fetch(kind)
    slice["operations.snooze_#{kind}s"].call([record.id], ends_at)
  end

  def snoozed = page.all("#inbox-snoozed .li .li-title", visible: :all).map { it.text(:all) }

  def synced(title) = create(:task, title:, list: "external").tap { create(:task_source, task: it) }

  def wake(kind, record)
    act("/admin/inbox/wake/#{kind}/#{record.id}")
    follow_redirect!
  end

  before { sign_in_to_admin }

  it "hides when nothing is snoozed" do
    create(:message)

    expect(show).to have_no_css("#inbox-snoozed")
  end

  describe "with one snoozed row of each kind" do
    before do
      snooze(:task, synced("Issue"), Time.now + 300)
      snooze(:message, create(:message, subject: "Message"), Time.now + 100)
      snooze(:webmention, create(:webmention, author_name: "Mention"), Time.now + 200)
      show
    end

    it "lists every snoozed row, soonest first, and none in the inbox" do
      expect([snoozed, inbox]).to eq([%w[Message Mention Issue], []])
    end

    it "starts collapsed" do
      expect(page).to have_css("#inbox-snoozed details:not([open])")
    end

    it "says what kind each row is and when it wakes", :aggregate_failures do
      expect(page.all("#inbox-snoozed .pill", visible: :all).map { it.text(:all) }).to eq(%w[message webmention issue])
      expect(page.all("#inbox-snoozed time", visible: :all).size).to eq(3)
    end
  end

  it "puts the wake time in a time tag" do
    ends_at = Time.utc(2027, 1, 4, 15)
    snooze(:message, create(:message), ends_at)

    expect(show.find("#inbox-snoozed time", visible: :all)[:datetime]).to eq("2027-01-04T09:00:00-06:00")
  end

  it "leaves out a snoozed row that would no longer wait", :aggregate_failures do
    snooze(:message, create(:message, :read), Time.now + 100)
    snooze(:webmention, create(:webmention, :approved), Time.now + 100)
    snooze(:task, create(:task, :done, list: "external").tap { create(:task_source, task: it) }, Time.now + 100)

    expect(show).to have_no_css("#inbox-snoozed")
  end

  it "leaves out a row whose snooze has ended", :aggregate_failures do
    snooze(:message, create(:message, subject: "Back"), Time.now - 60)
    show

    expect([inbox, page.has_css?("#inbox-snoozed")]).to eq([["Back"], false])
  end

  %i[message webmention task].each do |kind|
    it "wakes a #{kind} to the top of the inbox", :aggregate_failures do
      create(:message, subject: "Newer", received_at: Time.now)
      wake(kind, sleeper(kind).tap { snooze(kind, it, Time.now + 3600) })

      expect(inbox).to eq(%w[Woken Newer])
      expect(page).to have_no_css("#inbox-snoozed")
      expect(page).to have_text("Back in the inbox")
    end
  end

  it "answers 422 for a row that is not snoozed" do
    act("/admin/inbox/wake/message/#{create(:message).id}")

    expect(last_response.status).to eq(422)
  end

  it "answers 404 for a row that isn't there or a kind it does not know", :aggregate_failures do
    act("/admin/inbox/wake/message/0")
    expect(last_response.status).to eq(404)

    act("/admin/inbox/wake/comet/#{create(:message).id}")
    expect(last_response.status).to eq(404)
  end
end
