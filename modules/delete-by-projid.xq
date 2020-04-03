xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(:~
 : `DELETE exist/apps/tapas-xq/:doc-id` 
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
let $reqEstimate := if ( $projID eq '' or $projID eq '/' ) then
                      (400, "Parameter 'proj-id' must be present for project deletion")
                    else
                      txq:test-request($method, $parameters, $successCode)
let $estimateCode := $reqEstimate[1]
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
                                else (500, concat("Project collection '",$delDir,
                                  "' could not be deleted; check user permissions"))
                          else (500, concat("Project collection '",$delDir,"' does not exist"))
                      else if ( count($reqEstimate) eq 2 ) then
                        $reqEstimate
                      else tgen:get-error($estimateCode)
return 
  if ( count($responseBody) eq 2 ) then
    txq:build-response($responseBody[1], $contentType, tgen:set-error($responseBody[2]))
  else txq:build-response($estimateCode, $contentType, $responseBody)
