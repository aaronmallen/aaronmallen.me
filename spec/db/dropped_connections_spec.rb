# frozen_string_literal: true

RSpec.describe "Dropped database connections", :commits, type: :app do
  let(:post_queries) { Posts::Slice["repos.post_queries"] }

  def databases
    Hanami.app.with_slices.select { it.key?("db.rom") }.flat_map { it["db.rom"].gateways.values.map(&:connection) }.uniq
  end

  def drop_connections
    databases.each do |db|
      pids = []
      db.pool.all_connections { pids << it.backend_pid }
      terminate(db, pids)
    end
  end

  def terminate(db, pids)
    killer = Sequel.connect(db.opts.merge(keep_reference: false, max_connections: 1))
    killer[:pg_stat_activity].where(pid: pids).select_map(Sequel.function(:pg_terminate_backend, :pid, 5000))
  ensure
    killer&.disconnect
  end

  it "answers the next request", type: :request do
    get "/"
    drop_connections
    get "/"

    expect(last_response.status).to eq(200)
  end

  it "runs the next job" do
    post = create(:post, :scheduled, published_at: Time.now.round - 60)
    drop_connections
    Posts::Jobs::PublishDuePosts.new.perform

    expect(post_queries.by_id(post.id).status).to eq("published")
  end
end
