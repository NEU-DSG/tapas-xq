xquery version "3.0";

import module namespace tapasxq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";

import module namespace transform="http://exist-db.org/xquery/transform";

(: Variables corresponding to the expected request structure. :)
declare variable $method := "POST";
declare variable $parameters := ();
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 200;
declare variable $contentType := "application/xml";

let $statusCode := tapasxq:test-request($method, $parameters, $successCode) 
let $responseBody :=  if ( $statusCode = $successCode ) then
                        let $teiXML := tapasxq:get-body-xml()
                        let $mods := transform:transform($teiXML, doc("../resources/TAPAS2MODSminimal.xsl"), ())
                        return $mods
                      else tapasxq:get-error($statusCode)
return tapasxq:build-response($statusCode, $contentType, $responseBody)
