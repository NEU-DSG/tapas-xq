xquery version "3.0";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";

import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs" at "libraries/view-pkgs.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";
import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";

(:~
 : `POST exist/apps/tapas-xq/view-packages/update` 
 : Update the view packages stored in eXist, and the registry of those packages.
 : 
 : Returns status code 200.
 : 
 : <ul>
 :  <lh>Request Expectations</lh>
 :  <li>Method: POST</li>
 :  <li>Content-Type: multipart/form-data</li>
 : </ul>
 :
 : @return XHTML
 : 
 : @author Ashley M. Clark
 : @version 1.0
 :)

(:  VARIABLES  :)

(: Declaring the serialization method to be XHTML keeps tags from self-closing. :)
declare option output:method "xhtml";

(: Variables corresponding to the expected request structure. :)
declare variable $method := "POST";
declare variable $parameters := map {};
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 200;
declare variable $contentType := "text/html";


(:  MAIN QUERY  :)

let $reqEstimate := txq:test-request($method, $parameters, $successCode)
let $estimateCode := 
  (: Test if the current user has write access to the view package directory. Return 
    a 401 status code if they can't. :)
  if ( dpkg:has-write-access() ) then
    $reqEstimate[1]
  else 401
let $responseBody := 
  if ( $estimateCode = $successCode ) then
    let $update := dpkg:update-packages()
    return
      typeswitch ($update)
        case xs:string return $update
        default return ''
  else if ( $estimateCode eq 401 ) then
    tgen:set-error("User does not have write access to the view packages directory")
  else if ( $reqEstimate instance of item()* ) then
    tgen:set-error($reqEstimate[2])
  else tgen:get-error($estimateCode)
return
  txq:build-response($estimateCode, $contentType, $responseBody)
