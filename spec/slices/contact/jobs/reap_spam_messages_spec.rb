# frozen_string_literal: true

RSpec.describe Contact::Jobs::ReapSpamMessages, type: :request do
  let(:day) { 24 * 60 * 60 }
  let(:keep_for) { 30 * day }

  def kept = Contact::Slice["relations.messages"].to_a.map { it[:subject] }

  def later(seconds)
    now = Time.now + seconds
    allow(Time).to receive(:now).and_return(now)
  end

  def mark(message, status) = mcp_call("mark_message", id: message.id, status:)

  def reap = described_class.new.perform

  it "deletes a message marked spam more than 30 days ago" do
    mark(create(:message, subject: "Cheap pills"), "spam")
    later(keep_for + 60)
    reap

    expect(kept).to be_empty
  end

  it "keeps a message marked spam inside 30 days" do
    mark(create(:message, subject: "Cheap pills"), "spam")
    later(keep_for - 60)
    reap

    expect(kept).to eq(["Cheap pills"])
  end

  it "counts from the mark, not from when the message arrived" do
    mark(create(:message, subject: "Cheap pills", received_at: Time.now - (90 * day)), "spam")
    reap

    expect(kept).to eq(["Cheap pills"])
  end

  it "keeps the first mark when a spam message is marked spam again" do
    message = create(:message, :spam, subject: "Cheap pills", marked_spam_at: Time.now - keep_for + 60)
    mark(message, "spam")
    later(120)

    expect { reap }.to change { kept }.to([])
  end

  it "keeps unread and read messages whatever their age" do
    create(:message, subject: "Hello", received_at: Time.now - (400 * day))
    create(:message, :read, subject: "Thanks", received_at: Time.now - (400 * day))
    later(400 * day)
    reap

    expect(kept).to contain_exactly("Hello", "Thanks")
  end

  it "keeps a message moved back out of spam" do
    message = create(:message, :spam, subject: "Not spam after all")
    mark(message, "read")
    later(keep_for + 60)
    reap

    expect(kept).to eq(["Not spam after all"])
  end

  it "deletes only the spam marked more than 30 days ago" do
    create(:message, :spam, subject: "Old spam", marked_spam_at: Time.now - keep_for + 60)
    mark(create(:message, subject: "New spam"), "spam")
    later(120)

    expect { reap }.to change { kept }.to(["New spam"])
  end
end
