xquery version "3.0";

(:~
 : Library for generic XQuery functions.
 : 
 : @author Ashley M. Clark
 : @version 1.0
 :
 : 2017-08-22: Added get-document().
 : 2017-02-14: Changed the prefix for this library from 'tapas-xq' to the 'tgen' 
 :   already used everywhere else.
 : 2017-01-30: Added function to get a configuration file for a view package.
 : 2015-10-05: Added set-error().
:)

module namespace tgen="http://tapasproject.org/tapas-xq/general";

declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";


(: VARIABLES :)

declare variable $tgen:pkgDir := '/db/tapas-view-pkgs/';
declare variable $tgen:dataDir := '/db/tapas-data/';


(: FUNCTIONS :)

(: Get a stored file using its project and document identifiers. :)
declare function tgen:get-document($proj-id as xs:string, $doc-id as xs:string) {
  let $path := concat($tgen:dataDir, $proj-id, '/', $doc-id)
  return
    if ( doc-available($path) ) then
      doc($path)
    else 400
};

(:   ERROR MESSAGES   :)

(: Given an HTTP error code, return some human-readable text. :)
declare function tgen:get-error($code as xs:integer) {
  switch ($code)
    case 400 return <p>Error: bad request</p>
    case 401 return <p>Error: authentication failed</p>
    case 405 return <p>Error: unsupported HTTP method</p>
    case 500 return <p>Error: unable to access resource</p>
    case 501 return <p>Error: functionality not implemented</p>
    default  return <p>Error</p>
};

(: Ensure that error messages are formatted in XML. :)
declare function tgen:set-error($content) {
  typeswitch ($content)
    case xs:string return <p>{$content}</p>
    case node() return $content
    default return $content
};
