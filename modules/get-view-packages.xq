xquery version "3.0";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs" at "libraries/view-pkgs.xql";
import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

(:~
 : `GET exist/apps/tapas-xq/view-packages` 
 : Obtain registry of installed view packages.
 : 
 : Returns status code 200.
 : 
 : <ul>
 :  <lh>Request Expectations</lh>
 :  <li>Method: GET</li>
 : </ul>
 :
 : @return XML
 : 
 : @author Ashley M. Clark
 : @version 1.0
:)

(: Variables corresponding to the expected request structure. :)
declare variable $method := "GET";
declare variable $parameters := map {};
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 200;
declare variable $contentType := "application/xml";

let $reqEstimate := txq:test-request($method, $parameters, $successCode) 
let $estimateCode := $reqEstimate[1]
let $responseBody :=  if ( $estimateCode = $successCode ) then
                        (: Return an error if the registry doesn't exist. :)
                        if ( doc-available($dpkg:registry) ) then
                          doc($dpkg:registry)
                        else ( 500, tgen:get-error(500) )
                      else if ( $reqEstimate instance of item()* ) then
                        tgen:set-error($reqEstimate[2])
                      else tgen:get-error($estimateCode)
return 
  if ( $responseBody[2] ) then 
    txq:build-response($responseBody[1], $contentType, $responseBody[2])
  else txq:build-response($estimateCode, $contentType, $responseBody)
