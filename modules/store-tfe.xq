xquery version "3.0";

import module namespace tapasxq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace map="http://www.w3.org/2005/xpath-functions/map";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(: Variables corresponding to the expected request structure. :)
declare variable $method := "POST";
declare variable $parameters := map {
                                  "doc-id" : "xs:string",
                                  "proj-id" : "xs:string",
                                  "collections" : "xs:string",
                                  "is-public" : "xs:boolean"
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 201;
declare variable $contentType := "application/xml";

let $statusCode := tapasxq:test-request($method, $parameters, $successCode) 
let $responseBody :=  if ( $statusCode = $successCode ) then
                        let $tfe := <tapas:metadata xmlns:tapas="http://www.wheatoncollege.edu/TAPAS/1.0">
                                      <tapas:owners>
                                        <tapas:project>{ tapasxq:get-param-xml('proj-id') }</tapas:project>
                                        <tapas:document>{ tapasxq:get-param-xml('doc-id') }</tapas:document>
                                        <tapas:collections>{ tapasxq:get-param-xml('collections') }</tapas:collections>
                                      </tapas:owners>
                                      <tapas:access>{ tapasxq:get-param-xml('is-public') }</tapas:access>
                                    </tapas:metadata>
                        let $isStored := xmldb:store("/db/tapas-data/{$doc-id}","tfe.xml",$tfe)
                        return 
                            if ( empty($isStored) ) then
                              500
                            else $isStored
                      else $testStatus
return tapasxq:build-response($testStatus, $contentType, $responseBody)
