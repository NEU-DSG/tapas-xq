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

  declare variable $txqt:exreq := doc('../../resources/testdocs/exhttpSkeleton.xml');
  declare variable $txqt:host := $txqt:exreq//@href;
  declare variable $txqt:testFile := doc('../../resources/testdocs/sampleTEI.xml');
  declare variable $txqt:testData := 
    map {
        'formData': (
            txqt:set-http-header("Content-Disposition",' form-data; name="file"'),
            txqt:set-http-body("application/xml", "xml", $txqt:testFile)
          ),
        'docId': 'testDoc01',
        'projId': 'testProj01'
      };
  declare variable $txqt:user :=
    map {
        'name': 'tapas-tester',
        'password': 'freesample'
      };
  declare variable $txqt:endpoint :=
    map {
        'derive-mods': xs:anyURI(concat($txqt:host,"/derive-mods")),
        'derive-reader': xs:anyURI(concat($txqt:host,"/derive-reader")),
        'store-tei': xs:anyURI(concat($txqt:host,'/',$txqt:testData?('projId'),'/',
          $txqt:testData?('docId'),"/tei")),
        'store-mods': xs:anyURI(concat($txqt:host,'/',$txqt:testData?('projId'),'/',
          $txqt:testData?('docId'),"/mods")),
        'store-tfe': xs:anyURI(concat($txqt:host,'/',$txqt:testData?('projId'),'/',
          $txqt:testData?('docId'),"/tfe")),
        'delete-project': xs:anyURI(concat($txqt:host,'/',$txqt:testData?('projId'))),
        'delete-document': xs:anyURI(concat($txqt:host,'/',$txqt:testData?('projId'),'/',
          $txqt:testData?('docId')))
      };


(:  FUNCTIONS  :)

  declare
    %test:setUp
  function txqt:_test-setup() {
    sm:create-account($txqt:user?('name'), $txqt:user?('password'), 'tapas', ())
    ,
    let $dbPath := "/db/tapas-data/"
    let $dbProjPath := 
      xmldb:create-collection($dbPath, $txqt:testData?('projId'))
    let $dbDocPath := 
      xmldb:create-collection($dbProjPath, $txqt:testData?('docId'))
    let $fileName := concat($txqt:testData?('docId'),'.xml')
    return (
      xmldb:store($dbDocPath, $fileName, $txqt:testFile),
      sm:chmod($dbDocPath, 'rwxrwxr-x')
      )
  };
  
  declare
    %test:tearDown
  function txqt:_test-teardown() {
    sm:remove-account($txqt:user?('name'))
    ,
    xmldb:remove(concat("/db/tapas-data/",$txqt:testData?('projId')))
  };
  
  declare
    %test:name("Authentication checks")
    %test:args('derive-mods', 'tapas-tester', 'wrongpassword')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '401'")
  function txqt:authenticate($endpointKey as xs:string, $user as xs:string, 
     $password as xs:string) {
    let $function :=
      switch ($endpointKey)
        case 'derive-mods' return
          txqt:request-mods-derivative#4
        default return ()
    let $method :=
      switch ($endpointKey)
        case 'delete-project' return 'DELETE'
        case 'delete-document' return 'DELETE'
        default return 'POST'
    let $request :=
      if ( empty($function) ) then ()
      else
        $function($user, $password, $method, <default/>)
    return
      http:send-request($request)
  };
  
  declare
    %test:name("Derive MODS")
    %test:args('GET', 'false')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '405'")
    %test:args('POST', 'false')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '400'")
    %test:args('POST', 'true')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '200'")
      %test:assertXPath("count($result) eq 2")
      %test:assertXPath("not($result[2]//*[namespace-uri(.) ne 'http://www.loc.gov/mods/v3'])")
  function txqt:derive-mods($method as xs:string, $file as xs:string) {
    txqt:derive-mods($method, $file, (), (), ())
  };
  
  declare
    %test:name("Derive MODS: optional parameters")
    %test:args('POST', 'true', 'A Test Title', 'Sarah Sweeney|A.M. Clark|Syd Bauman', 'A. Duck')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '200'")
      %test:assertXPath("count($result) eq 2")
      %test:assertXPath("not($result[2]//*[namespace-uri(.) ne 'http://www.loc.gov/mods/v3'])")
      %test:assertXPath("exists($result[2]//*:titleInfo[@displayLabel eq 'TAPAS Title']/*:title[. eq 'Test Title'])")
      %test:assertXPath("exists($result[2]//*:name[@displayLabel eq 'TAPAS Author']/*:namePart[. eq 'A.M. Clark'])")
      %test:assertXPath("exists($result[2]//*:name[@displayLabel eq 'TAPAS Contributor']/*:namePart[. eq 'A. Duck'])")
  function txqt:derive-mods($method as xs:string, $file as xs:string, $title as 
     xs:string?, $authors as xs:string?, $contributors as xs:string?) {
    let $reqParts :=
      txqt:set-mods-formdata($file, $title, $authors, $contributors)
    let $request := 
      txqt:request-mods-derivative($txqt:user?('name'), $txqt:user?('password'), 
        $method, $reqParts)
    return http:send-request($request)
  };
  
  declare
    %test:name("Store TEI: replace document")
    %test:args('PUT', 'false')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '405'")
    %test:args('POST', 'false')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '400'")
    %test:args('POST', 'true')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '200'")
      %test:assertXPath("count($result) eq 2")
  function txqt:store-tei($method as xs:string, $file as xs:string) {
    let $reqParts :=
      txqt:set-http-multipart('xml', $txqt:testData?('formData'))
    let $request :=
      txqt:request-tei-storage($txqt:user?('name'), $txqt:user?('password'), $method, 
        $reqParts)
    return http:send-request($request)
  };
  
  declare
    %test:name("Store TEI: new document")
    %test:args('POST', 'true', 'testDoc02')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '200'")
      %test:assertXPath("count($result) eq 2")
  function txqt:store-tei($method as xs:string, $file as xs:string, $docId as 
     xs:string) {
    let $multipart :=
      txqt:set-http-multipart('xml', $txqt:testData?('formData'))
    let $baseUrl := $txqt:endpoint?('store-tei')
    let $customUrl := txqt:edit-document-url($baseUrl, (), $docId)
    let $request :=
      txqt:set-http-request($txqt:user?('name'), $txqt:user?('password'), $method, 
        $customUrl, $multipart)
    return http:send-request($request)
  };
  
  declare
    %test:name("Store MODS")
    %test:args('GET', 'false')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '405'")
    %test:args('POST', 'false')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '400'")
    %test:args('POST', 'true')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '200'")
      %test:assertXPath("count($result) eq 2")
      %test:assertXPath("not($result[2]//*[namespace-uri(.) ne 'http://www.loc.gov/mods/v3'])")
  function txqt:store-mods($method as xs:string, $file as xs:string) {
    txqt:store-mods($method, $file, (), (), ())
  };
  
  declare
    %test:name("Store MODS: dependency checks")
    %test:args('POST', 'true', 'nonexistentProj', 'nonexistentDoc')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '500'")
    %test:args('POST', 'true', 'testProj01', 'nonexistentDoc')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '500'")
  function txqt:store-mods($method as xs:string, $file as xs:string, $projId 
     as xs:string, $docId as xs:string) {
    let $reqParts := txqt:set-mods-formdata($file, (), (), ())
    let $baseUrl := $txqt:endpoint?('store-mods')
    let $customUrl := txqt:edit-document-url($baseUrl, $projId, $docId)
    let $request :=
      txqt:request-mods-generic($customUrl, $txqt:user?('name'), 
        $txqt:user?('password'), $method, $reqParts)
    return http:send-request($request)
  };
  
  declare
    %test:name("Store MODS: optional parameters")
    %test:args('POST', 'true', 'A Test Title', 'Sarah Sweeney|A.M. Clark|Syd Bauman', 'A. Duck')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '201'")
      %test:assertXPath("count($result) eq 2")
      %test:assertXPath("not($result[2]//*[namespace-uri(.) ne 'http://www.loc.gov/mods/v3'])")
      %test:assertXPath("exists($result[2]//*:titleInfo[@displayLabel eq 'TAPAS Title']/*:title[. eq 'Test Title'])")
      %test:assertXPath("exists($result[2]//*:name[@displayLabel eq 'TAPAS Author']/*:namePart[. eq 'A.M. Clark'])")
      %test:assertXPath("exists($result[2]//*:name[@displayLabel eq 'TAPAS Contributor']/*:namePart[. eq 'A. Duck'])")
   function txqt:store-mods($method as xs:string, $file as xs:string, $title as 
     xs:string?, $authors as xs:string?, $contributors as xs:string?) {
    let $reqParts :=
      txqt:set-mods-formdata($file, $title, $authors, $contributors)
    let $request :=
      txqt:request-mods-storage($txqt:user?('name'), $txqt:user?('password'), 
        $method, $reqParts)
    return http:send-request($request)
  };
  
  
  (:  SUPPORT FUNCTIONS  :)
  
  declare %private function txqt:edit-document-url($endpoint as xs:anyURI, $projId 
     as xs:string?, $docId as xs:string?) as xs:anyURI {
    let $editProjId := 
      if ( empty($projId) ) then $endpoint
      else
        replace($endpoint, $txqt:testData?('projId'), $projId)
    let $editDocId := 
      if ( empty($docId) ) then $editProjId
      else replace($editProjId, $txqt:testData?('docId'), $docId)
    return xs:anyURI($editDocId)
  };
  
  declare %private function txqt:get-file($key as xs:string) {
    if ( $key eq 'true' ) then
      $txqt:testData?('formData')
    else ()
  };
  
  declare function txqt:request-mods-derivative($user as xs:string, $password as 
     xs:string, $method as xs:string, $parts as node()*) {
    txqt:request-mods-generic($txqt:endpoint?('derive-mods'), $user, $password, 
      $method, $parts)
  };
  
  declare function txqt:request-mods-generic($endpoint as xs:anyURI, $user as 
     xs:string, $password as xs:string, $method as xs:string, $parts as node()*) 
     as node() {
    let $multipart :=
      if ( empty($parts) ) then ()
      else if ( $parts[self::default] ) then
        txqt:set-http-multipart('xml', $txqt:testData?('formData'))
      else
        txqt:set-http-multipart('form-data', $parts)
    return
      txqt:set-http-request($user, $password, $method, $endpoint, $multipart)
  };
  
  declare function txqt:request-mods-storage($user as xs:string, $password as 
     xs:string, $method as xs:string, $parts as node()*) {
    txqt:request-mods-generic($txqt:endpoint?('store-mods'), $user, $password, 
      $method, $parts)
  };
  
  declare function txqt:request-tei-storage($user as xs:string, $password as 
     xs:string, $method as xs:string, $parts as node()*) {
    let $body :=
      if ( $parts[self::default] ) then
        txqt:get-file('true')
      else $parts
    return
      txqt:set-http-request($user, $password, $method, $txqt:endpoint?('store-tei'), 
        $parts)
  };
  
  declare %private function txqt:set-http-body($media-type as xs:string, $method as 
     xs:string, $content as item()*) as element() {
    <http:body media-type="{$media-type}" method="{$method}">
      { $content }
    </http:body>
  };
  
  declare %private function txqt:set-http-header($name as xs:string, $value as 
     xs:string) as element() {
    <http:header name="{$name}" value="{$value}" />
  };
  
  declare %private function txqt:set-http-multipart($multipart-subtype as xs:string, 
     $partSeq as item()*) as element() {
    <http:multipart media-type="multipart/{$multipart-subtype}" 
       boundary="xyzBOUNDSAWAYzyx">
      { for $i in $partSeq return $i }
    </http:multipart>
  };
  
  declare %private function txqt:set-http-request($user as xs:string, $password as 
     xs:string, $method as xs:string, $href as xs:anyURI, $partSeq as item()*) 
     as element() {
    <http:request>
      {
        $txqt:exreq/http:request/@* except $txqt:exreq/http:request/@href, 
        attribute username { $user },
        attribute password { $password },
        attribute method { $method },
        attribute href { $href },
        $partSeq
      }
    </http:request>
  };
  
  declare function txqt:set-mods-formdata($file as xs:string, $title as xs:string?, 
     $authors as xs:string?, $contributors as xs:string?) as node()* {
    let $optParams :=
      map {
          'title': $title,
          'authors': $authors,
          'contributors': $contributors
        }
    let $fileField := txqt:get-file($file)
    let $optFields :=
      for $paramName in ('title', 'authors', 'contributors')
      let $header :=
        txqt:set-http-header("Content-Disposition", 
          concat(' form-data; name="',$paramName,'"'))
      let $body := txqt:set-http-body("text/text", "text", $optParams?($paramName))
      return
        if ( empty($optParams?($paramName)) ) then ()
        else ($header, $body)
    return ($fileField, $optFields)
  };
