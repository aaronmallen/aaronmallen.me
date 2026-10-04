# frozen_string_literal: true

RSpec.describe API::Queries::Calendar do
  let(:calendar) { API::Slice["queries.calendar"] }
  let(:first) { Date.new(2026, 10, 5) }
  let(:last) { Date.new(2026, 10, 11) }

  def at(day, hour = 12, minute = 0) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, minute)

  def day(date) = days.find { it.date == date }

  def days(from: first, to: last) = calendar.call(from:, to:).value!

  it "gives one day for every day in the range, empty days included, in order" do
    expect(days.map(&:date)).to eq((first..last).to_a)
  end

  it "leaves an empty day with no sprint, no posts and no journal" do
    expect(day(first)).to have_attributes(sprint: nil, posts: [], social_posts: [], journal: false)
  end

  it "gives a day its sprint and the count of tasks in it" do
    sprint = create(:sprint, sprint_date: first + 1)
    2.times { create(:task, :in_sprint, sprint_id: sprint.id) }
    create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: first + 2).id)

    expect(day(first + 1).sprint).to have_attributes(id: sprint.id, task_count: 2)
  end

  it "counts a sprint with no tasks as zero" do
    create(:sprint, sprint_date: first)

    expect(day(first).sprint.task_count).to eq(0)
  end

  it "lists a day's scheduled and published posts" do
    published = create(:post, :published, published_at: at(first + 2, 9))
    scheduled = create(:post, :scheduled, published_at: at(first + 2, 18))

    expect(day(first + 2).posts.map(&:id)).to eq([published.id, scheduled.id])
  end

  it "lists a day's scheduled and posted social posts" do
    posted = create(:social_post, :posted, posted_at: at(first + 3, 8))
    scheduled = create(:social_post, :scheduled, posted_at: at(first + 3, 20))

    expect(day(first + 3).social_posts.map(&:id)).to eq([posted.id, scheduled.id])
  end

  it "marks a day with a journal entry" do
    2.times { create(:journal_entry, entry_date: first + 4) }

    expect(days.map(&:journal)).to eq((first..last).map { it == first + 4 })
  end

  it "leaves out drafts of posts and social posts" do
    create(:post, :draft, published_at: at(first))
    create(:social_post, :draft, posted_at: at(first))

    expect(day(first)).to have_attributes(posts: [], social_posts: [])
  end

  it "puts a post at 23:30 site time on that day, not the next UTC day" do
    post = create(:post, :published, published_at: at(first + 5, 23, 30))

    expect([day(first + 5).posts.map(&:id), day(first + 6).posts]).to eq([[post.id], []])
  end

  it "leaves out records dated outside the range" do
    create(:sprint, sprint_date: last + 1)
    create(:post, :published, published_at: at(first - 1, 23, 59))
    create(:social_post, :posted, posted_at: at(last + 1, 0, 1))
    create(:journal_entry, entry_date: first - 1)

    expect(days).to all(have_attributes(sprint: nil, posts: [], social_posts: [], journal: false))
  end

  it "takes a range of 366 days" do
    expect(days(to: first + 365).length).to eq(366)
  end

  it "refuses a range over 366 days" do
    expect(calendar.call(from: first, to: first + 366)).to eq(Dry::Monads::Failure(Blog::DayWindow::TOO_LONG))
  end

  it "refuses a range that ends before it starts" do
    expect(calendar.call(from: first, to: first - 1)).to eq(Dry::Monads::Failure(described_class::BACKWARDS))
  end
end
