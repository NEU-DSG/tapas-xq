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

let $estimateCode := txq:test-request($method, $parameters, $successCode) 
let $responseBody :=  if ( $estimateCode = $successCode ) then
                        let $docID := txq:get-param('doc-id')
                        let $teiXML := txq:get-body-xml()
                        let $dataPath := concat("/db/tapas-data/",$docID)
                        let $docDir :=  if (not(xmldb:collection-available($dataPath))) then
                                          xmldb:create-collection("/db/tapas-data/",$docID)
                                        else ()
                        let $isStored := xmldb:store($dataPath,concat($docID,".xml"),$teiXML)
                        return 
                            if ( empty($isStored) ) then
                              500
                            else <p>{$isStored}</p>
                      else $estimateCode
return txq:build-response($estimateCode, $contentType, $responseBody)
