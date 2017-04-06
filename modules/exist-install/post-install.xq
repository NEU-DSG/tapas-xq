xquery version "3.0";

declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xdb="http://exist-db.org/xquery/xmldb";

import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs" at "/db/apps/tapas-xq/modules/libraries/view-pkgs.xql";


(:~ After installing the package, eXist will:
 :  * if there is no view package registry, acquire the view packages from GitHub 
 :    and create the registry (if there is a registry, do nothing)
 : 
 : NOTE: This script will try to log in as the TAPAS user before initializing view 
 : packages. This will only work if the TAPAS user still has the default password 
 : (read: in non-production environments and on fresh eXist installations). For 
 : other environments, log in as 'tapas' and either run `dpkg:initialize-packages()`, 
 : or send a POST request to `HOST/exist/apps/tapas-xq/update-view-packages`. While 
 : it is currently (2017-04) possible to use the admin account to initialize or 
 : update the view packages, doing so will keep the TAPAS user from being able to 
 : update later.
 : 
 : @author Ashley M. Clark
 :)

declare variable $owner := "tapas";
declare variable $storageDirBase := "/db";
declare variable $dataDir := "tapas-data";
declare variable $viewsDir := "tapas-view-pkgs";

let $parentDir := concat($storageDirBase,'/',$viewsDir)
let $registryName := 'registry.xml'
let $registryPath := concat($parentDir,'/',$registryName)
return
  if ( doc-available($registryPath) and doc($registryPath)[descendant::package_ref] ) then
    ()
  else
    (: Try to log in as the 'tapas' user before initializing view packages. :)
    if ( xdb:login($parentDir, $owner, $owner) ) then
      dpkg:initialize-packages()
    else
      util:log('warn','Could not initialize the TAPAS view packages collection. Try logging in as the TAPAS user and updating the view packages.')
