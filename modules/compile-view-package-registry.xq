xquery version "3.1";

(:~
  Generate the view package registry from view package configurations already stored 
  in the database.
 :)

import module namespace dpkg="http://tapasproject.org/tapas-xq/view-pkgs"
  at "view-packages.xql";

dpkg:compile-registry()
