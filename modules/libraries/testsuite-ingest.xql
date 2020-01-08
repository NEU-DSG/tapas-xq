xquery version "3.0";

module namespace txqt="http://tapasproject.org/tapas-xq/testsuite";
import module namespace test="http://exist-db.org/xquery/xqsuite" 
  at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace http="http://expath.org/ns/http-client";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mods="http://www.loc.gov/mods/v3";

(:~
  @author Ashley M. Clark
  @version 1.0
 :)

(:declare variable $txqt:host := "http://localhost:8080/exist/apps/tapas-xq";:)
declare variable $txqt:exreq := doc('../../resources/testdocs/exhttpSkeleton.xml');
declare variable $txqt:host := $txqt:exreq//@href;
declare variable $txqt:testDoc := doc('../../resources/testdocs/sampleTEI.xml');

(:  FUNCTIONS  :)

  declare
    %test:setUp
  function txqt:_test-setup() {
    sm:create-account('tapas-tester', 'freesample', 'tapas')
  };
  
  declare
    %test:tearDown
  function txqt:_test-teardown() {
    sm:remove-account('tapas-tester'),
    sm:remove-group('tapas-tester')
  };
  
  declare 
    %test:assertExists
  function txqt:testdoc() {
    $txqt:testDoc
  };
  
  declare
    %test:name("Derive MODS")
    %test:args('GET','false')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '405'")
    %test:args('POST','false')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '400'")
    %test:args('POST','true')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '200'")
      %test:assertXPath("namespace-uri($result[2]/*) eq 'http://www.loc.gov/mods/v3'")
  function txqt:derive-mods($method as xs:string, $file as xs:string) {
    let $reqURL := xs:anyURI(concat($txqt:host,"/derive-mods"))
    let $parts :=
      if ( $file eq 'true' ) then
        txqt:set-http-multipart("xml", (
          txqt:set-http-header("Content-Disposition",'form-data; name="file"'),
          txqt:set-http-body("application/xml","xml",$txqt:testDoc)
        ))
      else ()
    let $request := txqt:set-http-request($method, $reqURL, $parts)
    return http:send-request($request)
  };
  
  
  (:  SUPPORT FUNCTIONS  :)
  
  declare %private function txqt:set-http-body($media-type as xs:string, $method as 
     xs:string, $content as item()*) as element() {
    <http:body media-type="{$media-type}" method="{$method}">
      { $content }
    </http:body>
  };
  
  declare %private function txqt:set-http-header($name as xs:string, $value as 
     xs:string) {
    <http:header name="{$name}" value='{$value}' />
  };
  
  declare %private function txqt:set-http-multipart($multipart-subtype as xs:string, 
     $partSeq as item()*) as element() {
    <http:multipart media-type="multipart/{$multipart-subtype}" 
       boundary="xyzBOUNDSAWAYzyx">
      { for $i in $partSeq return $i }
    </http:multipart>
  };
  
  declare %private function txqt:set-http-request($method as xs:string, $href as 
     xs:anyURI, $partSeq as item()*) as element() {
    <http:request>
      {
        $txqt:exreq/http:request/@* except $txqt:exreq/http:request/@href, 
        attribute username { "tapas-tester" },
        attribute password { "freesample" },
        attribute method { $method }, 
        attribute href { xs:anyURI(concat($txqt:host,"/derive-mods")) }, 
        $txqt:exreq/http:request/*,
        $partSeq
      }
    </http:request>
    (:<http:request method="{$method}" href="{$href}" username="tapas-tester" password="freesample" auth-method="digest" send-authorization="true" http-version="1.0"> 
      {
        for $i in $partSeq
        return $i
      }
    </http:request>:)
  };
