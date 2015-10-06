xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(:~
 : `POST exist/apps/tapas-xq/:proj-id/:doc-id/mods` 
 : Derive MODS production file from a TEI document and store it in the database.
 : 
 : Returns an XML-encoded file of the MODS record with status code 201.
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
 :    <ul>
 :    <lh>Optional parameters</lh>
 :      <li>title: The title of the item as it appears on TAPAS.</li>
 :      <li>authors: A string with each author's name concatenated by a '|'.</li>
 :      <li>contributors: A string with each contributor's name concatenated by a '|'.</li>
 :      <li>timeline-date: The date corresponding to the item in the TAPAS 
 : timeline. xs:date format preferred. 
 : (see http://www.w3schools.com/schema/schema_dtypes_date.asp)</li>
 :    </ul>
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
                                      "proj-id" : "xs:string"
                                    };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 201;
declare variable $contentType := "application/xml";

let $projID := txq:get-param('proj-id')
let $docID := txq:get-param('doc-id')
let $docURI := concat("/db/tapas-data/",$projID,"/",$docID,"/",$docID,".xml")
let $reqEstimate := if ( $projID eq '' or not(doc-available($docURI)) ) then
                        (500, "TEI file must be available in database before MODS storage")
                      else
                        txq:test-request($method, $parameters, $successCode)
let $estimateCode := $reqEstimate[1]
let $responseBody :=  if ( $estimateCode = $successCode ) then
                        let $teiXML := doc($docURI)
                        let $title := txq:get-param('title')
                        let $authors := txq:get-param('authors')
                        let $contributors := txq:get-param('contributors')
                        let $date := txq:get-param('timeline-date')
                        let $XSLparams := <parameters>
                                            {
                                              if ( $title instance of xs:string ) then 
                                                <param name="displayTitle" value="{$title}"/>
                                              else (),
                                              if ( $authors instance of xs:string ) then
                                                <param name="displayAuthors" value="{$authors}"/>
                                              else (),
                                              if ( $contributors instance of xs:string ) then
                                                <param name="displayContributors" value="{$contributors}"/>
                                              else (),
                                              if ( $date instance of xs:string ) then
                                                <param name="timelineDate" value="{$date}"/>
                                              else ()
                                            }
                                          </parameters>
                        let $mods := transform:transform($teiXML, doc("../resources/tapas2mods.xsl"), $XSLparams)
                        let $isStored := xmldb:store(concat("/db/tapas-data/",$projID,"/",$docID),"mods.xml",$mods)
                        return 
                            if ( empty($isStored) ) then
                              (500, "The MODS file could not be stored; check user permissions")
                            else $mods
                      else if ( $reqEstimate instance of item()* ) then
                        tgen:set-error($reqEstimate[2])
                      else tgen:get-error($estimateCode)
return 
  if ( $responseBody[2] ) then txq:build-response($responseBody[1], $contentType, $responseBody[2])
  else txq:build-response($estimateCode, $contentType, $responseBody)