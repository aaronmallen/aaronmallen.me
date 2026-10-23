Feature: The list of posts
  The list shows every post with its status, numbers and tags, filters by status and pages through long lists.

  Background:
    Given I am signed in to the admin

  Scenario: The list shows every post, counts each status and links to the editors
    Given I wrote a draft post "Draft"
    And I wrote a scheduled post "Scheduled"
    And I wrote a published post "Published"
    When I visit "/admin/posts"
    Then the post list shows "Draft, Scheduled, Published" in any order
    And the editor sub-line reads "1 draft in progress. 1 published, 1 scheduled."
    And the posts filter is on "all"
    And the post editor offers "New post"
    And the post row "Draft" shows "draft"
    And the post row "Scheduled" shows "scheduled"
    And the post row "Published" shows "published"
    And the post list links "Draft" to its editor
    And the post list links "Published" to its analytics
    And the admin nav marks "posts" as current
    And the page has no axe breaches in light or dark

  Scenario Outline: A filter shows only the posts in that status
    Given I wrote a draft post "Draft"
    And I wrote a scheduled post "Scheduled"
    And I wrote a published post "Published"
    And I wrote a draft post "Another"
    When I visit "/admin/posts?status=<status>"
    Then the post list shows "<shown>" in any order
    And the posts filter is on "<checked>"
    And the editor sub-line reads "2 drafts in progress. 1 published, 1 scheduled."

    Examples:
      | status    | shown                                 | checked   |
      | published | Published                             | published |
      | draft     | Draft, Another                        | draft     |
      | scheduled | Scheduled                             | scheduled |
      | all       | Draft, Scheduled, Published, Another  | all       |
      | archived  | Draft, Scheduled, Published, Another  | all       |

  Scenario: The filters are labelled and send no token
    When I visit "/admin/posts"
    Then the posts filters read "all, published, drafts, scheduled, broken"
    And the posts filter sends no token
    And the post admin shows "No posts"

  Scenario: Choosing a filter redraws the list without loading the page
    Given I wrote a draft post "A draft"
    And I wrote a published post "Live"
    When I visit "/admin/posts"
    And I filter the posts to "drafts"
    Then I am on "/admin/posts?status=draft"
    And the post list shows "A draft"
    And the posts list redrew without a page load

  Scenario: A long list pages, keeping the filter and counting every post
    Given I wrote 102 published posts
    And I wrote a draft post "Draft"
    And the post analytics rolled up "today" for "/writing/published-1":
      | views | visitors | bounces |
      | 4     | 3        | 1       |
    When I visit "/admin/posts?status=published"
    Then the post list has 100 rows starting with "published 102"
    And the post list pages to "/admin/posts?status=published&page=2" as "Older"
    And the editor sub-line reads "1 draft in progress. 102 published, 0 scheduled."
    When I visit "/admin/posts?status=published&page=2"
    Then the post list shows "published 2, published 1"
    And the post row "published 1" shows "· 4 views · 3 visitors · 0 unique readers · 0 read-throughs"
    And the post list pages to "/admin/posts?status=published" as "Newer"
    And the posts filter is on "published"
    When I visit "/admin/posts?status=draft"
    Then the post list has no pager

  Scenario Outline: A page that is no page is not found
    When I visit "<path>"
    Then the server answers 404

    Examples:
      | path                                |
      | /admin/posts?status=published&page=3 |
      | /admin/posts?page=two               |

  Scenario: Each row shows the path, date, words and reading numbers
    Given I wrote a published post "Hello" with:
      | body         | one two three |
      | published_at | 27 days ago   |
    And I wrote a draft post "Unseen" with:
      | body       | one                  |
      | updated_at | 2026-09-01T12:00:00Z |
    When I visit "/admin/posts"
    Then the post row "Hello" reads "/writing/hello · {date} · 3 words · 0 views · 0 visitors · 0 unique readers · 0 read-throughs" with the date 27 days ago
    And the post row "Unseen" reads "/writing/unseen · Sep 1, 2026 · 1 word · 0 views · 0 visitors · 0 unique readers · 0 read-throughs"

  Scenario: A row adds up the views rolled up in the last 90 days and today's live views
    Given I wrote a published post "Hello" with:
      | body         | one two three |
      | published_at | 27 days ago   |
    And the post analytics rolled up "today" for "/writing/hello":
      | views | visitors | bounces | read_throughs |
      | 8     | 5        | 2       | 4             |
    And the post analytics rolled up "89 days ago" for "/writing/hello":
      | views | visitors | bounces |
      | 3     | 2        | 0       |
    And the post analytics rolled up "400 days ago" for "/writing/hello":
      | views | visitors | bounces | read_throughs |
      | 4     | 3        | 1       | 2             |
    And the post analytics rolled up "today" for "/writing/other":
      | views | visitors | bounces |
      | 9     | 6        | 2       |
    When I visit "/admin/posts"
    Then the post row "Hello" reads "/writing/hello · {date} · 3 words · 11 views · 7 visitors · 0 unique readers · 4 read-throughs" with the date 27 days ago

  Scenario: Today's views not rolled up yet join the rolled up days, counted once
    Given I wrote a published post "Hello" with:
      | published_at | 1 day ago |
    And the post analytics rolled up "1 day ago" for "/writing/hello":
      | views | visitors | bounces | read_throughs |
      | 4     | 3        | 1       | 1             |
    And the post analytics table analytics_events holds:
      | path           | visitor_hash | address_hash | scroll_depth | read_seconds |
      | /writing/hello | one          | one          | 75           | 30           |
      | /writing/hello | one          | one          | 75           | 30           |
      | /writing/hello | two          | two          | 75           | 30           |
    And the post analytics table analytics_events holds:
      | path           | visitor_hash | address_hash | scroll_depth | read_seconds | occurred_at |
      | /writing/hello | three        | three        | 75           | 30           | 1 day ago   |
    When I visit "/admin/posts"
    Then the post row "Hello" shows "7 views · 5 visitors"
    And the post row "Hello" shows "3 read-throughs"
    When I open the analytics for "Hello" over 7 days
    Then the stat "Page views" reads "7"
    When I visit "/admin/activity"
    Then the post admin shows "/writing/hello · published · 7 views"
    And the page has no axe breaches in light or dark

  Scenario: One view and one visitor read in the singular
    Given I wrote a published post "Hello"
    And the post analytics rolled up "today" for "/writing/hello":
      | views | visitors | bounces |
      | 1     | 1        | 1       |
    When I visit "/admin/posts"
    Then the post row "Hello" shows " · 1 view · 1 visitor · "

  Scenario: Unique readers count in a post's first 12 months, then as a final count
    Given I wrote a published post "Hello" with:
      | published_at | 27 days ago |
    And I wrote a published post "Old" with:
      | published_at | 400 days ago |
    And I wrote a published post "Older" with:
      | published_at | 401 days ago |
    And the post analytics table post_reader_hashes holds:
      | path           | reader_hash |
      | /writing/hello | ada         |
      | /writing/hello | bob         |
    And the post analytics table post_reader_counts holds:
      | path         | readers |
      | /writing/old | 1       |
    When I visit "/admin/posts"
    Then the post row "Hello" shows "2 unique readers"
    And the post row "Old" shows "1 unique reader, final"
    And the post row "Older" shows "no unique reader count"

  Scenario: A row dates a post by its Chicago day
    Given I wrote a published post "Hello" with:
      | published_at | 2026-09-02T03:00:00Z |
    When I visit "/admin/posts"
    Then the post row "Hello" shows "Sep 1, 2026"

  Scenario: A row shows the post's tags in their colours as links to their summaries
    Given the tags table holds:
      | name   | color    | scope  |
      | ruby   | mk-green | public |
      | hanami | mk-sand  | public |
    And I wrote a draft post "Hello"
    And the post "Hello" is tagged "ruby, hanami"
    When I visit "/admin/posts"
    Then the post row "Hello" links the tags "#hanami, #ruby" to "/admin/tags/hanami, /admin/tags/ruby"
    And the post row "Hello" colours the tags "sand, green" as text, not pills

  Scenario: A row counts every webmention the post received
    Given I wrote a draft post "Hello"
    And I wrote a draft post "Quiet"
    And the post "Hello" has received webmentions:
      | status   |
      | pending  |
      | spam     |
      | ignored  |
    When I visit "/admin/posts"
    Then the post row "Hello" shows "3 webmentions"
    And the post row "Hello" marks its webmention count in pink with an at sign readers skip
    And the post row "Quiet" does not show "webmention"

  Scenario: A row counts the open suggestions on a draft but not on a published post
    Given I wrote a draft post "Draft" with:
      | body | teh teh |
    And I wrote a published post "Live" with:
      | body | teh |
    And the post "Draft" has 2 open suggestions
    And the post "Live" has 1 open suggestion
    When I visit "/admin/posts"
    Then the post row "Draft" shows "2 suggestions"
    And the post row "Live" does not show "suggestion"
