xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace transform="http://exist-db.org/xquery/transform";

(:~
 : `POST exist/apps/tapas-xq/derive-mods` 
 : Derive MODS production file from a TEI document.
 : 
 : Returns an XML-encoded file of the MODS record with status code 200. eXist 
 : does not store any files as a result of this request.
 : 
 : <ul>
 :  <lh>Request Expectations</lh>
 :  <li>Method: POST</li>
 :  <li>Content-Type: application/xml</li>
 :  <li>Request body must be a TEI-encoded XML document.</li>
 : </ul>
 :
 : @return XML
 : 
 : @author Ashley M. Clark
 : @version 1.0
:)

(: Variables corresponding to the expected request structure. :)
declare variable $method := "POST";
declare variable $parameters := map {};
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 200;
declare variable $contentType := "application/xml";

let $estimateCode := txq:test-request($method, $parameters, $successCode) 
let $responseBody :=  if ( $estimateCode = $successCode ) then
                        let $teiXML := txq:get-body-xml()
                        let $mods := transform:transform($teiXML, doc("../resources/TAPAS2MODSminimal.xsl"), ())
                        return $mods
                      else tgen:get-error($estimateCode)
return txq:build-response($estimateCode, $contentType, $responseBody)
