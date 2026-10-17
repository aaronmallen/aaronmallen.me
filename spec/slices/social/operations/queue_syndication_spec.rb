# frozen_string_literal: true

RSpec.describe Social::Operations::QueueSyndication do
  describe "two queues of one post at once", :commits do
    def database = Social::Slice["db.rom"].gateways[:default].connection

    def held(post)
      other = Sequel.connect(database.opts.merge(max_connections: 1))
      other.transaction do
        other.get(Sequel.function(:pg_advisory_xact_lock, Sequel.function(:hashtext, "social_posts"), post.id))
        yield
      end
    ensure
      other&.disconnect
    end

    def queued_together(post)
      operation = Social::Slice["operations.queue_syndication"]
      operation.call(syndicated)

      held(post) do
        threads = Array.new(2) { Thread.new { operation.call(post) } }
        Spec::DB::Locks.wait_for_waiters(database, 2)
        threads
      end.map(&:value)
    end

    def syndicated = create(:post, :published, syndication_enabled: true, syndication_targets: %w[mastodon])

    before { connect_social_networks }

    it "stores one social post and turns the other away", :aggregate_failures do
      post = syndicated
      results = queued_together(post)

      expect(results.count(&:success?)).to eq(1)
      expect(results.reject(&:success?)).to contain_exactly(Failure(:already_queued))
      expect(Social::Slice["relations.social_posts"].for_post(post.id).count).to eq(1)
    end
  end
end
