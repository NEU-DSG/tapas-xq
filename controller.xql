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
  let $path := substring-before($exist:path, $exist:resource)
  let $parent := tokenize($path,'\/')[last()]
  return $parent
};

if ($exist:resource = 'tei' or $exist:resource = 'mods' or $exist:resource = 'tfe') then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/store-', $exist:resource, '.xq')}" method="{request:get-method()}">
      <add-parameter name="doc-id" value="{local:get-parent-dir()}"/>
    </forward>
  </dispatch>
else if (local:get-extension($exist:resource) eq '' and request:get-method() = 'DELETE') then
  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="{concat($exist:controller, '/modules/delete-by-docid.xq')}" method="{request:get-method()}">
      <add-parameter name="doc-id" value="{$exist:resource}"/>
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
