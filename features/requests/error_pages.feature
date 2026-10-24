Feature: The error pages in production
  In production every error answers a static page of the site: it names the site, links home, stays out of a
  shared cache and loads nothing the app has to render.

  @timeout:240_000
  Scenario: Every error in production answers a static page of the site
    Given the environment sets WEB_STATEMENT_TIMEOUT to "1"
    And the site runs in production
    When I request "/no-such-page"
    Then it answers an error page for 404
    When I request "/?a=%"
    Then it answers an error page for 400
    When I post a form field "message[body]" of 1048576 bytes to "/contact"
    Then it answers an error page for 413
    When I post the file "a.jpg" of type "image/jpeg" holding the bytes "61" as "photo" to "/contact"
    Then it answers an error page for 415
    Given another session locks the posts table
    When I request "/writing"
    Then it answers an error page for 500
    And the other session lets the posts table go

  Scenario: The pages in public/ match what config/error_page.html builds
    When I run "scripts/lint/error-pages"
    Then it succeeds
