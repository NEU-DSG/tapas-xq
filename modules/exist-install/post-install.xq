xquery version "3.0";

declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace system="http://exist-db.org/xquery/system";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xdb="http://exist-db.org/xquery/xmldb";

import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs" at "/db/apps/tapas-xq/modules/libraries/view-pkgs.xql";


(:~ After installing the package, eXist will:
 :  * refresh the collection configuration file;
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
declare variable $moduleLoc := replace(system:get-module-load-path(), 
   '^(xmldb:exist//)?(embedded-eXist-server)?(.+)$', '$3');

(
  (: Store the collection configuration for the data directory. :)
  let $inputPath := concat($moduleLoc,'/resources/collection.xconf')
  let $targetPath := concat('/db/system/config',$storageDirBase,'/',$dataDir)
  return
    xdb:store($targetPath, 'collection.xconf', doc($inputPath))
  ,
  (: Make sure that the data directory and all of its resources are writable by the 
    "tapas" group. :)
  for $projCollection in xdb:get-child-collections(concat($storageDirBase,'/',$dataDir))
  let $projPath := concat($storageDirBase,'/',$dataDir,'/',$projCollection)
  return (
      sm:chmod(xs:anyURI($projPath), 'rwxrwxr-x'),
      for $docCollection in xdb:get-child-collections($projPath)
      let $docCollPath := concat($projPath,'/',$docCollection)
      return (
          sm:chmod(xs:anyURI($docCollPath), 'rwxrwxr-x'),
          for $docName in xdb:get-child-resources($docCollPath)
          let $docPath := concat($docCollPath,'/',$docName)
          return
            sm:chmod(xs:anyURI($docPath), 'rw-rw-r--')
        )
    )
  ,
  (: Store the environment.xml file. :)
  let $environmentFileName := 'environment.xml'
  let $environmentFilePath := concat($storageDirBase, '/', $environmentFileName)
  let $environmentSet :=
    if ( doc-available($environmentFilePath) ) then true()
    else 
      let $defaultConfigPath := concat($moduleLoc,'/', $environmentFileName)
      return
        if ( util:binary-doc-available($defaultConfigPath) ) then
          let $stored := xdb:store($storageDirBase, $environmentFileName, 
             util:binary-doc($defaultConfigPath), 'text/xml' )
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
      let $warning := function () {
          util:log('warn',
            "Could not initialize the TAPAS view packages collection. Try logging in as the TAPAS user and updating the view packages.")
        }
      return
        if ( doc-available($registryPath) and doc($registryPath)[descendant::package_ref] ) then
          ()
        else
          (: Try to log in as the 'tapas' user before initializing view packages. :)
          if ( dpkg:has-write-access() ) then
            try { 
              dpkg:initialize-packages()
            } catch * { $warning() }
          else $warning()
    else () (: error :)
)
