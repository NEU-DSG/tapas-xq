xquery version "3.0";

import module namespace tapasxq="http://tapasproject.org/tapas-xq" at "upload-and-derivation-api.xql";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";

(: Variables corresponding to the expected request structure. :)
declare variable $method := "POST";
declare variable $parameters := (); (:( <param name="" type=""/> ):)

(: Variables corresponding to the expected response structure. :)
declare variable $contentType := "application/xml";

let $statusCode := tapasxq:test-request($method, $parameters) 
let $responseBody :=  if ( $statusCode = 201 ) then
                        let $teiXML := parse-xml( request:get-data() )
                        let $mods := transform:transform($teiXML, doc("../resources/TAPAS2MODSminimal.xsl"), ())
                        return $mods
                      else tapasxq:get-error($statusCode)
return tapasxq:build-response($statusCode, $contentType, $responseBody)
