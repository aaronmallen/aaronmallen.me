Feature: Short link titles and checks
  The site reads a short link's title from the page it points at, and checks every destination each night.

  Background:
    Given an API token

  Scenario: A new short link takes the og:title before the title
    Given the web answers GET "http://203.0.113.5/talk" with:
      """
      <html><head><title>Plain</title><meta property="og:title" content=" Open
        Graph "></head><body>hi</body></html>
      """
    When I POST "/short_links" through the API with:
      """
      {"destination": "http://203.0.113.5/talk"}
      """
    Then the API answers 201
    And the API answer holds:
      """
      {"code": "1", "destination": "http://203.0.113.5/talk", "click_count": 0}
      """
    And the short link to "http://203.0.113.5/talk" is titled "Open Graph"

  Scenario: A short link takes the title when the og:title is blank
    Given the web answers GET "http://203.0.113.5/talk" with:
      """
      <html><head><meta property="og:title" content=" "><title>
        My   talk 	</title></head></html>
      """
    When I POST "/short_links" through the API with:
      """
      {"destination": "http://203.0.113.5/talk"}
      """
    Then the short link to "http://203.0.113.5/talk" is titled "My talk"

  Scenario: A fetched title loses its control characters and stops at 200 characters
    Given the page "http://203.0.113.5/talk" has a title that runs past 200 characters
    When I POST "/short_links" through the API with:
      """
      {"destination": "http://203.0.113.5/talk"}
      """
    Then the short link to "http://203.0.113.5/talk" title starts with "bad bell word"
    And the short link to "http://203.0.113.5/talk" title ends with "word…" and runs 200 characters at most

  Scenario: A short link to an error page gets no title
    Given the web answers GET "http://203.0.113.5/talk" with status 500
    When I POST "/short_links" through the API with:
      """
      {"destination": "http://203.0.113.5/talk"}
      """
    Then the short link to "http://203.0.113.5/talk" has no title once the fetch is done

  Scenario: A short link to a page that is not HTML gets no title
    Given the web answers GET "http://203.0.113.5/talk" with:
      """
      {"title": "Not a page"}
      """
    When I POST "/short_links" through the API with:
      """
      {"destination": "http://203.0.113.5/talk"}
      """
    Then the short link to "http://203.0.113.5/talk" has no title once the fetch is done

  Scenario: A short link to a page with no title gets none
    Given the web answers GET "http://203.0.113.5/talk" with:
      """
      <p>hi</p>
      """
    When I POST "/short_links" through the API with:
      """
      {"destination": "http://203.0.113.5/talk"}
      """
    Then the short link to "http://203.0.113.5/talk" has no title once the fetch is done

  Scenario: The title fetch never asks a private address
    When I POST "/short_links" through the API with:
      """
      {"destination": "http://10.1.2.3/talk"}
      """
    Then the API answers 201
    And the short link to "http://10.1.2.3/talk" has no title once the fetch is done

  Scenario: A titled link fetches no title, and a link that is gone fetches nothing
    Given the short link "talk" to "http://203.0.113.5/talk"
    When the title fetch job runs for the short link 1
    And the title fetch job runs for the short link 99
    Then the short link to "http://203.0.113.5/talk" is titled "A short link"

  Scenario: Clearing a link's title has the site read it again
    Given the short link "talk" to "http://203.0.113.5/talk"
    And the web answers GET "http://203.0.113.5/talk" with:
      """
      <title>Fresh</title>
      """
    When I PATCH "/short_links/1" through the API with:
      """
      {"title": ""}
      """
    Then the short link to "http://203.0.113.5/talk" is titled "Fresh"

  Scenario: A link made while the queue is down holds its title fetch until the queue is back
    Given the web answers GET "http://203.0.113.5/talk" with:
      """
      <title>Held talk</title>
      """
    And the queue is down
    When I POST "/short_links" through the API with:
      """
      {"destination": "http://203.0.113.5/talk"}
      """
    Then the API answers 201
    And the short link to "http://203.0.113.5/talk" has a held title fetch
    When the queue is back
    And the held title fetches job runs
    Then the short link to "http://203.0.113.5/talk" is titled "Held talk"
    And no title fetch is held

  Scenario: Clearing a title while the queue is down holds the title fetch
    Given the short link "talk" to "http://203.0.113.5/talk"
    And the web answers GET "http://203.0.113.5/talk" with:
      """
      <title>Again</title>
      """
    And the queue is down
    When I PATCH "/short_links/1" through the API with:
      """
      {"title": ""}
      """
    Then the short link to "http://203.0.113.5/talk" has a held title fetch
    When the queue is back
    And the held title fetches job runs
    Then the short link to "http://203.0.113.5/talk" is titled "Again"

  Scenario: The held title fetches job queues nothing when nothing is held
    When the held title fetches job runs
    Then no title fetch is held

  Scenario: The nightly check marks a failing destination and passes a live one
    Given the short link "live" to "http://203.0.113.5/live"
    And the short link "dead" to "http://203.0.113.5/dead"
    And the web answers GET "http://203.0.113.5/live" with status 200
    And the web answers GET "http://203.0.113.5/dead" with status 404
    When the nightly link check runs
    Then the check of "http://203.0.113.5/live" counts no failures
    And the check of "http://203.0.113.5/dead" counts 1 failure with the reason "404 Not Found"
    When a browser fetches "/dead" from the share host
    Then the share host header "Location" is "http://203.0.113.5/dead"

  Scenario: A destination that keeps failing counts the nights and keeps when it first failed
    Given the short link "dead" to "http://203.0.113.5/dead"
    And the web answers GET "http://203.0.113.5/dead" with status 404
    When the nightly link check runs
    And the nightly link check runs
    Then the check of "http://203.0.113.5/dead" counts 2 failures with the reason "404 Not Found"
    And the check of "http://203.0.113.5/dead" keeps the time of its first failure

  Scenario: A 5xx fails the check and a 403 or 429 passes
    Given the short link "a" to "http://203.0.113.5/500"
    And the short link "b" to "http://203.0.113.5/403"
    And the short link "c" to "http://203.0.113.5/429"
    And the web answers GET "http://203.0.113.5/500" with status 500
    And the web answers GET "http://203.0.113.5/403" with status 403
    And the web answers GET "http://203.0.113.5/429" with status 429
    When the nightly link check runs
    Then the check of "http://203.0.113.5/500" counts 1 failure with the reason "500 Internal Server Error"
    And the check of "http://203.0.113.5/403" counts no failures
    And the check of "http://203.0.113.5/429" counts no failures

  Scenario: The check starts again once a link points somewhere new
    Given the short link "dead" to "http://203.0.113.5/dead"
    And the web answers GET "http://203.0.113.5/dead" with status 404
    And the web answers GET "http://203.0.113.5/live" with status 200
    When the nightly link check runs
    And I PATCH "/short_links/1" through the API with:
      """
      {"destination": "http://203.0.113.5/live"}
      """
    And the nightly link check runs
    Then the link checks cover only "http://203.0.113.5/live"
    And the check of "http://203.0.113.5/live" counts no failures

  Scenario: A check on demand checks that one link and counts on from the nightly run
    Given the short link "dead" to "http://203.0.113.5/dead"
    And the web answers GET "http://203.0.113.5/dead" with status 404
    When I POST "/short_links/1/check" through the API
    Then the check of "http://203.0.113.5/dead" counts 1 failure with the reason "404 Not Found"
    When the nightly link check runs
    And I POST "/short_links/1/check" through the API
    Then the check of "http://203.0.113.5/dead" counts 3 failures with the reason "404 Not Found"

  Scenario: A check on demand leaves the other links alone and checks nothing for a link that is gone
    Given the short link "dead" to "http://203.0.113.5/dead"
    And the short link "live" to "http://203.0.113.5/live"
    And the web answers GET "http://203.0.113.5/dead" with status 404
    When the short link check job runs for the short link 1
    And the short link check job runs for the short link 99
    Then the link checks cover only "http://203.0.113.5/dead"
