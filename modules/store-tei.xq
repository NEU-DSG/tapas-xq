xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(: Variables corresponding to the expected request structure. :)
declare variable $method := "PUT";
declare variable $parameters := map {
                                  "doc-id" : 'xs:string'
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 201;
declare variable $contentType := "application/xml";

let $statusCode := txq:test-request($method, $parameters, $successCode) 
let $responseBody :=  if ( $statusCode = $successCode ) then
                        let $doc-id := txq:get-param-xml('doc-id')
                        let $teiXML := txq:get-body-xml()
                        let $isStored := xmldb:store("/db/tapas-data/{$doc-id}","{$doc-id}.xml",$teiXML)
                        return 
                            if ( empty($isStored) ) then
                              500
                            else $isStored
                      else $testStatus
return txq:build-response($testStatus, $contentType, $responseBody)
