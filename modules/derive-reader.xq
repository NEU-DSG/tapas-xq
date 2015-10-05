xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace transform="http://exist-db.org/xquery/transform";

(:~
 : `POST exist/apps/tapas-xq/derive-reader/:type` 
 : Derive XHTML (reading interface) production files from a TEI document.
 : 
 : Returns XHTML generated from the TEI document with status code 200. eXist 
 : does not store any files as a result of this request.
 : 
 : <ul>
 :  <lh>Request Expectations</lh>
 :  <li>Method: POST</li>
 :  <li>Content-Type: multipart/form-data</li>
 :  <ul>
 :    <lh>Parameters</lh>
 :    <li>type: A keyword representing the type of reader view to generate. 
 : Values can be "teibp" or "tapas-generic".</li>
 :    <li>assets-base: A file path representing the path to the parent 
 : directory of the CSS/JS/image assets associated with the requested Reader 
 : type.</li>
 :    <li>file: A TEI-encoded XML document.</li>
 :  </ul>
 : </ul>
 :
 : @return XHTML
 : 
 : @author Ashley M. Clark
 : @version 1.0
:)

(: Variables corresponding to the expected request structure. :)
declare variable $method := "POST";
declare variable $parameters := map {
                                  "type" : 'xs:string',
                                  "assets-base" : 'xs:string',
                                  "file" : 'node()'
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 200;
declare variable $contentType := "text/html";

let $reqEstimate := txq:test-request($method, $parameters, $successCode) 
let $estimateCode := $reqEstimate[1]
let $responseBody :=  if ( $estimateCode = $successCode ) then
                        let $teiXML := txq:get-param-xml('file')
                        let $XSLparams := <parameters>
                                            <param name="filePrefix" value="{txq:get-param('assets-base')}"/>
                                          </parameters>
                        let $xhtml := (: Apply the appropriate Reader transform. :)
                                      if ( txq:get-param('type') eq 'teibp' ) then 
                                        transform:transform($teiXML, doc("../resources/teibp/teibp.xsl"), $XSLparams)
                                      else if ( txq:get-param('type') eq 'tapas-generic' ) then
                                        (: The tapas-generic Reader is generated 
                                         : with two stylesheets, so their 
                                         : transforms are chained here. :)
                                        transform:transform(
                                          transform:transform($teiXML, doc("../resources/tapas-generic/tei2html_1.xsl"), $XSLparams), 
                                          doc("../resources/tapas-generic/tei2html_2.xsl"), ())
                                      (: If the $type keyword doesn't match the 
                                       : expected values, return an error. :)
                                      else (400, "':type' must have a value of 'teibp' or 'tapas-generic'")
                        return $xhtml
                      else if ( $reqEstimate instance of item()* ) then
                        tgen:set-error($reqEstimate[2])
                      else tgen:get-error($estimateCode)
return 
  if ( $responseBody[2] ) then txq:build-response($responseBody[1], $contentType, $responseBody[2])
  else txq:build-response($estimateCode, $contentType, $responseBody)
