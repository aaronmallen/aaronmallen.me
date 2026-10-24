Feature: Content types
  A page answers HTML whether the browser sends no Accept header or */*, and a format the site does not serve
  gets 406.

  Scenario Outline: A public page answers HTML for <accept>
    Given my requests send <accept>
    When I request "/writing"
    Then the "Content-Type" header is "text/html; charset=utf-8"

    Examples:
      | accept                         |
      | no "Accept" header             |
      | the header "Accept" as "*/*"   |

  Scenario Outline: The admin sign-in page answers HTML for <accept>
    Given my requests send <accept>
    When I request "/admin/sign-in"
    Then the "Content-Type" header is "text/html; charset=utf-8"

    Examples:
      | accept                         |
      | no "Accept" header             |
      | the header "Accept" as "*/*"   |

  Scenario Outline: An admin page and the post preview answer HTML for <accept>
    Given I am signed in to the admin
    And my requests send <accept>
    When I request "/admin/posts"
    Then the "Content-Type" header is "text/html; charset=utf-8"
    When I post the form "/admin/posts/preview" with my token and:
      | post[title] | Hello |
    Then it answers 200
    And the "Content-Type" header is "text/html; charset=utf-8"

    Examples:
      | accept                         |
      | no "Accept" header             |
      | the header "Accept" as "*/*"   |

  Scenario: A page asked for in a format the site does not serve answers 406
    Given my requests send the header "Accept" as "application/json"
    When I request "/writing"
    Then it answers 406
