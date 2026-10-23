Feature: MCP list tool paging
  Each list tool answers a hundred rows a page, says when more remain, and names the page that holds them.

  Background:
    Given an MCP client connected with the scopes "read mail"

  Scenario Outline: <tool> answers a page at most, names the next, answers the rest from it, and bounds its pages
    Given 102 rows that <tool> lists
    When I read every row <tool> lists, two pages of it
    Then the first page of <tool> holds 100 rows, says more remain and names page 2
    And page 2 of <tool> holds the 2 rows after them and says it is whole
    And <tool> answers no rows on page 3
    And <tool> refuses page 0
    And <tool> refuses page 2147483648
    And <tool> answers no rows on page 2147483647

    Examples:
      | tool              |
      | list_posts        |
      | list_social_posts |
      | list_mail_threads |
      | list_webmentions  |
      | list_suggestions  |
      | list_tags         |

  Scenario: Paging messages keeps the status it was given
    Given 101 rows that list_mail_threads lists
    And the database runs "UPDATE mail_threads SET marked_spam_at = now(), status = 'spam' WHERE id = 1"
    And the database runs "UPDATE mail_threads SET subject = 'Spam thread' WHERE id = 1"
    Then paging list_mail_threads with '{"status": "unread"}' over two pages finds 100 rows, none of them "Spam thread"

  Scenario: Paging webmentions keeps the status it was given
    Given 101 rows that list_webmentions lists
    And the database runs "UPDATE webmentions SET status = 'spam', source_url = 'https://203.0.113.5/spam' WHERE id = 1"
    Then paging list_webmentions with '{"status": "pending"}' over two pages finds 100 rows, none of them "203.0.113.5/spam"

  Scenario: Paging posts keeps the range it was given
    Given 101 rows that list_posts lists
    And the database runs "UPDATE posts SET published_at = now() - interval '10 days', title = 'Old post' WHERE id = 1"
    Then paging list_posts with '{"from": "1970-01-02"}' over two pages finds 101 rows, none of them "nothing"
    And paging list_posts with the range of the last day over two pages finds 100 rows, none of them "Old post"

  Scenario: list_posts pages its unsent social posts, drafts newest first, then the queue soonest first
    Given the database runs:
      """
      INSERT INTO social_posts (targets, status, posted_at) VALUES ('{mastodon}', 'posted', now() - interval '1 hour');
      INSERT INTO social_posts (targets, status) SELECT '{mastodon}', 'draft' FROM generate_series(1, 51) AS n;
      INSERT INTO social_posts (targets, status, posted_at) SELECT '{mastodon}', 'scheduled', now() + n * interval '1 hour' FROM generate_series(1, 51) AS n
      """
    When I page through list_posts' social posts
    Then the social posts come drafts newest first, then the queue soonest first, with no posts
