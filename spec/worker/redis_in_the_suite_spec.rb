# frozen_string_literal: true

RSpec.describe "Redis in the test suite", type: :app do
  def ping = Sidekiq.redis(&:ping)

  def rescued_ping
    ping
  rescue RedisClient::CannotConnectError
    nil
  end

  it "refuses a connection, naming the spec and the fix", :redis_outage do
    expect { ping }.to raise_error(
      Spec::RedisRefused,
      %r{\A\./spec/worker/redis_in_the_suite_spec\.rb:12 opened a Redis connection.*stub the Sidekiq call or replace},
    )
  end

  it "fails the way CI does, so the outage rescues still catch it", :redis_outage do
    expect { ping }.to raise_error(RedisClient::CannotConnectError)
  end

  it "fails a spec that rescues the refusal, naming the spec" do
    rescued_ping

    expect { Spec::RefuseRedis.check!(RSpec.current_example) }.to raise_error(
      Spec::RedisRefused, %r{\A\./spec/worker/redis_in_the_suite_spec\.rb:23 reached Redis.*redis_outage: true},
    )
  end

  it "passes a spec that rescues the refusal when it covers a Redis outage", :redis_outage do
    rescued_ping

    expect { Spec::RefuseRedis.check!(RSpec.current_example) }.not_to raise_error
  end
end
