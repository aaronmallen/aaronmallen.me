Feature: Blog post MCP tools
  An agent writes, changes, publishes, deletes and lists blog posts through MCP, with the checks the admin makes.

  Background:
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write publish delete"

  Scenario: create_post writes a draft and answers it
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello", "body": "one two"}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "status": "draft", "title": "Hello", "slug": "hello", "published_at": null, "tags": [], "outcome": "drafted"}
      """
    And the MCP answer holds "updated_at"
    And the posts table has a row with:
      | title | body    | status |
      | Hello | one two | draft  |

  Scenario: create_post makes the slug from the title
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello, World"}
      """
    Then the posts table has a row with:
      | slug        |
      | hello-world |

  Scenario: create_post takes the summary, tags, social card and announcement
    When I call the MCP tool "create_post" with:
      """
      {
        "title": "Hello", "summary": "In short", "tags": ["Ruby", "hanami"], "og_title": "On the card",
        "syndication_body": "In my own words", "syndication_enabled": true, "syndication_targets": ["mastodon"]
      }
      """
    Then the posts table has a row with:
      | summary  | og_title    | syndication_body | syndication_enabled | syndication_targets |
      | In short | On the card | In my own words  | true                | {mastodon}          |
    And blog post 1 carries the tags "hanami ruby"

  Scenario: create_post leaves the announcement off unless asked and keeps a timed post a draft
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello", "publish_at": "2030-01-20T09:00"}
      """
    Then the posts table has a row with:
      | status | syndication_enabled |
      | draft  | false               |

  Scenario: create_post refuses a slug another post holds
    Given the posts table holds:
      | title | slug  |
      | Other | hello |
    When I call the MCP tool "create_post" with:
      """
      {"title": "Hello"}
      """
    Then the MCP tool refuses with "slug belongs to another post"

  Scenario Outline: create_post refuses fields it cannot take and saves nothing
    When I call the MCP tool "create_post" with:
      """
      <call>
      """
    Then the MCP tool refuses with "<message>"
    And the posts table holds 0 rows

    Examples:
      | call                                                                   | message                                                                     |
      | {"title": "  "}                                                        | title is empty                                                              |
      | {"title": " 　", "slug": "hello"}                             | title is empty                                                              |
      | {"title": "Hello", "slug": "tags"}                                     | slug belongs to a page on the site                                          |
      | {"title": "!!!"}                                                       | slug needs a letter or number, from itself or from the title                |
      | {"title": "Hello", "publish_at": "next friday"}                        | publish_at needs a time as YYYY-MM-DDTHH:MM, in America/Chicago time        |
      | {"title": "Hello", "publish_at": "2030-03-10T02:30"}                   | publish_at falls in the hour the clocks skip in America/Chicago             |
      | {"title": "Hello", "tags": ["two words"]}                              | tags are each lowercase words joined by hyphens                             |
      | {"title": "Hello", "body": "a\u0000b"}                                 | body holds a control character                                              |
      | {"title": "Hello", "og_image_url": "card.png", "publish_at": "soon"}   | og_image_url needs a URL starting with http:// or https://; publish_at needs a time as YYYY-MM-DDTHH:MM, in America/Chicago time |

  Scenario: create_post refuses a call with no title
    When I call the MCP tool "create_post" with:
      """
      {"body": "one two"}
      """
    Then the MCP tool call is refused
    And the posts table holds 0 rows

  Scenario: update_post changes the fields it is given and keeps the rest
    Given the posts table holds:
      | title | slug  | body | summary  | og_title    | syndication_enabled | syndication_body | syndication_targets | webmentions_enabled |
      | Hello | hello | one  | In short | On the card | true                | In my own words  | {mastodon}          | true                |
    When I call the MCP tool "update_post" with:
      """
      {"id": 1, "tags": ["ruby"]}
      """
    And I call the MCP tool "update_post" with:
      """
      {"id": 1, "body": "two"}
      """
    Then the MCP answer holds:
      """
      {"status": "draft", "outcome": "drafted"}
      """
    And the posts table has a row with:
      | title | slug  | body | summary  | og_title    | syndication_enabled | syndication_body | syndication_targets | webmentions_enabled | status | published_at |
      | Hello | hello | two  | In short | On the card | true                | In my own words  | {mastodon}          | true                | draft  | null         |
    And blog post 1 carries the tags "ruby"

  Scenario: update_post changes the title, slug and webmentions, and clears a field an empty string names
    Given the posts table holds:
      | title | slug  | summary  | webmentions_enabled |
      | Hello | hello | In short | true                |
    When I call the MCP tool "update_post" with:
      """
      {"id": 1, "title": "Goodbye", "slug": "goodbye", "webmentions_enabled": false, "summary": ""}
      """
    Then the posts table has a row with:
      | title   | slug    | webmentions_enabled | summary |
      | Goodbye | goodbye | false               |         |

  Scenario: update_post keeps a scheduled post at the minute it was set for, even in the hour the clock repeats
    Given the posts table holds:
      | title | status    | published_at             |
      | One   | scheduled | 2030-01-15T15:00:00Z     |
      | Two   | scheduled | 2030-11-03T07:30:00Z     |
    When I call the MCP tool "update_post" with:
      """
      {"id": 1, "body": "two"}
      """
    And I call the MCP tool "update_post" with:
      """
      {"id": 2, "title": "Goodbye"}
      """
    Then the posts table has a row with:
      | id | status    | body | published_at             |
      | 1  | scheduled | two  | 2030-01-15T15:00:00.000Z |
    And the posts table has a row with:
      | id | title   | published_at             |
      | 2  | Goodbye | 2030-11-03T07:30:00.000Z |

  Scenario: update_post moves a scheduled or overdue post to a new publish time
    Given the posts table holds:
      | title | status    | published_at         |
      | One   | scheduled | 2030-01-15T15:00:00Z |
      | Two   | scheduled | 1 minute ago         |
    When I call the MCP tool "update_post" with:
      """
      {"id": 1, "publish_at": "2030-02-01T09:00"}
      """
    And I call the MCP tool "update_post" with:
      """
      {"id": 2, "publish_at": "2030-02-02T09:00"}
      """
    Then the posts table has a row with:
      | id | status    | published_at             |
      | 1  | scheduled | 2030-02-01T15:00:00.000Z |
    And the posts table has a row with:
      | id | status    | published_at             |
      | 2  | scheduled | 2030-02-02T15:00:00.000Z |

  Scenario Outline: update_post refuses a publish time a scheduled post cannot take and keeps it as it was
    Given the posts table holds:
      | title | status    | published_at   | body |
      | One   | scheduled | <published_at> | one  |
    When I call the MCP tool "update_post" with:
      """
      <call>
      """
    Then the MCP tool call is refused
    And the MCP tool refuses with "publish_at needs a time still to come on a scheduled post, which update_post never publishes; publish_post is the tool that publishes a post"
    And the posts table has a row with:
      | status    | body |
      | scheduled | one  |
    And the posts table has no row with:
      | published_at |
      | null         |

    Examples:
      | published_at         | call                                        |
      | 2030-01-15T15:00:00Z | {"id": 1, "publish_at": "", "body": "two"} |
      | 2030-01-15T15:00:00Z | {"id": 1, "publish_at": "2020-01-01T09:00"} |
      | 1 minute ago         | {"id": 1, "body": "two"}                    |

  Scenario: update_post still clears the publish time of a draft
    Given the posts table holds:
      | title | published_at         |
      | One   | 2030-01-15T15:00:00Z |
    When I call the MCP tool "update_post" with:
      """
      {"id": 1, "publish_at": ""}
      """
    Then the posts table has a row with:
      | id | published_at |
      | 1  | null         |

  Scenario: update_post edits a published post with an edit note and keeps it published
    Given the posts table holds:
      | title | status    | published_at |
      | One   | published | 1 day ago    |
    When I call the MCP tool "update_post" with:
      """
      {"id": 1, "body": "fixed", "edit_note": "fixed the numbers"}
      """
    Then the posts table has a row with:
      | body  | status    |
      | fixed | published |
    And the post_edits table has a row with:
      | post_id | note              |
      | 1       | fixed the numbers |

  Scenario Outline: update_post refuses a published post's change it cannot take
    Given the posts table holds:
      | title | slug  | body | status    | published_at |
      | Hello | hello | one  | published | 1 day ago    |
    When I call the MCP tool "update_post" with:
      """
      <call>
      """
    Then the MCP tool refuses with "<message>"
    And the posts table has a row with:
      | slug  | body |
      | hello | one  |

    Examples:
      | call                                                          | message                                                                              |
      | {"id": 1, "body": "two"}                                      | edit_note is needed when the body of a published post changes: say what changed and why |
      | {"id": 1, "body": "two", "edit_note": " 　"}         | edit_note is needed when the body of a published post changes: say what changed and why |
      | {"id": 1, "body": "two", "edit_note": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}                 | edit_note runs over 500 characters                                                    |
      | {"id": 1, "slug": "goodbye"}                                  | slug cannot change once the post is published                                         |

  Scenario: update_post changes a published post's tags with no note and keeps its time
    Given the posts table holds:
      | title | status    | published_at         |
      | One   | published | 2026-01-01T12:00:00Z |
    When I call the MCP tool "update_post" with:
      """
      {"id": 1, "tags": ["ruby"], "publish_at": "2030-01-20T09:00"}
      """
    Then blog post 1 carries the tags "ruby"
    And the posts table has a row with:
      | published_at             |
      | 2026-01-01T12:00:00.000Z |

  Scenario: update_post refuses a mention of nobody in the directory and leaves the post as it stands
    Given the posts table holds:
      | title | body |
      | Hello | one  |
    When I call the MCP tool "update_post" with:
      """
      {"id": 1, "syndication_body": "hi @{grace}"}
      """
    Then the MCP tool refuses with "syndication_body mentions someone who is not in the directory"
    When I call the MCP tool "update_post" with:
      """
      {"id": 1, "body": "two", "og_image_url": "card.png"}
      """
    Then the MCP tool call is refused
    And the posts table has a row with:
      | body |
      | one  |

  Scenario Outline: A post tool calls an unknown ID an error
    When I call the MCP tool "<tool>" with:
      """
      <call>
      """
    Then the MCP tool refuses with "no blog post has the ID 999999"

    Examples:
      | tool                 | call                              |
      | update_post          | {"id": 999999, "body": "two"}     |
      | delete_post          | {"id": 999999}                    |
      | compose_announcement | {"id": 999999}                    |

  Scenario: publish_post schedules a draft for the hour the clock repeats at the time it holds
    Given the posts table holds:
      | title | published_at         |
      | Hello | 2030-11-03T07:30:00Z |
    When I call the MCP tool "publish_post" with:
      """
      {"id": 1}
      """
    Then the posts table has a row with:
      | status    | published_at             |
      | scheduled | 2030-11-03T07:30:00.000Z |

  Scenario: publish_post queues the announcement once the post goes out
    Given a Mastodon account on "203.0.113.60" takes announcements
    And the posts table holds:
      | title | syndication_enabled | syndication_body | syndication_targets |
      | Hello | true                | Out now          | {mastodon}          |
    When I call the MCP tool "publish_post" with:
      """
      {"id": 1}
      """
    Then the social_posts table has a row with:
      | post_id | status    | targets    |
      | 1       | scheduled | {mastodon} |

  Scenario: update_post sends no announcement when it refuses a publish time
    Given a Mastodon account on "203.0.113.60" takes announcements
    And the posts table holds:
      | title | slug | status    | published_at         | syndication_enabled | syndication_body | syndication_targets |
      | One   | one  | scheduled | 2030-01-15T15:00:00Z | true                | Out now          | {mastodon}          |
      | Two   | two  | scheduled | 1 minute ago         | true                | Out now          | {mastodon}          |
      | Three | three| draft     | null                 | true                | Out now          | {mastodon}          |
    When I call the MCP tool "update_post" with:
      """
      {"id": 1, "publish_at": "2020-01-01T09:00"}
      """
    And I call the MCP tool "update_post" with:
      """
      {"id": 2, "body": "two"}
      """
    And I call the MCP tool "publish_post" with:
      """
      {"id": 3}
      """
    Then the social_posts table has a row with:
      | post_id |
      | 3       |
    And the social_posts table holds 1 rows

  Scenario Outline: publish_post refuses an announcement it cannot send
    Given the posts table holds:
      | title | slug  | syndication_enabled | syndication_body | syndication_targets |
      | Hello | hello | true                | <body>           | <targets>           |
    When I call the MCP tool "publish_post" with:
      """
      {"id": 1}
      """
    Then the MCP tool refuses with "<message>"
    And the posts table has a row with:
      | status |
      | draft  |

    Examples:
      | body        | targets    | message                                                       |
      | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | {bluesky}  | syndication_body runs over a network's limit                  |
      | hi @{grace} | {mastodon} | syndication_body mentions someone who is not in the directory |

  Scenario: delete_post deletes the post and answers its ID
    Given the posts table holds:
      | title | status    | published_at |
      | One   | published | 1 day ago    |
      | Two   | draft     | null         |
    When I call the MCP tool "delete_post" with:
      """
      {"id": 1}
      """
    And I call the MCP tool "delete_post" with:
      """
      {"id": 2}
      """
    Then the MCP answer holds:
      """
      {"id": 2, "deleted": true}
      """
    And the posts table holds 0 rows

  Scenario: compose_announcement gives the text the post carries
    Given the posts table holds:
      | title | syndication_body |
      | Hello | In my own words  |
    When I call the MCP tool "compose_announcement" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "announcement": "In my own words"}
      """

  Scenario: compose_announcement gives the title then the link when the post carries no text, and changes nothing
    Given the posts table holds:
      | title | slug  | syndication_body |
      | Hello | hello |                  |
    When I call the MCP tool "compose_announcement" with:
      """
      {"id": 1}
      """
    Then the announcement reads the title, a blank line and the link to "hello"
    And the posts table has a row with:
      | syndication_body |
      |                  |

  Scenario: list_posts keeps the status asked for and counts every status
    Given the posts table holds:
      | title | status    | published_at |
      | One   | published | 1 day ago    |
      | Two   | published | 2 days ago   |
      | Three | draft     | null         |
    When I call the MCP tool "list_posts" with:
      """
      {"status": "draft"}
      """
    Then the MCP answer holds:
      """
      {"posts": [{"id": 3}], "counts": {"draft": 1, "scheduled": 0, "published": 2}}
      """

  Scenario: list_posts counts only the posts in the range
    Given the posts table holds:
      | title | status    | published_at |
      | One   | published | 10 days ago  |
      | Two   | published | 1 day ago    |
    When I call list_posts from 3 days ago
    Then the MCP answer holds:
      """
      {"counts": {"published": 1}}
      """

  Scenario: list_posts gives each post its words, readership and webmentions, as the admin row does
    Given the posts table holds:
      | title | slug  | body          | status    | published_at | word_count |
      | Hello | hello | one two three | published | 5 days ago   | 3          |
      | Quiet | quiet | one two       | draft     | null         | 2          |
      | Old   | old   | old           | published | 400 days ago | 1          |
    And "/writing/hello" drew 8 views from 5 visitors and 4 read-throughs today
    And 2 readers read "/writing/hello"
    And the webmentions table holds:
      | post_id | source_url              | type  | status  | spam_reason |
      | 1       | https://203.0.113.5/one | reply | pending | null        |
      | 1       | https://203.0.113.5/two | reply | spam    | junk        |
    When I call the MCP tool "list_posts"
    Then list_posts gives post 1:
      """
      {"word_count": 3, "views": 8, "visitors": 5, "readers": 2, "read_throughs": 4, "webmentions_received": 2}
      """
    And list_posts gives post 2:
      """
      {"word_count": 2, "views": 0, "visitors": 0, "readers": 0, "read_throughs": 0, "webmentions_received": 0}
      """
    And list_posts gives post 3:
      """
      {"readers": null}
      """
    When I visit "/admin/posts"
    Then I see "3 words · 8 views · 5 visitors · 2 unique readers · 4 read-throughs"
    And the page has no axe breaches in light or dark
