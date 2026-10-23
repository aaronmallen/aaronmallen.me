Feature: Receiving webmentions
  POST /webmention takes a notice that a page links to a post, keeps a receipt
  and queues a check of the source. It turns away what it cannot use.

  Background:
    Given a published post "Hello" taking webmentions

  Scenario: A notice for a post is taken and its source is checked
    Given the source page "http://203.0.113.7/notes/1" answers 410
    When a webmention arrives from "http://203.0.113.7/notes/1" for "{post}"
    Then the webmention endpoint answers 202
    And the webmention_receipts table has a row with:
      | post_id | source_url                 |
      | 1       | http://203.0.113.7/notes/1 |
    And the webmention checks finish

  Scenario Outline: A notice it cannot use is turned away and nothing is queued
    When a webmention arrives from "<source>" for "<target>"
    Then the webmention endpoint answers 400
    And the webmention_receipts table holds 0 rows

    Examples:
      | what                                     | source                          | target                   |
      | a source that is the target              | {post}                          | {post}                   |
      | the target under another spelling        | {site}/writing/hello/           | {post}                   |
      | a source that does not parse             | http://[bad                     | {post}                   |
      | a source with no host                    | https:///notes/1                | {post}                   |
      | a source that is not http                | ftp://203.0.113.7/notes/1       | {post}                   |
      | a target that is not http                | http://203.0.113.7/notes/1      | ftp://127.0.0.1/hello    |
      | a target that is not an article          | http://203.0.113.7/notes/1      | {site}/tags/ruby         |
      | a target no post has                     | http://203.0.113.7/notes/1      | {site}/writing/nope      |
      | a source past 2048 bytes                 | http://203.0.113.7/{a*2030}     | {post}                   |
      | a slug of bytes that are not UTF-8       | http://203.0.113.7/notes/1      | {site}/writing/%FF       |
      | a slug with an escaped space             | http://203.0.113.7/notes/1      | {site}/writing/hello%20x |
      | a slug with an escaped slash             | http://203.0.113.7/notes/1      | {site}/writing/hello%2Fx |
      | a slug that is a reserved word           | http://203.0.113.7/notes/1      | {site}/writing/tags      |

  Scenario: A slug with a capital letter is turned away even when a post has it
    Given the posts table holds:
      | title  | slug  | status    | published_at | webmentions_enabled |
      | Shouty | Hello | published | 1 hour ago   | true                |
    When a webmention arrives from "http://203.0.113.7/notes/1" for "{site}/writing/Hello"
    Then the webmention endpoint answers 400
    And the webmention_receipts table holds 0 rows

  Scenario: A source of exactly 2048 bytes is taken
    Given the source page "http://203.0.113.7/{a*2029}" answers 410
    When a webmention arrives from "http://203.0.113.7/{a*2029}" for "{post}"
    Then the webmention endpoint answers 202
    And the webmention checks finish

  Scenario: Every notice is turned away while receiving is off
    Given the webmention setting receive is off
    When a webmention arrives from "http://203.0.113.7/notes/1" for "{post}"
    Then the webmention endpoint answers 400

  Scenario: A new source is turned away once the post turns webmentions off
    Given the posts table holds:
      | title | status    | published_at | webmentions_enabled |
      | Quiet | published | 1 hour ago   | false               |
    When a webmention arrives from "http://203.0.113.7/notes/1" for "{site}/writing/quiet"
    Then the webmention endpoint answers 400
    And the webmention_receipts table holds 0 rows

  Scenario Outline: A source it stored before still gets checked once <what>, so a withdrawal lands
    Given these webmentions on the post "Hello":
      | source_url                 |
      | http://203.0.113.7/notes/1 |
    And <closed>
    And the source page "http://203.0.113.7/notes/1" answers 410
    When a webmention arrives from "http://203.0.113.7/notes/1" for "{post}"
    Then the webmention endpoint answers 202
    And the webmention checks finish
    And the webmentions table holds 0 rows

    Examples:
      | what                             | closed                                   |
      | the post turned webmentions off  | the post "Hello" turns webmentions off   |
      | receiving is off                 | the webmention setting receive is off    |

  Scenario: A Bridgy notice is taken while Bridgy is on
    Given the source page "http://brid.gy/like/mastodon/1" answers 410
    When a webmention arrives from "http://brid.gy/like/mastodon/1" for "{post}"
    Then the webmention endpoint answers 202
    And the webmention checks finish

  Scenario: A Bridgy notice is turned away once Bridgy is off
    Given the webmention setting accept_bridgy is off
    When a webmention arrives from "http://brid.gy/like/mastodon/1" for "{post}"
    Then the webmention endpoint answers 400
    And the webmention_receipts table holds 0 rows

  Scenario: A Bridgy source it stored before is still checked once Bridgy is off
    Given these webmentions on the post "Hello":
      | source_url                     |
      | http://brid.gy/like/mastodon/1 |
    And the webmention setting accept_bridgy is off
    And the source page "http://brid.gy/like/mastodon/1" answers 410
    When a webmention arrives from "http://brid.gy/like/mastodon/1" for "{post}"
    Then the webmention endpoint answers 202
    And the webmention checks finish

  Scenario: Other senders are still taken once Bridgy is off
    Given the webmention setting accept_bridgy is off
    And the source page "http://203.0.113.7/notes/1" answers 410
    When a webmention arrives from "http://203.0.113.7/notes/1" for "{post}"
    Then the webmention endpoint answers 202
    And the webmention checks finish

  Scenario: One sender's notices arriving together are taken up to the limit
    When 35 webmentions arrive at once from "http://203.0.113.7/notes" for "{post}"
    Then 30 of them are taken and 5 are turned away
    And the webmention_receipts table holds 30 rows
    And the webmention checks finish

  Scenario: A receipt older than the window is reaped, a newer one kept
    Given the webmention_receipts table holds:
      | post_id | source_url                 | visitor_hash                                                     | received_at    |
      | 1       | http://203.0.113.7/notes/1 | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | 61 minutes ago |
      | 1       | http://203.0.113.7/notes/2 | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | 59 minutes ago |
    When the webmention receipts are reaped
    Then the webmention_receipts table holds 1 rows
    And the webmention_receipts table has a row with:
      | source_url                 |
      | http://203.0.113.7/notes/2 |

  Scenario: A sender stays throttled for the receipts inside the window after a reap
    When 30 webmentions arrive at once from "http://203.0.113.7/notes" for "{post}"
    And the webmention checks finish
    And the webmention receipts are reaped
    And a webmention arrives from "http://203.0.113.7/late" for "{post}"
    Then the webmention endpoint answers 429

  Scenario: A notice that arrives while the queue is down is held, then checked once it is back
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a class="u-in-reply-to" href="{post}">re</a><p class="e-content">Hi</p></div>
      """
    And the webmention queue is down
    When a webmention arrives from "http://203.0.113.7/notes/1" for "{post}"
    Then the webmention endpoint answers 202
    And the held_webmentions table has a row with:
      | post_id | source_url                 |
      | 1       | http://203.0.113.7/notes/1 |
    Given the webmention queue is back
    When the held webmentions are queued
    Then the webmentions table has a row with:
      | source_url                 | status  |
      | http://203.0.113.7/notes/1 | pending |
    And the held_webmentions table holds 0 rows

  Scenario: Nothing is queued when nothing is held
    When the held webmentions are queued
    Then no webmention check has run
