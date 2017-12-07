xquery version "1.0";

import module namespace md="http://exist-db.org/xquery/markdown";
import module namespace request="http://exist-db.org/xquery/request";

declare variable $exist:path        external;
declare variable $exist:resource    external;
declare variable $exist:controller  external;

declare function local:get-extension($filename as xs:string) as xs:string {
  let $name := replace($filename, '.*[/\\]([^/\\]+)$', '$1')
  return 
      if (contains($name, '.'))
      then replace($name, '.*\.([^\.]*)$', '$1')
      else ''
};

declare function local:get-parent-dir() as xs:string {
  let $prepath := substring-before($exist:path, $exist:resource)
  let $parent := replace($prepath, '.*[/\\]([^/\\]+)/?$', '$1')
  return $parent
};

declare function local:get-proj-dir() as xs:string {
  let $prepath := substring-before($exist:path, concat('/',local:get-parent-dir()))
  let $proj := replace($prepath, '.*[/\\]([^/\\]+)/?$', '$1')
  return $proj
};

(:
 : Store TEI
 : exist/apps/tapas-xq/:proj-id/:doc-id/tei     -> modules/store-tei.xq
 :)
if ( $exist:resource eq 'tei' ) then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/store-', $exist:resource, '.xq')}" method="{request:get-method()}">
      <add-parameter name="doc-id" value="{local:get-parent-dir()}"/>
      <add-parameter name="proj-id" value="{local:get-proj-dir()}"/>
    </forward>
  </dispatch>
(:
 : Store MODS or TFE
 : exist/apps/tapas-xq/:proj-id/:doc-id/mods    -> modules/store-mods.xq
 : exist/apps/tapas-xq/:proj-id/:doc-id/tfe     -> modules/store-tfe.xq
 :)
else if ( $exist:resource eq 'mods' or $exist:resource eq 'tfe' ) then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/store-', $exist:resource, '.xq')}" method="{request:get-method()}">
      <add-parameter name="doc-id" value="{local:get-parent-dir()}"/>
      <add-parameter name="proj-id" value="{local:get-proj-dir()}"/>
    </forward>
  </dispatch>
(:
 : Derive HTML for reader
 : exist/apps/tapas-xq/derive-reader/:type      -> modules/derive-reader.xq
 :)
else if ( local:get-parent-dir() eq 'derive-reader' and local:get-extension($exist:resource) eq '' ) then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/derive-reader.xq')}" method="{request:get-method()}">
      <add-parameter name="type" value="{$exist:resource}"/>
    </forward>
  </dispatch>
(:
 : Delete project
 : DELETE exist/apps/tapas-xq/:proj-id          -> modules/delete-by-projid.xq
 :)
else if (request:get-method() eq 'DELETE' and local:get-extension($exist:resource) eq '') then
  if ( local:get-parent-dir() eq '/' ) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
      <forward url="{concat($exist:controller, '/modules/delete-by-projid.xq')}" method="{request:get-method()}">
        <add-parameter name="proj-id" value="{$exist:resource}"/>
      </forward>
    </dispatch>
(:
 : Delete TEI document and ephemera
 : DELETE exist/apps/tapas-xq/:proj-id/:doc-id  -> modules/delete-by-docid.xq
 :)
  else
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
      <forward url="{concat($exist:controller, '/modules/delete-by-docid.xq')}" method="{request:get-method()}">
        <add-parameter name="doc-id" value="{$exist:resource}"/>
        <add-parameter name="proj-id" value="{local:get-parent-dir()}"/>
      </forward>
    </dispatch>
(:
 : Obtain registry of installed view packages
 : exist/apps/tapas-xq/view-packages            -> modules/get-view-packages.xq
 :)
else if ( $exist:resource eq 'view-packages' ) then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/get-view-packages.xq')}" method="{request:get-method()}"/>
  </dispatch>
(:
 : Obtain the configuration file of an installed view package
 : exist/apps/tapas-xq/view-packages/:type      -> modules/get-package-configuration.xq
 :)
else if ( local:get-parent-dir() eq 'view-packages' and local:get-extension($exist:resource) eq '' ) then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/get-package-configuration.xq')}" method="{request:get-method()}">
      <add-parameter name="type" value="{$exist:resource}"/>
    </forward>
  </dispatch>
else if ( $exist:resource eq 'api' or $exist:resource eq '' ) then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/get-api.xq')}" method="GET"/>
  </dispatch>
(:
 : All other API requests are passed on to an XQuery sharing the same name (without extension)
 : exist/apps/tapas-xq/:api-call                -> modules/:api-call.xq
 :)
else if ( local:get-extension($exist:resource) eq '' ) then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/', $exist:resource, '.xq')}" method="{request:get-method()}"/>
  </dispatch>
else
  <ignore xmlns="http://exist.sourceforge.net/NS/exist">
    <cache-control cache="yes"/>
  </ignore>
