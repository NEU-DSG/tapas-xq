xquery version "3.0";

(:~
 : Library for generic XQuery functions.
 : 
 : @author Ashley M. Clark
 : @version 1.0
 :
 : 2017-01-30: Added function to get a configuration file for a view package.
 : 2015-10-05: Added set-error().
:)

module namespace tapas-xq="http://tapasproject.org/tapas-xq/general";
declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";


(: VARIABLES :)

declare variable $tapas-xq:pkgDir := '/db/tapas-view-pkgs/';


(: FUNCTIONS :)

(:   ERROR MESSAGES   :)

(: Given an HTTP error code, return some human-readable text. :)
declare function tapas-xq:get-error($code as xs:integer) {
  switch ($code)
    case 400 return <p>Error: bad request</p>
    case 401 return <p>Error: authentication failed</p>
    case 405 return <p>Error: unsupported HTTP method</p>
    case 500 return <p>Error: unable to access resource</p>
    case 501 return <p>Error: functionality not implemented</p>
    default  return <p>Error</p>
};

(: Ensure that error messages are formatted in XML. :)
declare function tapas-xq:set-error($content) {
  typeswitch ($content)
    case xs:string return <p>{$content}</p>
    case node() return $content
    default return $content
};

(:   VIEW PACKAGES   :)

(: Get the configuration file for a specified view package. :)
declare function tapas-xq:get-config-file($pkgID as xs:string) as node()? {
  let $path := tapas-xq:get-pkg-filepath($pkgID,'PKG-CONFIG.xml')
  return doc($path)/vpkg:view_package
};

(: Expand a relative filepath using a view package's home directory. :)
declare function tapas-xq:get-pkg-filepath($pkgID as xs:string, $relPath as xs:string) as xs:string {
  let $mungedPath := replace($relPath, '^/', '')
  return concat(tapas-xq:get-package-home($pkgID), $mungedPath)
};

(: Get the full path to a view pacakge's home directory. :)
declare function tapas-xq:get-package-home($pkgID as xs:string) as xs:string {
  concat($tapas-xq:pkgDir,$pkgID,'/')
};

(: Get the <run> element from the configuration file. :)
declare function tapas-xq:get-run-stmt($pkgID as xs:string) as node()? {
  let $config := tapas-xq:get-config-file($pkgID)
  return $config/vpkg:run
};

(: Get the configurations from all known view packages. :)
  (: XD: it turns out this use of collection() is eXist-specific. It outputs all 
    files in descendant collections. Saxon will not do the same. :)
(:declare function tapas-xq:get-view-packages() as item()* {
  collection($tapas-xq:pkgDir)[contains(base-uri(), 'CONFIG.xml')]/vpkg:view_package
};:)
