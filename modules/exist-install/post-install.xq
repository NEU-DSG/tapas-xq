xquery version "3.0";

declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs" at "/db/apps/tapas-xq/modules/libraries/view-pkgs.xql";


(:~ After installing the package, eXist will:
 :  * if there is no view package registry, create it and download all packages.
 : 
 : NOTE: When tapas-xq is installed on a web-accessible server, the user 
 : password should be changed afterward from the default used in $tempPass.
 : 
 : @author Ashley M. Clark
 :)

declare variable $storageDirBase := "/db";
declare variable $dataDir := "tapas-data";
declare variable $viewsDir := "tapas-view-pkgs";

let $parentDir := concat($storageDirBase,'/',$viewsDir)
let $registryName := 'registry.xml'
let $registryPath := concat($parentDir,'/',$registryName)
let $stub := <view_registry></view_registry>
return
  if ( doc-available($registryPath) and doc($registryPath)[descendant-or-self::view_registry] ) then
    ()
  else
    if ( empty(xmldb:store($parentDir, $registryName, $stub)) ) then
      util:log('error',
              concat('Could not create view package registry at ',$registryPath,
              ' as part of the post-install process for tapas-xq.'))
    else dpkg:update-packages()
