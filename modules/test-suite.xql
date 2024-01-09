xquery version "3.1";

  module namespace txqt="http://tapasproject.org/tapas-xq/testsuite";
(:  LIBRARIES  :)
  import module namespace bin="http://expath.org/ns/binary";
  import module namespace convert="http://basex.org/modules/convert";
  import module namespace db="http://basex.org/modules/db";
  import module namespace http="http://expath.org/ns/http-client";
  import module namespace tap="http://tapasproject.org/tapas-xq/api"
    at "tapas-api.xql";
  import module namespace tgen="http://tapasproject.org/tapas-xq/general"
    at "general-functions.xql";
  import module namespace unit="http://basex.org/modules/unit";
(:  NAMESPACES  :)
  declare namespace tei="http://www.tei-c.org/ns/1.0";
  declare namespace mods="http://www.loc.gov/mods/v3";
  declare namespace xhtml="http://www.w3.org/1999/xhtml";

(:~
  A suite of unit tests for the TAPAS-xq API support functions.
  
  In BaseX, XQUnit tests can only be run with the "TEST" command, in the GUI or on the command line. As 
  a result, this script cannot be run when BaseX is running in HTTP mode — and so, this script cannot be 
  used to test the responses of RESTXQ endpoints. Instead, this version of the script is intended to 
  test the support functions in tapas-api.xql and general-functions.xql .
  
  @author Ash Clark
  @version 3.0
  @see https://docs.basex.org/wiki/Unit_Module
  
  2023-10-11: Started refactoring for use in BaseX.
 :)

(:
    VARIABLES
 :)
  
  declare variable $txqt:test-project := 'testProj01';
  declare variable $txqt:test-doc-name := 'testDoc01';
  declare variable $txqt:test-doc-path := '../resources/testdocs/sampleTEI.xml';
  declare variable $txqt:test-doc := doc($txqt:test-doc-path);


(:
    FUNCTIONS
 :)

  (:~
    Before starting the unit tests, store the test document in the TAPAS database.
   :)
  declare %unit:before-module %updating function txqt:_test-setup() {
    let $dbDocPath := 
      concat($txqt:test-project,'/',$txqt:test-doc-name,'.xml')
    return db:put('tapas-data', $txqt:test-doc, $dbDocPath)
  };
  
  (:~
    After completing testing, delete any content stored under the test project path.
   :)
  declare %unit:after-module %updating function txqt:_test-teardown() {
    db:delete('tapas-data', $txqt:test-project)
  };
  
  (:~
    Ensure tgen:set-status-description() returns a message "OK" for HTTP status code 200.
   :)
  declare %unit:test function txqt:set-http-status-description-for-200() {
    let $msg := normalize-space(tgen:set-status-description(200))
    return unit:assert-equals($msg, "OK")
  };
  
  (:~
    Ensure tgen:set-status-description() returns the generic message "Error: bad request" for HTTP 
    status codes in the 4XX range.
   :)
  declare %unit:test function txqt:set-http-status-description-for-418() {
    (: HTTP code 418 is "I'm a teapot". :)
    let $msg := normalize-space(tgen:set-status-description(418))
    return (
        unit:assert(starts-with($msg, "Error:")),
        unit:assert(contains($msg, "bad request"))
      )
  };
  
  (:~
    Ensure tgen:set-status-description() returns the generic message "Error" as a fallback, e.g. when no 
    HTTP code is provided.
   :)
  declare %unit:test function txqt:set-http-status-description-without-code() {
    let $msg := normalize-space(tgen:set-status-description(()))
    return unit:assert-equals($msg, "Error")
  };
  
  (:~
    An HTTP response with a 200 status code and no content should reflect that status code and the message "OK".
   :)
  declare %unit:test function txqt:build-response-200() {
    let $response := tap:build-response(200)
    let $msg := $response[2]/normalize-space()
    return (
        unit:assert-equals($response[1]//@status/xs:string(.), '200'),
        unit:assert-equals(count($response), 2),
        unit:assert-equals($msg, 'OK')
      )
  };
  
  (:~
    Build HTTP response with a "400" status code. No content is provided to tap:build-response#1, but we 
    expect the response to include a generic error message.
   :)
  declare %unit:test function txqt:build-response-400() {
    let $response := tap:build-response(400)
    let $msg := $response[2]/normalize-space()
    return (
        unit:assert-equals($response[1]//@status/xs:string(.), '400'),
        unit:assert-equals(count($response), 2),
        unit:assert(contains($msg, 'Error:'), "Message does not contain 'Error:' — "||$msg)
      )
  };
  
  (:~
    Ensure that tap:get-file-content() can retrieve a valid UTF-8 XML document when it has been 
    serialized as a string, a node, or a binary file.
   :)
  declare %unit:test function txqt:get-valid-utf-8-xml() {
    (: UTF-8 test inputs, plus $txqt:test-doc :)
    let $xmlAsString := unparsed-text($txqt:test-doc-path)
    let $xmlAsBin64 := bin:encode-string($xmlAsString)
    let $inputSeq := 
      ( $txqt:test-doc, $xmlAsString, $xmlAsBin64 )
    return 
      if ( count($inputSeq) ne 3 ) then
        unit:fail("Could not load one or more test inputs")
      else
        for $testInput at $i in $inputSeq
        let $fileOut := tap:get-file-content($testInput)
        let $type :=
          switch ($i)
            case 1 return "node"
            case 2 return "string"
            case 3 return "base64Binary"
            default return unit:fail("Too many test inputs")
        return
          unit:assert(not($fileOut instance of element(tap:err)), 
            "Can't process UTF-8 XML as "||$type||" — "||normalize-space($fileOut))
  };
  
  (:~
    Ensure that tap:get-file-content() can retrieve a valid, UTF-16 XML document when it has been 
    serialized as a string, a node, or a binary file.
   :)
  declare %unit:test %unit:ignore("Skipping for now") function txqt:get-valid-utf-16-xml() {
    (: UTF-16 test inputs :)
    let $utf16XmlPath := '../resources/testdocs/utf16.xml'
    let $utf16XmlDoc := doc($utf16XmlPath)
    let $utf16XmlAsString := unparsed-text($utf16XmlPath, 'utf-16')
    let $utf16XmlAsBin64 := bin:encode-string($utf16XmlAsString, 'utf-16')
    let $inputSeq := 
      ( $utf16XmlDoc, $utf16XmlAsString, $utf16XmlAsBin64 )
    return 
      if ( count($inputSeq) ne 3 ) then
        unit:fail("Could not load one or more test inputs")
      else
        for $testInput at $i in $inputSeq
        let $fileOut := tap:get-file-content($testInput)
        let $type :=
          switch ($i)
            case 1 return "node"
            case 2 return "string"
            case 3 return "base64Binary"
            default return unit:fail("Too many test inputs")
        return
          unit:assert(not($fileOut instance of element(tap:err)), 
            "Can't process UTF-16 XML as "||$type||" — "||normalize-space($fileOut))
  };
  
  (:~
    A fully-valid TEI document (with no JS) should yield 0 invalidity messages.
   :)
  declare %unit:test function txqt:validate-tei() {
    let $doc := doc('../resources/testdocs/sampleTEI.xml')
    let $invalidityReport := tap:validate-tei-minimally($doc)
    return unit:assert(empty($invalidityReport),
      count($invalidityReport)||" invalidities found, expected 0")
  };
  
  (:~
    Well-formed XML with no similarity to TEI should be flagged as invalid TEI.
   :)
  declare %unit:test function txqt:report-invalid-tei() {
    let $doc := doc('../resources/testdocs/invalidTEI.xml')
    let $invalidityReport := tap:validate-tei-minimally($doc)
    (: There should be two errors returned for this document:
        1. outermost element is not a TEI element
        2. outermost element is not 'TEI'
     :)
    let $hasTwoExpectedErrors :=
      count($invalidityReport[. instance of element(tap:err)]
                             [starts-with(lower-case(.), 'outermost element')]) eq 2
    return (
        unit:assert(exists($invalidityReport)),
        unit:assert(count($invalidityReport) eq 2, 
          count($invalidityReport)||" invalidities found, expected 2"),
        unit:assert($hasTwoExpectedErrors,
          "The validation report does not report the 2 expected errors")
      )
  };
  
  (:~
    Ensure tap:plan-response() can recover from an empty <tap:err> element with an HTTP status code on 
    it, and build a cautionary HTTP response with a generic message.
   :)
  declare %unit:test function txqt:identify-error-from-http-code() {
    let $possibleErrors := ( 
        <p>Content</p>,
        <tap:err code="500"/>
      )
    let $plannedResponse := tap:plan-response(200, $possibleErrors)
    return (
        unit:assert(tap:is-expected-response($plannedResponse, 500)),
        unit:assert(contains($plannedResponse[2], "unable to access resource"), 
          "Expected error message to contain 'unable to access resource', got '"
          ||normalize-space($plannedResponse[2]||"'"))
      )
  };
  
  (:~
    Ensure tap:plan-response() can recover from an empty <tap:err> element, and build a cautionary HTTP 
    response with a generic message.
   :)
  declare %unit:test function txqt:identify-error-though-unknown() {
    let $possibleErrors := ( 
        <p>Content</p>,
        <tap:err/>
      )
    let $plannedResponse := tap:plan-response(200, $possibleErrors)
    return (
        unit:assert(tap:is-expected-response($plannedResponse, 400)),
        unit:assert(contains($plannedResponse[2], "Unknown error raised"), 
          "Expected 'Unknown error raised', got '"||normalize-space($plannedResponse[2]||"'"))
      )
  };
  
  (:~
    Ensure tap:plan-response() can identify TAPAS errors in a sequence of items, and build a cautionary 
    HTTP response.
   :)
  declare %unit:test function txqt:identify-errors-in-response() {
    let $possibleErrors := ( 
        <p>Content</p>,
        <tap:err>Oops!</tap:err>,
        <tap:err code="401">There was an error here!</tap:err>
      )
    let $plannedResponse := tap:plan-response(200, $possibleErrors)
    return (
        unit:assert(tap:is-expected-response($plannedResponse, 401)),
        unit:assert(count($plannedResponse[2]//xhtml:li) eq 2,
          count($plannedResponse[2]//xhtml:li)||" errors reported, expected 2")
      )
  };
  
  (:~
    Ensure tap:plan-response() can create a successful response when no TAPAS errors are present.
   :)
  declare %unit:test function txqt:identify-no-errors-in-response() {
    let $responseBody := <p>Content</p>
    let $possibleErrors := ( $responseBody )
    (: Test that tap:plan-response#3 returns the expected 200 response, with the provided message. :)
    let $plannedResponse := tap:plan-response(200, $possibleErrors, $responseBody)
    return (
        unit:assert(tap:is-expected-response($plannedResponse, 200)),
        unit:assert-equals($plannedResponse[2]/normalize-space(), 'Content'),
        (: Also test tap:plan-response#2, which creates the generic "OK" message if no response body is 
          available. :)
        unit:assert-equals(tap:plan-response(200, $possibleErrors)[2]/normalize-space(), 'OK')
      )
  };
  
(:
    SUPPORT FUNCTIONS
 :)
  
  
