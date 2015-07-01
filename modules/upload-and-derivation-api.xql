xquery version "3.0";

module namespace tapasxq="http://tapasproject.org/tapas-xq";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace transform="http://exist-db.org/xquery/transform";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";

declare function tapasxq:get-file-content($file) {
  typeswitch($file)
    (: Replace any instances of U+FEFF that might make eXist consider the XML 
      "invalid." :)
    case xs:string return replace($file,'﻿','')
    case xs:base64Binary return tapasxq:get-file-content(util:binary-to-string($file))
    default return <error>Unrecognized file type.</error>
};

declare function tapasxq:data-collection-exists() as xs:boolean {
  xmldb:collection-available('/db/data')
};

declare function tapasxq:logout() {
  xmldb:login('/db','guest','guest'),
  session:invalidate()
};

declare function tapasxq:test-request($method-type as xs:string, $params as item()*) as xs:integer {
  (: Test HTTP method. :)
  if (request:get-method() eq $method-type) then
    (: Attempt to log in the user. :)
    if (xmldb:login('/db','admin','dsgT@pas')) then
      200
    (: Return an error if login fails. :)
    else 401
  (: Return an error for any unsupported HTTP methods. :)
  else 405
};

declare function tapasxq:get-error($code as xs:integer) {
  switch ($code)
    case 401 return <p>Error: authentication failed</p>
    case 405 return <p>Error: unsupported HTTP method</p>
    case 500 return <p>Error: unable to access resource</p>
    default return <p>Error</p>
};

declare function tapasxq:build-response($code as xs:integer, $content-type as xs:string, $content as item()) {
  (
    response:set-status-code($code),
    response:set-header("Content-Type", $content-type),
    $content
  )
};