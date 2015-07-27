xquery version "3.0";

module namespace txq="http://tapasproject.org/tapas-xq/exist";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "general-functions.xql";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace transform="http://exist-db.org/xquery/transform";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace functx="http://www.functx.com";
import module namespace map="http://www.w3.org/2005/xpath-functions/map";

declare function txq:get-param($param-name as xs:string) {
  request:get-parameter($param-name, 400)
};

declare function txq:get-param-xml($param-name as xs:string) {
  let $value := txq:get-param($param-name)
  return parse-xml( txq:get-file-content($value) )
};

declare function txq:get-body-xml() {
  request:get-data()
};

declare function txq:get-file-content($file) {
  typeswitch($file)
    (: Replace any instances of U+FEFF that might make eXist consider the XML 
      "invalid." :)
    case xs:string return replace($file,'^﻿','')
    case xs:base64Binary return txq:get-file-content(util:binary-to-string($file))
    default return 400
};

declare function txq:test-request($method-type as xs:string, $params as map, $success-code as xs:integer) as xs:integer {
  let $requestParams := map:for-each-entry( $params, 
                                            function($param-name as xs:string, $param-type as xs:string) as xs:boolean {
                                              let $paramVal :=  if ( $param-type eq 'item()' ) then
                                                                  txq:get-param-xml($param-name)
                                                                else if ( $param-type eq 'xs:boolean' ) then
                                                                  txq:get-param($param-name) castable as xs:boolean
                                                                else txq:get-param($param-name)
                                              let $valType :=   if ( $paramVal instance of xs:integer ) then
                                                                  400
                                                                else functx:atomic-type($paramVal) 
                                              return $valType eq $param-type
                                            })
  return
    (: Test HTTP method. :)
    if ( request:get-method() eq $method-type ) then
      (: If one of the parameters does not match the expected type, return a 400 code. :)
      if ( not(functx:is-value-in-sequence(false(), $requestParams)) ) then
        (: xd: If the request includes the appropriate key, log in that user. :)
          (: If the current user has access to the 'tapas-data' folder, then return a success code. :)
          if ( sm:has-access(xs:anyURI('/db/tapas-data'),'rwx') ) then
            $success-code
          (: Return an error if login fails. :)
          else 401
      else 
        400
    (: Return an error for any unsupported HTTP methods. :)
    else 405
};

declare function txq:build-response($code as xs:integer, $content-type as xs:string, $content as item()) {
  let $isError := $content instance of xs:integer
  let $returnCode :=  if ($isError) then
                        $content
                      else $code
  return
      (
        response:set-status-code($returnCode),
        response:set-header("Content-Type", $content-type),
        if ($isError) then
          tgen:get-error($content)
        else $content
      )
};

declare function txq:logout() {
  xmldb:login('/db','guest','guest'),
  session:invalidate()
};