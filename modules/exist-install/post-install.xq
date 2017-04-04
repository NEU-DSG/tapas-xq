xquery version "3.0";

declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs" at "/db/apps/tapas-xq/modules/libraries/view-pkgs.xql";


(:~ After installing the package, eXist will:
 :  * if there is no view package registry, acquire the view packages from GitHub 
 :    and create the registry (if there is a registry, do nothing)
 : 
 : @author Ashley M. Clark
 :)

declare variable $storageDirBase := "/db";
declare variable $dataDir := "tapas-data";
declare variable $viewsDir := "tapas-view-pkgs";

let $parentDir := concat($storageDirBase,'/',$viewsDir)
let $registryName := 'registry.xml'
let $registryPath := concat($parentDir,'/',$registryName)
return
  if ( doc-available($registryPath) and doc($registryPath)[descendant-or-self::view_registry] ) then
    ()
  else
    dpkg:initialize-packages()
