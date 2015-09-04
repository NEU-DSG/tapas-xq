xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";
declare namespace tapas="http://www.wheatoncollege.edu/TAPAS/1.0";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(:~
 : `POST exist/db/apps/tapas-xq/:doc-id/tfe` 
 : Store 'TAPAS-friendly-eXist' metadata in eXist.
 : 
 : Triggers the generation of a small XML file containing useful information 
 : about the context of the TEI document, such as its parent project. Returns 
 : path to the TFE file within the database, with status code 201. If no TEI 
 : document is associated with the given doc-id, the response will have a 
 : status code of 500. The TEI file must be stored before any of its 
 : derivatives.
 : 
 : <ul>
 :  <lh>Request Expectations</lh>
 :  <li>Method: POST</li>
 :  <li>Content-Type: multipart/form-data</li>
 :  <ul>
 :    <lh>Parameters</lh>
 :    <li>doc-id: A unique identifier for the document record attached to the 
 : original TEI document and its derivatives (MODS, TFE).</li>
 :    <li>proj-id: The unique identifier of the project which owns the work.</li>
 :    <li>collections: Comma-separated list of collection identifiers with 
 : which the work should be associated.</li>
 :    <li>is-public: Value of "true" or "false". Indicates if the XML document 
 : should be queryable by the public. Default value is false. (Note that if the 
 : document belongs to even one public collection, it should be queryable.)</li>
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
                                  "doc-id" : "xs:string",
                                  "proj-id" : "xs:string",
                                  "collections" : "xs:string",
                                  "is-public" : "xs:boolean"
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 201;
declare variable $contentType := "application/xml";

let $estimateCode := txq:test-request($method, $parameters, $successCode) 
let $responseBody :=  if ( $estimateCode = $successCode ) then
                        let $docID := txq:get-param('doc-id')
                        let $collections := <tapas:collections>{ 
                                              for $n in tokenize(txq:get-param('collections'),',')
                                              return <tapas:collection>{ $n }</tapas:collection>
                                            }</tapas:collections>
                        let $tfe := <tapas:metadata xmlns:tapas="http://www.wheatoncollege.edu/TAPAS/1.0">
                                      <tapas:owners>
                                        <tapas:project>{ txq:get-param('proj-id') }</tapas:project>
                                        <tapas:document>{ $docID }</tapas:document>
                                        { $collections }
                                      </tapas:owners>
                                      <tapas:access>{ txq:get-param('is-public') }</tapas:access>
                                    </tapas:metadata>
                        (: xmldb:store() returns the path to the new resource, 
                         : or, on failure, an empty sequence. :)
                        let $isStored := xmldb:store(concat("/db/tapas-data/",$docID),"/tfe.xml",$tfe)
                        return 
                            if ( empty($isStored) ) then
                              500
                            else <p>{$isStored}</p>
                      else $estimateCode
return txq:build-response($estimateCode, $contentType, $responseBody)
