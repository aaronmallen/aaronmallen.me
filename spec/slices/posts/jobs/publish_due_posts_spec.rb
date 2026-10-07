# frozen_string_literal: true

RSpec.describe Posts::Jobs::PublishDuePosts do
  let(:post_mutations) { Posts::Slice["repos.post_mutations"] }
  let(:post_queries) { Posts::Slice["repos.post_queries"] }

  def due(**) = create(:post, :scheduled, published_at: Time.now.round - 60, **)

  def later = Time.now.round + 3600

  def perform = described_class.new.perform

  def perform_with_edit_after_select(posts = nil, **edit)
    allow(post_queries).to(receive(:due_scheduled).and_wrap_original do |select, *args|
      select.call(*args).tap { |due| (posts || due).each { post_mutations.update(it.id, edit) } }
    end)
    replace_component("repos.post_queries", post_queries)
    perform
  end

  def perform_with_failures(*broken)
    publish_post = Posts::Slice["operations.publish_post"]
    allow(publish_post).to(receive(:call).and_wrap_original do |publish, id, **options|
      failure = broken.find { it.first.id == id }
      failure ? raise(failure.last) : publish.call(id, **options)
    end)
    replace_component("operations.publish_post", publish_post)
    perform
  end

  def published_ids = queued.map { it["args"].first }

  def queued = [Social::Jobs::SyndicatePost, Social::Jobs::SendWebmentions].flat_map(&:jobs)

  def reloaded(post) = post_queries.by_id(post.id)

  it "publishes a scheduled post whose publish time has passed" do
    post = due
    perform

    expect(reloaded(post).status).to eq("published")
  end

  it "keeps the scheduled publish time" do
    post = due
    perform

    expect(reloaded(post).published_at).to eq(post.published_at)
  end

  it "publishes every due post in one run" do
    posts = [due, due]
    perform

    expect(posts.map { reloaded(it).status }).to all(eq("published"))
  end

  it "queues the cross-post and webmentions for a post it publishes", :commits do
    post = due
    perform

    expect(published_ids).to eq([post.id, post.id])
  end

  it "keeps a scheduled post with a future publish time scheduled" do
    post = create(:post, :scheduled, published_at: Time.now + 60)
    perform

    expect(reloaded(post).status).to eq("scheduled")
  end

  it "leaves drafts alone" do
    post = create(:post, :draft)
    perform

    expect(reloaded(post).status).to eq("draft")
  end

  it "leaves published posts alone", :aggregate_failures, :commits do
    post = create(:post, :published)
    perform

    expect(reloaded(post).updated_at).to eq(post.updated_at)
    expect(queued).to be_empty
  end

  it "never publishes a post twice when run twice", :aggregate_failures, :commits do
    post = due
    2.times { perform }

    expect(reloaded(post).status).to eq("published")
    expect(published_ids).to eq([post.id, post.id])
  end

  it "leaves a post moved back to draft after the select a draft", :aggregate_failures, :commits do
    post = due
    perform_with_edit_after_select(status: "draft", published_at: nil)

    expect(reloaded(post).status).to eq("draft")
    expect(queued).to be_empty
  end

  it "leaves a post moved later after the select scheduled at the later time", :aggregate_failures, :commits do
    post = due
    at = later
    perform_with_edit_after_select(published_at: at)

    expect(reloaded(post)).to have_attributes(status: "scheduled", published_at: at)
    expect(queued).to be_empty
  end

  it "publishes the rest when one post moves after the select" do
    moved = due
    kept = due
    perform_with_edit_after_select([moved], published_at: later)

    expect([moved, kept].map { reloaded(it).status }).to eq(%w[scheduled published])
  end

  describe "a post that raises" do
    let(:agent) { Hanami.app["honeybadger.agent"] }
    let(:crash) { RuntimeError.new("the post broke") }
    let(:other_crash) { RuntimeError.new("another post broke") }

    def first_due = due(published_at: Time.now.round - 120)

    def perform_past(*)
      perform_with_failures(*)
    rescue RuntimeError
      nil
    end

    before { allow(agent).to receive(:notify) }

    it "publishes every other due post" do
      kept = [due, due]
      perform_past([first_due, crash])

      expect(kept.map { reloaded(it).status }).to all(eq("published"))
    end

    it "leaves the post that raised scheduled" do
      broken = first_due
      perform_past([broken, crash])

      expect(reloaded(broken).status).to eq("scheduled")
    end

    it "fails the job with what the post raised" do
      expect { perform_with_failures([first_due, crash]) }.to raise_error(crash)
    end

    it "fails the job with what the first post raised when two raise" do
      expect { perform_with_failures([first_due, crash], [due, other_crash]) }.to raise_error(crash)
    end

    it "leaves the one error it raises for Sidekiq to report" do
      perform_past([first_due, crash])

      expect(agent).not_to have_received(:notify)
    end

    it "tells Honeybadger what each other post raised" do
      perform_past([first_due, crash], [due, other_crash])

      expect(agent).to have_received(:notify).with(other_crash).once
    end
  end
end
