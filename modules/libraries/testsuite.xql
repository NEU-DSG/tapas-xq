xquery version "3.0";

  module namespace txqt="http://tapasproject.org/tapas-xq/testsuite";
  import module namespace test="http://exist-db.org/xquery/xqsuite" 
    at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
  import module namespace http="http://expath.org/ns/http-client";
  
  declare namespace tei="http://www.tei-c.org/ns/1.0";
  declare namespace mods="http://www.loc.gov/mods/v3";

(:~
  A suite of tests for the TAPAS-xq API.
  
  NOTES
    eXist v2.2:     The test runner will not run, because setup cannot occur.
    eXist v.3.6.1:  22 failures due to a bug when libraries try to run 
                    authentication tests.
  
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
        'projId': 'testProj01',
        'collections': "testing,public-collection",
        'isPublic': 'true',
        'defaultPkg': 'tapas-generic',
        'assetsBase': '/exist/rest/db/view-packages'
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
    let $dbPath := "/db/tapas-data/"
    let $dbProjPath := 
      xmldb:create-collection($dbPath, $txqt:testData?('projId'))
    let $dbDocPath := 
      xmldb:create-collection($dbProjPath, $txqt:testData?('docId'))
    let $fileName := concat($txqt:testData?('docId'),'.xml')
    let $dbMods := (
        xmldb:store($dbDocPath, $fileName, $txqt:testFile)
      )
    return (
        $dbMods,
        session:invalidate()
      )
  };
  
  (:declare
    %test:tearDown
  function txqt:_test-teardown() {
    xmldb:remove(concat("/db/tapas-data/",$txqt:testData?('projId')))
  };:)
  
  declare
    %test:name("Authentication checks")
    %test:args('delete-document', 'faker', 'faker')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '401'")
    %test:args('delete-project', 'faker', 'faker')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '401'")
    %test:args('derive-mods', 'faker', 'faker')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '401'")
    %test:args('derive-reader', 'faker', 'faker')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '401'")
    %test:args('store-tei', 'faker', 'faker')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '401'")
    %test:args('store-mods', 'faker', 'faker')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '401'")
    %test:args('store-tfe', 'faker', 'faker')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '401'")
  function txqt:authenticate($endpointKey as xs:string, $user as xs:string, 
     $password as xs:string) {
    let $function :=
      switch ($endpointKey)
        case 'delete-document' return
          txqt:request-doc-deletion#4
        case 'delete-project' return
          txqt:request-project-deletion#4
        case 'derive-mods' return
          txqt:request-mods-derivative#4
        case 'derive-reader' return
          txqt:request-xhtml-derivative#4
        case 'store-tei' return
          txqt:request-tei-storage#4
        case 'store-mods' return
          txqt:request-mods-storage#4
        case 'store-tfe' return
          txqt:request-tfe-storage#4
        default return ()
    let $method :=
      switch ($endpointKey)
        case 'delete-project' return 'DELETE'
        case 'delete-document' return 'DELETE'
        default return 'POST'
    return
      if ( empty($function) ) then
        <p>There is no defined authentication test for endpoint 
          "{$endpointKey}"!</p>
      else
        let $request := $function($user, $password, $method, <default/>)
        return http:send-request($request)
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
    %test:name("Derive XHTML")
    %test:args('GET', 'false', 'tapas-generic', '/exist/rest/db/view-packages/')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '405'")
    %test:args('POST', 'false', 'tapas-generic', '')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '400'")
    %test:args('POST', 'true', 'fakeViewPackage', '/exist/rest/db/view-packages/')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '400'")
  function txqt:derive-reader($method as xs:string, $file as xs:string, $type as 
     xs:string, $assets-base as xs:string) {
    let $endpoint := concat($txqt:endpoint?('derive-reader'),'/',$type)
    let $allowFormParams := $method eq 'POST'
    let $useUrl :=
      let $urlParams :=
        if ( $assets-base ne '' ) then 
          concat('assets-base=', $assets-base)
        else ''
      return
        if ( $allowFormParams ) then $endpoint
        else concat($endpoint,'?', $urlParams)
    let $multipart :=
      if ( $allowFormParams ) then
        let $parts := (
          if ( $file eq 'false' ) then ()
          else $txqt:testData?('formData')
          ,
          if ( $assets-base eq '' ) then ()
          else (
            txqt:set-http-header("Content-Disposition",' form-data; name="assets-base"'),
            txqt:set-http-body("text/text", "text", $assets-base)
          )
        )
        return 
          if ( $parts ) then
            txqt:set-http-multipart('form-data', $parts)
          else ()
      else ()
    let $request :=
      txqt:request-xhtml-derivative(xs:anyURI($useUrl), $txqt:user?('name'), 
        $txqt:user?('password'), $method, $multipart)
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
      %test:assertXPath("$result[1]/@status eq '201'")
      %test:assertXPath("count($result) eq 2")
      %test:assertXPath("doc-available('/db/tapas-data/testProj01/testDoc01/testDoc01.xml')")
  function txqt:store-tei($method as xs:string, $file as xs:string) {
    let $reqParts :=
      if ( $file eq 'true' ) then
        txqt:set-http-multipart('xml', $txqt:testData?('formData'))
      else ()
    let $request :=
      txqt:request-tei-storage($txqt:user?('name'), $txqt:user?('password'), $method, 
        $reqParts)
    return http:send-request($request)
  };
  
  declare
    %test:name("Store TEI: new document")
    %test:args('POST', 'true', 'testDoc02')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '201'")
      %test:assertXPath("count($result) eq 2")
      %test:assertXPath("doc-available('/db/tapas-data/testProj01/testDoc02/testDoc02.xml')")
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
    %test:args('GET')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '405'")
    %test:args('POST')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '201'")
      %test:assertXPath("count($result) eq 2")
      %test:assertXPath("not($result[2]//*[namespace-uri(.) ne 'http://www.loc.gov/mods/v3'])")
  function txqt:store-mods($method as xs:string) {
    txqt:store-mods($method, 'false', (), (), ())
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
    return
      http:send-request($request)
  };
  
  declare
    %test:name("Store TFE")
    %test:args('GET', 'testProj01', 'testDoc01')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '405'")
    %test:args('POST', 'nonexistentProj', 'nonexistentDoc')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '500'")
    %test:args('POST', 'testProj01', 'nonexistentDoc')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '500'")
    %test:args('POST', 'testProj01', 'testDoc01')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '201'")
      %test:assertXPath("count($result) eq 2")
      %test:assertXPath("doc-available($result[2]//p/text())")
      %test:assertXPath("not(doc($result[2]//p/text())//*[namespace-uri(.) ne 'http://www.wheatoncollege.edu/TAPAS/1.0'])")
      %test:assertXPath("exists(doc($result[2]//p/text())//*:project[. eq 'testProj01'])")
      %test:assertXPath("exists(doc($result[2]//p/text())//*:document[. eq 'testDoc01'])")
      %test:assertXPath("exists(doc($result[2]//p/text())//*:collection[. eq 'testing'])")
      %test:assertXPath("exists(doc($result[2]//p/text())//*:collection[. eq 'public-collection'])")
      %test:assertXPath("exists(doc($result[2]//p/text())//*:access[. eq 'true'])")
  function txqt:store-tfe($method as xs:string, $projId as xs:string, $docId as 
     xs:string) {
    let $allowParams := $method eq 'POST'
    let $collections :=
      if ( $allowParams ) then $txqt:testData?('collections') else ()
    let $isPublic :=
      if ( $allowParams ) then $txqt:testData?('isPublic') else ()
    return
      txqt:store-tfe($method, $projId, $docId, $collections, $isPublic)
  };
  
  declare
    %test:name("Store TFE: required parameters")
    %test:args('POST', 'testProj01', 'testDoc01', '', '')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '400'")
      %test:assertXPath("count($result) eq 2")
      %test:assertXPath("$result[2]//li[contains(.,'collections')]/contains(., 'must be present')")
      %test:assertXPath("$result[2]//li[contains(.,'is-public')]/contains(., 'must be present')")
    %test:args('POST', 'testProj01', 'testDoc01', 'testing', 'notboolean')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '400'")
      %test:assertXPath("count($result) eq 2")
      %test:assertXPath("$result[2]//li[contains(.,'is-public')]/contains(., 'must be of type xs:boolean')")
  function txqt:store-tfe($method as xs:string, $projId as xs:string, $docId as 
     xs:string, $collections as xs:string?, $isPublic as xs:string?) {
    let $baseUrl := $txqt:endpoint?('store-tfe')
    let $customUrl := txqt:edit-document-url($baseUrl, $projId, $docId)
    let $reqCollections :=
      if ( empty($collections) or $collections eq '' ) then ()
      else (
          txqt:set-http-header("Content-Disposition",' form-data; name="collections"'),
          txqt:set-http-body("text/text", "text", $collections)
        )
    let $reqPublicFlag :=
      if ( empty($isPublic) or $isPublic eq '' ) then ()
      else (
          txqt:set-http-header("Content-Disposition",' form-data; name="is-public"'),
          txqt:set-http-body("text/text", "text", $isPublic)
        )
    let $request :=
      txqt:request-tfe-storage($customUrl, $txqt:user?('name'), 
        $txqt:user?('password'), $method, ($reqCollections, $reqPublicFlag))
    return
      http:send-request($request)
  };
  
  declare
    %test:name("Delete document folder")
    %test:args('DELETE', 'testProj02', 'testDoc03')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '500'")
    %test:args('DELETE', 'testProj01', 'testDoc02')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '200'")
      %test:assertXPath("not(doc-available('/db/tapas-data/testProj01/testDoc02/testDoc02.xml'))")
      %test:assertXPath("not(xmldb:collection-available('/db/tapas-data/testProj01/testDoc02'))")
  function txqt:terminate($method as xs:string, $projId as xs:string, $docId as 
     xs:string) {
    let $endpoint := txqt:edit-document-url($txqt:endpoint?('delete-document'), $projId, $docId)
    let $request :=
      txqt:request-doc-deletion($endpoint, $txqt:user?('name'), $txqt:user?('password'), $method,
        ())
    return
      http:send-request($request)
  };
  
  declare
    %test:name("Delete project folder")
    %test:args('DELETE', 'testProj02')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '500'")
    %test:args('DELETE', 'testProj01')
      %test:assertExists
      %test:assertXPath("$result[1]/@status eq '200'")
      %test:assertXPath("not(doc-available('/db/tapas-data/testProj01/testDoc01/testDoc01.xml'))")
      %test:assertXPath("not(xmldb:collection-available('/db/tapas-data/testProj01'))")
  function txqt:terminate-project($method as xs:string, $projId as xs:string) {
    let $endpoint :=
      txqt:edit-document-url($txqt:endpoint?('delete-project'), $projId, ())
    let $request :=
      txqt:request-project-deletion($endpoint, $txqt:user?('name'), 
        $txqt:user?('password'), $method, ())
    return
      http:send-request($request)
  };
  
  
  (:  SUPPORT FUNCTIONS  :)
  
  (:~
    Given an endpoint URL, customize it for a different project and/or document.
   :)
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
  
  (:~
    If $key is 'true', return the form data body for sending the default test file 
    in the HTTP request.
   :)
  declare %private function txqt:get-file($key as xs:string) {
    if ( $key eq 'true' ) then
      $txqt:testData?('formData')
    else ()
  };
  
  (:~
    Create an HTTP request for deleting a TEI document and its derivatives. This 
    version assumes that the project and document identifiers are the default ones.
   :)
  declare function txqt:request-doc-deletion($user as xs:string, $password as 
     xs:string, $method as xs:string, $parts as node()*) {
    txqt:request-doc-deletion($txqt:endpoint?('delete-document'), $user, $password, 
      $method, $parts)
  };
  
  (:~
    Create an HTTP request for deleting a TEI document and its derivatives. This 
    version can receive a customized URL.
   :)
  declare function txqt:request-doc-deletion($endpoint as xs:anyURI, $user as 
     xs:string, $password as xs:string, $method as xs:string, $parts as node()*) {
    let $body :=
      if ( $parts[self::default] ) then ()
      else $parts
    return
      txqt:set-http-request($user, $password, $method, $endpoint, $body)
  };
  
  (:~
    Create an HTTP request for deriving MODS metadata from a given TEI file.
   :)
  declare function txqt:request-mods-derivative($user as xs:string, $password as 
     xs:string, $method as xs:string, $parts as node()*) {
    txqt:request-mods-generic($txqt:endpoint?('derive-mods'), $user, $password, 
      $method, $parts)
  };
  
  (:~
    Create an HTTP request for obtaining MODS from a TEI file. This is a generic 
    function that can be used for either the "derive" or "store" endpoints.
   :)
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
  
  (:~
    Create an HTTP request for creating and storing MODS metadata from a 
    previously-stored TEI file.
   :)
  declare function txqt:request-mods-storage($user as xs:string, $password as 
     xs:string, $method as xs:string, $parts as node()*) {
    txqt:request-mods-generic($txqt:endpoint?('store-mods'), $user, $password, 
      $method, $parts)
  };
  
  (:~
    Create an HTTP request for deleting a project collection, and all files 
    within it. This version assumes that the project and document identifiers 
    are the default ones.
   :)
  declare function txqt:request-project-deletion($user as xs:string, $password as 
     xs:string, $method as xs:string, $parts as node()*) {
    let $body :=
      if ( $parts[self::default] ) then ()
      else $parts
    return
      txqt:request-project-deletion($txqt:endpoint?('delete-project'), $user, 
        $password, $method, $body)
  };
  
  (:~
    Create an HTTP request for deleting a project collection, and all files 
    within it. This version can receive a customized URL.
   :)
  declare function txqt:request-project-deletion($endpoint as xs:anyURI, $user as 
     xs:string, $password as xs:string, $method as xs:string, $parts as node()*) {
    let $body :=
      if ( $parts[self::default] ) then ()
      else $parts
    return
      txqt:set-http-request($user, $password, $method, $endpoint, $body)
  };
  
  (:~
    Create an HTTP request for storing a given TEI document.
   :)
  declare function txqt:request-tei-storage($user as xs:string, $password as 
     xs:string, $method as xs:string, $parts as node()*) {
    let $body :=
      if ( $parts[self::default] ) then
        txqt:set-http-multipart('xml', txqt:get-file('true'))
      else $parts
    return
      txqt:set-http-request($user, $password, $method, $txqt:endpoint?('store-tei'), 
        $body)
  };
  
  (:~
    Create an HTTP request for creating and storing a "TFE" file (TAPAS-specific
    metadata) for a previously-stored TEI file. This version assumes that the 
    project and document identifiers are the default ones.
   :)
  declare function txqt:request-tfe-storage($user as xs:string, $password as 
     xs:string, $method as xs:string, $parts as node()*) {
    txqt:request-tfe-storage($txqt:endpoint?('store-tfe'), $user, $password, 
      $method, $parts)
  };
  
  (:~
    Create an HTTP request for creating and storing a "TFE" file (TAPAS-specific
    metadata) for a previously-stored TEI file. This version can receive a 
    customized URL.
   :)
  declare function txqt:request-tfe-storage($endpoint as xs:anyURI, $user as 
     xs:string, $password as xs:string, $method as xs:string, $parts as node()*) {
    let $useParts :=
      if ( $parts[self::default] ) then (
          txqt:set-http-header("Content-Disposition",' form-data; name="is-public"'),
          txqt:set-http-body("text/text", "text", $txqt:testData?('isPublic')),
          txqt:set-http-header("Content-Disposition",' form-data; name="collections"'),
          txqt:set-http-body("text/text", "text", $txqt:testData?('collections'))
        )
      else $parts
    let $multipart :=
      if ( empty($useParts) ) then ()
      else
        txqt:set-http-multipart('form-data', $useParts)
    return
      txqt:set-http-request($user, $password, $method, $endpoint, $multipart)
  };
  
  (:~
    Create an HTTP request for deriving a given type of XHTML reader from a given 
    TEI file.
   :)
  declare %private function txqt:request-xhtml-derivative($user as xs:string, 
     $password as xs:string, $method as xs:string, $parts as node()*) {
    let $endpoint :=
      concat($txqt:endpoint?('derive-reader'),'/',$txqt:testData?('defaultPkg'))
    return
      txqt:request-xhtml-derivative(xs:anyURI($endpoint), $user, 
        $password, $method, $parts)
  };
  
  (:~
    Create an HTTP request for deriving a given type of XHTML reader from a given 
    TEI file. This version can receive a customized URL.
   :)
  declare %private function txqt:request-xhtml-derivative($endpoint as xs:anyURI, 
     $user as xs:string, $password as xs:string, $method as xs:string, $parts as 
     node()*) {
    let $useParts :=
      if ( $parts[self::default] ) then (
          txqt:set-http-header("Content-Disposition",' form-data; name="assets-base"'),
          txqt:set-http-body("text/text", "text", $txqt:testData?('assetsBase')),
          $txqt:testData?('formData')
        )
      else $parts
    let $multipart :=
      if ( empty($useParts) ) then ()
      else if ( $useParts[self::http:multipart] ) then $useParts
      else txqt:set-http-multipart('form-data', $useParts)
    return
      txqt:set-http-request($user, $password, $method, $endpoint, $multipart)
  };
  
  (:~
    Customize an <http:body> wrapper for an EXPath HTTP Client request.
   :)
  declare %private function txqt:set-http-body($media-type as xs:string, $method as 
     xs:string, $content as item()*) as element() {
    <http:body media-type="{$media-type}" method="{$method}">
      { $content }
    </http:body>
  };
  
  (:~
    Customize an <http:header> wrapper for an EXPath HTTP Client request.
   :)
  declare %private function txqt:set-http-header($name as xs:string, $value as 
     xs:string) as element() {
    <http:header name="{$name}" value="{$value}" />
  };
  
  (:~
    Customize an <http:multipart> wrapper for an EXPath HTTP Client request.
   :)
  declare %private function txqt:set-http-multipart($multipart-subtype as xs:string, 
     $partSeq as item()*) as element() {
    <http:multipart media-type="multipart/{$multipart-subtype}" 
       boundary="xyzBOUNDSAWAYzyx">
      { for $i in $partSeq return $i }
    </http:multipart>
  };
  
  (:~
    Customize an <http:request> wrapper for the EXPath HTTP Client.
   :)
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
  
  (:~
    Create form data for use when creating MODS. The form data simulates the fields 
    required by TAPAS: TAPAS author(s), TAPAS contributor(s), and TAPAS title.
   :)
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
