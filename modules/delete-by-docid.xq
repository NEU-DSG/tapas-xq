xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(: Variables corresponding to the expected request structure. :)
declare variable $method := "DELETE";
declare variable $parameters := map {
                                  "doc-id" : "xs:string"
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 200;
declare variable $contentType := "application/xml";

let $estimateCode := txq:test-request($method, $parameters, $successCode) 
let $docID := txq:get-param('doc-id')
let $delDir := concat("/db/tapas-data/",$docID)
let $responseBody :=  if ( xmldb:collection-available($delDir) ) then
                        let $delete := xmldb:remove($delDir)
                        return 
                            if ( not(xmldb:collection-available($delDir)) ) then
                              <p>Deleted document collection at {$delDir}.</p>
                            else 500
                      else 400
return txq:build-response($estimateCode, $contentType, $responseBody)
