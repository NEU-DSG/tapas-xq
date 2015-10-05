xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(:~
 : `PUT exist/db/apps/tapas-xq/:proj-id/:doc-id/tei` 
 : Store TEI in eXist.
 : 
 : Returns path to the TEI file within the database, with status code 201.
 : 
 : <ul>
 :  <lh>Request Expectations</lh>
 :  <li>Method: POST</li>
 :  <li>Content-Type: multipart/form-data</li>
 :  <ul>
 :    <lh>Parameters</lh>
 :    <li>file: The TEI-encoded XML document to be stored.</li>
 :    <li>doc-id: A unique identifier for the document record attached to the 
 : original TEI document and its derivatives (MODS, TFE).</li>
 :    <li>proj-id: The unique identifier of the project which owns the work.</li>
 :  </ul>
 : </ul>
 :
 : @return XML
 : 
 : @author Ashley M. Clark
 : @version 1.0
:)

(: Variables corresponding to the expected request structure. :)
declare variable $method := "POST";
declare variable $parameters := map {
                                  "doc-id" : 'xs:string',
                                  "proj-id" : 'xs:string',
                                  "file" : 'node()'
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 201;
declare variable $contentType := "application/xml";

let $reqEstimate := txq:test-request($method, $parameters, $successCode)
let $estimateCode := $reqEstimate[1]
let $responseBody :=  if ( $estimateCode = $successCode ) then
                        let $projID := txq:get-param('proj-id')
                        let $docID := txq:get-param('doc-id')
                        let $teiXML := txq:get-param-xml('file')
                        let $dataPath := concat("/db/tapas-data/",$projID,"/",$docID)
                        (: Create the project/document directory if this is not just
                         : a replacement version of the TEI, but a new resource. :)
                        let $projDir := if (not(xmldb:collection-available(concat("/db/tapas-data/",$projID)))) then
                                          xmldb:create-collection("/db/tapas-data/",$projID)
                                        else ()
                        let $docDir :=  if (not(xmldb:collection-available($dataPath))) then
                                          xmldb:create-collection(concat("/db/tapas-data/",$projID),$docID)
                                        else ()
                        (: xmldb:store() returns the path to the new resource, 
                         : or, on failure, an empty sequence. :)
                        let $isStored := xmldb:store($dataPath,concat($docID,".xml"),$teiXML)
                        return 
                            if ( empty($isStored) ) then
                              (500, "The TEI file could not be stored; check user permissions")
                            else <p>{$isStored}</p>
                      else if ( $reqEstimate instance of item()* ) then
                        tgen:set-error($reqEstimate[2])
                      else tgen:get-error($estimateCode)
return 
  if ( $responseBody[2] ) then txq:build-response($responseBody[1], $contentType, $responseBody[2])
  else txq:build-response($estimateCode, $contentType, $responseBody)
