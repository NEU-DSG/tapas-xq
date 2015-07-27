xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

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

let $estimateCode := txq:test-request($method, $parameters, $successCode) 
let $responseBody :=  if ( $estimateCode = $successCode ) then
                        let $docID := txq:get-param('doc-id')
                        let $tfe := <tapas:metadata xmlns:tapas="http://www.wheatoncollege.edu/TAPAS/1.0">
                                      <tapas:owners>
                                        <tapas:project>{ txq:get-param('proj-id') }</tapas:project>
                                        <tapas:document>{ $docID }</tapas:document>
                                        <tapas:collections>{ txq:get-param('collections') }</tapas:collections>
                                      </tapas:owners>
                                      <tapas:access>{ txq:get-param('is-public') }</tapas:access>
                                    </tapas:metadata>
                        let $isStored := xmldb:store(concat("/db/tapas-data/",$docID),"/tfe.xml",$tfe)
                        return 
                            if ( empty($isStored) ) then
                              500
                            else $isStored
                      else $estimateCode
return txq:build-response($estimateCode, $contentType, $responseBody)
