xquery version "3.0";

declare namespace tapas="http://tapasproject.org/tapas-xq/restxq";
import module namespace tapasxq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace rest="http://exquery.org/ns/restxq";
import module namespace map="http://www.w3.org/2005/xpath-functions/map";
(: xd: Abstract out database-dependent modules: :)
import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace transform="http://exist-db.org/xquery/transform";

declare %private function tapas:make-resp-header($status-code as xs:integer, $content-type as xs:string) {
  <rest:response>
    <http:response status="{$status-code}">
      <http:header name="Content-Language" value="en"/>
      <http:header name="Content-Type" value="{$content-type}"/>
    </http:response>
  </rest:response>
};

(:declare %private function tapas:make-resp-body($success-code as xs:integer, $content-type as xs:string) {
  let $isAuthenticated := tapasxq:test-request($success-code)
  return 
      if (  ) then
        
      else
};:)

declare
  %rest:POST("{$body}")
  %rest:path("/derive-mods")
  function tapas:derive-mods($body as xs:string) {
    let $successCode := 200
    let $statusCode := tapasxq:test-request($method, $parameters, $successCode)
    let $responseBody :=  if ( $statusCode = $successCode ) then
                            let $teiXML := parse-xml($body)
                            let $mods := transform:transform($teiXML, doc("../resources/TAPAS2MODSminimal.xsl"), ())
                            return $mods
                          else tapasxq:get-error($statusCode)
    return
        (
          tapas:make-resp-header($returnCode, 'application/xml'), (: xd: Need to get any new error code that may have appeared. :)
          $responseBody
        )
};

declare 
  %rest:POST
  %rest:path("/{$doc-id}/tei")
  function tapas:store-tei($doc-id as xs:string) {
    let $successCode := 201
    let $statusCode := tapasxq:test-request($method, $parameters, $successCode)
    return
        (
          tapas:make-resp-header($returnCode, 'application/text'),
          $responseBody
        )
};

declare
  %rest:POST
  %rest:path("/{$doc-id}/tfe")
  %rest:form-param("proj-id", "{$proj-id}")
  %rest:form-param("collections", "{$collections}")
  %rest:form-param("is-public", "{$is-public}")
  function tapas:store-tfe($doc-id as xs:string, $proj-id as xs:string, $collections as xs:string, $is-public as xs:boolean) {
    let $successCode := 201
    let $statusCode := tapasxq:test-request($method, $parameters, $successCode) 
    let $responseBody :=  if ( $statusCode = $successCode ) then
                            let $tfe := <tapas:metadata xmlns:tapas="http://www.wheatoncollege.edu/TAPAS/1.0">
                                          <tapas:owners>
                                            <tapas:project>{ $proj-id }</tapas:project>
                                            <tapas:document>{ $doc-id }</tapas:document>
                                            <tapas:collections>{ $collections }</tapas:collections>
                                          </tapas:owners>
                                          <tapas:access>{ $is-public }</tapas:access>
                                        </tapas:metadata>
                            let $isStored := xmldb:store("/db/tapas-data/{$doc-id}","tfe.xml",$tfe)
                            return 
                                if ( empty($isStored) ) then
                                  500
                                else $isStored
                          else $testStatus
    let $isError := $responseBody instance of xs:integer
    let $returnCode :=  if ($isError) then
                          tapasxq:get-error($content)
                        else $statusCode
    return
        ( 
          tapas:make-resp-header($returnCode, 'application/xml'),
          $responseBody
        )
};