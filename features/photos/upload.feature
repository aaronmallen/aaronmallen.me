Feature: Photo upload
  The admin and the API take a photo, make it safe and small enough, and keep it in the photo store.

  Background:
    Given I am signed in to the admin

  Scenario: The admin stores a rotated JPEG upright with no metadata
    When I upload the photo file "rotated_with_gps.jpg" in the admin
    Then the photo upload answers 201 with the photo's URL and key
    And the stored photo is a jpg of 20 by 40
    And the stored photo carries no metadata
    And the photo row is 20 by 40 with the widths ""
    And no photo is claimed
    And the photo's URL serves the stored photo to the owner

  Scenario: The admin stores a HEIC photo as a JPEG
    When I upload the photo file "photo.heic" in the admin
    Then the photo upload answers 201 with the photo's URL and key
    And the stored photo is a jpg of 64 by 48
    And the stored photo starts like a JPEG

  Scenario: The admin judges a photo by its bytes, not its name
    When I upload the photo file "rotated_with_gps.jpg as photo.png" in the admin
    Then the stored photo is a jpg of 20 by 40

  Scenario: The admin shrinks a large photo and keeps smaller widths beside it
    When I upload the photo file "large.png" in the admin
    Then the stored photo is a png of 2560 by 853
    And the photo store keeps the stored photo at the widths "640 1280 1920"
    And the photo row is 2560 by 853 with the widths "640 1280 1920"

  Scenario: The admin keeps a small photo at its size
    When I upload the photo file "small.png" in the admin
    Then the stored photo is a png of 32 by 24
    And the photo store holds 1 file
    And the photo row is 32 by 24 with the widths ""

  Scenario: The admin keeps the edge of a clear PNG white in each smaller width
    When I upload the photo file "clear.png" in the admin
    Then the stored photo's 640 wide copy is white at 320, 160

  Scenario: The admin keeps every frame of a wide GIF in each smaller width
    When I upload the photo file "wide.gif" in the admin
    Then the stored photo 640 holds 3 frames of 640 by 320

  Scenario Outline: The admin keeps an animated <type> as it is
    When I upload the photo file "<file>" in the admin
    Then the stored photo is a <type> of 32 by 24
    And the stored photo itself holds 3 frames of 32 by 24
    And the photo row is 32 by 24 with the widths ""

    Examples:
      | file          | type |
      | animated.gif  | gif  |
      | animated.webp | webp |

  Scenario Outline: The admin refuses <what>
    When I upload the photo file "<file>" in the admin
    Then the photo upload answers 422 with the error "<error>"
    And the photo store and the photos table are empty

    Examples:
      | what                          | file      | error                                                  |
      | a photo over 100 megapixels   | huge.png  | That photo is over 100 megapixels. Pick a smaller one. |
      | a file over 20 MB             | big.jpg   | That photo is over 20 MB. Pick a smaller one.          |
      | an SVG                        | drawing.svg | Upload a JPEG, PNG, WebP, GIF or HEIC photo.         |
      | bytes that match no type      | text.jpg  | Upload a JPEG, PNG, WebP, GIF or HEIC photo.           |
      | a file that only starts like a JPEG | half.jpg | The site could not read that photo.               |

  Scenario: The admin refuses an upload with no file
    When I send the admin a photo upload with no file
    Then the photo upload answers 422 with the error "Choose a photo to upload."
    And the photo store and the photos table are empty

  Scenario: The admin refuses an upload without a CSRF token
    When I upload the photo file "small.png" in the admin without a CSRF token
    Then the photo upload is refused with 403
    And the photo store and the photos table are empty

  Scenario: The admin stores nothing for someone signed out
    When someone signed out uploads the photo file "small.png" to the admin
    Then the photo store and the photos table are empty

  Scenario: The admin says the store is down when it turns the photo away
    Given the photo store turns away every write
    When I upload the photo file "small.png" in the admin
    Then the photo upload answers 503 with the error "The photo store is down or not set up."
    And the photo store and the photos table are empty
