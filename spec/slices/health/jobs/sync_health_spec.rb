# frozen_string_literal: true

RSpec.describe Health::Jobs::SyncHealth do
  let(:sync) { Blog::Types::SyncName["health"] }
  let(:today) { Blog::TimeZone.today }
  let(:yesterday) { today - 1 }

  def asked_for_summary(field)
    filter = %(#{field}.date >= "#{today - 2}" AND #{field}.date < "#{today + 1}")

    a_request(:get, %r{dataTypes/#{field.tr('_', '-')}/dataPoints\?}).with(query: hash_including("filter" => filter))
  end

  def asked_for_workouts_from(first)
    field = "exercise.interval.civil_start_time"
    filter = %(#{field} >= "#{first}" AND #{field} < "#{today + 1}")

    a_request(:get, %r{dataTypes/exercise/dataPoints\?}).with(query: hash_including("filter" => filter))
  end

  def days = Health::Slice["relations.health_days"].to_a.map(&:to_h)

  def failure = Record::Slice["repos.sync_state_queries"].failure(sync)

  def full_day
    zones = { sumInFatBurnHeartZone: "10", sumInCardioHeartZone: "12" }
    hrv = { date: google_date(today), averageHeartRateVariabilityMilliseconds: 48.5 }
    resting = { date: google_date(today), beatsPerMinute: "54" }

    {
      sleep: { dataPoints: [night(local(yesterday, 23), local(today, 7), 420)] },
      daily_resting_heart_rate: { dataPoints: [{ dailyRestingHeartRate: resting }] },
      daily_heart_rate_variability: { dataPoints: [{ dailyHeartRateVariability: hrv }] },
      steps: steps(today, 8421),
      active_zone_minutes: { rollupDataPoints: [{ civilStartTime: google_civil(today), activeZoneMinutes: zones }] },
      exercise: { dataPoints: [run_workout("run-1", local(today, 6))] },
    }
  end

  def local(date, hour) = Blog::TimeZone.local_time(date.year, date.month, date.day, hour)

  def night(bed, woke, asleep)
    interval = { startTime: google_time(bed), endTime: google_time(woke) }

    { sleep: { interval:, summary: { minutesAsleep: asleep.to_s } } }
  end

  def run = described_class.new.perform

  def run_workout(name, start)
    {
      name: "users/me/dataTypes/exercise/dataPoints/#{name}",
      dataSource: { device: { displayName: "Pixel Watch 3" } },
      exercise: {
        exerciseType: "RUNNING", activeDuration: "1800s",
        interval: { startTime: google_time(start), endTime: google_time(start + 1900) },
        metricsSummary: {
          distanceMillimeters: 5_000_000, averageHeartRateBeatsPerMinute: "152", activeZoneMinutes: "24",
          caloriesKcal: 410.4,
        },
      },
    }
  end

  def steps(date, count)
    { rollupDataPoints: [{ civilStartTime: google_civil(date), steps: { countSum: count.to_s } }] }
  end

  def stored = [days, workouts].map { it.map { |row| row.except(:updated_at) } }

  def stored_day
    {
      day: today, minutes_asleep: 420, bed_at: local(yesterday, 23), woke_at: local(today, 7),
      resting_heart_rate: 54, hrv: 48.5, steps: 8421, active_zone_minutes: 22,
    }
  end

  def stored_workout
    {
      google_id: "users/me/dataTypes/exercise/dataPoints/run-1", kind: "RUNNING", started_at: local(today, 6),
      minutes: 30, distance_meters: 5000.0, average_heart_rate: 152, zone_minutes: 24, kcal: 410,
      device: "Pixel Watch 3",
    }
  end

  def workouts = Health::Slice["relations.workouts"].to_a.map(&:to_h)

  describe "with Google Health connected" do
    before { connect_google }

    describe "a day Google holds" do
      before do
        stub_google_health(**full_day)
        run
      end

      it "stores the day's sleep, heart rate, HRV, steps and zone minutes" do
        expect(days).to contain_exactly(include(stored_day))
      end

      it "stores each workout with its type, start, minutes, distance, heart rate, zone minutes, kcal and device" do
        expect(workouts).to contain_exactly(include(stored_workout))
      end

      it "leaves the same rows when it runs twice over the same days" do
        expect { run }.not_to(change { stored })
      end

      it "sends the admin no notice when it runs twice over the same days", :commits do
        expect(admin_notice { run }).to be_nil
      end

      it "updates a day Google has changed since the last run" do
        stub_google_health(steps: steps(today, 9000))
        run

        expect(days).to contain_exactly(include(day: today, steps: 9000, minutes_asleep: nil))
      end
    end

    it "puts Monday night's sleep on Tuesday, the day I woke" do
      stub_google_health(sleep: { dataPoints: [night(local(yesterday, 22), local(today, 6), 450)] })
      run

      expect(days.map { it[:day] }).to eq([today])
    end

    it "keeps the longest sleep for bed and wake, and adds every nap to the minutes asleep" do
      naps = [night(local(today, 14), local(today, 15), 40), night(local(yesterday, 23), local(today, 7), 400)]
      stub_google_health(sleep: { dataPoints: naps })
      run

      expect(days.first).to include(minutes_asleep: 440, bed_at: local(yesterday, 23), woke_at: local(today, 7))
    end

    it "reads every page of workouts Google sends" do
      stub_google_health(exercise: { dataPoints: [run_workout("run-1", local(today, 6))], nextPageToken: "page-2" })
      stub_request(:get, %r{dataTypes/exercise/dataPoints\?.*page_token=page-2})
        .to_return(google_health_json({ dataPoints: [run_workout("run-2", local(yesterday, 6))] }))
      run

      expect(workouts.map { it[:google_id] }).to contain_exactly(end_with("run-1"), end_with("run-2"))
    end

    it "asks Google for the last three days" do
      stub_google_health
      run

      expect(asked_for_workouts_from(today - 2)).to have_been_made
    end

    it "filters the daily summaries on the field names Google takes", :aggregate_failures do
      stub_google_health
      run

      expect(asked_for_summary("daily_resting_heart_rate")).to have_been_made
      expect(asked_for_summary("daily_heart_rate_variability")).to have_been_made
    end

    it "stores no row for a day Google holds nothing for" do
      stub_google_health(steps: { rollupDataPoints: [{ civilStartTime: google_civil(yesterday) }] })
      run

      expect(days).to be_empty
    end

    it "records a failed run where read_sync_state finds it" do
      stub_google_health
      stub_request(:get, %r{dataTypes/sleep/dataPoints\?}).to_return(status: 503)
      run

      expect(failure).to include(reason: "google_health_failed", message: "Google answered 503", count: 1)
    end

    describe "after runs that failed" do
      before do
        Record::Slice["repos.sync_state_mutations"]
          .record_failure(sync, "google_health_failed", at: Blog::TimeZone.day_start(today - 10))
        stub_google_health
        run
      end

      it("clears the failure") { expect(failure).to be_nil }

      it "catches up from the day it began failing" do
        expect(asked_for_workouts_from(today - 12)).to have_been_made
      end
    end
  end

  describe "an account that also granted mail and calendar" do
    let(:scopes) { ["https://mail.google.com/", "https://www.googleapis.com/auth/calendar", *health_scopes] }
    let(:health_scopes) { Spec::GoogleAccounts::HEALTH_SCOPES }

    def narrowed = a_request(:post, Spec::GoogleAccounts::TOKEN_URL)

    def stored_token = Services::Slice["repos.connection_queries"].for(:google).first.credentials[:access_token]

    before do
      connect_google(scopes:)
      stub_google_health
    end

    it "reads Health with one token narrowed to the Health scopes", :aggregate_failures do
      run

      expect(narrowed.with(body: hash_including("scope" => health_scopes.join(" ")))).to have_been_made.once
      expect(a_request(:any, /health\.googleapis\.com/).with(headers: { "Authorization" => "Bearer ya29.token" }))
        .not_to have_been_made
    end

    it "keeps the stored token, which mail and calendar still need" do
      run

      expect(stored_token).to eq("ya29.token")
    end

    it "narrows again once when Google turns the narrowed token away", :aggregate_failures do
      stub_request(:get, %r{dataTypes/sleep/dataPoints\?})
        .to_return({ status: 401 }, google_health_json({ dataPoints: [] }))
      run

      expect(narrowed).to have_been_made.twice
      expect(failure).to be_nil
    end
  end

  it "asks Google nothing and records nothing for an account that needs a reconnect", :aggregate_failures do
    connect_google(revoked_at: Time.now)
    run

    expect(a_request(:any, /health\.googleapis\.com/)).not_to have_been_made
    expect(failure).to be_nil
  end

  it "reads from the account that granted Health and leaves the others alone" do
    connect_google(account_id: "work@example.com", scopes: %w[openid], token: "ya29.work")
    connect_google
    stub_google_health.then { run }

    expect(a_request(:any, /health\.googleapis\.com/).with(headers: { "Authorization" => "Bearer ya29.work" }))
      .not_to have_been_made
  end

  it "asks Google nothing while no account granted Health" do
    connect_google(scopes: %w[openid])
    run

    expect(a_request(:any, /health\.googleapis\.com/)).not_to have_been_made
  end

  it "asks Google nothing and records nothing while Google Health is not connected", :aggregate_failures do
    run

    expect(a_request(:any, /health\.googleapis\.com/)).not_to have_been_made
    expect(failure).to be_nil
  end

  describe "a run that crashes" do
    before { replace_component("operations.sync_health", ->(*) { raise KeyError, "key not found: :id" }) }

    def run_crashing
      run
    rescue KeyError
      nil
    end

    it "records the crash where the admin reads it" do
      run_crashing

      expect(failure).to include(reason: "crashed", message: "key not found: :id")
    end

    it "still raises, so the error reaches error tracking" do
      expect { run }.to raise_error(KeyError, /key not found/)
    end

    describe "ten days ago" do
      before do
        connect_google
        allow(Time).to receive(:now).and_return(Blog::TimeZone.day_start(today - 10))
        run_crashing
        allow(Time).to receive(:now).and_call_original
        restore_components
        set_up_google_client
        stub_google_health
        run
      end

      it "rereads from the day it crashed on the next run" do
        expect(asked_for_workouts_from(today - 12)).to have_been_made
      end
    end
  end
end
