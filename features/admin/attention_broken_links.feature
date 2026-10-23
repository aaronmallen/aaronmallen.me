Feature: Broken links on the attention list
  The weekly link check follows each link in a published post. A link that fails twice in a row gets a row on the
  Needs attention card, until it answers again, leaves the post or the post goes back to a draft.

  Background:
    Given an API token
    And the country database holds the test networks
    And the database runs:
      """
      insert into posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled)
      values ('Linky post', 'linky-post', 'published', now() - interval '1 day',
              'See [a note](http://203.0.113.8/notes). See [a note](http://203.0.113.7/gone).',
              '<p>See <a href="http://203.0.113.8/notes">a note</a>. See <a href="http://203.0.113.7/gone">a note</a>.</p>',
              1, 8, false);
      """
    And the web answers GET "http://203.0.113.8/notes" with:
      """
      <p>A note</p>
      """
    And the web answers GET "http://203.0.113.7/gone" with status 404

  Scenario: A link that failed once adds nothing
    When the Today link check runs
    And I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0

  Scenario: A link that failed twice in a row adds a row
    When the Today link check runs
    And the Today link check runs
    And I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"attention": [{"kind": "broken_link", "title": "Linky post", "post_id": 1, "url": "http://203.0.113.7/gone",
                      "reason": "404 Not Found", "failures": 2}]}
      """

  Scenario: The row goes once the link answers again
    When the Today link check runs
    And the Today link check runs
    Given the web answers GET "http://203.0.113.7/gone" with:
      """
      <p>Back</p>
      """
    When the Today link check runs
    And I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0

  Scenario: The row and its snooze go once the link leaves the post
    When the Today link check runs
    And the Today link check runs
    And I call the API with "POST /api/v1/attention/snooze" and:
      """
      {"kind": "broken_link", "record_id": 2}
      """
    Then the call answers 200
    Given the database runs:
      """
      update posts set body_html = '<p>See <a href="http://203.0.113.8/notes">a note</a>.</p>';
      """
    When the Today link check runs
    And I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0
    And the database answers "0" for:
      """
      select count(*) from attention_snoozes
      """

  Scenario: The row goes once the post goes back to a draft
    When the Today link check runs
    And the Today link check runs
    And the database runs:
      """
      update posts set status = 'draft', published_at = null;
      """
    And I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0

  Scenario: A snoozed row stays hidden until the snooze ends
    When the Today link check runs
    And the Today link check runs
    And the database runs:
      """
      insert into attention_snoozes (kind, record_id, ends_at) select 'broken_link', id, now() + interval '7 days' from post_link_checks where failures = 2;
      """
    And I call the API with "GET /api/v1/attention"
    Then the answer's "attention" lists 0
    Given the database runs:
      """
      update attention_snoozes set ends_at = now() - interval '1 day';
      """
    When I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"attention": [{"kind": "broken_link", "url": "http://203.0.113.7/gone"}]}
      """

  Scenario: The admin card shows the post, the URL, the reason and a snooze
    When the Today link check runs
    And the Today link check runs
    Given I am signed in to the admin
    When I visit "/admin"
    Then the attention row "Linky post" opens "/admin/posts/1/edit"
    And the attention row "Linky post" says "http://203.0.113.7/gone"
    And the attention row "Linky post" says "404 Not Found"
    And the attention row "Linky post" snoozes as "broken_link"

  Scenario: list_attention returns the row
    When the Today link check runs
    And the Today link check runs
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read"
    When I call the MCP tool "list_attention"
    Then the answer's "attention" is:
      """
      [{"kind": "broken_link", "record_id": 2, "title": "Linky post", "carried_count": null, "days": null, "post_id": 1,
        "url": "http://203.0.113.7/gone", "reason": "404 Not Found", "failures": 2}]
      """
