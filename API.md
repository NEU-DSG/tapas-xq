# TAPAS-xq API

_Last updated 2024-01-10._ For details, see the [changelog](#changelog).


## For all requests

### Authentication

Each request must contain a BaseX username and password with permission to modify the `tapas-data` database.

### HTTP status codes

<dl>
  <dt>Success of derivation request</dt>
  <dd>200</dd>
  <dt>Success of storage request</dt>
  <dd>201</dd>
  <dt>Success of deletion request</dt>
  <dd>202</dd>
  <dt>Log-in failed/insufficient permissions for executing request</dt>
  <dd>401</dd>
  <dt>Unsupported HTTP method</dt>
  <dd>405</dd>
  <dt>Unable to access resource</dt>
  <dd>500</dd>
</dl>

<!--
## Resource requests

### Derive MODS production file from a TEI document

`POST tapas-xq/derive-mods`

Content-type: multipart/form-data

Parameters:

| Name | Description |
| ------ | ------- |
| file | The TEI-encoded XML document to be transformed. |

Optional parameters:

| Name | Description |
| ------ | ------- |
| title | The work's title as it should appear in TAPAS metadata. |
| authors | A list of authors' names as they should appear in TAPAS metadata, separated by vertical bars. |
| contributors | A list of contributors' names as they should appear in TAPAS metadata, separated by vertical bars. |

Returns an XML-encoded file of the MODS record with status code 200. eXist does not store any files as a result of this request.

### Derive XHTML (reading interface) production files from a TEI document

`POST tapas-xq/derive-reader/:type`

Content-type: multipart/form-data

__`:type`__: A keyword representing the type of reader view to generate. Visit the View Package Registry endpoint for the reader types that the application can generate.

Parameters:

| Name | Description |
| ------ | ------- |
| file | An XML-encoded TEI document. |

Use [the view package configuration file](#obtain-the-configuration-file-of-an-installed-view-package) to determine what additional parameters are required for the requested type of reader.

If, in the future, a [view package](https://github.com/NEU-DSG/tapas-view-packages) makes use of a different input source (such as a TAPAS collection or a project), the file parameter may be removed from this endpoint's requirements.

Returns XHTML generated from the TEI document with status code 200. eXist does not store any files as a result of this request.
-->


## Core files and derivatives

“Core file” is the term used for the primary content of TAPAS, a TEI document. The XML database is used to store the TEI file and its supporting metadata files.

In endpoints described below:

<dl>
  <dt><code>:proj-id</code></dt>
  <dd>The unique identifier of the project which owns the item.</dd>
  <dt><code>:doc-id</code></dt>
  <dd>A unique identifier for the document record attached to the original TEI document and its derivatives (MODS, TFE).</dd>
</dl>


### Upload a TEI document

This endpoint stores a TEI document, or “core file”, into the `tapas-data` database. The core file must be stored before any of its derivatives can be generated.

`POST tapas-xq/:proj-id/:doc-id/tei`

Content-type for the request: multipart/form-data

Request parameters:

| Name | Description | Required? |
| ---- | ----------- | --------- |
| file | An XML-encoded TEI document. | Yes |


### Generate and store “TAPAS-friendly environment” metadata

This endpoint uses the provided information to create a “TAPAS-friendly environment” (TFE) file. The metadata here is useful for determining whether a core file is queryable from different contexts. Since TAPAS-xq does not yet provide endpoints for search or querying, this endpoint is optional but recommended.

`POST tapas-xq/:proj-id/:doc-id/tfe`

Content-type for the request: multipart/form-data

Request parameters:

| Name | Description | Required? |
| ---- | ----------- | --------- |
| collections | Comma-separated list of collection identifiers with which the work should be associated. | Yes |
| is-public | Value of "true" or "false". Indicates if the XML document should be queryable by the public. Default value is false. (Note that if the document belongs to even one public collection, it should be queryable.) | Yes |

If no TEI document is associated with the given `:doc-id`, the API will return an error code.


### Generate and store MODS metadata

This endpoint uses the provided parameters and the [TEI header](https://www.tei-c.org/release/doc/tei-p5-doc/en/html/HD.html) to generate [MODS metadata](https://www.loc.gov/standards/mods/) for the TEI document. The MODS file is stored in the database and returned in the response.

`POST tapas-xq/:proj-id/:doc-id/mods`

Content-type for the request: multipart/form-data

Request parameters:

| Name | Description | Required? |
| ---- | ----------- | --------- |
| title | The work's title as it should appear in TAPAS metadata. | No |
| authors | A list of authors' names as they should appear in TAPAS metadata, separated by vertical bars. | No |
| contributors | A list of contributors' names as they should appear in TAPAS metadata, separated by vertical bars. | No |

If no TEI document is associated with the given `:doc-id`, the API will return an error code.


### Delete a core file and its derivatives

This endpoint removes _all_ files associated with the given document identifier — the core file as well as its derivatives. This action cannot be undone.

`DELETE tapas-xq/:proj-id/:doc-id`

If no TEI document is associated with the given `:doc-id`, the API will return an error code.


## Projects

In TAPAS, core files are contained within “projects”. The XML database does not keep track of TAPAS “collections” (groupings of core files within projects), nor does it track ownership of individual files.

In endpoints described below:

<dl>
  <dt><code>:proj-id</code></dt>
  <dd>The unique identifier of the project which owns the item.</dd>
</dl>


### Delete all stored resources for a project

This endpoint removes _all_ files associated with the given project identifier. Core files and their derivatives alike are deleted from the database. This action cannot be undone.

`DELETE tapas-xq/:proj-id`

If no project collection is associated with the given `:doc-id`, the API will return an error code.


## View packages

In endpoints described below:

<dl>
  <dt><code>:pkg-name</code></dt>
  <dd>A keyword representing the view package name.</dd>
</dl>

### Obtain registry of installed view packages

`GET tapas-xq/view-packages`

Returns an XML registry of all the view packages which are currently installed in TAPAS-xq.

### Obtain the configuration file of an installed view package

`GET tapas-xq/view-packages/:pkg-name`

Returns the XML configuration file for a currently-installed view package.

### Update view packages from GitHub repository

`POST tapas-xq/view-packages/update`


## Informational requests

### Get API documentation

`GET tapas-xq/api`

Returns HTML containing this API documentation.


## Maintenance requests

### Trigger file reindexing (manually)

`POST tapas-xq/reindex`

<!--### Run XQSuite unit tests

`GET tapas-xq/tests`

Because it requires user administration powers, this endpoint can only be run by database administrators.
-->


***

## Changelog

### 2024-01-10

* Revised endpoint URLs and language to reflect the change of XML databases from eXist to BaseX.
* Updated the success code for deletion requests from 200 to 202.
* Removed the `timeline-date` parameter from the MODS generation endpoints.
* Reorganized this document to reflect the entities at stake: core files (+ derivatives), projects, and view packages.

### 2020-02-10

* In the Derive Reader endpoint, acknowledged that individual view packages may require additional parameters.
* Expanded section on unit tests.

### 2020-01-17

* Added API endpoints for running unit tests and for updating view packages.
* Removed 'transforms' parameter from the TFE Storage endpoint.

### 2017-12-07

* Added API endpoint for returning this document as HTML.
* Added endpoints for accessing the view package registry and the configuration files for individual view packages.
* Removed 'assets-base' parameter for the Derive Reader endpoint, since the list of required parameters will now be generated dynamically depending on the view package.
* Changed the base URL to 'tapas-xq' from 'exist/db/apps/tapas-xq', which was incorrect.
* Created this changelog.

### 2015-10-05

* Added 'file' parameter to Store TEI endpoint due to a problem reading the request body.
* Added error handling to all endpoints.
