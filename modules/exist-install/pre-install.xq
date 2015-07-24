xquery version "3.0";

(: Before installing the package, eXist will:
 :  * create a user for the app (if none exists);
 :  * create a 'tapas-data' directory for the app (if none exists); and
 :  * change the owner/group of 'tapas-data' (if it hasn't been done).
 : 
 : NOTE: When tapas-xq is installed on a web-accessible server, the user 
 : password should be changed afterward from the default used in $tempPass.
 :)
 
declare variable $owner := "tapas";
declare variable $tempPass := $owner;
declare variable $dataDir := "tapas-data";
declare variable $dataPath := concat('/db/',$dataDir);

(: Create the data directory, :)
declare function local:create-dir() {
  if ( not(xmldb:collection-available($dataPath)) ) then 
    let $createdPath := xmldb:create-collection('/db',$dataDir)
    return 
      if ( empty($createdPath) ) then
        util:log('error',concat('Could not create directory ',$dataPath,' as part of the pre-install process for tapas-xq.'))
      else 
        (
          util:log('warn',concat('Created ',$createdPath,' as part of the pre-install process for tapas-xq.')),
          local:chown-dir()
        )
  else local:chown-dir()
};

(: Change the owner of the data directory. :)
declare function local:chown-dir() {
  let $permissions := sm:get-permissions(xs:anyURI($dataPath))
  return
    if ( $permissions/sm:permission/@owner != $owner or $permissions/sm:permission/@group != $owner ) then
      let $chown := sm:chown($dataPath,concat($owner,':',$owner))
      return 
        let $newPermissions := sm:get-permissions(xs:anyURI($dataPath))
        return 
          if ( $newPermissions/sm:permission/@owner != $owner or $newPermissions/sm:permission/@group != $owner  ) then
            util:log('error',concat('Could not change the owner/group of ',$dataPath,' to ',$owner,' as part of the pre-install process for tapas-xq.'))
          else 
            util:log('warn',concat('Changed the owner/group of ',$dataPath,' to ',$owner,' as part of the pre-install process for tapas-xq.'))
    else
      ()
};

(: Create user who will own the tapas-data collection. :)
if ( not(sm:user-exists($owner)) ) then 
  let $newUser := sm:create-account($owner,$tempPass,())
  return 
    if ( not(sm:user-exists($owner)) ) then
      util:log('error',concat('Could not create user ',$owner,' as part of the pre-install process for tapas-xq.'))
    else 
      (
        util:log('warn',concat('Created user ',$owner,' as part of the pre-install process for tapas-xq.')),
        local:create-dir()
      )
else local:create-dir()
