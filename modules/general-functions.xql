xquery version "3.0";

(:~
  Library for generic XQuery functions.
  
  @author Ashley M. Clark
  @version 1.0
  
  2023-10-11:  Added tgen:set-status-description(), which will replace 
    tgen:get-error().
  2017-08-22:  Added get-document().
  2017-02-14:  Changed the prefix for this library from 'tapas-xq' to the 'tgen' 
    already used everywhere else.
  2017-01-30:  Added function to get a configuration file for a view package.
  2015-10-05:  Added set-error().
 :)

  module namespace tgen="http://tapasproject.org/tapas-xq/general";
  
  declare namespace vpkg="http://www.wheatoncollege.edu/TAPAS/1.0";


(:  VARIABLES  :)
  
  declare variable $tgen:pkgDir := '/db/tapas-view-pkgs/';
  declare variable $tgen:dataDir := '/db/tapas-data/';


(:  FUNCTIONS  :)

  (:~
    Get a stored file using its project and document identifiers.
   :)
  declare function tgen:get-document($proj-id as xs:string, $doc-id as xs:string) {
    let $path := concat($tgen:dataDir, $proj-id, '/', $doc-id)
    return
      if ( doc-available($path) ) then
        doc($path)
      else 400
  };


(:  HTTP STATUS MESSAGES  :)
  
  (:~
    Given an HTTP status code, return some human-readable text.
   :)
  declare function tgen:get-error($code as xs:integer) {
    tgen:set-status-description($code)
  };
  
  (:~
    Given an HTTP status code, return some human-readable text.
   :)
  declare function tgen:set-status-description($code as xs:integer?) {
    let $desc :=
      switch ($code)
        case 200 return "OK"
        case 400 return "bad request"
        case 401 return "authentication failed"
        case 405 return "unsupported HTTP method"
        case 500 return "unable to access resource"
        case 501 return "functionality not implemented"
        default  return
          if ( $code ge 500 ) then
            "server problem"
          else if ( $code ge 400 ) then
            "bad request"
          else if ( $code ge 300 ) then
            "Redirecting"
          else if ( $code ge 200 ) then
            "Success"
          else ()
    return
      if ( $desc and $code ge 400 ) then
        <p>Error: { $desc }</p>
      else if ( $desc ) then
        <p>{ $desc }</p>
      else
        <p>Error</p>
  };
  
  (:~
    Ensure that error messages are formatted in XML.
   :)
  declare function tgen:set-error($content) {
    typeswitch ($content)
      case xs:string return <p>{$content}</p>
      case node() return $content
      default return $content
  };
