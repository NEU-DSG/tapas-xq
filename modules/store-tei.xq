xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(:~
 : `PUT exist/db/apps/tapas-xq/:doc-id/tei` 
 : Store TEI in eXist.
 : 
 : Returns path to the TEI file within the database, with status code 201.
 : 
 : <ul>
 :  <lh>Request Expectations</lh>
 :  <li>Method: PUT</li>
 :  <li>Content-Type: application/xml</li>
 :  <ul>
 :    <lh>Parameters</lh>
 :    <li>doc-id: A unique identifier for the document record attached to the 
 : original TEI document and its derivatives (MODS, TFE).</li>
 :  </ul>
 : </ul>
 :
 : @return XML
 : 
 : @author Ashley M. Clark
 : @version 1.0
:)

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
                        (: Create the document directory if this is not just a
                         : replacement version of the TEI, but a new resource. :)
                        let $docDir :=  if (not(xmldb:collection-available($dataPath))) then
                                          xmldb:create-collection("/db/tapas-data/",$docID)
                                        else ()
                        (: xmldb:store() returns the path to the new resource, 
                         : or, on failure, an empty sequence. :)
                        let $isStored := xmldb:store($dataPath,concat($docID,".xml"),$teiXML)
                        return 
                            if ( empty($isStored) ) then
                              500
                            else <p>{$isStored}</p>
                      else $estimateCode
return txq:build-response($estimateCode, $contentType, $responseBody)
