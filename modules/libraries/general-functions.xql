xquery version "3.0";

module namespace tapas-xq="http://tapasproject.org/tapas-xq/general";

declare function tapas-xq:get-error($code as xs:integer) {
  switch ($code)
    case 400 return <p>Error: bad request</p>
    case 401 return <p>Error: authentication failed</p>
    case 405 return <p>Error: unsupported HTTP method</p>
    case 500 return <p>Error: unable to access resource</p>
    default return <p>Error</p>
};