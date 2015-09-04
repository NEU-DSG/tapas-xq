xquery version "3.0";

(:~
 : Library for generic XQuery functions.
 : 
 : @author Ashley M. Clark
 : @version 1.0
:)

module namespace tapas-xq="http://tapasproject.org/tapas-xq/general";

(: Given an HTTP error code, return some human-readable text. :)
declare function tapas-xq:get-error($code as xs:integer) {
  switch ($code)
    case 400 return <p>Error: bad request</p>
    case 401 return <p>Error: authentication failed</p>
    case 405 return <p>Error: unsupported HTTP method</p>
    case 500 return <p>Error: unable to access resource</p>
    default return <p>Error</p>
};
