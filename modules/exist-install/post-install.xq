xquery version "3.0";

declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace system="http://exist-db.org/xquery/system";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xdb="http://exist-db.org/xquery/xmldb";

import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs" at "/db/apps/tapas-xq/modules/libraries/view-pkgs.xql";


(:~ After installing the package, eXist will:
 :  * if there is no environment configuration file at /db/environment.xml, copy 
 :    the default configuration there;
 :  * if there is no view package registry, acquire the view packages from GitHub 
 :    and create the registry (if there is a registry with entries, do nothing)
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


let $environmentFileName := 'environment.xml'
let $environmentFilePath := concat($storageDirBase, '/', $environmentFileName)
let $environmentSet :=
  if ( doc-available($environmentFilePath) ) then
    true()
  else 
    let $moduleLoc := replace(system:get-module-load-path(), '^(xmldb:exist//)?(embedded-eXist-server)?(.+)$', '$3')
    let $defaultConfigPath := concat($moduleLoc,'/', $environmentFileName, '.default')
    return
      if ( util:binary-doc-available($defaultConfigPath) ) then
        let $stored := xdb:store($storageDirBase, $environmentFileName, util:binary-doc($defaultConfigPath), 'text/xml' )
        return 
          if ( exists($stored) and doc-available($stored) ) then 
            let $permissions := sm:chmod($environmentFilePath, 'rw-rw-r--')
            return true()
          else false()
      else false()
return
  if ( $environmentSet ) then
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
  else () (: error :)
