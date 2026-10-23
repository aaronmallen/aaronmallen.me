Feature: Photos through the API and MCP
  An agent uploads a photo and reads one back, through the JSON API or MCP.

  Scenario Outline: The API stores <file> as <type>
    Given I am signed in to the admin
    And an API token
    When I upload the photo file "<file>" through the API
    Then the uploaded photo answers with its URL and size
    And the stored photo is a <type> of <width> by <height>
    And the photo's URL serves the stored photo to the owner

    Examples:
      | file                 | type | width | height |
      | animated.gif         | gif  | 32    | 24     |
      | rotated_with_gps.jpg | jpg  | 20    | 40     |
      | small.png            | png  | 32    | 24     |
      | animated.webp        | webp | 32    | 24     |
      | photo.heic           | jpg  | 64    | 48     |

  Scenario: The API judges a photo by its bytes, not its name
    Given an API token
    When I upload the photo file "rotated_with_gps.jpg as photo.png" through the API
    Then the stored photo is a jpg of 20 by 40

  Scenario: The API takes base64 broken across lines
    Given an API token
    When I upload the photo file "small.png" through the API in base64 broken across lines
    Then the uploaded photo answers with its URL and size

  Scenario Outline: The API refuses <what>
    Given an API token
    When I upload the photo file "<file>" through the API
    Then the API refuses the photo with "<error>"
    And the photo store and the photos table are empty

    Examples:
      | what                                | file        | error                                                  |
      | a photo over 100 megapixels         | huge.png    | That photo is over 100 megapixels. Pick a smaller one. |
      | data over 20 MB                     | big.jpg     | That photo is over 20 MB. Pick a smaller one.          |
      | an SVG                              | drawing.svg | Upload a JPEG, PNG, WebP, GIF or HEIC photo.           |
      | a file that only starts like a JPEG | half.jpg    | The site could not read that photo.                    |

  Scenario: The API refuses blank data
    Given an API token
    When I POST "/photos" through the API with:
      """
      {"data": "", "filename": "photo.png"}
      """
    Then the API refuses the photo with "Choose a photo to upload."
    And the photo store and the photos table are empty

  Scenario: The API refuses data that is not base64
    Given an API token
    When I POST "/photos" through the API with:
      """
      {"data": "not*base64!", "filename": "photo.png"}
      """
    Then the API refuses the photo with "The site could not read that photo."
    And the photo store and the photos table are empty

  Scenario: The API refuses a photo with no file name
    Given an API token
    When I POST "/photos" through the API with:
      """
      {"data": ""}
      """
    Then the API answers 422
    And the API answer holds:
      """
      {"errors": {"filename": ["filename is missing"]}}
      """

  Scenario: The API refuses a photo with no token
    When I upload the photo file "small.png" through the API with no token
    Then the photo upload is refused with 401
    And the photo store and the photos table are empty

  Scenario: MCP uploads a photo and answers as the API does
    Given an MCP client connected with the scopes "read write publish"
    When I upload the photo file "small.png" through MCP
    Then the MCP upload answers like the API upload, less the key
    And the stored photo is a png of 32 by 24

  Scenario: MCP refuses a photo with the API's reason
    Given an MCP client connected with the scopes "read write"
    When I call the MCP tool "upload_photo" with:
      """
      {"data": "", "filename": "photo.png"}
      """
    Then the MCP tool refuses with "Choose a photo to upload."

  Scenario: A post saved through MCP claims the photo MCP uploaded
    Given an MCP client connected with the scopes "read write publish"
    When I upload the photo file "small.png" through MCP
    And I call the MCP tool "create_post" with the uploaded photo's URL in:
      """
      {"title": "Hello", "body": "![A photo](PHOTO_URL)"}
      """
    Then the post claims 1 photo

  Scenario: A journal entry saved through MCP claims the photo MCP uploaded
    Given an MCP client connected with the scopes "read write"
    When I upload the photo file "small.png" through MCP
    And I call the MCP tool "create_journal_entry" with the uploaded photo's URL in:
      """
      {"body": "![A photo](PHOTO_URL)"}
      """
    Then the journal_entry claims 1 photo

  Scenario: The API reads a photo with its bytes in base64
    Given an API token
    And the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" of 20 by 40 uploaded 1 hours ago
    When I read the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" through the API
    Then the photo read answers the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" of 20 by 40 with its bytes
    When I read the photo "https://aaronmallen.me/photos/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" through the API
    Then the photo read answers the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" of 20 by 40 with its bytes

  Scenario: The API answers 404 for a key the site does not keep
    Given an API token
    When I read the photo "missing.jpg" through the API
    Then the photo read answers 404 with "no photo has the key missing.jpg"

  Scenario: The API answers 503 when the store holds no bytes for a photo
    Given an API token
    And the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" of 20 by 40 uploaded 1 hours ago
    And the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" is missing from the photo store
    When I read the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" through the API
    Then the photo read answers 503 with "the photo store is not set up or did not answer; try again later"

  Scenario: MCP reads a photo as one image block and one text block
    Given an MCP client connected with the scopes "read"
    And the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" of 20 by 40 uploaded 1 hours ago
    When I read the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" through MCP
    Then the MCP photo read shows the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" of 20 by 40
    When I read the photo "http://127.0.0.1/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" through MCP
    Then the MCP photo read shows the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" of 20 by 40

  Scenario: MCP reads a photo only a draft post claims
    Given an MCP client connected with the scopes "read write"
    And the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" of 20 by 40 uploaded 1 hours ago
    And I call the MCP tool "create_post" with:
      """
      {"title": "Draft", "body": "![A photo](/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg)"}
      """
    When I read the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" through MCP
    Then the MCP photo read shows the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" of 20 by 40

  Scenario: MCP refuses a key the site does not keep and names it
    Given an MCP client connected with the scopes "read"
    When I read the photo "https://aaronmallen.me/media/ffffffffffffffffffffffffffffffff.png" through MCP
    Then the MCP photo read refuses with "no photo has the key ffffffffffffffffffffffffffffffff.png"

  Scenario: MCP refuses a photo the store holds no bytes for
    Given an MCP client connected with the scopes "read"
    And the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" of 20 by 40 uploaded 1 hours ago
    And the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" is missing from the photo store
    When I read the photo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" through MCP
    Then the MCP photo read refuses with "the photo store is not set up or did not answer; try again later"

  Scenario: The API says the store is down when it turns the photo away
    Given an API token
    And the photo store turns away every write
    When I upload the photo file "small.png" through the API
    Then the API says the photo store is down
    And the photo store and the photos table are empty

  Scenario: MCP says the store is down when it turns the photo away
    Given an MCP client connected with the scopes "read write"
    And the photo store turns away every write
    When I upload the photo file "small.png" through MCP
    Then the MCP tool refuses with "The photo store is down or not set up."

  Scenario: The API takes back the photos it stored when a later write fails
    Given an API token
    And the photo store turns away the third write
    When I upload the photo file "large.png" through the API
    Then the API says the photo store is down
    And the photo store was told to delete each photo it took
    And the photo store and the photos table are empty
