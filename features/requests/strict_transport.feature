Feature: Strict transport
  In production the site tells the browser to keep to HTTPS for a year, on every reply.

  @timeout:180_000
  Scenario: The site in production tells the browser to keep to HTTPS on every reply
    Given the site runs in production
    When I request "/"
    Then it answers 200
    And the "Strict-Transport-Security" header is "max-age=31536000"
    When I request "/favicon.ico"
    Then it answers 200
    And the "Strict-Transport-Security" header is "max-age=31536000"
    When I request "/?a=%"
    Then it answers 400
    And the "Strict-Transport-Security" header is "max-age=31536000"
    When I request "/.well-known/oauth-authorization-server"
    Then it answers 200
    And the "Strict-Transport-Security" header is "max-age=31536000"

  @timeout:180_000
  Scenario: The site in development leaves the header off
    Given the site runs in development
    When I request "/"
    Then there is no "Strict-Transport-Security" header
