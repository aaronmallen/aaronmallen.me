# frozen_string_literal: true

RSpec.describe "Redis in the test suite", type: :app do
  def ping = Sidekiq.redis(&:ping)

  it "refuses a connection, naming the spec and the fix" do
    expect { ping }.to raise_error(
      Spec::RedisRefused,
      %r{\A\./spec/worker/redis_in_the_suite_spec\.rb:6 opened a Redis connection.*stub the Sidekiq call or replace},
    )
  end

  it "fails the way CI does, so the outage rescues still catch it" do
    expect { ping }.to raise_error(RedisClient::CannotConnectError)
  end
end
