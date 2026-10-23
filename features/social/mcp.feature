Feature: Social tools for MCP clients
  An MCP client lists, writes, queues and deletes social posts with the same rules as the admin and the API.

  Background:
    Given Mastodon and Bluesky are connected
    And I am signed in to the admin
    And an MCP client connected with the scopes "read write publish delete"

  Scenario: The list gives sent and unsent posts in the range, newest first, both end days included
    Given the social posts:
      | text   | status    | at                        | created                   |
      | sent   | posted    | 2026-03-02T12:00:00-06:00 |                           |
      | queued | scheduled | 2026-03-20T12:00:00-06:00 |                           |
      | draft  | draft     |                           | 2026-03-10T12:00:00-06:00 |
      | first  | posted    | 2026-03-01T00:00:00-06:00 |                           |
      | last   | posted    | 2026-03-31T23:00:00-05:00 |                           |
      | april  | posted    | 2026-04-01T12:00:00-05:00 |                           |
      | feb    | draft     |                           | 2026-02-28T12:00:00-06:00 |
    When I call the MCP tool "list_social_posts" with:
      """
      {"from": "2026-03-01", "to": "2026-03-31"}
      """
    Then the social answer lists the ids "5,2,3,1,4"

  Scenario: The list gives the parts in order and each delivery's state, link, engagement and error
    Given the social posts:
      | text       | status | at                        | targets          |
      | one // two | posted | 2026-03-05T12:00:00-06:00 | mastodon,bluesky |
    And the social_post_deliveries table holds:
      | social_post_id | network  | remote_ids | remote_url                | like_count | failed | error        |
      | 1              | mastodon | {1,2}      | https://ruby.social/@ada/1 | 4          | false  | null         |
      | 1              | bluesky  | {}         | null                      | 0          | true   | rate limited |
    When I call the MCP tool "list_social_posts" with:
      """
      {"from": "2026-03-01", "to": "2026-03-31"}
      """
    Then the MCP answer holds:
      """
      {"social_posts": [{"id": 1, "status": "posted", "parts": ["one", "two"], "deliveries": [
        {"network": "mastodon", "state": "sent", "url": "https://ruby.social/@ada/1", "likes": 4},
        {"network": "bluesky", "state": "failed", "error": {"untrusted": true, "text": "rate limited"}}
      ]}]}
      """

  Scenario: The list calls a network with no delivery waiting and one with an error retrying
    Given the social posts:
      | text | status    | at                        |
      | one  | scheduled | 2026-03-05T12:00:00-06:00 |
      | two  | scheduled | 2026-03-06T12:00:00-06:00 |
    And the social_post_deliveries table holds:
      | social_post_id | network  | error        |
      | 2              | mastodon | rate limited |
    When I call the MCP tool "list_social_posts" with:
      """
      {"from": "2026-03-01", "to": "2026-03-31"}
      """
    Then the MCP answer holds:
      """
      {"social_posts": [{"id": 2, "deliveries": [{"network": "mastodon", "state": "retrying"}]},
                        {"id": 1, "deliveries": [{"network": "mastodon", "state": "waiting"}]}]}
      """

  Scenario: The list gives each part's length and limit on each network it targets
    Given the social posts:
      | text        | status | targets | created                   |
      | hello there | draft  | bluesky | 2026-03-05T12:00:00-06:00 |
    When I call the MCP tool "list_social_posts" with:
      """
      {"from": "2026-03-01", "to": "2026-03-31"}
      """
    Then the MCP answer holds:
      """
      {"social_posts": [{"lengths": [{"bluesky": {"count": 11, "limit": 300}}]}]}
      """

  Scenario: The list keeps only the queue asked for and counts every queue in the range
    Given the social posts:
      | text   | status    | at                        | created                   |
      | sent   | posted    | 2026-03-02T12:00:00-06:00 |                           |
      | sent   | posted    | 2026-03-03T12:00:00-06:00 |                           |
      | queued | scheduled | 2026-03-20T12:00:00-05:00 |                           |
      | draft  | draft     |                           | 2026-03-10T12:00:00-05:00 |
      | later  | scheduled | 2026-04-02T12:00:00-05:00 |                           |
    When I call the MCP tool "list_social_posts" with:
      """
      {"from": "2026-03-01", "to": "2026-03-31", "queue": "queued"}
      """
    Then the social answer lists the ids "3"
    When I call the MCP tool "list_social_posts" with:
      """
      {"from": "2026-03-01", "to": "2026-03-31", "queue": "drafts"}
      """
    Then the social answer lists the ids "4"
    And the MCP answer holds:
      """
      {"counts": {"queued": 1, "posted": 2, "drafts": 1}}
      """
    When I call the MCP tool "list_social_posts" with:
      """
      {"from": "2026-03-01", "to": "2026-03-31", "queue": "posted"}
      """
    Then the social answer lists the ids "2,1"

  Scenario: With no range the list gives and counts every social post
    Given the social posts:
      | text  | status    | at                        |
      | older | posted    | 2020-03-02T12:00:00-06:00 |
      | newer | scheduled | 2030-03-02T12:00:00-06:00 |
    When I call the MCP tool "list_social_posts"
    Then the social answer lists the ids "2,1"
    And the MCP answer holds:
      """
      {"from": null, "to": null, "counts": {"queued": 1, "posted": 1, "drafts": 0}}
      """

  Scenario: With only one end the list runs open at the other
    Given the social posts:
      | text  | status    | at                        |
      | old   | posted    | 2020-03-02T12:00:00-06:00 |
      | feb   | posted    | 2026-02-28T12:00:00-06:00 |
      | march | posted    | 2026-03-02T12:00:00-06:00 |
      | later | scheduled | 2030-03-02T12:00:00-06:00 |
    When I call the MCP tool "list_social_posts" with:
      """
      {"from": "2026-03-01"}
      """
    Then the social answer lists the ids "4,3"
    When I call the MCP tool "list_social_posts" with:
      """
      {"to": "2026-03-01"}
      """
    Then the social answer lists the ids "2,1"

  Scenario: With no range the list pages through one queue
    Given 101 social posts posted "a day" apart
    And the social posts:
      | text  | status |
      | draft | draft  |
    When I call the MCP tool "list_social_posts" with:
      """
      {"queue": "posted", "page": 2}
      """
    Then the social answer lists the ids "101"

  Scenario Outline: The list refuses a queue, a day or a range it cannot use
    When I call the MCP tool "list_social_posts" with:
      """
      <arguments>
      """
    Then the MCP tool refuses with "<message>"

    Examples:
      | arguments                                  | message                                      |
      | {"queue": "archived"}                      | Invalid arguments: value at `/queue` is not one of: [\"queued\", \"posted\", \"drafts\"] |
      | {"from": "March", "to": "2026-03-31"}      | give from and to as days, such as 2026-01-01 |
      | {"from": "2026-03-31", "to": "2026-03-01"} | from comes after to                          |

  Scenario: Creating saves a draft with its parts in order and answers with it
    When I call the MCP tool "create_social_post" with:
      """
      {"parts": ["hello", "there"], "targets": ["mastodon"]}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "status": "draft", "parts": ["hello", "there"], "posted_at": null}
      """
    And social post 1 is draft
    And social post 1 goes to "mastodon"
    And social post 1 has the parts "hello // there"

  Scenario: Creating gives each part's length and limit on each network
    When I call the social MCP tool "create_social_post" with:
      """
      {"parts": ["{a*400}", "hi"], "targets": ["mastodon", "bluesky"]}
      """
    Then the MCP answer holds:
      """
      {"lengths": [
        {"mastodon": {"count": 400, "limit": 500}, "bluesky": {"count": 400, "limit": 300}},
        {"mastodon": {"count": 2, "limit": 500}, "bluesky": {"count": 2, "limit": 300}}
      ]}
      """

  Scenario: Creating counts a link and a mention as each network gets them
    Given the people table holds:
      | key | name         | mastodon_handle  | bluesky_handle  | bluesky_did |
      | ada | Ada Lovelace | @ada@ruby.social | ada.bsky.social | did:plc:ada |
    When I call the social MCP tool "create_social_post" with:
      """
      {"parts": ["{site}/a", "@{ada}"], "targets": ["mastodon", "bluesky"]}
      """
    Then the MCP answer holds:
      """
      {"lengths": [
        {"mastodon": {"count": 23}, "bluesky": {"count": 36}},
        {"mastodon": {"count": 4}, "bluesky": {"count": 16}}
      ]}
      """

  Scenario Outline: Creating refuses what the admin refuses and saves nothing
    When I call the MCP tool "create_social_post" with:
      """
      {"parts": <parts>, "targets": <targets>}
      """
    Then the MCP tool refuses with "<message>"
    And there are 0 social posts

    Examples:
      | parts                    | targets      | message                                              |
      | ["  "]                   | ["mastodon"] | parts is empty                                       |
      | [" "]               | ["mastodon"] | parts is empty                                       |
      | ["Hello", " 　"] | ["mastodon"] | parts is empty                                       |
      | ["hello"]                | []           | targets is empty                                     |
      | ["hel\u0000lo"]          | ["mastodon"] | parts holds a control character                      |
      | ["hi @{nobody}"]         | ["mastodon"] | parts mentions someone who is not in the directory   |

  Scenario: Creating refuses a network with no credentials
    Given my Bluesky account is no longer connected
    When I call the MCP tool "create_social_post" with:
      """
      {"parts": ["hello"], "targets": ["bluesky"]}
      """
    Then the MCP tool refuses with "targets names a network that has no credentials"

  Scenario: Creating keeps Unicode spaces around real words and a mention of someone in the directory
    Given the people table holds:
      | key          | name         |
      | ada-lovelace | Ada Lovelace |
    When I call the MCP tool "create_social_post" with:
      """
      {"parts": [" Pick a queue ", "hi @{ada-lovelace}"], "targets": ["mastodon"]}
      """
    And I call the MCP tool "read_social_post" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"parts": [" Pick a queue ", "hi @{ada-lovelace}"]}
      """

  Scenario: Updating replaces the parts, keeps the networks and gives the new lengths
    Given the social posts:
      | text | status |
      | old  | draft  |
    When I call the MCP tool "update_social_post" with:
      """
      {"id": 1, "parts": ["new", "words"]}
      """
    Then the MCP answer holds:
      """
      {"lengths": [{"mastodon": {"count": 3, "limit": 500}}, {"mastodon": {"count": 5, "limit": 500}}]}
      """
    And social post 1 has the parts "new // words"
    And social post 1 goes to "mastodon"
    When I call the MCP tool "update_social_post" with:
      """
      {"id": 1, "targets": ["mastodon", "bluesky"]}
      """
    Then social post 1 goes to "mastodon,bluesky"
    And social post 1 has the parts "new // words"

  Scenario: Updating a post that picked accounts sends to every account on a network it adds
    Given my Mastodon account "ada" on "hachyderm.io" is connected
    And the social posts:
      | text | status | accounts |
      | old  | draft  | 3        |
    When I call the MCP tool "update_social_post" with:
      """
      {"id": 1, "targets": ["mastodon", "bluesky"]}
      """
    And I call the MCP tool "read_social_post" with:
      """
      {"id": 1}
      """
    Then the social answer's deliveries go to "mastodon @ada@hachyderm.io waiting, bluesky @ada.example waiting"

  Scenario: Updating a queued post leaves it a draft
    Given the social posts:
      | text   | status    |
      | queued | scheduled |
    When I call the MCP tool "update_social_post" with:
      """
      {"id": 1, "parts": ["new"]}
      """
    Then social post 1 is draft

  Scenario Outline: Updating refuses a post it cannot change and keeps what was there
    Given the social posts:
      | text | status   | at        |
      | old  | <status> | 1 day ago |
    When I call the MCP tool "update_social_post" with:
      """
      {"id": <id>, "parts": <parts>}
      """
    Then the MCP tool refuses with "<message>"
    And social post 1 has the parts "old"

    Examples:
      | status | id     | parts   | message                                           |
      | posted | 1      | ["new"] | social post 1 has gone out, so nothing was saved  |
      | draft  | 999999 | ["new"] | no social post has the ID 999999                  |
      | draft  | 1      | [""]    | parts is empty                                    |

  Scenario: Sending queues a post now or at a time and answers with it
    Given the social posts:
      | text | status |
      | hi   | draft  |
      | hi   | draft  |
    When I call the MCP tool "send_social_post" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "status": "scheduled"}
      """
    And social post 1 goes out within a minute
    When I call the MCP tool "send_social_post" with:
      """
      {"id": 2, "schedule_at": "2030-01-02T09:30"}
      """
    Then social post 2 goes out at "2030-01-02T09:30" in Chicago

  Scenario Outline: Sending refuses a part over a network's limit and leaves the post a draft
    Given the social posts:
      | text   | status | targets   |
      | <text> | draft  | <targets> |
    When I call the MCP tool "send_social_post" with:
      """
      {"id": 1}
      """
    Then the MCP tool refuses with "parts has a part over the limit for a network you picked: <detail>"
    And social post 1 is draft

    Examples:
      | text               | targets          | detail                                                                                               |
      | {a*501}            | mastodon         | part 1 runs 501 of 500 on mastodon                                                                   |
      | hi // {a*400}      | mastodon,bluesky | part 2 runs 400 of 300 on bluesky                                                                    |
      | {👨‍👩‍👧‍👦*121}         | mastodon,bluesky | part 1 has too many bytes for bluesky                                                                |
      | {a*501} // {b*301} | mastodon,bluesky | part 1 runs 501 of 500 on mastodon, part 1 runs 501 of 300 on bluesky, part 2 runs 301 of 300 on bluesky |

  Scenario Outline: Sending refuses a time or a post it cannot use
    Given the social posts:
      | text | status   | at        |
      | hi   | <status> | 1 day ago |
    When I call the MCP tool "send_social_post" with:
      """
      {"id": <id>, "schedule_at": "<at>"}
      """
    Then the MCP tool refuses with "<message>"

    Examples:
      | status    | id     | at               | message                                                          |
      | scheduled | 1      | tomorrow         | schedule_at needs a date and time, as 2026-10-01T09:30           |
      | scheduled | 1      | 2030-03-10T02:30 | schedule_at falls in the hour the clocks skip in America/Chicago |
      | posted    | 1      | 2030-01-02T09:30 | social post 1 has gone out, so nothing was saved                 |
      | scheduled | 999999 | 2030-01-02T09:30 | no social post has the ID 999999                                 |

  Scenario: Deleting removes a post that has not gone out and answers with its ID
    Given the social posts:
      | text | status |
      | hi   | draft  |
    When I call the MCP tool "delete_social_post" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "deleted": true}
      """
    And social post 1 is gone

  Scenario: Deleting keeps a post a network has taken and says why
    Given the social posts:
      | text  | status    |
      | taken | scheduled |
    And the social_post_deliveries table holds:
      | social_post_id | network  |
      | 1              | mastodon |
    When I call the MCP tool "delete_social_post" with:
      """
      {"id": 1}
      """
    Then the MCP tool refuses with "social post 1 has gone out, so nothing was removed"
    And social post 1 is scheduled
    When I call the MCP tool "delete_social_post" with:
      """
      {"id": 999999}
      """
    Then the MCP tool refuses with "no social post has the ID 999999"

  Scenario: The tools answer as the API does
    Given an API token
    And my Mastodon account "ada" on "hachyderm.io" is connected
    And the photos table holds:
      | key                                  | width | height | byte_size |
      | 00000000000000000000000000000001.png | 10    | 10     | 100       |
    And the social posts:
      | text        | status | targets  | at        |
      | teh cat sat | draft  | mastodon |           |
      | hi          | posted | mastodon | 1 day ago |
      | a long one  | draft  | mastodon |           |
    And the social_post_deliveries table holds:
      | social_post_id | network  | error | connection_id | remote_ids |
      | 1              | mastodon | slow  | null          | {}         |
      | 2              | mastodon | null  | 1             | {1}        |
      | 2              | mastodon | null  | 3             | {2}        |
    And the social_post_photos table holds:
      | social_post_part_id | position | photo_key                            | alt_text |
      | 1                   | 1        | 00000000000000000000000000000001.png | A cat    |
    And the suggestions table holds:
      | social_post_id |
      | 1              |
    And the suggestion_edits table holds:
      | suggestion_id | position | part | original | replacement | reason | status  |
      | 1             | 1        | 1    | teh      | the         | typo   | pending |
    Then the MCP tool "read_social_post" with id 1 answers as GET "/api/v1/social_posts/1" does
    And the MCP tool "read_social_post" with id 2 answers as GET "/api/v1/social_posts/2" does
    And the MCP tool "list_social_posts" with queue "drafts" answers as GET "/api/v1/social_posts?queue=drafts" does
    And the MCP tool "read_social_post" with id 999999 refuses as GET "/api/v1/social_posts/999999" does

  Scenario: Creating, sending and deleting answer as the API does
    Given an API token
    And the social posts:
      | text      | status |
      | {a*501}   | draft  |
      | gone soon | draft  |
    When I call the social MCP tool "create_social_post" with:
      """
      {"parts": ["hi"], "targets": ["mastodon"]}
      """
    And I POST "/social_posts" through the API with:
      """
      {"parts": ["hi"], "targets": ["mastodon"]}
      """
    Then the last two social answers match but for "id, created_at, updated_at"
    And the MCP tool "send_social_post" with id 1 refuses as POST "/api/v1/social_posts/1/send" does
    When I call the MCP tool "delete_social_post" with:
      """
      {"id": 2}
      """
    Then the MCP answer holds:
      """
      {"id": 2, "deleted": true}
      """

  Scenario: A social hit from search reads whatever its status
    Given the social posts:
      | text           | status    | at        |
      | Saw a zeppelin | draft     |           |
      | Saw a zeppelin | scheduled | in 1 day  |
      | Saw a zeppelin | posted    | 1 day ago |
    When I call the MCP tool "search" with:
      """
      {"query": "zeppelin"}
      """
    Then each social hit reads through read_social_post as "draft, scheduled, posted"

  Scenario: A LinkedIn thread counts as the joined post and is refused once it runs over
    Given my LinkedIn account "Ada Lovelace" is connected
    When I call the social MCP tool "create_social_post" with:
      """
      {"parts": ["{a*1500}", "{b*1498}"], "targets": ["linkedin"]}
      """
    Then the MCP answer holds:
      """
      {"lengths": [{"linkedin": {"count": 3000, "limit": 3000}}, {"linkedin": {"count": 3000, "limit": 3000}}]}
      """
    When I call the MCP tool "send_social_post" with:
      """
      {"id": 1}
      """
    Then social post 1 is scheduled
    When I call the social MCP tool "create_social_post" with:
      """
      {"parts": ["{a*1500}", "{b*1499}"], "targets": ["linkedin"]}
      """
    Then the MCP answer holds:
      """
      {"lengths": [{"linkedin": {"count": 3001, "limit": 3000}}, {"linkedin": {"count": 3001, "limit": 3000}}]}
      """
    When I call the MCP tool "send_social_post" with:
      """
      {"id": 2}
      """
    Then the MCP tool refuses with "parts has a part over the limit for a network you picked: part 1 runs 3001 of 3000 on linkedin, part 2 runs 3001 of 3000 on linkedin"
    And social post 2 is draft
