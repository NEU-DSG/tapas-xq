xquery version "3.0";

(:~
 : Library for generic XQuery functions.
 : 
 : @author Ashley M. Clark
 : @version 1.0
 :
 : 2017-02-14: Changed the prefix for this library from 'tapas-xq' to the 'tgen' 
 :   already used everywhere else.
 : 2017-01-30: Added function to get a configuration file for a view package.
 : 2015-10-05: Added set-error().
:)

module namespace tgen="http://tapasproject.org/tapas-xq/general";
declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";


(: VARIABLES :)

declare variable $tgen:pkgDir := '/db/tapas-view-pkgs/';


(: FUNCTIONS :)

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

(:   VIEW PACKAGES   :)

(: Get the configuration file for a specified view package. :)
declare function tgen:get-config-file($pkgID as xs:string) as node()? {
  let $path := tgen:get-pkg-filepath($pkgID,'PKG-CONFIG.xml')
  return doc($path)/vpkg:view_package
};

(: Expand a relative filepath using a view package's home directory. :)
declare function tgen:get-pkg-filepath($pkgID as xs:string, $relPath as xs:string) as xs:string {
  let $mungedPath := replace($relPath, '^/', '')
  return concat(tgen:get-package-home($pkgID), $mungedPath)
};

(: Get the full path to a view pacakge's home directory. :)
declare function tgen:get-package-home($pkgID as xs:string) as xs:string {
  concat($tgen:pkgDir,$pkgID,'/')
};

(: Get the <run> element from the configuration file. :)
declare function tgen:get-run-stmt($pkgID as xs:string) as node()? {
  let $config := tgen:get-config-file($pkgID)
  return $config/vpkg:run
};

(: Get the configurations from all known view packages. :)
  (: XD: it turns out this use of collection() is eXist-specific. It outputs all 
    files in descendant collections. Saxon will not do the same. :)
(:declare function tgen:get-view-packages() as item()* {
  collection($tgen:pkgDir)[contains(base-uri(), 'CONFIG.xml')]/vpkg:view_package
};:)
