xquery version "3.0";

import module namespace txq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "libraries/general-functions.xql";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(: Variables corresponding to the expected request structure. :)
declare variable $method := "POST";
declare variable $parameters := map {
                                  "doc-id" : "xs:string"
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 201;
declare variable $contentType := "application/xml";

let $statusCode := txq:test-request($method, $parameters, $successCode) 
let $responseBody :=  if ( $statusCode = $successCode ) then
                        let $docID := txq:get-param('doc-id')
                        let $xslParams := <parameters>
                                            <param name="proj-id" value="{$reqXML/proj-id}"/>
                                            <param name="doc-id" value="{$docID}"/>
                                            <param name="is-public" value="{$reqXML/is-public}"/>
                                            <param name="collections" value="test"/>
                                          </parameters> (: xd: Implement parameters from user input form. :)
                        let $mods := transform:transform(txq:get-body-xml(), doc("../resources/TAPAS2MODSminimal.xsl"), $xslParams)
                        let $isStored := xmldb:store("/db/tapas-data/{txq:get-param-xml('doc-id')}","mods.xml",$mods)
                        return 
                            if ( empty($isStored) ) then
                              500
                            else $isStored
                      else $statusCode
return txq:build-response($statusCode, $contentType, $responseBody)
