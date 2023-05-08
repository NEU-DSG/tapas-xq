xquery version "3.0";

declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";


(:~ Before installing the package, eXist will:
    * create a user for the app (if none exists);
    * create 'tapas-data' and 'tapas-view-pkgs' directories for the app (if none exists); and
    * change the owner/group of 'tapas-data' and 'tapas-view-pkgs' (if it hasn't been done).
   
   NOTE: When tapas-xq is installed on a web-accessible server, the user 
   password should be changed afterward from the default used in $tempPass.
   
   @author Ashley M. Clark
 :)
 
  declare variable $owner := "tapas";
  declare variable $tempPass := $owner;
  declare variable $group := "tapas";
  declare variable $storageDirBase := "/db";
  declare variable $dataDir := "tapas-data";
  declare variable $viewsDir := "tapas-view-pkgs";
  
  (: Create a specified directory if it does not already exist, logging any errors. :)
  declare function local:create-dir($pathBase as xs:string, $dirName as xs:string) {
    let $path := concat($pathBase,'/',$dirName)
    return 
      if ( not(xmldb:collection-available($path)) ) then 
        let $createdPath := xmldb:create-collection($pathBase,$dirName)
        let $ace := 
          sm:add-group-ace(xs:anyURI(concat($storageDirBase,'/',$dataDir)), 
            'tapas', true(), '-w-')
        return 
          if ( empty($createdPath) ) then
            util:log('error',concat('Could not create directory ',$path,
              ' as part of the pre-install process for tapas-xq.'))
          else 
            (
              util:log('warn',concat('Created ',$createdPath,
                ' as part of the pre-install process for tapas-xq.')),
              local:chown-dir($path)
            )
      else local:chown-dir($path)
  };
  
  (: Change the owner, group, and/or mode of a specified directory. :)
  declare function local:chown-dir($path as xs:string) {
    let $permissions := sm:get-permissions(xs:anyURI($path))
    let $doChangeOwner := function ($currentPermissions) as xs:boolean {
        $currentPermissions/sm:permission/@owner != $owner 
        or $currentPermissions/sm:permission/@group != $owner
      }
    let $dirMode := "rwxrwxr-x"
    let $doChangeMode := function ($currentPermissions) as xs:boolean {
        $currentPermissions/sm:permission/@mode ne $dirMode
      }
    return (
        if ( $doChangeOwner($permissions) ) then
          let $chown := sm:chown($path,concat($owner,':',$owner))
          return 
            let $newPermissions := sm:get-permissions(xs:anyURI($path))
            return 
              if ( $doChangeOwner($newPermissions) ) then
                util:log('error', concat('Could not change the owner/group of ',
                  $path,' to ',$owner,' as part of the pre-install process for tapas-xq.'))
              else 
                util:log('info',concat('Changed the owner/group of ',$path,' to ',
                  $owner,' as part of the pre-install process for tapas-xq.'))
        (: There is no need to return anything if the owner and group are already 
         : correct. Nothing happens. :)
        else ()
        ,
        if ( $doChangeMode($permissions) ) then
          let $chmod := sm:chmod($path, $dirMode)
          return
            let $newPermissions := sm:get-permissions(xs:anyURI($path))
            return
              if ( $doChangeMode($newPermissions) ) then
                util:log('error', concat('Could not change the mode of ',$path,
                  ' to "',$dirMode,'" as part of the pre-install process for tapas-xq.'))
              else
                util:log('info',concat('Changed the mode of ',$path,
                  ' as part of the pre-install process for tapas-xq.'))
        else ()
      )
  };
  
  (: Helper function to recursively create a collection hierarchy. :)
  declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
  };
  
  declare function local:mkcol-recursive($collection, $components) {
    if ( exists($components) ) then
      let $newColl := concat($collection, "/", $components[1])
      return (
          xmldb:create-collection($collection, $components[1]),
          local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else ()
  };


(
  (: Create user who will own the TAPAS collections. :)
  if ( not(sm:user-exists($owner)) ) then 
    let $newUser := sm:create-account($owner, $tempPass, $group)
    return 
      if ( not(sm:user-exists($owner)) ) then
        util:log('error',concat('Could not create user ',$owner,
          ' as part of the pre-install process for tapas-xq.'))
      else 
        util:log('warn',concat('Created user ',$owner,
          ' as part of the pre-install process for tapas-xq.'))
  else ()
  ,
  (: Create the user data directory. :)
  local:create-dir($storageDirBase,  $dataDir),
  (: Create the view package directory. :)
  local:create-dir($storageDirBase, $viewsDir),
  (: Create a directory for the collection configuration file. :)
  local:mkcol("/db/system/config", concat($storageDirBase,'/',$dataDir))
)
