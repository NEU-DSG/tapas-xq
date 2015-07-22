xquery version "3.0";

module namespace tapas-exist="http://tapasproject.org/tapas-xq/exist";
import module namespace tgen="http://tapasproject.org/tapas-xq/general" at "general-functions.xql";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace transform="http://exist-db.org/xquery/transform";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";

declare function tapas-exist:get-param($paramName as xs:string) {
  if ($paramName) then
    request:get-parameter($paramName, 400)
  else ()
};

declare function tapas-exist:get-param-xml($paramName as xs:string) {
  let $value := tapas-exist:get-param($paramName)
  return parse-xml( tapas-exist:get-file-content($value) )
};

declare function tapas-exist:get-body-xml() {
  request:get-data()
};

declare function tapas-exist:get-file-content($file) {
  typeswitch($file)
    (: Replace any instances of U+FEFF that might make eXist consider the XML 
      "invalid." :)
    case xs:string return replace($file,'^﻿','')
    case xs:base64Binary return tapas-exist:get-file-content(util:binary-to-string($file))
    default return 400
};

(: xd: Check the type of each parameter value. :)
declare function tapas-exist:test-request($method-type as xs:string, $params as item()*, $success-code) as xs:integer {
  (: Test HTTP method. :)
  if (request:get-method() eq $method-type) then
    (: Attempt to log in the user. :)
    if (xmldb:login('/db','admin','dsgT@pas')) then (: xd: Authenticate with given username/password. :)
      $success-code
    (: Return an error if login fails. :)
    else 401
  (: Return an error for any unsupported HTTP methods. :)
  else 405
};

declare function tapas-exist:build-response($code as xs:integer, $content-type as xs:string, $content as item()) {
  let $isError := $content instance of xs:integer
  let $returnCode :=  if ($isError) then
                        tgen:get-error($content)
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

declare function tapas-exist:logout() {
  xmldb:login('/db','guest','guest'),
  session:invalidate()
};