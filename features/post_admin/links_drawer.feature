Feature: The links drawer in the editor
  The editor lists the links in a post with how the nightly check found them, and checks them again on request.

  Background:
    Given I am signed in to the admin

  Scenario: A published post's drawer counts and sorts its links, failing ones first
    Given I wrote a published post "Hello" with:
      | body_html | <p><a href="http://203.0.113.1/ok">a</a> <a href="http://203.0.113.2/slow">b</a> <a href="http://203.0.113.3/gone">c</a> <a href="http://203.0.113.4/new">d</a></p> |
    And the post_link_checks table holds:
      | post_id | url                      | failures | reason        | checked_at           | first_failed_at      |
      | 1       | http://203.0.113.3/gone  | 3        | 404 Not Found | 2026-10-14T08:00:00Z | 2026-10-12T08:00:00Z |
      | 1       | http://203.0.113.2/slow  | 1        | 404 Not Found | 2026-10-12T08:00:00Z | 2026-10-12T08:00:00Z |
      | 1       | http://203.0.113.1/ok    | 0        | null          | 2026-10-12T08:00:00Z | null                 |
    When I open the editor for "Hello"
    Then the post links button says "2 failing"
    When I open the post links
    Then the post links drawer shows "4 links"
    And the post links drawer shows "2 failing"
    And the post links drawer shows "1 not checked yet"
    And the post links drawer lists "http://203.0.113.3/gone, http://203.0.113.2/slow, http://203.0.113.4/new"
    And the post link "http://203.0.113.3/gone" shows "failing 3 nights"
    And the post link "http://203.0.113.3/gone" shows "404 Not Found"
    And the post link "http://203.0.113.3/gone" shows "first failed Oct 12, 2026"
    And the post link "http://203.0.113.3/gone" is marked pink
    And the post link "http://203.0.113.2/slow" is marked orange
    And the post link "http://203.0.113.4/new" shows "not checked yet"
    And the post link "http://203.0.113.4/new" shows "added since the last check"
    And the post links drawer folds "1 fine"
    And the post link "http://203.0.113.3/gone" offers Find in post, Check again and Open link
    And the page has no axe breaches in light or dark

  Scenario: A draft's links wait until it is live and offer no check
    Given I wrote a draft post "Draft" with:
      | body_html | <p><a href="http://203.0.113.3/gone">c</a></p> |
    When I open the editor for "Draft"
    And I open the post links
    Then the post link "http://203.0.113.3/gone" shows "not checked yet"
    And the post link "http://203.0.113.3/gone" shows "checked once the post is live"
    And the post links drawer shows "Drafts are not checked overnight"
    And the post links drawer offers no check

  Scenario: A post that links nowhere says so
    Given I wrote a published post "Hello"
    When I open the editor for "Hello"
    And I open the post links
    Then the post links drawer shows "No links"

  Scenario: Checking one link again records what it answers and updates the open drawer
    Given I wrote a published post "Hello" with:
      | body_html | <p><a href="http://203.0.113.3/gone">c</a> <a href="http://203.0.113.1/ok">a</a></p> |
    And the web answers GET "http://203.0.113.3/gone" with status 404
    When I open the editor for "Hello"
    And I open the post links
    Then the post link "http://203.0.113.3/gone" shows "not checked yet"
    When I check the post link "http://203.0.113.3/gone" again
    Then the post toast says "Checking that link"
    And I am on "/admin/posts/1/edit?links=1"
    And the post links drawer is open
    And the post link "http://203.0.113.3/gone" shows "404 Not Found"
    And the post link "http://203.0.113.3/gone" is marked orange
    And the post_link_checks table holds 1 rows

  Scenario: Checking every link again checks each one
    Given I wrote a published post "Hello" with:
      | body_html | <p><a href="http://203.0.113.3/gone">c</a> <a href="http://203.0.113.1/ok">a</a></p> |
    And the web answers GET "http://203.0.113.3/gone" with status 404
    And the web answers GET "http://203.0.113.1/ok" with status 200
    When I open the editor for "Hello"
    And I open the post links
    And I check every post link again
    Then the post links drawer is open
    And the post_link_checks table holds 2 rows

  Scenario: Find in post closes the drawer and picks the link in the body
    Given I wrote a published post "Hello" with:
      | body      | intro\n\n[the note](http://203.0.113.3/gone)                  |
      | body_html | <p>intro</p><p><a href="http://203.0.113.3/gone">the note</a></p> |
    When I open the editor for "Hello"
    And I open the post links
    And I find "http://203.0.113.3/gone" in the post
    Then the post links drawer is shut
    And the post body has "http://203.0.113.3/gone" picked

  Scenario: Checking a draft's links queues nothing
    Given I wrote a draft post "Draft" with:
      | body_html | <p><a href="http://203.0.113.3/gone">c</a></p> |
    And I open the editor for "Draft"
    When I send the post form to "/admin/posts/{Draft}/links/check" with:
      | url | http://203.0.113.3/gone |
    Then the post toast says "Not checked · links get checked once the post is live"
    And the post_link_checks table holds 0 rows
