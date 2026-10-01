# frozen_string_literal: true

RSpec.describe Social::Operations::ModerateWebmention do
  def moderate(id, verdict, **) = Social::Slice["operations.moderate_webmention"].call(id, verdict, **)

  def spam_reason(mention) = stored(mention)[:spam_reason]

  def status(mention) = stored(mention)[:status]

  def stored(mention) = Social::Slice["relations.webmentions"].by_pk(mention.id).one

  {
    "a pending mention" => [],
    "an approved mention" => [:approved],
    "a spam mention" => [:spam],
    "an ignored mention" => [:ignored],
  }.to_a.product(%w[approved spam ignored]).each do |(what, traits), verdict|
    it "stores #{what} as #{verdict}" do
      mention = create(:webmention, *traits)
      moderate(mention.id, verdict)

      expect(status(mention)).to eq(verdict)
    end
  end

  it "stores the reason given with spam" do
    mention = create(:webmention)
    moderate(mention.id, "spam", reason: "  link farm  ")

    expect(spam_reason(mention)).to eq("link farm")
  end

  it "stores no reason for spam marked without one" do
    mention = create(:webmention)
    moderate(mention.id, "spam", reason: " ")

    expect(spam_reason(mention)).to be_nil
  end

  it "replaces the reason when marked as spam again" do
    mention = create(:webmention, :spam, spam_reason: "link farm")
    moderate(mention.id, "spam")

    expect(spam_reason(mention)).to be_nil
  end

  %w[approved ignored].each do |verdict|
    it "clears the spam reason when #{verdict}" do
      mention = create(:webmention, :spam, spam_reason: "link farm")
      moderate(mention.id, verdict)

      expect(spam_reason(mention)).to be_nil
    end

    it "keeps no reason given with #{verdict}" do
      mention = create(:webmention)
      moderate(mention.id, verdict, reason: "link farm")

      expect(spam_reason(mention)).to be_nil
    end
  end

  it "answers with the moderated mention" do
    mention = create(:webmention)

    expect(moderate(mention.id, "ignored").value!).to have_attributes(id: mention.id, status: "ignored")
  end

  it "fails as not found for a mention that is gone" do
    expect(moderate(create(:webmention).id + 1, "ignored").failure).to eq(:not_found)
  end
end
