xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(:~
 : `DELETE exist/db/apps/tapas-xq/:doc-id` 
 : Delete document and derivatives.
 : 
 : Completely removes any files in the eXist collection associated with a 
 : proj-id. Returns a short confirmation that the resources have been deleted. 
 : If no collection is associated with the given proj-id, the response will 
 : have a status code of 500.
 : 
 : <ul>
 :  <lh>Request Expectations</lh>
 :  <li>Method: DELETE</li>
 :  <ul>
 :    <lh>Parameters</lh>
 :    <li>proj-id: The unique identifier of the project to be deleted.</li>
 :  </ul>
 : </ul>
 :
 : @return XML
 : 
 : @author Ashley M. Clark
 : @version 1.0
:)

(: Variables corresponding to the expected request structure. :)
declare variable $method := "DELETE";
declare variable $parameters := map {
                                  "proj-id" : 'xs:string'
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 200;
declare variable $contentType := "application/xml";

let $projID := txq:get-param('proj-id')
let $estimateCode := if ( $projID eq '' or $projID eq '/' ) then
                        500
                      else
                        txq:test-request($method, $parameters, $successCode)
let $responseBody :=  if ( $estimateCode = $successCode ) then
                        let $delDir := concat("/db/tapas-data/",$projID)
                        return
                          if ( xmldb:collection-available($delDir) ) then
                            let $delete := xmldb:remove($delDir)
                            return 
                                (: xmldb:remove() does not return anything helpful, 
                                 : so check to make sure the collection is gone. :)
                                if ( not(xmldb:collection-available($delDir)) ) then
                                  <p>Deleted project collection at {$delDir}.</p>
                                else 500
                          else 500
                      else tgen:get-error($estimateCode)
return txq:build-response($estimateCode, $contentType, $responseBody)
