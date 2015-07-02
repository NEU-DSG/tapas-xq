xquery version "3.0";

import module namespace tapasxq="http://tapasproject.org/tapas-xq/exist" at "upload-and-derivation-api.xql";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";

(: Variables corresponding to the expected request structure. :)
declare variable $method := "PUT";
declare variable $parameters := map {
                                  "doc-id" := xs:string
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $contentType := "application/xml";

let $statusCode := tapasxq:test-request($method, $parameters) 
let $responseBody :=  if ( $statusCode = 200 ) then
                        let $teiXML := tapasxq:get-param-xml('file')
                        let $e := xmldb:store("/db/tapas-data","test.xml",$tfc)
                        return $mods
                      else tapasxq:get-error($statusCode)
return tapasxq:build-response($statusCode, $contentType, $responseBody)
