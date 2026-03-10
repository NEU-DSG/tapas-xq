
This documentation was generated from its <a href="https://github.com/NEU-DSG/tapas-xq/blob/develop/modules/tapas-api.xql">source code</a> on March 10th, 2026, 2:00 p.m. GMT-04:00.

# TAPAS-xq API documentation

This is the API for TAPAS-xq, the XML database component of TAPAS. TAPAS-xq stores TEI documents, 
indexes them, and generates derivatives such as MODS metadata and reading interface XHTML.

TAPAS-xq also maintains a registry of “<a href="https://github.com/NEU-DSG/tapas-view-packages">view 
packages</a>”. Each view package includes: a program for generating a “view” (a web page); web assets 
for displaying that page; and a configuration file describing these contents. TAPAS-xq is mostly 
concerned with the program component, and the configuration file which defines how to execute that 
program.

All POST and DELETE requests <strong>must</strong> include an Authentication header containing the 
credentials for a BaseX user with write access to the TAPAS databases. If a request doesn’t meet this
criteria, a response with an HTTP status code 401 will be returned.


<h2 id="tei-viability-testing">TEI viability testing</h2>


If an endpoint accepts TEI XML in a request, TAPAS-xq must receive a single, <a href="https://wwp.northeastern.edu/outreach/seminars/_current/presentations/xml_intro/xml_newIntro_tutorial_13.xhtml">well-formed</a> XML file, with <code>&lt;TEI xmlns="http://www.tei-c.org/ns/1.0"&gt;</code> 
(<a href="https://en.wikipedia.org/wiki/XML_namespace#Namespace_declaration">or an equivalent</a>) as 
the outermost element, and exactly one <code>&lt;teiHeader&gt;</code>. No arbitrary Javascript is 
allowed. TAPAS-xq does not, however, validate the file against a full TEI schema. This allows TAPAS 
users to upload files that adhere to arbitrary (modern) TEI versions, or even their own custom schemas.

TAPAS-xq will run minimal validation processes on a request’s file parameter before doing anything 
else. Processing will halt for any of the following cases:

<ul>
<li>Multiple files are identified</li>
<li>The file is an unparsable binary file</li>
<li>The file cannot be parsed as XML (it may be ill-formed)</li>
<li>The file is parsable XML but one or more of the following is true:
<ul>
<li>The outermost element is not in the TEI namespace 
(<code>http://www.tei-c.org/ns/1.0</code>)</li>
<li>The outermost element’s name is not <code>TEI</code></li>
<li>There is no <code>teiHeader</code> element</li>
<li>There are multiple <code>teiHeader</code> elements</li>
<li>An element named <code>script</code> is found in any namespace</li>
</ul>
</li>
</ul>

When a test failure occurs, HTTP status code 422 will be returned. The response body will contain a 
description of identified problems.

<h2 id="all-endpoints">Request endpoints</h2>

### Get documentation

<code>GET /tapas-xq/api</code>

Generate documentation for the TAPAS-xq API, in XHTML or Markdown. If the user has administrator 
privileges, this documentation is generated dynamically from the RESTXQ code. Otherwise, a cached 
HTML or Markdown file is used.

This endpoint returns a representation of the API documentation, with status code 200.

<table><caption>Request settings</caption><thead><tr><th style="min-width:10%;">Name</th><th>Description</th><th>Where to set value</th></tr></thead><tbody><tr><th scope="row">format</th><td>The formatting method to use when producing documentation. Valid options are 
"markdown" or "html". The default is to return HTML, in XHTML format.</td><td>query parameter</td></tr></tbody></table>

### Store core file and supplementals

<code>POST /tapas-xq/<strong>project-id</strong>/<strong>doc-id</strong></code>

Store a TEI record into the XML database, as well as MODS metadata and “TAPAS-friendly environment” 
(TFE) metadata. The generated MODS metadata record is also returned in the HTTP response.

This endpoint is a convenient wrapper for the “Store core file”, “Store core file object 
description”, and “Store core file contextual metadata” endpoints. When a core file is initially 
created, this endpoint alone will suffice to generate everything needed by TAPAS-xq and Rails.

This endpoint returns the MODS record derived from the TEI file, with HTTP status code 201.

If the provided file is not viable TEI, processing will halt with HTTP status code 422. See the 
<a href="#tei-viability-testing">“TEI viability testing”</a> section above for more information.

If the MODS file could not be generated because of a problem with the XSLT stylesheet, an HTTP 
status code 500 will be returned. If necessary, the TAPAS-xq maintainer should be alerted so they 
can fix the problem. The TEI and TFE files will be stored regardless.

<table><caption>Request settings</caption><thead><tr><th style="min-width:10%;">Name</th><th>Description</th><th>Where to set value</th></tr></thead><tbody><tr><th scope="row">project-id</th><td>The unique identifier of the project which owns the work.</td><td>URL</td></tr><tr><th scope="row">doc-id</th><td>A unique identifier for the document record attached to the original TEI document and 
its derivatives.</td><td>URL</td></tr><tr><th scope="row">file</th><td>The TEI-encoded XML document to be stored.</td><td>form parameter</td></tr><tr><th scope="row">collections</th><td>Comma-separated list of collection identifiers with which the work should be 
associated.</td><td>form parameter</td></tr><tr><th scope="row">is-public</th><td>Optional. Value of “true” or “false”. Indicates if the XML document should be 
queryable by the public. By default, the document is considered private. (Note that if the 
document belongs to even one public collection, it should be queryable.)</td><td>form parameter</td></tr><tr><th scope="row">title</th><td>Optional. The work’s title as it should appear in TAPAS metadata.</td><td>form parameter</td></tr><tr><th scope="row">authors</th><td>Optional. A list of authors’ names as they should appear in TAPAS metadata, separated 
by vertical bars.</td><td>form parameter</td></tr><tr><th scope="row">contributors</th><td>Optional. A list of contributors’ names as they should appear in TAPAS metadata, 
separated by vertical bars.</td><td>form parameter</td></tr></tbody></table>

### Store core file

<code>POST /tapas-xq/<strong>project-id</strong>/<strong>doc-id</strong>/tei</code>

Store a TEI document.

This endpoint returns a URL path for accessing the stored TEI file through the TAPAS-xq API, with status code 201.

If the provided file is not viable TEI, processing will halt with HTTP status code 422. See the 
<a href="#tei-viability-testing">“TEI viability testing”</a> section above for more information.

<table><caption>Request settings</caption><thead><tr><th style="min-width:10%;">Name</th><th>Description</th><th>Where to set value</th></tr></thead><tbody><tr><th scope="row">project-id</th><td>The unique identifier of the project which owns the work.</td><td>URL</td></tr><tr><th scope="row">doc-id</th><td>A unique identifier for the document record attached to the original TEI document and 
its derivatives (MODS, TFE).</td><td>URL</td></tr><tr><th scope="row">file</th><td>The TEI-encoded XML document to be stored.</td><td>form parameter</td></tr></tbody></table>

### Store core file object description

<code>POST /tapas-xq/<strong>project-id</strong>/<strong>doc-id</strong>/mods</code>

Construct a MODS metadata record using the TEI header and any additional information provided in the 
request. Store the MODS in the database alongside its core file TEI.

The TEI core file must be stored <em>before</em> any of its derivatives.

This endpoint returns the MODS record derived from the TEI file, with status code 201. If no TEI document is 
associated with the given <code>doc-id</code>, or if something went wrong with the 
MODS transformation, the response will have a status code of 500.

<table><caption>Request settings</caption><thead><tr><th style="min-width:10%;">Name</th><th>Description</th><th>Where to set value</th></tr></thead><tbody><tr><th scope="row">project-id</th><td>The unique identifier of the project which owns the work.</td><td>URL</td></tr><tr><th scope="row">doc-id</th><td>A unique identifier for the document record attached to the original TEI document and 
its derivatives.</td><td>URL</td></tr><tr><th scope="row">title</th><td>Optional. The work’s title as it should appear in TAPAS metadata.</td><td>form parameter</td></tr><tr><th scope="row">authors</th><td>Optional. A list of authors’ names as they should appear in TAPAS metadata, separated 
by vertical bars.</td><td>form parameter</td></tr><tr><th scope="row">contributors</th><td>Optional. A list of contributors’ names as they should appear in TAPAS metadata, 
separated by vertical bars.</td><td>form parameter</td></tr></tbody></table>

### Store core file contextual metadata

<code>POST /tapas-xq/<strong>project-id</strong>/<strong>doc-id</strong>/tfe</code>

Store “TAPAS-friendly environment” (TFE) metadata. Triggers the generation of a small XML file 
containing useful information about the context of the TEI document, such as its parent project.

The TEI core file must be stored <em>before</em> any of its derivatives.

This endpoint returns a URL path for reading the new TFE file through the TAPAS-xq API, with status code 201. If 
no TEI document is associated with the given <code>doc-id</code>, the response will 
have a status code of 500.

<table><caption>Request settings</caption><thead><tr><th style="min-width:10%;">Name</th><th>Description</th><th>Where to set value</th></tr></thead><tbody><tr><th scope="row">project-id</th><td>The unique identifier of the project which owns the work.</td><td>URL</td></tr><tr><th scope="row">doc-id</th><td>A unique identifier for the document record attached to the original TEI document and 
its derivatives.</td><td>URL</td></tr><tr><th scope="row">collections</th><td>Comma-separated list of collection identifiers with which the work should be 
associated.</td><td>form parameter</td></tr><tr><th scope="row">is-public</th><td>Optional. Value of “true” or “false”. Indicates if the XML document should be 
queryable by the public. By default, the document is considered private. (Note that if the 
document belongs to even one public collection, it should be queryable.)</td><td>form parameter</td></tr></tbody></table>

### Derive reader

<code>POST /tapas-xq/derive-reader/<strong>type</strong></code>

Given the name of a TAPAS view package, generate an XHTML file from the provided TEI document. The 
generated XHTML is not a full webpage but a <code>&lt;div&gt;</code> snippet, suitable for inclusion 
in the TAPAS reading interface. 

The XML database does not store any files as a result of this request.

Note that additional form parameters may be available, depending on the view package selected. Check 
the view package’s configuration file for additional parameters.

This endpoint returns generated XHTML with status code 200.

If the provided file is not viable TEI, processing will halt with HTTP status code 422. See the 
<a href="#tei-viability-testing">“TEI viability testing”</a> section above for more information.

<table><caption>Request settings</caption><thead><tr><th style="min-width:10%;">Name</th><th>Description</th><th>Where to set value</th></tr></thead><tbody><tr><th scope="row">type</th><td>A keyword representing the type of reader view to generate. Valid keywords can be found 
by making a request to  the “List registered view packages” endpoint.</td><td>URL</td></tr><tr><th scope="row">file</th><td>A TEI-encoded XML document. The file parameter may become optional in the future, if a 
view package makes use of a different input source (such as a TAPAS collection or a project).</td><td>form parameter</td></tr></tbody></table>

### Read core file

<code>GET /tapas-xq/<strong>project-id</strong>/<strong>doc-id</strong>/tei</code>

Retrieve a TEI file stored in the XML database.

This endpoint returns a copy of the TEI file, with status code 200. If the file does not exist, the response will 
have a status code of 404.

If the file is marked as private in the contextual metadata (TFE file), only users with write 
access to the database will be able to access the file. An attempt at unauthorized access will 
yield a 403 status code and error.

<table><caption>Request settings</caption><thead><tr><th style="min-width:10%;">Name</th><th>Description</th><th>Where to set value</th></tr></thead><tbody><tr><th scope="row">project-id</th><td>The identifier of the project which owns the core file.</td><td>URL</td></tr><tr><th scope="row">doc-id</th><td>The identifier of the TEI core file.</td><td>URL</td></tr></tbody></table>

### Read core file object description

<code>GET /tapas-xq/<strong>project-id</strong>/<strong>doc-id</strong>/mods</code>

Retrieve a MODS file associated with a given core file identifier.

This endpoint returns a copy of the MODS metadata, with status code 200. If the file does not exist, the response 
will have a status code of 404.

If the file is marked as private in the contextual metadata (TFE file), only users with write 
access to the database will be able to access the file. An attempt at unauthorized access will 
yield a 403 status code and error.

<table><caption>Request settings</caption><thead><tr><th style="min-width:10%;">Name</th><th>Description</th><th>Where to set value</th></tr></thead><tbody><tr><th scope="row">project-id</th><td>The identifier of the project which owns the core file.</td><td>URL</td></tr><tr><th scope="row">doc-id</th><td>The identifier of the TEI core file.</td><td>URL</td></tr></tbody></table>

### Read core file contextual metadata

<code>GET /tapas-xq/<strong>project-id</strong>/<strong>doc-id</strong>/tfe</code>

Retrieve a TAPAS-friendly environment (TFE) file associated with a given core file identifier.

This endpoint returns a copy of the TFE metadata, with status code 200. If the file does not exist, the response 
will have a status code of 404.

If the file is marked as private in the contextual metadata (TFE file), only users with write 
access to the database will be able to access the file. An attempt at unauthorized access will 
yield a 403 status code and error.

<table><caption>Request settings</caption><thead><tr><th style="min-width:10%;">Name</th><th>Description</th><th>Where to set value</th></tr></thead><tbody><tr><th scope="row">project-id</th><td>The identifier of the project which owns the core file.</td><td>URL</td></tr><tr><th scope="row">doc-id</th><td>The identifier of the TEI core file.</td><td>URL</td></tr></tbody></table>

### Delete core file

<code>DELETE /tapas-xq/<strong>project-id</strong>/<strong>doc-id</strong></code>

Completely remove all database records associated with a given TEI core file identifier: TEI file, 
MODS metadata, and TAPAS-friendly environment record.

This endpoint returns a short confirmation in XML that the resources will be deleted, with status code 202. If no 
TEI document is associated with the given identifier, the response will have a status code of 500.

<table><caption>Request settings</caption><thead><tr><th style="min-width:10%;">Name</th><th>Description</th><th>Where to set value</th></tr></thead><tbody><tr><th scope="row">project-id</th><td>The identifier of the project which owns the core file.</td><td>URL</td></tr><tr><th scope="row">doc-id</th><td>The identifier of the TEI core file.</td><td>URL</td></tr></tbody></table>

### Delete project documents

<code>DELETE /tapas-xq/<strong>project-id</strong></code>

Completely remove all database records associated with the given TAPAS project.

This endpoint returns a short confirmation in XML that the resources will be deleted, with status code 202. If no 
TEI document is associated with the given identifier, the response will have a status code of 500.

<table><caption>Request settings</caption><thead><tr><th style="min-width:10%;">Name</th><th>Description</th><th>Where to set value</th></tr></thead><tbody><tr><th scope="row">project-id</th><td>The unique identifier of the project to be deleted.</td><td>URL</td></tr></tbody></table>

### List registered view packages

<code>GET /tapas-xq/view-packages</code>

Retrieve the XML registry of all view packages currently available in TAPAS-xq.

This endpoint returns the XML registry of view packages, with status code 200.

### Update registered view packages

<code>POST /tapas-xq/view-packages</code>

Update the view packages database using the latest commits from the GitHub repository. Then, update 
the view package registry.

<strong>Important:</strong> This endpoint can only be accessed by BaseX accounts with administrator
permissions.

This endpoint returns a short confirmation in XML that the view package repository and database has been updated,
with status code 201. The view package registry will be re-generated after 500 milliseconds.

### Get view package configuration

<code>GET /tapas-xq/view-packages/<strong>package-id</strong></code>

Retrieve the configuration file for a given view package.

This endpoint returns the XML configuration file of the view package with status code 200. If the requested 
identifier does not match a view package registered with TAPAS-xq, the response will have a status 
code of 400.

<table><caption>Request settings</caption><thead><tr><th style="min-width:10%;">Name</th><th>Description</th><th>Where to set value</th></tr></thead><tbody><tr><th scope="row">package-id</th><td>The identifier of the view package.</td><td>URL</td></tr></tbody></table>
