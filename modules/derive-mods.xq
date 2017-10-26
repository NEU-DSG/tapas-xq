xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace transform="http://exist-db.org/xquery/transform";

(:~
 : `POST exist/apps/tapas-xq/derive-mods` 
 : Derive MODS production file from a TEI document.
 : 
 : Returns an XML-encoded file of the MODS record with status code 200. eXist 
 : does not store any files as a result of this request.
 : 
 : <ul>
 :  <lh>Request Expectations</lh>
 :  <li>Method: POST</li>
 :  <li>Content-Type: multipart/form-data</li>
 :  <ul>
 :    <lh>Parameters</lh>
 :    <li>file: The TEI-encoded XML document to be transformed.</li>
 :    <ul>
 :      <lh>Optional parameters</lh>
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
                                      "file" : 'node()'
                                    };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 200;
declare variable $contentType := "application/xml";

let $reqEstimate := txq:test-request($method, $parameters, $successCode) 
let $estimateCode := $reqEstimate[1]
let $responseBody :=  if ( $estimateCode = $successCode ) then
                        let $teiXML := txq:get-param-xml('file')
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
                        return $mods
                      else if ( $reqEstimate instance of item()* ) then
                        tgen:set-error($reqEstimate[2])
                      else tgen:get-error($estimateCode)
return txq:build-response($estimateCode, $contentType, $responseBody)
