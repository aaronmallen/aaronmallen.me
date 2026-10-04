# frozen_string_literal: true

RSpec.describe Social::Operations::ModerateWebmention do
  def moderate(id, verdict, **) = Social::Slice["operations.moderate_webmention"].call(id, verdict, **)

  def spam_reason(mention) = stored(mention)[:spam_reason]

  def stored(mention) = Social::Slice["relations.webmentions"].by_pk(mention.id).one

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

  it "stores no reason for spam marked with only Unicode spaces" do
    mention = create(:webmention)
    moderate(mention.id, "spam", reason: "\u3000\u2003\u00a0")

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
  end

  it "fails as not found for a mention that is gone" do
    expect(moderate(create(:webmention).id + 1, "ignored").failure).to eq(:not_found)
  end
end
