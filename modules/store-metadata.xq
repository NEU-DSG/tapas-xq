xquery version "3.0";

import module namespace tapasxq="http://tapasproject.org/tapas-xq/exist" at "libraries/tapas-exist.xql";
import module namespace map="http://www.w3.org/2005/xpath-functions/map";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(: Variables corresponding to the expected request structure. :)
declare variable $method := "POST";
declare variable $parameters := map {
                                  "doc-id" : "xs:string"
                                };
(: Variables corresponding to the expected response structure. :)
declare variable $successCode := 201;
declare variable $contentType := "application/xml";

let $statusCode := tapasxq:test-request($method, $parameters, $successCode) 
let $responseBody :=  if ( $statusCode = $successCode ) then
                        let $xslParams := <parameters>
                                            <param name="proj-id" value="{$reqXML/proj-id}"/>
                                            <param name="doc-id" value="{$reqXML/doc-id}"/>
                                            <param name="is-public" value="{$reqXML/is-public}"/>
                                            <param name="collections" value="test"/>
                                          </parameters> (: xd: Implement parameters from user input form. :)
                        let $mods := transform:transform(tapasxq:get-body-xml(), doc("../resources/TAPAS2MODSminimal.xsl"), $xslParams)
                        let $isStored := xmldb:store("/db/tapas-data/{tapasxq:get-param-xml('doc-id')}","mods.xml",$mods)
                        return 
                            if ( empty($isStored) ) then
                              500
                            else $isStored
                      else $testStatus
return tapasxq:build-response($testStatus, $contentType, $responseBody)
