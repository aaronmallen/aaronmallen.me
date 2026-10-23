Feature: Social posts in the JSON API
  The API lists, reads, writes, queues and deletes social posts the way the admin and the MCP tools do.

  Background:
    Given Mastodon and Bluesky are connected
    And an API token

  Scenario: The list gives the range's posts newest first with the counts per queue
    Given the social posts:
      | text   | status    | at                        |
      | sent   | posted    | 2026-03-02T12:00:00-06:00 |
      | queued | scheduled | 2026-03-20T12:00:00-06:00 |
    When I GET "/social_posts?from=2026-03-01&to=2026-03-31" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {"social_posts": [{"id": 2}, {"id": 1}], "counts": {"queued": 1, "posted": 1, "drafts": 0}}
      """

  Scenario: The list keeps only the queue asked for
    Given the social posts:
      | text  | status | at                        | created                   |
      | sent  | posted | 2026-03-02T12:00:00-06:00 |                           |
      | draft | draft  |                           | 2026-03-10T12:00:00-06:00 |
    When I GET "/social_posts?from=2026-03-01&to=2026-03-31&queue=drafts" through the API
    Then the social answer lists the ids "2"

  Scenario: The list gives each post's lengths per part
    Given the social posts:
      | text        | status |
      | hi // there | draft  |
    When I GET "/social_posts" through the API
    Then the API answer holds:
      """
      {"social_posts": [{"lengths": [{"mastodon": {"count": 2, "limit": 500}}, {"mastodon": {"count": 5, "limit": 500}}]}]}
      """

  Scenario: The list pages through the posts
    Given 101 social posts posted "a day" apart
    When I GET "/social_posts?page=1" through the API
    Then the API answer holds:
      """
      {"partial": true, "next_page": 2}
      """
    When I GET "/social_posts?page=2" through the API
    Then the social answer lists the ids "101"

  Scenario: The list refuses a day it cannot read
    When I GET "/social_posts?from=March" through the API
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "give from and to as days, such as 2026-01-01"}
      """

  Scenario: Creating saves a draft and answers with it
    When I POST "/social_posts" through the API with:
      """
      {"parts": ["hello", "there"], "targets": ["mastodon"]}
      """
    Then the API answers 201
    And the API answer holds:
      """
      {"id": 1, "status": "draft", "parts": ["hello", "there"]}
      """
    And social post 1 is draft

  Scenario: Creating refuses empty text
    When I POST "/social_posts" through the API with:
      """
      {"parts": [" "], "targets": ["mastodon"]}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "parts is empty"}
      """

  Scenario: Updating replaces the parts or the networks and keeps the rest
    Given the social posts:
      | text | status |
      | old  | draft  |
    When I PATCH "/social_posts/1" through the API with:
      """
      {"targets": ["mastodon", "bluesky"]}
      """
    Then the API answer holds:
      """
      {"targets": ["mastodon", "bluesky"], "parts": ["old"]}
      """
    When I PATCH "/social_posts/1" through the API with:
      """
      {"parts": ["new"]}
      """
    Then social post 1 has the parts "new"
    And social post 1 goes to "mastodon,bluesky"

  Scenario: A network added to a post that picked accounts goes to every account on it
    Given my Mastodon account "ada" on "hachyderm.io" is connected
    And my Bluesky account "grace.example" is connected
    And the social posts:
      | text | status | accounts |
      | old  | draft  | 3        |
    When I PATCH "/social_posts/1" through the API with:
      """
      {"targets": ["mastodon", "bluesky"]}
      """
    And I GET "/social_posts/1" through the API
    Then the social answer's deliveries go to "mastodon @ada@hachyderm.io waiting, bluesky @ada.example waiting, bluesky @grace.example waiting"

  Scenario: Updating a post that has gone out is refused
    Given the social posts:
      | text | status | at         |
      | sent | posted | 1 day ago  |
    When I PATCH "/social_posts/1" through the API with:
      """
      {"parts": ["new"]}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "social post 1 has gone out, so nothing was saved"}
      """

  Scenario: Sending queues a post now or for a time
    Given the social posts:
      | text | status |
      | hi   | draft  |
      | hi   | draft  |
    When I POST "/social_posts/1/send" through the API with:
      """
      {}
      """
    Then the API answer holds:
      """
      {"status": "scheduled"}
      """
    And social post 1 goes out within a minute
    When I POST "/social_posts/2/send" through the API with:
      """
      {"schedule_at": "2030-01-02T09:30"}
      """
    Then social post 2 goes out at "2030-01-02T09:30" in Chicago

  Scenario: Sending names each part and network over its limit
    Given the social posts:
      | text                | status | targets          |
      | {a*501} // {b*301}  | draft  | mastodon,bluesky |
    When I POST "/social_posts/1/send" through the API with:
      """
      {}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "parts has a part over the limit for a network you picked: part 1 runs 501 of 500 on mastodon, part 1 runs 501 of 300 on bluesky, part 2 runs 301 of 300 on bluesky"}
      """

  Scenario: Sending a post that has gone out is refused
    Given the social posts:
      | text | status | at        |
      | sent | posted | 1 day ago |
    When I POST "/social_posts/1/send" through the API with:
      """
      {}
      """
    Then the API answers 422

  Scenario: Deleting removes a post that has not gone out
    Given the social posts:
      | text | status |
      | hi   | draft  |
    When I DELETE "/social_posts/1" through the API
    Then the API answer holds:
      """
      {"id": 1, "deleted": true}
      """
    And social post 1 is gone

  Scenario: Deleting keeps a post a network has taken
    Given the social posts:
      | text  | status    |
      | taken | scheduled |
    And the social_post_deliveries table holds:
      | social_post_id | network  |
      | 1              | mastodon |
    When I DELETE "/social_posts/1" through the API
    Then the API answers 422
    And the API answer holds:
      """
      {"message": "social post 1 has gone out, so nothing was removed"}
      """
    And social post 1 is scheduled

  Scenario: Reading a sent post gives its targets, parts and each network's delivery
    Given the social posts:
      | text   | status | targets          | at        |
      | posted | posted | mastodon,bluesky | 1 day ago |
    And the social_post_deliveries table holds:
      | social_post_id | network  | remote_ids | remote_url               | like_count | repost_count | reply_count |
      | 1              | mastodon | {1}        | https://ruby.social/@me/1 | 4          | 2            | 1           |
    When I GET "/social_posts/1" through the API
    Then the API answers 200
    And the API answer holds:
      """
      {
        "id": 1, "status": "posted", "post_id": null, "targets": ["mastodon", "bluesky"], "parts": ["posted"],
        "photos": [[]], "suggestion_id": null, "suggestion_edits": [], "record_links": {},
        "lengths": [{"mastodon": {"count": 6, "limit": 500}, "bluesky": {"count": 6, "limit": 300}}],
        "deliveries": [
          {"network": "mastodon", "account": null, "state": "sent", "url": "https://ruby.social/@me/1", "error": null, "likes": 4, "reposts": 2, "replies": 1},
          {"network": "bluesky", "account": null, "state": "waiting", "url": null, "error": null, "likes": 0, "reposts": 0, "replies": 0}
        ]
      }
      """
    And the social answer has the stamps "posted_at, created_at, updated_at"

  Scenario: Reading a draft or a scheduled post gives its status
    Given the social posts:
      | text | status    |
      | one  | draft     |
      | two  | scheduled |
    When I GET "/social_posts/1" through the API
    Then the API answer holds:
      """
      {"status": "draft"}
      """
    When I GET "/social_posts/2" through the API
    Then the API answer holds:
      """
      {"status": "scheduled"}
      """

  Scenario: Reading gives each part's photos in order with key and alt text
    Given the photos table holds:
      | key                                  | width | height | byte_size |
      | 00000000000000000000000000000001.png | 10    | 10     | 100       |
      | 00000000000000000000000000000002.png | 10    | 10     | 100       |
      | 00000000000000000000000000000003.png | 10    | 10     | 100       |
    And the social posts:
      | text                | status |
      | one // two // three | draft  |
    And the social_post_photos table holds:
      | social_post_part_id | position | photo_key                            | alt_text |
      | 2                   | 1        | 00000000000000000000000000000003.png | A bird   |
      | 1                   | 1        | 00000000000000000000000000000002.png | A dog    |
      | 1                   | 2        | 00000000000000000000000000000001.png | null     |
    When I GET "/social_posts/1" through the API
    Then the API answer holds:
      """
      {"photos": [
        [{"key": "00000000000000000000000000000002.png", "alt": "A dog"}, {"key": "00000000000000000000000000000001.png", "alt": null}],
        [{"key": "00000000000000000000000000000003.png", "alt": "A bird"}],
        []
      ]}
      """

  Scenario: Reading names the post a social post announces
    Given the posts table holds:
      | title | status    | published_at |
      | Hello | published | 1 day ago    |
    And the social posts:
      | text | status | at        | post |
      | hi   | posted | 1 day ago | 1    |
    When I GET "/social_posts/1" through the API
    Then the API answer holds:
      """
      {"post_id": 1}
      """

  Scenario: Reading tells a failed delivery from a retrying one and one still sending
    Given the social posts:
      | text | status | targets                   | at        |
      | hi   | posted | mastodon,bluesky          | 1 day ago |
    And the social_post_deliveries table holds:
      | social_post_id | network  | error     | failed |
      | 1              | mastodon | timed out | false  |
      | 1              | bluesky  | refused   | true   |
    When I GET "/social_posts/1" through the API
    Then the social answer's delivery states read "mastodon retrying timed out, bluesky failed refused"
    Given the social posts:
      | text | status | at        |
      | hi   | posted | 1 day ago |
    And the social_post_deliveries table holds:
      | social_post_id | network  |
      | 2              | mastodon |
    When I GET "/social_posts/2" through the API
    Then the social answer's delivery states read "mastodon sending"

  Scenario: A LinkedIn thread reads sent once its one post is out
    Given the social posts:
      | text      | status | targets  | at  |
      | one // two | posted | linkedin | now |
    And the social_post_deliveries table holds:
      | social_post_id | network  | remote_ids          |
      | 1              | linkedin | {urn:li:share:7}    |
    When I GET "/social_posts/1" through the API
    Then the social answer's delivery states read "linkedin sent"

  Scenario: Reading names each account a post went to on one network, or will go to
    Given my Mastodon account "ada" on "hachyderm.io" is connected
    And the social posts:
      | text | status    | targets          | at        |
      | hi   | posted    | mastodon         | 1 day ago |
      | hi   | scheduled | mastodon,bluesky | in 1 day  |
    And the social_post_deliveries table holds:
      | social_post_id | network  | connection_id | remote_ids | failed | error   |
      | 1              | mastodon | 1             | {1}        | false  | null    |
      | 1              | mastodon | 3             | {}         | true   | refused |
    When I GET "/social_posts/1" through the API
    Then the social answer's deliveries go to "mastodon @aaronmallen@ruby.social sent, mastodon @ada@hachyderm.io failed"
    When I GET "/social_posts/2" through the API
    Then the social answer's deliveries go to "mastodon @aaronmallen@ruby.social waiting, mastodon @ada@hachyderm.io waiting, bluesky @ada.example waiting"

  Scenario: Reading gives the open suggested edits and the suggestion that holds them
    Given the social posts:
      | text            | status |
      | a cat and a dog | draft  |
    And the suggestions table holds:
      | social_post_id |
      | 1              |
    And the suggestion_edits table holds:
      | suggestion_id | position | part | original | replacement | reason | status   |
      | 1             | 1        | 1    | cat      | black cat   | typo   | pending  |
      | 1             | 2        | 1    | dog      | dogs        | typo   | rejected |
    When I GET "/social_posts/1" through the API
    Then the API answer holds:
      """
      {"suggestion_id": 1, "suggestion_edits": [{"id": 1, "part": 1, "original": "cat", "replacement": "black cat", "reason": "typo", "status": "pending"}]}
      """
    And the social answer has 1 suggested edit

  Scenario: Reading gives a null suggestion once every edit is settled
    Given the social posts:
      | text  | status |
      | a cat | draft  |
    And the suggestions table holds:
      | social_post_id |
      | 1              |
    And the suggestion_edits table holds:
      | suggestion_id | position | part | original | replacement | reason | status   |
      | 1             | 1        | 1    | cat      | dog         | typo   | rejected |
    When I GET "/social_posts/1" through the API
    Then the API answer holds:
      """
      {"suggestion_id": null}
      """

  Scenario: Reading gives the records linked to the social post, grouped by kind
    Given the social posts:
      | text | status |
      | hi   | draft  |
    And the tasks table holds:
      | title              | position | number | list |
      | Announce the move  | 1        | 1      | next |
    And the record_links table holds:
      | left_kind | left_id | right_kind  | right_id |
      | task      | 1       | social_post | 1        |
    When I GET "/social_posts/1" through the API
    Then the API answer holds:
      """
      {"record_links": {"task": [{"kind": "task", "id": 1, "title": "Announce the move"}]}}
      """
