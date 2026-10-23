Feature: CORS preflight
  The MCP endpoint and the token endpoint answer a browser's preflight; registration names no origin.

  Scenario Outline: OPTIONS <path> answers with no content and allows any origin, POST and the MCP headers
    When a browser on another site asks before it posts to "<path>"
    Then the answer is 204
    And the answer has no body
    And the answer has the header "Access-Control-Allow-Origin" set to "*"
    And the answer has the header "Access-Control-Allow-Methods" set to "POST"
    And the answer has the header "Access-Control-Allow-Headers" set to "Authorization, Content-Type, MCP-Protocol-Version"
    And the answer has no header "WWW-Authenticate"

    Examples:
      | path         |
      | /mcp         |
      | /oauth/token |

  Scenario: OPTIONS /oauth/register names no origin and allows no cross-origin POST
    When a browser on another site asks before it posts to "/oauth/register"
    Then the answer has no header "Access-Control-Allow-Origin"
    And the answer has no header "Access-Control-Allow-Methods"
