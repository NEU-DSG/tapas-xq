xquery version "1.0";

import module namespace request="http://exist-db.org/xquery/request";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;

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

if ($exist:resource = 'tei') then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/store-', $exist:resource, '.xq')}" method="{request:get-method()}">
      <add-parameter name="doc-id" value="{local:get-parent-dir()}"/>
      <add-parameter name="proj-id" value="{local:get-proj-dir()}"/>
    </forward>
  </dispatch>
else if ($exist:resource = 'mods' or $exist:resource = 'tfe') then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/store-', $exist:resource, '.xq')}" method="{request:get-method()}">
      <add-parameter name="doc-id" value="{local:get-parent-dir()}"/>
      <add-parameter name="proj-id" value="{local:get-proj-dir()}"/>
    </forward>
  </dispatch>
else if (local:get-parent-dir() eq 'derive-reader' and local:get-extension($exist:resource) eq '') then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/derive-reader.xq')}" method="{request:get-method()}">
      <add-parameter name="type" value="{$exist:resource}"/>
    </forward>
  </dispatch>
else if (request:get-method() = 'DELETE' and local:get-extension($exist:resource) eq '') then
  if ( local:get-parent-dir() eq '/' ) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
      <forward url="{concat($exist:controller, '/modules/delete-by-projid.xq')}" method="{request:get-method()}">
        <add-parameter name="proj-id" value="{$exist:resource}"/>
      </forward>
    </dispatch>
  else
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
      <forward url="{concat($exist:controller, '/modules/delete-by-docid.xq')}" method="{request:get-method()}">
        <add-parameter name="doc-id" value="{$exist:resource}"/>
        <add-parameter name="proj-id" value="{local:get-parent-dir()}"/>
      </forward>
    </dispatch>
else if (local:get-extension($exist:resource) eq '') then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/', $exist:resource, '.xq')}" method="{request:get-method()}"/>
  </dispatch>
else
  <ignore xmlns="http://exist.sourceforge.net/NS/exist">
    <cache-control cache="yes"/>
  </ignore>
