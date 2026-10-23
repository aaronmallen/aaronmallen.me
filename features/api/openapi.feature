Feature: API OpenAPI document
  The API serves an OpenAPI document that names every operation, and each operation answers as it documents.

  Scenario: The document is OpenAPI 3.1 with one ID an operation and no reference left dangling
    Then the API document is OpenAPI 3.1, each operation has one ID, and every reference in it resolves

  Scenario: The document bounds each repeat field as the cadence contract does
    Then the API document bounds each repeat field of a new task as the cadence contract does

  Scenario: Every operation refuses a request with no token
    Then every operation the API document names refuses a request with no token

  @timeout:300_000
  Scenario: Every operation answers with a status the document names
    Then every operation the API document names answers with a status it documents
