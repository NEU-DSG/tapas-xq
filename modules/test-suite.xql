xquery version "3.1";

  module namespace txqt="http://tapasproject.org/tapas-xq/testsuite";
(:  LIBRARIES  :)
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
  declare variable $txqt:test-doc := doc('../resources/testdocs/sampleTEI.xml');


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
