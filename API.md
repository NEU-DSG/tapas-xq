# TAPAS-xq API

_Last updated 2017-12-07._ For details, see the changelog below.

## For all requests

### Authentication

Each request must contain _either_

* an eXist-db user name and password with the permissions to execute XQueries and modify the 'tapas-data' collection, _or_
* an Authentication header with a user token implying the above.

### Status codes

* Success (derivation): 200
* Success (storage): 201
* Log-in failed/insufficient permissions for executing request: 401
* Unsupported HTTP method: 405
* Unable to access some resource: 500


## Resource requests

### Derive MODS production file from a TEI document

`POST exist/apps/tapas-xq/derive-mods`

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
| timeline-date | The date associated with this item in the TAPAS Timeline feature. |

Returns an XML-encoded file of the MODS record with status code 200. eXist does not store any files as a result of this request.

### Derive XHTML (reading interface) production files from a TEI document

`POST exist/apps/tapas-xq/derive-reader/:type`

Content-type: multipart/form-data

__`:type`__: A keyword representing the type of reader view to generate. For a registry including the valid values,

Parameters:

| Name | Description |
| ------ | ------- |
| assets-base | A file path representing the parent folder of any CSS/JS/image assets that will be referenced by the resulting HTML document. |
| file | An XML-encoded TEI document. |

Returns XHTML generated from the TEI document with status code 200. eXist does not store any files as a result of this request.


## Storage requests

In the storage request API endpoints:

__`:proj-id`__: The identifier of the project which owns the item.

__`:doc-id`__: A unique identifier for the document record attached to the original TEI document and its derivatives (MODS, TFE). Currently maps to the Drupal identifier ('did').

### Store TEI in eXist

`POST exist/apps/tapas-xq/:proj-id/:doc-id/tei`

Content-type: multipart/form-data

Parameters:

| Name | Description |
| ------ | ------- |
| file | An XML-encoded TEI document. |

### Store MODS metadata in eXist (and return the new XML file)

`POST exist/apps/tapas-xq/:proj-id/:doc-id/mods`

Content-type: multipart/form-data

Optional parameters:

| Name | Description |
| ------ | ------- |
| title | The work's title as it should appear in TAPAS metadata. |
| authors | A list of authors' names as they should appear in TAPAS metadata, separated by vertical bars. |
| contributors | A list of contributors' names as they should appear in TAPAS metadata, separated by vertical bars. |
| timeline-date | The date associated with this item in the TAPAS Timeline feature. |

If no TEI document is associated with the given doc-id, the response will have a status code of 500. The TEI file must be stored _before_ any of its derivatives.

### Store TFE metadata in eXist

`POST exist/apps/tapas-xq/:proj-id/:doc-id/tfe`

Content-type: multipart/form-data

Parameters:

| Name | Description |
| ------ | ------- |
| collections | Comma-separated list of collection identifiers with which the work should be associated. |
| is-public | Value of "true" or "false". Indicates if the XML document should be queryable by the public. Default value is false. (Note that if the document belongs to even one public collection, it should be queryable.) |
| transforms | Comma-separated list of view packages compatible with this document. |

If no TEI document is associated with the given doc-id, the response will have a status code of 500. The TEI file must be stored _before_ any of its derivatives.

### Delete project and its resources

`DELETE exist/apps/tapas-xq/:proj-id`

If no project collection is associated with the given doc-id, the response will have a status code of 500.

### Delete document and derivatives

`DELETE exist/apps/tapas-xq/:proj-id/:doc-id`

If no TEI document is associated with the given doc-id, the response will have a status code of 500.


## Informational requests

### Get API documentation

`GET exist/apps/tapas-xq/api`

Returns HTML containing this API documentation.

### Obtain registry of installed view packages

`GET exist/apps/tapas-xq/view-packages`

Returns an XML registry of all the view packages which are currently installed in TAPAS-xq.

### Obtain the configuration file of an installed view package

`GET exist/apps/tapas-xq/view-packages/:type`

__`:type`__: A keyword representing the view package name.

Returns the XML configuration file for a currently-installed view package.


## Maintenance requests

### Trigger file reindexing (manually)

`POST exist/apps/tapas-xq/reindex`

### Update view packages from GitHub repository
### Run XQSuite unit tests

## Changelog

### 2017-12-07

* Added API endpoint for returning this document as HTML.
* Added endpoints for accessing the view package registry and the configuration files for individual view packages.
* Removed 'assets-base' parameter for the Derive Reader endpoint, since the list of required parameters will now be generated dynamically depending on the view package.
* Changed the base URL to 'exist/apps/tapas-xq' from 'exist/db/apps/tapas-xq', which was incorrect.
* Created this changelog.

### 2015-10-05

* Added 'file' parameter to Store TEI endpoint due to a problem reading the request body.
* Added error handling to all endpoints.
