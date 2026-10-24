Feature: A request the site cannot read
  A request with bytes that are not UTF-8, a query Rack cannot unescape or a field sent in two shapes gets the
  site's 400 page, and stores nothing. A request the site can read reaches its action.

  Scenario Outline: <what> gets the site's 400 page
    When I request "<path>"
    Then it answers 400
    And the body matches "<main[\s\S]*class=\"status\"[^>]*>400<"

    Examples:
      | what                        | path                  |
      | A tag that is not UTF-8     | /writing/tags/%FF     |
      | A tag feed that is not UTF-8 | /writing/tags/%FF.atom |
      | A query value that is not UTF-8 | /writing?page=%FF  |
      | A query key that is not UTF-8 | /writing?%FF=1       |
      | A query Rack cannot unescape | /?a=%                |

  Scenario: A contact field that is not UTF-8 gets the 400 page and stores no message
    When I post "/contact" with the "application/x-www-form-urlencoded" body "message[subject]=hi&message[body]=%FF"
    Then it answers 400
    And the body matches "<main[\s\S]*class=\"status\"[^>]*>400<"
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_messages
      """

  Scenario: A contact field sent as both a value and a hash gets the 400 page
    When I post "/contact" with the "application/x-www-form-urlencoded" body "message[body]=a&message[body][x]=b"
    Then it answers 400
    And the body matches "<main[\s\S]*class=\"status\"[^>]*>400<"

  Scenario: A client that asks for JSON gets the 400 status in JSON
    Given my requests send the header "Accept" as "application/json"
    When I request "/?a=%"
    Then it answers 400
    And the JSON answer holds "status" as "400"

  Scenario: A JSON body that holds a percent sign reaches the MCP action
    Given my requests send the header "Authorization" as "Bearer nope"
    When I post "/mcp" with the "application/json" body:
      """
      {"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"note":"100%"}}
      """
    Then it answers 401

  Scenario: A file upload whose bytes are not UTF-8 passes the guard
    When I post the file "a.jpg" of type "image/jpeg" holding the bytes "FF D8 FF FE" as "photo" to "/admin/photos"
    Then it answers 403

  Scenario Outline: A JSON body the admin cannot parse, to <verb> <path> signed out, answers 400
    When I <verb> "<path>" with the "application/json" body "{"
    Then it answers 400

    Examples:
      | verb | path                 |
      | post | /admin/photos        |
      | get  | /admin/search/palette |

  Scenario Outline: A JSON body the admin cannot parse, to <verb> <path> signed in, answers 400
    Given I am signed in to the admin
    When I <verb> "<path>" with the "application/json" body "{"
    Then it answers 400

    Examples:
      | verb | path                 |
      | post | /admin/photos        |
      | get  | /admin/search/palette |

  Scenario: A request the site can read reaches its action
    When I request "/writing/tags/nothing-here?a=caf%C3%A9"
    Then it answers 404
    And the body matches "<main[\s\S]*class=\"status\"[^>]*>404<"
