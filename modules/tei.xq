xquery version "3.0";

import module namespace tapasxq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace map="http://www.w3.org/2005/xpath-functions/map";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(: Variables corresponding to the expected request structure. :)
declare variable $method := "PUT";
declare variable $parameters := map {
                                  "doc-id" : 'xs:string'
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 201;
declare variable $contentType := "application/xml";

let $statusCode := tapasxq:test-request($method, $parameters, $successCode) 
let $responseBody :=  if ( $statusCode = $successCode ) then
                        let $doc-id := tapasxq:get-param-xml('doc-id')
                        let $teiXML := tapasxq:get-body-xml()
                        let $is-stored := xmldb:store("/db/tapas-data/{$doc-id}","{$doc-id}.xml",$teiXML)
                        return 
                            if ( empty($is-stored) ) then
                              500
                            else $is-stored
                      else $testStatus
return tapasxq:build-response($testStatus, $contentType, $responseBody)
