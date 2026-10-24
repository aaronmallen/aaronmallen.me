Feature: Public pages
  Every public page renders under the test settings, which leave the MaxMind, Google and LinkedIn credentials
  blank, and sets no cookie.

  Scenario Outline: <path> renders and sets no cookie
    When I request "<path>"
    Then it answers 200
    And there is no "Set-Cookie" header

    Examples:
      | path      |
      | /         |
      | /about    |
      | /contact  |
      | /privacy  |
      | /projects |
      | /writing  |
